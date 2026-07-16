extends CharacterBody2D

@export var stats: PlayerStats

@onready var shield_pivot: Node2D = $ShieldPivot
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer

var is_invulnerable: bool = false

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash") and input_direction != Vector2.ZERO and dash_cooldown_timer.is_stopped():
		velocity = input_direction.normalized() * stats.dash_speed
		is_invulnerable = true
		dash_timer.wait_time = stats.dash_duration
		dash_cooldown_timer.wait_time = stats.dash_cooldown
		dash_timer.start()
		dash_cooldown_timer.start()

	var target_velocity := input_direction * stats.move_speed
	var rate := stats.move_speed / stats.acceleration_time if input_direction != Vector2.ZERO else stats.move_speed / stats.friction_time
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

	shield_pivot.rotation = (get_global_mouse_position() - global_position).angle()
