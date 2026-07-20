# SPEC 20 — Retorno curvo más directo: turn rate variable + backstop por tiempo

> **Status:** Implementado
> **Depends on:** [10-retorno-curvo-steering.md](10-retorno-curvo-steering.md), [11-recall-manual-timeout.md](11-recall-manual-timeout.md)
> **Date:** 2026-07-20
> **Objective:** Reemplazar el `return_turn_rate` constante de `RETURNING` por un turn rate variable —más agresivo cuanto mayor es el error de ángulo hacia el jugador— más un backstop por tiempo (`return_straighten_delay`) que, si el disco lleva demasiado tiempo sin converger, sube el turn rate a un valor mucho más alto (`return_straighten_turn_rate`) para el resto del trayecto, de forma que el disco nunca describa arcos anchos ni tarde demasiado en volver, sin importar qué tan lejos del jugador esté (ej. centro de la arena).

## Scope

**In:**

- `entities/disc/disc_stats.gd`: agregar 3 campos nuevos:
  - `@export var return_turn_rate_gain: float` — rad/s adicionales por cada radián de error de ángulo hacia el jugador (turn rate variable: cuanto más desviado el rumbo, más rápido corrige).
  - `@export var return_straighten_delay: float` — segundos que el disco puede pasar en `RETURNING` antes de activar el backstop.
  - `@export var return_straighten_turn_rate: float` — turn rate (rad/s) que se usa como techo del turn rate variable, y que se fuerza sin condición una vez pasado `return_straighten_delay`.
- `data/disc_stats.tres`: setear valores concretos para los 3 campos nuevos (conserva `return_turn_rate`, `return_speed`, `catch_radius`, `flight_timeout` sin cambios).
- `entities/disc/disc.gd`:
  - Nueva variable `return_time: float` que cuenta el tiempo transcurrido específicamente dentro de `RETURNING` (distinto de `flight_time`, que ya existe y cuenta desde el `throw()`). Se resetea a `0.0` en los dos puntos donde el disco entra a `RETURNING`: al agotar `bounces_left` en `FLYING`, y en `recall()`.
  - En la rama `elif state == State.RETURNING`, reemplazar el uso de `stats.return_turn_rate` fijo por: `effective_turn_rate = min(stats.return_turn_rate + stats.return_turn_rate_gain * absf(angle_to_desired), stats.return_straighten_turn_rate)`, y si `return_time >= stats.return_straighten_delay`, forzar `effective_turn_rate = stats.return_straighten_turn_rate` directo (bypass de la fórmula, backstop incondicional).
  - `return_time += _delta` en cada frame que el disco está en `RETURNING`.
- Verificación manual en `test_arena.tscn` (F6): lanzar el disco de forma que agote los rebotes cerca del centro de la arena (lejos del jugador) y confirmar que el arco de regreso es notoriamente más directo/corto que antes, sin arcos anchos ni demoras largas, incluso moviendo al jugador durante el retorno.

**Out of scope (para specs futuras o ya cubierto):**

- `flight_timeout` y el teletransporte de seguridad de spec 11 (ya existente) — no se modifica; sigue siendo el backstop final absoluto si algo falla.
- `return_speed` y `catch_radius` — sin cambios de valor ni de mecanismo.
- Lógica de `FLYING`/rebotes (spec 09) — sin cambios.
- Backstop basado en distancia recorrida (en vez de tiempo) — descartado, el usuario eligió el enfoque por tiempo.
- Acción `recall` en sí (input, cooldown) — spec 11, intacta; esta spec solo toca qué pasa _dentro_ de `RETURNING` una vez que ya se entró, sea por rebotes agotados o por `recall()`.
- Preview de puntería, VFX/SFX del retorno — sin cambios.
- Cambios al jugador (`player.gd`) — sin cambios.

## Data model

**`entities/disc/disc_stats.gd`** (3 campos nuevos sobre la clase existente, `return_turn_rate` se conserva como piso del turn rate):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0
@export var max_bounces: int = 2
@export var return_speed: float = 700.0
@export var return_turn_rate: float = 4.0             # rad/s, piso del turn rate (error de ángulo chico)
@export var return_turn_rate_gain: float = 3.0         # rad/s adicionales por radián de error de ángulo
@export var return_straighten_delay: float = 1.2       # s en RETURNING antes de forzar el backstop
@export var return_straighten_turn_rate: float = 12.0  # techo del turn rate variable y valor del backstop
@export var catch_radius: float = 20.0
@export var flight_timeout: float = 4.0
@export var aim_preview_max_distance: float = 1500.0
@export var bounce_shake_intensity: float = 2.0
```

**`data/disc_stats.tres`**: se agregan `return_turn_rate_gain = 3.0`, `return_straighten_delay = 1.2`, `return_straighten_turn_rate = 12.0` (conserva el resto de campos existentes intactos).

**`entities/disc/disc.gd`** (cambios sobre el archivo existente):

```gdscript
var return_time: float = 0.0   # tiempo en RETURNING, se resetea al entrar al estado

