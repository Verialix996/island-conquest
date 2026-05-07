extends Node

const ATTACK_STRENGTH := 5

var _last_move_target: Vector2i = Vector2i(-1, -1)

func take_turn(faction: FactionData) -> void:
	_consider_war_declarations(faction)

	for commander: CommanderData in _get_all_commanders(faction):
		_run_commander(faction, commander)

# Runs one commander's full AP budget for this turn.
# move_target is cached so the commander doesn't oscillate between tiles.
func _run_commander(faction: FactionData, commander: CommanderData) -> void:
	var move_target := Vector2i(-1, -1)
	while TurnManager.ap_remaining > 0:
		var result := _take_best_action(faction, commander, move_target)
		if result == "attacked" or result == "claimed":
			move_target = Vector2i(-1, -1)   # territory changed — find a fresh target
		elif result == "moved":
			# Update the cached target in case _take_best_action recalculated it
			move_target = _last_move_target
		else:
			break   # "done" or "no_target"

# ─── Diplomacy ────────────────────────────────────────────────────────────────

func _consider_war_declarations(faction: FactionData) -> void:
	var candidates: Dictionary = {}
	for coord: Vector2i in ProvinceGrid.hex_ownership:
		if ProvinceGrid.get_hex_owner(coord) != faction:
			continue
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(coord):
			var owner: FactionData = ProvinceGrid.get_hex_owner(nb)
			if owner == null or owner == faction or owner == TurnManager.FACTION_BARBARIAN:
				continue
			candidates[owner] = true

	for neighbor_faction: FactionData in candidates:
		if not DiplomacyManager.are_at_war(faction, neighbor_faction):
			if randf() < 0.30:
				DiplomacyManager.declare_war(faction, neighbor_faction)

# ─── Action selection ─────────────────────────────────────────────────────────

# Returns a string tag so the caller knows whether to reset the cached target.
func _take_best_action(faction: FactionData, commander: CommanderData,
		move_target: Vector2i) -> String:
	var pos := commander.current_hex

	# Priority 1 — attack an adjacent enemy hex (costs 2 AP)
	if TurnManager.ap_remaining >= 2:
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(pos):
			var owner: FactionData = ProvinceGrid.get_hex_owner(nb)
			if owner == null or owner == faction:
				continue
			if not DiplomacyManager.are_at_war(faction, owner):
				continue
			_do_attack(faction, commander, nb, owner)
			return "attacked"

	# Priority 2 — claim an adjacent neutral hex (costs 1 AP)
	if TurnManager.ap_remaining >= 1:
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(pos):
			if ProvinceGrid.get_hex_owner(nb) == null:
				_do_claim(faction, commander, nb)
				return "claimed"

	# Priority 3 — step toward the cached target; recalculate only when it runs out
	if TurnManager.ap_remaining >= 1:
		var target := move_target
		if target == Vector2i(-1, -1) or target == pos:
			target = _find_nearest_target(faction, pos)
		if target == Vector2i(-1, -1):
			return "no_target"
		var next_step := _step_toward(pos, target)
		if next_step == Vector2i(-1, -1) or next_step == pos:
			return "no_target"
		_last_move_target = target   # let caller re-use this target next AP
		_do_move(commander, next_step)
		return "moved"

	return "done"

# ─── Actions ──────────────────────────────────────────────────────────────────

func _do_attack(faction: FactionData, commander: CommanderData, target: Vector2i, defender_faction: FactionData) -> void:
	TurnManager.spend_ap(2)

	# Attacking a player tile queues a defense battle instead of auto-resolving
	if defender_faction == TurnManager.FACTION_PLAYER:
		var province := ProvinceGrid.get_province_for_hex(target)
		if province != null:
			province.is_contested     = true
			province.attacker_faction = faction
			TurnManager.pending_defense.append({
				"province": province,
				"attacker": faction,
				"hex":      target
			})
		return

	# Auto-resolve vs non-player defenders
	var province := ProvinceGrid.get_province_for_hex(target)
	var garrison := ProvinceGrid.get_province_garrison(province) if province else 3
	if ATTACK_STRENGTH > garrison:
		var old_owner: FactionData = ProvinceGrid.get_hex_owner(target)
		ProvinceGrid.capture_hex(target, faction)
		EventBus.hex_captured.emit(target, faction, old_owner)
		# Destroy the defending commander if they were standing on this tile
		var defender_cmd := TurnManager.get_commander_at(target)
		if defender_cmd != null:
			TurnManager.destroy_commander(defender_cmd)
		# Move attacker onto the captured tile — no extra AP cost for the advance
		commander.current_hex = target
		EventBus.commander_moved.emit(commander, target)

func _do_claim(faction: FactionData, commander: CommanderData, target: Vector2i) -> void:
	TurnManager.spend_ap(1)
	var old_owner: FactionData = ProvinceGrid.get_hex_owner(target)
	ProvinceGrid.capture_hex(target, faction)
	EventBus.hex_captured.emit(target, faction, old_owner)
	commander.current_hex = target
	EventBus.commander_moved.emit(commander, target)

func _do_move(commander: CommanderData, target: Vector2i) -> void:
	TurnManager.spend_ap(1)
	commander.current_hex = target
	EventBus.commander_moved.emit(commander, target)

# ─── Pathfinding ──────────────────────────────────────────────────────────────

func _find_nearest_target(faction: FactionData, from: Vector2i) -> Vector2i:
	var visited := {from: true}
	var queue   := [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur != from:
			var owner: FactionData = ProvinceGrid.get_hex_owner(cur)
			if owner == null:
				return cur
			if owner != faction and DiplomacyManager.are_at_war(faction, owner):
				return cur
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(cur):
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	return Vector2i(-1, -1)

func _step_toward(from: Vector2i, target: Vector2i) -> Vector2i:
	if from == target:
		return from
	var parent: Dictionary = {from: from}
	var queue := [from]
	var found := false
	while not queue.is_empty() and not found:
		var cur: Vector2i = queue.pop_front()
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(cur):
			if not parent.has(nb):
				parent[nb] = cur
				if nb == target:
					found = true
					break
				queue.append(nb)

	if not found:
		return Vector2i(-1, -1)

	var step := target
	while parent[step] != from:
		step = parent[step]
	return step

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _get_all_commanders(faction: FactionData) -> Array:
	var result := []
	for c in TurnManager.commanders:
		var cd := c as CommanderData
		if cd and cd.owner_faction == faction:
			result.append(cd)
	return result
