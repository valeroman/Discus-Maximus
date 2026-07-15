# SPEC 05 — Jugador: movimiento 8 direcciones con aceleración/fricción

> **Status:** Aprobado
> **Depends on:** [03-capas-fisica.md](03-capas-fisica.md), [04-arena-de-pruebas.md](04-arena-de-pruebas.md)
> **Date:** 2026-07-15
> **Objective:** Crear `entities/player/player.tscn` (CharacterBody2D) que se mueve en 8 direcciones acelerando hasta velocidad máxima y frenando por fricción en ~0.1s, con los parámetros leídos desde un Resource tipado `data/player_stats.tres`, instanciado dentro de `levels/test_arena.tscn` para probarlo contra las paredes.

## Scope

**In:**

- `entities/player/player_stats.gd`: clase `PlayerStats` (`extends Resource`, `class_name PlayerStats`) con los campos de movimiento: `move_speed`, `acceleration_time`, `friction_time`.
- `data/player_stats.tres`: instancia de `PlayerStats` con `move_speed = 320.0`, `acceleration_time = 0.1`, `friction_time = 0.1` (mismos valores para ambos, a ajustar en playtesting posterior).
- `assets/player/player_placeholder.svg`: forma simple (círculo/rombo) en paleta synthwave, claramente distinguible de los tiles de suelo/pared.
- `entities/player/player.tscn`: `CharacterBody2D` raíz llamado `Player`, con `Sprite2D` (textura = placeholder) y `CollisionShape2D`. `collision_layer = player`, `collision_mask = walls, enemies, enemy_projectiles, pickups` (matriz de spec 03).
- `entities/player/player.gd`: script del `Player` que lee `move_speed`/`acceleration_time`/`friction_time` desde un `@export var stats: PlayerStats`, toma input de `move_up/down/left/right`, acelera hacia velocidad máxima en 8 direcciones y frena por fricción, usando `move_and_slide()`.
- Instanciar `Player` como hijo de `levels/test_arena.tscn`, posicionado en el centro del área interior de la arena.
- Marcar la tarea `1.1` como `[x]` en `docs/tasks.md`.

**Out of scope (para specs futuras):**

- Apuntado hacia el cursor y rotación de `ShieldPivot` (tarea 1.3 / referencia 02 sección "Apuntado").
- Dash con i-frames y cooldown (tarea 1.8 / referencia 02 task 4), incluyendo el nodo `DashTimer`.
- Disco como arma: escena, FSM, lanzamiento, rebote, retorno (tareas 1.3–1.7 / referencia 02 tasks 5-8).
- Disco como escudo: bloqueo, parry, `ShieldPivot`, `ShieldHitbox`, `ParryWindowTimer` (referencia 02 tasks 9-12).
- Animaciones del jugador (`AnimatedSprite2D`/`AnimationPlayer`) — el sprite es estático.
- Vida/daño del jugador (`HealthComponent`) — Fase 2.
- Juice (shake, hit-stop, partículas) asociado al movimiento.
- Controles táctiles (joystick virtual) — Fase 4, tarea 4.5.
- i18n — esta spec no agrega texto de UI.

Cada uno de estos, cuando llegue, tendrá su propia spec.

## Data model

```gdscript
# entities/player/player_stats.gd
class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0        # px/s, velocidad máxima
@export var acceleration_time: float = 0.1   # segundos hasta alcanzar move_speed
@export var friction_time: float = 0.1       # segundos hasta frenar desde move_speed a 0
```

`data/player_stats.tres`: instancia de `PlayerStats` con los tres valores por defecto de arriba (`move_speed = 320.0`, `acceleration_time = 0.1`, `friction_time = 0.1`).

Conventions:

- `acceleration_time`/`friction_time` se expresan en segundos (no px/s² directo) para que sean legibles/editables en el inspector según el lenguaje del RF-2.1 ("velocidad máxima en ~0.1s"). `player.gd` deriva la aceleración real como `stats.move_speed / stats.acceleration_time` (px/s²) y la fricción como `stats.move_speed / stats.friction_time` (px/s²), y las aplica con `velocity.move_toward(target_velocity, rate * delta)`.
- Dirección de input: `Input.get_vector("move_left", "move_right", "move_up", "move_down")` (ya normaliza diagonales).
- Esta spec no agrega señales nuevas a `EventBus`.

