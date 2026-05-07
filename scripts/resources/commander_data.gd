class_name CommanderData
extends Resource

@export var commander_name: String = ""
@export var owner_faction: FactionData = null

# Runtime position on the hex grid — not exported, set at spawn time
var current_hex: Vector2i = Vector2i.ZERO
var has_attacked: bool = false   # set when attack is declared; blocks further orders this turn
