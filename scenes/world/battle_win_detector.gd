extends Node

# Polls every 2 seconds — cheap and avoids per-frame checks.
var _timer: float = 2.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 2.0

	var enemies := get_tree().get_nodes_in_group("enemy")
	var living := 0
	for e in enemies:
		if not e.get("is_dead"):
			living += 1

	if living == 0:
		BattleContext.finish_battle(true)   # attacker wins
