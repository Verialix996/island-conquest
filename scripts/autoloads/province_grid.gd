extends Node

# ─── Grid constants ───────────────────────────────────────────────────────────
const GRID_W := 12          # micro-hex columns
const GRID_H := 8           # micro-hex rows  → 96 tiles / 16 provinces ≈ 6 tiles each
const NUM_PROVINCES := 16   # Voronoi seed count

# ─── Runtime data ─────────────────────────────────────────────────────────────
# hex_terrain[Vector2i] → ProvinceData.TerrainType
var hex_terrain: Dictionary = {}

# hex_province[Vector2i] → ProvinceData
var hex_province: Dictionary = {}

# Ordered list of all provinces
var provinces: Array[ProvinceData] = []

# Per-tile ownership and buildings — the atomic unit for capture
var hex_ownership: Dictionary = {}   # Vector2i → FactionData (null = unowned)
var hex_buildings: Dictionary = {}   # Vector2i → BuildingData (null = no building)

# province_adjacency[ProvinceData] → Array[ProvinceData]
var province_adjacency: Dictionary = {}

# The seed hex for each province (capital/label position)
var province_seeds: Array[Vector2i] = []

# ─── Faction resources ────────────────────────────────────────────────────────
const FACTION_PLAYER = preload("res://scripts/resources/faction_player.tres")
const FACTION_RED    = preload("res://scripts/resources/faction_red.tres")
const FACTION_BLUE   = preload("res://scripts/resources/faction_blue.tres")
const FACTION_ORANGE = preload("res://scripts/resources/faction_orange.tres")

# ─── Internal ─────────────────────────────────────────────────────────────────
var _noise: FastNoiseLite = null

# Catan-style distribution (no 7 — reserved for map events)
const DICE_POOL := [2, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 12]

func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.12
	# Generation is triggered by province_map via initialize()

# Called by province_map at the start of every new game (including restarts).
# Clears all previous state, picks a new random seed, and regenerates the world.
func initialize() -> void:
	# Clear runtime data from previous game
	for p in provinces:
		p.hex_tiles.clear()
		p.owner_faction = null
		p.turns_unowned = 0
		p.is_contested = false
		p.attacker_faction = null
	provinces.clear()
	hex_terrain.clear()
	hex_province.clear()
	hex_ownership.clear()
	hex_buildings.clear()
	province_adjacency.clear()
	province_seeds.clear()

	# Reset faction runtime state (owned_provinces, resources)
	for f in [FACTION_PLAYER, FACTION_RED, FACTION_BLUE, FACTION_ORANGE]:
		(f as FactionData).reset_runtime_state()

	_noise.seed = randi()
	_place_seeds()
	_create_provinces()
	_assign_voronoi()
	_generate_terrain()
	_assign_province_properties()
	_assign_dice_numbers()
	_compute_adjacency()
	_assign_faction_starts()

# ─── Step 1: scatter 16 seeds across a 4×4 cell layout ──────────────────────
# Works for any grid size — divides into cells by float math, so no crash on
# small grids where the old integer block sizes caused randi_range(1,0) errors.
func _place_seeds() -> void:
	province_seeds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed

	var cols := 4
	var rows := 4
	var cell_w := float(GRID_W) / cols
	var cell_h := float(GRID_H) / rows

	for row in rows:
		for col in cols:
			# Center of this cell, then nudge by up to ±30% of cell size
			var cx := cell_w * (col + 0.5)
			var cy := cell_h * (row + 0.5)
			var ox := rng.randf_range(-cell_w * 0.3, cell_w * 0.3)
			var oy := rng.randf_range(-cell_h * 0.3, cell_h * 0.3)
			var sx := clampi(int(cx + ox), 0, GRID_W - 1)
			var sy := clampi(int(cy + oy), 0, GRID_H - 1)
			province_seeds.append(Vector2i(sx, sy))

# ─── Step 2: create ProvinceData objects ─────────────────────────────────────
func _create_provinces() -> void:
	provinces.clear()
	for i in NUM_PROVINCES:
		var p := ProvinceData.new()
		p.province_id = i
		p.province_name = "Province %d" % (i + 1)
		p.seed_hex = province_seeds[i]
		provinces.append(p)

