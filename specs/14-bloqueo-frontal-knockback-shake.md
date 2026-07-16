# SPEC 14 — Bloqueo frontal: knockback + shake al parar golpes (espalda sin cambios)

> **Status:** Aprobado
> **Depends on:** [12-bloqueo-estado-block.md](12-bloqueo-estado-block.md), [13-proyectil-generico-training-dummy.md](13-proyectil-generico-training-dummy.md)
> **Date:** 2026-07-16
> **Objective:** Agregar feedback de impacto al bloqueo frontal ya existente (`ShieldHitbox`/`is_blocking`, specs 12-13): al bloquear un `Projectile` `parryable`, aplicar un knockback leve al `Player` (nuevo `block_knockback_speed` en `PlayerStats`) e implementar un `Juice.shake()` mínimo real (jitter de cámara); los golpes que llegan por la espalda (fuera del `ShieldHitbox`, sin bloqueo) siguen destruyéndose contra el cuerpo del jugador sin ninguna consecuencia, exactamente igual que hoy, a la espera de la tarea 2.1 (`HealthComponent`).

## Scope

**In:**

- `entities/player/player_stats.gd`: agregar dos campos a `PlayerStats`:
  - `@export var block_knockback_speed: float = 250.0` (velocidad del impulso al bloquear, px/s).
  - `@export var block_shake_intensity: float = 4.0` (magnitud del jitter de cámara al bloquear, px).
- `data/player_stats.tres`: setear ambos campos nuevos (conservando los 7 campos previos).
- `entities/player/player.gd`: en `_on_shield_hitbox_body_entered`, cuando el `body` es `Projectile` y `parryable`:
  - Aplicar `velocity = body.velocity.normalized() * stats.block_knockback_speed` **antes** de llamar a `body.block()` (el impulso empuja al `Player` en la misma dirección en que viajaba el proyectil, como un recule leve).
  - Llamar a `Juice.shake(stats.block_shake_intensity)`.
  - El impulso no congela el movimiento ni el input (a diferencia del dash): se disipa solo vía el `move_toward` de aceleración/fricción ya existente en `_physics_process`.
- `autoload/juice.gd`: implementar `shake(intensity: float)` con un efecto real mínimo (jitter del `Camera2D` activo vía `get_viewport().get_camera_2d()`, decayendo a `Vector2.ZERO` en un lapso corto con `Tween`). `hit_stop()`, `slowmo()`, `flash_sprite()` **siguen como stub** (`pass`) — no se tocan.
- Verificación manual en `test_arena.tscn` (F6).

**Out of scope (specs futuras):**

- `HealthComponent`/`HurtboxComponent` y cualquier daño real al jugador — tarea `2.1`, sin hacer todavía. Un golpe por la espalda (proyectil que nunca entra a `ShieldHitbox`, `parryable` o no) sigue destruyéndose contra el `CollisionShape2D` principal del `Player` sin ningún efecto, tal cual hoy (spec 13) — cero cambios en `projectile.gd` ni en la detección de colisión física del `Player`.
- Detección de ángulo frontal/espalda explícita (dot product, cono, etc.) — "frontal" sigue siendo, como hoy, lo que geométricamente entra en el `ShieldHitbox` (`Area2D` fija al offset del `ShieldPivot`, que ya rota hacia el cursor). No se agrega lógica de ángulo nueva.
- Knockback/shake en golpes **no** `parryable` que entran al `ShieldHitbox` — siguen sin disparar ninguna rama en `_on_shield_hitbox_body_entered` (mismo comportamiento que spec 13: atraviesan el escudo).
- Reflejar o redirigir el proyectil bloqueado — sigue destruyéndose (`body.block()`), sin cambios en `projectile.gd`.
- Ventana de parry perfecto — diferida desde spec 12, no se reabre aquí.
- Que la `Camera2D` de `test_arena.tscn` siga al `Player` — sigue estática (posición fija); el shake se aplica sobre esa cámara tal cual está, sin agregar seguimiento de cámara.
- SFX del bloqueo/impacto — pase de audio, Fase 4.
- Partículas o flash de impacto — Juice v1 completo, tarea `1.9` (solo se adelanta `shake()`, no el resto de Juice).
- Controles táctiles — no aplica.
- Cambios a `docs/tasks.md` — no hay tarea explícita para este feedback de bloqueo (mismo criterio que specs 06/12/13); se deja intacto.

## Data model

**`entities/player/player_stats.gd`** (2 campos nuevos, resto intacto):

