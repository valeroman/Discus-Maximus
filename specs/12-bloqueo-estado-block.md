# SPEC 12 — Bloqueo: estado `BLOCK` (escudo frontal, velocidad 40%, no lanzar)

> **Status:** Aprobado
> **Depends on:** [05-jugador-movimiento-8-direcciones.md](05-jugador-movimiento-8-direcciones.md), [06-jugador-apuntado-cursor.md](06-jugador-apuntado-cursor.md), [07-dash-i-frames-cooldown.md](07-dash-i-frames-cooldown.md), [08-disc-fsm-lanzamiento.md](08-disc-fsm-lanzamiento.md)
> **Date:** 2026-07-16
> **Objective:** Agregar al `Player` un estado de bloqueo sostenido (`BLOCK`), disponible **solo con el disco en mano** (`has_disc`), activado con la acción `block` (Left Shift, ya mapeada), que mientras está activo reduce la velocidad de movimiento al 40% (`block_speed_multiplier`), impide lanzar el disco y muestra un indicador visual en el disco/escudo frontal; el dash cancela el bloqueo.

## Scope

**In:**

- `entities/player/player_stats.gd`: agregar `@export var block_speed_multiplier: float = 0.4` a `PlayerStats` (fracción de `move_speed` mientras `BLOCK` está activo).
- `data/player_stats.tres`: setear `block_speed_multiplier = 0.4` (conservando `move_speed`, `acceleration_time`, `friction_time`, `dash_speed`, `dash_duration`, `dash_cooldown`).
- `entities/player/player.gd`:
  - Nueva var pública `var is_blocking: bool = false` (estado runtime, inspeccionable en pestaña "Remote"; sin `@export`, mismo patrón que `is_invulnerable`).
  - Cada frame en `_physics_process`, **después** del chequeo de dash, recalcular: `is_blocking = Input.is_action_pressed("block") and has_disc and not is_invulnerable`.
  - Movimiento: escalar la velocidad objetivo por `stats.block_speed_multiplier` mientras `is_blocking` (velocidad tope al 40%); el bloque de aceleración/fricción existente sigue corriendo (no se congela como en el dash).
  - Lanzamiento: agregar la guarda `and not is_blocking` a la condición de `throw` (no se puede lanzar mientras se bloquea).
  - Indicador visual: mientras `is_blocking`, tintar `disc.modulate` al acento neón (`#00f0ff`); al soltar, restaurar a blanco (`Color.WHITE`). Directo en `player.gd`, sin tocar `Juice`.
- Verificación manual en `test_arena.tscn` (F6).

**Out of scope (specs futuras):**

- `ShieldHitbox` (Area2D, capa 7) y cualquier colisión/bloqueo real de proyectiles — spec futura (no hay proyectiles enemigos hasta Fase 2, tareas 2.x).
- **Parry** (ventana de bloqueo perfecto, `ParryWindowTimer`, reflejar/aturdir) — spec futura propia.
- Daño al jugador / `HealthComponent` / consumir `is_blocking` para reducir o anular daño — Fase 2.
- Señales nuevas en `EventBus` (`player_block_started`/`player_block_ended`) — no se agregan (sin consumidor todavía; mismo criterio que spec 07 con `is_invulnerable`).
- Cambios al Input Map — la acción `block` ya existe (Left Shift, `physical_keycode 4194325`, desde spec 02).
- VFX/SFX del bloqueo (partículas, sonido de impacto contra el escudo) — Juice v1 (tarea 1.9) y pase de audio (Fase 4).
- Sprite/hitbox propios del `ShieldPivot` — el indicador visual reusa el `Disc` ya montado en `ShieldPivot`.
- Controles táctiles del bloqueo (botón/gesto) — tarea 4.5, Fase 4.
- Cambios en `docs/tasks.md` — no hay tarea de bloqueo en la lista de Fase 1 (1.1–1.9); se deja intacto (mismo criterio que spec 06).
- Bloquear mientras el disco está lanzado (`FLYING`/`RETURNING`) — `BLOCK` requiere `has_disc`; con disco fuera no hay escudo.

