# CLAUDE.md — Tactical Top-Down Shooter (Godot 4)

## Project Overview

We are building a **3D top-down military/tactical open-world sandbox** using **Godot 4**.
The full vision: a randomly generated continent, multiple AI factions with randomized goals that simulate autonomously, full diplomacy, territory control, and RTS-lite base building. Comparable in scope to Mount & Blade or Kenshi.

This is a **learning-first** project. The developer is a complete beginner to Godot and game development.
Claude Code's role is equal parts **collaborator and teacher** — always explain *why* you're doing something, not just *what*.

---

## Developer Profile

- **Experience level:** Complete beginner (no prior Godot or game dev experience)
- **Learning goals:** Understand Godot 4 architecture, GDScript, scene/node system, game loops, and how to iterate toward a shippable product
- **Working style:** Hands-on — wants to type/build things themselves, not copy-paste. Claude guides step by step.

---

## Game Vision

| Attribute | Detail |
|---|---|
| **Engine** | Godot 4 (latest stable) |
| **Perspective** | Top-down 3D (camera at an angle above the player) |
| **Genre** | Military / Tactical Shooter + Grand Strategy |
| **Setting** | Modern military |
| **Game Loop** | Territory control, faction management, RTS-lite base building |
| **World** | Randomly generated large continent, regions, roads, cities |
| **Factions** | Multiple AI factions fight each other and player, full diplomacy |
| **Done criteria** | Boot up → random world → factions with random goals → everything simulates |
| **Target Platform** | PC (Windows primary) |
| **Monetization** | Commercial release (Steam or itch.io) |

---

## How Claude Code Should Work With Me

1. **Teach as you build.** Before writing any non-trivial code, briefly explain the concept or pattern being used.
2. **Explain Godot-specific concepts on first use.** Nodes, Scenes, Signals, the SceneTree, Resources, Autoloads.
3. **Guide, don't create.** Give step-by-step instructions for the developer to follow. Only write code files directly when the developer asks. Never auto-create files without permission.
4. **Build incrementally.** Always prefer small, testable steps. After each step, explain how to test it.
5. **Comment the code.** All GDScript files should have meaningful comments explaining non-obvious logic.
6. **Think about sellability.** Flag tradeoffs between quick prototype and production quality.
7. **Ask before assuming.** If a design decision isn't clear, ask rather than guess.
8. **Milestone thinking.** Always know what the current milestone is and what "done" looks like for it.

---

## Tech Stack

