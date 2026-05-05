extends Node

class_name HealthComponent

signal unit_died
signal debuffs_updated(debuffs: Dictionary)
signal part_hit(part_name: String, damage: float)

# Default body parts — units can override these via @export
@export var parts: Array[BodyPart] = []

func _ready() -> void:
	# If no parts set in Inspector, build the default human layout
	if parts.is_empty():
		parts = _build_default_parts()
	for part in parts:
		part.initialize()

func take_hit(damage: float, hit_chance_modifiers: Dictionary = {}) -> void:
	var part = _roll_hit_location(hit_chance_modifiers)
	part.take_damage(damage)
	part_hit.emit(part.part_name, damage)

	if part.is_depleted() and part.lethal:
		unit_died.emit()
		return

	debuffs_updated.emit(_calculate_debuffs())

func heal_most_damaged(amount: float) -> void:
	var worst: BodyPart = null
	var worst_pct: float = 1.0
	for part in parts:
		var pct = part.current_health / part.max_health
		if worst == null or pct < worst_pct:
			worst = part
			worst_pct = pct
	if worst:
		worst.heal(amount)
	debuffs_updated.emit(_calculate_debuffs())

func _roll_hit_location(modifiers: Dictionary) -> BodyPart:
	# Build adjusted hit chances
	var chances: Array[float] = []
	var total: float = 0.0
	for part in parts:
		var chance = part.hit_chance
		if modifiers.has(part.part_name):
			chance = clamp(chance + modifiers[part.part_name], 0.0, 1.0)
		chances.append(chance)
		total += chance

	# Normalize and roll
	var roll = randf() * total
	var cumulative: float = 0.0
	for i in parts.size():
		cumulative += chances[i]
		if roll <= cumulative:
			return parts[i]
	return parts[parts.size() - 1]

func _calculate_debuffs() -> Dictionary:
	var debuffs = {
		"accuracy": 0.0,
		"damage_taken": 0.0,
		"sway": 0.0,
		"fire_rate": 0.0,
		"movement": 0.0
	}
	for part in parts:
		var strength = part.get_debuff_strength()
		match part.debuff_type:
			BodyPart.DebuffType.ACCURACY:    debuffs["accuracy"]    += strength
			BodyPart.DebuffType.DAMAGE_TAKEN: debuffs["damage_taken"] += strength
			BodyPart.DebuffType.SWAY:         debuffs["sway"]         += strength
			BodyPart.DebuffType.FIRE_RATE:    debuffs["fire_rate"]    += strength
			BodyPart.DebuffType.MOVEMENT:     debuffs["movement"]     += strength
	return debuffs

func _build_default_parts() -> Array[BodyPart]:
	var head = BodyPart.new()
	head.part_name = "head"
	head.max_health = 30.0
	head.hit_chance = 0.10
	head.debuff_type = BodyPart.DebuffType.ACCURACY
	head.lethal = true

	var torso = BodyPart.new()
	torso.part_name = "torso"
	torso.max_health = 80.0
	torso.hit_chance = 0.40
	torso.debuff_type = BodyPart.DebuffType.DAMAGE_TAKEN
	torso.lethal = true

	var left_arm = BodyPart.new()
	left_arm.part_name = "left_arm"
	left_arm.max_health = 40.0
	left_arm.hit_chance = 0.15
	left_arm.debuff_type = BodyPart.DebuffType.SWAY
	left_arm.lethal = false

	var right_arm = BodyPart.new()
	right_arm.part_name = "right_arm"
	right_arm.max_health = 40.0
	right_arm.hit_chance = 0.15
	right_arm.debuff_type = BodyPart.DebuffType.FIRE_RATE
	right_arm.lethal = false

	var legs = BodyPart.new()
	legs.part_name = "legs"
	legs.max_health = 50.0
	legs.hit_chance = 0.20
	legs.debuff_type = BodyPart.DebuffType.MOVEMENT
	legs.lethal = false

	return [head, torso, left_arm, right_arm, legs]
