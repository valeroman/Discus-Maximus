# SPEC 07 — Dash con i-frames, cooldown y feedback visual

> **Status:** Implementado
> **Depends on:** [05-jugador-movimiento-8-direcciones.md](05-jugador-movimiento-8-direcciones.md), [06-jugador-apuntado-cursor.md](06-jugador-apuntado-cursor.md)
> **Date:** 2026-07-16
> **Objective:** Agregar un dash corto al `Player` (tecla `dash`, ya mapeada a espacio) que impulsa al jugador en la dirección de movimiento activa durante 0.2s con `is_invulnerable = true` y parpadeo de alpha del sprite, seguido de un cooldown de 2s que bloquea reactivarlo.

## Scope

**In:**

- `entities/player/player_stats.gd`: agregar campos `dash_speed`, `dash_duration`, `dash_cooldown` a `PlayerStats`.
- `data/player_stats.tres`: setear valores de dash (`dash_speed`, `dash_duration = 0.2`, `dash_cooldown = 2.0`).
- `entities/player/player.tscn`: agregar dos nodos `Timer` hijos de `Player`: `DashTimer` (one_shot, wait_time = `dash_duration`) y `DashCooldownTimer` (one_shot, wait_time = `dash_cooldown`).
- `entities/player/player.gd`:
  - Detectar `Input.is_action_just_pressed("dash")`.
  - Si hay `input_direction != Vector2.ZERO` y `DashCooldownTimer.is_stopped()` (no está en cooldown), iniciar dash: fijar `velocity = input_direction.normalized() * stats.dash_speed`, poner `is_invulnerable = true`, arrancar `DashTimer` y `DashCooldownTimer` simultáneamente.
  - Si no hay dirección de movimiento activa, o el dash está en cooldown, ignorar la acción (no consume cooldown, no hace nada).
  - Mientras `DashTimer` corre: la velocidad queda "congelada" en la dirección/velocidad del dash, ignorando `Input.get_vector(move_*)` (no se recalcula aceleración/fricción ese frame).
  - Al expirar `DashTimer` (señal `timeout`): `is_invulnerable = false`, se retoma el flujo normal de aceleración/fricción desde la velocidad actual.
  - Durante el dash se sigue llamando `move_and_slide()` cada frame (respeta colisión con `walls`, igual que el movimiento normal).
  - Variable pública `var is_invulnerable: bool = false` en `Player`, sin consumidor real todavía (queda para el futuro `HealthComponent`, Fase 2).
  - Parpadeo de alpha: mientras `is_invulnerable`, `Sprite2D.modulate.a` oscila (ej. alternar entre 1.0 y 0.4 cada ~0.05s, o vía `sin()` sobre el tiempo transcurrido de `DashTimer`); al terminar el dash, `modulate.a` vuelve a `1.0`.
- Marcar la tarea `1.8` como `[x]` en `docs/tasks.md`.
- Verificación manual en `player.tscn` y `test_arena.tscn` (F6): presionar `dash` (espacio) con una dirección de movimiento sostenida, confirmar el impulso, el parpadeo del sprite, y que no se puede volver a dashear hasta pasados los 2s (vía inspector remoto sobre `DashCooldownTimer.time_left` o `print()` temporal).

**Out of scope (para specs futuras):**

- `HealthComponent`, daño real, y cualquier lógica que efectivamente consuma `is_invulnerable` para ignorar daño — Fase 2.
- Señales nuevas en `EventBus` (ej. `player_dash_started`/`player_dash_ended`) — no se agregan en esta spec (decisión: solo variable pública `is_invulnerable`, sin señales).
- Indicador de UI de cooldown (barra, icono) — Fase 4, tarea 4.3/4.4.
- Dash atravesando paredes — el dash respeta la colisión sólida contra `walls`.
- Mejora "dash más largo" (RF-5.2, tarea 3.4) — sistema de mejoras aún no existe.
- Controles táctiles para dash (botón dash táctil) — tarea 4.5, Fase 4.
- Cualquier VFX/partícula de estela o SFX del dash — Juice v1 (tarea 1.9) y pase de audio (Fase 4) son specs separadas.
- Implementar el cuerpo de `Juice.flash_sprite()` — el parpadeo se hace directo en `player.gd`; `Juice` sigue siendo stub.
- Dash con dirección hacia el cursor o última dirección de movimiento como fallback — sin input de movimiento activo, el dash simplemente no ocurre.

