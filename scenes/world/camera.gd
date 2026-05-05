extends Camera3D
var target:Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target=get_tree().get_first_node_in_group("player")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target:
		global_position = target.global_position +Vector3(0, 15, 8)
