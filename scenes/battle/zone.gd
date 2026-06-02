extends Area3D

const ENEMY_MELEE = preload("res://scenes/units/enemy_base.tscn")
const ENEMY_RANGED = preload("res://scenes/units/enemy_ranged.tscn")

@export var zone_name: String = "Zone"
@export var owner_faction: FactionData = null
@export var player_faction: FactionData = null
@export var capture_time: float = 3.0
@export var heal_amount: float = 5.0
@export var heal_interval: float = 1.0
@export var mags_to_add: int = 1
@export var spawn_interval: float = 10.0
@export var max_units: int = 5

var zone_visual: MeshInstance3D
var capture_progress: float = 0.0
var heal_timer: float = 0.0
var spawn_timer: float = 0.0
var mat: StandardMaterial3D
var bodies_in_zone: Array = []
var spawned_units: Array = []

func _ready() -> void:
	add_to_group("battle_zone")
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
	var faction_counts: Dictionary = {}

	for body in bodies_in_zone:
		if not is_instance_valid(body):
			continue
		var body_faction: FactionData = _get_body_faction(body)
		if body.is_in_group("player"):
			player = body
		if body_faction != null:
			faction_counts[body_faction] = faction_counts.get(body_faction, 0) + 1

	bodies_in_zone = bodies_in_zone.filter(func(b): return is_instance_valid(b))

	# Find dominant faction (most bodies, no capture on a tie)
	var dominant_faction: FactionData = null
	var max_count: int = 0
	for f in faction_counts:
		if faction_counts[f] > max_count:
			max_count = faction_counts[f]
			dominant_faction = f
		elif faction_counts[f] == max_count:
			dominant_faction = null  # tie, contested

	if dominant_faction != null and dominant_faction != owner_faction and _can_capture(dominant_faction, owner_faction):
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

	# Spawn units for all factions that own this zone
	if owner_faction != null:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = spawn_interval
			_try_spawn_unit()

func _try_spawn_unit() -> void:
	spawned_units = spawned_units.filter(func(u): return is_instance_valid(u))
	if spawned_units.size() >= max_units:
		return
	if BattleContext.is_battle_mode():
		var tracker = get_tree().get_first_node_in_group("battle_tracker")
		if tracker != null:
			var is_player_side: bool = owner_faction != null and owner_faction.is_player_faction
			if is_player_side:
				if not tracker.use_player_ticket():
					return
			else:
				if not tracker.use_enemy_ticket():
					return
	var scene = ENEMY_MELEE if randf() < 0.5 else ENEMY_RANGED
	var unit = scene.instantiate()
	unit.faction = owner_faction
	get_tree().current_scene.add_child(unit)
	var offset = Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	unit.global_position = Vector3(global_position.x + offset.x, 1.1, global_position.z + offset.z)
	spawned_units.append(unit)

func _can_capture(attacker: FactionData, defender: FactionData) -> bool:
	if attacker == null:
		return false
	if defender == null:
		return true
	return DiplomacyManager.are_at_war(attacker, defender)

func _get_body_faction(body: Node) -> FactionData:
	if body == null:
		return null
	if "is_dead" in body and body.is_dead:
		return null
	if body.has_method("get_faction"):
		return body.get_faction()
	var body_faction: FactionData = body.get("faction")
	if body_faction != null:
		return body_faction
	if body.is_in_group("player"):
		return player_faction
	return null

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
	spawn_timer = spawn_interval  # delay before new faction starts spawning
	_update_color()
	print("%s captured by %s!" % [zone_name, owner_faction.faction_name])
	EventBus.zone_captured.emit(self, owner_faction)

func _update_color() -> void:
	if owner_faction == null or mat == null:
		return
	var c = owner_faction.color
	mat.albedo_color = Color(c.r, c.g, c.b, 0.4)