## Data model

**`entities/player/player_stats.gd`** (campos nuevos agregados a la clase existente):

```gdscript
class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0
@export var acceleration_time: float = 0.1
@export var friction_time: float = 0.1

@export var dash_speed: float = 900.0        # px/s, velocidad durante el dash
@export var dash_duration: float = 0.2       # segundos que dura el impulso + i-frames (RF-1.2)
@export var dash_cooldown: float = 2.0       # segundos antes de poder volver a dashear (RF-1.2)
```

`data/player_stats.tres`: se actualiza la instancia existente agregando `dash_speed = 900.0`, `dash_duration = 0.2`, `dash_cooldown = 2.0` (valores placeholder a ajustar en playtesting, mismo criterio que `move_speed`/`acceleration_time`/`friction_time` de spec 05).

**`entities/player/player.tscn`** (árbol de nodos actualizado):

```
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── ShieldPivot (Node2D)
├── DashTimer (Timer)              # nuevo — one_shot = true, wait_time = dash_duration (se re-setea en código antes de start())
└── DashCooldownTimer (Timer)      # nuevo — one_shot = true, wait_time = dash_cooldown (se re-setea en código antes de start())
```

Convenciones:

- `player.gd` referencia los timers vía `@onready var dash_timer: Timer = $DashTimer` y `@onready var dash_cooldown_timer: Timer = $DashCooldownTimer`.
- Ambos timers se configuran `one_shot = true` en el editor; `wait_time` se sobreescribe en código (`dash_timer.wait_time = stats.dash_duration`) al iniciar el dash, para que lean siempre el valor vigente de `stats` (igual criterio que `move_speed` derivado de `PlayerStats`, no hardcodeado en la escena).
- `is_invulnerable: bool = false` es una variable simple en `player.gd`, sin `@export` (no es configurable, es estado runtime).
- No se agrega ninguna señal nueva a `EventBus` en esta spec.
- El parpadeo de alpha no necesita estado persistido en `PlayerStats`: se calcula en `_physics_process` a partir de `dash_timer.time_left` (o del tiempo transcurrido), sin campos nuevos de "velocidad de parpadeo" por ahora.

## Implementation plan

