# Island Conquest — Game Systems Reference

Current state of every implemented system. Updated as of Milestone 7.

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

**Post-battle (map phase):**
- Win: attacker captures the contested hex; defender's commander (if any) is destroyed and respawns next turn.
- Lose: defender holds the hex; attacker's commander is destroyed.

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
- On battle loss: commander is destroyed. Respawn at seed hex next turn.
- **Script:** `scenes/map/commander_token.gd`, **Data:** `scripts/resources/commander_data.gd`

### Building System

One building slot per hex. Buildings cost resources and provide bonuses.

| Building | Effect |
|---|---|
| Barracks | +garrison strength in battle, +income bonus |
| Wall | +defensive cover in battle |
| Turret | +auto-turret in battle scene |
| Energy Plant | +income bonus |

- **Script:** `scenes/map/province_info_panel.gd`, **Data:** `scripts/resources/building_data.gd`

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

**Decision logic per turn:**
1. BFS from owned hexes to find the nearest unclaimed or enemy hex.
2. Move commander toward target.
3. Declare attack if adjacent to a valid target and AP allows.
4. Cache BFS paths to avoid re-computing every frame (cache invalidated on map change).

**Barbarian faction:**
- Created when a 7 is rolled (Catan-style map event).
- Always at war with everyone.
- Expands into neutral hexes only (never initiates war on player or AI unless adjacent).

- **Autoload:** `scripts/autoloads/ai_director.gd`

---

## 8. World Generator (Battle Scene)

Procedurally builds the battle scene at runtime.

- Places `cover_count` (default 30) randomly oriented box obstacles.
- Generates and places `zone_count` (default 6) zones with minimum spacing.
- Splits zones between player and enemy faction based on proximity to player start.
- Spawns initial garrison units for the enemy faction near their zones.
- Moves the player character to a friendly zone.
- Bakes the navigation mesh with `PARSED_GEOMETRY_BOTH`, agent radius 1.0.

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

Faction files: `faction_player.tres`, `faction_red.tres`, `faction_blue.tres`, `faction_orange.tres`, `faction_barbarian.tres`
- **Script:** `scripts/resources/faction_data.gd`
