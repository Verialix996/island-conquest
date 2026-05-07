class_name CommanderData
extends Resource

@export var commander_name: String = ""
@export var owner_faction: FactionData = null

# Runtime position on the hex grid — not exported, set at spawn time
var current_hex: Vector2i = Vector2i.ZERO
var has_attacked: bool = false   # set when attack is declared; blocks further orders this turn

var strength: int = 0        # current unit count
var max_strength: int = 10   # hard cap
const RECRUIT_CAP: int = 2   # max units recruitble per turn (before trait bonuses)