**`entities/player/player.tscn`** (árbol de nodos):

```
Player (CharacterBody2D)          # collision_layer = player, collision_mask = walls|enemies|enemy_projectiles|pickups
├── Sprite2D                      # texture = player_placeholder.svg
└── CollisionShape2D              # forma acorde al sprite placeholder
```

## Implementation plan

1. Crear la carpeta `entities/player/`.
2. Crear `entities/player/player_stats.gd` con `class_name PlayerStats extends Resource` y los 3 campos exportados (`move_speed`, `acceleration_time`, `friction_time`).
3. Crear `data/player_stats.tres`: nuevo recurso `PlayerStats` desde el editor, guardado con los valores por defecto (320.0 / 0.1 / 0.1).
4. Crear `assets/player/player_placeholder.svg`: forma simple (círculo/rombo) en paleta synthwave, distinguible de los tiles de la arena.
5. Abrir el proyecto en el editor de Godot para que el SVG se importe como `Texture2D`.
6. Crear `entities/player/player.tscn`: nodo raíz `CharacterBody2D` llamado `Player`, hijo `Sprite2D` con la textura placeholder, hijo `CollisionShape2D` con una forma ajustada al sprite.
7. Configurar en `Player`: `collision_layer = player`, `collision_mask = walls, enemies, enemy_projectiles, pickups` (matriz de spec 03).
8. Crear `entities/player/player.gd`, asignarlo al nodo raíz `Player`, con `@export var stats: PlayerStats`.
9. En el editor, asignar `data/player_stats.tres` al campo `stats` del nodo `Player` en `player.tscn`.
10. Implementar en `player.gd` (`_physics_process`): leer input de 8 direcciones (`Input.get_vector`), calcular velocidad objetivo (`dirección * stats.move_speed`), aplicar aceleración/fricción derivadas con `velocity.move_toward()`, y llamar `move_and_slide()`.
11. Abrir `player.tscn` y probar standalone (F6): moverse en 8 direcciones, verificar que acelera/frena sin errores en consola.
12. Instanciar `Player` como hijo de `levels/test_arena.tscn`, posicionado en el centro del área interior (usando `Floor.map_to_local()` sobre la celda central, mismo criterio que la cámara en spec 04).
13. Ejecutar `test_arena.tscn` (F6): moverse en 8 direcciones, llegar a velocidad máxima, frenar, y verificar que no atraviesa las paredes del perímetro.
14. Marcar la tarea `1.1` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] Existe `entities/player/player_stats.gd` con `class_name PlayerStats extends Resource` y los campos `move_speed`, `acceleration_time`, `friction_time`.
- [ ] Existe `data/player_stats.tres`, instancia de `PlayerStats` con `move_speed = 320.0`, `acceleration_time = 0.1`, `friction_time = 0.1`.
- [ ] Existe `assets/player/player_placeholder.svg`, forma simple en paleta synthwave, importada como `Texture2D` sin errores.
- [ ] Existe `entities/player/player.tscn` con nodo raíz `CharacterBody2D` llamado `Player`, hijos `Sprite2D` (con el placeholder) y `CollisionShape2D`.
- [ ] `Player` tiene `collision_layer = player` y `collision_mask` con exactamente los bits `walls`, `enemies`, `enemy_projectiles`, `pickups` activos.
- [ ] Existe `entities/player/player.gd` asignado a `Player`, con `@export var stats: PlayerStats` apuntando a `data/player_stats.tres`.
- [ ] Al ejecutar `player.tscn` standalone (F6), el jugador se mueve en las 8 direcciones (arriba/abajo/izquierda/derecha y las 4 diagonales) sin errores en consola.
- [ ] El jugador alcanza `move_speed` en aproximadamente `acceleration_time` segundos al mantener una dirección, y se detiene en aproximadamente `friction_time` segundos al soltar el input.
- [ ] `levels/test_arena.tscn` instancia a `Player` como hijo, posicionado en el centro del área interior de la arena.
- [ ] Al ejecutar `test_arena.tscn` (F6), el jugador se mueve dentro de la arena y no atraviesa las paredes del perímetro.
- [ ] Ningún nodo de disco, dash, escudo o `ShieldPivot`/`ShieldHitbox`/`DashTimer`/`ParryWindowTimer` fue agregado en `player.tscn`.
- [ ] `docs/tasks.md` tiene la tarea `1.1` marcada como `[x]`.