func recall() -> void:
	if state != State.FLYING:
		return
	state = State.RETURNING
	velocity = velocity.normalized() * stats.return_speed
	return_time = 0.0
	EventBus.disc_recalled.emit()

func _physics_process(_delta: float) -> void:
	# ... (flight_timeout sin cambios)
	if state == State.FLYING:
		var collision := move_and_collide(velocity * _delta)
		if collision:
			# ... (TrainingDummy hit, bounce sin cambios)
			else:
				state = State.RETURNING
				velocity = velocity.normalized() * stats.return_speed
				return_time = 0.0
	elif state == State.RETURNING:
		return_time += _delta
		var to_target := held_parent.global_position - global_position
		var desired_direction := to_target.normalized()
		var angle_to_desired := velocity.angle_to(desired_direction)
		var effective_turn_rate := minf(
			stats.return_turn_rate + stats.return_turn_rate_gain * absf(angle_to_desired),
			stats.return_straighten_turn_rate
		)
		if return_time >= stats.return_straighten_delay:
			effective_turn_rate = stats.return_straighten_turn_rate
		var max_step := effective_turn_rate * _delta
		velocity = velocity.rotated(clampf(angle_to_desired, -max_step, max_step))
		global_position += velocity * _delta
		if to_target.length() <= stats.catch_radius:
			_return_to_held()
