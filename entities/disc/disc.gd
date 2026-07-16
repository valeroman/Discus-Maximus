class_name Disc
extends CharacterBody2D

enum State { HELD, FLYING, RETURNING }

@export var stats: DiscStats

var state: State = State.HELD
var bounces_left: int = 0
var flight_time: float = 0.0

@onready var held_parent: Node2D = get_parent()      # ShieldPivot, capturado antes de cualquier reparent
@onready var held_position: Vector2 = position        # offset local dentro de ShieldPivot (ej. (24, 0))

func throw(direction: Vector2) -> void:
	var origin := global_position
	reparent(get_tree().current_scene, false)
	global_position = origin
	state = State.FLYING
	velocity = direction.normalized() * stats.fly_speed
	bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))
	EventBus.disc_thrown.emit(origin, direction)

func _physics_process(_delta: float) -> void:
	if state == State.FLYING:
		var collision := move_and_collide(velocity * _delta)
		if collision:
			if bounces_left > 0:
				velocity = velocity.bounce(collision.get_normal())
				bounces_left -= 1
				EventBus.disc_bounced.emit(collision.get_position(), bounces_left)
			else:
				state = State.RETURNING
				velocity = velocity.normalized() * stats.return_speed
	elif state == State.RETURNING:
		var to_target := held_parent.global_position - global_position
		var desired_direction := to_target.normalized()
		var angle_to_desired := velocity.angle_to(desired_direction)
		var max_step := stats.return_turn_rate * _delta
		velocity = velocity.rotated(clampf(angle_to_desired, -max_step, max_step))
		global_position += velocity * _delta
		if to_target.length() <= stats.catch_radius:
			_return_to_held()

func _return_to_held() -> void:
	state = State.RETURNING
	velocity = Vector2.ZERO
	reparent(held_parent, false)
	position = held_position
	rotation = 0.0
	state = State.HELD
	EventBus.disc_caught.emit()
