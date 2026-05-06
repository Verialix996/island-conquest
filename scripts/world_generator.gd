extends Node

const ZONE_SCENE   = preload("res://scenes/world/zone.tscn")
const ENEMY_MELEE  = preload("res://scenes/enemies/enemy_base.tscn")
const ENEMY_RANGED = preload("res://scenes/enemies/enemy_ranged.tscn")

const FACTION_PLAYER = preload("res://scripts/resources/faction_player.tres")
const FACTION_RED    = preload("res://scripts/resources/faction_red.tres")
const FACTION_BLUE   = preload("res://scripts/resources/faction_blue.tres")
const FACTION_ORANGE = preload("res://scripts/resources/faction_orange.tres")

@export var zone_count: int = 6
@export var zone_min_distance: float = 25.0
@export var map_half_size: float = 40.0
@export var cover_count: int = 30
@export var ai_units_per_zone: int = 3
@export var player_starting_units: int = 3
@export var city_height: float = 3.0

var _nav_region: NavigationRegion3D
var _zone_positions: Array[Vector3] = []

func _ready() -> void:
	call_deferred("_generate")

func _generate() -> void:
	_nav_region = get_parent().get_node("NavigationRegion3D")
	_place_cover()
	_place_zones()
	_bake_navmesh()
	_spawn_starting_units()

# ── Cover ─────────────────────────────────────────────────────────────────────

func _place_cover() -> void:
	var cover_shape = BoxShape3D.new()
	cover_shape.size = Vector3(4, 1.5, 1)

	for i in cover_count:
		var pos = _random_map_pos(1.0)
		var body = StaticBody3D.new()
		body.position = pos
		body.rotation_degrees.y = randf_range(0, 360)

		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(4, 1.5, 1)
		mesh_inst.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.3, 0.2)
		mesh_inst.set_surface_override_material(0, mat)

		var col = CollisionShape3D.new()
		col.shape = cover_shape

		body.add_child(mesh_inst)
		body.add_child(col)
		_nav_region.add_child(body)

# ── Zones ─────────────────────────────────────────────────────────────────────

func _place_zones() -> void:
	var attempts := 0
	while _zone_positions.size() < zone_count and attempts < 500:
		attempts += 1
		var pos = _random_map_pos(0.0)
		if _too_close(pos, _zone_positions, zone_min_distance):
			continue
		_zone_positions.append(pos)

	var player_node = get_tree().get_first_node_in_group("player")
	var player_pos = player_node.global_position if player_node else Vector3.ZERO

	var sorted = _zone_positions.duplicate()
	sorted.sort_custom(func(a, b): return a.distance_to(player_pos) < b.distance_to(player_pos))

	var ai_factions: Array[FactionData] = [FACTION_RED, FACTION_BLUE, FACTION_ORANGE]
	var zone_index := 0

	for pos in sorted:
		var faction: FactionData
		if zone_index == 0:
			faction = FACTION_PLAYER
		else:
			faction = ai_factions[(zone_index - 1) % ai_factions.size()]
		_spawn_zone(pos, faction, zone_index)
		zone_index += 1

func _spawn_zone(pos: Vector3, faction: FactionData, index: int) -> void:
	var zone = ZONE_SCENE.instantiate()
	zone.name = "Zone_%d" % index
	zone.zone_name = "Zone %d" % index
	zone.owner_faction = faction
	zone.player_faction = FACTION_PLAYER
	get_parent().add_child(zone)
	zone.global_position = pos
	_spawn_city_marker(pos, faction)

func _spawn_city_marker(pos: Vector3, faction: FactionData) -> void:
	var mesh_inst = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = city_height
	mesh_inst.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = faction.color
	mesh_inst.set_surface_override_material(0, mat)
	mesh_inst.position = Vector3(pos.x, city_height * 0.5 + 0.5, pos.z)
	get_parent().add_child(mesh_inst)

# ── NavMesh ───────────────────────────────────────────────────────────────────

func _bake_navmesh() -> void:
	_nav_region.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	_nav_region.navigation_mesh.agent_radius = 1.0
	_nav_region.bake_navigation_mesh(false)

# ── Starting units ────────────────────────────────────────────────────────────

func _spawn_starting_units() -> void:
	await get_tree().process_frame
	for zone_key in GameManager.zones:
		var zone = GameManager.zones[zone_key]
		var faction = GameManager.zone_ownership.get(zone_key)
		if faction == null:
			continue
		var count = player_starting_units if faction.is_player_faction else ai_units_per_zone
		for i in count:
			var scene = ENEMY_MELEE if randf() < 0.5 else ENEMY_RANGED
			var unit = scene.instantiate()
			unit.faction = faction
			get_parent().add_child(unit)
			var offset = Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0))
			unit.global_position = Vector3(zone.global_position.x + offset.x, 1.1, zone.global_position.z + offset.z)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _random_map_pos(y: float) -> Vector3:
	return Vector3(randf_range(-map_half_size, map_half_size), y, randf_range(-map_half_size, map_half_size))

func _too_close(pos: Vector3, others: Array, min_dist: float) -> bool:
	for other in others:
		if pos.distance_to(other) < min_dist:
			return true
	return false
