extends Area3D

@export var heal_amount: float = 10.0
@export var heal_interval: float = 0.5
@export var mags_to_add: int = 1

var player: Node3D = null
var heal_timer: float = 0.0
var is_captured: bool = true  # Milestone 5 will tie this to zone ownership

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if player == null or not is_captured:
		return
	heal_timer -= delta
	if heal_timer <= 0.0:
		heal_timer = heal_interval
		_resupply_player()

func _resupply_player() -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	var weapons = player.weapons
	if weapons.size() > 0:
		var current = weapons[player.current_weapon]
		if current.has_method("add_mags") and current.current_mags < current.max_mags:
			current.add_mags(mags_to_add)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player = null
