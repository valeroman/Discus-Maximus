# SPEC 08 — Disc: escena + FSM HELD/FLYING/RETURNING, lanzamiento hacia el cursor

> **Status:** Aprobado
> **Depends on:** [02-input-map-teclado-mouse.md](02-input-map-teclado-mouse.md), [03-capas-fisica.md](03-capas-fisica.md), [06-jugador-apuntado-cursor.md](06-jugador-apuntado-cursor.md)
> **Date:** 2026-07-16
> **Objective:** Crear `entities/disc/` (escena `CharacterBody2D` + FSM `HELD`/`FLYING`/`RETURNING`) que el jugador lanza hacia el cursor con la acción `throw`; el disco viaja en línea recta hasta chocar con una pared —donde pasa instantáneamente por `RETURNING` de vuelta a `HELD`, sin rebote real ni steering curvo, que llegan en specs futuras (1.4/1.5)— y bloquea nuevos lanzamientos mientras el disco no está en `HELD` (`Player.has_disc`).

## Scope

**In:**

- `entities/disc/disc_stats.gd`: nuevo `Resource` (`class_name DiscStats`) con `@export var fly_speed: float = 900.0` (según `design.md §3.1`, "velocidad ~900 px/s").
- `data/disc_stats.tres`: instancia de `DiscStats` con `fly_speed = 900.0`.
- `entities/disc/disc.gd` (extends `CharacterBody2D`):
  - Enum de estado `HELD` / `FLYING` / `RETURNING`.
  - `collision_layer = player_disc`, `collision_mask = walls | enemies | shield` (matriz de spec 03; `enemies`/`shield` no tienen cuerpos físicos todavía, pero se deja seteado según la referencia ya documentada).
  - Método público `throw(direction: Vector2)`: reparenta el disco a la raíz del nivel (o mantiene posición global si sigue en el árbol de `Player`), pasa a `FLYING`, fija `velocity = direction.normalized() * stats.fly_speed`, emite `EventBus.disc_thrown(origin, direction)`.
  - En `FLYING`, cada `_physics_process` llama `move_and_slide()` (o `move_and_collide()`); al detectar colisión (cualquier cuerpo en `walls`), pasa a `RETURNING` y, en el mismo frame, a `HELD` (teleport instantáneo de vuelta a `ShieldPivot`, `velocity = Vector2.ZERO`), emitiendo `EventBus.disc_caught()`.
  - En `HELD`, el disco no se mueve por código propio: es hijo de `ShieldPivot` y sigue su transform (posición/rotación) pasivamente.
- `entities/disc/disc.tscn`: `CharacterBody2D` raíz + `Sprite2D` (nuevo placeholder) + `CollisionShape2D` (`CircleShape2D`, radius = 12.0).
- `assets/disc/disc_placeholder.svg` (+ `.import` generado por el editor): placeholder simple (círculo/disco), mismo criterio que `assets/player/player_placeholder.svg`.
- `entities/player/player.tscn`: instanciar `disc.tscn` como hijo de `ShieldPivot`, con offset local (ej. `Vector2(24, 0)`) para que se vea "en la mano" apuntando hacia el cursor.
- `entities/player/player.gd`:
  - `var has_disc: bool = true`.
  - `@onready var disc: CharacterBody2D = $ShieldPivot/Disc`.
  - En `_physics_process`: si `Input.is_action_just_pressed("throw")` y `has_disc`, calcular dirección hacia `get_global_mouse_position()` y llamar `disc.throw(direction)`; poner `has_disc = false`.
  - Conectar `EventBus.disc_caught` (en `_ready()`) para volver a poner `has_disc = true`.
- Marcar la tarea `1.3` como `[x]` en `docs/tasks.md`.
- Verificación manual en `test_arena.tscn` (F6): lanzar con click izquierdo, ver el disco viajar en línea recta hacia el cursor, chocar contra una pared del perímetro y volver instantáneamente a `HELD`; confirmar que un segundo click mientras el disco vuela no hace nada (`has_disc == false`).

**Out of scope (para specs futuras):**

