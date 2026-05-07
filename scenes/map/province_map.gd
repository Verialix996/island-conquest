extends Node2D

const PROVINCE_TILE        = preload("res://scenes/map/province_tile.tscn")
const BORDER_LAYER_GD      = preload("res://scenes/map/province_border_layer.gd")
const INFO_PANEL_SCN       = preload("res://scenes/map/province_info_panel.tscn")
const MAP_HUD_SCN          = preload("res://scenes/map/map_hud.tscn")
const COMMANDER_TOKEN_SCN  = preload("res://scenes/map/commander_token.tscn")
const DIPLOMACY_PANEL_SCN  = preload("res://scenes/map/diplomacy_panel.tscn")

const HEX_RADIUS := 40.0
const HEX_W := HEX_RADIUS * 1.7321
const HEX_H := HEX_RADIUS * 2.0

var tile_nodes: Dictionary = {}
var _info_panel: Control = null
var _game_over: bool = false

# ─── Commander state ──────────────────────────────────────────────────────────
var _commander_tokens:     Dictionary = {}
var _selected_commander:   CommanderData = null
var _highlighted_move_hexes:   Array[Vector2i] = []
var _highlighted_attack_hexes: Array[Vector2i] = []
var _highlighted_claim_hexes:  Array[Vector2i] = []

func _ready() -> void:
	# Province data must exist before _build_grid() so tiles get valid province refs
	# (province_tile._gui_input guards on `province != null` before emitting clicks).
	if not BattleContext.returning_from_battle:
		ProvinceGrid.initialize()
		TurnManager.reset_state()
		DiplomacyManager.reset_state()

	_build_grid()
	_build_ui()
	EventBus.province_captured.connect(_on_province_captured)
	EventBus.hex_captured.connect(_on_hex_captured)
	EventBus.dice_rolled.connect(_on_dice_rolled)
	EventBus.commander_moved.connect(_on_commander_moved)
	EventBus.commander_spawned.connect(_on_commander_spawned)
	EventBus.commander_destroyed.connect(_on_commander_destroyed)

	if BattleContext.returning_from_battle:
		BattleContext.returning_from_battle = false
		for tile in tile_nodes.values():
			(tile as ProvinceT).refresh()
		_spawn_commanders()
		if BattleContext.was_defense:
			BattleContext.was_defense = false
			TurnManager.resume_after_defense_battle()
		else:
			TurnManager.resume_after_battle()
		TurnManager.refresh_hud()
	else:
		TurnManager.start_game()
		_spawn_commanders()

func _build_grid() -> void:
	for y in ProvinceGrid.GRID_H:
		for x in ProvinceGrid.GRID_W:
			var coord := Vector2i(x, y)
			var tile: ProvinceT = PROVINCE_TILE.instantiate()
			var px := x * HEX_W + (y % 2) * (HEX_W / 2.0)
			var py := y * HEX_H * 0.75
			tile.position = Vector2(px, py)
			tile.size = Vector2(HEX_W, HEX_H)
			tile.setup(coord)
			tile.tile_clicked.connect(_on_tile_clicked)
			tile.tile_right_clicked.connect(_on_tile_right_clicked)
			add_child(tile)
			tile_nodes[coord] = tile

	var border_layer := Node2D.new()
	border_layer.set_script(BORDER_LAYER_GD)
	add_child(border_layer)

func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	_info_panel = INFO_PANEL_SCN.instantiate()
	ui_layer.add_child(_info_panel)

	var hud := MAP_HUD_SCN.instantiate()
	ui_layer.add_child(hud)

	var dip := DIPLOMACY_PANEL_SCN.instantiate()
	ui_layer.add_child(dip)

# ─── Commander spawning ───────────────────────────────────────────────────────
func _spawn_commanders() -> void:
	for commander in TurnManager.commanders:
		_spawn_token(commander)