1. En `entities/player/player_stats.gd`, agregar los campos `dash_speed`, `dash_duration`, `dash_cooldown` (con los valores por defecto de la sección Data model).
2. Abrir `data/player_stats.tres` en el editor y setear `dash_speed = 900.0`, `dash_duration = 0.2`, `dash_cooldown = 2.0` en el inspector.
3. Abrir `entities/player/player.tscn`, agregar dos nodos `Timer` hijos de `Player`: renombrar a `DashTimer` y `DashCooldownTimer`, marcar `one_shot = true` en ambos.
4. En `entities/player/player.gd`, agregar `@onready var dash_timer: Timer = $DashTimer`, `@onready var dash_cooldown_timer: Timer = $DashCooldownTimer`, y `var is_invulnerable: bool = false`.
5. En `_physics_process`, antes de la lógica de movimiento existente, detectar `Input.is_action_just_pressed("dash")`: si `input_direction != Vector2.ZERO` y `dash_cooldown_timer.is_stopped()`, iniciar el dash (fijar velocity, `is_invulnerable = true`, setear `wait_time` en ambos timers desde `stats` y llamar `start()` en ambos).
6. Ajustar el bloque de movimiento existente (aceleración/fricción) para que se salte por completo mientras `is_invulnerable` es `true` (la velocidad queda fija en la del dash ese frame).
7. Conectar la señal `timeout` de `DashTimer` (por código, `dash_timer.timeout.connect(...)` en `_ready()`, o vía editor) a un método que ponga `is_invulnerable = false` y restaure `Sprite2D.modulate.a = 1.0`.
8. En `_physics_process`, mientras `is_invulnerable` es `true`, calcular y aplicar el parpadeo de `Sprite2D.modulate.a` en función de `dash_timer.time_left`.
9. Ejecutar `player.tscn` standalone (F6): mantener una dirección de movimiento y presionar espacio, confirmar el impulso, el parpadeo del sprite, y que repetir espacio antes de 2s no hace nada (verificar `dash_cooldown_timer.time_left` vía pestaña "Remote" o `print()` temporal que se retira antes de cerrar la spec).
10. Ejecutar `test_arena.tscn` (F6): repetir la verificación dentro de la arena, confirmando que el dash respeta las paredes del perímetro (se detiene igual que el movimiento normal) y que la rotación de `ShieldPivot` sigue funcionando sin errores en consola.
11. Marcar la tarea `1.8` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `entities/player/player_stats.gd` (`PlayerStats`) tiene los campos `dash_speed`, `dash_duration`, `dash_cooldown`.
- [ ] `data/player_stats.tres` tiene `dash_speed = 900.0`, `dash_duration = 0.2`, `dash_cooldown = 2.0`.
- [ ] `entities/player/player.tscn` tiene los nodos `DashTimer` y `DashCooldownTimer` (`Timer`, `one_shot = true`) como hijos directos de `Player`.
- [ ] Al presionar `dash` (espacio) con una dirección de movimiento sostenida y sin estar en cooldown, el jugador se impulsa instantáneamente a `stats.dash_speed` en esa dirección durante `stats.dash_duration` segundos, ignorando el input de movimiento normal mientras dura.
- [ ] Al presionar `dash` sin ninguna dirección de movimiento sostenida (`input_direction == Vector2.ZERO`), no ocurre ningún dash ni se inicia el cooldown.
- [ ] Durante el dash, `is_invulnerable` es `true`; al expirar `DashTimer`, vuelve a `false` y el jugador retoma el flujo normal de aceleración/fricción.
- [ ] Durante el dash, `Sprite2D.modulate.a` parpadea visiblemente; al terminar el dash, vuelve a `1.0`.
- [ ] Al presionar `dash` nuevamente antes de que pasen `stats.dash_cooldown` segundos desde el inicio del dash anterior, la acción se ignora (verificable vía `dash_cooldown_timer.time_left` en la pestaña "Remote" o `print()` temporal).
- [ ] Pasados los `stats.dash_cooldown` segundos desde el inicio del dash anterior, un nuevo `dash` funciona normalmente.
- [ ] El dash respeta la colisión con `walls`: al ejecutar `test_arena.tscn` (F6), el jugador no atraviesa las paredes del perímetro al dashear contra ellas.
- [ ] La rotación de `ShieldPivot` hacia el cursor sigue funcionando sin errores en consola, tanto en `player.tscn` como en `test_arena.tscn`, durante y después del dash.
- [ ] `autoload/juice.gd` permanece sin cambios (sigue siendo stub).
- [ ] `EventBus` (`autoload/event_bus.gd`) permanece sin cambios (no se agregan señales nuevas).
- [ ] `docs/tasks.md` tiene la tarea `1.8` marcada como `[x]`.

## Decisions

