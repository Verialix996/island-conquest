# Island Conquest — Game Systems Reference

Current state of every implemented system. Updated as of Milestone 8.

---

## 1. Body Part Health System

Every unit (player and enemies) has five independent body parts, each with its own HP pool, hit probability, and debuff effect.

| Part | Hit Chance | Max HP | Lethal | Debuff on damage |
|---|---|---|---|---|
| Head | 10% | 30 | Yes | Accuracy penalty |
| Torso | 40% | 80 | Yes | Increased damage taken |
| Left Arm | 15% | 40 | No | Weapon sway |
| Right Arm | 15% | 40 | No | Fire rate reduction |
| Legs | 20% | 50 | No | Movement speed reduction |

- When a lethal part (head or torso) reaches 0 HP the unit dies.
- Non-lethal parts at 0 HP lock at maximum debuff strength.
- Debuffs stack across all damaged parts.
- Weapons can pass hit-chance modifiers (e.g. shotgun biases toward legs, away from head).
- **Script:** `scripts/components/health_component.gd`, `scripts/resources/body_part.gd`

---

## 2. Weapon System

Three weapon types. The player starts with all three; enemies use melee or ranged AI instead.

| Weapon | Key | Mag size | Mags | Mechanic |
|---|---|---|---|---|
| Pistol | 1 | 12 | ∞ | Fallback, always available |
| Rifle | 2 | 30 | 5 | Hitscan raycast |
| Shotgun | 3 | 8 | 4 | 6 pellets per shot, spread pattern |

- **Reload (R):** discards the current mag regardless of remaining rounds (Tarkov-style).
- **Auto-switch:** when the active weapon runs out of mags it automatically switches to the pistol.
- **Ammo HUD:** current mag / mags remaining shown bottom-right.
- **Tracer lines:** brief visual line drawn from muzzle to hit point on fire.
- **Scripts:** `scenes/weapons/weapon_base.gd`, `scenes/weapons/weapon_shotgun.gd`

---

## 3. Enemy AI

Two enemy archetypes, both based on the same state machine:

**States:** `PATROL → CHASE → ATTACK`

- **PATROL:** moves toward the nearest hostile zone.
- **CHASE:** navigates toward the nearest hostile unit within detection range.
- **ATTACK:** stops and fires/melee-attacks at the target on a timer.

**Melee (`enemy_base`):** close-range attack, blue capsule model.
**Ranged (`enemy_ranged`):** keeps preferred distance (~8 units), fires raycasts with configurable damage and cooldown, purple capsule model.

Both types:
- Are faction-aware: only attack units from a different faction.
- Use `NavigationAgent3D` + RVO avoidance for pathfinding.
- Color themselves by their faction's color on spawn.
- Join the `"enemy"` group and a faction-specific group (`"green"` for player faction, faction name lowercase for others).
- **Scripts:** `scenes/units/enemy_base.gd`, `scenes/units/enemy_ranged.gd`

---

## 4. Zone Capture System

Zones are `Area3D` cylinders placed in the battle scene. Each has a faction owner.

**Capture logic (runs every frame):**
1. Count bodies inside the zone by faction.
2. The faction with the most bodies is "dominant" (tie = contested, no progress).
3. If the dominant faction differs from the owner: capture progress increments.
4. When progress reaches `capture_time` (default 3s) the zone is captured.
5. If the dominant faction is the owner (or contested): progress decays back to 0.

**While in a player-owned zone:**
- Player heals `heal_amount` HP every `heal_interval` seconds (applied to most-damaged body part).
- Player's active weapon gets `mags_to_add` magazines refilled when below max.

**Unit spawning:**
- Every `spawn_interval` seconds (default 10s) the zone spawns one melee or ranged unit for its owner faction.
- In battle mode: spawning consumes a ticket (player side = player ticket, enemy side = enemy ticket). No ticket = no spawn.
- Maximum `max_units` alive at a time per zone.
- **Script:** `scenes/battle/zone.gd`

---

## 5. Battle Phase (Shooter)

The 3D shooter scene (`scenes/battle/main_world.tscn`) is the tactical layer.

