# Island Conquest

A top-down 3D military strategy game built in **Godot 4**. You fight on the ground in a tactical shooter, then zoom out to a grand strategy map to manage territory, factions, and diplomacy — think Mount & Blade meets Catan.

---

## Concept

The world is a randomly generated continent divided into provinces. Multiple AI factions compete for control. You can fight battles yourself in the 3D shooter phase, or auto-resolve them on the map. Build bases, manage resources, declare wars, forge alliances, and conquer the island.

---

## Features (current)

- **Top-down 3D shooter** — WASD movement, mouse aiming, 3 weapon types (pistol / rifle / shotgun)
- **Body part hit system** — head, torso, arms, legs each have separate HP and apply unique debuffs
- **Territory control** — capture zones, factions fight over them in real time
- **Procedural world** — Voronoi hex map with noise-based terrain, dice resource numbers (Catan-style), organic province shapes
- **4X strategy map** — turn-based, AP system, dice rolls for resource production
- **Commander tokens** — move across hexes, declare attacks; army strength grows by recruiting each turn
- **Building system** — Barracks, Wall, Turret, Energy Plant per hex; each has physical battlefield effects
- **Faction traits** — 10-trait pool (Aggressive, Expansionist, Builder, Militarist, Pacifist, etc.); 3 randomly assigned per AI faction at game start; drive all AI behaviour
- **Full faction simulation** — 5 factions with BFS expansion, trait-driven war/peace/building decisions, and event-driven AI
- **Diplomacy** — war, peace, alliance; player diplomacy panel; AI peace offers based on faction traits
- **Battle transition** — map attack → 3D shooter scene → result applied back to map
- **Ticket-based respawn** — base 10 tickets per side + commander army strength; building effects modify further
- **Trade exchange** — spend 2 trade resources to gain 1 of any other resource via Map HUD
- **Event log** — scrolling in-map feed of AI actions (wars declared, territory captured, peace made, Barbarian spawns, buildings placed)

---

## Tech Stack

| | |
|---|---|
| Engine | Godot 4 (GDScript) |
| Rendering | Forward Plus, D3D12 |
| Physics | Jolt Physics |
| Platform | Windows (PC) |
| Art | Godot primitives (placeholder) |

---

## Project Structure

```
scenes/
├── battle/       # 3D shooter phase (world, zones, HUD, camera)
├── map/          # 4X strategy map phase
├── player/       # Player character
├── units/        # Enemy/ally unit scenes (melee + ranged)
└── weapons/      # Pistol, rifle, shotgun

scripts/
├── autoloads/    # Global singletons (EventBus, GameManager, TurnManager, etc.)
├── components/   # Reusable components (HealthComponent)
└── resources/    # Data classes and .tres instances (FactionData, ProvinceData, etc.)

assets/
└── sounds/       # Gunshot, hit, death sounds
```

---

## Roadmap

### ✅ Milestone 1 — Foundation
Top-down camera, WASD movement, mouse aiming, flat terrain.

### ✅ Milestone 2 — Core Combat
Raycast weapon, enemy chase/attack AI, player health, HUD.

### ✅ Milestone 3 — Game Feel
Screen shake, muzzle flash, sound effects, hit flash, death sound.

### ✅ Milestone 4 — Open World Sandbox
Large world with cover, two enemy types, three weapons, body part health system, mag-based ammo, supply stations, zone capture.

### ✅ Milestone 5 — Territory & Factions
FactionData resources, zone ownership with faction colors, zone healing/resupply, inter-faction combat, GameManager + EventBus autoloads, zone unit spawning.

### ✅ Milestone 6 — Procedural World Generation
Runtime procedural cover, zone placement, faction starting positions, runtime navmesh baking.

### ✅ Milestone 7 — 4X Map Phase
Voronoi hex map, turn manager, resource system, province info panel, commander tokens, buildings, diplomacy, attack → battle transition, Barbarian faction, AI director, win/lose conditions.

### ✅ Milestone 8 — Full Faction Simulation
Faction traits, commander armies, building battlefield effects, commander defeat/retreat flow, trade exchange UI, trait-driven AI war/peace/expansion/building, event log.

### Milestone 9 — Full Diplomacy
Player diplomatic messages, treaties (ceasefire / alliance / trade / vassalage), faction agendas (expansionist / isolationist / opportunist), betrayal, coalition building, faction collapse. Begin replacing placeholder art with Blender low-poly models.

### Milestone 10 — Polish & Release
Full art and sound pass, main menu, pause menu, game over screen, map territory overview, performance pass, Windows build export, Steam / itch.io release.

---

## Getting Started

1. Clone the repo
2. Open the project folder in **Godot 4**
3. Press **F5** to run — the 4X map loads first
4. Click a province to see info, move your commander, declare attacks
5. When a battle triggers, the 3D shooter phase loads automatically

---

## License

Personal project — not licensed for redistribution yet.
