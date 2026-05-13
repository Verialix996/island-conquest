extends Node

enum Relation { PEACE, WAR, ALLIANCE, TRADE_PACT, VASSALAGE }

const FACTION_BARBARIAN = preload("res://scripts/resources/faction_barbarian.tres")

# Canonical key: alphabetically sorted faction names joined by "|"
# so get_relation(A,B) == get_relation(B,A) always.
var _relations: Dictionary = {}
var _overlords: Dictionary = {} # vassal faction_name -> FactionData

# ─── Public API ────────────────────────────────────────────────────────────────
func get_relation(a: FactionData, b: FactionData) -> int:
	if a == null or b == null or a == b:
		return Relation.PEACE
	if is_vassal_of(a, b) or is_vassal_of(b, a):
		return Relation.VASSALAGE
	return _relations.get(_key(a, b), Relation.PEACE)

func are_at_war(a: FactionData, b: FactionData) -> bool:
	if a == null or b == null or a == b:
		return false
	if a == FACTION_BARBARIAN or b == FACTION_BARBARIAN:
		return true   # Barbarians are always at war with everyone
	if is_vassal_of(a, b) or is_vassal_of(b, a):
		return false
	var a_overlord: FactionData = get_overlord(a)
	var b_overlord: FactionData = get_overlord(b)
	if a_overlord != null and b_overlord != null and a_overlord == b_overlord:
		return false
	if a_overlord != null:
		return are_at_war(a_overlord, b)
	if b_overlord != null:
		return are_at_war(a, b_overlord)
	return get_relation(a, b) == Relation.WAR

func declare_war(attacker: FactionData, target: FactionData) -> void:
	if attacker == null or target == null or attacker == target:
		return
	if attacker == FACTION_BARBARIAN or target == FACTION_BARBARIAN:
		return
	if is_vassal(attacker):
		attacker = get_overlord(attacker)
	if is_vassal(target):
		target = get_overlord(target)
	if attacker == null or target == null or attacker == target:
		return
	if get_relation(attacker, target) == Relation.ALLIANCE or get_relation(attacker, target) == Relation.TRADE_PACT:
		EventBus.betrayal_committed.emit(attacker, target)
	set_relation(attacker, target, Relation.WAR)
	EventBus.war_declared.emit(attacker, target)

func offer_peace(initiator: FactionData, target: FactionData) -> void:
	set_relation(initiator, target, Relation.PEACE)
	EventBus.peace_made.emit(initiator, target)

func propose_alliance(initiator: FactionData, target: FactionData) -> void:
	set_relation(initiator, target, Relation.ALLIANCE)

func propose_trade_pact(initiator: FactionData, target: FactionData) -> void:
	set_relation(initiator, target, Relation.TRADE_PACT)

func set_relation(a: FactionData, b: FactionData, relation: int) -> void:
	if a == null or b == null or a == b:
		return
	if a == FACTION_BARBARIAN or b == FACTION_BARBARIAN:
		return
	if relation == Relation.VASSALAGE:
		start_vassalage(a, b)
		return
	if is_vassal_of(a, b) or is_vassal_of(b, a):
		return
	_relations[_key(a, b)] = relation
	EventBus.treaty_changed.emit(a, b, relation)

func break_treaty(a: FactionData, b: FactionData) -> void:
	if is_vassal_of(a, b):
		_overlords.erase(a.faction_name)
	elif is_vassal_of(b, a):
		_overlords.erase(b.faction_name)
	set_relation(a, b, Relation.PEACE)

func has_trade_pact(a: FactionData, b: FactionData) -> bool:
	return get_relation(a, b) == Relation.TRADE_PACT

func is_vassal(faction: FactionData) -> bool:
	return get_overlord(faction) != null

func is_vassal_of(vassal: FactionData, overlord: FactionData) -> bool:
	return vassal != null and overlord != null and get_overlord(vassal) == overlord

func get_overlord(faction: FactionData) -> FactionData:
	if faction == null:
		return null
	return _overlords.get(faction.faction_name, null)

func get_subjects(overlord: FactionData) -> Array:
	var result := []
	for faction in TurnManager.get_all_factions():
		if get_overlord(faction) == overlord:
			result.append(faction)
	return result