## Decisions

- **Sí:** `PlayerStats` mínimo, solo con campos de movimiento (`move_speed`, `acceleration_time`, `friction_time`), no el Resource completo de `design.md` con todos los parámetros de disco/dash/escudo. _Razón: decisión del usuario — evita campos sin consumidor todavía; cada spec futura (dash, disco, escudo) amplía este Resource con sus propios campos cuando los necesite._
- **Sí:** `acceleration_time` y `friction_time` con el mismo valor (`0.1`) por ahora. _Razón: decisión del usuario — se ajustará en playtesting posterior, no bloquea esta spec._
- **Sí:** campos expresados en segundos (tiempo hasta velocidad máxima / hasta frenar) en vez de aceleración en px/s² directa. _Razón: coincide con el lenguaje del RF-2.1 ("velocidad máxima en ~0.1s"), más legible en el inspector; `player.gd` deriva el valor en px/s² internamente._
- **Sí:** instanciar `Player` como hijo de `test_arena.tscn` en esta misma spec, en vez de probarlo solo standalone. _Razón: decisión del usuario — quiere ver el movimiento contra las paredes ya en esta spec._
- **Sí:** `Sprite2D` con SVG propio placeholder (`assets/player/player_placeholder.svg`), mismo enfoque que `floor_tile.svg`/`wall_tile.svg` de spec 04, en vez de reusar el `icon.svg` genérico de Godot. _Razón: decisión del usuario — mantiene consistencia con el approach ya usado en la arena._
- **Sí:** aplicar ya la máscara de colisión completa (`walls`, `enemies`, `enemy_projectiles`, `pickups`), aunque solo `walls` tenga cuerpos reales hoy. _Razón: decisión del usuario — es solo configuración de bits sin costo, evita reeditar la escena cuando lleguen enemigos/pickups._
- **No:** apuntado hacia el cursor y rotación de `ShieldPivot`. _Razón: pertenece a la tarea 1.3, es una mecánica separada que merece su propia spec._
- **No:** dash, disco (lanzar/rebotar/recuperar), escudo/parry en esta spec. _Razón: cada uno es una FSM grande y distinta; se dejan para sus propias specs, siguiendo el recorte ya acordado del scope._
- **No:** animaciones (`AnimatedSprite2D`/`AnimationPlayer`) del jugador. _Razón: el sprite placeholder estático alcanza para probar movimiento; la animación real es un pase de arte posterior._

## Risks

| Riesgo                                                                                                                                              | Mitigación                                                                                                                                                      |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| El `CollisionShape2D`/`Sprite2D` del jugador no calzan visualmente con el tamaño isométrico del suelo (128×64), viéndose desproporcionado.          | No bloqueante: es un placeholder explícito. Se ajusta a ojo en el editor durante el paso 6; el pase de arte real resuelve la proporción definitiva.             |
| Sin apuntado hacia el cursor todavía, el sprite no indica hacia dónde "mira" el jugador al moverse.                                                 | Comportamiento esperado y documentado (tarea 1.3 lo resuelve en spec futura); no afecta la verificación de movimiento/colisión de esta spec.                    |
| Desajuste entre el bit de `collision_mask` del jugador y el bit real de la capa `walls` (spec 03, bit 2), dejando que el jugador atraviese paredes. | Se verifica explícitamente en el criterio de aceptación (probar contra el perímetro en `test_arena.tscn`); si falla, se corrige el bit antes de cerrar la spec. |
| `acceleration_time`/`friction_time` iguales (0.1s) pueden sentirse "pegajosos" o poco satisfactorios una vez sumados dash y disco.                  | Ya decidido como placeholder a ajustar en playtesting; el checkpoint crítico de diversión (referencia 02) llega en una spec posterior con la mecánica completa. |

## What is **not** in this spec

- Apuntado hacia el cursor y rotación de `ShieldPivot`.
- Dash con i-frames y cooldown.
- Disco como arma (lanzar/rebotar/recuperar) y como escudo (bloqueo/parry).
- Animaciones del jugador.
- Vida/daño del jugador.
- Juice (shake, hit-stop) del movimiento.
- Controles táctiles.
- i18n.

Cada una de estas, si llega, tendrá su propia spec.
