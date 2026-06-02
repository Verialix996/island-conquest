extends Node

# Polls every 2 seconds.
# Win: all living factions at war with the player are dead AND no hostile zones remain.
# Lose: handled by player._on_died() when player tickets run out.

const FACTION_PLAYER = preload("res://scripts/resources/faction_player.tres")
const DEBUG_LOGS := false

var _timer: float = 2.0
var _finished: bool = false

func _process(delta: float) -> void:
	if _finished:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 2.0
	_check_conditions()

func _check_conditions() -> void:
	_debug_log("_check_conditions fired")

	var living_enemies: int = 0
	for faction in TurnManager.get_all_factions():
		var hostile_faction := faction as FactionData
		if not _is_hostile_to_player(hostile_faction):
			continue
		var group_name := _faction_group_name(hostile_faction)
		for unit in get_tree().get_nodes_in_group(group_name):
			if _is_living_combat_unit(unit):
				living_enemies += 1
				_debug_log("  hostile unit %s faction=%s" % [unit.name, hostile_faction.faction_name])
	_debug_log("living hostile units=%d" % living_enemies)

	var enemy_zones: int = 0
	var all_zones: Array[Node] = get_tree().get_nodes_in_group("battle_zone")
	_debug_log("battle_zone group has %d zones" % all_zones.size())
	for z in all_zones:
		var zone_owner: FactionData = z.get("owner_faction")
		var faction_name = zone_owner.faction_name if zone_owner != null else "null"
		var hostile = _is_hostile_to_player(zone_owner)
		_debug_log("  zone %s owner=%s hostile=%s" % [z.name, faction_name, str(hostile)])
		if hostile:
			enemy_zones += 1
	_debug_log("hostile_zones=%d living_hostiles=%d" % [enemy_zones, living_enemies])

	if living_enemies == 0 and enemy_zones == 0 and not _finished:
		_debug_log("WIN condition met — calling finish_battle(true)")
		_finished = true
		BattleContext.finish_battle(true)

func _debug_log(message: String) -> void:
	if DEBUG_LOGS:
		print("[BWD] %s" % message)

func _is_living_combat_unit(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not unit.has_method("take_damage"):
		return false
	if "is_dead" in unit and unit.is_dead:
		return false
	return true

func _is_hostile_to_player(faction: FactionData) -> bool:
	return faction != null and DiplomacyManager.are_at_war(FACTION_PLAYER, faction)

func _faction_group_name(faction_data: FactionData) -> String:
	if faction_data == null:
		return "faction_unknown"
	return "faction_" + faction_data.faction_name.to_lower().replace(" ", "_")