- Rebote físico real con contador de rebotes (`velocity.bounce(normal)`, `bounces_left`) — tarea `1.4`.
- Retorno con steering curvo hacia el jugador y daño de paso — tarea `1.5`.
- Recall manual (`Input` acción `recall`) y timeout de seguridad si el disco queda atascado — tarea `1.6`.
- Preview de puntería (`Line2D` + raycast mostrando trayectoria/rebote) — tarea `1.7`.
- Daño a enemigos, hit-stop y knockback al impactar (RF-2.5) — no hay enemigos todavía (Fase 2).
- SFX/VFX de lanzar, rebotar o recoger (estela de partículas, sonido) — Juice v1, tarea `1.9`.
- Indicador de UI de `has_disc` (icono lleno/vacío en HUD) — Fase 4.
- Controles táctiles de lanzamiento (drag-aim) — tarea `4.5`.
- Animación/rotación visual de giro del disco mientras vuela — no pedida, se deja para el pase de arte/Juice.
- Señales `disc_bounced` y `disc_recalled` — no se emiten en esta spec (no hay rebote real ni recall manual todavía); solo se emiten `disc_thrown` y `disc_caught`.

## Data model

**`entities/disc/disc_stats.gd`** (nuevo):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0   # px/s, velocidad durante FLYING (RF-2.1, design.md §3.1)
```

**`data/disc_stats.tres`** (nuevo): instancia de `DiscStats` con `fly_speed = 900.0`.

**`entities/disc/disc.gd`** (nuevo, extends `CharacterBody2D`):

```gdscript
class_name Disc
extends CharacterBody2D

enum State { HELD, FLYING, RETURNING }

@export var stats: DiscStats

var state: State = State.HELD

@onready var held_parent: Node2D = get_parent()      # ShieldPivot, capturado antes de cualquier reparent
@onready var held_position: Vector2 = position        # offset local dentro de ShieldPivot (ej. (24, 0))

func throw(direction: Vector2) -> void:
    var origin := global_position
    reparent(get_tree().current_scene, false)
    state = State.FLYING
    velocity = direction.normalized() * stats.fly_speed
    EventBus.disc_thrown.emit(origin, direction)

func _physics_process(_delta: float) -> void:
    if state == State.FLYING:
        var collision := move_and_collide(velocity * _delta)
        if collision:
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

**`entities/disc/disc.tscn`** (nuevo, árbol de nodos):

```
Disc (CharacterBody2D)
├── Sprite2D                # texture = disc_placeholder.svg
└── CollisionShape2D        # CircleShape2D, radius = 12.0
```

- `collision_layer = 8` (bit de `player_disc`, capa 4 según spec 03).
- `collision_mask = 70` (`walls`(2) + `enemies`(4) + `shield`(64)), igual criterio numérico que `player.tscn` (`collision_mask = 54`).
- `stats = ExtResource("data/disc_stats.tres")`.

**`entities/player/player.tscn`** (árbol actualizado):

```
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── ShieldPivot (Node2D)
│   └── Disc (instancia de disc.tscn)   # nuevo — position = (24, 0) local
├── DashTimer (Timer)
└── DashCooldownTimer (Timer)
```

**`entities/player/player.gd`** (campos/lógica nuevos):

```gdscript
@onready var disc: Disc = $ShieldPivot/Disc

var has_disc: bool = true

func _ready() -> void:
    dash_timer.timeout.connect(_on_dash_timer_timeout)
    EventBus.disc_caught.connect(_on_disc_caught)

func _on_disc_caught() -> void:
    has_disc = true
```

En `_physics_process`, antes o después del bloque de dash (sin interferir con `velocity`):

```gdscript
if Input.is_action_just_pressed("throw") and has_disc:
    var direction := (get_global_mouse_position() - global_position).normalized()
    disc.throw(direction)
    has_disc = false
```

Convenciones:

- `assets/disc/disc_placeholder.svg`: mismo criterio que `assets/player/player_placeholder.svg` (SVG simple, importado por el editor).
- No se agrega ninguna señal nueva a `EventBus`: se reutilizan `disc_thrown` y `disc_caught`, ya declaradas desde spec 01.
- `reparent(parent, false)` se usa con `keep_global_transform = false` en ambos sentidos (ida y vuelta) porque la posición se fija explícitamente después (`held_position` al volver; el `global_position` real se pasa como `origin` al emitir `disc_thrown`, no depende del transform local tras el reparent).

## Implementation plan

