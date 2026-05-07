class_name FactionTrait
extends Resource

enum TraitType {
	AGGRESSIVE,
	EXPANSIONIST,
	BUILDER,
	TRADER,
	DIPLOMATIC,
	ISOLATIONIST,
	MILITARIST,
	OPPORTUNIST,
	PACIFIST,
	ZEALOT
}

@export var trait_type: TraitType = TraitType.AGGRESSIVE
@export var trait_name: String = ""
@export var description: String = ""

# AI behavioral modifiers — read by AIDirector
@export var war_declaration_bias: float = 0.0  # added to base 0.30 war chance
@export var expansion_priority: bool = false    # claim neutrals before attacking
@export var build_priority: bool = false        # place buildings each turn
@export var trade_active: bool = false          # attempt trade exchanges
@export var recruit_bonus: int = 0             # extra units recruitable per turn
@export var peace_bias: float = 0.0            # added to peace-offer chance per turn
