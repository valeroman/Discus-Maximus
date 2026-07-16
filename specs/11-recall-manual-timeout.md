# SPEC 11 — Recall manual (`recall`) + timeout de seguridad de 4s

> **Status:** Implementado
> **Depends on:** [08-disc-fsm-lanzamiento.md](08-disc-fsm-lanzamiento.md), [10-retorno-curvo-steering.md](10-retorno-curvo-steering.md)
> **Date:** 2026-07-16
> **Objective:** Agregar dos triggers de retorno al disco además de "rebotes agotados": `recall` manual (click derecho durante `FLYING` → transiciona a `RETURNING` con el mismo steering curvo de spec 10, emitiendo `EventBus.disc_recalled`) y un timeout de seguridad de 4s desde el `throw` que, al expirar en cualquier estado distinto de `HELD`, fuerza la recogida instantánea (`_return_to_held()`) para que el disco nunca quede atascado/orbitando.

## Scope

**In:**

- `entities/disc/disc_stats.gd`: agregar `@export var flight_timeout: float = 4.0` (segundos; tiempo máx. desde `throw` hasta forzar recogida — seguridad anti-atasco, tarea `1.6`).
- `data/disc_stats.tres`: setear `flight_timeout = 4.0` (conservando `fly_speed`, `max_bounces`, `return_speed`, `return_turn_rate`, `catch_radius`).
- `entities/disc/disc.gd`:
  - Nueva var `var flight_time: float = 0.0` (acumulador del tiempo desde el `throw`).
  - En `throw()`: resetear `flight_time = 0.0`.
  - En `_physics_process`: mientras `state != HELD`, acumular `flight_time += _delta`; si `flight_time >= stats.flight_timeout`, llamar `_return_to_held()` y retornar (recogida forzada, gana sobre cualquier otra lógica del frame).
  - Nuevo método público `recall()`: si `state == State.FLYING`, transicionar a `State.RETURNING` reescalando `velocity` a `return_speed` conservando la dirección (idéntico a la rama "rebotes agotados" de spec 10), y emitir `EventBus.disc_recalled`. En cualquier otro estado, no hace nada.
- `entities/player/player.gd`: en `_physics_process`, agregar detección de `Input.is_action_just_pressed("recall")` con `not has_disc` → `disc.recall()`.
- Marcar la tarea `1.6` como `[x]` en `docs/tasks.md`.
- Verificación manual en `test_arena.tscn` (F6).

**Out of scope (specs futuras):**

- Preview de puntería (`Line2D` + raycast) — tarea `1.7`.
- Daño a enemigos / hit-stop / knockback durante `RETURNING` — Fase 2 (no hay enemigos).
- SFX/VFX de recall o de recogida forzada por timeout — Juice v1, tarea `1.9`.
- Consumo de `EventBus.disc_recalled` por UI/audio/VFX — Fase 4 / Juice v1.
- Timeout emitiendo una señal propia (`disc_recalled` u otra) — decisión tomada: no.
- Segundo recall en `RETURNING` como atajo a catch instantáneo — descartado.
- Controles táctiles del recall (tap corto derecho) — tarea `4.5`.
- Cualquier cambio a la lógica de `FLYING`/rebotes (spec 09) o al steering de `RETURNING` (spec 10) — permanecen intactos.

## Data model

**`entities/disc/disc_stats.gd`** (1 campo nuevo):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0
@export var max_bounces: int = 2
@export var return_speed: float = 700.0
@export var return_turn_rate: float = 4.0
@export var catch_radius: float = 20.0
@export var flight_timeout: float = 4.0   # s, tiempo máx desde throw hasta forzar recogida (seguridad anti-atasco, tarea 1.6)
```

**`data/disc_stats.tres`**: agregar `flight_timeout = 4.0`.

**`entities/disc/disc.gd`** (var nueva + cambios en `throw`/`_physics_process` + método `recall`; `_return_to_held()` NO cambia):

```gdscript
var flight_time: float = 0.0

func throw(direction: Vector2) -> void:
	var origin := global_position
	reparent(get_tree().current_scene, false)
	global_position = origin
	state = State.FLYING
	velocity = direction.normalized() * stats.fly_speed
	bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))
	flight_time = 0.0
	EventBus.disc_thrown.emit(origin, direction)

func recall() -> void:
	if state != State.FLYING:
		return
	state = State.RETURNING
	velocity = velocity.normalized() * stats.return_speed
	EventBus.disc_recalled.emit()

