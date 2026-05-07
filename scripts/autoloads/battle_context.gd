extends Node

const MAP_SCENE    := "res://scenes/map/province_map.tscn"
const BATTLE_SCENE := "res://scenes/world/main_world.tscn"

var target_hex:            Vector2i     = Vector2i(-1, -1)
var pending_province:      ProvinceData = null
var attacker_faction:      FactionData  = null
var returning_from_battle: bool = false
var is_defense:            bool = false   # true = player is defending, not attacking
var was_defense:           bool = false   # survives finish_battle so province_map can branch

func is_battle_mode() -> bool:
	return pending_province != null

# Player attacks an enemy hex
func start_battle(province: ProvinceData, attacker: FactionData) -> void:
	pending_province = province
	attacker_faction = attacker
	is_defense       = false
	get_tree().change_scene_to_file(BATTLE_SCENE)

# AI attacks a player hex — player must defend
func start_defense_battle(province: ProvinceData, attacker: FactionData, hex: Vector2i) -> void:
	pending_province = province
	attacker_faction = attacker
	target_hex       = hex
	is_defense       = true
	get_tree().change_scene_to_file(BATTLE_SCENE)

func finish_battle(player_won: bool) -> void:
	if is_defense:
		if not player_won and target_hex != Vector2i(-1, -1):
			# AI wins: capture the hex and destroy the player's commander if they were on it
			ProvinceGrid.capture_hex(target_hex, attacker_faction)
			var player_cmd := TurnManager.get_commander_at(target_hex)
			if player_cmd != null:
				TurnManager.destroy_commander(player_cmd)
		else:
			# Player wins defense: destroy the AI attacker's commander
			var ai_cmd := TurnManager._find_commander(attacker_faction)
			if ai_cmd != null:
				TurnManager.destroy_commander(ai_cmd)
	else:
		if player_won and target_hex != Vector2i(-1, -1):
			# Player wins offense: capture the hex and destroy any defender commander on it
			ProvinceGrid.capture_hex(target_hex, attacker_faction)
			var defender_cmd := TurnManager.get_commander_at(target_hex)
			if defender_cmd != null:
				TurnManager.destroy_commander(defender_cmd)
		else:
			# Player loses offense: destroy the player's own commander
			var player_cmd := TurnManager._find_commander(TurnManager.FACTION_PLAYER)
			if player_cmd != null:
				TurnManager.destroy_commander(player_cmd)

	if pending_province != null:
		pending_province.is_contested     = false
		pending_province.attacker_faction = null

	was_defense           = is_defense
	target_hex            = Vector2i(-1, -1)
	pending_province      = null
	attacker_faction      = null
	is_defense            = false
	returning_from_battle = true
	get_tree().change_scene_to_file(MAP_SCENE)
