# CLAUDE.md — Tactical Top-Down Shooter (Godot 4)

## Project Overview

We are building a **3D top-down military/tactical open-world sandbox shooter** using **Godot 4**.
The goal is a functional, polished, and commercially sellable game.

This is a **learning-first** project. The developer is a complete beginner to Godot and game development.
Claude Code's role is equal parts **collaborator and teacher** — always explain *why* you're doing something, not just *what*.

---

## Developer Profile

- **Experience level:** Complete beginner (no prior Godot or game dev experience)
- **Learning goals:** Understand Godot 4 architecture, GDScript, scene/node system, game loops, and how to iterate toward a shippable product
- **Working style:** Hands-on — build real things, learn from them, refine them

---

## Game Vision

| Attribute | Detail |
|---|---|
| **Engine** | Godot 4 (latest stable) |
| **Perspective** | Top-down 3D (camera at an angle above the player) |
| **Genre** | Military / Tactical Shooter |
| **Game Loop** | Open world / sandbox — player has freedom to explore, complete objectives, and engage enemies in a persistent world |
| **Target Platform** | PC (Windows primary, Mac/Linux secondary) |
| **Monetization goal** | Commercial release (Steam or itch.io) |

---

## How Claude Code Should Work With Me

1. **Teach as you build.** Before writing any non-trivial code, briefly explain the concept or pattern being used (e.g. "We're using a CharacterBody3D here because it gives us built-in physics helpers for a moving character — here's what that means...").

2. **Explain Godot-specific concepts on first use.** Nodes, Scenes, Signals, the SceneTree, Resources, Autoloads — explain them the first time they appear.

3. **Build incrementally.** Always prefer small, testable steps over large code dumps. After each step, explain how to test it in the Godot editor.

4. **Comment the code.** All GDScript files should have meaningful comments explaining non-obvious logic.

5. **Think about sellability.** When making design decisions, mention if there's a tradeoff between "quick prototype" and "production quality." Flag tech debt.

6. **Ask before assuming.** If a design decision isn't clear (e.g. how many enemy types, what weapons to start with), ask rather than guess.

7. **Milestone thinking.** Always know what the current milestone is and what "done" looks like for it.

---

## Tech Stack

- **Engine:** Godot 4 (GDScript — not C#)
- **Language:** GDScript
- **Version control:** Git (remind the developer to commit after each milestone)
- **Asset pipeline:** Start with Godot primitives and free assets; upgrade to custom art later
- **Audio:** Godot's built-in AudioStreamPlayer3D
- **UI:** Godot's built-in Control nodes (CanvasLayer)

---

## Project Structure

```
project/
├── scenes/
│   ├── player/
│   │   ├── player.tscn
│   │   └── player.gd
│   ├── enemies/
│   │   ├── enemy_base.tscn
│   │   └── enemy_base.gd
│   ├── world/
│   │   ├── main_world.tscn
│   │   └── terrain/
│   ├── ui/
│   │   ├── hud.tscn
│   │   └── hud.gd
│   └── weapons/
│       ├── weapon_base.tscn
│       └── weapon_base.gd
├── scripts/
│   ├── autoloads/
│   │   ├── game_manager.gd      # Global game state
│   │   └── event_bus.gd         # Global signal hub
│   └── resources/
│       ├── weapon_data.gd       # Weapon stats as Resources
│       └── enemy_data.gd        # Enemy stats as Resources
├── assets/
│   ├── textures/
│   ├── models/
│   ├── sounds/
│   └── music/
└── CLAUDE.md
```

---

## Development Milestones

Work through these in order. Do not skip ahead.

### Milestone 1 — Foundation ✅
- [x] Godot project created and organized per folder structure above
- [x] Top-down 3D camera set up and working
- [x] Player character moves in the world (WASD)
- [x] Player aims toward mouse cursor (top-down aiming)
- [x] Basic flat terrain / placeholder world

### Milestone 2 — Core Combat ✅
- [x] Player can fire a weapon (raycast)
- [x] Basic enemy with health that can be damaged and killed
- [x] Enemy has simple AI (patrol → detect → chase → attack)
- [x] Player has health and can die (scene restarts)
- [x] Basic HUD (health bar)

### Milestone 3 — Game Feel ✅
- [x] Screen shake when player takes damage
- [x] Muzzle flash particles when shooting
- [x] Sound effects: gunshots, player hit grunt, enemy death
- [x] Enemy freezes and plays death sound before disappearing
- [x] Player and enemy flash red on hit

### Milestone 4 — Open World Sandbox
- [ ] Larger explorable world with cover objects
- [ ] Multiple enemy types (at least 2)
- [ ] Multiple weapons (at least 2, e.g. rifle + shotgun)
- [ ] Pickups: ammo, health, weapons
- [ ] Objective system (simple: eliminate all enemies in zone)

### Milestone 5 — Polish & Loop
- [ ] Main menu scene
- [ ] Pause menu
- [ ] Death / game over screen with restart
- [ ] Save/load or persistent world state (basic)
- [ ] Performance pass: ensure smooth framerate

### Milestone 6 — Pre-Release
- [ ] Replace placeholder art with consistent visual style
- [ ] Sound and music pass
- [ ] Playtesting feedback and balance
- [ ] Build export for Windows
- [ ] Steam / itch.io page preparation

---

## Coding Conventions (GDScript)

```gdscript
# Use snake_case for variables and functions
var player_health: int = 100

# Use PascalCase for class names
class_name PlayerController

# Always type-hint variables where possible
var speed: float = 5.0
var enemies: Array[Node] = []

# Use signals for decoupled communication
signal player_died
signal enemy_killed(enemy: Node)

# Autoloads are accessed via their registered name, not preloaded
# e.g. GameManager.current_level (not load("res://..."))

# Every script file should have a brief comment at the top explaining its purpose
```

---

## Key Godot 4 Concepts to Learn (in order)

1. **Nodes & Scenes** — Everything is a node; scenes are reusable node trees
2. **CharacterBody3D** — The right node for a player or enemy that moves
3. **Signals** — How nodes communicate without tight coupling
4. **@export** — How to expose variables to the Godot editor inspector
5. **Autoloads (Singletons)** — Global scripts for game state and events
6. **Resources** — Data containers (great for weapon/enemy stats)
7. **AnimationPlayer / AnimationTree** — Character animations
8. **NavigationAgent3D** — Enemy pathfinding
9. **RayCast3D** — Hit detection for weapons
10. **GPUParticles3D** — Visual effects

---

## Design Principles

- **Fun first, graphics second.** A game with placeholder cubes that feels great beats a beautiful game that feels bad.
- **Iterate fast.** Get something working, play it, improve it.
- **Scope management.** When a new idea comes up, add it to a "future features" list rather than implementing it immediately.
- **Sellability checklist:** Good game loop, clear win/lose states, polished core experience, works without crashes, has a reasonable content volume.

---

## Future Features (Backlog — do not implement until Milestone 4+)

- Destructible environments
- Vehicles
- Stealth mechanics
- Day/night cycle
- Multiplayer
- Procedural map generation
- Mission/story campaign
- Inventory system
- Skill tree / progression

---

## Notes for Claude Code

- Always refer back to the current milestone before suggesting new features
- If the developer asks "how does X work," stop and explain it before writing code
- Remind the developer to run and test in Godot after each meaningful change
- Keep scripts focused — one responsibility per script
- When in doubt, build the simplest version first and note where to expand later
