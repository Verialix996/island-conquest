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
var _gameplay_started: bool = false
var _main_menu_layer: CanvasLayer = null
var _pause_layer: CanvasLayer = null
var _end_screen_layer: CanvasLayer = null

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
	EventBus.battle_choice_needed.connect(_on_battle_choice_needed)
	EventBus.pause_menu_requested.connect(_on_pause_menu_requested)

	if BattleContext.returning_from_battle:
		BattleContext.returning_from_battle = false
		_gameplay_started = true
		for tile in tile_nodes.values():
			(tile as ProvinceT).refresh()
		_spawn_commanders()
		if BattleContext.was_defense:
			BattleContext.was_defense = false
			TurnManager.resume_after_defense_battle()
		else:
			TurnManager.resume_after_battle()
		TurnManager.refresh_hud()
	elif GameManager.skip_main_menu_once:
		GameManager.skip_main_menu_once = false
		_start_gameplay()
	else:
		_show_main_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if _game_over or not _gameplay_started or _main_menu_layer != null:
				return
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()

func _on_pause_menu_requested() -> void:
	if _game_over or not _gameplay_started or _main_menu_layer != null:
		return
	_toggle_pause_menu()

func _build_grid() -> void:
	for y in ProvinceGrid.GRID_H:
		for x in ProvinceGrid.GRID_W:
			var coord := Vector2i(x, y)
			var tile: ProvinceT = PROVINCE_TILE.instantiate()
			var px: float = x * HEX_W + (y % 2) * (HEX_W / 2.0)
			var py: float = y * HEX_H * 0.75
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

# ─── Menu / overlay UX ────────────────────────────────────────────────────────
func _start_gameplay() -> void:
	if _gameplay_started:
		return
	_gameplay_started = true
	_hide_main_menu()
	TurnManager.start_game()
	_spawn_commanders()
	TurnManager.refresh_hud()

func _show_main_menu() -> void:
	if _main_menu_layer != null:
		return
	_main_menu_layer = _build_menu_layer(
		1,
		"ISLAND CONQUEST",
		"Command your faction across the island. Capture provinces, manage resources, and outlast rival commanders.",
		[
			{"text": "Start New Game", "callback": _start_gameplay},
			{"text": "Quit", "callback": func(): get_tree().quit()},
		]
	)
	add_child(_main_menu_layer)

func _hide_main_menu() -> void:
	if _main_menu_layer == null:
		return
	_main_menu_layer.queue_free()
	_main_menu_layer = null

func _toggle_pause_menu() -> void:
	if _pause_layer == null:
		_show_pause_menu()
	else:
		_hide_pause_menu()

func _show_pause_menu() -> void:
	if _pause_layer != null:
		return
	_deselect_commander()
	_pause_layer = _build_menu_layer(
		8,
		"PAUSED",
		"The campaign is waiting. Resume, restart with a fresh island, or exit the game.",
		[
			{"text": "Resume", "callback": _hide_pause_menu},
			{"text": "New Game", "callback": _restart_without_menu},
			{"text": "Quit", "callback": func(): get_tree().quit()},
		]
	)
	add_child(_pause_layer)

func _hide_pause_menu() -> void:
	if _pause_layer == null:
		return
	_pause_layer.queue_free()
	_pause_layer = null

func _restart_without_menu() -> void:
	GameManager.skip_main_menu_once = true
	get_tree().reload_current_scene()

func _build_menu_layer(layer_index: int, title_text: String, body_text: String, buttons: Array) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = layer_index

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.76)
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
		margin.add_theme_constant_override(side, 46)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.28))
	vbox.add_child(title)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(420, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.78, 0.80, 0.84))
	vbox.add_child(body)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(1, 1, 1, 0.12))
	vbox.add_child(sep)

	for spec in buttons:
		var btn := Button.new()
		btn.text = spec.get("text", "Button")
		btn.custom_minimum_size = Vector2(220, 44)
		btn.pressed.connect(spec.get("callback"))
		vbox.add_child(btn)

	return layer

func _is_interaction_locked() -> bool:
	return _game_over or not _gameplay_started or _pause_layer != null or _main_menu_layer != null

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
	if _is_interaction_locked():
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
	var province: ProvinceData = ProvinceGrid.get_province_for_hex(target_hex)
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
	if _is_interaction_locked():
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
	if _is_interaction_locked():
		return
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
	if _end_screen_layer != null:
		return
	_end_screen_layer = CanvasLayer.new()
	_end_screen_layer.layer = 10
	add_child(_end_screen_layer)

	# Semi-transparent background — blocks all clicks on the map below
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_screen_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_screen_layer.add_child(center)

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
	var title_color: Color = Color(1.0, 0.85, 0.10) if player_won else Color(0.92, 0.22, 0.22)
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
	btn.pressed.connect(_restart_without_menu)
	vbox.add_child(btn)