1. Crear `entities/disc/disc_stats.gd` con `class_name DiscStats extends Resource` y el campo `fly_speed: float = 900.0`.
2. Crear `data/disc_stats.tres`: instanciar `DiscStats` en el editor y confirmar `fly_speed = 900.0`.
3. Crear `assets/disc/disc_placeholder.svg` (placeholder simple tipo disco/círculo, mismo estilo que `assets/player/player_placeholder.svg`) e importarlo en el editor.
4. Crear `entities/disc/disc.gd` con `class_name Disc extends CharacterBody2D`, el enum `State { HELD, FLYING, RETURNING }`, `@export var stats: DiscStats`, y las variables `held_parent`/`held_position` capturadas en `@onready`.
5. Implementar `throw(direction: Vector2)`: guardar `origin`, `reparent(get_tree().current_scene, false)`, pasar a `FLYING`, fijar `velocity`, emitir `EventBus.disc_thrown(origin, direction)`.
6. Implementar `_physics_process`: mientras `state == FLYING`, llamar `move_and_collide(velocity * delta)`; si hay colisión, llamar `_return_to_held()`.
7. Implementar `_return_to_held()`: pasar por `RETURNING` (asignación de estado, sin lógica propia todavía), poner `velocity = Vector2.ZERO`, `reparent(held_parent, false)`, restaurar `position`/`rotation`, volver a `HELD`, emitir `EventBus.disc_caught()`.
8. Crear `entities/disc/disc.tscn`: nodo raíz `Disc` (script del paso 4), hijo `Sprite2D` (textura del paso 3), hijo `CollisionShape2D` (`CircleShape2D`, radius = 12.0); setear `collision_layer = 8`, `collision_mask = 70`, `stats = data/disc_stats.tres`.
9. Abrir `entities/player/player.tscn`, instanciar `disc.tscn` como hijo de `ShieldPivot`, renombrar a `Disc`, posición local `(24, 0)`.
10. En `entities/player/player.gd`: agregar `@onready var disc: Disc = $ShieldPivot/Disc`, `var has_disc: bool = true`; en `_ready()`, conectar `EventBus.disc_caught` a `_on_disc_caught()` (pone `has_disc = true`), además de la conexión ya existente de `dash_timer.timeout`.
11. En `_physics_process` de `player.gd`, agregar la detección de `Input.is_action_just_pressed("throw")`: si `has_disc` es `true`, calcular dirección hacia `get_global_mouse_position()`, llamar `disc.throw(direction)` y poner `has_disc = false`.
12. Ejecutar `entities/player/player.tscn` standalone (F6): lanzar con click izquierdo, confirmar que el disco viaja en línea recta hacia donde apuntaba el cursor al momento del click, y que un segundo click mientras vuela no hace nada (`has_disc == false`, verificable por inspector remoto o `print()` temporal).
13. Ejecutar `test_arena.tscn` (F6): repetir la verificación dentro de la arena, confirmando que al chocar con una pared del perímetro el disco vuelve instantáneamente a `HELD` (visualmente reaparece junto al jugador, siguiendo la rotación de `ShieldPivot`), `has_disc` vuelve a `true`, y un nuevo lanzamiento funciona con normalidad.
14. Confirmar en consola que no hay errores durante lanzamiento/colisión/retorno repetidos varias veces seguidas.
15. Marcar la tarea `1.3` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `entities/disc/disc_stats.gd` (`DiscStats`) existe con el campo `fly_speed` (`float`, default `900.0`).
- [ ] `data/disc_stats.tres` existe con `fly_speed = 900.0`.
- [ ] `entities/disc/disc.gd` (`Disc`, `class_name`) existe con el enum `State { HELD, FLYING, RETURNING }` y una variable `state` que refleja el estado actual.
- [ ] `entities/disc/disc.tscn` tiene `Disc` (`CharacterBody2D`) como raíz, con `Sprite2D` y `CollisionShape2D` (`CircleShape2D`, radius = 12.0) como hijos, `collision_layer = 8`, `collision_mask = 70`, y `stats` apuntando a `data/disc_stats.tres`.
- [ ] `entities/player/player.tscn` tiene `Disc` instanciado como hijo de `ShieldPivot`, en posición local `(24, 0)`.
- [ ] Al presionar `throw` (click izquierdo) con `has_disc == true`, el disco pasa a `FLYING`, se desprende de `ShieldPivot` y viaja en línea recta a `stats.fly_speed` px/s en la dirección que apuntaba el cursor en el momento del click.
- [ ] Mientras el disco está en `FLYING`/`RETURNING` (`has_disc == false`), presionar `throw` de nuevo no tiene ningún efecto (no se lanza un segundo disco, no se reinicia el vuelo).
- [ ] Al chocar el disco contra una pared (capa `walls`), pasa por `RETURNING` y en el mismo frame vuelve a `HELD`: se reparenta a `ShieldPivot`, restaura su posición local `(24, 0)` y rotación `0`, y `velocity` vuelve a `Vector2.ZERO`.
- [ ] Al volver a `HELD`, `EventBus.disc_caught` se emite y `Player.has_disc` vuelve a `true`, permitiendo un nuevo lanzamiento inmediatamente.
- [ ] Al lanzar el disco, `EventBus.disc_thrown` se emite con el `origin` (posición global del disco al momento del lanzamiento) y la `direction` normalizada.
- [ ] En `HELD`, el disco sigue la posición y rotación de `ShieldPivot` (por herencia de transform, sin código propio de seguimiento en `disc.gd`).
- [ ] Al ejecutar `player.tscn` standalone (F6), el lanzamiento funciona sin errores en consola.
- [ ] Al ejecutar `test_arena.tscn` (F6), lanzar el disco contra una pared del perímetro produce el ciclo completo (`HELD → FLYING → RETURNING → HELD`) sin errores en consola, y el movimiento del jugador, el dash y la rotación de `ShieldPivot` siguen funcionando con normalidad durante y después del ciclo.
- [ ] Repetir el ciclo lanzar/chocar/volver varias veces seguidas no genera errores ni deja el disco en un estado inconsistente (posición incorrecta, `has_disc` desincronizado, etc.).
- [ ] `EventBus` (`autoload/event_bus.gd`) permanece sin cambios (no se agregan señales nuevas; se reutilizan `disc_thrown` y `disc_caught`).
- [ ] `docs/tasks.md` tiene la tarea `1.3` marcada como `[x]`.