## Data model

**`entities/player/player_stats.gd`** (1 campo nuevo, resto intacto):

```gdscript
class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0
@export var acceleration_time: float = 0.1
@export var friction_time: float = 0.1

@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0

@export var block_speed_multiplier: float = 0.4   # fracción de move_speed mientras BLOCK está activo
```

**`data/player_stats.tres`**: agregar `block_speed_multiplier = 0.4` (conservando los 6 campos previos).

**`entities/player/player.gd`** (var nueva + cambios en `_physics_process`; sin cambios en `_ready`/handlers de dash/disc):

```gdscript
var is_blocking: bool = false

func _physics_process(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash") and input_direction != Vector2.ZERO and dash_cooldown_timer.is_stopped():
		velocity = input_direction.normalized() * stats.dash_speed
		is_invulnerable = true
		dash_timer.wait_time = stats.dash_duration
		dash_cooldown_timer.wait_time = stats.dash_cooldown
		dash_timer.start()
		dash_cooldown_timer.start()

	is_blocking = Input.is_action_pressed("block") and has_disc and not is_invulnerable

	if not is_invulnerable:
		var speed := stats.move_speed * (stats.block_speed_multiplier if is_blocking else 1.0)
		var target_velocity := input_direction * speed
		var rate := stats.move_speed / stats.acceleration_time if input_direction != Vector2.ZERO else stats.move_speed / stats.friction_time
		velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

	if is_invulnerable:
		var elapsed := stats.dash_duration - dash_timer.time_left
		sprite.modulate.a = 1.0 if int(elapsed / 0.05) % 2 == 0 else 0.4

	shield_pivot.rotation = (get_global_mouse_position() - global_position).angle()

	disc.modulate = Color("#00f0ff") if is_blocking else Color.WHITE

	if Input.is_action_just_pressed("throw") and has_disc and not is_blocking:
		var direction := (get_global_mouse_position() - global_position).normalized()
		disc.throw(direction)
		has_disc = false

	if Input.is_action_just_pressed("recall") and not has_disc:
		disc.recall()
```

Convenciones:

- `is_blocking` se recalcula **después** del bloque de dash: si en el mismo frame se dispara el dash (`is_invulnerable = true`), la guarda `and not is_invulnerable` deja `is_blocking = false` → el dash cancela el bloqueo. Si el jugador sigue sosteniendo `block` al terminar el dash, el bloqueo se reanuda solo (control sostenido).
- El escalado de velocidad solo afecta la **velocidad tope** (`target_velocity`); el `rate` de aceleración/fricción sigue derivado de `move_speed`, así el frenado/arranque conserva su tacto.
- El `ShieldPivot` sigue rotando hacia el cursor durante `BLOCK` (escudo frontal apunta al mouse).
- El indicador visual reusa `disc.modulate` (el `Disc` cuelga de `ShieldPivot` en `HELD`, exactamente cuando `BLOCK` es posible); se restaura a `Color.WHITE` al soltar. Acoplamiento ligero player→disc coherente con `disc.throw()`/`disc.recall()` ya presentes.
- `is_blocking` no persiste en `PlayerStats` (estado runtime, no configurable), igual que `is_invulnerable`.

## Implementation plan

