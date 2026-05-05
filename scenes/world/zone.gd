extends Area3D

signal zone_captured(zone: Node)
signal zone_lost(zone: Node)

@export var zone_name: String = "Zone"
@export var faction: String = "enemy"

var is_captured: bool = false
var zone_visual: MeshInstance3D

func _ready() -> void:
	zone_visual = $ZoneVisual

func _process(_delta: float) -> void:
	if is_captured:
		return
	var has_player := false
	var living_enemies := 0
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			has_player = true
		elif body.is_in_group("enemy") and not body.is_dead:
			living_enemies += 1
	if has_player and living_enemies == 0:
		_capture()

func _capture() -> void:
	is_captured = true
	faction = "player"
	zone_visual.get_active_material(0).albedo_color = Color(0, 1, 0, 0.4)
	print("%s captured!" % zone_name)
	zone_captured.emit(self)