**Entry:** triggered from the 4X map via `BattleContext`. Two paths:
- **Attack:** player's commander attacks an enemy province.
- **Defense:** an AI faction attacks a player-owned hex.

**Setup (WorldGenerator):**
- Places cover objects randomly across the map.
- Splits zones: first half (closest to player spawn) → player faction, second half → enemy faction.
- Spawns initial enemy garrison units near enemy zones (offset ±2 units from zone center).
- Repositions the player character to a friendly zone on load.
- Bakes the navigation mesh at runtime.
- Adds `BattleWinDetector` and `BattleTracker` nodes to the scene.

**Ticket system:**
- Each side starts with 10 tickets.
- Player death → consumes 1 player ticket → respawn at nearest friendly zone. At 0 tickets: lose.
- Zone unit spawning → consumes 1 ticket per unit. At 0 tickets: zone stops spawning.
- HUD shows `Allies: N   Enemies: N` (top-right).
- **Script:** `scenes/battle/battle_tracker.gd`

**Win condition (checked every 2s):**
- All living hostile units dead AND no enemy-owned zones remain → player wins.
- Player tickets reach 0 when dying → player loses.
- Result is reported back to `BattleContext.finish_battle(won)`.
- **Script:** `scenes/battle/battle_win_detector.gd`

**Ticket system (M8 update):**
- Base tickets = 10 + commander army strength for each side.
- Building effects apply on top: Energy Plant +2 tickets to defender; Barracks +3 garrison units; Wall spawns box obstacles around enemy zones (navmesh rebaked); Turret spawns a near-stationary ranged unit with detection range 30.

**Post-battle (map phase):**
- Win: attacker captures the contested hex; losing commander's army is wiped (strength → 0) and the commander teleports to a friendly capital.
- Lose: defender holds the hex; attacking commander retreats the same way.
- A commander with no friendly province left is eliminated permanently.

---

## 6. 4X Strategy Map

The grand strategy layer (`scenes/map/province_map.tscn`).

### Province Grid

- **12 × 8 hex grid** using odd-row offset coordinates.
- Each hex belongs to a province (Voronoi regions, 16 provinces).
- Terrain types: Plains, Forest, Mountains, Urban, Desert — assigned by noise.
- Each province has a **dice number** (2–12) distributed Catan-style.
- Each hex has a **resource type** derived from its terrain (Manpower / Oil / Steel / Trade).
- **Autoload:** `scripts/autoloads/province_grid.gd`

### Turn Manager

Turn order: Player → Red → Blue → Orange → Barbarian.

**Each turn:**
1. Roll 2d6. Provinces whose dice number matches → collect resources for every hex owned by that faction.
2. Seed hex (province capital) produces double resources.
3. Player gets **3 Action Points** to spend.
4. AI factions take their turns automatically via AIDirector.
5. All declared attacks resolve (battle phase or auto-resolve).

**Action costs:**

| Action | AP |
|---|---|
| Move commander 1 hex | 1 |
| Claim neutral hex | 1 |
| Build in province | 1 |
| Declare attack | 2 |

- **Autoload:** `scripts/autoloads/turn_manager.gd`

### Resource System

Four resource types per faction:

| Resource | Produced by terrain |
|---|---|
| Manpower | Plains, Forest |
| Steel | Mountains |
| Trade | Urban |
| Oil | Desert |

- Resources stored in `faction.resources` dictionary.
- Buildings add `income_bonus` to their hex's production.
- Seed hex (province capital) doubles production.
- Displayed in the Map HUD as a resource bar.

### Commander Tokens

- Each faction starts with 1 commander.
- Rendered as colored circles on the hex map.
- Click to select, click adjacent hex to move (1 AP).
- **Has-attacked flag** resets each turn.
- **Army strength:** commanders have `strength` (0–10). At the start of their faction's turn, while standing on a friendly hex, they recruit up to 2 units (costs 1 manpower each). Militarist trait adds extra recruit capacity.
- **Strength adds to battle tickets:** entering battle grants `strength` extra tickets to that side.
- **On defeat:** army wiped to 0, commander teleports to any friendly capital. Eliminated only if no friendly territory remains. Respawns with 0 strength next turn if they had no commander.
- **Script:** `scenes/map/commander_token.gd`, **Data:** `scripts/resources/commander_data.gd`

