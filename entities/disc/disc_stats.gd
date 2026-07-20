class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0   # px/s, velocidad durante FLYING (RF-2.1, design.md §3.1)
@export var max_bounces: int = 2       # rebotes base contra paredes antes de retornar (RF-2.3)
@export var return_speed: float = 700.0      # px/s, velocidad durante RETURNING (RF-2.4)
@export var return_turn_rate: float = 4.0    # rad/s, tasa máxima de giro del steering (curva del retorno)
@export var catch_radius: float = 20.0       # px, distancia al jugador para considerar el disco recogido
@export var flight_timeout: float = 4.0      # s, tiempo máx desde throw hasta forzar recogida (seguridad anti-atasco, tarea 1.6)
@export var aim_preview_max_distance: float = 1500.0   # px, fallback si el raycast del preview no golpea nada (tarea 1.7)
@export var bounce_shake_intensity: float = 2.0   # px, shake leve de Juice al rebotar (tarea 1.9)