# ─── Step 3: Voronoi — assign each micro-hex to nearest seed ─────────────────
func _assign_voronoi() -> void:
	hex_province.clear()
	for y in GRID_H:
		for x in GRID_W:
			var coord := Vector2i(x, y)
			var world_pos := _hex_to_world(coord)
			var best_dist := INF
			var best_province: ProvinceData = null
			for i in NUM_PROVINCES:
				var seed_pos := _hex_to_world(province_seeds[i])
				var d := world_pos.distance_squared_to(seed_pos)
				if d < best_dist:
					best_dist = d
					best_province = provinces[i]
			hex_province[coord] = best_province
			best_province.hex_tiles.append(coord)

# ─── Step 4: noise terrain per hex ───────────────────────────────────────────
func _generate_terrain() -> void:
	hex_terrain.clear()
	for y in GRID_H:
		for x in GRID_W:
			var coord := Vector2i(x, y)
			var n := _noise.get_noise_2d(float(x), float(y))
			# n ∈ [-1, 1] → bucket into terrain types
			var terrain: ProvinceData.TerrainType
			if n > 0.4:
				terrain = ProvinceData.TerrainType.MOUNTAINS
			elif n > 0.15:
				terrain = ProvinceData.TerrainType.FOREST
			elif n > -0.1:
				terrain = ProvinceData.TerrainType.PLAINS
			elif n > -0.35:
				terrain = ProvinceData.TerrainType.URBAN
			else:
				terrain = ProvinceData.TerrainType.DESERT
			hex_terrain[coord] = terrain

# ─── Step 5: dominant terrain + resource type per province ───────────────────
func _assign_province_properties() -> void:
	for p in provinces:
		var counts := {}
		for coord in p.hex_tiles:
			var t: int = hex_terrain[coord]
			counts[t] = counts.get(t, 0) + 1
		# Dominant terrain = most common hex terrain in this province
		var best_terrain := ProvinceData.TerrainType.PLAINS
		var best_count := 0
		for t in counts:
			if counts[t] > best_count:
				best_count = counts[t]
				best_terrain = t as ProvinceData.TerrainType
		p.dominant_terrain = best_terrain
		match best_terrain:
			ProvinceData.TerrainType.MOUNTAINS: p.resource_type = ProvinceData.ResourceType.STEEL
			ProvinceData.TerrainType.DESERT:    p.resource_type = ProvinceData.ResourceType.OIL
			ProvinceData.TerrainType.URBAN:     p.resource_type = ProvinceData.ResourceType.TRADE
			_:                                  p.resource_type = ProvinceData.ResourceType.MANPOWER
		match best_terrain:
			ProvinceData.TerrainType.MOUNTAINS: p.base_garrison = 5
			ProvinceData.TerrainType.URBAN:     p.base_garrison = 4
			_:                                  p.base_garrison = 3

# ─── Step 6: shuffle Catan dice pool onto provinces ──────────────────────────
func _assign_dice_numbers() -> void:
	var pool := DICE_POOL.duplicate()
	pool.shuffle()
	for i in NUM_PROVINCES:
		provinces[i].dice_number = pool[i]

# ─── Step 7: province adjacency graph ────────────────────────────────────────
func _compute_adjacency() -> void:
	province_adjacency.clear()
	for p in provinces:
		province_adjacency[p] = []

	for y in GRID_H:
		for x in GRID_W:
			var coord := Vector2i(x, y)
			var p_here: ProvinceData = hex_province[coord]
			for nb in _hex_neighbors(coord):
				var p_nb: ProvinceData = hex_province[nb]
				if p_nb != p_here:
					var adj: Array = province_adjacency[p_here]
					if not adj.has(p_nb):
						adj.append(p_nb)

# ─── Step 8: give each faction one starting province ─────────────────────────
func _assign_faction_starts() -> void:
	var factions := [FACTION_PLAYER, FACTION_RED, FACTION_BLUE, FACTION_ORANGE]
	# Assign one corner-ish province per faction
	# Provinces 0/3/12/15 are near the four corners of the 4×4 block layout
	var start_indices := [0, 3, 12, 15]
	for i in factions.size():
		capture_province(provinces[start_indices[i]], factions[i])

