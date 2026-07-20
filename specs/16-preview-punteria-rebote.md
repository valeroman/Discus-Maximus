# SPEC 16 — Preview de puntería: Line2D con raycast (trayectoria + primer rebote)

> **Status:** Implementado
> **Depends on:** [09-rebote-disco-paredes.md](09-rebote-disco-paredes.md), [06-jugador-apuntado-cursor.md](06-jugador-apuntado-cursor.md)
> **Date:** 2026-07-20
> **Objective:** Agregar un nodo `AimPreview` (script dedicado, dos `Line2D` hijos) que, mientras el jugador tenga el disco y no esté bloqueando, dibuje en tiempo real —vía `PhysicsDirectSpaceState2D.intersect_ray`, reusando `disc.collision_mask`— la trayectoria recta desde `disc.global_position` hasta la primera pared que golpearía, más un segundo segmento (más transparente) que muestra el primer rebote calculado con `Vector2.bounce()`, replicando exactamente la física real del disco (spec 09) sin ejecutarla.

## Scope

**In:**

- `entities/disc/disc_stats.gd`: agregar `@export var aim_preview_max_distance: float = 1500.0` (px, distancia máxima de fallback para cada segmento del raycast si no hay colisión dentro de ese rango).
- `data/disc_stats.tres`: setear `aim_preview_max_distance = 1500.0` (conservando `fly_speed`, `max_bounces`, `return_speed`, `return_turn_rate`, `catch_radius`, `flight_timeout`).
- `entities/player/aim_preview.gd` (script nuevo):
  - Attachado a un `Node2D` llamado `AimPreview`, hijo de `Player`.
  - En `_physics_process`: si `player.has_disc and not player.is_blocking`, calcula y dibuja los 2 segmentos; si no, oculta ambos `Line2D` (`visible = false`).
  - Segmento 1: raycast desde `disc.global_position` en la dirección `(get_global_mouse_position() - global_position).normalized()` (misma fórmula que ya usa `player.gd` para `throw`/`shield_pivot.rotation`), con `collision_mask = disc.collision_mask`, excluyendo `player` y `disc` de la query (`PhysicsRayQueryParameters2D.exclude`). Si hay colisión: dibuja hasta el punto de impacto. Si no: dibuja hasta `aim_preview_max_distance`.
  - Segmento 2 (solo si el segmento 1 tuvo colisión real): raycast desde el punto de impacto del segmento 1, en la dirección `incoming_direction.bounce(collision_normal)`, mismos `collision_mask`/`exclude`. Dibuja hasta la 2ª colisión o hasta `aim_preview_max_distance` si no hay.
  - Si el segmento 1 no colisionó (caso borde, apuntando a distancia abierta mayor a `aim_preview_max_distance`), el segmento 2 queda oculto (no hay punto de rebote desde el cual partir).
- `entities/player/player.tscn`: agregar el nodo `AimPreview` (`Node2D`, script `aim_preview.gd`) como hijo de `Player`, con dos `Line2D` hijos (`Segment1`, `Segment2`):
  - Ambos: `width = 3.0`, `default_color = Color("#00f0ff")`.
  - `Segment1.default_color.a = 0.9`, `Segment2.default_color.a = 0.4`.
- Verificación manual en `test_arena.tscn` (F6).

**Out of scope (specs futuras):**

- Controles táctiles / drag-aim con preview (tarea `4.5`, Fase 4) — esta spec es exclusivamente el preview de mouse/PC.
- Mostrar más de 1 rebote en la línea (rebotes 2, 3, ... hasta que el disco realmente retorne) — el propio task `1.7` pide únicamente "trayectoria + primer rebote".
- Accesibilidad / toggle para ocultar o simplificar el preview — Fase 4 (settings), igual criterio que specs 14/15.
- SFX asociado al preview.
- Cambiar `disc.gd`, `disc.tscn`, `entities/player/player_stats.gd`/`.tres`, o la lógica real de lanzamiento/rebote (spec 08/09) — el preview solo lee datos existentes (`disc.global_position`, `disc.collision_mask`), nunca los modifica.
- Marcador visual (punto/ícono) en el punto de rebote — solo las 2 líneas, sin nodos adicionales de VFX.
- Ocultar el preview cuando el punto de impacto quede detrás de un elemento de UI o fuera de cámara — no aplica, no hay UI que lo tape todavía.

