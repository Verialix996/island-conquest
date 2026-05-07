extends Control

# ─── Constants ────────────────────────────────────────────────────────────────
const PANEL_WIDTH  := 270.0
const SLIDE_TIME   := 0.22

# All buildable structures. Each entry is a plain Dictionary so no extra Resource
# files are needed — we create BuildingData instances on demand when purchasing.
const BUILDING_CATALOG := [
	{"type": &"barracks",     "display": "Barracks",     "cost": {"manpower": 20},
	 "desc": "+3 garrison",   "garrison": 3, "defense": 0, "income": 0},
	{"type": &"wall",         "display": "Wall",         "cost": {"steel": 15},
	 "desc": "+2 defense",    "garrison": 0, "defense": 2, "income": 0},
	{"type": &"turret",       "display": "Turret",       "cost": {"steel": 10, "oil": 10},
	 "desc": "+1 def+turret", "garrison": 0, "defense": 1, "income": 0},
	{"type": &"energy_plant", "display": "Energy Plant", "cost": {"oil": 20},
	 "desc": "+5 income",     "garrison": 0, "defense": 0, "income": 5},
]

# ─── State ────────────────────────────────────────────────────────────────────
var _pinned := false
var _tween: Tween = null
var _current_province: ProvinceData = null
var _current_tile_terrain: ProvinceData.TerrainType = ProvinceData.TerrainType.PLAINS
var _current_coord: Vector2i = Vector2i(-1, -1)

# ─── Child references (populated in _build_ui) ────────────────────────────────
var _name_label:       Label
var _close_btn:        Button
var _owner_label:      Label
var _tile_terrain_val: Label
var _resource_val:     Label
var _dice_val:         Label
var _garrison_val:     Label
var _buildings_box:    VBoxContainer

var _build_sep:        HSeparator
var _build_header:     Label
var _build_rows:       VBoxContainer

# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_ui()
	var vp := get_viewport_rect().size
	size = Vector2(PANEL_WIDTH, vp.y)
	position = Vector2(vp.x, 0)

# ─── Public API ───────────────────────────────────────────────────────────────
func show_province(province: ProvinceData, tile_terrain: ProvinceData.TerrainType,
		coord: Vector2i, pin: bool = false) -> void:
	if _pinned and not pin:
		return

	_populate(province, tile_terrain, coord)

	if pin:
		_pinned = true
		_close_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	else:
		_pinned = false
		_close_btn.remove_theme_color_override("font_color")

	_slide_in()

func close() -> void:
	if not _pinned:
		_slide_out()

# ─── UI construction ─────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.12, 0.16, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var accent := ColorRect.new()
	accent.color = Color(0.40, 0.55, 0.80, 0.90)
	accent.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	accent.custom_minimum_size = Vector2(3, 0)
	accent.offset_right = 3
	add_child(accent)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Title row ────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 17)
	title_row.add_child(_name_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.pressed.connect(_on_close_pressed)
	title_row.add_child(_close_btn)

	vbox.add_child(_make_separator())

	# ── Owner ────────────────────────────────────────────────────────────────
	_owner_label = Label.new()
	_owner_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_owner_label)

	vbox.add_child(_make_separator())

	# ── Info rows ────────────────────────────────────────────────────────────
	_tile_terrain_val = _add_row(vbox, "Hex terrain")
	_resource_val     = _add_row(vbox, "Resource")
	_dice_val         = _add_row(vbox, "Produces on roll")
	_garrison_val     = _add_row(vbox, "Garrison")

	vbox.add_child(_make_separator())

	# ── Existing buildings ────────────────────────────────────────────────────
	var bld_header := Label.new()
	bld_header.text = "Buildings"
	bld_header.add_theme_font_size_override("font_size", 13)
	bld_header.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(bld_header)

	_buildings_box = VBoxContainer.new()
	_buildings_box.add_theme_constant_override("separation", 3)
	vbox.add_child(_buildings_box)

	# ── Build section (shown only when player owns the province) ──────────────
	_build_sep = _make_separator()
	vbox.add_child(_build_sep)

	_build_header = Label.new()
	_build_header.text = "Build  (1 AP)"
	_build_header.add_theme_font_size_override("font_size", 13)
	_build_header.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(_build_header)

	_build_rows = VBoxContainer.new()
	_build_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_build_rows)

# ─── Data population ──────────────────────────────────────────────────────────
func _populate(province: ProvinceData, tile_terrain: ProvinceData.TerrainType, coord: Vector2i) -> void:
	_current_province     = province
	_current_tile_terrain = tile_terrain
	_current_coord        = coord

	_name_label.text = province.province_name

	# Ownership is per-tile now
	var hex_owner: FactionData = ProvinceGrid.get_hex_owner(coord)
	if hex_owner != null:
		_owner_label.text = "Owner:  " + hex_owner.faction_name
		_owner_label.add_theme_color_override("font_color", hex_owner.color.lightened(0.25))
	else:
		_owner_label.text = "Owner:  Unowned"
		_owner_label.remove_theme_color_override("font_color")

	_tile_terrain_val.text = _terrain_name(tile_terrain)
	_resource_val.text     = _resource_name(province.resource_type)
	_dice_val.text         = str(province.dice_number)
	_garrison_val.text     = str(ProvinceGrid.get_province_garrison(province)) + " units"

	# Show the building on this specific tile
	for child in _buildings_box.get_children():
		child.queue_free()

	var hex_building: BuildingData = ProvinceGrid.get_hex_building(coord)
	if hex_building == null:
		var lbl := Label.new()
		lbl.text = "None"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
		_buildings_box.add_child(lbl)
	else:
		var lbl := Label.new()
		lbl.text = "• " + hex_building.building_name
		_buildings_box.add_child(lbl)

	_populate_build_section()