```gdscript
class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0
@export var acceleration_time: float = 0.1
@export var friction_time: float = 0.1

@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0

@export var block_speed_multiplier: float = 0.4

@export var block_knockback_speed: float = 250.0   # px/s, impulso al bloquear un golpe frontal
@export var block_shake_intensity: float = 4.0      # px, magnitud del jitter de cámara al bloquear
```

**`data/player_stats.tres`**: agregar `block_knockback_speed = 250.0` y `block_shake_intensity = 4.0` (conservando los 7 campos previos).

**`entities/player/player.gd`** (solo el handler cambia; resto de `_physics_process` intacto):

```gdscript
func _on_shield_hitbox_body_entered(body: Node2D) -> void:
	if body is Projectile and body.stats.parryable:
		velocity = body.velocity.normalized() * stats.block_knockback_speed
		Juice.shake(stats.block_shake_intensity)
		body.block()
```

**`autoload/juice.gd`** (solo `shake()` cambia; `hit_stop()`, `slowmo()`, `flash_sprite()` siguen `pass`):

```gdscript
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
```

Convenciones:

- El orden en `_on_shield_hitbox_body_entered` importa: `body.velocity` se lee **antes** de `body.block()` (que hace `queue_free()` y volvería inválida la referencia si se leyera después).
- El knockback usa la dirección del proyectil (`body.velocity.normalized()`), no la del jugador ni la del cursor: el `Player` recula en la misma línea en que viajaba el disparo bloqueado.
- El impulso sobreescribe `velocity` una vez; el `move_toward` ya existente en `_physics_process` lo disipa hacia `target_velocity` al ritmo de `acceleration_time`/`friction_time`, igual que cualquier otro cambio de velocidad — no se agrega temporizador ni estado nuevo (`is_knocked_back`, etc.).
- `Juice.shake()` no depende de qué nodo lo llama: usa `get_viewport().get_camera_2d()`, la cámara activa del árbol en ese momento (hoy la `Camera2D` estática de `test_arena.tscn`). Si no hay cámara activa, no hace nada (sin error).
- `block_shake_intensity` vive en `PlayerStats` (no como constante en `juice.gd`) porque es el bloqueo del jugador el que decide "qué tan fuerte tiembla"; `Juice.shake()` es genérico y reutilizable por cualquier otro sistema futuro (rebote del disco, muerte de enemigo, etc.) con su propia intensidad.

## Implementation plan

1. En `entities/player/player_stats.gd`, agregar `@export var block_knockback_speed: float = 250.0` y `@export var block_shake_intensity: float = 4.0`.
2. Abrir `data/player_stats.tres` en el editor y setear ambos campos nuevos (confirmar que los 7 campos previos siguen intactos).
3. En `autoload/juice.gd`, implementar `shake(intensity: float)` con el jitter de cámara vía `Tween` (dejando `hit_stop()`, `slowmo()`, `flash_sprite()` como `pass`).
4. En `entities/player/player.gd`, modificar `_on_shield_hitbox_body_entered` para leer `body.velocity` y aplicar el knockback + `Juice.shake()` **antes** de llamar a `body.block()`.
5. F6 `test_arena.tscn`: con disco en mano, sostener `block` (Left Shift) cuando un proyectil `parryable` del `TrainingDummy` se acerque → confirmar que el proyectil se destruye, el `Player` recula levemente en la dirección del disparo, y la cámara tiembla brevemente.
6. F6: repetir el bloqueo varias veces seguidas → confirmar que el knockback y el shake se disparan cada vez, sin acumularse ni quedar "trabado" el `velocity` o el `offset` de la cámara entre bloqueos.
7. F6: dejar que un proyectil golpee al `Player` **sin** bloquear (soltando `block` o con el disparo llegando por la espalda, fuera del `ShieldHitbox`) → confirmar que el proyectil se destruye contra el cuerpo del jugador sin knockback, sin shake y sin ningún otro efecto, igual que en spec 13.
8. F6: cambiar temporalmente `parryable = false` en `data/projectile_data.tres`, repetir el bloqueo → confirmar que el proyectil atraviesa el `ShieldHitbox` sin knockback ni shake (misma rama vacía que spec 13). Revertir `parryable = true` al terminar.
9. Confirmar en consola: sin errores (en particular, ningún acceso a `body` después de `queue_free()`).
10. Marcar el spec como `Implemented` (no hay tarea en `docs/tasks.md` que marcar).