### Building System

One building slot per hex. Buildings cost resources and provide bonuses.

| Building | Cost | Map effect | Battlefield effect |
|---|---|---|---|
| Barracks | 20 manpower | — | +3 extra garrison units spawned near defender zones |
| Wall | 15 steel | — | 4 box obstacles placed around each defender zone |
| Turret | 10 steel + 10 oil | — | 1 stationary ranged unit at zone center (range 30, nearly immobile) |
| Energy Plant | 20 oil | +5 income | +2 tickets to defending side |

- Buildings placed by the player via the Province Info Panel (1 AP cost).
- AI Builder/Militarist factions place Barracks automatically when they can afford it.
- Battlefield effects are applied by `WorldGenerator._apply_building_effects()` after garrison is spawned. Walls are added before the navmesh bake so pathfinding routes around them.
- **Script:** `scenes/map/province_info_panel.gd`, **Data:** `scripts/resources/building_data.gd`

### Trade Exchange

- **Rate:** 2 trade resource → 1 of any other resource (manpower / steel / oil).
- Player accesses this via the **Trade** button in the Map HUD top bar, which opens a small popup.
- Buttons are disabled when the player has fewer than 2 trade.
- **Autoload:** `scripts/autoloads/diplomacy_manager.gd` (`exchange_trade`, `can_exchange`)

### Diplomacy System

Relations between factions: **War / Peace / Alliance**.

- **War:** can attack each other's provinces.
- **Peace:** cannot attack, can coexist.
- **Alliance:** cannot attack each other, may coordinate.

Player actions available via the Diplomacy panel (click a faction):
- Declare war, offer peace, propose alliance.

AI reactions are handled by AIDirector based on aggression values and existing war states.
- **Autoload:** `scripts/autoloads/diplomacy_manager.gd`, **Panel:** `scenes/map/diplomacy_panel.gd`

### Win / Lose Conditions (Map)

- **Win:** control majority of provinces.
- **Lose:** all your provinces are captured (eliminated).
- Either triggers an end-game screen with a **New Game** option that resets all state.

---

## 7. AI Director

Controls Red, Blue, Orange, and Barbarian factions each turn.

**Each turn runs in this order:**
1. `_consider_peace` — trait-driven peace offers (DIPLOMATIC / TRADER factions).
2. `_consider_war_declarations` — trait-modified war chance against neighboring factions.
3. `_consider_building` — BUILDER / MILITARIST factions spend resources on Barracks.
4. Commander action loop: move → claim neutral → attack enemy, spending AP until exhausted.

**War declaration logic:**
- Base chance 0.30, modified by each trait's `war_declaration_bias`.
- PACIFIST never declares war.
- OPPORTUNIST only targets factions with fewer provinces than itself.
- Barbarian is excluded — always at war.

**Expansion priority:**
- Default: attack adjacent enemies first (priority 1), then claim neutral hexes (priority 2).
- EXPANSIONIST trait reverses this: claim neutrals first, then attack.

**Peace offers:**
- Factions sum their traits' `peace_bias`. If > 0, they roll each turn against each enemy faction.
- Barbarian faction is excluded from peace offers entirely.

**Building placement:**
- BUILDER or MILITARIST factions pick a random owned hex without a building and place a Barracks when they can afford 20 manpower. One building per turn.

**Barbarian faction:**
- Created when a 7 is rolled (Catan-style map event).
- Always at war with everyone; never receives or sends peace offers.
- Expands into neutral hexes only via the standard BFS commander loop.

- **Autoload:** `scripts/autoloads/ai_director.gd`

---

## 8. World Generator (Battle Scene)

Procedurally builds the battle scene at runtime.

- Places `cover_count` (default 30) randomly oriented box obstacles.
- Generates and places `zone_count` (default 6) zones with minimum spacing.
- Splits zones between player and enemy faction based on proximity to player start.
- Spawns initial garrison units for the enemy faction near their zones.
- Moves the player character to a friendly zone.
- Applies building effects from `BattleContext.contested_hex_building` (see below).
- Bakes the navigation mesh **after** walls are placed, so pathfinding routes around them.