func _physics_process(_delta: float) -> void:
	if state != State.HELD:
		flight_time += _delta
		if flight_time >= stats.flight_timeout:
			_return_to_held()
			return

	if state == State.FLYING:
		var collision := move_and_collide(velocity * _delta)
		if collision:
			if bounces_left > 0:
				velocity = velocity.bounce(collision.get_normal())
				bounces_left -= 1
				EventBus.disc_bounced.emit(collision.get_position(), bounces_left)
			else:
				state = State.RETURNING
				velocity = velocity.normalized() * stats.return_speed
	elif state == State.RETURNING:
		var to_target := held_parent.global_position - global_position
		var desired_direction := to_target.normalized()
		var angle_to_desired := velocity.angle_to(desired_direction)
		var max_step := stats.return_turn_rate * _delta
		velocity = velocity.rotated(clampf(angle_to_desired, -max_step, max_step))
		global_position += velocity * _delta
		if to_target.length() <= stats.catch_radius:
			_return_to_held()
```

**`entities/player/player.gd`** (en `_physics_process`, junto al bloque de `throw`):

```gdscript
if Input.is_action_just_pressed("recall") and not has_disc:
	disc.recall()
```

Convenciones:

- El chequeo de timeout va **primero** en `_physics_process` y hace `return`: gana sobre rebote/steering del mismo frame, garantizando la recogida aunque el disco esté orbitando en `RETURNING`.
- `flight_time` acumula en `FLYING` y `RETURNING` (todo estado `!= HELD`); `_return_to_held()` deja `state = HELD`, así la acumulación se detiene sola hasta el próximo `throw` (que la resetea).
- `recall()` reusa exactamente la transición de la rama "rebotes agotados" de spec 10 (misma reescala de `velocity` a `return_speed`, misma dirección conservada) — el steering curvo de `RETURNING` es idéntico, solo cambia el trigger.
- La guarda `not has_disc` en `player.gd` refleja el mismo patrón que `throw` (`has_disc`); `recall()` además se auto-protege (`state != FLYING → return`), así que un recall en `RETURNING` es inofensivo.
- No se agregan campos `@export` a `disc.gd`; `flight_timeout` vive en `DiscStats` (mismo patrón que `fly_speed`/`return_speed`).

## Implementation plan

1. En `entities/disc/disc_stats.gd`, agregar `@export var flight_timeout: float = 4.0`.
2. Abrir `data/disc_stats.tres` en el editor y setear `flight_timeout = 4.0` (confirmar que los otros 5 campos siguen intactos).
3. En `entities/disc/disc.gd`, agregar `var flight_time: float = 0.0`.
4. En `throw()`, agregar `flight_time = 0.0` (antes de emitir `disc_thrown`).
5. En `_physics_process`, al inicio, agregar el bloque `if state != State.HELD: flight_time += _delta; if flight_time >= stats.flight_timeout: _return_to_held(); return`.
6. Agregar el método `recall()` (guard `state != FLYING`, transición a `RETURNING`, reescala de `velocity`, `EventBus.disc_recalled.emit()`).
7. En `entities/player/player.gd` `_physics_process`, agregar `if Input.is_action_just_pressed("recall") and not has_disc: disc.recall()`.
8. F6 `test_arena.tscn`: lanzar, **click derecho** mientras vuela → confirmar que corta el vuelo y emprende el arco curvo de retorno hacia el jugador (mismo comportamiento que rebotes agotados) y se recoge.
9. F6: lanzar y **no** recoger (dejar orbitar/volar); confirmar que a los ~4s el disco se recoge solo (catch forzado) sin importar el estado.
10. F6: confirmar que un recall en `HELD` (disco ya en mano) o durante `RETURNING` no rompe nada (no-op).
11. Confirmar en consola: sin errores; `disc_recalled` se emite solo en recall manual (no en timeout) — verificable con `print()` temporal o pestaña "Remote".
12. Retirar `print()` temporales; marcar tarea `1.6` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `DiscStats` tiene `flight_timeout` (`float`, default `4.0`) sin remover los 5 campos previos.
- [ ] `data/disc_stats.tres` tiene `flight_timeout = 4.0` (y conserva `fly_speed`, `max_bounces`, `return_speed`, `return_turn_rate`, `catch_radius`).
- [ ] `disc.gd` tiene `var flight_time` que se resetea a `0.0` en cada `throw()`.
- [ ] Mientras `state != HELD`, `flight_time` acumula `_delta` cada frame; al alcanzar `stats.flight_timeout` se llama `_return_to_held()` y se corta el resto del frame (`return`).
- [ ] El timeout fuerza la recogida tanto si el disco está en `FLYING` como en `RETURNING` (cubre el caso "orbita sin converger" de spec 10).
- [ ] `disc.recall()` en `FLYING` transiciona a `RETURNING`, reescala `velocity` a `return_speed` conservando dirección, y emite `EventBus.disc_recalled`.
- [ ] `disc.recall()` en `HELD` o `RETURNING` no hace nada (no cambia estado, no emite señal).
- [ ] Presionar `recall` (click derecho) con `not has_disc` durante `FLYING` inicia el retorno curvo (steering idéntico a spec 10) y termina en recogida (`disc_caught`, `has_disc = true`).
- [ ] `EventBus.disc_recalled` se emite **solo** en recall manual; el timeout NO emite señal nueva.
- [ ] `_return_to_held()` permanece exactamente igual que en specs 08/10.
- [ ] La lógica de `FLYING`/rebotes (spec 09) y el steering de `RETURNING` (spec 10) no cambian.
- [ ] `EventBus` (`autoload/event_bus.gd`) permanece sin cambios en su declaración (se reutiliza `disc_recalled`, ya declarada desde spec 01).
- [ ] F6 en `test_arena.tscn`: recall manual, timeout a 4s, y recall no-op se comportan como arriba, sin errores en consola, repetible varias veces sin estado inconsistente.
- [ ] `docs/tasks.md` tiene la tarea `1.6` marcada como `[x]`.

## Decisions

- **Sí:** timeout = 4s desde `throw` cubriendo el ciclo completo (`FLYING`+`RETURNING`); al expirar fuerza `_return_to_held()` instantáneo. _Razón: decisión del usuario — resuelve directamente el riesgo documentado en spec 10 (disco orbitando sin converger en `RETURNING`); un timeout que solo cubriera `FLYING` dejaría ese caso abierto._
- **Sí:** chequeo de timeout al inicio de `_physics_process` con `return` (gana sobre rebote/steering del frame). _Razón: garantiza la recogida como red de seguridad incondicional, sin importar en qué rama esté el disco._
- **Sí:** `flight_timeout` como campo de `DiscStats` (`Resource`) + acumulador `float`. _Razón: decisión del usuario — sin números mágicos (regla `CLAUDE.md`), ajustable en el editor; el acumulador es coherente con la física manual del disco (spec 10 ya actualiza `global_position` a mano) y evita agregar un nodo `Timer` a `disc.tscn`._
- **Sí:** recall solo válido en `FLYING`, reusando la transición de "rebotes agotados" de spec 10. _Razón: decisión del usuario — un solo camino de entrada a `RETURNING`, sin duplicar la lógica de steering; recall en otros estados no tiene sentido (en `HELD` ya está en mano)._
- **Sí:** `disc_recalled` se emite solo en recall manual. _Razón: decisión del usuario — separa semánticamente "el jugador pidió el disco" de "red de seguridad automática"; deja un hook limpio para SFX/HUD futuro sin ruido._
- **Sí:** guarda `not has_disc` en `player.gd` + auto-guarda en `recall()`. _Razón: simetría con el patrón de `throw` y defensa en profundidad (un recall mal temporizado nunca corrompe estado)._
- **No:** timeout emitiendo señal propia. _Razón: decisión del usuario — no hay consumidor todavía (Juice v1 sigue stub); mismo criterio anti-señales-especulativas de specs 08/10._
- **No:** segundo recall en `RETURNING` como atajo a catch instantáneo. _Razón: decisión del usuario — mantiene recall con un único efecto claro; el timeout ya garantiza la recogida._
- **No:** SFX/VFX del recall o del catch forzado. _Razón: Juice v1 (tarea `1.9`); `autoload/juice.gd` sigue stub._

## Risks

| Riesgo                                                                                                                                                                       | Mitigación                                                                                                                                                                                                   |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `flight_timeout = 4.0` podría cortar retornos legítimos largos (arena grande + `return_speed` bajo + jugador lejos), recogiendo el disco antes de que llegue "naturalmente". | No bloqueante: es campo de `DiscStats` ajustable en el editor sin tocar código; se afina en playtesting junto a `return_speed`/`return_turn_rate` (spec 10). Es una red de seguridad, no el camino esperado. |
| El catch forzado por timeout puede sentirse abrupto (el disco "salta" a la mano sin feedback) igual que el teleport de specs 08/09.                                          | Comportamiento esperado/aceptado para esta spec; se suaviza con VFX/SFX en Juice v1 (tarea `1.9`).                                                                                                           |
| `recall` está mapeado al click derecho (botón 2); si una spec futura de UI usa click derecho para otra cosa, habría conflicto.                                               | No aplica hoy: es el único consumidor de `recall`; el Input Map es la fuente de verdad y se re-mapea sin tocar `disc.gd`/`player.gd`.                                                                        |

## What is **not** in this spec

- Preview de puntería (`Line2D` + raycast).
- Daño a enemigos / hit-stop / knockback durante `RETURNING`.
- SFX/VFX de recall o de recogida forzada por timeout.
- Consumo de `EventBus.disc_recalled` por UI/audio/VFX.
- Timeout emitiendo una señal propia.
- Segundo recall en `RETURNING` como atajo a catch instantáneo.
- Controles táctiles del recall.
- Cambios a la lógica de `FLYING`/rebotes (spec 09) o al steering de `RETURNING` (spec 10).

Cada una de estas, si llega, tendrá su propia spec.