## Data model

**`entities/disc/disc_stats.gd`** (campo nuevo agregado a la clase existente):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0
@export var max_bounces: int = 2
@export var return_speed: float = 700.0
@export var return_turn_rate: float = 4.0
@export var catch_radius: float = 20.0
@export var flight_timeout: float = 4.0
@export var aim_preview_max_distance: float = 1500.0   # px, fallback si el raycast del preview no golpea nada (tarea 1.7)
```

`data/disc_stats.tres`: se agrega `aim_preview_max_distance = 1500.0` (conservando los 5 campos previos ya seteados).

**`entities/player/player.tscn`** (2 nodos nuevos, hijos de `Player`, mismo nivel que `ShieldPivot`/`DashTimer`):

```
[node name="AimPreview" type="Node2D" parent="."]
script = ExtResource("aim_preview_script")

[node name="Segment1" type="Line2D" parent="AimPreview"]
width = 3.0
default_color = Color(0, 0.941176, 1, 0.9)

[node name="Segment2" type="Line2D" parent="AimPreview"]
width = 3.0
default_color = Color(0, 0.941176, 1, 0.4)
```

**`entities/player/aim_preview.gd`** (script nuevo):

```gdscript
extends Node2D

@onready var player: CharacterBody2D = get_parent()
@onready var segment1: Line2D = $Segment1
@onready var segment2: Line2D = $Segment2

func _physics_process(_delta: float) -> void:
	if not (player.has_disc and not player.is_blocking):
		segment1.visible = false
		segment2.visible = false
		return

	var disc: Disc = player.disc
	var space_state := get_world_2d().direct_space_state
	var origin := disc.global_position
	var direction := (get_global_mouse_position() - player.global_position).normalized()
	var exclude := [player.get_rid(), disc.get_rid()]

	var hit1 := _cast(space_state, origin, direction, disc.collision_mask, exclude)
	var end1: Vector2 = hit1.position if hit1 else origin + direction * disc.stats.aim_preview_max_distance

	segment1.visible = true
	segment1.points = PackedVector2Array([to_local(origin), to_local(end1)])

	if not hit1:
		segment2.visible = false
		return

	var reflected := direction.bounce(hit1.normal)
	var hit2 := _cast(space_state, end1, reflected, disc.collision_mask, exclude)
	var end2: Vector2 = hit2.position if hit2 else end1 + reflected * disc.stats.aim_preview_max_distance

	segment2.visible = true
	segment2.points = PackedVector2Array([to_local(end1), to_local(end2)])

func _cast(space_state: PhysicsDirectSpaceState2D, from: Vector2, direction: Vector2, mask: int, exclude: Array) -> Dictionary:
	var to := from + direction * player.disc.stats.aim_preview_max_distance
	var query := PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
	return space_state.intersect_ray(query)
