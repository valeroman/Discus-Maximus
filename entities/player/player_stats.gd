class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0        # px/s, velocidad máxima
@export var acceleration_time: float = 0.1   # segundos hasta alcanzar move_speed
@export var friction_time: float = 0.1       # segundos hasta frenar desde move_speed a 0
