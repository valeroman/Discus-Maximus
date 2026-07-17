class_name Projectile
extends CharacterBody2D

@export var stats: ProjectileData

var _lifetime_left: float = 0.0
var damage: float = 0.0

func launch(direction: Vector2) -> void:
	velocity = direction.normalized() * stats.speed
	_lifetime_left = stats.lifetime
	damage = stats.damage

func reflect(multiplier: float) -> void:
	velocity = -velocity
	damage *= multiplier
	set_collision_mask_value(3, true)   # capa "enemies" — para impactar contra el TrainingDummy al volver

func block() -> void:
	EventBus.disc_blocked.emit(false)
	queue_free()

func _physics_process(delta: float) -> void:
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()
		return
	var collision := move_and_collide(velocity * delta)
	if collision:
		queue_free()