func _spawn_token(commander: CommanderData) -> void:
	var token: CommanderToken = COMMANDER_TOKEN_SCN.instantiate()
	token.setup(commander)
	token.position = _token_pos(commander.current_hex)
	token.token_clicked.connect(_on_token_clicked)
	add_child(token)
	_commander_tokens[commander] = token

func _token_pos(coord: Vector2i) -> Vector2:
	if not tile_nodes.has(coord):
		return Vector2.ZERO
	var tile: ProvinceT = tile_nodes[coord]
	return tile.position + tile.size / 2.0 - Vector2(CommanderToken.TOKEN_SIZE / 2.0, CommanderToken.TOKEN_SIZE / 2.0)

# ─── Commander selection / movement / attack ──────────────────────────────────
func _on_token_clicked(commander: CommanderData) -> void:
	if _game_over:
		return
	if commander.owner_faction != TurnManager.FACTION_PLAYER:
		return
	if not TurnManager.is_player_turn():
		return
	if commander.has_attacked:
		return   # committed to battle this turn — no further orders
	if _selected_commander == commander:
		_deselect_commander()
		return
	_deselect_commander()
	_selected_commander = commander
	_commander_tokens[commander].set_selected(true)

	for nb in ProvinceGrid.get_hex_neighbors(commander.current_hex):
		var nb_owner: FactionData = ProvinceGrid.get_hex_owner(nb)
		if nb_owner == TurnManager.FACTION_PLAYER:
			tile_nodes[nb].set_move_highlight(true)
			_highlighted_move_hexes.append(nb)
		elif nb_owner == null:
			tile_nodes[nb].set_claim_highlight(true)
			_highlighted_claim_hexes.append(nb)
		elif DiplomacyManager.are_at_war(TurnManager.FACTION_PLAYER, nb_owner) \
				and TurnManager.ap_remaining >= 2:
			tile_nodes[nb].set_attack_highlight(true)
			_highlighted_attack_hexes.append(nb)

func _deselect_commander() -> void:
	if _selected_commander != null and _commander_tokens.has(_selected_commander):
		_commander_tokens[_selected_commander].set_selected(false)
	for coord in _highlighted_move_hexes:
		if tile_nodes.has(coord):
			tile_nodes[coord].set_move_highlight(false)
	for coord in _highlighted_attack_hexes:
		if tile_nodes.has(coord):
			tile_nodes[coord].set_attack_highlight(false)
	for coord in _highlighted_claim_hexes:
		if tile_nodes.has(coord):
			tile_nodes[coord].set_claim_highlight(false)
	_highlighted_move_hexes.clear()
	_highlighted_attack_hexes.clear()
	_highlighted_claim_hexes.clear()
	_selected_commander = null

func _move_commander(commander: CommanderData, target_hex: Vector2i) -> void:
	if not TurnManager.spend_ap(1):
		return
	commander.current_hex = target_hex
	if _commander_tokens.has(commander):
		_commander_tokens[commander].position = _token_pos(target_hex)
	_deselect_commander()

func _claim_neutral(coord: Vector2i) -> void:
	if not TurnManager.spend_ap(1):
		return
	var old_owner: FactionData = ProvinceGrid.get_hex_owner(coord)
	ProvinceGrid.capture_hex(coord, TurnManager.FACTION_PLAYER)
	EventBus.hex_captured.emit(coord, TurnManager.FACTION_PLAYER, old_owner)
	if _selected_commander != null:
		_selected_commander.current_hex = coord
		if _commander_tokens.has(_selected_commander):
			_commander_tokens[_selected_commander].position = _token_pos(coord)
	_deselect_commander()

func _declare_attack(target_hex: Vector2i) -> void:
	var province := ProvinceGrid.get_province_for_hex(target_hex)
	if province == null:
		return
	if not TurnManager.spend_ap(2):
		return
	province.is_contested      = true
	province.attacker_faction  = TurnManager.FACTION_PLAYER
	BattleContext.target_hex   = target_hex
	if _selected_commander != null:
		_selected_commander.has_attacked = true
	EventBus.attack_declared.emit(province, TurnManager.FACTION_PLAYER)
	if tile_nodes.has(target_hex):
		tile_nodes[target_hex].refresh()
	_deselect_commander()

