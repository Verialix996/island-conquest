extends Control

# _rows[FactionData] → labels/buttons for each diplomacy card
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
	EventBus.treaty_changed.connect(func(_a, _b, _r): if visible: _refresh_rows())
	EventBus.vassalage_started.connect(func(_a, _b): if visible: _refresh_rows())
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
	card.custom_minimum_size = Vector2(620, 0)
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

	# ── One card per AI faction ───────────────────────────────────────────────
	var factions: Array[FactionData] = [TurnManager.FACTION_RED, TurnManager.FACTION_BLUE, TurnManager.FACTION_ORANGE]
	for faction: FactionData in factions:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		vbox.add_child(row)

		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		row.add_child(top)

		var dot := Label.new()
		dot.text = "●"
		dot.add_theme_color_override("font_color", faction.color)
		dot.add_theme_font_size_override("font_size", 16)
		top.add_child(dot)

		var name_lbl := Label.new()
		name_lbl.text = faction.faction_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_lbl)

		var rel_lbl := Label.new()
		rel_lbl.custom_minimum_size = Vector2(95, 0)
		rel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(rel_lbl)

		var info_lbl := Label.new()
		info_lbl.add_theme_font_size_override("font_size", 11)
		info_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.74))
		row.add_child(info_lbl)

		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		row.add_child(actions)

		var buttons: Dictionary = {}
		var action_defs: Array[Array] = [
			["war", "War"],
			["peace", "Peace"],
			["alliance", "Alliance"],
			["trade", "Trade Pact"],
			["vassal", "Vassalage"],
			["break", "Break"]
		]
		for entry: Array in action_defs:
			var btn := Button.new()
			btn.text = str(entry[1])
			btn.custom_minimum_size = Vector2(88, 26)
			var f: FactionData = faction
			var action: String = str(entry[0])
			btn.pressed.connect(func(): _on_action_pressed(f, action))
			actions.add_child(btn)
			buttons[action] = btn

		_rows[faction] = {
			"rel_lbl": rel_lbl,
			"info_lbl": info_lbl,
			"buttons": buttons
		}

	vbox.add_child(_sep())

	var note := Label.new()
	note.text = "Diplomacy costs 0 AP. Treaties resolve immediately."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note)

# ─── Data ─────────────────────────────────────────────────────────────────────
func _refresh_rows() -> void:
	var player: FactionData = TurnManager.FACTION_PLAYER
	var my_turn: bool = TurnManager.is_player_turn()

	for faction_key in _rows:
		var faction: FactionData = faction_key
		var data: Dictionary = _rows[faction]
		var rel: int = DiplomacyManager.get_relation(player, faction)
		var rel_lbl: Label  = data["rel_lbl"]
		var info_lbl: Label = data["info_lbl"]
		var buttons: Dictionary = data["buttons"]

		match rel:
			DiplomacyManager.Relation.PEACE:
				rel_lbl.text = "Peace"
				rel_lbl.add_theme_color_override("font_color", Color(0.40, 0.85, 0.40))
			DiplomacyManager.Relation.WAR:
				rel_lbl.text = "War"
				rel_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.30))
			DiplomacyManager.Relation.ALLIANCE:
				rel_lbl.text = "Alliance"
				rel_lbl.add_theme_color_override("font_color", Color(0.40, 0.70, 1.0))
			DiplomacyManager.Relation.TRADE_PACT:
				rel_lbl.text = "Trade Pact"
				rel_lbl.add_theme_color_override("font_color", Color(0.90, 0.65, 0.35))
			DiplomacyManager.Relation.VASSALAGE:
				if DiplomacyManager.is_vassal_of(faction, player):
					rel_lbl.text = "Vassal"
				elif DiplomacyManager.is_vassal_of(player, faction):
					rel_lbl.text = "Overlord"
				else:
					rel_lbl.text = "Vassalage"
				rel_lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 1.0))

		var province_count: int = _count_seed_provinces(faction)
		var trait_text: String = _trait_summary(faction)
		info_lbl.text = "Provinces: %d   Traits: %s" % [province_count, trait_text]

		var is_vassal_pair: bool = rel == DiplomacyManager.Relation.VASSALAGE
		for btn in buttons.values():
			(btn as Button).disabled = not my_turn
		(buttons["war"] as Button).disabled = not my_turn or rel == DiplomacyManager.Relation.WAR or is_vassal_pair
		(buttons["peace"] as Button).disabled = not my_turn or rel != DiplomacyManager.Relation.WAR or is_vassal_pair
		(buttons["alliance"] as Button).disabled = not my_turn or rel == DiplomacyManager.Relation.ALLIANCE or rel == DiplomacyManager.Relation.WAR or is_vassal_pair
		(buttons["trade"] as Button).disabled = not my_turn or rel == DiplomacyManager.Relation.TRADE_PACT or rel == DiplomacyManager.Relation.WAR or is_vassal_pair
		(buttons["vassal"] as Button).disabled = not my_turn or is_vassal_pair or province_count > 1
		(buttons["break"] as Button).disabled = not my_turn or rel == DiplomacyManager.Relation.PEACE or rel == DiplomacyManager.Relation.WAR

func _on_action_pressed(faction: FactionData, action: String) -> void:
	var player: FactionData = TurnManager.FACTION_PLAYER
	match action:
		"war":
			DiplomacyManager.declare_war(player, faction)
		"peace":
			DiplomacyManager.offer_peace(player, faction)
		"alliance":
			DiplomacyManager.propose_alliance(player, faction)
		"trade":
			DiplomacyManager.propose_trade_pact(player, faction)
		"vassal":
			DiplomacyManager.start_vassalage(faction, player)
		"break":
			DiplomacyManager.break_treaty(player, faction)
	_refresh_rows()

# ─── Helper ───────────────────────────────────────────────────────────────────
func _sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(1, 1, 1, 0.10))
	return s

func _trait_summary(faction: FactionData) -> String:
	if faction.traits.is_empty():
		return "None"
	var names: PackedStringArray = PackedStringArray()
	for trait_item in faction.traits:
		var trait_data := trait_item as FactionTrait
		if trait_data != null:
			names.append(trait_data.trait_name)
	return ", ".join(names)

func _count_seed_provinces(faction: FactionData) -> int:
	var count := 0
	for p: ProvinceData in ProvinceGrid.provinces:
		if ProvinceGrid.get_hex_owner(p.seed_hex) == faction:
			count += 1
	return count