## Acceptance criteria

- [ ] `PlayerStats` tiene `block_knockback_speed` (`float`, default `250.0`) y `block_shake_intensity` (`float`, default `4.0`) sin remover los 7 campos previos.
- [ ] `data/player_stats.tres` tiene ambos campos nuevos seteados (y conserva `move_speed`, `acceleration_time`, `friction_time`, `dash_speed`, `dash_duration`, `dash_cooldown`, `block_speed_multiplier`).
- [ ] `Juice.shake(intensity)` tiene una implementación real (no `pass`): al llamarla con una `Camera2D` activa en el árbol, la propiedad `offset` de esa cámara varía brevemente y vuelve a `Vector2.ZERO`.
- [ ] `Juice.hit_stop()`, `Juice.slowmo()` y `Juice.flash_sprite()` siguen siendo `pass` (sin cambios).
- [ ] Al bloquear un `Projectile` con `parryable = true` (`is_blocking = true` y el proyectil entra en `ShieldHitbox`): el proyectil se destruye, `EventBus.disc_blocked(false)` se emite (sin cambios de spec 13), el `Player` recibe un impulso de velocidad en la dirección en que viajaba el proyectil (`stats.block_knockback_speed`), y se llama `Juice.shake(stats.block_shake_intensity)`.
- [ ] El impulso de knockback se disipa solo mediante el `move_toward` de aceleración/fricción ya existente (sin temporizador ni estado nuevo), y no impide seguir moviéndose ni bloqueando en los frames siguientes.
- [ ] Un `Projectile` con `parryable = false` que entra en `ShieldHitbox` **no** dispara knockback ni shake (sigue de largo, igual que spec 13).
- [ ] Un `Projectile` (`parryable` o no) que golpea el cuerpo principal del `Player` **sin** pasar por `ShieldHitbox` (por la espalda, o sin `is_blocking`) se destruye sin ningún efecto — sin knockback, sin shake, sin daño real — exactamente igual que spec 13.
- [ ] No se agrega `HealthComponent`, `HurtboxComponent`, HP ni ninguna señal nueva a `EventBus`.
- [ ] No se agrega lógica de ángulo/cono frontal-espalda; la distinción sigue siendo puramente geométrica vía la posición del `ShieldHitbox`.
- [ ] La `Camera2D` de `test_arena.tscn` no cambia (sigue estática, sin seguimiento del `Player`).
- [ ] `docs/tasks.md` no se modifica.
- [ ] F6 en `test_arena.tscn`: los 4 escenarios del plan (bloqueo con feedback, bloqueo repetido sin estado inconsistente, golpe sin bloquear sin efecto, `parryable = false` sin efecto) se comportan como se describe, sin errores en consola, repetible varias veces.

## Decisions

