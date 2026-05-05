extends CharacterBody3D

enum State { PATROL, CHASE, ATTACK }

@export var max_health: int = 100
@export var move_speed: float = 3.0
@export var detection_range: float = 10.0
@export var attack_range: float = 1.5
@export var attack_damage: int = 10

var health: int
var state: State = State.PATROL
var player: Node3D
var nav_agent: NavigationAgent3D
var attack_timer: Timer

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	nav_agent = $NavigationAgent3D
	attack_timer = $AttackTimer
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(_delta: float) -> void:
	if player == null:
		return

	var dist = global_position.distance_to(player.global_position)

	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= detection_range:
		state = State.CHASE
	else:
		state = State.PATROL

	match state:
		State.CHASE:
			nav_agent.target_position = player.global_position
			var next = nav_agent.get_next_path_position()
			var dir = (next - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
		State.PATROL:
			velocity = Vector3.ZERO
		State.ATTACK:
			velocity = Vector3.ZERO

func _on_attack_timer_timeout() -> void:
	if state == State.ATTACK and player != null:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy hit! Health: ", health)
	if health <= 0:
		die()

func die() -> void:
	print("Enemy died!")
	queue_free()
