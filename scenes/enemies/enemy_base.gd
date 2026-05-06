extends CharacterBody3D

enum State { PATROL, CHASE, ATTACK }

@export var move_speed: float = 3.0
@export var detection_range: float = 10.0
@export var attack_range: float = 1.5
@export var attack_damage: float = 10.0
@export var faction: FactionData = null

var is_dead: bool = false
var state: State = State.PATROL
var player: Node3D
var nav_agent: NavigationAgent3D
var attack_timer: Timer
var death_sound: AudioStreamPlayer3D
var mesh: MeshInstance3D
var health_component: HealthComponent
var original_color: Color

var debuff_movement: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	nav_agent = $NavigationAgent3D
	attack_timer = $AttackTimer
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	death_sound = $DeathSound
	mesh = $MeshInstance3D
	health_component = $HealthComponent
	health_component.unit_died.connect(_on_died)
	health_component.debuffs_updated.connect(_on_debuffs_updated)
	# Duplicate material so each enemy has its own, then store original color
	var mat = mesh.get_active_material(0).duplicate()
	mesh.set_surface_override_material(0, mat)
	original_color = mat.albedo_color

func _physics_process(_delta: float) -> void:
	if player == null:
		return

	var dist = global_position.distance_to(player.global_position)

	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= detection_range:
		state = State.CHASE
	else:
		state = State.PATROL

	var effective_speed = move_speed * (1.0 - debuff_movement * 0.6)

	match state:
		State.CHASE:
			nav_agent.target_position = player.global_position
			var next = nav_agent.get_next_path_position()
			var dir = (next - global_position).normalized()
			velocity = dir * effective_speed
			move_and_slide()
		State.PATROL:
			# Move toward the nearest player-owned zone to contest it
			var target_zone = _find_player_zone()
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

func _find_player_zone() -> Node:
	var closest: Node = null
	var closest_dist: float = INF
	for zone_key in GameManager.zones:
		var owner = GameManager.zone_ownership.get(zone_key)
		if owner != null and owner.is_player_faction:
			var zone = GameManager.zones[zone_key]
			var dist = global_position.distance_to(zone.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = zone
	return closest

func _on_attack_timer_timeout() -> void:
	if state == State.ATTACK and player != null:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

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
