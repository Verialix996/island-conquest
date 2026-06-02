extends CharacterBody3D

enum State { PATROL, CHASE, ATTACK }

@export var move_speed: float = 3.0
@export var detection_range: float = 10.0
@export var attack_range: float = 1.5
@export var attack_damage: float = 10.0
@export var faction: FactionData = null
@export var weapon_slot: int = -1

var is_dead: bool = false
var state: State = State.PATROL
var target: Node3D = null
var target_search_timer: float = 0.0
var nav_agent: NavigationAgent3D
var attack_timer: Timer
var death_sound: AudioStreamPlayer3D
var attack_sound: AudioStreamPlayer3D
var mesh: MeshInstance3D
var health_component: HealthComponent
var original_color: Color
var weapons: Array[Node] = []
var current_weapon: int = -1

var debuff_movement: float = 0.0
var startup_timer: float = 0.3  # wait for NavigationAgent3D to sync after spawning

func _ready() -> void:
	_remove_broad_combat_groups()
	if faction != null:
		add_to_group(_faction_group_name(faction))
	nav_agent = $NavigationAgent3D
	nav_agent.avoidance_enabled = true
	attack_timer = $AttackTimer
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	death_sound = $DeathSound
	attack_sound = $AttackSound if has_node("AttackSound") else null
	mesh = _find_visual_tint_mesh()
	if mesh == null and has_node("MeshInstance3D") and $MeshInstance3D is MeshInstance3D:
		mesh = $MeshInstance3D
	health_component = $HealthComponent
	health_component.unit_died.connect(_on_died)
	health_component.debuffs_updated.connect(_on_debuffs_updated)
	_collect_loadout()
	if weapon_slot >= 0:
		_equip_weapon(weapon_slot)
	# Give each unit its own material instance and color it by faction
	if mesh != null and mesh.get_active_material(0) != null:
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
	if target_search_timer <= 0.0 or not _is_valid_target(target):
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

func get_faction() -> FactionData:
	return faction

func _find_nearest_hostile() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist: float = detection_range

	for other_faction in TurnManager.get_all_factions():
		var candidate_faction := other_faction as FactionData
		if not _is_hostile_faction(candidate_faction):
			continue
		for unit in get_tree().get_nodes_in_group(_faction_group_name(candidate_faction)):
			if unit == self or not is_instance_valid(unit):
				continue
			if not (unit is Node3D):
				continue
			if "is_dead" in unit and unit.is_dead:
				continue
			if not unit.has_method("take_damage"):
				continue
			var dist = global_position.distance_to(unit.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = unit

	return nearest

func _find_hostile_zone() -> Node:
	var closest: Node = null
	var closest_dist: float = INF
	for zone in get_tree().get_nodes_in_group("battle_zone"):
		var zone_owner: FactionData = zone.get("owner_faction")
		if not _is_hostile_faction(zone_owner):
			continue
		var dist = global_position.distance_to(zone.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = zone
	return closest

func _on_attack_timer_timeout() -> void:
	if state == State.ATTACK and _is_valid_target(target):
		if _fire_current_weapon():
			return
		if target.has_method("take_damage"):
			_play_attack_sound()
			target.take_damage(attack_damage)

func _play_attack_sound() -> void:
	if attack_sound == null:
		return
	attack_sound.pitch_scale = randf_range(0.92, 1.08)
	attack_sound.play()

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

func _collect_loadout() -> void:
	weapons.clear()
	for child in get_children():
		if child is Node3D and child.has_method("fire"):
			weapons.append(child)
			child.set_process(false)

func _equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		current_weapon = -1
		return
	current_weapon = index
	for i in weapons.size():
		weapons[i].set_process(false)

func _fire_current_weapon() -> bool:
	if current_weapon < 0 or current_weapon >= weapons.size():
		return false
	var weapon = weapons[current_weapon]
	if weapon.has_method("ai_fire"):
		return weapon.ai_fire(faction)
	return false

func _is_valid_target(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if "is_dead" in candidate and candidate.is_dead:
		return false
	var candidate_faction = _get_node_faction(candidate)
	return _is_hostile_faction(candidate_faction)

func _get_node_faction(node: Object) -> FactionData:
	if node == null:
		return null
	if node.has_method("get_faction"):
		return node.get_faction()
	return node.get("faction")

func _is_hostile_faction(other_faction: FactionData) -> bool:
	return faction != null and other_faction != null and DiplomacyManager.are_at_war(faction, other_faction)

func _remove_broad_combat_groups() -> void:
	if is_in_group("enemy"):
		remove_from_group("enemy")

func _faction_group_name(faction_data: FactionData) -> String:
	if faction_data == null:
		return "faction_unknown"
	return "faction_" + faction_data.faction_name.to_lower().replace(" ", "_")

func _flash_red() -> void:
	if mesh == null or mesh.get_active_material(0) == null:
		return
	mesh.get_active_material(0).albedo_color = Color.RED
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self) and mesh != null and mesh.get_active_material(0) != null:
		mesh.get_active_material(0).albedo_color = original_color

func _find_visual_tint_mesh() -> MeshInstance3D:
	for child in find_children("FactionTintTorso", "MeshInstance3D", true, false):
		var tint_mesh := child as MeshInstance3D
		if tint_mesh != null and tint_mesh.is_visible_in_tree():
			return tint_mesh
	for child in find_children("", "MeshInstance3D", true, false):
		var visible_mesh := child as MeshInstance3D
		if visible_mesh != null and visible_mesh.is_visible_in_tree():
			return visible_mesh
	return null
