extends "res://scenes/weapons/weapon_base.gd"

@export var pellet_count: int = 6
@export var spread_angle: float = 15.0

func fire() -> void:
	muzzle_flash.restart()
	gunshot_sound.play()

	for i in pellet_count:
		var angle = deg_to_rad(randf_range(-spread_angle, spread_angle))
		var spread_dir = Vector3(sin(angle), 0, -cos(angle))
		var world_dir = global_transform.basis * spread_dir

		var space_state = get_world_3d().direct_space_state
		var origin = global_position
		var end = origin + world_dir * 20.0
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [get_parent()]
		var result = space_state.intersect_ray(query)

		if result:
			if result.collider.has_method("take_damage"):
				result.collider.take_damage(damage, hit_chance_modifiers)
			spawn_tracer(origin, result.position)
		else:
			spawn_tracer(origin, end)
