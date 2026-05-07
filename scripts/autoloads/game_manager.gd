extends Node

# Key = zone node name, Value = FactionData that owns it
var zone_ownership: Dictionary = {}

# Key = zone node name, Value = the zone Node itself
var zones: Dictionary = {}

var factions: Array[FactionData] = []

func _ready() -> void:
	EventBus.zone_captured.connect(_on_zone_captured)

func register_zone(zone: Node, faction: FactionData) -> void:
	zone_ownership[zone.name] = faction
	zones[zone.name] = zone

func get_zone_owner(zone: Node) -> FactionData:
	return zone_ownership.get(zone.name, null)

func _on_zone_captured(zone: Node, faction: FactionData) -> void:
	zone_ownership[zone.name] = faction
	print("GameManager: %s now owns %s" % [faction.faction_name, zone.name])