```

Convenciones:

- `Line2D.points` se pasa en coordenadas locales de `AimPreview` (`to_local(...)`) — `AimPreview` no rota (a diferencia de `ShieldPivot`), solo traslada con `Player`.
- `hit1`/`hit2` son `Dictionary` vacíos si `intersect_ray` no golpea nada (comportamiento nativo de Godot); se chequean con `if hit1`/`not hit1`.
- La dirección de apuntado (`direction`) usa la misma fórmula que `player.gd` para `throw()` y `shield_pivot.rotation` (spec 06/08): `(get_global_mouse_position() - global_position).normalized()`, sobre `player.global_position` (no sobre `disc.global_position`), para que el preview apunte exactamente hacia donde apunta el jugador.
- `disc.collision_mask` se lee en runtime en cada frame (no se cachea), así el preview queda automáticamente sincronizado si esa máscara cambia a futuro (ej. al agregar el escudo del Warden en `enemies`/`shield`, tarea `2.7`).
- No se agrega ninguna señal nueva a `EventBus` — el preview es puramente visual, sin comunicar estado a otros sistemas.

## Implementation plan

1. En `entities/disc/disc_stats.gd`, agregar `@export var aim_preview_max_distance: float = 1500.0`.
2. Abrir `data/disc_stats.tres` en el editor y setear `aim_preview_max_distance = 1500.0` (confirmar que los 5 campos previos siguen intactos).
3. Crear `entities/player/aim_preview.gd` con el contenido de la sección "Data model" (`_physics_process`, `_cast`).
4. En `entities/player/player.tscn`, agregar el nodo `AimPreview` (`Node2D`, script `aim_preview.gd`) como hijo de `Player`, y sus dos hijos `Segment1`/`Segment2` (`Line2D`, `width = 3.0`, colores cian con alpha `0.9`/`0.4` respectivamente).
5. F6 `test_arena.tscn`: con el disco en mano (`has_disc = true`) y sin bloquear, mover el mouse y confirmar que aparece una línea cian desde el disco hasta la primera pared que cruce la dirección de apuntado.
6. F6: apuntar en un ángulo (no perpendicular) contra una pared del perímetro y confirmar que aparece un 2º segmento (más transparente) desde el punto de impacto, con el ángulo de reflexión correcto (mismo lado que un rebote físico real esperaría).
7. F6: lanzar el disco (`throw`) siguiendo la dirección exacta que mostraba el preview justo antes de lanzar, y confirmar visualmente que el disco vuela y rebota siguiendo esa misma trayectoria/ángulo (sin discrepancia perceptible entre preview y física real).
8. F6: presionar `block` (o esperar a que `has_disc` sea `false` tras lanzar) y confirmar que ambos segmentos se ocultan (`visible = false`) mientras se bloquea o mientras el disco vuela/retorna.
9. F6: soltar `block` (con el disco ya recuperado, `has_disc = true`) y confirmar que el preview reaparece inmediatamente.
10. F6: apuntar hacia una zona sin pared alcanzable dentro de `aim_preview_max_distance` (si la geometría de `test_arena.tscn` lo permite) y confirmar que el segmento 1 se dibuja hasta el límite de `aim_preview_max_distance` sin error, y que el segmento 2 queda oculto (no hay punto de rebote).
11. Confirmar en consola: sin errores durante ningún escenario anterior (en particular, ningún acceso inválido a `hit1`/`hit2` cuando `intersect_ray` devuelve `{}`).
12. Marcar la tarea `1.7` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `entities/disc/disc_stats.gd` (`DiscStats`) tiene el campo `aim_preview_max_distance` (`float`, default `1500.0`), sin remover `fly_speed`, `max_bounces`, `return_speed`, `return_turn_rate`, `catch_radius`, `flight_timeout`.
- [ ] `data/disc_stats.tres` tiene `aim_preview_max_distance = 1500.0` y conserva los 5 campos previos.
- [ ] Existe `entities/player/aim_preview.gd` con la lógica de raycast + actualización de los 2 `Line2D`, según la sección "Data model".
- [ ] `entities/player/player.tscn` tiene el nodo `AimPreview` (`Node2D`, script `aim_preview.gd`) como hijo de `Player`, con 2 hijos `Line2D` (`Segment1`, `Segment2`), `width = 3.0`, color `#00f0ff` con alpha `0.9` y `0.4` respectivamente.
- [ ] Mientras `player.has_disc == true` y `player.is_blocking == false`: `Segment1` es visible y va desde `disc.global_position` hasta el primer punto de colisión en la dirección de apuntado (o hasta `aim_preview_max_distance` si no hay colisión).
- [ ] Cuando el segmento 1 tuvo colisión real: `Segment2` es visible y va desde ese punto de impacto hasta la 2ª colisión (dirección `direction.bounce(normal)`) o hasta `aim_preview_max_distance` si no hay 2ª colisión.
- [ ] Cuando el segmento 1 NO tuvo colisión (apunta a espacio abierto más allá de `aim_preview_max_distance`): `Segment2` queda oculto (`visible = false`).
- [ ] Mientras `player.has_disc == false` (disco volando/retornando) o `player.is_blocking == true`: ambos `Segment1` y `Segment2` quedan ocultos (`visible = false`).
- [ ] El raycast usa `collision_mask = disc.collision_mask` (leído en runtime, no hardcodeado) y excluye al `Player` y al `Disc` de la query (`PhysicsRayQueryParameters2D.exclude`).
- [ ] La dirección de apuntado del preview coincide exactamente con la fórmula usada por `player.gd` para `throw()`/`shield_pivot.rotation`: `(get_global_mouse_position() - player.global_position).normalized()`.
- [ ] Lanzar el disco en la dirección que mostraba el preview produce una trayectoria/ángulo de rebote real coincidente con lo que mostraba el segmento 2 (verificación visual F6, sin discrepancia perceptible).
- [ ] No se agrega ninguna señal nueva a `EventBus`; no se modifica `disc.gd`, `disc.tscn`, `entities/player/player_stats.gd`/`.tres`, ni la lógica de `throw()`/rebote real (specs 08/09).
- [ ] No se agregan controles táctiles ni cambios relacionados a la tarea `4.5`.
- [ ] F6 en `test_arena.tscn`: los 6 escenarios del plan (preview visible con disco en mano, 2º segmento con ángulo correcto, coincidencia preview↔física real al lanzar, ocultamiento al bloquear/lanzar, reaparición al recuperar el disco, fallback a `aim_preview_max_distance` en espacio abierto) se comportan como se describe, sin errores en consola, repetible varias veces.
- [ ] `docs/tasks.md` tiene la tarea `1.7` marcada como `[x]`.

