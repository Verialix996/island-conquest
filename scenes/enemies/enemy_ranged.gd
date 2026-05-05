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
	if player == null or is_dead:
		return

	var dist = global_position.distance_to(player.global_position)
	shoot_timer -= delta

	if dist <= shoot_range:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		if dist < preferred_distance:
			var dir = (global_position - player.global_position).normalized()
			velocity = dir * move_speed
		else:
			velocity = Vector3.ZERO
		if shoot_timer <= 0.0:
			_try_shoot()
			shoot_timer = shoot_cooldown
	else:
		nav_agent.target_position = player.global_position
		var next = nav_agent.get_next_path_position()
		var dir = (next - global_position).normalized()
		velocity = dir * move_speed

	move_and_slide()

func _try_shoot() -> void:
	if shoot_ray.is_colliding():
		var hit = shoot_ray.get_collider()
		if hit != null and hit.has_method("take_damage"):
			hit.take_damage(shoot_damage)
