extends Node

const MAP_SCENE    := "res://scenes/map/province_map.tscn"
const BATTLE_SCENE := "res://scenes/battle/main_world.tscn"

var target_hex:            Vector2i     = Vector2i(-1, -1)
var pending_province:      ProvinceData = null
var attacker_faction:      FactionData  = null
var returning_from_battle: bool = false
var is_defense:            bool = false   # true = player is defending, not attacking
var was_defense:           bool = false   # survives finish_battle so province_map can branch

# Commander army strength — added to base 10 tickets at battle start
var player_commander_strength: int = 0
var enemy_commander_strength:  int = 0

# Building on the contested hex — read by WorldGenerator to spawn effects
var contested_hex_building: BuildingData = null

func is_battle_mode() -> bool:
	return pending_province != null

func _cache_commander_strengths(hex: Vector2i, enemy_faction: FactionData) -> void:
	player_commander_strength = 0
	enemy_commander_strength  = 0
	for cmd in TurnManager.commanders:
		var cd := cmd as CommanderData
		if cd == null:
			continue
		if cd.owner_faction == TurnManager.FACTION_PLAYER:
			player_commander_strength = cd.strength
		elif cd.owner_faction == enemy_faction and cd.current_hex == hex:
			enemy_commander_strength = cd.strength
	contested_hex_building = ProvinceGrid.get_hex_building(hex)

# Player attacks an enemy hex
func start_battle(province: ProvinceData, attacker: FactionData) -> void:
	pending_province = province
	attacker_faction = attacker
	is_defense       = false
	_cache_commander_strengths(province.seed_hex, province.owner_faction)
	get_tree().change_scene_to_file(BATTLE_SCENE)

# AI attacks a player hex — player must defend
func start_defense_battle(province: ProvinceData, attacker: FactionData, hex: Vector2i) -> void:
	pending_province = province
	attacker_faction = attacker
	target_hex       = hex
	is_defense       = true
	_cache_commander_strengths(hex, attacker_faction)
	get_tree().change_scene_to_file(BATTLE_SCENE)

func finish_battle(player_won: bool) -> void:
	if is_defense:
		if not player_won and target_hex != Vector2i(-1, -1):
			# AI wins defense: capture the hex; player commander retreats to capital
			ProvinceGrid.capture_hex(target_hex, attacker_faction)
			var player_cmd: CommanderData = TurnManager.get_commander_at(target_hex)
			if player_cmd != null:
				TurnManager.defeat_commander(player_cmd)
		else:
			# Player wins defense: AI attacker retreats to their capital
			var ai_cmd: CommanderData = TurnManager._find_commander(attacker_faction)
			if ai_cmd != null:
				TurnManager.defeat_commander(ai_cmd)
	else:
		if player_won and target_hex != Vector2i(-1, -1):
			# Player wins offense: capture the hex; defending commander retreats
			ProvinceGrid.capture_hex(target_hex, attacker_faction)
			var defender_cmd: CommanderData = TurnManager.get_commander_at(target_hex)
			if defender_cmd != null:
				TurnManager.defeat_commander(defender_cmd)
		else:
			# Player loses offense: player commander retreats to capital
			var player_cmd: CommanderData = TurnManager._find_commander(TurnManager.FACTION_PLAYER)
			if player_cmd != null:
				TurnManager.defeat_commander(player_cmd)

	if pending_province != null:
		pending_province.is_contested     = false
		pending_province.attacker_faction = null

	was_defense                   = is_defense
	target_hex                    = Vector2i(-1, -1)
	pending_province              = null
	attacker_faction              = null
	is_defense                    = false
	player_commander_strength     = 0
	enemy_commander_strength      = 0
	contested_hex_building        = null
	returning_from_battle         = true
	get_tree().change_scene_to_file(MAP_SCENE)
