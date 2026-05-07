class_name ProvinceData
extends Resource

enum TerrainType { PLAINS, FOREST, URBAN, DESERT, MOUNTAINS }
enum ResourceType { MANPOWER, OIL, STEEL, TRADE }

@export var province_id: int = 0
@export var province_name: String = ""
@export var owner_faction: FactionData = null
@export var dominant_terrain: TerrainType = TerrainType.PLAINS
@export var resource_type: ResourceType = ResourceType.MANPOWER
@export var base_income: int = 10
@export var dice_number: int = 0       # 2-12, Catan-style
@export var base_garrison: int = 3     # base defenders in battle
@export var buildings: Array[Resource] = []

# Runtime state — not saved to disk
var hex_tiles: Array[Vector2i] = []    # all micro-hexes belonging to this province
var seed_hex: Vector2i = Vector2i.ZERO # capital hex (shows dice number)
var turns_unowned: int = 0             # barbarian spawn counter
var is_contested: bool = false
var attacker_faction: FactionData = null

func get_total_income() -> int:
	var total := base_income
	for b in buildings:
		total += (b as BuildingData).income_bonus
	return total

func get_defense_rating() -> int:
	var total := 0
	for b in buildings:
		total += (b as BuildingData).defense_bonus
	return total

func get_total_garrison() -> int:
	var total := base_garrison
	for b in buildings:
		total += (b as BuildingData).extra_defender_units
	return total

func has_building(type: StringName) -> bool:
	return get_building_of_type(type) != null

func get_building_of_type(type: StringName) -> BuildingData:
	for b in buildings:
		if (b as BuildingData).building_type == type:
			return b as BuildingData
	return null

func add_building(b: BuildingData) -> void:
	buildings.append(b)

func remove_building(b: BuildingData) -> void:
	buildings.erase(b)