# ─── Public API ───────────────────────────────────────────────────────────────
func get_hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	return _hex_neighbors(coord)

func get_province_for_hex(coord: Vector2i) -> ProvinceData:
	return hex_province.get(coord, null)

# Backward-compat alias
func get_province(coord: Vector2i) -> ProvinceData:
	return hex_province.get(coord, null)

func get_adjacent_provinces(p: ProvinceData) -> Array:
	return province_adjacency.get(p, [])

func get_provinces_owned_by(faction: FactionData) -> Array:
	var result := []
	for p in provinces:
		if p.owner_faction == faction:
			result.append(p)
	return result

func capture_province(province: ProvinceData, new_owner: FactionData) -> void:
	var old_owner: FactionData = province.owner_faction
	if old_owner != null:
		old_owner.owned_provinces.erase(province)
	province.owner_faction = new_owner
	province.turns_unowned = 0
	if new_owner != null:
		new_owner.owned_provinces.append(province)
	# Sync all tiles to the province owner
	for coord in province.hex_tiles:
		hex_ownership[coord] = new_owner
	EventBus.province_captured.emit(province, new_owner, old_owner)

# Capture exactly one tile; if it's the seed hex, also update province.owner_faction.
func capture_hex(coord: Vector2i, new_owner: FactionData) -> void:
	var old_owner: FactionData = hex_ownership.get(coord, null)
	hex_ownership[coord] = new_owner
	var province: ProvinceData = hex_province.get(coord, null)
	if province != null and province.seed_hex == coord:
		# Owning the seed hex is how a faction "owns" the province for dice/resources
		if old_owner != null:
			old_owner.owned_provinces.erase(province)
		province.owner_faction = new_owner
		if new_owner != null and not new_owner.owned_provinces.has(province):
			new_owner.owned_provinces.append(province)
	EventBus.hex_captured.emit(coord, new_owner, old_owner)

func get_hex_owner(coord: Vector2i) -> FactionData:
	return hex_ownership.get(coord, null)

# Buildings — one slot per tile
func get_hex_building(coord: Vector2i) -> BuildingData:
	return hex_buildings.get(coord, null)

func place_building(coord: Vector2i, building: BuildingData) -> void:
	hex_buildings[coord] = building

func remove_hex_building(coord: Vector2i) -> void:
	hex_buildings.erase(coord)

# Total garrison for a province: base + building bonuses from every hex
func get_province_garrison(province: ProvinceData) -> int:
	var total := province.base_garrison
	for coord in province.hex_tiles:
		var b: BuildingData = get_hex_building(coord)
		if b != null:
			total += b.extra_defender_units
	return total

# Total income for a province: base + income_bonus from every hex
func get_province_income(province: ProvinceData) -> int:
	var total := province.base_income
	for coord in province.hex_tiles:
		var b: BuildingData = get_hex_building(coord)
		if b != null:
			total += b.income_bonus
	return total

# ─── Geometry helpers ─────────────────────────────────────────────────────────
# Odd-r offset → approximate world position (used for Voronoi distance only)
func _hex_to_world(coord: Vector2i) -> Vector2:
	var x := coord.x + (coord.y % 2) * 0.5
	var y := coord.y * 0.866
	return Vector2(x, y)

# 6 grid-valid neighbors for odd-r offset hex layout (odd rows shift right).
func _hex_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets: Array
	if coord.y % 2 == 0:
		offsets = [
			Vector2i(1, 0),  Vector2i(-1, 0),
			Vector2i(0, -1), Vector2i(-1, -1),
			Vector2i(0, 1),  Vector2i(-1, 1)
		]
	else:
		offsets = [
			Vector2i(1, 0),  Vector2i(-1, 0),
			Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(1, 1),  Vector2i(0, 1)
		]
	for off in offsets:
		var nb: Vector2i = coord + off
		if nb.x >= 0 and nb.x < GRID_W and nb.y >= 0 and nb.y < GRID_H:
			result.append(nb)
	return result
