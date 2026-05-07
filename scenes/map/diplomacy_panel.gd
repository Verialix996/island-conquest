extends Control

# _rows[FactionData] → { rel_lbl: Label, action_btn: Button }
var _rows: Dictionary = {}
var _card: Control = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false

	EventBus.diplomacy_panel_toggled.connect(_on_toggle)
	EventBus.war_declared.connect(func(_a, _b): if visible: _refresh_rows())
	EventBus.peace_made.connect(func(_a, _b):   if visible: _refresh_rows())
	EventBus.turn_started.connect(func(_f, _r): if visible: _refresh_rows())

func _on_toggle() -> void:
	visible = not visible
	if visible:
		_refresh_rows()

# Click outside the card → close
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _card != null and not _card.get_global_rect().has_point(event.global_position):
			visible = false

# ─── UI construction ──────────────────────────────────────────────────────────
func _build_ui() -> void:
	# Dark overlay — IGNORE so _gui_input on the outer panel catches outside clicks
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# CenterContainer lets the card auto-size and stay centered
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wrapper)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.17, 0.97)
	style.corner_radius_top_left    = 8
	style.corner_radius_top_right   = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)
	wrapper.add_child(card)
	_card = card

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# ── Title row ────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "Diplomacy"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.pressed.connect(func(): visible = false)
	title_row.add_child(close_btn)

	vbox.add_child(_sep())

	# ── One row per AI faction ────────────────────────────────────────────────
	var factions: Array = [TurnManager.FACTION_RED, TurnManager.FACTION_BLUE, TurnManager.FACTION_ORANGE]
	for faction in factions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", faction.color)
		dot.add_theme_font_size_override("font_size", 16)
		row.add_child(dot)

		var name_lbl := Label.new()
		name_lbl.text = faction.faction_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var rel_lbl := Label.new()
		rel_lbl.custom_minimum_size = Vector2(70, 0)
		rel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(rel_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 28)
		var f: FactionData = faction  # capture for lambda
		btn.pressed.connect(func(): _on_action_pressed(f))
		row.add_child(btn)

		_rows[faction] = {"rel_lbl": rel_lbl, "action_btn": btn}

	vbox.add_child(_sep())

	var note := Label.new()
	note.text = "Diplomacy costs 0 AP"
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note)

# ─── Data ─────────────────────────────────────────────────────────────────────
func _refresh_rows() -> void:
	var player     := TurnManager.FACTION_PLAYER
	var my_turn    := TurnManager.is_player_turn()

	for faction in _rows:
		var data: Dictionary = _rows[faction]
		var rel: int = DiplomacyManager.get_relation(player, faction)
		var rel_lbl: Label  = data["rel_lbl"]
		var btn:     Button = data["action_btn"]

		match rel:
			DiplomacyManager.Relation.PEACE:
				rel_lbl.text = "Peace"
				rel_lbl.add_theme_color_override("font_color", Color(0.40, 0.85, 0.40))
				btn.text = "Declare War"
				btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			DiplomacyManager.Relation.WAR:
				rel_lbl.text = "War"
				rel_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
				btn.text = "Offer Peace"
				btn.remove_theme_color_override("font_color")
			DiplomacyManager.Relation.ALLIANCE:
				rel_lbl.text = "Alliance"
				rel_lbl.add_theme_color_override("font_color", Color(0.40, 0.70, 1.0))
				btn.text = "Break Alliance"
				btn.remove_theme_color_override("font_color")

		btn.disabled = not my_turn

func _on_action_pressed(faction: FactionData) -> void:
	var player := TurnManager.FACTION_PLAYER
	match DiplomacyManager.get_relation(player, faction):
		DiplomacyManager.Relation.PEACE:
			DiplomacyManager.declare_war(player, faction)
		DiplomacyManager.Relation.WAR:
			DiplomacyManager.offer_peace(player, faction)
		DiplomacyManager.Relation.ALLIANCE:
			DiplomacyManager.offer_peace(player, faction)  # break → peace
	_refresh_rows()

# ─── Helper ───────────────────────────────────────────────────────────────────
func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(1, 1, 1, 0.10))
	return s
