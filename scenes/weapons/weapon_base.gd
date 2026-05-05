extends Node3D

signal ammo_changed(current_mag: int, mags_left: int)
signal weapon_empty

@export var damage: float = 25.0
@export var fire_rate: float = 0.2
@export var tracer_color: Color = Color(1.0, 0.9, 0.3)
@export var mag_size: int = 30
@export var max_mags: int = 5
@export var unlimited_mags: bool = false
@export var hit_chance_modifiers: Dictionary = {}

var can_fire: bool = true
var is_reloading: bool = false
var current_mag_ammo: int
var current_mags: int
var raycast: RayCast3D
var muzzle_flash: GPUParticles3D
var gunshot_sound: AudioStreamPlayer3D

func _ready() -> void:
	raycast = $RayCast3D
	muzzle_flash = $MuzzleFlash
	gunshot_sound = $GunShotSound
	current_mag_ammo = mag_size
	current_mags = max_mags

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("reload") and not is_reloading:
		reload()
	if Input.is_action_pressed("shoot") and can_fire and not is_reloading:
		if current_mag_ammo > 0:
			can_fire = false
			current_mag_ammo -= 1
			ammo_changed.emit(current_mag_ammo, current_mags)
			fire()
			await get_tree().create_timer(fire_rate).timeout
			can_fire = true
		else:
			if unlimited_mags or current_mags > 0:
				reload()
			else:
				weapon_empty.emit()

func fire() -> void:
	muzzle_flash.restart()
	gunshot_sound.play()
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		var hit_point = raycast.get_collision_point()
		if hit != null and hit.has_method("take_damage"):
			hit.take_damage(damage, hit_chance_modifiers)
		spawn_tracer(global_position, hit_point)
	else:
		var end = global_position + (-global_transform.basis.z * 50.0)
		spawn_tracer(global_position, end)

func reload() -> void:
	if is_reloading:
		return
	if not unlimited_mags and current_mags <= 0:
		return
	is_reloading = true
	await get_tree().create_timer(1.5).timeout
	if not unlimited_mags:
		current_mags -= 1
	current_mag_ammo = mag_size
	ammo_changed.emit(current_mag_ammo, current_mags)
	is_reloading = false

func add_mags(amount: int) -> void:
	current_mags = min(current_mags + amount, max_mags)
	ammo_changed.emit(current_mag_ammo, current_mags)

func spawn_tracer(from: Vector3, to: Vector3) -> void:
	var mesh_instance = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tracer_color
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	get_tree().root.add_child(mesh_instance)
	await get_tree().create_timer(0.05).timeout
	mesh_instance.queue_free()
