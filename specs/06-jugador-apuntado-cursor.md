# SPEC 06 — Jugador: apuntado hacia el cursor + rotación de ShieldPivot

> **Status:** Implementado
> **Depends on:** [05-jugador-movimiento-8-direcciones.md](05-jugador-movimiento-8-direcciones.md)
> **Date:** 2026-07-16
> **Objective:** Agregar apuntado hacia el cursor al `Player`: un nodo `ShieldPivot` (`Node2D`, hijo de `Player`) que rota en cada frame de física para mirar hacia la posición del mouse en el mundo, sin sprite ni hitbox propios todavía — sirve de base para el disco/escudo de specs futuras.

## Scope

**In:**

- `entities/player/player.tscn`: agregar nodo hijo `ShieldPivot` (`Node2D`, sin hijos propios) al nodo raíz `Player`.
- `entities/player/player.gd`: en `_physics_process`, calcular la dirección hacia `get_global_mouse_position()` y aplicar `shield_pivot.rotation = (get_global_mouse_position() - global_position).angle()` (o equivalente con `look_at`).
- El `ShieldPivot` rota de forma continua e instantánea (sin suavizado/interpolación) siguiendo al cursor, independiente del movimiento del jugador.
- Verificación manual en `test_arena.tscn` (F6): mover el mouse alrededor del jugador y confirmar la rotación vía el inspector remoto de Godot (pestaña "Remote" del árbol de escena durante ejecución) o un `print()` temporal de depuración que se retira antes de cerrar la spec.

**Out of scope (para specs futuras):**

- `ShieldHitbox` (Area2D, capa 7) y toda la mecánica de bloqueo/parry — tarea 1.3 referencia 02, tasks 9-12.
- Disco (`entities/disc/disc.tscn`), su FSM, lanzamiento, rebote y retorno — tareas 1.3-1.7 referencia 02, tasks 5-8.
- Cualquier sprite, VFX o indicador visual del `ShieldPivot` — se agrega cuando el disco/escudo lo necesite.
- Rotación del `Sprite2D` del jugador — el cuerpo del jugador no rota, solo el `ShieldPivot`.
- Apuntado táctil (drag-aim) o con gamepad — tarea 4.5, fase 4.
- Suavizado/interpolación de la rotación (lerp/slerp) — rotación instantánea por ahora; se evalúa si hace falta en playtesting posterior.
- Cualquier campo nuevo en `player_stats.tres` — esta spec no necesita parámetros configurables (no hay velocidad de rotación, sensibilidad, etc.).

## Data model

Esta spec no introduce ninguna clase GDScript ni Resource nuevos. Reutiliza `entities/player/player.gd` y `entities/player/player.tscn` (spec 05), agregando únicamente el nodo `ShieldPivot`.

**`entities/player/player.tscn`** (árbol de nodos actualizado):

```
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
└── ShieldPivot (Node2D)          # nuevo — sin hijos, position = (0, 0) relativo a Player
```

Convenciones:

- `ShieldPivot` se referencia en `player.gd` vía `@onready var shield_pivot: Node2D = $ShieldPivot`.
- La rotación se calcula en `_physics_process`, junto al movimiento ya existente, con `shield_pivot.rotation = shield_pivot.global_position.angle_to_point(get_global_mouse_position())` o equivalente (`(get_global_mouse_position() - global_position).angle()`).
- No se agrega ninguna señal nueva a `EventBus`.

## Implementation plan

1. Abrir `entities/player/player.tscn` en el editor y agregar un nodo hijo `Node2D` al nodo raíz `Player`, renombrarlo a `ShieldPivot`, posición `(0, 0)`.
2. En `entities/player/player.gd`, agregar `@onready var shield_pivot: Node2D = $ShieldPivot`.
3. En `_physics_process`, después de la lógica de movimiento existente, calcular la rotación de `shield_pivot` hacia `get_global_mouse_position()` y asignarla.
4. Ejecutar `player.tscn` standalone (F6): mover el mouse alrededor y confirmar (vía pestaña "Remote" del árbol de escena, inspeccionando `ShieldPivot.rotation`) que el valor cambia siguiendo al cursor.
5. Ejecutar `test_arena.tscn` (F6): repetir la verificación dentro de la arena, confirmando que no rompe el movimiento del jugador ni genera errores en consola.

