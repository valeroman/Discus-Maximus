# SPEC 10 — Retorno curvo con steering, atraviesa paredes, recogida (`disc_caught`)

> **Status:** Aprobado
> **Depends on:** [08-disc-fsm-lanzamiento.md](08-disc-fsm-lanzamiento.md), [09-rebote-disco-paredes.md](09-rebote-disco-paredes.md)
> **Date:** 2026-07-16
> **Objective:** Reemplazar el teleport instantáneo de `_return_to_held()` (llamado hoy cuando `bounces_left` se agota) por una transición real al estado `RETURNING`, donde el disco persigue al jugador en tiempo real con steering curvo —`velocity` rota hacia la dirección al jugador a una tasa angular máxima `return_turn_rate`, a velocidad `return_speed`, sin llamar `move_and_collide`/`move_and_slide` (por lo que atraviesa paredes)— hasta entrar en `catch_radius`, momento en el que se recoge exactamente igual que hoy (reparenta a `HELD`, emite `EventBus.disc_caught`).

## Scope

**In:**

- `entities/disc/disc_stats.gd`: agregar `@export var return_speed: float`, `@export var return_turn_rate: float` (rad/s) y `@export var catch_radius: float` (RF-2.4, design.md §3.1).
- `data/disc_stats.tres`: setear `return_speed`, `return_turn_rate` y `catch_radius` con valores concretos.
- `entities/disc/disc.gd`:
  - En `_physics_process`, cuando `bounces_left <= 0` en una colisión durante `FLYING`, en vez de llamar `_return_to_held()` directamente, transicionar a `state = State.RETURNING` (sin teleport).
  - Nueva rama en `_physics_process`: mientras `state == RETURNING`, calcular la dirección hacia `held_parent.global_position` (posición actual del jugador/`ShieldPivot`, recalculada cada frame — target móvil), rotar `velocity` hacia esa dirección a un máximo de `return_turn_rate` rad/s, mantener su magnitud en `return_speed`, y actualizar `global_position += velocity * delta` directamente — **sin** llamar `move_and_collide`/`move_and_slide` (por eso atraviesa paredes sin tocar `collision_layer`/`mask`).
  - Cuando la distancia a `held_parent.global_position` sea `<= catch_radius`, llamar a `_return_to_held()` (mismo cuerpo exacto que spec 08/09, sin cambios: reparenta a `HELD`, resetea posición/rotación, emite `EventBus.disc_caught`).
- Marcar la tarea `1.5` como `[x]` en `docs/tasks.md`.
- Verificación manual en `test_arena.tscn` (F6): lanzar el disco, agotar los 2 rebotes contra una pared, confirmar que en vez del teleport instantáneo actual el disco emprende un arco curvo visible de regreso (no línea recta), atraviesa cualquier pared en su camino, y al acercarse al jugador se recoge (reaparece en `HELD`, `has_disc` vuelve a `true`).

**Out of scope (para specs futuras):**

- Recall manual (acción `Input` `recall`) y timeout de seguridad si el disco queda atascado — tarea `1.6`.
- Preview de puntería (`Line2D` + raycast) — tarea `1.7`.
- Daño a enemigos, hit-stop y knockback durante el trayecto de `RETURNING` (RF-2.4, "dañando enemigos en el trayecto de vuelta") — no hay enemigos todavía (Fase 2).
- Señal nueva `EventBus.disc_returning` (inicio del retorno) — decisión ya tomada, no se agrega en esta spec.
- SFX/VFX del retorno (estela, partículas, sonido) — Juice v1, tarea `1.9`.
- Cambios a `collision_layer`/`collision_mask` del disco durante `RETURNING` — no aplica, ya que no se llama `move_and_collide`/`move_and_slide` en ese estado.
- Curvas de aceleración/desaceleración adicionales (ease-in/out de velocidad, frenado al llegar) — steering simple con `return_turn_rate` constante, sin suavizados extra.
- Cualquier cambio a la lógica de `FLYING`/rebotes de spec 09 (`bounces_left`, `disc_bounced`) — permanece intacta; esta spec solo cambia qué ocurre después de agotar los rebotes.

## Data model