## Decisions

- **Sí:** raycast vía `PhysicsDirectSpaceState2D.intersect_ray` (consulta directa cada frame), en vez de un nodo `RayCast2D` con `force_raycast_update()`. _Razón: decisión tomada junto al usuario — la dirección cambia continuamente con el mouse; una consulta directa por frame es más simple que gestionar el ciclo de vida de un `RayCast2D` (mover su `target_position`, forzar update, leer resultado) para el mismo efecto._
- **Sí:** origen del segmento 1 en `disc.global_position` (no `player.global_position`), coincidiendo exactamente con el origen real de `disc.throw()` (spec 08). _Razón: decisión del usuario — pixel-perfect entre preview y lanzamiento real, sin offset perceptible entre lo que se ve y lo que ocurre al lanzar._
- **Sí:** `collision_mask` del raycast = `disc.collision_mask` leído en runtime, sin constante propia duplicada. _Razón: decisión del usuario — evita desincronización futura si la máscara real del disco cambia (ej. tarea `2.7`, escudo del Warden); una sola fuente de verdad._
- **Sí:** segundo segmento calculado con un 2º raycast real (`direction.bounce(normal)` + `intersect_ray` de nuevo), no una longitud fija. _Razón: decisión del usuario — más preciso que una longitud arbitraria; reutiliza la misma función `_cast()` sin duplicar lógica, y respeta el pedido explícito de la tarea `1.7` ("trayectoria + primer rebote")._
- **Sí:** nuevo stat `aim_preview_max_distance` en `DiscStats` (no en `PlayerStats`), usado como fallback de ambos segmentos cuando no hay colisión dentro de rango. _Razón: decisión del usuario — es una propiedad de "hasta dónde se ve/viaja el disco", mismo `Resource` que ya modela `fly_speed`/`max_bounces`/`return_speed`; sigue la regla `CLAUDE.md` anti-números-mágicos._
- **Sí:** lógica del preview aislada en un script/nodo dedicado (`AimPreview` + `aim_preview.gd`), no agregada directamente a `player.gd`. _Razón: decisión del usuario — `player.gd` ya concentra movimiento, dash, block y parry; separar la responsabilidad puramente visual del preview mantiene ese script enfocado, coherente con el principio de desacoplamiento de `CLAUDE.md` (aunque aquí no es vía `EventBus` sino vía nodo especializado, ya que el preview necesita leer estado del `Player` cada frame, no reaccionar a eventos discretos)._
- **Sí:** excluir `Player` y `Disc` de la query de raycast (`PhysicsRayQueryParameters2D.exclude`). _Razón: decisión técnica para evitar que el rayo se autointersecte contra el propio `CollisionShape2D` del jugador o del disco (el origen del segmento 1 está muy cerca de ambos), lo cual truncaría la línea a longitud ~0 de forma intermitente._
- **Sí:** ocultar el preview completo (`has_disc == false or is_blocking == true`) en vez de mostrarlo atenuado/deshabilitado. _Razón: decisión del usuario — mismas condiciones exactas que ya bloquean `throw()` en `player.gd`; mostrar una línea que no se puede ejecutar generaría confusión ("¿por qué no lanza hacia ahí?")._
- **Sí:** 2 nodos `Line2D` separados (`Segment1`/`Segment2`) con alpha distinto (`0.9`/`0.4`), en vez de 1 solo `Line2D` con gradiente. _Razón: decisión del usuario — más simple de implementar y leer que configurar un `Gradient` para 2 tramos; comunica visualmente que el 2º tramo es "más incierto" (depende de que el rebote real ocurra igual)._
- **No:** mostrar más de 1 rebote (2º, 3er segmento, etc.) en la línea. _Razón: decisión del usuario — la tarea `1.7` pide explícitamente "trayectoria + primer rebote", no la trayectoria completa hasta el retorno._
- **No:** controles táctiles / drag-aim. _Razón: pertenece a la tarea `4.5`, Fase 4, spec separada._
- **No:** accesibilidad/toggle para ocultar o simplificar el preview. _Razón: fuera de alcance — pertenece a un sistema de settings de Fase 4 que todavía no existe, mismo criterio que specs 14/15._
- **No:** marcador visual (punto/ícono) en el punto de rebote. _Razón: decisión del usuario — las 2 líneas ya comunican el punto de rebote (donde termina el segmento 1 y empieza el 2); un marcador adicional es VFX no pedido por la tarea `1.7`._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Mitigación                                                                                                                                                                                                                                                                                           |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `intersect_ray` detecta colisión inmediata en la esquina/borde de un tile de `Walls` (`TileMapLayer`) con una normal ligeramente distinta a la que produciría `move_and_collide` en el disco real (por diferencias de forma de colisión entre el tile y el radio del disco, `CircleShape2D` de 12px), generando una pequeña discrepancia visual entre el ángulo del segmento 2 y el rebote físico real.                                                      | No bloqueante: mismo riesgo de esquinas cóncavas ya documentado y aceptado en spec 09; si se nota en playtesting, se ajusta con un margen/offset en el raycast, sin cambiar la arquitectura del preview.                                                                                             |
| El preview recalcula 2 raycasts por frame en `_physics_process` mientras el jugador tiene el disco (la mayoría del tiempo de juego); en un nivel con muchas paredes/enemigos futuros esto podría sumar costo de física por frame.                                                                                                                                                                                                                            | No bloqueante hoy: 2 raycasts/frame es trivial para Godot incluso en web/móvil (RNF-5 de `docs/requirements.md`); si en Fase 2+ se vuelve perceptible con muchos enemigos en la máscara de colisión, se puede limitar la frecuencia de recálculo (ej. cada 2 frames) sin cambiar el contrato visual. |
| El origen del segmento 1 (`disc.global_position`) y la dirección de apuntado (`player.global_position` hacia el mouse) no son el mismo punto — si el offset del `ShieldPivot` cambia a futuro (ej. brazo más largo), el preview seguiría siendo preciso porque ambos se leen en runtime, pero un desarrollador que no lea esta spec podría intentar "simplificar" usando `player.global_position` como origen único y romper el pixel-perfect con `throw()`. | No bloqueante: documentado explícitamente en "Decisions" y en el comentario del código; revisión de código/spec futura debe preservar `disc.global_position` como origen del segmento 1.                                                                                                             |

## What is **not** in this spec

- Controles táctiles / drag-aim con preview.
- Más de 1 rebote mostrado en la línea.
- Accesibilidad / toggle de reducción del preview.
- SFX asociado al preview.
- Marcador visual en el punto de rebote.
- Cambios a `disc.gd`, `disc.tscn`, `player_stats.gd`/`.tres`, o a la lógica real de lanzamiento/rebote.

Cada una de estas, si llega, tendrá su propia spec.
