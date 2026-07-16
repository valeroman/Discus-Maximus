class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0        # px/s, velocidad máxima
@export var acceleration_time: float = 0.1   # segundos hasta alcanzar move_speed
@export var friction_time: float = 0.1       # segundos hasta frenar desde move_speed a 0

@export var dash_speed: float = 900.0        # px/s, velocidad durante el dash
@export var dash_duration: float = 0.2       # segundos que dura el impulso + i-frames (RF-1.2)
@export var dash_cooldown: float = 2.0       # segundos antes de poder volver a dashear (RF-1.2)

@export var block_speed_multiplier: float = 0.4   # fracción de move_speed mientras BLOCK está activo
