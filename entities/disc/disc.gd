class_name Disc
extends CharacterBody2D

enum State { HELD, FLYING, RETURNING }

@export var stats: DiscStats

var state: State = State.HELD

@onready var held_parent: Node2D = get_parent()      # ShieldPivot, capturado antes de cualquier reparent
@onready var held_position: Vector2 = position        # offset local dentro de ShieldPivot (ej. (24, 0))

func throw(direction: Vector2) -> void:
	var origin := global_position
	reparent(get_tree().current_scene, false)
	global_position = origin
	state = State.FLYING
	velocity = direction.normalized() * stats.fly_speed
	EventBus.disc_thrown.emit(origin, direction)

func _physics_process(_delta: float) -> void:
	if state == State.FLYING:
		var collision := move_and_collide(velocity * _delta)
		if collision:
			_return_to_held()

func _return_to_held() -> void:
	state = State.RETURNING
	velocity = Vector2.ZERO
	reparent(held_parent, false)
	position = held_position
	rotation = 0.0
	state = State.HELD
	EventBus.disc_caught.emit()