## Decisions

- **Sí:** el disco pasa por `RETURNING` como estado real (aunque sin lógica propia todavía) antes de volver a `HELD`, en vez de saltar directo de `FLYING` a `HELD`. _Razón: decisión del usuario — así la spec `1.5` (retorno con steering curvo) solo agrega comportamiento **dentro** de `RETURNING` (movimiento, daño de paso) sin tener que cablear una transición de estado nueva._
- **Sí:** al chocar con una pared, el disco vuelve instantáneamente a `HELD` (teleport, sin rebote real ni steering curvo), en vez de detenerse en seco o de ignorar las paredes con un límite de tiempo/distancia. _Razón: decisión del usuario — dejar el playtesting funcional (`test_arena.tscn` con paredes reales) sin adelantar trabajo de las specs `1.4` (rebote) y `1.5` (retorno), que reemplazarán este cierre por completo._
- **Sí:** `Player.has_disc: bool` bloquea nuevos lanzamientos mientras el disco no está en `HELD` (RF-2.2). _Razón: decisión del usuario — es la base que `design.md §3.1` espera exponer para el HUD futuro, y evita instanciar discos duplicados._
- **Sí:** el disco es hijo de `ShieldPivot` mientras está en `HELD`, siguiendo su rotación hacia el cursor. _Razón: decisión del usuario — coherente con el propósito declarado de `ShieldPivot` en spec 06 ("sirve de base para el disco/escudo de specs futuras")._
- **Sí:** una única instancia persistente de `Disc` (reparentada entre `ShieldPivot` y la raíz de la escena según su estado), en vez de instanciar/liberar una `PackedScene` en cada lanzamiento. _Razón: decisión del usuario — alineado con el pooling mencionado en `design.md §5`, evita instanciar nodos repetidamente para algo que ocurre constantemente._
- **Sí:** `DiscStats` (`Resource`) con el campo `fly_speed`, en vez de hardcodear la velocidad en `disc.gd`. _Razón: decisión del usuario — sigue la regla no negociable de `CLAUDE.md` ("balance en Resources, nada de números mágicos hardcodeados"), mismo patrón que `PlayerStats`._
- **Sí:** `CircleShape2D` (radius = 12.0, más chico que el radius = 24.0 del jugador) y un nuevo `assets/disc/disc_placeholder.svg`. _Razón: decisión del usuario — mismo patrón que `assets/player/player_placeholder.svg`, evita dejar el `Sprite2D` sin textura._
- **Sí:** `collision_layer = 8` (`player_disc`) y `collision_mask = 70` (`walls` + `enemies` + `shield`) aplicados ya en esta spec, aunque `enemies`/`shield` no tengan cuerpos físicos todavía. _Razón: sigue la matriz de colisión de referencia ya documentada en spec 03, evita re-decidirla; los bits sin cuerpos físicos reales no tienen efecto hasta que esas entidades existan._
- **Sí:** `reparent(parent, false)` (sin mantener transform global) en ambos sentidos, fijando `position`/`origin` explícitamente después. _Razón: evita que el offset local dentro de `ShieldPivot` quede corrompido por la posición mundial del punto de colisión al volver a `HELD`._
- **No:** rebote físico real (`velocity.bounce(normal)`, contador de rebotes). _Razón: decisión explícita del usuario — pertenece a la tarea `1.4`, spec separada._
- **No:** retorno con steering curvo ni daño de paso durante `RETURNING`. _Razón: pertenece a la tarea `1.5`, spec separada._
- **No:** recall manual (`Input` acción `recall`) ni timeout de seguridad. _Razón: pertenece a la tarea `1.6`, spec separada._
- **No:** preview de puntería (`Line2D` + raycast). _Razón: pertenece a la tarea `1.7`, spec separada._
- **No:** daño a enemigos, hit-stop ni knockback al impactar (RF-2.5). _Razón: no existen enemigos todavía (Fase 2); no hay nada que dañar._
- **No:** SFX/VFX de lanzar, rebotar o recoger. _Razón: pertenece a Juice v1 (tarea `1.9`), spec separada; `autoload/juice.gd` sigue siendo stub._
- **No:** señales nuevas en `EventBus` (`disc_bounced`, `disc_recalled` no se emiten en esta spec). _Razón: decisión del usuario — no hay rebote real ni recall manual todavía; emitirlas sería engañoso. Ya están declaradas desde spec 01 para cuando las specs `1.4`/`1.6` las necesiten._
- **No:** indicador de UI de `has_disc` en HUD. _Razón: no existe sistema de UI todavía (Fase 4), igual criterio que el cooldown de dash en spec 07._
- **No:** animación/rotación visual de giro del disco mientras vuela. _Razón: no fue pedida; se deja para el pase de arte/Juice._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                                          | Mitigación                                                                                                                                                                                                                                                                                                                     |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| A `fly_speed = 900 px/s`, si el `CollisionShape2D` de las paredes es delgado respecto al framerate, `move_and_collide` podría no detectar la colisión en un solo frame y el disco atravesaría la pared (tunneling).                                                                                                                             | No bloqueante para esta spec: `move_and_collide` (a diferencia de un raycast manual) ya resuelve colisión continua dentro del desplazamiento del frame; se verifica a ojo en el paso 13 del plan contra las paredes reales de `test_arena.tscn` y se ajusta `fly_speed`/grosor de pared en playtesting si aparece el problema. |
| El teletransporte instantáneo `FLYING → HELD` al chocar con una pared puede sentirse abrupto o confuso sin ningún feedback visual/sonoro (el disco "desaparece" de la pared y "reaparece" en el jugador).                                                                                                                                       | Comportamiento esperado y explícitamente aceptado por decisión del usuario para esta spec; se reemplaza por rebote real + retorno curvo en `1.4`/`1.5`, y por VFX/SFX en `1.9` (Juice v1).                                                                                                                                     |
| `reparent()` a `get_tree().current_scene` asume que la raíz de la escena en ejecución es un nodo `Node2D`/`Node` válido para alojar al disco en coordenadas de mundo; si en el futuro el flujo de escenas (`design.md §6`) envuelve el nivel en una jerarquía distinta (ej. `Main Menu → World Select → Level`), este supuesto podría romperse. | No bloqueante hoy: tanto `player.tscn` como `test_arena.tscn` (los dos contextos de verificación de esta spec) tienen una raíz simple compatible; se revisita si una spec futura de flujo de escenas cambia la estructura.                                                                                                     |
| Si `EventBus.disc_caught` llegara a tener más de un listener en el futuro (ej. UI, audio) y alguno de ellos lanzara una excepción, `Player.has_disc` podría no resetearse a `true`, dejando al jugador desarmado permanentemente.                                                                                                               | No aplica todavía (un solo listener: `Player._on_disc_caught`); se documenta como contrato a tener en cuenta cuando se agreguen más consumidores de esa señal (audio/VFX en `1.9`).                                                                                                                                            |
| El offset local fijo `(24, 0)` en `ShieldPivot` es un valor placeholder elegido a ojo; podría verse mal según el tamaño final del sprite del disco/jugador.                                                                                                                                                                                     | Ajustable sin tocar arquitectura: es un valor de posición en el editor, se afina en playtesting posterior igual que `dash_speed`/`move_speed`.                                                                                                                                                                                 |

## What is **not** in this spec

- Rebote físico real (`velocity.bounce(normal)`, contador de rebotes).
- Retorno con steering curvo hacia el jugador y daño de paso durante `RETURNING`.
- Recall manual y timeout de seguridad.
- Preview de puntería (`Line2D` + raycast).
- Daño a enemigos, hit-stop y knockback al impactar (no hay enemigos todavía).
- SFX/VFX de lanzar, rebotar o recoger (Juice v1).
- Indicador de UI de `has_disc` en HUD.
- Controles táctiles de lanzamiento (drag-aim).
- Animación/rotación visual de giro del disco mientras vuela.
- Señales nuevas en `EventBus` (`disc_bounced`, `disc_recalled` no se emiten en esta spec).

Cada una de estas, si llega, tendrá su propia spec.
