extends Node

# ─── Faction references ────────────────────────────────────────────────────────
const FACTION_PLAYER    = preload("res://scripts/resources/faction_player.tres")
const FACTION_RED       = preload("res://scripts/resources/faction_red.tres")
const FACTION_BLUE      = preload("res://scripts/resources/faction_blue.tres")
const FACTION_ORANGE    = preload("res://scripts/resources/faction_orange.tres")
const FACTION_BARBARIAN = preload("res://scripts/resources/faction_barbarian.tres")

# ─── State ─────────────────────────────────────────────────────────────────────
var current_round: int = 1
var ap_remaining:  int = 3
var last_roll:     int = 0

var _turn_order: Array[FactionData] = []
var _turn_index:  int = 0

# Commander tokens persist across battle scene changes so positions are remembered
var commanders: Array = []   # Array[CommanderData]

# Pending AI-vs-player battles; resolved at the start of the player's next turn
var pending_defense: Array = []          # Array of {province, attacker, hex}
var pending_defense_battle: Dictionary = {}  # The one currently being resolved (choice dialog)

# ─── Public API ────────────────────────────────────────────────────────────────
func reset_state() -> void:
	current_round = 1
	ap_remaining  = 3
	last_roll     = 0
	_turn_order.clear()
	_turn_index = 0
	commanders.clear()
	pending_defense.clear()
	pending_defense_battle = {}
	# Give all factions a small starting stockpile
	var start := { "manpower": 10, "oil": 5, "steel": 5, "trade": 5 }
	for f in [FACTION_PLAYER, FACTION_RED, FACTION_BLUE, FACTION_ORANGE, FACTION_BARBARIAN]:
		(f as FactionData).resources = start.duplicate()

func start_game() -> void:
	_turn_order = [FACTION_PLAYER, FACTION_RED, FACTION_BLUE, FACTION_ORANGE, FACTION_BARBARIAN]
	_turn_index = 0
	_create_commanders()
	_begin_turn()

func _create_commanders() -> void:
	commanders.clear()
	for faction in [FACTION_PLAYER, FACTION_RED, FACTION_BLUE, FACTION_ORANGE]:
		if faction.owned_provinces.is_empty():
			continue
		var province: ProvinceData = faction.owned_provinces[0]
		var commander := CommanderData.new()
		commander.commander_name = faction.faction_name
		commander.owner_faction  = faction
		commander.current_hex    = province.seed_hex
		commanders.append(commander)
	# Barbarians start with no commanders — they spawn via roll-of-7

func end_player_turn() -> void:
	if not is_player_turn():
		return
	for p: ProvinceData in ProvinceGrid.provinces:
		if p.is_contested and p.attacker_faction == FACTION_PLAYER:
			EventBus.battle_choice_needed.emit(p, false, FACTION_PLAYER)
			return
	_finish_player_turn()

func resume_after_battle() -> void:
	_finish_player_turn()

# Called when returning from a defense battle (player was defending)
func resume_after_defense_battle() -> void:
	if not pending_defense.is_empty():
		_trigger_next_defense()
	# Player still has their AP from when the turn started — no reset needed

func _finish_player_turn() -> void:
	EventBus.turn_ended.emit(current_faction())
	_next_turn()

func refresh_hud() -> void:
	EventBus.turn_started.emit(current_faction(), current_round)
	EventBus.resources_changed.emit(FACTION_PLAYER)
	EventBus.ap_changed.emit(ap_remaining)

func can_afford(faction: FactionData, cost: Dictionary) -> bool:
	for key in cost:
		if faction.resources.get(key, 0) < cost[key]:
			return false
	return true

func spend_resources(faction: FactionData, cost: Dictionary) -> void:
	for key in cost:
		faction.resources[key] = faction.resources.get(key, 0) - cost[key]
	EventBus.resources_changed.emit(faction)

func spend_ap(amount: int) -> bool:
	if ap_remaining < amount:
		return false
	ap_remaining -= amount
	EventBus.ap_changed.emit(ap_remaining)
	return true

func is_player_turn() -> bool:
	return not _turn_order.is_empty() and current_faction() == FACTION_PLAYER

func current_faction() -> FactionData:
	return _turn_order[_turn_index] if not _turn_order.is_empty() else null

# ─── Internal ──────────────────────────────────────────────────────────────────
func _next_turn() -> void:
	_turn_index = (_turn_index + 1) % _turn_order.size()
	if _turn_index == 0:
		current_round += 1
		EventBus.round_ended.emit(current_round)
	_begin_turn()

