extends CharacterBody3D

signal health_changed(parts: Array)
signal damage_taken

const SPEED = 5.0

var hit_sound: AudioStreamPlayer3D
var mesh: MeshInstance3D
var health_component: HealthComponent
var weapons: Array[Node] = []
var current_weapon: int = 0

# Debuff values — updated by HealthComponent signals
var debuff_movement: float = 0.0
var debuff_fire_rate: float = 0.0

func _ready() -> void:
	hit_sound = $HitSound
	mesh = $MeshInstance3D
	health_component = $HealthComponent
	health_component.unit_died.connect(_on_died)
	health_component.debuffs_updated.connect(_on_debuffs_updated)
	health_component.part_hit.connect(_on_part_hit)
	for child in get_children():
		if child is Node3D and child.has_method("fire"):
			weapons.append(child)
			child.weapon_empty.connect(_on_weapon_empty)
	_equip_weapon(0)

func _aim_at_mouse() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	if ray_dir.y != 0.0:
		var t := -ray_origin.y / ray_dir.y
		var world_mouse_pos := ray_origin + ray_dir * t
		look_at(Vector3(world_mouse_pos.x, global_position.y, world_mouse_pos.z), Vector3.UP)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	# Apply movement debuff from leg damage
	var effective_speed = SPEED * (1.0 - debuff_movement * 0.6)
	if direction:
		velocity.x = direction.x * effective_speed
		velocity.z = direction.z * effective_speed
	else:
		velocity.x = move_toward(velocity.x, 0, effective_speed)
		velocity.z = move_toward(velocity.z, 0, effective_speed)

	move_and_slide()
	_aim_at_mouse()
	_handle_weapon_switch()

func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		_equip_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_equip_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"):
		_equip_weapon(2)

func _equip_weapon(index: int) -> void:
	if index >= weapons.size():
		return
	current_weapon = index
	for i in weapons.size():
		weapons[i].set_process(i == current_weapon)
	# Notify HUD of new weapon's ammo state
	var w = weapons[current_weapon]
	w.ammo_changed.emit(w.current_mag_ammo, w.current_mags)

func take_damage(amount: float, hit_modifiers: Dictionary = {}) -> void:
	health_component.take_hit(amount, hit_modifiers)

func heal(amount: float) -> void:
	health_component.heal_most_damaged(amount)
	health_changed.emit(health_component.parts)

func _on_part_hit(_part_name: String, _damage: float) -> void:
	hit_sound.play()
	_flash_red()
	damage_taken.emit()
	health_changed.emit(health_component.parts)

func _on_debuffs_updated(debuffs: Dictionary) -> void:
	debuff_movement = debuffs["movement"]
	debuff_fire_rate = debuffs["fire_rate"]

func _on_died() -> void:
	if BattleContext.is_battle_mode():
		BattleContext.finish_battle(false)   # player lost — defender keeps province
	else:
		get_tree().reload_current_scene()

func _on_weapon_empty() -> void:
	# Auto-switch to pistol (index 0) when out of mags
	_equip_weapon(0)

func _flash_red() -> void:
	mesh.get_active_material(0).albedo_color = Color.RED
	await get_tree().create_timer(0.1).timeout
	mesh.get_active_material(0).albedo_color = Color("357e00")
