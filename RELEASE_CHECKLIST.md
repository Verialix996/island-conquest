# Island Conquest — Milestone 10 Release Checklist

Scope: Windows desktop export for Godot 4.6, then Steam and itch.io packaging. This checklist was produced from the current repo state on 2026-06-02; it is a release-readiness artifact, not a statement that the build is ready to ship.

## Current release gate status

| Gate | Status | Evidence / action needed |
|---|---|---|
| Godot project opens headless | PASS with warning | `godot --headless --path . --quit` exits 0 on Godot 4.6.3, but emits a runtime navmesh-bake performance warning from `scenes/battle/world_generator.gd:208` / current line `236` after existing repo edits. |
| Static repo checks | PASS | `python3 tools/verify_diplomacy_slice.py`, `python3 tools/verify_battle_chunks.py`, and `git diff --check` pass. |
| Windows export preset | MISSING | No `export_presets.cfg` is present. Create one in the Godot editor before export automation can run. |
| License / redistribution rights | BLOCKED | README says `Personal project — not licensed for redistribution yet`; there is no LICENSE / COPYING / NOTICE file. Add a license decision and asset/audio attribution notes before Steam/itch upload. |
| Release build artifact | NOT VERIFIED | Cannot export until the Windows preset and export templates are configured. |
| Store metadata | TODO | Steam/itch pages need title, capsule art/screenshots, short/long descriptions, system requirements, and install/run instructions. |

## Performance hotspots to address before release

1. Runtime navigation mesh baking parses visual meshes.
   - Evidence: Godot warning during headless project validation: `Source geometry parsing for navigation mesh baking had to parse RenderingServer meshes at runtime... use and parse collision shapes as source geometry or create geometry data procedurally in scripts.`
   - Source: `scenes/battle/world_generator.gd:_bake_navmesh()` sets `geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH` and bakes after cover/walls are generated.
   - Release action: switch runtime bake source to collision geometry where possible, prebuild reusable chunk nav geometry, or gate runtime rebakes to battle setup only and measure battle load time on a Windows target.

2. Per-frame zone processing scales with every active zone body.
   - Source: `scenes/battle/zone.gd:_process()` rebuilds faction counts, filters stale bodies, handles capture/heal/spawn timers every frame.
   - Current scale is small (`zone_count = 6`, `max_units = 5` per zone), so this is acceptable for the current slice.
   - Release action: if battle size grows, move capture/spawn checks to a fixed timer (for example 5–10 times/second) instead of every rendered frame.

3. AI pathing and target scans can scale with unit count.
   - Source: `scenes/units/enemy_base.gd:_physics_process()` refreshes targets every second by scanning faction groups; patrol finds the nearest hostile zone.
   - Current cap is modest, but additional garrisons/turrets/chunks will increase total NavigationAgent3D work.
   - Release action: profile a large battle with the Godot profiler; consider cached hostile lists or staggered target refresh intervals.

4. Transient combat VFX allocate nodes/materials on every shot.
   - Source: `scenes/weapons/weapon_base.gd:spawn_tracer()` creates `MeshInstance3D`, `ImmediateMesh`, and `StandardMaterial3D` for each tracer, then frees it after 0.05s.
   - Release action: acceptable for prototype fire rates, but pool tracer nodes/materials or use a reusable MultiMesh/LineMesh approach if profiling shows spikes.

5. Debug/runtime console output should be intentionally gated.
   - Current broad scan finds routine prints in `scripts/autoloads/game_manager.gd` and `scenes/battle/zone.gd`; `battle_win_detector.gd` debug output is gated by `DEBUG_LOGS := false`.
   - Release action: decide whether zone capture and GameManager ownership messages should remain in release logs, or route them through EventBus/HUD only.

6. Godot resource import warning should be cleaned up.
   - Evidence: `godot --headless --path . --quit` warns that `res://scenes/units/enemy_base.tscn` has an invalid UID for `res://assets/sounds/grunt.ogg` and falls back to the text path.
   - Release action: reimport/regenerate the UID for that sound in the editor and confirm the warning disappears.

## Windows export preset requirements

Create `export_presets.cfg` via Godot Editor > Project > Export. Recommended preset:

- Platform: Windows Desktop
- Name: `Windows Desktop`
- Export path: `build/windows/IslandConquest.exe`
- Export mode: Release
- Architecture: x86_64
- Renderer/features: keep Forward Plus and D3D12 unless lower-spec testing requires Compatibility renderer.
- Embed PCK: choose one policy and document it:
  - Embedded PCK: simpler single `.exe` for itch zip.
  - Separate PCK: easier patching; package `.exe` and `.pck` together.
