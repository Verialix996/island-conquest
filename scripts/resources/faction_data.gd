extends Resource

class_name FactionData

@export var faction_name: String = "Unknown"
@export var color: Color = Color.WHITE
@export var is_player_faction: bool = false

# Relationship values: 1.0 = ally, 0.0 = neutral, -1.0 = enemy
# Key = faction_name of the other faction
@export var relationships: Dictionary = {}