1. En `entities/player/player_stats.gd`, agregar `@export var block_speed_multiplier: float = 0.4`.
2. Abrir `data/player_stats.tres` en el editor y setear `block_speed_multiplier = 0.4` (confirmar que los otros 6 campos siguen intactos).
3. En `entities/player/player.gd`, agregar `var is_blocking: bool = false`.
4. En `_physics_process`, tras el bloque de dash, agregar `is_blocking = Input.is_action_pressed("block") and has_disc and not is_invulnerable`.
5. Modificar el bloque de movimiento para escalar la velocidad tope por `stats.block_speed_multiplier` cuando `is_blocking` (dejando el `rate` derivado de `move_speed`).
6. Agregar `disc.modulate = Color("#00f0ff") if is_blocking else Color.WHITE` junto a la rotación del `ShieldPivot`.
7. Agregar la guarda `and not is_blocking` a la condición del `throw`.
8. F6 `test_arena.tscn`: mantener Left Shift con disco en mano → confirmar que el jugador se mueve al ~40% y el disco se tinta al acento neón.
9. F6: con Left Shift sostenido, intentar lanzar (click izquierdo) → confirmar que **no** lanza; soltar Shift y lanzar → confirmar que lanza normal.
10. F6: con Left Shift sostenido, presionar dash (espacio) con dirección → confirmar que el dash se ejecuta (i-frames) y el bloqueo se corta ese lapso; al terminar el dash con Shift aún sostenido, el bloqueo se reanuda.
11. F6: lanzar el disco y mantener Shift → confirmar que **no** entra en `BLOCK` (sin disco en mano; sin tinte, velocidad normal).
12. Confirmar en consola: sin errores; `is_blocking` cambia correctamente (verificable en pestaña "Remote" o `print()` temporal); retirar `print()` temporales.
13. Marcar el spec como `Implemented` (no hay tarea en `docs/tasks.md` que marcar).

## Acceptance criteria

- [ ] `PlayerStats` tiene `block_speed_multiplier` (`float`, default `0.4`) sin remover los 6 campos previos.
- [ ] `data/player_stats.tres` tiene `block_speed_multiplier = 0.4` (y conserva `move_speed`, `acceleration_time`, `friction_time`, `dash_speed`, `dash_duration`, `dash_cooldown`).
- [ ] `player.gd` tiene `var is_blocking: bool` que se recalcula cada frame como `Input.is_action_pressed("block") and has_disc and not is_invulnerable`.
- [ ] Con disco en mano y `block` sostenido, la velocidad tope del jugador es `move_speed * block_speed_multiplier` (~40%); al soltar `block`, vuelve a `move_speed`.
- [ ] Mientras `is_blocking`, presionar `throw` (click izquierdo) **no** lanza el disco; al soltar `block`, `throw` funciona normal.
- [ ] Presionar `dash` durante `BLOCK` ejecuta el dash (con i-frames) y `is_blocking` pasa a `false` ese lapso; si `block` sigue sostenido al terminar el dash, `is_blocking` vuelve a `true`.
- [ ] Con el disco lanzado (`not has_disc`), sostener `block` **no** activa `BLOCK` (`is_blocking` permanece `false`, sin penalización de velocidad ni tinte).
- [ ] Mientras `is_blocking`, `disc.modulate` cambia al acento neón (`#00f0ff`); al dejar de bloquear vuelve a `Color.WHITE`.
- [ ] El `ShieldPivot` sigue rotando hacia el cursor durante `BLOCK`.
- [ ] No se agrega `ShieldHitbox`, `Area2D`, ni nodo nuevo a `player.tscn`.
- [ ] No se agregan señales nuevas a `EventBus`; `autoload/juice.gd` permanece stub.
- [ ] El Input Map (`project.godot`) no cambia (la acción `block` ya existía en Left Shift).
- [ ] F6 en `test_arena.tscn`: velocidad al 40%, no-lanzar, dash-cancela-bloqueo y bloqueo-solo-con-disco se comportan como arriba, sin errores en consola, repetible varias veces sin estado inconsistente.

## Decisions

