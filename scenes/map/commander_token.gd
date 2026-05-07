class_name CommanderToken
extends Control

signal token_clicked(data: CommanderData)

const TOKEN_SIZE := 32.0

var data: CommanderData = null
var is_selected := false

func setup(commander: CommanderData) -> void:
	data = commander
	custom_minimum_size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	size = Vector2(TOKEN_SIZE, TOKEN_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_selected(v: bool) -> void:
	is_selected = v
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var c := size / 2.0
	var r := size.y / 2.0 - 2.0

	# Yellow selection ring drawn first (underneath the circle)
	if is_selected:
		draw_circle(c, r + 4.0, Color(1.0, 0.90, 0.0, 0.95))

	var col := data.owner_faction.color if data.owner_faction else Color.GRAY
	draw_circle(c, r, col)
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 1.5)

	# First letter of faction name as a simple marker
	var letter := data.owner_faction.faction_name.left(1).to_upper() if data.owner_faction else "?"
	var font := ThemeDB.fallback_font
	var fs := int(r * 0.95)
	var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw / 2.0, fs * 0.35), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()   # prevent click reaching the tile underneath
		token_clicked.emit(data)
