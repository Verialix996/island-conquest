extends Node

const ATTACK_STRENGTH := 5

var _last_move_target: Vector2i = Vector2i(-1, -1)

func take_turn(faction: FactionData) -> void:
	_consider_trade_and_alliance(faction)
	_consider_coalition(faction)
	_consider_betrayal(faction)
	_consider_peace(faction)
	_consider_war_declarations(faction)
	_consider_building(faction)

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
	if DiplomacyManager.is_vassal(faction):
		return
	# PACIFIST never declares war
	if faction.has_trait(FactionTrait.TraitType.PACIFIST):
		return

	var base_chance := 0.30
	for trait_item in faction.traits:
		base_chance += (trait_item as FactionTrait).war_declaration_bias
	base_chance = clamp(base_chance, 0.0, 1.0)

	var faction_province_count: int = 0
	for p: ProvinceData in ProvinceGrid.provinces:
		if p.owner_faction == faction:
			faction_province_count += 1

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
		if DiplomacyManager.are_at_war(faction, neighbor_faction):
			continue
		# OPPORTUNIST only targets factions with fewer provinces than themselves
		if faction.has_trait(FactionTrait.TraitType.OPPORTUNIST):
			var target_count: int = 0
			for p: ProvinceData in ProvinceGrid.provinces:
				if p.owner_faction == neighbor_faction:
					target_count += 1
			if target_count >= faction_province_count:
				continue
		if randf() < base_chance:
			DiplomacyManager.declare_war(faction, neighbor_faction)

func _consider_peace(faction: FactionData) -> void:
	if faction == TurnManager.FACTION_BARBARIAN:
		return
	var peace_bias := 0.0
	for trait_item in faction.traits:
		peace_bias += (trait_item as FactionTrait).peace_bias
	if peace_bias <= 0.0:
		return
	for other in TurnManager.get_all_factions():
		if other == faction:
			continue
		if DiplomacyManager.are_at_war(faction, other) and randf() < peace_bias:
			if other == TurnManager.FACTION_PLAYER:
				DiplomacyManager.send_proposal(faction, other, DiplomacyManager.ProposalType.CEASEFIRE)
			else:
				DiplomacyManager.offer_peace(faction, other)

func _consider_trade_and_alliance(faction: FactionData) -> void:
	if faction == TurnManager.FACTION_BARBARIAN or DiplomacyManager.is_vassal(faction):
		return
	var trade_chance := 0.08
	var alliance_chance := 0.04
	if faction.has_trait(FactionTrait.TraitType.TRADER):
		trade_chance += 0.22
	if faction.has_trait(FactionTrait.TraitType.DIPLOMATIC):
		trade_chance += 0.12
		alliance_chance += 0.20
	if faction.has_trait(FactionTrait.TraitType.ISOLATIONIST):
		trade_chance -= 0.05
		alliance_chance -= 0.03
	if faction.has_trait(FactionTrait.TraitType.AGGRESSIVE) or faction.has_trait(FactionTrait.TraitType.ZEALOT):
		alliance_chance -= 0.03
	trade_chance = clamp(trade_chance, 0.0, 0.6)
	alliance_chance = clamp(alliance_chance, 0.0, 0.5)

	for other: FactionData in TurnManager.get_all_factions():
		if other == faction or other == TurnManager.FACTION_BARBARIAN or DiplomacyManager.is_vassal(other):
			continue
		var relation: int = DiplomacyManager.get_relation(faction, other)
		if relation == DiplomacyManager.Relation.PEACE and randf() < trade_chance:
			if other == TurnManager.FACTION_PLAYER:
				DiplomacyManager.send_proposal(faction, other, DiplomacyManager.ProposalType.TRADE_PACT)
			else:
				DiplomacyManager.propose_trade_pact(faction, other)
		elif relation == DiplomacyManager.Relation.TRADE_PACT and randf() < alliance_chance:
			if other == TurnManager.FACTION_PLAYER:
				DiplomacyManager.send_proposal(faction, other, DiplomacyManager.ProposalType.ALLIANCE)
			else:
				DiplomacyManager.propose_alliance(faction, other)

func _consider_coalition(faction: FactionData) -> void:
	if faction == TurnManager.FACTION_BARBARIAN or DiplomacyManager.is_vassal(faction):
		return
	var leader: FactionData = _find_province_leader()
	if leader == null or leader == faction or leader == TurnManager.FACTION_BARBARIAN:
		return
	var leader_count: int = _count_seed_provinces(leader)
	if leader_count < ceili(float(ProvinceGrid.NUM_PROVINCES) * 0.4):
		return
	if DiplomacyManager.are_at_war(faction, leader):
		return
	var chance := 0.18
	if faction.has_trait(FactionTrait.TraitType.DIPLOMATIC):
		chance += 0.12
	if faction.has_trait(FactionTrait.TraitType.OPPORTUNIST):
		chance += 0.10
	if faction.has_trait(FactionTrait.TraitType.PACIFIST):
		chance -= 0.12
	if randf() < clamp(chance, 0.0, 0.5):
		DiplomacyManager.declare_war(faction, leader)
		for other: FactionData in TurnManager.get_all_factions():
			if other == faction or other == leader or other == TurnManager.FACTION_BARBARIAN:
				continue
			if DiplomacyManager.are_at_war(other, leader) and DiplomacyManager.get_relation(faction, other) == DiplomacyManager.Relation.PEACE:
				DiplomacyManager.propose_alliance(faction, other)
				break

