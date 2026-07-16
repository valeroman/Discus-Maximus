class_name ProjectileData
extends Resource

@export var speed: float = 400.0      # px/s, velocidad en línea recta
@export var lifetime: float = 3.0     # s, autodestrucción si no choca con nada (seguridad anti-atasco)
@export var parryable: bool = true    # si true, ShieldHitbox lo bloquea durante BLOCK
