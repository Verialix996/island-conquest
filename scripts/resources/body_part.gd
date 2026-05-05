extends Resource

class_name BodyPart

enum DebuffType { NONE, ACCURACY, DAMAGE_TAKEN, SWAY, FIRE_RATE, MOVEMENT }

@export var part_name: String = ""
@export var max_health: float = 50.0
@export var hit_chance: float = 0.2
@export var debuff_type: DebuffType = DebuffType.NONE
@export var lethal: bool = false

var current_health: float

func initialize() -> void:
	current_health = max_health

func take_damage(amount: float) -> void:
	current_health = max(current_health - amount, 0.0)

func get_debuff_strength() -> float:
	if max_health == 0:
		return 0.0
	return 1.0 - (current_health / max_health)

func is_depleted() -> bool:
	return current_health <= 0.0

func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
