class_name BuildingData
extends Resource

@export var building_type: StringName = &"generic"
@export var building_name: String = ""
@export var description: String = ""
@export var cost: Dictionary = {}           # e.g. {"manpower": 20} or {"steel": 10, "oil": 10}
@export var income_bonus: int = 0
@export var defense_bonus: int = 0
@export var extra_defender_units: int = 0
@export var cover_density_add: float = 0.0