- **Engine:** Godot 4 (GDScript — not C#)
- **Language:** GDScript
- **Version control:** Git (remind the developer to commit after each milestone)
- **Asset pipeline:** Godot primitives until Milestone 9; Blender for custom art from Milestone 9+
- **Audio:** Godot's built-in AudioStreamPlayer3D
- **UI:** Godot's built-in Control nodes (CanvasLayer)

---

## Current File Structure (actual)

```
scenes/
├── player/
│   ├── player.tscn
│   └── player.gd
├── enemies/
│   ├── enemy_base.tscn + enemy_base.gd     # Melee, faction-aware, navigates to hostile zones
│   └── enemy_ranged.tscn + enemy_ranged.gd # Ranged, keeps preferred distance, strafe-backs
├── weapons/
│   ├── weapon_base.tscn + weapon_base.gd   # Pistol (unlimited mags)
│   ├── weapon_rifle.tscn                   # Rifle (inherits base)
│   └── weapon_shotgun.tscn + weapon_shotgun.gd
├── world/
│   ├── main_world.tscn                     # Main scene
│   ├── camera.gd
│   ├── hud.gd
│   ├── supply_station.tscn + supply_station.gd  # Visual prop only (healing now in zone.gd)
│   └── zone.tscn + zone.gd                # Faction-aware capture + healing + unit spawning
scripts/
├── health_component.gd                     # Body part health system
├── world_generator.gd                      # Procedural world: cover, zones, navmesh, starting units
├── game_manager.gd                         # Autoload: zone ownership + faction registry
├── event_bus.gd                            # Autoload: global signal hub
└── resources/
    ├── body_part.gd                        # Body part Resource
    ├── faction_data.gd                     # FactionData Resource (name, color, is_player_faction)
    ├── faction_player.tres                 # Green, is_player_faction=true
    ├── faction_red.tres                    # Red AI faction
    ├── faction_blue.tres                   # Blue AI faction
    └── faction_orange.tres                 # Orange AI faction
assets/
└── sounds/
    ├── gunshot.wav
    ├── grunt.ogg
    └── death_male.wav
```

---

## Development Milestones

### Milestone 1 — Foundation ✅
- [x] Top-down 3D camera, WASD movement, mouse aiming, flat terrain

### Milestone 2 — Core Combat ✅
- [x] Raycast weapon, enemy AI (chase/attack), player health, HUD health bar

### Milestone 3 — Game Feel ✅
- [x] Screen shake, muzzle flash, sound effects, hit flash, death sound

### Milestone 4 — Open World Sandbox ✅
- [x] Large world (100x100) with cover objects and navigation mesh
- [x] Two enemy types: melee (blue) and ranged (purple), using scene inheritance
- [x] Three weapons: pistol (unlimited), rifle, shotgun — with tracer lines
- [x] Body part health system (head/torso/arms/legs), probability-based hits, stacking debuffs
- [x] Magazine-based ammo: discard on reload, auto-switch to pistol when empty
- [x] Supply station: heals and rearms player when nearby (replaces pickups)
- [x] Zone capture system: clear enemies → zone turns green → foundation for territory control

### Milestone 5 — Territory & Factions ✅
- [x] `FactionData` Resource: name, color, is_player_faction flag
- [x] Zone ownership: each zone belongs to a faction (colored cylinder marker)
- [x] Faction-aware capture: dominant faction by body count wins the zone
- [x] Zone heals + rearms player when in a player-owned zone
- [x] Factions fight each other — units from different factions attack each other
- [x] GameManager autoload: tracks zone_ownership and zones dictionaries
- [x] EventBus autoload: zone_captured / zone_lost / faction_relationship_changed signals
- [x] Zone spawns units for its owner faction every 10 seconds (50/50 melee/ranged)

### Milestone 6 — Procedural World Generation ✅
- [x] WorldGenerator node: procedurally places cover, zones, and starting units at runtime
- [x] Zones assigned to factions (player gets closest, AI round-robins Red/Blue/Orange)
- [x] All factions start with units around their zones
- [x] Navigation mesh baked at runtime (PARSED_GEOMETRY_BOTH, agent_radius=1.0, RVO avoidance)
- [x] All generation settings exposed as @export vars (editable in Inspector)

### Milestone 7 — Base Building
- [ ] Player can place structures in owned zones
- [ ] Structure types: barracks (spawns units), wall, turret, supply depot
- [ ] Resource system: supply points generated by owned zones
- [ ] Tech tree: unlock better units/buildings with resources
- [ ] Supply station tied to supply depot building in owned zone

### Milestone 8 — Full Faction Simulation
- [ ] Factions have economies (resources from owned zones)
- [ ] Factions make autonomous decisions: expand, attack, defend, negotiate
- [ ] Factions form alliances and declare war on each other
- [ ] World state evolves even when player is idle

### Milestone 9 — Full Diplomacy
- [ ] Player can send/receive diplomatic messages
- [ ] Treaties: ceasefire, alliance, trade, vassalage
- [ ] Faction agendas: expansionist, isolationist, opportunist
- [ ] Betrayal, coalition building, faction collapse
- [ ] Start replacing placeholder art with Blender low-poly models

### Milestone 10 — Polish & Release
- [ ] Full art and sound pass
- [ ] Main menu, pause menu, game over screen
- [ ] Map screen UI showing faction territories
- [ ] Performance pass for large simulated world
- [ ] Build export for Windows
- [ ] Steam / itch.io page preparation

---

## Key Architecture Decisions (already made)

- **Scene inheritance** for enemies and weapons — new types override only what's different
- **HealthComponent** node on every unit — body part system, hit rolling, debuff signals
- **BodyPart Resource** — data container per body part (hit chance, health, debuff type)
- **Mag-based ammo** — discard on reload, auto-switch to pistol when empty
- **Zone as Area3D** — uses `get_overlapping_bodies()` each frame to check capture state
- **Supply station** — heals/rearms only in captured zones (Milestone 5 will enforce this)
- **Factions as Resources** — faction data stored as Godot Resources (Milestone 5)
- **GameManager + EventBus autoloads** — global state and signal hub (Milestone 5)

---

## Health & Ammo System (implemented)

### Body Part System
| Part | Hit Chance | Max HP | On Depleted | Debuff |
|---|---|---|---|---|
| Head | 10% | 30 | Instant death | Accuracy |
| Torso | 40% | 80 | Instant death | Damage taken |
| Left Arm | 15% | 40 | Max debuff | Weapon sway |
| Right Arm | 15% | 40 | Max debuff | Fire rate |
| Legs | 20% | 50 | Max debuff | Movement speed |

- Debuffs stack across all damaged parts
- Weapons can have hit chance modifiers (e.g. shotgun: +legs, -head)

### Ammo System
- Pistol: unlimited mags, 12 rounds, fallback weapon (key 1)
- Rifle: 5 mags, 30 rounds (key 2)
- Shotgun: 4 mags, 8 rounds, 6 pellets with spread (key 3)
- R to reload — discards current mag (Tarkov style)
- Auto-switch to pistol when rifle/shotgun runs out of mags

---

## Coding Conventions (GDScript)

```gdscript
# snake_case for variables and functions
# PascalCase for class names
# Always type-hint variables where possible
# Use signals for decoupled communication
# Autoloads accessed via registered name (e.g. GameManager.zones)
# One responsibility per script
```

---

## Asset Plan

- **Milestones 1-8:** Godot primitives (boxes, capsules) with faction colors
- **Milestone 9+:** Blender for low-poly 3D models (units, buildings, vehicles)
- **Animation:** Minimal — top-down camera makes character animation barely visible. Use Godot AnimationPlayer for buildings/UI. Blender for any character animations in Milestone 10.

---

## Notes for Claude Code

- Always refer back to the current milestone before suggesting new features
- If the developer asks "how does X work," stop and explain before writing code
- Remind the developer to commit after each milestone
- Keep scripts focused — one responsibility per script
- When in doubt, build the simplest version first and note where to expand later
- The developer types code themselves — guide step by step, don't auto-generate files