# ─── Battle choice dialog ─────────────────────────────────────────────────────
const BATTLE_ATTACK_STRENGTH := 5

func _on_battle_choice_needed(province: ProvinceData, is_defense: bool, attacker: FactionData) -> void:
	if _is_interaction_locked():
		return
	var garrison: int = ProvinceGrid.get_province_garrison(province)

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
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
		margin.add_theme_constant_override(side, 40)
	card.add_child(margin)

	var vbox2 := VBoxContainer.new()
	vbox2.add_theme_constant_override("separation", 14)
	vbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox2)

	var title2 := Label.new()
	title2.text = "BATTLE — %s" % province.province_name
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2.add_theme_font_size_override("font_size", 22)
	vbox2.add_child(title2)

	var sep3 := HSeparator.new()
	vbox2.add_child(sep3)

	var role := Label.new()
	role.text = "Defending" if is_defense else "Attacking"
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 14)
	role.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
	vbox2.add_child(role)

	var stats2 := Label.new()
	if is_defense:
		stats2.text = "Your garrison: %d  vs  Attacker: %d" % [garrison, BATTLE_ATTACK_STRENGTH]
	else:
		stats2.text = "Your force: %d  vs  Garrison: %d" % [BATTLE_ATTACK_STRENGTH, garrison]
	stats2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats2.add_theme_font_size_override("font_size", 13)
	vbox2.add_child(stats2)

	var player_favored: bool = (BATTLE_ATTACK_STRENGTH > garrison) if not is_defense else (garrison >= BATTLE_ATTACK_STRENGTH)
	var odds_lbl := Label.new()
	odds_lbl.text = "Auto-resolve outcome: %s" % ("Win" if player_favored else "Lose")
	odds_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	odds_lbl.add_theme_font_size_override("font_size", 13)
	odds_lbl.add_theme_color_override("font_color", Color(0.35, 0.9, 0.35) if player_favored else Color(0.9, 0.35, 0.35))
	vbox2.add_child(odds_lbl)

	var sep4 := HSeparator.new()
	vbox2.add_child(sep4)

	var hbox2 := HBoxContainer.new()
	hbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox2.add_theme_constant_override("separation", 20)
	vbox2.add_child(hbox2)

	var fight_btn := Button.new()
	fight_btn.text = "Fight"
	fight_btn.custom_minimum_size = Vector2(130, 42)
	hbox2.add_child(fight_btn)

	var auto_btn := Button.new()
	auto_btn.text = "Auto-resolve"
	auto_btn.custom_minimum_size = Vector2(130, 42)
	hbox2.add_child(auto_btn)

	fight_btn.pressed.connect(func():
		layer.queue_free()
		if is_defense:
			BattleContext.start_defense_battle(
				TurnManager.pending_defense_battle.province,
				TurnManager.pending_defense_battle.attacker,
				TurnManager.pending_defense_battle.hex
			)
		else:
			BattleContext.start_battle(province, TurnManager.FACTION_PLAYER)
	)

	auto_btn.pressed.connect(func():
		layer.queue_free()
		_auto_resolve_battle(province, is_defense, attacker, garrison)
	)

func _auto_resolve_battle(province: ProvinceData, is_defense: bool, attacker: FactionData, garrison: int) -> void:
	var player_won: bool = (BATTLE_ATTACK_STRENGTH > garrison) if not is_defense else (garrison >= BATTLE_ATTACK_STRENGTH)
	var target_hex: Vector2i
	if is_defense:
		target_hex = TurnManager.pending_defense_battle.get("hex", province.seed_hex)
	else:
		target_hex = BattleContext.target_hex
		BattleContext.target_hex = Vector2i(-1, -1)

	if is_defense:
		if not player_won:
			ProvinceGrid.capture_hex(target_hex, attacker)
			var player_cmd: CommanderData = TurnManager.get_commander_at(target_hex)
			if player_cmd != null:
				TurnManager.destroy_commander(player_cmd)
		else:
			var ai_cmd: CommanderData = TurnManager._find_commander(attacker)
			if ai_cmd != null:
				TurnManager.destroy_commander(ai_cmd)
	else:
		if player_won:
			ProvinceGrid.capture_hex(target_hex, TurnManager.FACTION_PLAYER)
			var defender_cmd: CommanderData = TurnManager.get_commander_at(target_hex)
			if defender_cmd != null:
				TurnManager.destroy_commander(defender_cmd)
		else:
			var player_cmd: CommanderData = TurnManager._find_commander(TurnManager.FACTION_PLAYER)
			if player_cmd != null:
				TurnManager.destroy_commander(player_cmd)

	province.is_contested    = false
	province.attacker_faction = null
	for coord in province.hex_tiles:
		if tile_nodes.has(coord):
			tile_nodes[coord].refresh()
	_check_victory_condition()

	if is_defense:
		TurnManager.resume_after_defense_battle()
	else:
		TurnManager.resume_after_battle()
