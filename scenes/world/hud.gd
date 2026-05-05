extends CanvasLayer

var health_bar: ProgressBar
var ammo_label: Label
var player: Node3D

func _ready() -> void:
	health_bar = $HealthBar
	ammo_label = $AmmoLabel
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		# Connect to first weapon's ammo signal
		_connect_weapon_signals()

func _connect_weapon_signals() -> void:
	for child in player.get_children():
		if child is Node3D and child.has_method("fire"):
			child.ammo_changed.connect(_on_ammo_changed)

func _on_health_changed(parts: Array) -> void:
	var total_current: float = 0.0
	var total_max: float = 0.0
	for part in parts:
		total_current += part.current_health
		total_max += part.max_health
	if total_max > 0:
		health_bar.value = (total_current / total_max) * 100.0

func _on_ammo_changed(current_mag: int, mags_left: int) -> void:
	ammo_label.text = "%d / %d" % [current_mag, mags_left]
