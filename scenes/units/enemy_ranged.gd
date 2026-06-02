extends "res://scenes/units/enemy_base.gd"

@export var preferred_distance: float = 8.0
@export var shoot_range: float = 15.0
@export var shoot_cooldown: float = 1.5

var shoot_timer: float = 0.0

func _ready() -> void:
	weapon_slot = max(weapon_slot, 2) # default to Rifle from the shared Pistol/Shotgun/Rifle loadout
	super._ready()
	attack_range = shoot_range

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or is_dead:
		return

	if startup_timer > 0.0:
		startup_timer -= delta
		return

	# Refresh target every second
	target_search_timer -= delta
	if target_search_timer <= 0.0 or not _is_valid_target(target):
		target_search_timer = 1.0
		target = _find_nearest_hostile()

	var effective_speed = move_speed * (1.0 - debuff_movement * 0.6)

	# No target — patrol toward a hostile zone
	if target == null:
		var zone = _find_hostile_zone()
		if zone != null:
			nav_agent.target_position = zone.global_position
			var next = nav_agent.get_next_path_position()
			var dir = (next - global_position).normalized()
			velocity = dir * effective_speed
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
			velocity = dir.normalized() * effective_speed
		else:
			velocity = Vector3.ZERO
		if shoot_timer <= 0.0:
			_try_shoot()
			shoot_timer = shoot_cooldown
	else:
		nav_agent.target_position = target.global_position
		var next = nav_agent.get_next_path_position()
		var dir = (next - global_position).normalized()
		velocity = dir * effective_speed

	move_and_slide()

func _try_shoot() -> void:
	if _is_valid_target(target):
		_fire_current_weapon()