- **Sí:** knockback como impulso directo de `velocity` (`velocity = body.velocity.normalized() * stats.block_knockback_speed`), disipado por el `move_toward` de aceleración/fricción ya existente. _Razón: reusa el mismo mecanismo de blending que dash/movimiento normal (spec 05/07); ningún estado ni temporizador nuevo — el "leve" del pedido se logra dejando que la fricción existente lo apague solo, sin necesidad de una duración configurable aparte._
- **Sí:** dirección del knockback = dirección de viaje del proyectil bloqueado (`body.velocity.normalized()`), no la dirección jugador→proyectil ni la del cursor. _Razón: es la lectura más simple de "recular por el impacto" — el proyectil ya trae su dirección calculada; evita reconstruir un vector nuevo a partir de posiciones._
- **Sí:** `block_knockback_speed` y `block_shake_intensity` como campos de `PlayerStats`. _Razón: regla `CLAUDE.md` anti-números-mágicos, mismo patrón que `block_speed_multiplier` (spec 12) — ajustables en el editor sin tocar código._
- **Sí:** implementar `Juice.shake()` real ahora, adelantando una porción mínima de la tarea `1.9` (Juice v1). _Razón: decisión del usuario — sin un shake visible, la verificación manual F6 de esta spec no podría confirmar el feedback de bloqueo; se acota a solo `shake()`, dejando `hit_stop`/`slowmo`/`flash_sprite` como stub para no adelantar el resto de `1.9`._
- **Sí:** `Juice.shake()` usa `get_viewport().get_camera_2d()` (la cámara activa del árbol), sin que `player.gd` guarde una referencia propia a la cámara. _Razón: mantiene `Juice` desacoplado y reutilizable por cualquier emisor futuro (rebote de disco, muerte de enemigo), consistente con la regla de desacoplamiento por señales/autoloads de `CLAUDE.md`._
- **Sí:** "frontal" sigue siendo puramente geométrico (lo que entra en `ShieldHitbox`), sin chequeo de ángulo/cono nuevo. _Razón: decisión del usuario — el `ShieldHitbox` ya solo existe en la posición frontal (offset del `ShieldPivot` orientado al cursor, spec 13); agregar un chequeo de ángulo sería lógica duplicada para el mismo resultado que ya se obtiene gratis por geometría._
- **No:** HP real / `HealthComponent` / señal `player_damaged` para los golpes por la espalda. _Razón: decisión del usuario — mantiene la línea de spec 13 (no adelantar lógica de vida a medias); "el daño entra" se documenta como "sin bloqueo, sin mitigar", y el efecto real llega íntegro con la tarea `2.1`._
- **No:** reflejar o redirigir el proyectil al bloquearlo. _Razón: fuera de alcance de este pedido; sigue destruyéndose (`body.block()`), mismo criterio que spec 13._
- **No:** que la cámara siga al `Player`. _Razón: no fue parte del pedido; el shake funciona igual sobre una cámara estática (jitter de `offset`), y agregar seguimiento de cámara es una feature aparte._
- **No:** marcar `docs/tasks.md`. _Razón: no hay tarea explícita para este feedback de bloqueo en la lista de Fase 1/2; mismo criterio que specs 06/12/13._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                    | Mitigación                                                                                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| El knockback aplicado directo a `velocity` durante `is_blocking` puede sentirse extraño si el jugador sigue empujando el input de movimiento en dirección contraria al impulso: el `move_toward` tirará hacia `target_velocity` de inmediato, pudiendo "cancelar" el recule en 1-2 frames si `acceleration_time` es bajo. | No bloqueante: mismo comportamiento que cualquier cambio de `velocity` externo (ej. rebote físico); si en playtesting el recule se siente demasiado débil, se ajusta `block_knockback_speed` o se evalúa un `rate` de retorno más lento solo durante el recule, sin cambiar la arquitectura.                                       |
| Adelantar `Juice.shake()` real (parte de la tarea `1.9`) antes de que exista el resto de Juice v1 (partículas, SFX) podría generar inconsistencia de expectativas: un impacto bloqueado tiembla la cámara pero no tiene partículas ni sonido todavía.                                                                     | No bloqueante: aceptado explícitamente por el usuario; el resto de Juice v1 llega íntegro en la tarea `1.9` y se integrará sobre la misma llamada a `Juice.shake()` ya existente.                                                                                                                                                  |
| `get_viewport().get_camera_2d()` depende de que haya una `Camera2D` con `enabled = true` en el árbol activo; si una escena futura no tiene cámara (o tiene más de una sin la correcta activa), `shake()` no hace nada silenciosamente.                                                                                    | No bloqueante: el guard `if not camera: return` ya cubre el caso sin cámara sin lanzar error; es el mismo patrón defensivo que otros autoloads del proyecto. Si se nota en una escena futura, se resuelve ahí (asignar `Camera2D` correcta), sin tocar `juice.gd`.                                                                 |
| Múltiples bloqueos consecutivos muy rápidos podrían encolar varios `Tween` de shake simultáneos sobre la misma `Camera2D`, compitiendo por la propiedad `offset` y produciendo un tembleque no uniforme.                                                                                                                  | No bloqueante para esta spec (el `fire_interval` del `TrainingDummy` es de 2s, muy por encima de la duración del shake de 0.2s); si en combate real con múltiples proyectiles se nota el solapamiento, se resuelve en la tarea `1.9` (ej. matar el tween anterior antes de crear uno nuevo), sin cambiar el contrato de `shake()`. |

## What is **not** in this spec

- `HealthComponent`/`HurtboxComponent` y daño real al jugador (golpes por la espalda siguen sin consecuencia).
- Detección de ángulo/cono frontal-espalda explícita.
- Knockback/shake en golpes no `parryable`.
- Reflejar o redirigir el proyectil bloqueado.
- Ventana de parry perfecto.
- Seguimiento de cámara.
- SFX del bloqueo/impacto.
- Partículas, flash de impacto, o el resto de Juice v1 (`hit_stop`, `slowmo`, `flash_sprite`).
- Controles táctiles.
- Cambios a `docs/tasks.md`.

Cada una de estas, si llega, tendrá su propia spec.