func _consider_betrayal(faction: FactionData) -> void:
	if faction == TurnManager.FACTION_BARBARIAN or DiplomacyManager.is_vassal(faction):
		return
	var chance := 0.0
	if faction.has_trait(FactionTrait.TraitType.AGGRESSIVE):
		chance += 0.08
	if faction.has_trait(FactionTrait.TraitType.OPPORTUNIST):
		chance += 0.10
	if faction.has_trait(FactionTrait.TraitType.ZEALOT):
		chance += 0.06
	if faction.has_trait(FactionTrait.TraitType.DIPLOMATIC) or faction.has_trait(FactionTrait.TraitType.PACIFIST):
		chance -= 0.08
	if chance <= 0.0:
		return
	for other: FactionData in TurnManager.get_all_factions():
		if other == faction or other == TurnManager.FACTION_BARBARIAN:
			continue
		var relation: int = DiplomacyManager.get_relation(faction, other)
		if relation != DiplomacyManager.Relation.ALLIANCE and relation != DiplomacyManager.Relation.TRADE_PACT:
			continue
		if faction.has_trait(FactionTrait.TraitType.OPPORTUNIST) and _count_seed_provinces(other) >= _count_seed_provinces(faction):
			continue
		if randf() < clamp(chance, 0.0, 0.35):
			DiplomacyManager.declare_war(faction, other)
			return

func _consider_building(faction: FactionData) -> void:
	if not faction.has_trait(FactionTrait.TraitType.BUILDER) and \
	   not faction.has_trait(FactionTrait.TraitType.MILITARIST):
		return

	# Collect owned hexes without a building
	var candidates: Array[Vector2i] = []
	for coord: Vector2i in ProvinceGrid.hex_ownership:
		if ProvinceGrid.get_hex_owner(coord) != faction:
			continue
		if ProvinceGrid.get_hex_building(coord) != null:
			continue
		candidates.append(coord)

	if candidates.is_empty():
		return

	# Pick a building type by trait
	var prefer_barracks: bool = faction.has_trait(FactionTrait.TraitType.MILITARIST)
	var building_type: StringName = &"barracks" if prefer_barracks else &"barracks"
	var cost: Dictionary = { "manpower": 20 }

	if not TurnManager.can_afford(faction, cost):
		return

	var target_coord: Vector2i = candidates[randi() % candidates.size()]
	TurnManager.spend_resources(faction, cost)

	var b := BuildingData.new()
	b.building_type        = building_type
	b.building_name        = "Barracks"
	b.description          = "+3 garrison"
	b.cost                 = cost
	b.extra_defender_units = 3
	b.defense_bonus        = 0
	b.income_bonus         = 0
	ProvinceGrid.place_building(target_coord, b)
	EventBus.province_building_added.emit(ProvinceGrid.get_province_for_hex(target_coord))

# ─── Action selection ─────────────────────────────────────────────────────────

# Returns a string tag so the caller knows whether to reset the cached target.
func _take_best_action(faction: FactionData, commander: CommanderData,
		move_target: Vector2i) -> String:
	var pos := commander.current_hex

	var prefer_expand: bool = faction.has_trait(FactionTrait.TraitType.EXPANSIONIST)

	# Priority 1 (or 2 for EXPANSIONIST) — attack an adjacent enemy hex (costs 2 AP)
	if not prefer_expand and TurnManager.ap_remaining >= 2:
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(pos):
			var owner: FactionData = ProvinceGrid.get_hex_owner(nb)
			if owner == null or owner == faction:
				continue
			if not DiplomacyManager.are_at_war(faction, owner):
				continue
			_do_attack(faction, commander, nb, owner)
			return "attacked"

	# Priority 1 for EXPANSIONIST, priority 2 otherwise — claim adjacent neutral (costs 1 AP)
	if TurnManager.ap_remaining >= 1:
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(pos):
			if ProvinceGrid.get_hex_owner(nb) == null:
				_do_claim(faction, commander, nb)
				return "claimed"

	# EXPANSIONIST attack pass (after claiming neutrals)
	if prefer_expand and TurnManager.ap_remaining >= 2:
		for nb: Vector2i in ProvinceGrid.get_hex_neighbors(pos):
			var owner: FactionData = ProvinceGrid.get_hex_owner(nb)
			if owner == null or owner == faction:
				continue
			if not DiplomacyManager.are_at_war(faction, owner):
				continue
			_do_attack(faction, commander, nb, owner)
			return "attacked"

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
		var province: ProvinceData = ProvinceGrid.get_province_for_hex(target)
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
	var province: ProvinceData = ProvinceGrid.get_province_for_hex(target)
	var garrison: int = ProvinceGrid.get_province_garrison(province) if province else 3
	if ATTACK_STRENGTH > garrison:
		var old_owner: FactionData = ProvinceGrid.get_hex_owner(target)
		ProvinceGrid.capture_hex(target, faction)
		EventBus.hex_captured.emit(target, faction, old_owner)
		# Destroy the defending commander if they were standing on this tile
		var defender_cmd: CommanderData = TurnManager.get_commander_at(target)
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

func _find_province_leader() -> FactionData:
	var best_faction: FactionData = null
	var best_count := 0
	for faction: FactionData in TurnManager.get_all_factions():
		if faction == TurnManager.FACTION_BARBARIAN:
			continue
		var count: int = _count_seed_provinces(faction)
		if count > best_count:
			best_count = count
			best_faction = faction
	return best_faction

func _count_seed_provinces(faction: FactionData) -> int:
	var count := 0
	for p: ProvinceData in ProvinceGrid.provinces:
		if ProvinceGrid.get_hex_owner(p.seed_hex) == faction:
			count += 1
	return count