- **Sí:** `dash_speed` + `dash_duration` en `PlayerStats`, en vez de una `dash_distance` fija. _Razón: decisión del usuario — coherente con el patrón ya usado (`move_speed`/`acceleration_time`/`friction_time` en segundos), da más control sobre la sensación del dash._
- **Sí:** un solo timer (`dash_duration = 0.2s`) para movimiento e i-frames, en vez de dos valores independientes. _Razón: decisión del usuario — mantiene la implementación mínima; RF-1.2 pide el mismo valor (0.2s) para ambos, no hay necesidad de desacoplarlos hoy._
- **Sí:** dirección del dash = dirección de movimiento activa (`Input.get_vector(move_*)`) en el momento de presionar la tecla. _Razón: decisión del usuario — patrón típico de dash arcade, evita ambigüedad con la dirección del cursor (que ya tiene otro uso: `ShieldPivot`)._
- **Sí:** si no hay dirección de movimiento activa, el dash simplemente no ocurre (no consume cooldown). _Razón: decisión del usuario — evita direcciones de fallback ambiguas (cursor o última dirección) sin un caso de uso claro todavía._
- **Sí:** velocidad "congelada" durante el dash, ignorando el input de movimiento mientras dura. _Razón: decisión del usuario — dash arcade estándar, más simple que permitir redirección a mitad de dash._
- **Sí:** `is_invulnerable: bool` como variable pública simple en `Player`, sin señales nuevas en `EventBus`. _Razón: decisión del usuario — no hay ningún consumidor real todavía (`HealthComponent` es Fase 2); agregar señales sin listener es prematuro._
- **Sí:** el cooldown de 2s arranca al iniciar el dash (en paralelo a los 0.2s de movimiento/i-frames), no al terminarlo. _Razón: decisión del usuario — más generoso y estándar en la mayoría de juegos arcade; evita un tiempo efectivo de 2.2s entre dashes._
- **Sí:** feedback visual como parpadeo directo de `Sprite2D.modulate.a` en `player.gd`, sin tocar `autoload/juice.gd`. _Razón: decisión del usuario — `Juice` sigue siendo stub (`pass`); completar su cuerpo es una spec propia (tarea 1.9), no se adelanta aquí._
- **Sí:** el dash respeta la colisión sólida contra `walls` (usa `move_and_slide()` igual que el movimiento normal). _Razón: decisión del usuario — nada en RF-1.2 pide atravesar paredes; los i-frames son sobre daño futuro, no sobre física de colisión sólida._
- **Sí:** `DashTimer` y `DashCooldownTimer` como nodos `Timer` explícitos en la escena, en vez de floats decrementados a mano. _Razón: decisión del usuario — más fácil de inspeccionar en el editor/pestaña Remote, consistente con el enfoque de nodos nombrados ya usado (`ShieldPivot`)._
- **Sí:** marcar la tarea `1.8` como `[x]` en `docs/tasks.md`. _Razón: decisión del usuario — a diferencia de spec 06 (sub-parte de la tarea 1.3), el alcance de esta spec coincide exactamente y por completo con la tarea 1.8._
- **No:** indicador de UI de cooldown. _Razón: decisión del usuario — no existe sistema de UI todavía; se verifica con inspector remoto o `print()` temporal, igual que la rotación de `ShieldPivot` en spec 06._
- **No:** VFX de estela, SFX de dash, ni mejora "dash más largo". _Razón: pertenecen a tareas separadas (1.9 Juice v1, pase de audio Fase 4, sistema de mejoras Fase 3)._

## Risks

| Riesgo                                                                                                                                                                                                                                                              | Mitigación                                                                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `is_invulnerable` queda como convención implícita sin contrato formal; el futuro `HealthComponent` (Fase 2) podría no leerla correctamente o esperar otro nombre/tipo.                                                                                              | No bloqueante para esta spec: se documenta explícitamente el nombre y tipo (`bool`) en Data model; la spec de `HealthComponent` deberá referenciar este campo al implementarse. |
| Al terminar el dash bruscamente (`is_invulnerable = false`), la velocidad queda en `dash_speed` y el siguiente frame de aceleración/fricción parte desde ahí, pudiendo sentirse como un "frenazo" si `dash_speed` es mucho mayor que `move_speed`.                  | Comportamiento esperado dado que `friction_time` ya frena progresivamente; se ajusta `dash_speed`/`friction_time` en playtesting posterior si se siente mal.                    |
| `dash_timer.wait_time`/`dash_cooldown_timer.wait_time` se sobreescriben en código en cada `start()`; si se olvida resetear antes de un segundo dash, podría quedar un `wait_time` desactualizado si `stats` cambia en runtime (ej. mejora futura "dash más largo"). | Mitigado por el plan de implementación (paso 5: setear `wait_time` desde `stats` en cada inicio de dash, no solo una vez en `_ready()`).                                        |
| El parpadeo de `Sprite2D.modulate.a` podría no notarse bien contra el placeholder synthwave si el contraste de alpha es muy sutil.                                                                                                                                  | No bloqueante: es un ajuste de valores (ej. 1.0 ↔ 0.4) verificable a ojo en el paso 9 del plan; se puede afinar sin cambiar la arquitectura.                                    |

## What is **not** in this spec

- `HealthComponent` y cualquier lógica real de daño/vida que consuma `is_invulnerable`.
- Señales nuevas en `EventBus` (`player_dash_started`/`player_dash_ended`).
- Indicador de UI de cooldown.
- Dash atravesando paredes.
- Mejora "dash más largo" ni sistema de mejoras.
- Controles táctiles de dash.
- VFX de estela, SFX del dash, o implementación real de `Juice.flash_sprite()`.
- Dash con dirección hacia el cursor o última dirección de movimiento como fallback.

Cada una de estas, si llega, tendrá su propia spec.
