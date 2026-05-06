extends Area3D

@export var zone_name: String = "Zone"
@export var owner_faction: FactionData = null
@export var player_faction: FactionData = null
@export var enemy_faction: FactionData = null
@export var capture_time: float = 3.0
@export var heal_amount: float = 5.0
@export var heal_interval: float = 1.0
@export var mags_to_add: int = 1

var zone_visual: MeshInstance3D
var capture_progress: float = 0.0
var heal_timer: float = 0.0
var mat: StandardMaterial3D
var bodies_in_zone: Array = []

func _ready() -> void:
	zone_visual = $ZoneVisual
	mat = zone_visual.get_active_material(0).duplicate()
	zone_visual.set_surface_override_material(0, mat)
	GameManager.register_zone(self, owner_faction)
	_update_color()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	bodies_in_zone.append(body)

func _on_body_exited(body: Node3D) -> void:
	bodies_in_zone.erase(body)

func _process(delta: float) -> void:
	var player: Node3D = null
	var player_count := 0
	var enemy_count := 0

	for body in bodies_in_zone:
		if not is_instance_valid(body):
			continue
		if body.is_in_group("player"):
			player_count += 1
			player = body
		elif body.is_in_group("enemy") and not body.is_dead:
			enemy_count += 1

	bodies_in_zone = bodies_in_zone.filter(func(b): return is_instance_valid(b))

	# Capture logic
	var dominant_faction: FactionData = null
	if player_count > enemy_count:
		dominant_faction = player_faction
	elif enemy_count > player_count:
		dominant_faction = enemy_faction

	if dominant_faction != null and dominant_faction != owner_faction:
		capture_progress += delta
		if capture_progress >= capture_time:
			capture_progress = 0.0
			_capture(dominant_faction)
	else:
		capture_progress = max(0.0, capture_progress - delta)

	# Heal and resupply player while in a player-owned zone
	if player != null and owner_faction != null and owner_faction.is_player_faction:
		heal_timer -= delta
		if heal_timer <= 0.0:
			heal_timer = heal_interval
			_resupply(player)

func _resupply(player: Node3D) -> void:
	if player.has_method("heal"):
		player.heal(heal_amount)
	var weapons = player.weapons
	if weapons.size() > 0:
		var current = weapons[player.current_weapon]
		if current.has_method("add_mags") and current.current_mags < current.max_mags:
			current.add_mags(mags_to_add)

func _capture(new_faction: FactionData) -> void:
	owner_faction = new_faction
	heal_timer = 0.0
	_update_color()
	print("%s captured by %s!" % [zone_name, owner_faction.faction_name])
	EventBus.zone_captured.emit(self, owner_faction)

func _update_color() -> void:
	if owner_faction == null or mat == null:
		return
	var c = owner_faction.color
	mat.albedo_color = Color(c.r, c.g, c.b, 0.4)