**`entities/disc/disc_stats.gd`** (3 campos nuevos sobre la clase existente):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0
@export var max_bounces: int = 2
@export var return_speed: float = 700.0      # px/s, velocidad durante RETURNING (RF-2.4)
@export var return_turn_rate: float = 4.0    # rad/s, tasa máxima de giro del steering (curva del retorno)
@export var catch_radius: float = 20.0       # px, distancia al jugador para considerar el disco recogido
```

**`data/disc_stats.tres`**: se agregan `return_speed = 700.0`, `return_turn_rate = 4.0`, `catch_radius = 20.0` (conserva `fly_speed = 900.0` y `max_bounces = 2`).

**`entities/disc/disc.gd`** (lógica nueva sobre `_physics_process`; `_return_to_held()` no cambia):

```gdscript
func _physics_process(_delta: float) -> void:
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

Convenciones:

- Al entrar en `RETURNING` (rebotes agotados), `velocity` conserva la dirección que traía del último rebote pero se reescala a `return_speed` — evita un salto visual brusco de dirección en el instante de la transición; el steering la va curvando hacia el jugador cuadro a cuadro.
- `held_parent.global_position` es el target del steering (mismo nodo `ShieldPivot` ya usado como referencia de "posición del jugador" en spec 08/09); se recalcula cada frame, así que el disco persigue al jugador en movimiento (pursuit real, no punto congelado).
- `velocity.rotated(step)` preserva la magnitud (`return_speed`) mientras gira la dirección — no hace falta renormalizar la velocidad cada frame.
- `global_position += velocity * _delta` reemplaza a `move_and_collide` solo durante `RETURNING`: el disco no consulta física en este estado, por eso atraviesa paredes sin tocar `collision_layer`/`collision_mask`.
- `_return_to_held()` se invoca con el mismo criterio y cuerpo que en spec 08/09 (reparenta, resetea posición/rotación, emite `disc_caught`) — solo cambia que ahora se llama al cruzar `catch_radius` en vez de en la 3ª colisión con pared.
- No se agregan campos `@export` a `disc.gd`; `return_speed`/`return_turn_rate`/`catch_radius` viven en `DiscStats` (mismo patrón que `fly_speed`/`max_bounces`).

## Implementation plan