- **Sí:** `BLOCK` como flag `is_blocking: bool` recalculado por frame, no una FSM/enum. _Razón: el `Player` ya modela su estado con flags (`has_disc`, `is_invulnerable`); una FSM formal sería sobre-ingeniería para un estado sostenido derivado del input._
- **Sí:** input = acción `block` sostenida (`is_action_pressed`), en tecla dedicada (Left Shift, ya mapeada). _Razón: decisión del usuario — separa `BLOCK` de `recall` (que reusa click derecho), y sostenido es el patrón arcade de guardia; la acción ya existía en el Input Map, cero cambios._
- **Sí:** `BLOCK` solo con `has_disc` (disco en `HELD`). _Razón: requisito del usuario — el disco ES el escudo; sin disco en mano no hay nada que interponer._
- **Sí:** dash cancela `BLOCK` vía la guarda `not is_invulnerable`. _Razón: decisión del usuario — dash e i-frames tienen prioridad como movida de escape; recalcular `is_blocking` tras el dash lo suprime sin lógica extra, y se reanuda solo si se mantiene el input._
- **Sí:** velocidad al 40% como campo `block_speed_multiplier` en `PlayerStats`. _Razón: regla `CLAUDE.md` anti-números-mágicos; ajustable en el editor, mismo patrón que `dash_speed`/`move_speed`._
- **Sí:** escalar solo la velocidad tope, dejando `rate` (accel/fricción) derivado de `move_speed`. _Razón: mantiene el tacto de arranque/frenado ya afinado en spec 05; el bloqueo cambia el techo de velocidad, no la respuesta._
- **Sí:** indicador visual mínimo tintando `disc.modulate` al acento neón, directo en `player.gd`. _Razón: la opción elegida pide indicador visual; `Juice` sigue stub (VFX real es tarea 1.9) y el `Disc` en `ShieldPivot` es el objeto natural del escudo._
- **No:** `ShieldHitbox`/`Area2D` ni bloqueo real de colisión. _Razón: decisión del usuario — no hay proyectiles enemigos hasta Fase 2; agregar hitbox sin nada que bloquear es prematuro (mismo criterio que `is_invulnerable` sin consumidor en spec 07)._
- **No:** parry / ventana de bloqueo perfecto. _Razón: mecánica distinta y más grande; merece su propia spec cuando exista daño entrante._
- **No:** señales nuevas en `EventBus`. _Razón: sin consumidor (UI/audio/VFX aún stub); mismo criterio anti-señales-especulativas de spec 07._
- **No:** marcar `docs/tasks.md`. _Razón: no hay tarea de bloqueo en la lista de Fase 1 (1.1–1.9); se deja intacto, igual que spec 06._

## Risks

| Riesgo                                                                                                                                                                            | Mitigación                                                                                                                                                                                                                  |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| El indicador visual acopla `player.gd` a `disc.modulate`; una spec futura de VFX del disco (Juice, estados) podría querer controlar `modulate` y pisarse con el tinte de bloqueo. | No bloqueante: es una línea reversible; cuando llegue Juice v1 (tarea 1.9) o el VFX del disco, se centraliza el `modulate` (ej. el propio `Disc` expone un método de estado visual) y `player.gd` deja de tintarlo directo. |
| `block_speed_multiplier = 0.4` podría sentirse demasiado lento o demasiado rápido antes de tener enemigos para probar en combate real.                                            | No bloqueante: es campo de `PlayerStats` ajustable en el editor sin tocar código; se afina en playtesting de Fase 2 junto a `move_speed`/`dash`.                                                                            |
| Reanudar `BLOCK` automáticamente tras el dash (input sostenido) podría sorprender si el jugador esperaba "un dash apaga el bloqueo hasta re-presionar".                           | Comportamiento estándar de control sostenido y coherente con `is_action_pressed`; si molesta en playtesting se cambia a requerir re-pulsar (soltar+mantener) sin cambio de arquitectura.                                    |
| `is_blocking` es convención implícita sin contrato formal; el futuro `HealthComponent` (Fase 2) que lo consuma para mitigar daño podría esperar otro nombre/semántica.            | No bloqueante: se documenta nombre/tipo (`bool`); la spec de daño referenciará este campo al implementarse, igual que hará con `is_invulnerable`.                                                                           |

## What is **not** in this spec

- `ShieldHitbox` (Area2D capa 7) y bloqueo real de proyectiles.
- Parry / ventana de bloqueo perfecto.
- Daño al jugador / `HealthComponent` que consuma `is_blocking`.
- Señales nuevas en `EventBus`.
- VFX/SFX del bloqueo.
- Sprite/hitbox propios del `ShieldPivot`.
- Controles táctiles del bloqueo.
- Cambios al Input Map o a `docs/tasks.md`.
- Bloquear con el disco lanzado.

Cada una de estas, si llega, tendrá su propia spec.