- Include filters: keep default unless non-resource files are needed.
- Exclude filters: exclude dev-only paths such as `.git/`, `.hermes/`, `docs/plans/`, temporary build dirs, and any local screenshots not meant for release.
- Icon: replace `res://icon.svg` with a game icon if available; otherwise document placeholder art.
- Code signing: optional for itch prototype, recommended for Steam/release builds if available.

After creating the preset, commit it only after checking it contains no local user paths or secrets.

## License and attribution checklist

- Add a root `LICENSE` file or explicit proprietary/all-rights-reserved notice.
- Update README license text so redistribution/upload rights are unambiguous.
- Inventory all assets under `assets/` before uploading:
  - models
  - sounds/music
  - icons/UI art
  - fonts, if any
- Add an attribution section or `NOTICE.md` for third-party assets.
- If assets are placeholders generated in-project, state that clearly so store reviewers and players are not misled.

## Steam release checklist

Before upload:

- Create Steam app depot(s) for Windows x86_64.
- Install Steamworks SDK / SteamPipe tools on the release machine.
- Prepare store assets:
  - capsule/header art
  - screenshots from the release build
  - short description
  - long description
  - tags/genres
  - system requirements
- Decide release type: private beta, playtest, demo, or full app.
- Create a clean release directory containing only the Windows build files and required notices.
- Verify launch options point to `IslandConquest.exe`.
- Run local smoke tests before depot upload.
- Upload with SteamPipe, then install from Steam client on a Windows machine and rerun smoke tests.

Steam packaging notes:

- Keep the depot root simple: `IslandConquest.exe`, `.pck` if separate, license/notice/readme files, and any required DLLs.
- Do not include Godot editor files, `.import/` cache, git metadata, or source docs unless intentionally shipping source.
- If using Steam Input/cloud/achievements later, add Steamworks integration only after the base standalone build is stable.

## itch.io release checklist

Before upload:

- Create an itch project page and mark it draft/private until validated.
- Prepare a Windows zip named like `island-conquest-windows-x86_64-v0.10.0.zip`.
- Zip the contents of the release folder, not the folder above it, so the `.exe` is immediately visible after unzip.
- Include `README.txt`, `LICENSE` or `NOTICE`, and controls summary.
- If Butler is installed, push with a channel such as `windows`:
  - `butler push build/windows_zip verialix/island-conquest:windows --userversion 0.10.0`
- If Butler is not installed, upload the zip manually from the itch dashboard.
- Download/install from itch on a Windows machine and rerun smoke tests.

## Smoke-test commands

Run these from the repo root on the release machine after the Windows preset exists:

```bash
# Confirm toolchain
command -v godot || command -v godot4
godot --version

# Static checks
python3 tools/verify_diplomacy_slice.py
python3 tools/verify_battle_chunks.py
git diff --check

# Import/parse project without launching the editor UI
godot --headless --path . --quit

# Export release build once export_presets.cfg exists
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" build/windows/IslandConquest.exe

# Confirm packaged files; add .pck check if not embedding PCK
find build/windows -maxdepth 2 -type f -print
```

On a Windows target, perform manual smoke tests:

1. Launch `IslandConquest.exe` from a clean folder outside the repo.
2. Start a new game and verify the 4X map loads.
3. Select the player commander, move/claim a tile, and end/advance turns.
4. Open diplomacy, accept/reject an incoming proposal if one appears, and verify the event log updates.
5. Trigger a battle from the map; verify player spawn, enemy spawn, zone capture, shooting, reload, and respawn/tickets.
6. Finish or auto-resolve a battle; verify the map result applies correctly.
7. Trigger victory/defeat/new-game flow if practical.
8. Close and relaunch the build; confirm no missing DLL/PCK/resource errors.
9. Check Windows Defender/SmartScreen behavior and record whether unsigned-build warnings appear.

## Suggested release order

1. Decide license/redistribution language and add root legal files.
2. Create and validate `export_presets.cfg` for Windows Desktop.
3. Fix or intentionally accept the runtime navmesh-bake warning after profiling battle load time.
4. Reimport/regenerate the invalid `grunt.ogg` UID and confirm no project-open warnings remain.
5. Remove/gate release-noisy prints if desired.
6. Export a Windows release build.
7. Smoke-test on a Windows machine.
8. Package itch zip and/or Steam depot.
9. Install from the store channel and repeat smoke tests.
10. Tag the release only after store-channel validation passes.
