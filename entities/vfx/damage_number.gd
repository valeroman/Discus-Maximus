class_name DamageNumber
extends Node2D

const RISE_DISTANCE := 40.0
const DURATION := 0.6

@onready var label: Label = $Label

func setup(amount: float, is_crit: bool) -> void:
	label.text = str(int(round(amount)))
	if is_crit:
		label.add_theme_color_override("font_color", Color("#ff2079"))
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_color_override("font_color", Color("#00f0ff"))
		label.add_theme_font_size_override("font_size", 18)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