**Building effects (`_apply_building_effects`):**

| Building | Effect in battle scene |
|---|---|
| Barracks | Spawns 3 extra melee units near enemy zones |
| Wall | Places 4 `StaticBody3D` box obstacles around each enemy zone perimeter |
| Turret | Spawns a near-stationary `enemy_ranged` unit at the enemy zone center (detection range 30, move speed 0.1) |
| Energy Plant | Adds +2 tickets to the defending side's `BattleTracker` |

Walls are added as children of the `NavigationRegion3D` before the navmesh bake so agents route around them. Units spawned by building effects are assigned the enemy faction via `unit.set("faction", ...)` since `PackedScene.instantiate()` returns a base `Node`.

All settings are `@export` variables — editable in the Inspector.
- **Script:** `scenes/battle/world_generator.gd`

---

## 9. Event Bus

Central signal hub for cross-system communication. All signals are defined here; systems subscribe to what they need without holding direct references to each other.

Key signals:
- `zone_captured(zone, faction)` — fired when a zone changes owner
- `resources_changed(faction)` — fired after resource collection
- `battle_choice_needed(province, is_defense, attacker)` — intercepts battle launch for auto-resolve dialog
- `turn_started / turn_ended / round_ended / dice_rolled`

- **Autoload:** `scripts/autoloads/event_bus.gd`

---

## 10. Faction Data

Each faction is a Godot `Resource` (`.tres` file) with:
- `faction_name: String`
- `color: Color`
- `is_player_faction: bool`
- `aggression: float` (0.0 – 1.0, used by AI for war decisions)
- `resources: Dictionary` (manpower / oil / steel / trade counts)
- `relationships: Dictionary` (key = other faction name, value = -1.0 to 1.0)
- `traits: Array` (Array[FactionTrait], 3 assigned at game start)

Helper: `has_trait(TraitType) -> bool` — used by AIDirector and TurnManager.

Faction files: `faction_player.tres`, `faction_red.tres`, `faction_blue.tres`, `faction_orange.tres`, `faction_barbarian.tres`
- **Script:** `scripts/resources/faction_data.gd`

---

## 11. Faction Trait System

Each AI faction is assigned 3 random traits from a pool of 10 at game start. Traits are Godot `Resource` instances with float/bool modifiers read by AIDirector and TurnManager. The player faction has no traits.

| Trait | Key modifiers |
|---|---|
| Aggressive | `war_declaration_bias +0.4` |
| Expansionist | `expansion_priority true`, `war_declaration_bias +0.1` |
| Builder | `build_priority true` |
| Trader | `trade_active true`, `peace_bias +0.3` |
| Diplomatic | `war_declaration_bias -0.2`, `peace_bias +0.4` |
| Isolationist | `war_declaration_bias -0.3` |
| Militarist | `recruit_bonus +2`, `war_declaration_bias +0.2` |
| Opportunist | `war_declaration_bias +0.15` (only vs. weaker factions) |
| Pacifist | `war_declaration_bias -0.4`, `peace_bias +0.5` |
| Zealot | `war_declaration_bias +0.5` |

- Barbarian faction always gets Aggressive + Militarist + Zealot (fixed, not random).
- `recruit_bonus` is added to `CommanderData.RECRUIT_CAP` for the MILITARIST trait.
- **Script:** `scripts/resources/faction_trait.gd`
- **Instances:** `scripts/resources/traits/trait_*.tres` (10 files)

---

## 12. Event Log

A scrolling feed in the bottom-left of the Map HUD that records significant world events during the AI turns. Maximum 12 entries; oldest entry is removed when the limit is exceeded.

**Logged events:**

| Event | Color |
|---|---|
| War declared between two factions | Red |
| Peace made between two factions | Green |
| Province capital captured (seed hex only) | Faction color |
| New round started | Grey (separator) |
| Barbarian commander spawned | Orange |
| AI faction places a building | Blue |

- Player actions are not logged (the player sees them directly).
- Only hex captures on province seed hexes are logged (avoids noise from individual tile flips).
- **Script:** `scenes/map/map_hud.gd` (`_build_event_log`, `_log`, event handler methods)
