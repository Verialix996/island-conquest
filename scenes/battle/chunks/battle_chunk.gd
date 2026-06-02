extends Node3D
class_name BattleChunk

## Reusable authored layout for battle map generation.
## Marker3D children under CoverSlots become cover positions;
## Marker3D children under ZoneSlots become candidate capture-zone positions.
@export var chunk_name: String = "Battle Chunk"

func get_cover_positions() -> Array[Vector3]:
	return _marker_positions("CoverSlots")

func get_zone_positions() -> Array[Vector3]:
	return _marker_positions("ZoneSlots")

func _marker_positions(container_name: StringName) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var container := get_node_or_null(NodePath(container_name))
	if container == null:
		return positions
	for child in container.get_children():
		if child is Node3D:
			positions.append((child as Node3D).position)
	return positions
