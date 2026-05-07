extends Node

enum Relation { PEACE, WAR, ALLIANCE }

const FACTION_BARBARIAN = preload("res://scripts/resources/faction_barbarian.tres")

# Canonical key: alphabetically sorted faction names joined by "|"
# so get_relation(A,B) == get_relation(B,A) always.
var _relations: Dictionary = {}

# ─── Public API ────────────────────────────────────────────────────────────────
func get_relation(a: FactionData, b: FactionData) -> Relation:
	return _relations.get(_key(a, b), Relation.PEACE)

func are_at_war(a: FactionData, b: FactionData) -> bool:
	if a == FACTION_BARBARIAN or b == FACTION_BARBARIAN:
		return true   # Barbarians are always at war with everyone
	return get_relation(a, b) == Relation.WAR

func declare_war(attacker: FactionData, target: FactionData) -> void:
	_relations[_key(attacker, target)] = Relation.WAR
	EventBus.war_declared.emit(attacker, target)

func offer_peace(initiator: FactionData, target: FactionData) -> void:
	_relations[_key(initiator, target)] = Relation.PEACE
	EventBus.peace_made.emit(initiator, target)

func propose_alliance(initiator: FactionData, target: FactionData) -> void:
	_relations[_key(initiator, target)] = Relation.ALLIANCE

func reset_state() -> void:
	_relations.clear()

func get_enemies(faction: FactionData, all_factions: Array) -> Array:
	var result := []
	for other in all_factions:
		if other != faction and are_at_war(faction, other):
			result.append(other)
	return result

# ─── Internal ─────────────────────────────────────────────────────────────────
func _key(a: FactionData, b: FactionData) -> String:
	var names := [a.faction_name, b.faction_name]
	names.sort()
	return names[0] + "|" + names[1]
