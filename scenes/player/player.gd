extends CharacterBody3D


const SPEED = 5.0

func _aim_at_mouse() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos :=get_viewport().get_mouse_position()
	var ray_origin :=camera.project_ray_origin(mouse_pos)
	var ray_dir :=camera.project_ray_normal(mouse_pos)
	if ray_dir.y != 0.0:
		var t := -ray_origin.y / ray_dir.y
		var world_mouse_pos := ray_origin + ray_dir * t
		look_at(Vector3(world_mouse_pos.x, global_position.y,world_mouse_pos.z), Vector3.UP)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_aim_at_mouse()