# ─── Tile input handlers ──────────────────────────────────────────────────────
func _on_tile_clicked(province: ProvinceData, tile_terrain: ProvinceData.TerrainType, coord: Vector2i) -> void:
	if _game_over:
		return
	if _selected_commander != null:
		if coord in _highlighted_attack_hexes:
			_declare_attack(coord)
		elif coord in _highlighted_move_hexes:
			_move_commander(_selected_commander, coord)
		elif coord in _highlighted_claim_hexes:
			_claim_neutral(coord)
		else:
			_deselect_commander()
			_info_panel.show_province(province, tile_terrain, coord, false)
	else:
		_info_panel.show_province(province, tile_terrain, coord, false)

func _on_tile_right_clicked(province: ProvinceData, tile_terrain: ProvinceData.TerrainType, coord: Vector2i) -> void:
	_deselect_commander()
	_info_panel.show_province(province, tile_terrain, coord, true)

# ─── Dice roll flash ──────────────────────────────────────────────────────────
func _on_dice_rolled(result: int) -> void:
	if not TurnManager.is_player_turn():
		return
	for p: ProvinceData in ProvinceGrid.provinces:
		if ProvinceGrid.get_hex_owner(p.seed_hex) == TurnManager.FACTION_PLAYER and p.dice_number == result:
			for coord in p.hex_tiles:
				if tile_nodes.has(coord):
					tile_nodes[coord].flash_produce()

# ─── Capture listeners ────────────────────────────────────────────────────────
func _on_province_captured(province: ProvinceData, _new: FactionData, _old: FactionData) -> void:
	for coord in province.hex_tiles:
		if tile_nodes.has(coord):
			tile_nodes[coord].refresh()
	_check_victory_condition()

func _on_hex_captured(coord: Vector2i, _new: FactionData, _old: FactionData) -> void:
	if tile_nodes.has(coord):
		tile_nodes[coord].refresh()
	_check_victory_condition()

func _on_commander_moved(commander: CommanderData, new_hex: Vector2i) -> void:
	if _commander_tokens.has(commander):
		_commander_tokens[commander].position = _token_pos(new_hex)

func _on_commander_spawned(commander: CommanderData) -> void:
	_spawn_token(commander)

func _on_commander_destroyed(commander: CommanderData) -> void:
	if _selected_commander == commander:
		_deselect_commander()
	if _commander_tokens.has(commander):
		_commander_tokens[commander].queue_free()
		_commander_tokens.erase(commander)

# ─── Victory / defeat ─────────────────────────────────────────────────────────
func _check_victory_condition() -> void:
	if _game_over:
		return
	var player_count := 0
	for p: ProvinceData in ProvinceGrid.provinces:
		if ProvinceGrid.get_hex_owner(p.seed_hex) == TurnManager.FACTION_PLAYER:
			player_count += 1

	if player_count == 0:
		_trigger_game_over(false, "Your faction has been eliminated.")
	elif player_count > ProvinceGrid.NUM_PROVINCES / 2:
		_trigger_game_over(true, "You control the majority of the island!")

func _trigger_game_over(player_won: bool, reason: String) -> void:
	_game_over = true
	_deselect_commander()
	_show_end_screen(player_won, reason)

func _show_end_screen(player_won: bool, reason: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	# Semi-transparent background — blocks all clicks on the map below
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var card := PanelContainer.new()
	center.add_child(card)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 56)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "VICTORY" if player_won else "DEFEAT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	var title_color := Color(1.0, 0.85, 0.10) if player_won else Color(0.92, 0.22, 0.22)
	title.add_theme_color_override("font_color", title_color)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = reason
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(sub)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.12))
	vbox.add_child(sep)

	var btn := Button.new()
	btn.text = "New Game"
	btn.custom_minimum_size = Vector2(180, 46)
	btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(btn)