1. En `entities/disc/disc_stats.gd`, agregar `@export var return_speed: float = 700.0`, `@export var return_turn_rate: float = 4.0` y `@export var catch_radius: float = 20.0`.
2. Abrir `data/disc_stats.tres` en el editor y setear `return_speed = 700.0`, `return_turn_rate = 4.0`, `catch_radius = 20.0` (confirmar que `fly_speed = 900.0` y `max_bounces = 2` siguen intactos).
3. En `entities/disc/disc.gd`, dentro de `_physics_process`, en la rama `bounces_left <= 0` (colisión durante `FLYING`), reemplazar la llamada a `_return_to_held()` por: `state = State.RETURNING` y `velocity = velocity.normalized() * stats.return_speed`.
4. Agregar el bloque `elif state == State.RETURNING:` en `_physics_process` con el steering (rotar `velocity` hacia `held_parent.global_position` a máximo `return_turn_rate` rad/s, avanzar `global_position` manualmente) y el chequeo de `catch_radius` que llama a `_return_to_held()` cuando corresponde — tal como quedó en Data model. No modificar `_return_to_held()`.
5. Ejecutar `entities/player/player.tscn` standalone (F6): lanzar el disco y confirmar que no hay errores de consola al entrar en `RETURNING` (si la escena no tiene paredes de prueba cercanas, alcanza con confirmar ausencia de errores; el ciclo visual completo se valida en el paso 6).
6. Ejecutar `test_arena.tscn` (F6): lanzar el disco en ángulo contra una pared del perímetro, dejar que rebote 2 veces (comportamiento de spec 09 sin cambios) y, en la 3ª colisión, confirmar que en vez del teletransporte instantáneo anterior el disco inicia un arco curvo visible de regreso hacia el jugador.
7. Durante ese mismo vuelo de retorno, verificar que el disco atraviesa cualquier pared que quede en su trayectoria (no rebota, no se detiene, no cambia de estado al chocar).
8. Confirmar que al entrar en `catch_radius` el disco se recoge: reaparece en `HELD` (reparentado a `ShieldPivot`, posición/rotación restauradas), `has_disc` vuelve a `true`, y `EventBus.disc_caught` se emite (verificable con `print()` temporal o pestaña "Remote").
9. Repetir el lanzamiento y, mientras el disco está en `RETURNING`, mover al jugador con WASD; confirmar que la curva se ajusta dinámicamente hacia la nueva posición (pursuit real sobre target móvil, no un punto congelado).
10. Repetir el ciclo completo (`throw` → 2 rebotes → `RETURNING` curvo → recogida) varias veces seguidas sin errores en consola ni estado inconsistente (`state`, `bounces_left`, `has_disc`).
11. Retirar cualquier `print()` temporal agregado para depurar antes de cerrar la spec.
12. Marcar la tarea `1.5` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `entities/disc/disc_stats.gd` (`DiscStats`) tiene los campos `return_speed` (`float`, default `700.0`), `return_turn_rate` (`float`, default `4.0`) y `catch_radius` (`float`, default `20.0`), sin remover `fly_speed` ni `max_bounces`.
- [ ] `data/disc_stats.tres` tiene `return_speed = 700.0`, `return_turn_rate = 4.0`, `catch_radius = 20.0` (y conserva `fly_speed = 900.0`, `max_bounces = 2`).
- [ ] Cuando el disco choca contra una pared con `bounces_left <= 0`, en vez de llamar a `_return_to_held()` directamente, pasa a `state == State.RETURNING` y `velocity` se reescala a `stats.return_speed` conservando la dirección que traía del último rebote (sin salto brusco de dirección).
- [ ] Mientras `state == State.RETURNING`, en cada `_physics_process` el disco NO llama a `move_and_collide` ni `move_and_slide` — su `global_position` se actualiza directamente vía `global_position += velocity * delta`.
- [ ] Mientras `state == State.RETURNING`, `velocity` rota progresivamente hacia la dirección de `held_parent.global_position`, limitado a `stats.return_turn_rate` rad/s por segundo, produciendo una trayectoria curva (arco), no una línea recta ni un giro instantáneo.
- [ ] El target del steering se recalcula cada frame contra la posición actual del jugador (`held_parent.global_position`): si el jugador se mueve durante `RETURNING`, la curva se ajusta dinámicamente hacia la nueva posición.
- [ ] Durante `RETURNING`, si hay una pared en la trayectoria del disco, el disco la atraviesa sin rebotar, sin detenerse y sin cambiar de estado por esa colisión.
- [ ] Cuando la distancia entre el disco y `held_parent.global_position` es `<= stats.catch_radius`, se llama a `_return_to_held()` (sin cambios respecto a spec 08/09): el disco se reparenta a `HELD`, restaura posición local y rotación `0`, `velocity` vuelve a `Vector2.ZERO`, y se emite `EventBus.disc_caught`.
- [ ] Al recibir `EventBus.disc_caught`, `Player.has_disc` vuelve a `true`, permitiendo un nuevo lanzamiento inmediatamente (comportamiento ya existente, sin cambios en `player.gd`).
- [ ] `_return_to_held()` en `entities/disc/disc.gd` permanece exactamente igual que en spec 08/09 (mismo cuerpo, sin modificaciones).
- [ ] La lógica de `FLYING`/rebotes (`bounces_left`, `EventBus.disc_bounced`, `velocity.bounce(normal)`) de spec 09 no cambia: los 2 rebotes contra paredes siguen ocurriendo antes de que el disco entre en `RETURNING`.
- [ ] Al ejecutar `test_arena.tscn` (F6): lanzar el disco en ángulo contra una pared del perímetro produce el ciclo completo (2 rebotes reales → `RETURNING` con arco curvo visible → recogida en `HELD`) sin errores en consola.
- [ ] Repetir el ciclo lanzar/rebotar×2/retorno curvo/recogida varias veces seguidas no genera errores ni deja `state`, `bounces_left` o `has_disc` en un estado inconsistente.
- [ ] Mover al jugador mientras el disco está en `RETURNING` no rompe el steering ni genera errores; el disco sigue curvando hacia la nueva posición del jugador hasta recogerse.
- [ ] `EventBus` (`autoload/event_bus.gd`) permanece sin cambios en su declaración (no se agrega `disc_returning` ni ninguna señal nueva; se reutiliza `disc_caught`).
- [ ] `docs/tasks.md` tiene la tarea `1.5` marcada como `[x]`.

