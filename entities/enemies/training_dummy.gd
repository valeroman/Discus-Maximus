class_name TrainingDummy
extends StaticBody2D

@export var projectile_scene: PackedScene
@export var projectile_data: ProjectileData
@export var fire_interval: float = 2.0

@onready var fire_timer: Timer = $FireTimer

func _ready() -> void:
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.start()

func _on_fire_timer_timeout() -> void:
	var target := get_tree().get_first_node_in_group("player")
	if not target:
		return
	var projectile: Projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.stats = projectile_data
	projectile.launch((target.global_position - global_position).normalized())
