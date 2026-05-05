extends Camera3D

var target: Node3D

# Shake state
var shake_amount: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0

func _ready() -> void:
	target = get_tree().get_first_node_in_group("player")
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.damage_taken.connect(_on_player_damage_taken)

func _process(delta: float) -> void:
	if target:
		var base_pos = target.global_position + Vector3(0, 15, 8)
		if shake_timer > 0.0:
			shake_timer -= delta
			# Add random offset to simulate shake
			var offset = Vector3(
				randf_range(-shake_amount, shake_amount),
				0.0,
				randf_range(-shake_amount, shake_amount)
			)
			global_position = base_pos + offset
		else:
			global_position = base_pos

func shake(amount: float, duration: float) -> void:
	shake_amount = amount
	shake_duration = duration
	shake_timer = duration

func _on_player_damage_taken() -> void:
	shake(0.3, 0.2)
