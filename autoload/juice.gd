extends Node

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
	pass

func flash_sprite(sprite: CanvasItem) -> void:
	pass