_(Sin paso de actualización de `docs/tasks.md` — se deja intacto por decisión del usuario, ver sección de decisiones.)_

## Acceptance criteria

- [x] Existe el nodo `ShieldPivot` (`Node2D`) como hijo directo de `Player` en `entities/player/player.tscn`, sin hijos propios.
- [x] `entities/player/player.gd` referencia `ShieldPivot` vía `@onready var shield_pivot: Node2D = $ShieldPivot`.
- [x] En `_physics_process`, `shield_pivot.rotation` se recalcula cada frame en función de `get_global_mouse_position()`.
- [x] Al ejecutar `player.tscn` standalone (F6) y mover el mouse alrededor del jugador, `ShieldPivot.rotation` (verificado vía pestaña "Remote" del árbol de escena) cambia siguiendo la posición del cursor en tiempo real.
- [x] Al ejecutar `test_arena.tscn` (F6), el movimiento del jugador en 8 direcciones sigue funcionando sin errores en consola, y la rotación de `ShieldPivot` funciona igual dentro de la arena.
- [x] El `Sprite2D` del jugador no rota — permanece con `rotation = 0` en todo momento.
- [x] Ningún `ShieldHitbox`, disco, ni campo nuevo fue agregado a `player_stats.tres`.
- [x] `docs/tasks.md` permanece sin cambios (no se marca ninguna tarea en esta spec).

## Decisions

- **Sí:** `ShieldPivot` como `Node2D` vacío, sin sprite ni hitbox. _Razón: decisión del usuario — el escudo real (hitbox, VFX) pertenece a la spec de bloqueo/parry; esta spec solo sienta la base de rotación que esa spec futura consumirá._
- **Sí:** solo el `ShieldPivot` rota; el `Sprite2D` del jugador se queda estático. _Razón: decisión del usuario — evita conflicto visual entre el movimiento en 8 direcciones del cuerpo y el apuntado libre hacia el cursor, patrón típico de twin-stick._
- **Sí:** fuente de apuntado exclusivamente mouse (`get_global_mouse_position()`). _Razón: decisión del usuario — táctil/gamepad es la tarea 4.5 (fase 4), fuera de alcance por ahora._
- **Sí:** rotación instantánea, sin lerp/slerp de suavizado. _Razón: decisión del usuario — mantiene la implementación mínima; se evalúa suavizado en playtesting posterior si se siente brusco._
- **No:** agregar campos nuevos a `player_stats.tres` (ej. velocidad de rotación, sensibilidad). _Razón: no hay ningún consumidor todavía — rotación instantánea no necesita parámetros configurables._
- **No:** marcar ninguna tarea en `docs/tasks.md`. _Razón: decisión explícita del usuario — la tarea 1.3 ahí agrupa el FSM completo del disco, y el apuntado es solo una sub-parte que la referencia 02 separa; se deja intacta hasta que el disco esté también implementado._
- **No:** verificación visual con un indicador temporal (línea/sprite placeholder) en el propio `ShieldPivot`. _Razón: decisión del usuario (sección Scope) — se usa el inspector remoto de Godot o un `print()` temporal en su lugar, sin dejar rastros visuales que limpiar después._

## What is **not** in this spec

- `ShieldHitbox` y mecánica de bloqueo/parry.
- Disco (escena, FSM, lanzamiento, rebote, retorno).
- Sprite/VFX visible en `ShieldPivot`.
- Rotación del `Sprite2D` del jugador.
- Apuntado táctil o con gamepad.
- Suavizado de la rotación.
- Cambios en `docs/tasks.md`.

Cada una de estas, si llega, tendrá su propia spec.