func _begin_turn() -> void:
	var faction := current_faction()
	_respawn_commanders_for(faction)
	# Reset attack lock so commanders can act again this turn
	for c in commanders:
		var cd := c as CommanderData
		if cd and cd.owner_faction == faction:
			cd.has_attacked = false
	ap_remaining = 3

	var roll := randi_range(1, 6) + randi_range(1, 6)
	last_roll  = roll

	var affected: Array = []
	for p: ProvinceData in ProvinceGrid.provinces:
		if p.dice_number == roll:
			for coord: Vector2i in p.hex_tiles:
				var tile_owner: FactionData = ProvinceGrid.get_hex_owner(coord)
				if tile_owner == null:
					continue
				var terrain: ProvinceData.TerrainType = ProvinceGrid.hex_terrain.get(coord, ProvinceData.TerrainType.PLAINS)
				var res_key := _terrain_to_resource_key(terrain)
				var amount := 1
				var building: BuildingData = ProvinceGrid.get_hex_building(coord)
				if building != null:
					amount += building.income_bonus
				if coord == p.seed_hex:
					amount *= 2
				tile_owner.resources[res_key] = tile_owner.resources.get(res_key, 0) + amount
				if not affected.has(tile_owner):
					affected.append(tile_owner)
	for f: FactionData in affected:
		EventBus.resources_changed.emit(f)

	# Roll of 7 is a global map event — no production, but spawns a Barbarian
	if roll == 7:
		_spawn_barbarian_event()

	EventBus.dice_rolled.emit(roll)
	EventBus.turn_started.emit(faction, current_round)

	if not is_player_turn():
		AIDirector.take_turn(faction)
		EventBus.turn_ended.emit(faction)
		_next_turn()
	else:
		# Before the player acts, trigger any pending defense battles
		if not pending_defense.is_empty():
			_trigger_next_defense()

func _trigger_next_defense() -> void:
	pending_defense_battle = pending_defense.pop_front()
	EventBus.battle_choice_needed.emit(pending_defense_battle.province, true, pending_defense_battle.attacker)

# ─── Barbarian event ──────────────────────────────────────────────────────────
func _spawn_barbarian_event() -> void:
	# Cap at 3 Barbarian commanders total
	var barb_count := 0
	for c in commanders:
		var cd := c as CommanderData
		if cd and cd.owner_faction == FACTION_BARBARIAN:
			barb_count += 1
	if barb_count >= 3:
		return

	# Pick a random unowned province
	var unowned: Array[ProvinceData] = []
	for p: ProvinceData in ProvinceGrid.provinces:
		if ProvinceGrid.get_hex_owner(p.seed_hex) == null:
			unowned.append(p)
	if unowned.is_empty():
		return

	var province: ProvinceData = unowned[randi() % unowned.size()]
	ProvinceGrid.capture_hex(province.seed_hex, FACTION_BARBARIAN)
	EventBus.hex_captured.emit(province.seed_hex, FACTION_BARBARIAN, null)

	var commander := CommanderData.new()
	commander.commander_name = "Barbarians" if barb_count == 0 else "Barbarians " + str(barb_count + 1)
	commander.owner_faction  = FACTION_BARBARIAN
	commander.current_hex    = province.seed_hex
	commanders.append(commander)
	EventBus.commander_spawned.emit(commander)

func get_commander_at(hex: Vector2i) -> CommanderData:
	for c in commanders:
		var cd := c as CommanderData
		if cd and cd.current_hex == hex:
			return cd
	return null

func destroy_commander(commander: CommanderData) -> void:
	commanders.erase(commander)
	EventBus.commander_destroyed.emit(commander)

func _find_commander(faction: FactionData) -> CommanderData:
	for c in commanders:
		var cd := c as CommanderData
		if cd and cd.owner_faction == faction:
			return cd
	return null

# Respawn a commander for any faction that has territory but no commanders left.
# Called at the start of every turn so the respawn lands on the faction's next turn.
func _respawn_commanders_for(faction: FactionData) -> void:
	for c in commanders:
		var cd := c as CommanderData
		if cd and cd.owner_faction == faction:
			return   # still has at least one commander
	# Spawn at the seed hex (capital) of any province this faction owns
	for p: ProvinceData in ProvinceGrid.provinces:
		if p.owner_faction == faction:
			var commander := CommanderData.new()
			commander.commander_name = faction.faction_name
			commander.owner_faction  = faction
			commander.current_hex    = p.seed_hex
			commanders.append(commander)
			EventBus.commander_spawned.emit(commander)
			return

func _terrain_to_resource_key(terrain: ProvinceData.TerrainType) -> String:
	match terrain:
		ProvinceData.TerrainType.MOUNTAINS: return "steel"
		ProvinceData.TerrainType.DESERT:    return "oil"
		ProvinceData.TerrainType.URBAN:     return "trade"
		_:                                  return "manpower"
