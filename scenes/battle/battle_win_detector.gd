extends Node

# Polls every 2 seconds.
# Win:  all living enemies dead AND no enemy-owned zones remain.
# Lose: handled by player._on_died() when player tickets run out.

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
	print("[BWD] _check_conditions fired")

	# Enemy count — only non-player-faction units count as enemies
	var all_enemies := get_tree().get_nodes_in_group("enemy")
	var living_enemies := 0
	for e in all_enemies:
		var dead = e.get("is_dead")
		var faction = e.get("faction")
		var is_hostile: bool = faction == null or not faction.get("is_player_faction")
		print("[BWD]   enemy %s  is_dead=%s  faction=%s  hostile=%s" % [e.name, str(dead), str(faction), str(is_hostile)])
		if not dead and is_hostile:
			living_enemies += 1
	print("[BWD] living_enemies=%d / total=%d" % [living_enemies, all_enemies.size()])

	# Zone count
	var all_zones := get_tree().get_nodes_in_group("battle_zone")
	print("[BWD] battle_zone group has %d zones" % all_zones.size())
	var enemy_zones := 0
	for z in all_zones:
		var faction = z.get("owner_faction")
		var faction_name = faction.faction_name if faction != null else "null"
		var is_player = faction.get("is_player_faction") if faction != null else "n/a"
		print("[BWD]   zone %s  owner=%s  is_player=%s" % [z.name, faction_name, str(is_player)])
		if faction != null and not faction.get("is_player_faction"):
			enemy_zones += 1
	print("[BWD] enemy_zones=%d  living_enemies=%d" % [enemy_zones, living_enemies])

	if living_enemies == 0 and enemy_zones == 0 and not _finished:
		print("[BWD] WIN condition met — calling finish_battle(true)")
		_finished = true
		BattleContext.finish_battle(true)
