class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0   # px/s, velocidad durante FLYING (RF-2.1, design.md §3.1)
@export var max_bounces: int = 2       # rebotes base contra paredes antes de retornar (RF-2.3)
@export var return_speed: float = 700.0      # px/s, velocidad durante RETURNING (RF-2.4)
@export var return_turn_rate: float = 4.0    # rad/s, tasa máxima de giro del steering (curva del retorno)
@export var catch_radius: float = 20.0       # px, distancia al jugador para considerar el disco recogido
