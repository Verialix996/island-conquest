extends Node

# Global signal hub — emit here, listen from anywhere
# No game logic lives here, only signal declarations

@warning_ignore("unused_signal")
signal zone_captured(zone: Node, faction: FactionData)
@warning_ignore("unused_signal")
signal zone_lost(zone: Node, faction: FactionData)
@warning_ignore("unused_signal")
signal faction_relationship_changed(faction_a: FactionData, faction_b: FactionData, new_value: float)

# Map phase — province events
@warning_ignore("unused_signal")
signal province_captured(province: ProvinceData, new_owner: FactionData, old_owner: FactionData)
@warning_ignore("unused_signal")
signal province_data_changed(province: ProvinceData)
@warning_ignore("unused_signal")
signal battle_started(province: ProvinceData, attacker: FactionData)
@warning_ignore("unused_signal")
signal battle_ended(attacker_won: bool)
@warning_ignore("unused_signal")
signal ai_province_captured(province: ProvinceData, faction: FactionData)

# Turn system
@warning_ignore("unused_signal")
signal turn_started(faction: FactionData, turn_number: int)
@warning_ignore("unused_signal")
signal turn_ended(faction: FactionData)
@warning_ignore("unused_signal")
signal round_ended(round_number: int)
@warning_ignore("unused_signal")
signal dice_rolled(result: int)
@warning_ignore("unused_signal")
signal resources_changed(faction: FactionData)
@warning_ignore("unused_signal")
signal ap_changed(remaining: int)
@warning_ignore("unused_signal")
signal province_building_added(province: ProvinceData)

# Diplomacy
@warning_ignore("unused_signal")
signal attack_declared(province: ProvinceData, attacker: FactionData)
@warning_ignore("unused_signal")
signal hex_captured(coord: Vector2i, new_owner: FactionData, old_owner: FactionData)
@warning_ignore("unused_signal")
signal commander_moved(commander: CommanderData, new_hex: Vector2i)
@warning_ignore("unused_signal")
signal commander_spawned(commander: CommanderData)
@warning_ignore("unused_signal")
signal commander_destroyed(commander: CommanderData)
@warning_ignore("unused_signal")
signal war_declared(attacker: FactionData, target: FactionData)
@warning_ignore("unused_signal")
signal peace_made(initiator: FactionData, target: FactionData)
@warning_ignore("unused_signal")
signal diplomacy_panel_toggled
@warning_ignore("unused_signal")
signal battle_choice_needed(province: ProvinceData, is_defense: bool, attacker: FactionData)
