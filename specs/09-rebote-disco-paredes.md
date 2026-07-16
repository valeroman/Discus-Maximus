# SPEC 09 — Rebote físico del disco en paredes con contador de rebotes

> **Status:** Aprobadosi

> **Depends on:** [08-disc-fsm-lanzamiento.md](08-disc-fsm-lanzamiento.md)
> **Date:** 2026-07-16
> **Objective:** Reemplazar el teleport instantáneo `FLYING → HELD` de cualquier colisión con pared por un rebote físico real (`velocity.bounce(normal)`) controlado por un contador `bounces_left` —inicializado en cada lanzamiento desde `DiscStats.max_bounces` (base 2) más `GameState.get_stat("disc_bounces")`—, de forma que el disco rebote 2 veces contra las paredes y recién en la 3ª colisión inicie el retorno a `HELD` ya existente.

## Scope

**In:**

- `entities/disc/disc_stats.gd`: agregar `@export var max_bounces: int = 2` (RF-2.3, "base: 2, ampliable por mejoras").
- `data/disc_stats.tres`: setear `max_bounces = 2`.
- `entities/disc/disc.gd`:
  - Nueva variable `var bounces_left: int = 0`.
  - En `throw(direction)`: inicializar `bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))` (hoy `GameState.get_stat` es un stub que devuelve `0.0`, así que el bonus es inerte hasta la tarea 3.4, pero queda cableado).
  - En `_physics_process`, al detectar colisión durante `FLYING`:
    - Si `bounces_left > 0`: aplicar `velocity = velocity.bounce(collision.get_normal())`, decrementar `bounces_left -= 1`, emitir `EventBus.disc_bounced(collision.get_position(), bounces_left)`. El disco sigue en `FLYING` (no cambia de estado).
    - Si `bounces_left <= 0`: comportamiento actual de spec 08 sin cambios — llamar `_return_to_held()` (teleport instantáneo a `HELD` vía `RETURNING`).
  - Cualquier colisión detectada por `move_and_collide` se trata como "pared" (mismo criterio que spec 08: no se filtra por `collision_layer`, ya que no hay otros cuerpos físicos todavía).
- Marcar la tarea `1.4` como `[x]` en `docs/tasks.md`.
- Verificación manual en `test_arena.tscn` (F6): lanzar el disco en ángulo contra una pared del perímetro, confirmar visualmente 2 reflexiones reales (cambia de dirección, sigue en `FLYING`, mantiene velocidad) y que la 3ª colisión dispara el retorno instantáneo a `HELD` de siempre; confirmar `EventBus.disc_bounced` se emite en las 2 primeras colisiones (vía `print()` temporal o inspector) y no en la 3ª.

**Out of scope (para specs futuras):**

- Retorno con steering curvo hacia el jugador y daño de paso durante `RETURNING` — tarea `1.5`.
- Recall manual (`Input` acción `recall`) y timeout de seguridad — tarea `1.6`.
- Preview de puntería (`Line2D` + raycast mostrando trayectoria + rebotes) — tarea `1.7`.
- Daño a enemigos, perforar, hit-stop y knockback al impactar contra enemigos — no hay enemigos todavía (Fase 2).
- SFX/VFX de rebote (partículas, sonido, screen shake) — Juice v1, tarea `1.9`.
- Implementación real de la mejora "+1 rebote" ni del resto del sistema de mejoras (`GameState.get_stat` sigue siendo stub) — tarea `3.4`.
- Manejo del remainder de `move_and_collide` (distancia no consumida tras el rebote dentro del mismo frame) — misma limitación que ya existía en spec 08, no se resuelve aquí.
- Corrección de posibles rebotes en esquinas cóncavas o normales degeneradas — no se pide, se deja para playtesting/ajuste posterior.

## Data model

