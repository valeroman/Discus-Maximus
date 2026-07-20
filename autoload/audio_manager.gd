extends Node

func _ready() -> void:
	EventBus.disc_thrown.connect(func(_origin, _direction): play_sfx("throw"))
	EventBus.disc_bounced.connect(func(_position, _bounces_left, _shake_intensity): play_sfx("bounce"))
	EventBus.disc_caught.connect(func(): play_sfx("catch"))
	EventBus.disc_blocked.connect(_on_disc_blocked)

func _on_disc_blocked(perfect: bool) -> void:
	play_sfx("parry" if perfect else "block")

func play_sfx(sfx_id: String) -> void:
	pass

func play_music(track_id: String) -> void:
	pass

func stop_music() -> void:
	pass

func set_sfx_volume(v: float) -> void:
	pass

func set_music_volume(v: float) -> void:
	pass
