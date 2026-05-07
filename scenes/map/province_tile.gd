class_name ProvinceT
extends Control

signal tile_clicked(province: ProvinceData, tile_terrain: ProvinceData.TerrainType, coord: Vector2i)
signal tile_right_clicked(province: ProvinceData, tile_terrain: ProvinceData.TerrainType, coord: Vector2i)

var hex_coord: Vector2i = Vector2i.ZERO
var province: ProvinceData = null
var terrain: ProvinceData.TerrainType = ProvinceData.TerrainType.PLAINS
var is_seed: bool = false   # true = this hex shows the dice number
var _move_highlight:   bool = false
var _attack_highlight: bool = false
var _claim_highlight:  bool = false

func setup(coord: Vector2i) -> void:
	hex_coord = coord
	province = ProvinceGrid.get_province_for_hex(coord)
	terrain = ProvinceGrid.hex_terrain.get(coord, ProvinceData.TerrainType.PLAINS)
	is_seed = (province != null and province.seed_hex == coord)
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func set_move_highlight(v: bool) -> void:
	_move_highlight = v
	queue_redraw()

func set_attack_highlight(v: bool) -> void:
	_attack_highlight = v
	queue_redraw()

func set_claim_highlight(v: bool) -> void:
	_claim_highlight = v
	queue_redraw()

# Brief golden flash when this tile's province produces resources on a dice roll.
func flash_produce() -> void:
	modulate = Color(1.8, 1.6, 0.4, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.7).set_ease(Tween.EASE_IN)

func _draw() -> void:
	var center := size / 2.0
	var r := size.y / 2.0

	# Oversized fill (+1 px) closes the sub-pixel gap between adjacent tile bounds
	var pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 90.0)
		pts.append(center + Vector2(cos(angle), sin(angle)) * (r + 1.0))

	var fill := _terrain_color()
	var owner: FactionData = ProvinceGrid.get_hex_owner(hex_coord)
	if owner != null:
		fill = fill.lerp(owner.color, 0.40)
	draw_polygon(pts, PackedColorArray([fill]))

	# Move-to highlight: white overlay
	if _move_highlight:
		draw_polygon(pts, PackedColorArray([Color(1.0, 1.0, 1.0, 0.30)]))
	# Claim neutral highlight: gold overlay
	if _claim_highlight:
		draw_polygon(pts, PackedColorArray([Color(1.0, 0.85, 0.10, 0.35)]))
	# Attack target highlight: orange overlay
	if _attack_highlight:
		draw_polygon(pts, PackedColorArray([Color(1.0, 0.45, 0.10, 0.40)]))
	# Contested: red overlay when an attack has been declared on this province
	if province != null and province.is_contested:
		draw_polygon(pts, PackedColorArray([Color(1.0, 0.10, 0.10, 0.35)]))

	# Borders are drawn by ProvinceBorderLayer on top of all tiles — not here.

	# Building indicator — small letter in the bottom-right area of the hex
	var building: BuildingData = ProvinceGrid.get_hex_building(hex_coord)
	if building != null:
		var bfont  := ThemeDB.fallback_font
		var bfs    := int(r * 0.38)
		var letter := building.building_name.left(1).to_upper()
		var btw    := bfont.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		var bpos   := center + Vector2(r * 0.35 - btw / 2.0, r * 0.55)
		draw_string(bfont, bpos + Vector2(1, 1), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color(0, 0, 0, 0.7))
		draw_string(bfont, bpos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color.WHITE)

	# On the seed hex, draw the dice number in the center
	if is_seed and province != null and province.dice_number > 0:
		var font := ThemeDB.fallback_font
		var font_size := int(r * 0.6)
		var label := str(province.dice_number)
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var text_pos := center + Vector2(-text_w / 2.0, font_size * 0.35)
		# Shadow for readability
		draw_string(font, text_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and province != null:
		if event.button_index == MOUSE_BUTTON_LEFT:
			tile_clicked.emit(province, terrain, hex_coord)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			tile_right_clicked.emit(province, terrain, hex_coord)

func _terrain_color() -> Color:
	match terrain:
		ProvinceData.TerrainType.PLAINS:    return Color(0.58, 0.76, 0.38)
		ProvinceData.TerrainType.FOREST:    return Color(0.13, 0.45, 0.13)
		ProvinceData.TerrainType.URBAN:     return Color(0.52, 0.52, 0.58)
		ProvinceData.TerrainType.DESERT:    return Color(0.87, 0.76, 0.42)
		ProvinceData.TerrainType.MOUNTAINS: return Color(0.42, 0.38, 0.33)
	return Color.DARK_GRAY