**`entities/disc/disc_stats.gd`** (campo nuevo agregado a la clase existente):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0   # px/s, velocidad durante FLYING (RF-2.1, design.md §3.1)
@export var max_bounces: int = 2       # rebotes base contra paredes antes de retornar (RF-2.3)
```

`data/disc_stats.tres`: se actualiza la instancia existente agregando `max_bounces = 2` (además de `fly_speed = 900.0` ya seteado en spec 08).

**`entities/disc/disc.gd`** (campo y lógica nuevos sobre la clase existente):

```gdscript
class_name Disc
extends CharacterBody2D

enum State { HELD, FLYING, RETURNING }

@export var stats: DiscStats

var state: State = State.HELD
var bounces_left: int = 0

@onready var held_parent: Node2D = get_parent()
@onready var held_position: Vector2 = position

func throw(direction: Vector2) -> void:
	var origin := global_position
	reparent(get_tree().current_scene, false)
	global_position = origin
	state = State.FLYING
	velocity = direction.normalized() * stats.fly_speed
	bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))
	EventBus.disc_thrown.emit(origin, direction)

func _physics_process(_delta: float) -> void:
	if state == State.FLYING:
		var collision := move_and_collide(velocity * _delta)
		if collision:
			if bounces_left > 0:
				velocity = velocity.bounce(collision.get_normal())
				bounces_left -= 1
				EventBus.disc_bounced.emit(collision.get_position(), bounces_left)
			else:
				_return_to_held()

func _return_to_held() -> void:
	state = State.RETURNING
	velocity = Vector2.ZERO
	reparent(held_parent, false)
	position = held_position
	rotation = 0.0
	state = State.HELD
	EventBus.disc_caught.emit()
