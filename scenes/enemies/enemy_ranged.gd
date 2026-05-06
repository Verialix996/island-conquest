extends "res://scenes/enemies/enemy_base.gd"

@export var preferred_distance: float = 8.0
@export var shoot_range: float = 15.0
@export var shoot_damage: int = 10
@export var shoot_cooldown: float = 1.5

var shoot_timer: float = 0.0
var shoot_ray: RayCast3D

func _ready() -> void:
	super._ready()
	shoot_ray = $ShootRay

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or is_dead:
		return

	if startup_timer > 0.0:
		startup_timer -= delta
		return

	# Refresh target every second
	target_search_timer -= delta
	if target_search_timer <= 0.0 or not is_instance_valid(target):
		target_search_timer = 1.0
		target = _find_nearest_hostile()

	# No target — patrol toward a hostile zone
	if target == null:
		var zone = _find_hostile_zone()
		if zone != null:
			nav_agent.target_position = zone.global_position
			var next = nav_agent.get_next_path_position()
			var dir = (next - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO
		return

	shoot_timer -= delta
	var dist = global_position.distance_to(target.global_position)

	if dist <= shoot_range:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
		if dist < preferred_distance:
			var dir = (global_position - target.global_position)
			dir.y = 0.0
			velocity = dir.normalized() * move_speed
		else:
			velocity = Vector3.ZERO
		if shoot_timer <= 0.0:
			_try_shoot()
			shoot_timer = shoot_cooldown
	else:
		nav_agent.target_position = target.global_position
		var next = nav_agent.get_next_path_position()
		var dir = (next - global_position).normalized()
		velocity = dir * move_speed

	move_and_slide()

func _try_shoot() -> void:
	if shoot_ray.is_colliding():
		var hit = shoot_ray.get_collider()
		if hit != null and hit.has_method("take_damage"):
			hit.take_damage(shoot_damage)
