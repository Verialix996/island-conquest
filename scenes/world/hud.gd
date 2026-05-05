extends CanvasLayer

var health_bar: ProgressBar

func _ready() -> void:
	health_bar = $HealthBar
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_health_changed)

func _on_health_changed(new_health: int) -> void:
	health_bar.value = new_health
