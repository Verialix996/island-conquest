extends Control

# ─── Child references ─────────────────────────────────────────────────────────
var _round_label:  Label
var _ap_label:     Label
var _dice_small:   Label   # persistent small roll display in top bar
var _res_labels:   Dictionary = {}   # "manpower" / "oil" / "steel" / "trade" → Label

var _dice_popup:   Label   # big animated number that fades out
var _dice_tween:   Tween = null

var _end_turn_btn:   Button
var _trade_popup:    PanelContainer
var _trade_btns:     Dictionary = {}   # resource key → Button

var _log_list:       VBoxContainer
var _log_scroll:     ScrollContainer
const _MAX_LOG: int  = 12

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
	EventBus.war_declared.connect(_on_war_declared)
	EventBus.peace_made.connect(_on_peace_made)
	EventBus.treaty_changed.connect(_on_treaty_changed)
	EventBus.betrayal_committed.connect(_on_betrayal_committed)
	EventBus.vassalage_started.connect(_on_vassalage_started)
	EventBus.tribute_paid.connect(_on_tribute_paid)
	EventBus.faction_collapsed.connect(_on_faction_collapsed)
	EventBus.hex_captured.connect(_on_hex_captured)
	EventBus.round_ended.connect(_on_round_ended)
	EventBus.commander_spawned.connect(_on_commander_spawned)
	EventBus.province_building_added.connect(_on_building_added)

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

	var trade_btn := Button.new()
	trade_btn.text = "Trade"
	trade_btn.custom_minimum_size = Vector2(70, 26)
	trade_btn.pressed.connect(_toggle_trade_popup)
	left.add_child(trade_btn)

	_build_trade_popup()

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

	# ── Event log ────────────────────────────────────────────────────────────
	_build_event_log()

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

# ─── Trade popup ─────────────────────────────────────────────────────────────
func _build_trade_popup() -> void:
	_trade_popup = PanelContainer.new()
	_trade_popup.visible = false
	# Position just below the top bar, left side
	_trade_popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_trade_popup.offset_top  = 44
	_trade_popup.offset_left = 12

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_trade_popup.add_child(vbox)

	var header := Label.new()
	header.text = "Spend 2 TRD → +1 resource"
	header.add_theme_font_size_override("font_size", 12)
	vbox.add_child(header)

	for entry in [["manpower", "+1 MAN"], ["oil", "+1 OIL"], ["steel", "+1 STL"]]:
		var btn := Button.new()
		btn.text = entry[1]
		btn.custom_minimum_size = Vector2(130, 28)
		var res_key: String = entry[0]
		btn.pressed.connect(func():
			DiplomacyManager.exchange_trade(TurnManager.FACTION_PLAYER, res_key)
			_refresh_trade_btns()
		)
		vbox.add_child(btn)
		_trade_btns[res_key] = btn

	add_child(_trade_popup)
	_refresh_trade_btns()

func _toggle_trade_popup() -> void:
	_trade_popup.visible = not _trade_popup.visible
	if _trade_popup.visible:
		_refresh_trade_btns()

func _refresh_trade_btns() -> void:
	var can_trade: bool = DiplomacyManager.can_exchange(TurnManager.FACTION_PLAYER)
	for btn in _trade_btns.values():
		(btn as Button).disabled = not can_trade

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
	_refresh_trade_btns()

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

# ─── Event log ────────────────────────────────────────────────────────────────
func _build_event_log() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.12, 0.82)
	bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bg.offset_top    = -210
	bg.offset_right  =  260
	bg.offset_bottom = -20
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.offset_top    = -210
	margin.offset_right  =  260
	margin.offset_bottom = -20
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Event Log"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_log_scroll)

	_log_list = VBoxContainer.new()
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_list.add_theme_constant_override("separation", 1)
	_log_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_scroll.add_child(_log_list)

func _log(text: String, color: Color = Color(0.85, 0.85, 0.85)) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_log_list.add_child(lbl)
	# Remove oldest entry when over limit
	if _log_list.get_child_count() > _MAX_LOG:
		_log_list.get_child(0).queue_free()
	# Scroll to bottom next frame
	await get_tree().process_frame
	_log_scroll.scroll_vertical = _log_scroll.get_v_scroll_bar().max_value

# ─── Event log signal handlers ────────────────────────────────────────────────
func _on_war_declared(attacker: FactionData, target: FactionData) -> void:
	_log(attacker.faction_name + " declared war on " + target.faction_name + "!",
		Color(1.0, 0.38, 0.28))

func _on_peace_made(initiator: FactionData, target: FactionData) -> void:
	_log(initiator.faction_name + " and " + target.faction_name + " made peace.",
		Color(0.45, 0.90, 0.55))

func _on_treaty_changed(faction_a: FactionData, faction_b: FactionData, relation: int) -> void:
	match relation:
		DiplomacyManager.Relation.ALLIANCE:
			_log(faction_a.faction_name + " allied with " + faction_b.faction_name + ".",
				Color(0.45, 0.70, 1.0))
		DiplomacyManager.Relation.TRADE_PACT:
			_log(faction_a.faction_name + " signed a trade pact with " + faction_b.faction_name + ".",
				Color(0.95, 0.65, 0.35))

func _on_betrayal_committed(betrayer: FactionData, target: FactionData) -> void:
	_log(betrayer.faction_name + " betrayed " + target.faction_name + "!",
		Color(1.0, 0.25, 0.20))

func _on_vassalage_started(vassal: FactionData, overlord: FactionData) -> void:
	_log(vassal.faction_name + " became a vassal of " + overlord.faction_name + ".",
		Color(0.75, 0.55, 1.0))

func _on_tribute_paid(vassal: FactionData, overlord: FactionData) -> void:
	if vassal == TurnManager.FACTION_PLAYER or overlord == TurnManager.FACTION_PLAYER:
		_log(vassal.faction_name + " paid tribute to " + overlord.faction_name + ".",
			Color(0.75, 0.55, 1.0))

func _on_faction_collapsed(faction: FactionData, conqueror: FactionData) -> void:
	_log(faction.faction_name + " collapsed under " + conqueror.faction_name + ".",
		Color(0.80, 0.45, 1.0))

func _on_hex_captured(coord: Vector2i, new_owner: FactionData, old_owner: FactionData) -> void:
	if old_owner == null or new_owner == null:
		return
	# Only log province-capital captures to avoid per-hex spam
	var province: ProvinceData = ProvinceGrid.get_province_for_hex(coord)
	if province == null or province.seed_hex != coord:
		return
	var col: Color = new_owner.color.lerp(Color.WHITE, 0.35)
	_log(new_owner.faction_name + " seized territory from " + old_owner.faction_name, col)

func _on_round_ended(round_number: int) -> void:
	_log("── Round " + str(round_number) + " ──", Color(0.45, 0.50, 0.60))

func _on_commander_spawned(commander: CommanderData) -> void:
	if commander.owner_faction == TurnManager.FACTION_BARBARIAN:
		_log("Barbarians have appeared!", Color(0.90, 0.70, 0.25))

func _on_building_added(province: ProvinceData) -> void:
	if province == null or province.owner_faction == null:
		return
	if province.owner_faction == TurnManager.FACTION_PLAYER:
		return
	var building: BuildingData = ProvinceGrid.get_hex_building(province.seed_hex)
	if building == null:
		return
	_log(province.owner_faction.faction_name + " built " + building.building_name,
		Color(0.55, 0.75, 1.0))

# ─── Helper ───────────────────────────────────────────────────────────────────
func _lbl(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
