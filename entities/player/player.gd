extends CharacterBody2D

@export var stats: PlayerStats

@onready var shield_pivot: Node2D = $ShieldPivot
@onready var sprite: Sprite2D = $Sprite2D
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var parry_window_timer: Timer = $ParryWindowTimer
@onready var disc: Disc = $ShieldPivot/Disc
@onready var shield_hitbox: Area2D = $ShieldPivot/ShieldHitbox

var is_invulnerable: bool = false
var has_disc: bool = true
var is_blocking: bool = false

func _ready() -> void:
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	EventBus.disc_caught.connect(_on_disc_caught)
	shield_hitbox.body_entered.connect(_on_shield_hitbox_body_entered)

func _on_dash_timer_timeout() -> void:
	is_invulnerable = false
	sprite.modulate.a = 1.0

func _on_disc_caught() -> void:
	has_disc = true

func _on_shield_hitbox_body_entered(body: Node2D) -> void:
	if body is Projectile and body.stats.parryable:
		if not parry_window_timer.is_stopped():
			body.reflect(stats.parry_damage_multiplier)
			Juice.slowmo(stats.parry_slowmo_scale, stats.parry_slowmo_duration)
			Juice.flash_sprite(sprite)
			EventBus.disc_blocked.emit(true)
		else:
			velocity = body.velocity.normalized() * stats.block_knockback_speed
			Juice.shake(stats.block_shake_intensity)
			body.block()

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash") and input_direction != Vector2.ZERO and dash_cooldown_timer.is_stopped():
		velocity = input_direction.normalized() * stats.dash_speed
		is_invulnerable = true
		dash_timer.wait_time = stats.dash_duration
		dash_cooldown_timer.wait_time = stats.dash_cooldown
		dash_timer.start()
		dash_cooldown_timer.start()

	var was_blocking := is_blocking
	is_blocking = Input.is_action_pressed("block") and has_disc and not is_invulnerable
	if is_blocking and not was_blocking:
		parry_window_timer.start(stats.parry_window)
	shield_hitbox.monitoring = is_blocking

	if not is_invulnerable:
		var speed := stats.move_speed * (stats.block_speed_multiplier if is_blocking else 1.0)
		var target_velocity := input_direction * speed
		var rate := stats.move_speed / stats.acceleration_time if input_direction != Vector2.ZERO else stats.move_speed / stats.friction_time
		velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

	if is_invulnerable:
		var elapsed := stats.dash_duration - dash_timer.time_left
		sprite.modulate.a = 1.0 if int(elapsed / 0.05) % 2 == 0 else 0.4

	shield_pivot.rotation = (get_global_mouse_position() - global_position).angle()

	disc.modulate = Color("#00f0ff") if is_blocking else Color.WHITE

	if Input.is_action_just_pressed("throw") and has_disc and not is_blocking:
		var direction := (get_global_mouse_position() - global_position).normalized()
		disc.throw(direction)
		has_disc = false

	if Input.is_action_just_pressed("recall") and not has_disc:
		disc.recall()
