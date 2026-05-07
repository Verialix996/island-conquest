extends Node

const ZONE_SCENE   = preload("res://scenes/battle/zone.tscn")
const ENEMY_MELEE  = preload("res://scenes/units/enemy_base.tscn")
const ENEMY_RANGED = preload("res://scenes/units/enemy_ranged.tscn")

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
	if BattleContext.is_battle_mode():
		_place_zones()
		await _spawn_battle_units()   # may place walls; bake happens after
		_bake_navmesh()
	else:
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

	if BattleContext.is_battle_mode():
		# Battle: first half of zones → player, second half → enemy faction
		var enemy_faction: FactionData
		if BattleContext.is_defense:
			enemy_faction = BattleContext.attacker_faction
		else:
			var prov: ProvinceData = BattleContext.pending_province
			enemy_faction = prov.owner_faction if prov != null else null
		var mid := sorted.size() / 2
		for i in sorted.size():
			_spawn_zone(sorted[i], FACTION_PLAYER if i < mid else enemy_faction, i)
	else:
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
	if faction == null:
		return
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

# ── Battle mode: spawn province garrison as enemies ───────────────────────────
const BATTLE_WIN_DETECTOR_GD = preload("res://scenes/battle/battle_win_detector.gd")
const BATTLE_TRACKER_GD      = preload("res://scenes/battle/battle_tracker.gd")

func _spawn_battle_units() -> void:
	var detector := Node.new()
	detector.set_script(BATTLE_WIN_DETECTOR_GD)
	get_parent().add_child(detector)

	var tracker := Node.new()
	tracker.set_script(BATTLE_TRACKER_GD)
	tracker.add_to_group("battle_tracker")
	get_parent().add_child(tracker)
	tracker.player_tickets = 10 + BattleContext.player_commander_strength
	tracker.enemy_tickets  = 10 + BattleContext.enemy_commander_strength

	await get_tree().process_frame
	var province: ProvinceData = BattleContext.pending_province

	var enemy_faction: FactionData
	if BattleContext.is_defense:
		enemy_faction = BattleContext.attacker_faction
	else:
		enemy_faction = province.owner_faction if province != null else null

	var count: int = ProvinceGrid.get_province_garrison(province) if province != null else 3
	if count <= 0:
		count = 3

	# Sort zones by faction so each side spawns at their own zones
	var enemy_zone_nodes: Array = []
	var player_zone_nodes: Array = []
	for z in get_tree().get_nodes_in_group("battle_zone"):
		if z.owner_faction == null:
			continue
		if z.owner_faction.is_player_faction:
			player_zone_nodes.append(z)
		else:
			enemy_zone_nodes.append(z)

	# Move player character to a player zone
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node != null and not player_zone_nodes.is_empty():
		var pz: Node3D = player_zone_nodes[0]
		player_node.global_position = Vector3(pz.global_position.x, 1.1, pz.global_position.z)

	for i in count:
		var scene = ENEMY_MELEE if randf() < 0.5 else ENEMY_RANGED
		var unit  = scene.instantiate()
		unit.faction = enemy_faction
		get_parent().add_child(unit)
		var base_pos: Vector3
		if not enemy_zone_nodes.is_empty():
			base_pos = enemy_zone_nodes[randi() % enemy_zone_nodes.size()].global_position
		else:
			base_pos = Vector3.ZERO
		var offset := Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
		unit.global_position = Vector3(base_pos.x + offset.x, 1.1, base_pos.z + offset.z)

	_apply_building_effects(enemy_faction, enemy_zone_nodes, tracker)

# ── Building battlefield effects ──────────────────────────────────────────────

func _apply_building_effects(enemy_faction: FactionData, enemy_zones: Array, tracker: Node) -> void:
	var building: BuildingData = BattleContext.contested_hex_building
	if building == null:
		return

	match building.building_type:
		&"barracks":
			_spawn_extra_garrison(enemy_faction, enemy_zones, building.extra_defender_units)
		&"wall":
			_spawn_walls(enemy_zones)
		&"turret":
			_spawn_turret(enemy_faction, enemy_zones)
		&"energy_plant":
			# Defender of the contested hex gets the ticket bonus
			if BattleContext.is_defense:
				tracker.player_tickets += 2   # player is defending
			else:
				tracker.enemy_tickets  += 2   # enemy is defending their own hex

func _spawn_extra_garrison(enemy_faction: FactionData, enemy_zones: Array, count: int) -> void:
	var base_pos := Vector3.ZERO
	if not enemy_zones.is_empty():
		var z: Node3D = enemy_zones[randi() % enemy_zones.size()]
		base_pos = z.global_position
	for i in count:
		var unit := ENEMY_MELEE.instantiate()
		unit.set("faction", enemy_faction)
		get_parent().add_child(unit)
		var ox := randf_range(-2.0, 2.0)
		var oz := randf_range(-2.0, 2.0)
		unit.global_position = Vector3(base_pos.x + ox, 1.1, base_pos.z + oz)

func _spawn_walls(enemy_zones: Array) -> void:
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(10.0, 2.0, 0.5)
	for zone: Node3D in enemy_zones:
		var c := zone.global_position
		_place_wall_segment(wall_shape, Vector3(c.x,       c.y + 1.0, c.z + 6.0), 0.0)
		_place_wall_segment(wall_shape, Vector3(c.x,       c.y + 1.0, c.z - 6.0), 0.0)
		_place_wall_segment(wall_shape, Vector3(c.x + 6.0, c.y + 1.0, c.z),       90.0)
		_place_wall_segment(wall_shape, Vector3(c.x - 6.0, c.y + 1.0, c.z),       90.0)

func _place_wall_segment(shape: BoxShape3D, pos: Vector3, rot_y: float) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees.y = rot_y

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10.0, 2.0, 0.5)
	mesh_inst.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.50, 0.45, 0.40)
	mesh_inst.set_surface_override_material(0, mat)

	var col := CollisionShape3D.new()
	col.shape = shape

	body.add_child(mesh_inst)
	body.add_child(col)
	_nav_region.add_child(body)

func _spawn_turret(enemy_faction: FactionData, enemy_zones: Array) -> void:
	if enemy_zones.is_empty():
		return
	var zone: Node3D = enemy_zones[randi() % enemy_zones.size()]
	var unit := ENEMY_RANGED.instantiate()
	unit.set("faction",         enemy_faction)
	unit.set("move_speed",      0.1)
	unit.set("detection_range", 30.0)
	get_parent().add_child(unit)
	unit.global_position = Vector3(zone.global_position.x, 1.1, zone.global_position.z)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _random_map_pos(y: float) -> Vector3:
	return Vector3(randf_range(-map_half_size, map_half_size), y, randf_range(-map_half_size, map_half_size))

func _too_close(pos: Vector3, others: Array, min_dist: float) -> bool:
	for other in others:
		if pos.distance_to(other) < min_dist:
			return true
	return false
