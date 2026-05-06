extends Node

# Global signal hub — emit here, listen from anywhere
# No game logic lives here, only signal declarations

@warning_ignore("unused_signal")
signal zone_captured(zone: Node, faction: FactionData)
@warning_ignore("unused_signal")
signal zone_lost(zone: Node, faction: FactionData)
@warning_ignore("unused_signal")
signal faction_relationship_changed(faction_a: FactionData, faction_b: FactionData, new_value: float)
