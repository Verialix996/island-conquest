extends Node

enum Relation { PEACE, WAR, ALLIANCE, TRADE_PACT, VASSALAGE }
enum ProposalType { CEASEFIRE, ALLIANCE, TRADE_PACT, VASSALAGE }

const FACTION_BARBARIAN = preload("res://scripts/resources/faction_barbarian.tres")

# Canonical key: alphabetically sorted faction names joined by "|"
# so get_relation(A,B) == get_relation(B,A) always.
var _relations: Dictionary = {}
var _overlords: Dictionary = {} # vassal faction_name -> FactionData
var _messages: Array[Dictionary] = []
var _next_message_id: int = 1

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

func send_proposal(sender: FactionData, recipient: FactionData, proposal_type: int, note: String = "") -> Dictionary:
	if sender == null or recipient == null or sender == recipient:
		return {}
	if sender == FACTION_BARBARIAN or recipient == FACTION_BARBARIAN:
		return {}
	var existing := _find_pending_proposal(sender, recipient, proposal_type)
	if not existing.is_empty():
		return existing
	var message := {
		"id": _next_message_id,
		"sender": sender,
		"recipient": recipient,
		"type": proposal_type,
		"title": proposal_title(proposal_type),
		"body": note if note != "" else proposal_body(sender, recipient, proposal_type),
		"round": TurnManager.current_round,
		"resolved": false,
		"accepted": false
	}
	_next_message_id += 1
	_messages.append(message)
	EventBus.diplomatic_message_sent.emit(message)
	return message

func respond_to_proposal(message_id: int, accepted: bool) -> bool:
	for i in _messages.size():
		var message: Dictionary = _messages[i]
		if int(message.get("id", -1)) != message_id or bool(message.get("resolved", false)):
			continue
		message["resolved"] = true
		message["accepted"] = accepted
		_messages[i] = message
		if accepted:
			_apply_proposal(message)
		EventBus.diplomatic_proposal_resolved.emit(message, accepted)
		return true
	return false

func get_messages_for(faction: FactionData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for message: Dictionary in _messages:
		if message.get("recipient", null) == faction:
			result.append(message)
	return result

func get_pending_messages_for(faction: FactionData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for message: Dictionary in _messages:
		if message.get("recipient", null) == faction and not bool(message.get("resolved", false)):
			result.append(message)
	return result

func proposal_title(proposal_type: int) -> String:
	match proposal_type:
		ProposalType.CEASEFIRE: return "Ceasefire Offer"
		ProposalType.ALLIANCE: return "Alliance Proposal"
		ProposalType.TRADE_PACT: return "Trade Pact Proposal"
		ProposalType.VASSALAGE: return "Vassalage Demand"
		_: return "Diplomatic Message"

func proposal_body(sender: FactionData, recipient: FactionData, proposal_type: int) -> String:
	var sender_name := sender.faction_name if sender != null else "Unknown"
	var recipient_name := recipient.faction_name if recipient != null else "Unknown"
	match proposal_type:
		ProposalType.CEASEFIRE:
			return sender_name + " asks " + recipient_name + " to end the war and restore peace."
		ProposalType.ALLIANCE:
			return sender_name + " wants a military alliance against common rivals."
		ProposalType.TRADE_PACT:
			return sender_name + " offers a trade pact for extra trade income each turn."
		ProposalType.VASSALAGE:
			return sender_name + " demands that " + recipient_name + " become a vassal and pay tribute."
		_:
			return sender_name + " sends a diplomatic message."

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
	_messages.clear()
	_next_message_id = 1

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

func _find_pending_proposal(sender: FactionData, recipient: FactionData, proposal_type: int) -> Dictionary:
	for message: Dictionary in _messages:
		if bool(message.get("resolved", false)):
			continue
		if message.get("sender", null) == sender and message.get("recipient", null) == recipient and int(message.get("type", -1)) == proposal_type:
			return message
	return {}

func _apply_proposal(message: Dictionary) -> void:
	var sender: FactionData = message.get("sender", null)
	var recipient: FactionData = message.get("recipient", null)
	match int(message.get("type", -1)):
		ProposalType.CEASEFIRE:
			offer_peace(recipient, sender)
		ProposalType.ALLIANCE:
			propose_alliance(recipient, sender)
		ProposalType.TRADE_PACT:
			propose_trade_pact(recipient, sender)
		ProposalType.VASSALAGE:
			start_vassalage(recipient, sender)