```

Convenciones:

- `bounces_left` es estado runtime simple (`int`, sin `@export`), igual criterio que `is_invulnerable` en spec 07 — no configurable, se resetea en cada `throw()`.
- `EventBus.disc_bounced(position, bounces_left)` ya estaba declarada desde spec 01; esta es la primera spec que la emite realmente.
- No se agregan señales nuevas a `EventBus`; no se modifica `_return_to_held()` (mismo comportamiento exacto que spec 08).
- `GameState.get_stat("disc_bounces")` se llama tal cual está hoy (stub, devuelve `0.0`); no se modifica `autoload/game_state.gd` en esta spec.

## Implementation plan

1. En `entities/disc/disc_stats.gd`, agregar `@export var max_bounces: int = 2`.
2. Abrir `data/disc_stats.tres` en el editor y setear `max_bounces = 2` en el inspector (confirmar que `fly_speed = 900.0` sigue intacto).
3. En `entities/disc/disc.gd`, agregar `var bounces_left: int = 0`.
4. En `throw(direction)`, agregar la línea `bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))`, después de fijar `velocity` y antes (o después, sin que importe el orden) de emitir `EventBus.disc_thrown`.
5. Modificar `_physics_process`: dentro del `if collision:`, reemplazar la llamada directa a `_return_to_held()` por la rama condicional: si `bounces_left > 0`, aplicar `velocity = velocity.bounce(collision.get_normal())`, decrementar `bounces_left -= 1` y emitir `EventBus.disc_bounced(collision.get_position(), bounces_left)`; si no, llamar `_return_to_held()` (sin cambios en ese método).
6. Ejecutar `entities/player/player.tscn` standalone (F6): lanzar el disco contra una superficie sólida cercana (si existe alguna en esa escena) o pasar directo al paso 7 si `player.tscn` no tiene paredes de prueba.
7. Ejecutar `test_arena.tscn` (F6): lanzar el disco en ángulo (no perpendicular) contra una pared del perímetro. Confirmar visualmente que el disco cambia de dirección (reflexión, no desaparece), sigue viajando a la misma velocidad aproximada, y que esto ocurre 2 veces seguidas antes de que el disco retorne instantáneamente a `HELD` en la 3ª colisión.
8. Agregar temporalmente un `print()` en la rama de rebote y otro en `_return_to_held()` (o usar la pestaña "Remote" sobre `bounces_left`) para confirmar en consola: 2 emisiones de `disc_bounced` con `bounces_left` decreciendo (`1`, luego `0`), y que la 3ª colisión no emite `disc_bounced` sino solo `disc_caught`. Retirar los `print()` temporales antes de cerrar la spec.
9. Confirmar que tras volver a `HELD`, `has_disc` vuelve a `true` (`Player._on_disc_caught`) y un nuevo lanzamiento reinicia `bounces_left` correctamente (repetir el ciclo completo 2-3 veces seguidas sin errores en consola).
10. Marcar la tarea `1.4` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `entities/disc/disc_stats.gd` (`DiscStats`) tiene el campo `max_bounces` (`int`, default `2`).
- [ ] `data/disc_stats.tres` tiene `max_bounces = 2` (y conserva `fly_speed = 900.0`).
- [ ] `entities/disc/disc.gd` tiene la variable `bounces_left: int`, sin `@export`.
- [ ] Al lanzar el disco (`throw()`), `bounces_left` se inicializa en `stats.max_bounces + int(GameState.get_stat("disc_bounces"))` (hoy equivalente a `2 + 0 = 2`).
- [ ] Al chocar el disco contra una pared con `bounces_left > 0`: `velocity` se refleja con `velocity.bounce(collision.get_normal())` (cambia de dirección, mantiene magnitud), `bounces_left` se decrementa en 1, el disco permanece en `state == FLYING` (no pasa por `RETURNING`/`HELD`), y se emite `EventBus.disc_bounced(position, bounces_left)` con el `bounces_left` ya decrementado.
- [ ] Con `max_bounces = 2`, el disco rebota físicamente 2 veces contra paredes en un mismo vuelo antes de agotar el contador.
- [ ] Al chocar el disco contra una pared con `bounces_left <= 0` (3ª colisión con la configuración base), el disco NO rebota: se comporta exactamente como en spec 08 (`_return_to_held()` sin cambios — pasa por `RETURNING` y en el mismo frame vuelve a `HELD`, reparentado a `ShieldPivot`, `velocity = Vector2.ZERO`, posición/rotación restauradas).
- [ ] `EventBus.disc_bounced` NO se emite en la colisión que agota los rebotes (esa colisión emite únicamente `EventBus.disc_caught`, como en spec 08).
- [ ] Al volver a `HELD` tras agotar los rebotes, `EventBus.disc_caught` se emite y `Player.has_disc` vuelve a `true`, permitiendo un nuevo lanzamiento.
- [ ] Un nuevo lanzamiento reinicia `bounces_left` desde cero (no arrastra el valor agotado del vuelo anterior).
- [ ] Al ejecutar `test_arena.tscn` (F6), lanzar el disco en ángulo contra una pared del perímetro produce el ciclo completo (2 rebotes reales visibles seguidos de retorno instantáneo a `HELD`) sin errores en consola.
- [ ] Repetir el ciclo lanzar/rebotar×2/retornar varias veces seguidas no genera errores ni deja `bounces_left`, `state` o `has_disc` en un estado inconsistente.
- [ ] `entities/disc/disc.gd` no modifica `_return_to_held()` respecto a spec 08 (mismo cuerpo exacto).
- [ ] `autoload/game_state.gd` permanece sin cambios (sigue siendo stub, `get_stat` sigue devolviendo `0.0`).
- [ ] `EventBus` (`autoload/event_bus.gd`) permanece sin cambios en su declaración (no se agregan señales nuevas; `disc_bounced` ya estaba declarada desde spec 01).
- [ ] `docs/tasks.md` tiene la tarea `1.4` marcada como `[x]`.

## Decisions

- **Sí:** implementar rebote físico real (`velocity.bounce(normal)` + contador `bounces_left`), en vez de adoptar el modelo sin rebote de "Tron: Deadly Discs" (Intellivision, 1982). _Razón: decisión del usuario tras verificar que `docs/requirements.md` ya declara el rebote como "la fantasía central" del juego (RF-2.3, RF-5.2) y que la tarea `1.4` de `docs/tasks.md` lo pide explícitamente; la referencia a Tron: Deadly Discs queda como inspiración temática/visual, no de física._
- **Sí:** `max_bounces: int = 2` en `DiscStats` (`Resource`), en vez de hardcodear el valor en `disc.gd`. _Razón: sigue la regla no negociable de `CLAUDE.md` ("balance en Resources, nada de números mágicos hardcodeados"), mismo patrón que `fly_speed` (spec 08) y `dash_speed`/`dash_duration`/`dash_cooldown` (spec 07)._
- **Sí:** 2 rebotes físicos reales visibles antes de que la 3ª colisión dispare el retorno (`bounces_left: 2→1→0`, y recién con `bounces_left <= 0` se llama `_return_to_held()`). _Razón: decisión del usuario — es la lectura literal de RF-2.3 ("reflejarlo... hasta un máximo de N rebotes"); con `max_bounces = 2` el jugador ve 2 reflexiones reales, no 1._
- **Sí:** `bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))`, calculado en cada `throw()`, aunque `GameState.get_stat` sea hoy un stub que devuelve `0.0`. _Razón: decisión del usuario — sigue el patrón ya documentado en `design.md §5` ("el disco/jugador consultan stats vía `GameState.get_stat`"); evita tener que volver a tocar `disc.gd` cuando la tarea `3.4` (sistema de mejoras) implemente `+1 rebote` de verdad._
- **Sí:** `bounces_left` se recalcula por completo en cada `throw()` (no persiste ni se ajusta entre lanzamientos). _Razón: decisión del usuario — consistente con que `has_disc` ya bloquea lanzar mientras el disco vuela (spec 08); cada vuelo es un ciclo independiente._
- **Sí:** cualquier colisión detectada por `move_and_collide` durante `FLYING` se trata como "rebote de pared", sin filtrar por `collision_layer` del cuerpo colisionado. _Razón: decisión del usuario — mismo criterio ya usado en spec 08; no existen cuerpos físicos en `enemies`/`shield` todavía, filtrar sería lógica muerta hasta que existan (Fase 2)._
- **Sí:** `EventBus.disc_bounced(position, bounces_left)` se emite solo en colisiones que efectivamente rebotan (`bounces_left > 0` antes de decrementar), y NO en la colisión que agota el contador (esa emite únicamente `disc_caught`). _Razón: decisión del usuario — mantiene la semántica de la señal ("rebote real ocurrido"), evita que un listener futuro (VFX/SFX en `1.9`) dispare un efecto de rebote justo cuando el disco en realidad está retornando._
- **Sí:** `_return_to_held()` permanece exactamente igual que en spec 08 (teleport instantáneo, sin steering curvo). _Razón: pertenece a la tarea `1.5`, spec separada; esta spec solo cambia la condición que decide CUÁNDO se llama a ese método, no su cuerpo._
- **No:** manejo del remainder de `move_and_collide` (distancia no consumida por el rebote dentro del mismo frame). _Razón: decisión del usuario (implícita al no pedirlo) — misma limitación que ya existía en spec 08 antes de este cambio; no se introduce regresión, se puede ajustar en playtesting si el `fly_speed` alto genera tunneling perceptible._
- **No:** retorno con steering curvo, daño de paso, recall manual, timeout de seguridad, preview de puntería con rebotes. _Razón: pertenecen a las tareas `1.5`/`1.6`/`1.7`, specs separadas._
- **No:** daño a enemigos, perforar, hit-stop, knockback. _Razón: no existen enemigos todavía (Fase 2)._
- **No:** SFX/VFX de rebote (partículas, sonido, screen shake). _Razón: pertenece a Juice v1 (tarea `1.9`); `autoload/juice.gd` sigue siendo stub._
- **No:** implementación real de la mejora "+1 rebote" ni de `GameState.get_stat`/`apply_upgrade`. _Razón: pertenece a la tarea `3.4`, sistema de mejoras aún no existe; esta spec solo deja el punto de integración cableado._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                                                                                                     | Mitigación                                                                                                                                                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Con `fly_speed = 900 px/s`, si el rebote ocurre muy cerca de una esquina cóncava (donde dos paredes se encuentran), la normal devuelta por `move_and_collide` podría producir una reflexión que manda el disco directo a la segunda pared en el mismo o el siguiente frame, generando un rebote "extra" no visible como reflexión limpia (se ve raro pero sigue contando 1 rebote real de `bounces_left`). | No bloqueante para esta spec: es un caso de esquina, no rompe el contrato (`bounces_left` sigue decrementando 1 por colisión real); se ajusta en playtesting contra `test_arena.tscn` si se ve mal, sin cambiar la arquitectura del rebote.                             |
| El remainder de `move_and_collide` (distancia sobrante tras el impacto dentro del mismo frame) se ignora, igual que en spec 08; a velocidades altas esto puede hacer que el disco "pierda" una fracción de frame de movimiento en cada rebote, acumulando un pequeño error de distancia recorrida.                                                                                                         | Comportamiento heredado sin regresión respecto a spec 08; no perceptible a 60 FPS con `fly_speed` actual. Si se vuelve perceptible, se resuelve reinvocando `move_and_collide` con el remainder — cambio aislado a `_physics_process`, no afecta el resto de esta spec. |
| `GameState.get_stat("disc_bounces")` es un stub que siempre devuelve `0.0`; si la tarea `3.4` (sistema de mejoras) implementa `get_stat` de forma incompatible con lo esperado aquí (ej. devuelve un `Dictionary` en vez de `float`, o requiere un argumento adicional), la línea `int(GameState.get_stat("disc_bounces"))` en `disc.gd` se rompería.                                                      | No bloqueante hoy: el contrato (`get_stat(stat_name: String) -> float`) ya está definido en `autoload/game_state.gd` desde antes de esta spec; la tarea `3.4` deberá respetarlo o actualizar este call site explícitamente.                                             |
| Si en el futuro se agrega un cuerpo físico real en la capa `enemies` o `shield` (Fase 2) antes de que exista lógica específica de "rebote contra enemigo" (RF-2.4, tarea futura), el disco lo tratará como pared y rebotará contra él en vez de dañarlo/perforarlo, consumiendo `bounces_left` incorrectamente.                                                                                            | Riesgo conocido y aceptado: documentado ya en spec 08 (mismo criterio de "cualquier colisión = pared"); se resuelve cuando la spec de combate contra enemigos (Fase 2) agregue el chequeo de capa/tipo de colisión que hoy es innecesario.                              |
| El teletransporte instantáneo al agotar `bounces_left` sigue sin feedback visual/sonoro distinto al del rebote (spec 08 ya documentaba este riesgo); ahora que hay 2 rebotes visibles antes del teleport, la diferencia entre "rebote real" y "retorno instantáneo" podría no notarse a simple vista sin VFX/SFX diferenciados.                                                                            | Comportamiento esperado y aceptado para esta spec; se resuelve con Juice v1 (tarea `1.9`) agregando feedback distinto para `disc_bounced` vs. `disc_caught`.                                                                                                            |

## What is **not** in this spec

- Retorno con steering curvo hacia el jugador y daño de paso durante `RETURNING`.
- Recall manual y timeout de seguridad.
- Preview de puntería (`Line2D` + raycast).
- Daño a enemigos, perforar, hit-stop y knockback al impactar.
- SFX/VFX de rebote (Juice v1).
- Implementación real de la mejora "+1 rebote" ni del sistema de mejoras.
- Manejo del remainder de `move_and_collide`.
- Corrección de rebotes en esquinas cóncavas o normales degeneradas.

Cada una de estas, si llega, tendrá su propia spec.
