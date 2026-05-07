extends Control

# ─── Child references ─────────────────────────────────────────────────────────
var _round_label:  Label
var _ap_label:     Label
var _dice_small:   Label   # persistent small roll display in top bar
var _res_labels:   Dictionary = {}   # "manpower" / "oil" / "steel" / "trade" → Label

var _dice_popup:   Label   # big animated number that fades out
var _dice_tween:   Tween = null

var _end_turn_btn: Button

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	# CanvasLayer has no intrinsic size, so anchors collapse to (0,0) unless we
	# explicitly size this Control to the viewport first.
	size = get_viewport_rect().size

	_build_ui()

	EventBus.turn_started.connect(_on_turn_started)
	EventBus.dice_rolled.connect(_on_dice_rolled)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.ap_changed.connect(_on_ap_changed)

# ─── UI construction ──────────────────────────────────────────────────────────
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # don't block map clicks

	# ── Top bar ───────────────────────────────────────────────────────────────
	var top_bg := ColorRect.new()
	top_bg.color = Color(0.08, 0.10, 0.14, 0.90)
	top_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bg.offset_bottom = 38
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bg)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.offset_bottom = 38
	top_margin.add_theme_constant_override("margin_left",   12)
	top_margin.add_theme_constant_override("margin_right",  12)
	top_margin.add_theme_constant_override("margin_top",    6)
	top_margin.add_theme_constant_override("margin_bottom", 6)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_margin)

	var top_bar := HBoxContainer.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top_bar)

	# Left: round + AP
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 18)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(left)

	_round_label = _lbl("Round 1", 14)
	left.add_child(_round_label)

	_ap_label = _lbl("AP: 3", 14)
	_ap_label.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55))
	left.add_child(_ap_label)

	var dip_btn := Button.new()
	dip_btn.text = "Diplomacy"
	dip_btn.custom_minimum_size = Vector2(90, 26)
	dip_btn.pressed.connect(func(): EventBus.diplomacy_panel_toggled.emit())
	left.add_child(dip_btn)

	# Center: last dice roll
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(center)

	_dice_small = _lbl("", 14)
	_dice_small.add_theme_color_override("font_color", Color(0.95, 0.88, 0.45))
	center.add_child(_dice_small)

	# Right: resources
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 16)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(right)

	for entry in [["manpower", "MAN 0", Color(0.85, 0.85, 0.55)],
				  ["oil",      "OIL 0", Color(0.55, 0.85, 0.85)],
				  ["steel",    "STL 0", Color(0.70, 0.70, 0.80)],
				  ["trade",    "TRD 0", Color(0.85, 0.65, 0.45)]]:
		var lbl := _lbl(entry[1], 13)
		lbl.add_theme_color_override("font_color", entry[2])
		right.add_child(lbl)
		_res_labels[entry[0]] = lbl

	# ── Dice popup (big animated number) ─────────────────────────────────────
	_dice_popup = Label.new()
	_dice_popup.add_theme_font_size_override("font_size", 88)
	_dice_popup.add_theme_color_override("font_color", Color(1.0, 0.92, 0.30))
	_dice_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_popup.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dice_popup.custom_minimum_size  = Vector2(180, 130)
	_dice_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_popup.modulate.a = 0.0
	# Centered in the viewport (info panel is on the right, so roughly fine)
	_dice_popup.set_anchors_preset(Control.PRESET_CENTER)
	_dice_popup.offset_left   = -90
	_dice_popup.offset_top    = -65
	_dice_popup.offset_right  =  90
	_dice_popup.offset_bottom =  65
	add_child(_dice_popup)

	# ── End Turn button ───────────────────────────────────────────────────────
	_end_turn_btn = Button.new()
	_end_turn_btn.text = "End Turn"
	_end_turn_btn.custom_minimum_size = Vector2(150, 46)
	# Bottom-right, sitting above the info panel footer area
	_end_turn_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_end_turn_btn.offset_left   = -170
	_end_turn_btn.offset_top    = -66
	_end_turn_btn.offset_right  = -20
	_end_turn_btn.offset_bottom = -20
	_end_turn_btn.pressed.connect(TurnManager.end_player_turn)
	add_child(_end_turn_btn)

# ─── Signal handlers ──────────────────────────────────────────────────────────
func _on_turn_started(faction: FactionData, round_num: int) -> void:
	_round_label.text = "Round " + str(round_num)
	_ap_label.text    = "AP: "   + str(TurnManager.ap_remaining)
	_end_turn_btn.disabled = not TurnManager.is_player_turn()

func _on_dice_rolled(result: int) -> void:
	# Only show visual feedback on the player's turn
	if not TurnManager.is_player_turn():
		return
	_dice_small.text = "Roll: " + str(result)
	_show_dice_popup(result)

func _on_ap_changed(remaining: int) -> void:
	_ap_label.text = "AP: " + str(remaining)

func _on_resources_changed(faction: FactionData) -> void:
	if faction != TurnManager.FACTION_PLAYER:
		return
	_res_labels["manpower"].text = "MAN " + str(faction.resources.get("manpower", 0))
	_res_labels["oil"].text      = "OIL " + str(faction.resources.get("oil",      0))
	_res_labels["steel"].text    = "STL " + str(faction.resources.get("steel",    0))
	_res_labels["trade"].text    = "TRD " + str(faction.resources.get("trade",    0))

# ─── Dice popup animation ────────────────────────────────────────────────────
func _show_dice_popup(result: int) -> void:
	_dice_popup.text = str(result)
	_dice_popup.pivot_offset = _dice_popup.custom_minimum_size / 2.0
	_dice_popup.scale = Vector2(0.4, 0.4)
	_dice_popup.modulate.a = 1.0

	if _dice_tween:
		_dice_tween.kill()
	_dice_tween = create_tween()
	# Pop in
	_dice_tween.tween_property(_dice_popup, "scale", Vector2.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hold
	_dice_tween.tween_interval(1.1)
	# Fade out
	_dice_tween.tween_property(_dice_popup, "modulate:a", 0.0, 0.45)

# ─── Helper ───────────────────────────────────────────────────────────────────
func _lbl(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