## Decisions

- **Sí:** steering real (`velocity` rota hacia la dirección al jugador a una tasa angular máxima `return_turn_rate`), en vez de interpolación de posición con ease. _Razón: decisión del usuario — es la lectura literal de `design.md §3.1` ("interpolación con steering hacia el jugador (curva, no línea recta)") y mantiene la coherencia con el resto de la FSM del disco, que ya opera sobre `velocity`/`CharacterBody2D` en `FLYING`._
- **Sí:** nuevo campo `return_speed` en `DiscStats`, independiente de `fly_speed`. _Razón: decisión del usuario — permite tunear el feel del retorno (más lento/rápido que el lanzamiento) sin afectar `FLYING`; sigue el mismo patrón de `Resource` sin números mágicos que `fly_speed`/`max_bounces` (spec 08/09, regla no negociable de `CLAUDE.md`)._
- **Sí:** target del steering recalculado cada frame contra `held_parent.global_position` (pursuit real sobre target móvil), en vez de congelar la posición del jugador al momento de agotar los rebotes. _Razón: decisión del usuario — es lo que implica "steering hacia el jugador"; evita que el disco quede apuntando a un punto viejo si el jugador se mueve durante el retorno._
- **Sí:** durante `RETURNING`, actualizar `global_position` manualmente (`+= velocity * delta`) sin llamar `move_and_collide`/`move_and_slide`, en vez de togglear `collision_mask` a `0`. _Razón: decisión del usuario — logra el mismo efecto ("atraviesa paredes") sin necesidad de guardar/restaurar el `collision_mask` original al volver a `HELD`/`FLYING`; menos estado mutable que cuidar. Coherente además con spec 03, que ya documentaba que la recogida del disco "se resuelve por lógica de distancia... no por la matriz de capas físicas"._
- **Sí:** `catch_radius = 20.0` px como umbral de recogida. _Razón: decisión del usuario — valor cercano al offset actual del disco en `HELD` (`(24, 0)` en `ShieldPivot`, spec 08), suficientemente ajustado para que la recogida se sienta precisa sin exigir superposición exacta de posiciones._
- **Sí:** al entrar en `RETURNING`, `velocity` conserva la dirección del último rebote y solo se reescala la magnitud a `return_speed` (no se resetea a apuntar directo al jugador). _Razón: evita un salto visual brusco de dirección justo en el instante de la transición; el steering se encarga de curvar la dirección progresivamente cuadro a cuadro, que es precisamente el efecto "curva" pedido._
- **Sí:** único trigger para entrar en `RETURNING` es `bounces_left <= 0` en colisión durante `FLYING` (mismo trigger que ya disparaba el teleport en spec 09), sin agregar recall manual todavía. _Razón: decisión del usuario — el recall manual (acción `Input` `recall`) y el timeout de seguridad pertenecen a la tarea `1.6`, spec separada; agregar el trigger acá ampliaría el scope innecesariamente._
- **Sí:** `_return_to_held()` permanece exactamente igual que en spec 08/09 (mismo cuerpo, sin cambios). _Razón: esta spec solo cambia CUÁNDO y CÓMO se llega a esa función (desde `RETURNING` con steering, cruzando `catch_radius`, en vez de instantáneamente en la 3ª colisión); el cierre del ciclo (reparent, reset, `disc_caught`) no cambia._
- **No:** señal nueva `EventBus.disc_returning` para marcar el inicio de `RETURNING`. _Razón: decisión del usuario — mismo criterio que specs 08/09 (las señales se agregan cuando algo las necesita); no hay VFX/SFX de retorno todavía (Juice v1 sigue siendo stub), agregarla ahora sería especulativo._
- **No:** daño a enemigos, hit-stop ni knockback durante el trayecto de `RETURNING` (RF-2.4, "dañando enemigos en el trayecto de vuelta"). _Razón: decisión del usuario — no existen enemigos todavía (Fase 2); mismo criterio que specs 08/09 (no hay nada que dañar, agregar el hook ahora sería código muerto)._
- **No:** recall manual (acción `Input` `recall`) ni timeout de seguridad si el disco queda atascado en `RETURNING`. _Razón: pertenece a la tarea `1.6`, spec separada._
- **No:** preview de puntería (`Line2D` + raycast mostrando trayectoria/rebotes/retorno). _Razón: pertenece a la tarea `1.7`, spec separada._
- **No:** cambios a `collision_layer`/`collision_mask` del disco durante `RETURNING`. _Razón: no aplica — al no llamarse `move_and_collide`/`move_and_slide` en ese estado, la física no se consulta; tocar la matriz de colisión sería innecesario._
- **No:** curvas de aceleración/desaceleración adicionales (ease-in/out de velocidad, frenado al acercarse al jugador). _Razón: no fue pedida; el steering con `return_turn_rate` constante ya produce el efecto de curva pedido, un frenado adicional se puede ajustar en playtesting sin cambiar la arquitectura._
- **No:** SFX/VFX del retorno (estela de partículas, sonido, screen shake). _Razón: pertenece a Juice v1 (tarea `1.9`); `autoload/juice.gd` sigue siendo stub._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                | Mitigación                                                                                                                                                                                                                                         |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Si `return_turn_rate` es demasiado bajo respecto a `return_speed` y a la distancia al jugador, el disco podría "orbitar" alrededor del jugador sin converger nunca dentro de `catch_radius` (sobre todo si el jugador también se mueve), quedando en `RETURNING` indefinidamente.                     | No bloqueante: ambos valores son campos de `DiscStats` (`Resource`), ajustables en el editor sin tocar código; se afinan en playtesting contra `test_arena.tscn` (paso 6-9 del plan) igual que `dash_speed`/`fly_speed` en specs previas.          |
| El disco atravesando paredes visualmente (sin ningún VFX que lo distinga como "energía") puede sentirse como un bug en vez de una mecánica intencional, ya que no hay ninguna señal visual/sonora que diferencie `RETURNING` de `FLYING`.                                                             | Comportamiento esperado y aceptado para esta spec (mismo criterio que el teleport instantáneo sin feedback en spec 08/09); se resuelve con Juice v1 (tarea `1.9`), agregando una estela/partícula distinta durante `RETURNING`.                    |
| El steering asume que `held_parent.global_position` (el `ShieldPivot`) coincide siempre con la posición del jugador — si una spec futura le da a `ShieldPivot` un offset propio respecto a `Player` (hoy no lo tiene, solo rota), el disco apuntaría a un punto desplazado en vez de al jugador real. | No bloqueante hoy: verificado contra el árbol de nodos actual de `player.tscn` (`ShieldPivot` sin offset de posición, spec 06/08); si una spec futura le agrega un offset, deberá actualizar el target del steering explícitamente en ese momento. |
| Actualizar `global_position` manualmente durante `RETURNING` (sin `move_and_collide`) puede hacer que el disco se superponga visualmente con el sprite del jugador durante un par de frames antes de que `catch_radius` lo detecte, si la velocidad de acercamiento es alta en el último tramo.       | Riesgo menor y puramente visual (no afecta lógica ni estado); ajustable bajando `return_speed` o subiendo `catch_radius` en playtesting sin cambiar la arquitectura.                                                                               |
| Los valores default (`return_speed = 700.0`, `return_turn_rate = 4.0`, `catch_radius = 20.0`) son elegidos a criterio, sin playtesting previo — podrían sentirse "planos" o demasiado curvos según el tamaño final de la arena.                                                                       | Mismo patrón que `fly_speed`/`dash_speed` en specs anteriores: son valores de `Resource` ajustables en el editor sin tocar código; se afinan en playtesting posterior.                                                                             |

## What is **not** in this spec

- Recall manual y timeout de seguridad.
- Preview de puntería (`Line2D` + raycast).
- Daño a enemigos, hit-stop y knockback durante el trayecto de `RETURNING`.
- Señal nueva `EventBus.disc_returning`.
- SFX/VFX del retorno (Juice v1).
- Cambios a `collision_layer`/`collision_mask` del disco.
- Curvas de aceleración/desaceleración adicionales en el steering.
- Cambios a la lógica de `FLYING`/rebotes de spec 09.

Cada una de estas, si llega, tendrá su propia spec.