```

Convenciones:

- `return_turn_rate` pasa a ser el piso (turn rate mínimo, error de ángulo chico); `return_turn_rate_gain` escala el turn rate hacia arriba cuando el error de ángulo es grande (arco ancho), sin necesidad de tocar `return_turn_rate` existente.
- `return_straighten_turn_rate` cumple doble rol: techo (`minf`) del turn rate variable en operación normal, y valor forzado incondicional una vez que `return_time >= return_straighten_delay` — mismo campo, dos usos, sin duplicar un stat.
- `return_time` es independiente de `flight_time` (que sigue contando desde `throw()` para el timeout absoluto de spec 11): se resetea cada vez que se entra a `RETURNING`, así el backstop mide "tiempo tratando de converger", no tiempo total de vuelo.
- `_return_to_held()` no cambia — el backstop solo ajusta el turn rate, nunca hace snap/teleport (decisión ya tomada: "endereza suave", no instantáneo).
- `flight_timeout` (spec 11) permanece como red de seguridad absoluta e independiente; con estos cambios debería activarse mucho menos seguido, pero no se remueve.

## Implementation plan

1. En `entities/disc/disc_stats.gd`, agregar `@export var return_turn_rate_gain: float = 3.0`, `@export var return_straighten_delay: float = 1.2` y `@export var return_straighten_turn_rate: float = 12.0`.
2. Abrir `data/disc_stats.tres` en el editor y setear los 3 campos nuevos con esos valores default; confirmar que `return_turn_rate = 4.0`, `return_speed = 700.0`, `catch_radius = 20.0`, `flight_timeout = 4.0` siguen intactos.
3. En `entities/disc/disc.gd`, agregar `var return_time: float = 0.0` junto al resto de variables de estado (`bounces_left`, `flight_time`).
4. En `recall()`, agregar `return_time = 0.0` al entrar a `RETURNING`.
5. En `_physics_process`, en la rama de colisión de `FLYING` con `bounces_left <= 0`, agregar `return_time = 0.0` al entrar a `RETURNING`.
6. En la rama `elif state == State.RETURNING`, agregar `return_time += _delta` al inicio, calcular `effective_turn_rate` con la fórmula de `minf(return_turn_rate + return_turn_rate_gain * absf(angle_to_desired), return_straighten_turn_rate)`, aplicar el backstop incondicional cuando `return_time >= stats.return_straighten_delay`, y usar `effective_turn_rate` (en vez de `stats.return_turn_rate` fijo) para calcular `max_step`. El resto de la rama (`velocity.rotated`, `global_position += velocity * _delta`, chequeo de `catch_radius`) no cambia.
7. F6 `test_arena.tscn`: lanzar el disco desde una posición tal que agote los rebotes cerca del centro de la arena (lejos del jugador) y confirmar que el arco de regreso ahora es visiblemente más directo/corto que el comportamiento anterior (sin arco ancho, sin vueltas).
8. F6: repetir el lanzamiento varias veces con distintos ángulos/distancias, incluyendo casos con el jugador moviéndose durante `RETURNING`, y confirmar que el disco converge de forma consistente sin quedar dando vueltas anchas.
9. F6: forzar (o esperar) que un retorno tarde más de `return_straighten_delay` segundos sin converger (ej. moviendo al jugador en círculos) y confirmar que el disco endereza notoriamente su rumbo hacia el jugador (turn rate alto) sin teletransportarse, hasta entrar en `catch_radius`.
10. F6: confirmar que un retorno con error de ángulo chico (disco ya casi apuntando al jugador al entrar en `RETURNING`) sigue viéndose con una curva suave, no un giro brusco — la fórmula no debe notarse en el caso ya-bien-alineado.
11. F6: confirmar que la lógica de `FLYING`/rebotes (spec 09) y el timeout absoluto (spec 11, `flight_timeout`) siguen funcionando sin cambios.
12. Retirar cualquier `print()` temporal agregado para depurar antes de cerrar la spec.

## Acceptance criteria

- [ ] `entities/disc/disc_stats.gd` (`DiscStats`) tiene `return_turn_rate_gain` (`float`, default `3.0`), `return_straighten_delay` (`float`, default `1.2`) y `return_straighten_turn_rate` (`float`, default `12.0`), sin remover ningún campo existente.
- [ ] `data/disc_stats.tres` tiene los 3 campos nuevos seteados con esos valores y conserva `return_turn_rate = 4.0`, `return_speed = 700.0`, `catch_radius = 20.0`, `flight_timeout = 4.0` sin cambios.
- [ ] `entities/disc/disc.gd` tiene `var return_time: float = 0.0`, reseteado a `0.0` tanto en `recall()` como en la rama de `FLYING` que transiciona a `RETURNING` al agotar `bounces_left`.
- [ ] Mientras `state == State.RETURNING`, `return_time` se incrementa cada `_physics_process` en `_delta`.
- [ ] Mientras `state == State.RETURNING` y `return_time < stats.return_straighten_delay`, el turn rate efectivo usado para `max_step` es `minf(stats.return_turn_rate + stats.return_turn_rate_gain * absf(angle_to_desired), stats.return_straighten_turn_rate)` — no un valor fijo.
- [ ] En cuanto `return_time >= stats.return_straighten_delay`, el turn rate efectivo pasa a ser `stats.return_straighten_turn_rate` de forma incondicional (ignora la fórmula) para el resto del trayecto en `RETURNING`.
- [ ] El backstop nunca hace snap/teleport: `global_position` sigue actualizándose vía `global_position += velocity * _delta` (steering), nunca se asigna directamente la posición del jugador antes de `catch_radius`.
- [ ] `_return_to_held()` no cambia su cuerpo respecto a spec 10/11 (reparent, reset posición/rotación, `EventBus.disc_caught`).
- [ ] Con error de ángulo chico al entrar en `RETURNING` (disco ya casi alineado con el jugador), el turn rate efectivo es cercano al piso `return_turn_rate` — la curva sigue viéndose suave, no se nota la fórmula nueva.
- [ ] Con error de ángulo grande y/o el disco lejos del jugador (ej. centro de la arena), el arco de retorno converge visiblemente más rápido/directo que el comportamiento de spec 10 (turn rate fijo `4.0`), sin describir arcos anchos.
- [ ] Si el retorno no converge dentro de `return_straighten_delay` segundos (ej. jugador moviéndose de forma que evita `catch_radius`), el disco endereza notoriamente su rumbo (turn rate alto) hasta entrar en `catch_radius`, sin quedar dando vueltas indefinidamente.
- [ ] La lógica de `FLYING`/rebotes (spec 09) no cambia.
- [ ] `flight_timeout` (spec 11) permanece como red de seguridad absoluta sin cambios: si por cualquier motivo el disco sigue sin recogerse al llegar a `stats.flight_timeout` segundos desde el `throw()`, se fuerza `_return_to_held()` igual que antes.
- [ ] `EventBus` no tiene señales nuevas ni modificadas por esta spec.
- [ ] F6 en `test_arena.tscn`: los escenarios del plan (retorno desde el centro de la arena, jugador moviéndose durante `RETURNING`, backstop por tiempo, caso ya-alineado) se comportan como se describe, repetible varias veces sin errores en consola.

## Decisions

- **Sí:** turn rate variable (proporcional al error de ángulo) + backstop por tiempo, en vez de solo subir el valor fijo de `return_turn_rate` o solo agregar un tope. _Razón: decisión del usuario — subir solo el valor fijo no garantiza eliminar arcos anchos en todos los casos (misma fórmula constante); el backstop por tiempo solo, sin la fórmula variable, deja el arco ancho hasta que se activa el tope. La combinación ataca la causa (arcos anchos con error de ángulo grande) y además garantiza un techo de tiempo._
- **Sí:** backstop por **tiempo** en `RETURNING` (`return_time`/`return_straighten_delay`), no por distancia recorrida. _Razón: decisión del usuario — más simple y predecible independientemente del tamaño de la arena o de cuánto se mueva el jugador; no requiere trackear distancia acumulada._
- **Sí:** al activarse el backstop, el disco "endereza suave" (turn rate alto, sigue viajando con steering) en vez de teletransportarse. _Razón: decisión del usuario — mantiene la sensación de "disco de energía volando", evita el salto brusco de posición que ya se identificó como mala UX en el teleport pre-spec-10._
- **Sí:** `return_straighten_turn_rate` cumple doble rol (techo del turn rate variable + valor del backstop incondicional), sin agregar un cuarto campo. _Razón: simplicidad — un turn rate "alto" tiene un solo significado conceptual en este sistema (el máximo que el disco puede girar), no hace falta distinguir "techo normal" de "backstop" con dos números distintos._
- **Sí:** `return_time` es una variable nueva e independiente de `flight_time` (spec 08/11). _Razón: decisión derivada — `flight_time` cuenta desde el `throw()` (incluye tiempo en `FLYING`) y alimenta el timeout absoluto de spec 11; el backstop de esta spec necesita medir específicamente "tiempo intentando converger en RETURNING", que es un reloj distinto con un propósito distinto._
- **No:** modificar o remover `flight_timeout`/spec 11. _Razón: decisión del usuario (implícita en el scope) — sigue siendo la red de seguridad absoluta; esta spec reduce cuánto se necesita en la práctica, pero no la reemplaza._
- **No:** cambiar `return_speed` ni `catch_radius`. _Razón: el problema reportado es sobre la curvatura/dirección del retorno, no sobre su velocidad o el umbral de recogida; tocarlos sería scope creep._
- **No:** valores default definitivos — `return_turn_rate_gain = 3.0`, `return_straighten_delay = 1.2`, `return_straighten_turn_rate = 12.0` son estimaciones razonables, no playtesting. _Razón: mismo criterio que specs 08/09/10 — son campos de `DiscStats` (`Resource`), ajustables en el editor sin tocar código; se afinan en playtesting (paso 7-10 del plan)._

## Risks

| Riesgo                                                                                                                                                                                                                                                                           | Mitigación                                                                                                                                                                                                                                          |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Los valores default (`gain = 3.0`, `delay = 1.2`, `straighten_turn_rate = 12.0`) podrían sentirse "demasiado agresivos" (el disco corrige tan rápido que pierde el efecto de curva) o "insuficientes" (sigue arqueando) según el tamaño final de la arena.                       | No bloqueante: son campos de `Resource` ajustables en el editor sin tocar código, mismo patrón que `fly_speed`/`return_speed` en specs previas; se afinan en playtesting (pasos 7-10).                                                              |
| Si `return_straighten_delay` es muy corto, el backstop podría activarse en retornos normales (no solo en el caso "centro de la arena"), haciendo que el disco pierda la sensación de curva en la mayoría de los lanzamientos.                                                    | Ajustable en `.tres`; el paso 10 del plan de implementación verifica explícitamente que el caso ya-alineado siga viéndose curvo, no robótico.                                                                                                       |
| El backstop incondicional (`effective_turn_rate = return_straighten_turn_rate` sin importar el error de ángulo) podría producir un cambio de dirección visualmente abrupto si se activa justo cuando el error de ángulo es grande.                                               | Riesgo menor y aceptado: es la mitigación intencional al problema original (arcos largos); un cambio de dirección notorio pero sin teleport es preferible a "varios giros". Ajustable subiendo `return_straighten_delay` si se percibe muy abrupto. |
| `return_time` no se resetea si el disco vuelve a `RETURNING` sin pasar por `HELD` (no aplica hoy: los dos únicos puntos de entrada a `RETURNING` ya resetean `return_time` explícitamente), pero una spec futura que agregue un tercer punto de entrada podría olvidar el reset. | No bloqueante hoy: documentado aquí; cualquier spec futura que agregue un nuevo trigger a `RETURNING` debe resetear `return_time` igual que los dos existentes.                                                                                     |

## What is **not** in this spec

- Cambios a `flight_timeout` o al teletransporte de seguridad de spec 11.
- Cambios a `return_speed` o `catch_radius`.
- Cambios a la lógica de `FLYING`/rebotes de spec 09.
- Backstop basado en distancia recorrida.
- Cambios a la acción `recall` (input, cooldown) en sí.
- Preview de puntería, VFX/SFX del retorno.
- Cambios al jugador (`player.gd`).

Cada una de estas, si llega, tendrá su propia spec.