func start_vassalage(vassal: FactionData, overlord: FactionData) -> void:
	if vassal == null or overlord == null or vassal == overlord:
		return
	if vassal == FACTION_BARBARIAN or overlord == FACTION_BARBARIAN:
		return
	clear_faction_treaties(vassal)
	_overlords[vassal.faction_name] = overlord
	_relations[_key(vassal, overlord)] = Relation.VASSALAGE
	EventBus.vassalage_started.emit(vassal, overlord)
	EventBus.treaty_changed.emit(vassal, overlord, Relation.VASSALAGE)

func collapse_as_vassal(faction: FactionData, conqueror: FactionData) -> void:
	if faction == null or conqueror == null or faction == conqueror:
		return
	if faction == FACTION_BARBARIAN or faction.is_player_faction:
		return
	if _count_seed_provinces(faction) > 0:
		return
	for commander in TurnManager.commanders.duplicate():
		var cd := commander as CommanderData
		if cd != null and cd.owner_faction == faction:
			TurnManager.destroy_commander(cd)
	EventBus.faction_collapsed.emit(faction, conqueror)
	start_vassalage(faction, conqueror)

func clear_faction_treaties(faction: FactionData) -> void:
	if faction == null:
		return
	for key in _relations.keys():
		var key_str: String = str(key)
		if key_str.begins_with(faction.faction_name + "|") or key_str.ends_with("|" + faction.faction_name):
			_relations.erase(key)
	for vassal_key in _overlords.keys():
		var vassal_name: String = str(vassal_key)
		var overlord: FactionData = _overlords[vassal_key]
		if vassal_name == faction.faction_name or overlord == faction:
			_overlords.erase(vassal_key)

func apply_turn_effects(faction: FactionData) -> void:
	if faction == null or faction == FACTION_BARBARIAN:
		return
	var changed: Array = []
	for other in TurnManager.get_all_factions():
		if other == faction:
			continue
		if has_trade_pact(faction, other):
			faction.resources["trade"] = faction.resources.get("trade", 0) + 1
			if not changed.has(faction):
				changed.append(faction)
	var overlord: FactionData = get_overlord(faction)
	if overlord != null:
		var paid := false
		for key in ["manpower", "oil", "steel", "trade"]:
			if faction.resources.get(key, 0) > 0:
				faction.resources[key] = faction.resources.get(key, 0) - 1
				overlord.resources[key] = overlord.resources.get(key, 0) + 1
				paid = true
		if paid:
			if not changed.has(faction):
				changed.append(faction)
			if not changed.has(overlord):
				changed.append(overlord)
			EventBus.tribute_paid.emit(faction, overlord)
	for f: FactionData in changed:
		EventBus.resources_changed.emit(f)

const TRADE_COST := 2   # trade units to spend per 1 unit of another resource

func can_exchange(faction: FactionData) -> bool:
	return faction.resources.get("trade", 0) >= TRADE_COST

func exchange_trade(faction: FactionData, target_resource: String) -> bool:
	if not can_exchange(faction):
		return false
	faction.resources["trade"] -= TRADE_COST
	faction.resources[target_resource] = faction.resources.get(target_resource, 0) + 1
	EventBus.resources_changed.emit(faction)
	return true

func reset_state() -> void:
	_relations.clear()
	_overlords.clear()

func get_enemies(faction: FactionData, all_factions: Array) -> Array:
	var result := []
	for other in all_factions:
		if other != faction and are_at_war(faction, other):
			result.append(other)
	return result

func relation_name(relation: int) -> String:
	match relation:
		Relation.WAR: return "War"
		Relation.ALLIANCE: return "Alliance"
		Relation.TRADE_PACT: return "Trade Pact"
		Relation.VASSALAGE: return "Vassalage"
		_: return "Peace"

# ─── Internal ─────────────────────────────────────────────────────────────────
func _key(a: FactionData, b: FactionData) -> String:
	if a.faction_name < b.faction_name:
		return a.faction_name + "|" + b.faction_name
	return b.faction_name + "|" + a.faction_name

func _count_seed_provinces(faction: FactionData) -> int:
	var count := 0
	for p: ProvinceData in ProvinceGrid.provinces:
		if ProvinceGrid.get_hex_owner(p.seed_hex) == faction:
			count += 1
	return count
