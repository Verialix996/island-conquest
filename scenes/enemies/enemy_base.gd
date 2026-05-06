extends CharacterBody3D

enum State { PATROL, CHASE, ATTACK }

@export var move_speed: float = 3.0
@export var detection_range: float = 10.0
@export var attack_range: float = 1.5
@export var attack_damage: float = 10.0
@export var faction: FactionData = null

var is_dead: bool = false
var state: State = State.PATROL
var target: Node3D = null
var target_search_timer: float = 0.0
var nav_agent: NavigationAgent3D
var attack_timer: Timer
var death_sound: AudioStreamPlayer3D
var mesh: MeshInstance3D
var health_component: HealthComponent
var original_color: Color

var debuff_movement: float = 0.0
var startup_timer: float = 0.3  # wait for NavigationAgent3D to sync after spawning

func _ready() -> void:
	add_to_group("enemy")
	nav_agent = $NavigationAgent3D
	attack_timer = $AttackTimer
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	death_sound = $DeathSound
	mesh = $MeshInstance3D
	health_component = $HealthComponent
	health_component.unit_died.connect(_on_died)
	health_component.debuffs_updated.connect(_on_debuffs_updated)
	# Give each unit its own material instance and color it by faction
	var mat = mesh.get_active_material(0).duplicate()
	mesh.set_surface_override_material(0, mat)
	if faction != null:
		mat.albedo_color = faction.color
	original_color = mat.albedo_color

func _physics_process(delta: float) -> void:
	if startup_timer > 0.0:
		startup_timer -= delta
		return

	# Refresh target every second
	target_search_timer -= delta
	if target_search_timer <= 0.0 or not is_instance_valid(target):
		target_search_timer = 1.0
		target = _find_nearest_hostile()

	if target == null:
		state = State.PATROL
	else:
		var dist = global_position.distance_to(target.global_position)
		if dist <= attack_range:
			state = State.ATTACK
		elif dist <= detection_range:
			state = State.CHASE
		else:
			state = State.PATROL

	var effective_speed = move_speed * (1.0 - debuff_movement * 0.6)

	match state:
		State.CHASE:
			nav_agent.target_position = target.global_position
			var next = nav_agent.get_next_path_position()
			var dir = (next - global_position).normalized()
			velocity = dir * effective_speed
			move_and_slide()
		State.PATROL:
			var target_zone = _find_hostile_zone()
			if target_zone != null:
				nav_agent.target_position = target_zone.global_position
				var next = nav_agent.get_next_path_position()
				var dir = (next - global_position).normalized()
				velocity = dir * effective_speed
				move_and_slide()
			else:
				velocity = Vector3.ZERO
		State.ATTACK:
			velocity = Vector3.ZERO

func _find_nearest_hostile() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = detection_range

	# Player character is always hostile to non-player factions
	if faction == null or not faction.is_player_faction:
		var player = get_tree().get_first_node_in_group("player")
		if player != null:
			var dist = global_position.distance_to(player.global_position)
			if dist < nearest_dist:
				nearest = player
				nearest_dist = dist

	# Check all enemy-group units from rival factions
	for unit in get_tree().get_nodes_in_group("enemy"):
		if unit == self or not is_instance_valid(unit):
			continue
		if "is_dead" in unit and unit.is_dead:
			continue
		var unit_faction = unit.get("faction")
		if unit_faction == faction:
			continue
		var dist = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	return nearest

func _find_hostile_zone() -> Node:
	var closest: Node = null
	var closest_dist: float = INF
	for zone_key in GameManager.zones:
		var zone_owner = GameManager.zone_ownership.get(zone_key)
		if zone_owner == null or zone_owner == faction:
			continue
		var zone = GameManager.zones[zone_key]
		var dist = global_position.distance_to(zone.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = zone
	return closest

func _on_attack_timer_timeout() -> void:
	if state == State.ATTACK and is_instance_valid(target):
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func take_damage(amount: float, hit_modifiers: Dictionary = {}) -> void:
	if is_dead:
		return
	health_component.take_hit(amount, hit_modifiers)
	_flash_red()

func _on_debuffs_updated(debuffs: Dictionary) -> void:
	debuff_movement = debuffs["movement"]

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	death_sound.play()
	await death_sound.finished
	queue_free()

func _flash_red() -> void:
	mesh.get_active_material(0).albedo_color = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		mesh.get_active_material(0).albedo_color = original_color
