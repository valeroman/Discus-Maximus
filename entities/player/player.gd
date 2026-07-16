extends CharacterBody2D

@export var stats: PlayerStats

@onready var shield_pivot: Node2D = $ShieldPivot
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer

var is_invulnerable: bool = false

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity := input_direction * stats.move_speed
	var rate := stats.move_speed / stats.acceleration_time if input_direction != Vector2.ZERO else stats.move_speed / stats.friction_time
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

	shield_pivot.rotation = (get_global_mouse_position() - global_position).angle()
