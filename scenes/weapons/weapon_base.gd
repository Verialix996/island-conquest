extends Node3D

@export var damage: int = 25
@export var fire_rate: float = 0.2

var can_fire: bool = true
var raycast: RayCast3D
var muzzle_flash: GPUParticles3D
var gunshot_sound: AudioStreamPlayer3D

func _ready() -> void:
	raycast = $RayCast3D
	muzzle_flash = $MuzzleFlash
	gunshot_sound = $GunShotSound

func _process(_delta: float) -> void:
	if Input.is_action_pressed("shoot") and can_fire:
		fire()

func fire() -> void:
	can_fire = false
	muzzle_flash.restart()
	gunshot_sound.play()
	if raycast.is_colliding():
		var hit = raycast.get_collider()
		if hit != null and hit.has_method("take_damage"):
			hit.take_damage(damage)
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true
