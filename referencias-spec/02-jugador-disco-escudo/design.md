# Design — 02 Jugador, Disco y Escudo

## Player (`entities/player/player.tscn`)
CharacterBody2D + Sprite2D placeholder + CollisionShape2D + `ShieldPivot` (Node2D que rota hacia el aim) con `ShieldHitbox` (Area2D, capa 7, desactivada por defecto) + `DashTimer` + `ParryWindowTimer`.

### FSM del jugador
`MOVE ↔ BLOCK` (mantener block, SOLO si `has_disc`) · `MOVE → DASH → MOVE` · cualquiera → `DEAD`.
- En BLOCK: `speed *= 0.4`, `ShieldHitbox` activa, no puede lanzar.
- Parry: al entrar a BLOCK arranca `ParryWindowTimer (0.15s)`; si un proyectil toca el escudo con el timer activo → parry.

## Disc (`entities/disc/disc.tscn`)
CharacterBody2D (capa 4) + estela (GPUParticles2D o Line2D).

### FSM del disco
HELD → (throw) → FLYING → (rebotes==0 | recall | 4s) → RETURNING → (llega) → HELD
- FLYING: `move_and_collide`; contra wall → `velocity = velocity.bounce(normal)`, `bounces -= 1`, SFX + shake leve. Contra enemigo → aplica daño (en esta spec, sobre el dummy).
- RETURNING: steering hacia el jugador con lerp de velocidad → curva orgánica; `collision_mask` sin walls (atraviesa como energía, evita atascos). Radio de recogida 20px → HELD.
- Rebotes máximos: `GameState.get_stat("disc_bounces")` (base 2).

## Parry (reutilizable para toda la vida del proyecto)
El proyectil parryado cambia de capa (5 → 4, pasa a ser "del jugador"), invierte dirección hacia el aim, `damage *= 2`, tinte cian, `Juice.slowmo(0.3, 0.25)` + SFX metálico. Cualquier `Projectile` con flag `parryable = true` lo soporta.

## Preview de puntería
`Line2D` desde el jugador: raycast hasta la primera pared, se calcula la reflexión y se dibuja el segmento de rebote con menor opacidad. Visible solo mientras se apunta.

## Dummy de pruebas (temporal, se retira en spec 03)
`training_dummy.tscn`: StaticBody2D con vida simple, números de daño flotantes, y un `DummyShooter` que dispara un proyectil lento al jugador cada 2s (para probar bloqueo/parry).

## Parámetros en `data/player_stats.tres`
move_speed=320 · block_speed_mult=0.4 · dash_time=0.15 · dash_cooldown=2.0 · parry_window=0.15 · disc_speed=900 · disc_bounces=2 · disc_return_timeout=4.0 · disc_damage=10