func _populate_build_section() -> void:
	for child in _build_rows.get_children():
		child.queue_free()

	var is_player_owned := (_current_coord != Vector2i(-1, -1)
		and ProvinceGrid.get_hex_owner(_current_coord) == TurnManager.FACTION_PLAYER)
	_build_sep.visible    = is_player_owned
	_build_header.visible = is_player_owned
	_build_rows.visible   = is_player_owned

	if not is_player_owned:
		return

	for entry in BUILDING_CATALOG:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_build_rows.add_child(row)

		# Name + description
		var name_lbl := Label.new()
		name_lbl.text = entry["display"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		# Cost label
		var cost_lbl := Label.new()
		cost_lbl.text = _cost_text(entry["cost"])
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.50))
		row.add_child(cost_lbl)

		# Build button — one building per hex, so if any exists all are locked
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(48, 24)
		var hex_occupied: bool  = ProvinceGrid.get_hex_building(_current_coord) != null
		var can_pay: bool       = TurnManager.can_afford(TurnManager.FACTION_PLAYER, entry["cost"])
		var player_turn: bool   = TurnManager.is_player_turn()
		var has_ap: bool        = TurnManager.ap_remaining >= 1

		if hex_occupied:
			btn.text = "✓"
			btn.disabled = true
		elif not player_turn or not has_ap or not can_pay:
			btn.text = "Build"
			btn.disabled = true
		else:
			btn.text = "Build"
			btn.disabled = false
			btn.pressed.connect(_on_build_pressed.bind(entry))

		row.add_child(btn)

# ─── Build action ─────────────────────────────────────────────────────────────
func _on_build_pressed(entry: Dictionary) -> void:
	if _current_coord == Vector2i(-1, -1):
		return
	if not TurnManager.spend_ap(1):
		return
	TurnManager.spend_resources(TurnManager.FACTION_PLAYER, entry["cost"])

	var b := BuildingData.new()
	b.building_type        = entry["type"]
	b.building_name        = entry["display"]
	b.description          = entry["desc"]
	b.cost                 = entry["cost"]
	b.extra_defender_units = entry["garrison"]
	b.defense_bonus        = entry["defense"]
	b.income_bonus         = entry["income"]

	# Place on this specific tile
	ProvinceGrid.place_building(_current_coord, b)
	EventBus.province_building_added.emit(_current_province)
	_populate(_current_province, _current_tile_terrain, _current_coord)

# ─── Pin / close ──────────────────────────────────────────────────────────────
func _on_close_pressed() -> void:
	_pinned = false
	_close_btn.remove_theme_color_override("font_color")
	_slide_out()

# ─── Slide animation ──────────────────────────────────────────────────────────
func _slide_in() -> void:
	_animate_to(get_viewport_rect().size.x - PANEL_WIDTH)

func _slide_out() -> void:
	_animate_to(get_viewport_rect().size.x)

func _animate_to(target_x: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "position:x", target_x, SLIDE_TIME)

# ─── Helpers ──────────────────────────────────────────────────────────────────
func _add_row(parent: VBoxContainer, key: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var key_lbl := Label.new()
	key_lbl.text = key + ":"
	key_lbl.add_theme_color_override("font_color", Color(0.60, 0.62, 0.65))
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	return val_lbl

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.08))
	return sep

func _cost_text(cost: Dictionary) -> String:
	var parts := []
	for key in cost:
		var abbr: String = str(key).substr(0, 3).to_upper()
		parts.append(str(cost[key]) + " " + abbr)
	return " + ".join(parts)

func _terrain_name(t: ProvinceData.TerrainType) -> String:
	match t:
		ProvinceData.TerrainType.PLAINS:    return "Plains"
		ProvinceData.TerrainType.FOREST:    return "Forest"
		ProvinceData.TerrainType.URBAN:     return "Urban"
		ProvinceData.TerrainType.DESERT:    return "Desert"
		ProvinceData.TerrainType.MOUNTAINS: return "Mountains"
	return "?"

func _resource_name(r: ProvinceData.ResourceType) -> String:
	match r:
		ProvinceData.ResourceType.MANPOWER: return "Manpower"
		ProvinceData.ResourceType.OIL:      return "Oil"
		ProvinceData.ResourceType.STEEL:    return "Steel"
		ProvinceData.ResourceType.TRADE:    return "Trade"
	return "?"
