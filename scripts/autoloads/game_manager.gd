extends Node

# Key = zone node name, Value = FactionData that owns it
var zone_ownership: Dictionary = {}

# Key = zone node name, Value = the zone Node itself
var zones: Dictionary = {}

var factions: Array[FactionData] = []

# Set by menu/new-game UI before reloading the map scene so a player-requested
# restart can jump straight into a fresh campaign instead of stopping on the
# splash menu again.
var skip_main_menu_once: bool = false

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
