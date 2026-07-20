extends Node2D

@onready var player: CharacterBody2D = get_parent()
@onready var segment1: Line2D = $Segment1
@onready var segment2: Line2D = $Segment2

func _physics_process(_delta: float) -> void:
	if not (player.has_disc and not player.is_blocking):
		segment1.visible = false
		segment2.visible = false
		return

	var disc: Disc = player.disc
	var space_state := get_world_2d().direct_space_state
	var origin := disc.global_position
	var direction := (get_global_mouse_position() - player.global_position).normalized()
	var exclude := [player.get_rid(), disc.get_rid()]

	var hit1 := _cast(space_state, origin, direction, disc.collision_mask, exclude)
	var end1: Vector2 = hit1.position if hit1 else origin + direction * disc.stats.aim_preview_max_distance

	segment1.visible = true
	segment1.points = PackedVector2Array([to_local(origin), to_local(end1)])

	if not hit1:
		segment2.visible = false
		return

	var reflected := direction.bounce(hit1.normal)
	var hit2 := _cast(space_state, end1, reflected, disc.collision_mask, exclude)
	var end2: Vector2 = hit2.position if hit2 else end1 + reflected * disc.stats.aim_preview_max_distance

	segment2.visible = true
	segment2.points = PackedVector2Array([to_local(end1), to_local(end2)])

func _cast(space_state: PhysicsDirectSpaceState2D, from: Vector2, direction: Vector2, mask: int, exclude: Array) -> Dictionary:
	var to := from + direction * player.disc.stats.aim_preview_max_distance
	var query := PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
	return space_state.intersect_ray(query)
