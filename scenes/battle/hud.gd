extends CanvasLayer

var health_bar: ProgressBar
var ammo_label: Label
var player: Node3D

var _ticket_label: Label = null
var _tracker = null

func _ready() -> void:
	health_bar = $HealthBar
	ammo_label = $AmmoLabel
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)
		_connect_weapon_signals()

	if BattleContext.is_battle_mode():
		_ticket_label = Label.new()
		_ticket_label.add_theme_font_size_override("font_size", 15)
		_ticket_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_ticket_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_ticket_label.offset_left  = -220
		_ticket_label.offset_top   = 10
		_ticket_label.offset_right = -10
		_ticket_label.offset_bottom = 36
		add_child(_ticket_label)

func _process(_delta: float) -> void:
	if _ticket_label == null:
		return
	if _tracker == null:
		_tracker = get_tree().get_first_node_in_group("battle_tracker")
	if _tracker != null:
		_ticket_label.text = "Allies: %d   Enemies: %d" % [_tracker.player_tickets, _tracker.enemy_tickets]

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
