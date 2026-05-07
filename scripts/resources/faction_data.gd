extends Resource

class_name FactionData

@export var faction_name: String = "Unknown"
@export var color: Color = Color.WHITE
@export var is_player_faction: bool = false

# Relationship values: 1.0 = ally, 0.0 = neutral, -1.0 = enemy
# Key = faction_name of the other faction
@export var relationships: Dictionary = {}

# 4X strategy settings
@export var aggression: float = 0.5
@export var expansion_bias: float = 0.5

# Runtime state — reset each new game, NOT saved to .tres
var resources: Dictionary = { "manpower": 0, "oil": 0, "steel": 0, "trade": 0 }
var owned_provinces: Array = []   # Array[ProvinceData] — untyped to avoid circular dependency
var traits: Array = []            # Array[FactionTrait], assigned at game start; empty for player

func reset_runtime_state() -> void:
	resources = { "manpower": 0, "oil": 0, "steel": 0, "trade": 0 }
	owned_provinces.clear()
	traits.clear()

func has_trait(t: FactionTrait.TraitType) -> bool:
	for trait_item in traits:
		if trait_item.trait_type == t:
			return true
	return false
