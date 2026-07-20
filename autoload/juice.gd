extends Node

func _ready() -> void:
	EventBus.disc_bounced.connect(_on_disc_bounced)

func _on_disc_bounced(_position: Vector2, _bounces_left: int, shake_intensity: float) -> void:
	shake(shake_intensity)

func shake(intensity: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return
	var tween := create_tween()
	var shake_duration := 0.2
	var steps := 6
	for i in steps:
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", offset, shake_duration / steps)
	tween.tween_property(camera, "offset", Vector2.ZERO, shake_duration / steps)

func hit_stop(duration: float) -> void:
	pass

func slowmo(scale: float, duration: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, false, false, true).timeout
	Engine.time_scale = 1.0

func flash_sprite(sprite: CanvasItem) -> void:
	var original_modulate := sprite.modulate
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color("#00f0ff"), 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)
