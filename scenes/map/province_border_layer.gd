extends Node2D

# Draws province boundary edges in a single pass, on top of all hex tile fills.
# Doing it here (instead of per-tile) means every shared edge is computed once
# in one coordinate frame — no floating-point mismatch at hex vertices.

const HEX_RADIUS := 40.0
const HEX_W := HEX_RADIUS * 1.7321
const HEX_H := HEX_RADIUS * 2.0
const BORDER_WIDTH := 3.5

func _ready() -> void:
	queue_redraw()
	EventBus.province_captured.connect(func(_p, _n, _o): queue_redraw())
	EventBus.hex_captured.connect(func(_c, _n, _o): queue_redraw())

func _draw() -> void:
	# Track drawn edges so each shared border is only drawn once
	var drawn: Dictionary = {}

	for y in ProvinceGrid.GRID_H:
		for x in ProvinceGrid.GRID_W:
			var coord := Vector2i(x, y)
			var prov: ProvinceData = ProvinceGrid.hex_province.get(coord)
			if prov == null:
				continue

			var center := _hex_center(coord)

			for edge_i in 6:
				var nb := _neighbor_for_edge(coord, edge_i)
				var nb_prov: ProvinceData = ProvinceGrid.hex_province.get(nb)
				if nb_prov == prov:
					continue  # Same province — no border here

				# Canonical key so we draw each shared edge exactly once
				var key := _edge_key(coord, nb)
				if drawn.has(key):
					continue
				drawn[key] = true

				# Both vertices of this edge in scene-local (ProvinceMap) space
				var angle_a := deg_to_rad(60.0 * edge_i - 90.0)
				var angle_b := deg_to_rad(60.0 * (edge_i + 1) - 90.0)
				var a := center + Vector2(cos(angle_a), sin(angle_a)) * HEX_RADIUS
				var b := center + Vector2(cos(angle_b), sin(angle_b)) * HEX_RADIUS

				var col := Color(0.08, 0.08, 0.08)
				draw_line(a, b, col, BORDER_WIDTH, true)
				draw_circle(a, BORDER_WIDTH * 0.5, col)
				draw_circle(b, BORDER_WIDTH * 0.5, col)

# Position of the hex center in ProvinceMap's local space.
# Mirrors the layout in province_map.gd: position = (x*HEX_W + odd_offset, y*HEX_H*0.75),
# size = (HEX_W, HEX_H), so center = position + size/2.
func _hex_center(coord: Vector2i) -> Vector2:
	var px := coord.x * HEX_W + (coord.y % 2) * (HEX_W / 2.0) + HEX_W / 2.0
	var py := coord.y * HEX_H * 0.75 + HEX_H / 2.0
	return Vector2(px, py)

# Sorted canonical key for the edge between two hexes (order-independent)
func _edge_key(a: Vector2i, b: Vector2i) -> int:
	# Coords fit in 8 bits each (grid is 24×18); pack into one int
	var ka := a.x | (a.y << 8)
	var kb := b.x | (b.y << 8)
	if ka > kb:
		var t := ka; ka = kb; kb = t
	return ka | (kb << 16)

# Pointy-top odd-r offset (odd rows shift RIGHT by half a hex).
# Edge i runs clockwise: 0=NE, 1=E, 2=SE, 3=SW, 4=W, 5=NW.
func _neighbor_for_edge(coord: Vector2i, edge: int) -> Vector2i:
	var even_off: Array[Vector2i] = [
		Vector2i(0, -1),  # 0: NE  (even row: row above is odd, shift right → same x)
		Vector2i(1, 0),   # 1: E
		Vector2i(0, 1),   # 2: SE
		Vector2i(-1, 1),  # 3: SW
		Vector2i(-1, 0),  # 4: W
		Vector2i(-1, -1), # 5: NW
	]
	var odd_off: Array[Vector2i] = [
		Vector2i(1, -1),  # 0: NE  (odd row: row above is even, no shift → x+1)
		Vector2i(1, 0),   # 1: E
		Vector2i(1, 1),   # 2: SE
		Vector2i(0, 1),   # 3: SW
		Vector2i(-1, 0),  # 4: W
		Vector2i(0, -1),  # 5: NW
	]
	var off: Vector2i = even_off[edge] if coord.y % 2 == 0 else odd_off[edge]
	return coord + off
