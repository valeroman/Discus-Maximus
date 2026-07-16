# SPEC 13 — Proyectil genérico parryable + TrainingDummy

> **Status:** Implementado
> **Depends on:** [03-capas-fisica.md](03-capas-fisica.md), [12-bloqueo-estado-block.md](12-bloqueo-estado-block.md)
> **Date:** 2026-07-16
> **Objective:** Crear `projectile.tscn` (proyectil genérico con flag `parryable`) y `TrainingDummy` (dispara hacia el jugador cada 2s), agregando el primer `ShieldHitbox` real para que el bloqueo de spec 12 detenga proyectiles `parryable` en pruebas manuales.

## Scope

**In:**

- `entities/projectile/projectile_data.gd`: nuevo `Resource` (`class_name ProjectileData`) con `speed: float`, `lifetime: float`, `parryable: bool`.
- `data/projectile_data.tres`: instancia por defecto (`speed = 400.0`, `lifetime = 3.0`, `parryable = true`).
- `entities/projectile/projectile.gd` + `entities/projectile/projectile.tscn`: `CharacterBody2D` genérico, capa `enemy_projectiles` (mask `walls`, `player`, `shield`, ya fijada en spec 03). Vuela en línea recta a `stats.speed` desde el `direction` recibido en un método `launch(direction: Vector2)`; se autodestruye (`queue_free`) al colisionar con pared o jugador, o al agotar `stats.lifetime`.
- `entities/enemies/training_dummy.gd` + `entities/enemies/training_dummy.tscn`: `StaticBody2D` en capa `enemies` (mask vacía, igual que "Walls" en spec 03 — cuerpo estático), sin vida ni FSM. Cada `fire_interval` (`@export var fire_interval: float = 2.0`, `Timer`), instancia `projectile_scene` (`@export var projectile_scene: PackedScene`), lo posiciona en su `global_position` y llama `launch()` con dirección recalculada hacia `global_position` del jugador (`get_tree().get_first_node_in_group("player")`).
- `entities/player/player.tscn`: agregar `ShieldHitbox` (`Area2D`, capa `shield`, mask `enemy_projectiles`) como hijo de `ShieldPivot`, con `monitoring = false` por defecto. Agregar el `Player` al grupo `player`.
- `entities/player/player.gd`: en `_physics_process`, sincronizar `shield_hitbox.monitoring = is_blocking`; conectar `body_entered` → si el cuerpo es `Projectile` y `parryable`, llamar a `projectile.block()` (destruye el proyectil y emite `EventBus.disc_blocked(false)`); si no es `parryable`, no hacer nada (el proyectil sigue de largo, sin bloquear su movimiento — `Area2D` nunca detiene físicamente).
- `levels/test_arena.tscn`: agregar una instancia de `TrainingDummy` dentro del área de la arena, con `projectile_scene`/`projectile_data` asignados en el editor.
- Placeholders SVG mínimos (mismo estilo synthwave que los existentes): `assets/enemies/training_dummy_placeholder.svg`, `assets/projectile/projectile_placeholder.svg`.
- Verificación manual en `test_arena.tscn` (F6).

**Out of scope (specs futuras):**

- `HealthComponent`/`HurtboxComponent` y cualquier daño real al jugador o al `TrainingDummy` — tarea `2.1`, sin hacer todavía. El proyectil que golpea al jugador (sin bloqueo o no-parryable) solo se destruye; no hay pérdida de vida.
- `EnemyBase`, FSM de enemigos, `NavigationAgent2D`, `EnemyData` — tarea `2.2`. `TrainingDummy` es un nodo standalone, no un enemigo completo.
- Ventana de **parry perfecto** (`perfect: bool` siempre `false` en esta spec) — spec propia futura, como ya definió spec 12.
- Lancer real (proyectil-disco propio, keep-range, recarga) — tarea `2.6`. Este proyectil es genérico/reusable, no específico del Lancer.
- Reflejar o redirigir el proyectil al bloquearlo — el bloqueo solo lo destruye (`disc_blocked(false)`), no lo devuelve al remitente.
- SFX/VFX de impacto, bloqueo o disparo (partículas, screen shake, sonido) — Juice v1 (tarea `1.9`) y pase de audio (Fase 4).
- Sprite/arte final del proyectil o del dummy — placeholders únicamente, mismo criterio que `player_placeholder.svg`/`disc_placeholder.svg`.
- Controles táctiles — no aplica (esta spec no toca input del jugador más allá de reusar `is_blocking` ya existente).
- Cambios a `docs/tasks.md` — no hay tarea explícita para "proyectil genérico + TrainingDummy" en el plan (igual que specs 06/12); se deja intacto.
- Cambios a la física/steering del disco del jugador (`disc.gd`, specs 08-11) — el disco del jugador no interactúa con `ShieldHitbox` ni con el proyectil enemigo salvo el rebote físico normal contra `TrainingDummy` (ya cubierto por capas existentes, sin código nuevo en `disc.gd`).

## Data model

**`entities/projectile/projectile_data.gd`** (nuevo):

```gdscript
class_name ProjectileData
extends Resource

@export var speed: float = 400.0      # px/s, velocidad en línea recta
@export var lifetime: float = 3.0     # s, autodestrucción si no choca con nada (seguridad anti-atasco)
@export var parryable: bool = true    # si true, ShieldHitbox lo bloquea durante BLOCK
```

**`data/projectile_data.tres`**: instancia de `ProjectileData` con los valores por defecto de arriba.

**`entities/projectile/projectile.gd`** (nuevo):

```gdscript
class_name Projectile
extends CharacterBody2D

@export var stats: ProjectileData

var _lifetime_left: float = 0.0

func launch(direction: Vector2) -> void:
	velocity = direction.normalized() * stats.speed
	_lifetime_left = stats.lifetime

func block() -> void:
	EventBus.disc_blocked.emit(false)
	queue_free()

func _physics_process(delta: float) -> void:
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		queue_free()
		return
	var collision := move_and_collide(velocity * delta)
	if collision:
		queue_free()
```

**`entities/enemies/training_dummy.gd`** (nuevo):

```gdscript
class_name TrainingDummy
extends StaticBody2D

@export var projectile_scene: PackedScene
@export var projectile_data: ProjectileData
@export var fire_interval: float = 2.0

@onready var fire_timer: Timer = $FireTimer

func _ready() -> void:
	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	fire_timer.start()

func _on_fire_timer_timeout() -> void:
	var target := get_tree().get_first_node_in_group("player")
	if not target:
		return
	var projectile: Projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.stats = projectile_data
	projectile.launch((target.global_position - global_position).normalized())
```

**`entities/player/player.gd`** (agregado a lo existente, sin tocar el resto):

```gdscript
@onready var shield_hitbox: Area2D = $ShieldPivot/ShieldHitbox

func _ready() -> void:
	dash_timer.timeout.connect(_on_dash_timer_timeout)
	EventBus.disc_caught.connect(_on_disc_caught)
	shield_hitbox.body_entered.connect(_on_shield_hitbox_body_entered)

func _on_shield_hitbox_body_entered(body: Node2D) -> void:
	if body is Projectile and body.stats.parryable:
		body.block()

# en _physics_process, junto al resto de is_blocking:
	shield_hitbox.monitoring = is_blocking
```

Convenciones:

- `Projectile` no tiene FSM (a diferencia de `Disc`): solo `launch()`/`block()` y autodestrucción por colisión o `lifetime`. No hay estado `HELD`/`RETURNING` — es de un solo uso.
- `TrainingDummy` requiere que el `Player` esté en el grupo `player` (se agrega el grupo en `player.tscn` como parte de esta spec, si no existe ya).
- `ShieldHitbox.monitoring` se sincroniza con `is_blocking` cada frame (mismo patrón que el tinte de `disc.modulate` en spec 12): activo solo con disco en mano y bloqueando.
- Un proyectil no-`parryable` que entra en `ShieldHitbox` no dispara ninguna rama en `_on_shield_hitbox_body_entered` (la condición `body.stats.parryable` es `false`) — sigue su `move_and_collide` normal y puede golpear el cuerpo físico del `Player` (capa `enemy_projectiles` ya está en el mask de `player`, spec 03) y autodestruirse ahí.
- `TrainingDummy` en capa `enemies` (mask vacía, igual que "Walls"): el disco del jugador (`mask` incluye `enemies`, spec 03) rebota contra él vía la lógica ya existente en `disc.gd` (spec 09) — cero cambios en `disc.gd`.

## Implementation plan

1. Crear `entities/projectile/projectile_data.gd` (`Resource`, campos `speed`/`lifetime`/`parryable`) y `data/projectile_data.tres` con los valores por defecto.
2. Crear `entities/projectile/projectile.gd` con `launch(direction)`, `block()` y `_physics_process` (descuento de `lifetime`, `move_and_collide`, autodestrucción).
3. Crear `entities/projectile/projectile.tscn`: `CharacterBody2D` + `CollisionShape2D` (círculo ~8px) + `Sprite2D`, capa `enemy_projectiles` / mask `walls, player, shield`, script y `stats` asignados.
4. Crear placeholder `assets/projectile/projectile_placeholder.svg` (forma simple, acento neón `#ff2079`) e importar en el editor.
5. Crear `entities/enemies/training_dummy.gd` con `FireTimer`-driven: cada `fire_interval`, instancia `projectile_scene`, lo posiciona y lanza hacia el jugador.
6. Crear `entities/enemies/training_dummy.tscn`: `StaticBody2D` + `CollisionShape2D` + `Sprite2D` + `FireTimer`, capa `enemies` (mask vacía), script asignado.
7. Crear placeholder `assets/enemies/training_dummy_placeholder.svg`.
8. En el editor, en `training_dummy.tscn`, asignar `projectile_scene = projectile.tscn` y `projectile_data = data/projectile_data.tres` en el Inspector.
9. Agregar al `Player` (`player.tscn`) al grupo `player` (si no está ya) y el nodo `ShieldHitbox` (`Area2D` + `CollisionShape2D`, capa `shield` / mask `enemy_projectiles`, `monitoring = false`) como hijo de `ShieldPivot`.
10. En `player.gd`, agregar `@onready var shield_hitbox`, conectar `body_entered` en `_ready()`, agregar `_on_shield_hitbox_body_entered()`, y sincronizar `shield_hitbox.monitoring = is_blocking` en `_physics_process`.
11. En `levels/test_arena.tscn`, instanciar `TrainingDummy` dentro del área jugable de la arena (ajustar posición en el editor para que quede accesible desde el spawn del jugador).
12. F6 `test_arena.tscn`: confirmar que el dummy dispara un proyectil cada 2s hacia la posición del jugador, en línea recta, y que se destruye al chocar con una pared o con el jugador.
13. F6: cruzar el disco (en vuelo normal, sin relación con el proyectil) contra el `TrainingDummy` → confirmar que rebota como si fuera una pared, sin tocar `disc.gd`.
14. F6: con disco en mano, sostener `block` (Left Shift) cuando un proyectil se acerque → confirmar que se destruye cerca del escudo (bloqueado) y no llega al jugador; en consola, confirmar que `EventBus.disc_blocked(false)` se emite (print temporal o pestaña "Remote").
15. F6: cambiar temporalmente `parryable = false` en `data/projectile_data.tres`, repetir el bloqueo → confirmar que el proyectil atraviesa el escudo sin destruirse ahí y golpea/se destruye contra el cuerpo del jugador. Revertir `parryable = true` al terminar.
16. Retirar cualquier `print()` temporal usado para verificar `disc_blocked`.

## Acceptance criteria

- [x] `ProjectileData` (`Resource`) existe con `speed: float`, `lifetime: float`, `parryable: bool`; `data/projectile_data.tres` tiene los 3 campos con los valores por defecto (`400.0`, `3.0`, `true`).
- [x] `Projectile` (`CharacterBody2D`) viaja en línea recta a `stats.speed` tras `launch(direction)`.
- [x] `Projectile` se autodestruye al chocar con una pared o con el jugador (colisión física, capa `enemy_projectiles` / mask `walls, player, shield`).
- [x] `Projectile` se autodestruye al agotar `stats.lifetime` si no chocó con nada antes.
- [x] `TrainingDummy` dispara un `Projectile` cada `fire_interval` (default `2.0s`) hacia la posición actual del jugador (recalculada en cada disparo).
- [x] `TrainingDummy` es un `StaticBody2D` en capa `enemies` (mask vacía), sin `HealthComponent`, FSM ni `NavigationAgent2D`.
- [x] El disco del jugador (`disc.gd`, sin cambios) rebota contra `TrainingDummy` igual que contra una pared.
- [x] `ShieldHitbox` (`Area2D`, capa `shield` / mask `enemy_projectiles`) existe como hijo de `ShieldPivot`, con `monitoring` sincronizado a `is_blocking` cada frame.
- [x] Mientras `is_blocking` y un `Projectile` con `parryable = true` entra en `ShieldHitbox`, se destruye (`queue_free`) y se emite `EventBus.disc_blocked(false)`.
- [x] Mientras `is_blocking` y un `Projectile` con `parryable = false` entra en `ShieldHitbox`, no pasa nada en el escudo (no se destruye ahí, sigue su trayectoria); si continúa y choca con el jugador, se destruye por la colisión física normal.
- [x] Sin `is_blocking` (`ShieldHitbox.monitoring = false`), cualquier `Projectile` (parryable o no) que llega al jugador se destruye por colisión física directa contra el cuerpo del `Player`, sin pasar por `ShieldHitbox`.
- [x] `EventBus.disc_blocked` se emite **solo** con `perfect = false` en esta spec (sin ventana de parry perfecto).
- [x] No se agrega `HealthComponent`, `HurtboxComponent`, `EnemyBase` ni daño real al jugador.
- [x] `levels/test_arena.tscn` incluye una instancia de `TrainingDummy` visible y funcional junto al `Player`.
- [x] F6 en `test_arena.tscn`: los 4 escenarios de arriba (disparo cada 2s, rebote del disco contra el dummy, bloqueo con `parryable = true`, atravesar con `parryable = false`) se comportan como se describe, sin errores en consola, repetible varias veces sin estado inconsistente.
- [x] `docs/tasks.md` no se modifica (no hay tarea explícita para esta spec, mismo criterio que specs 06/12).

## Decisions

- **Sí:** implementar `ShieldHitbox` real (`Area2D`) ahora, en vez de dejar `parryable` como flag sin consumidor. _Razón: decisión del usuario — sin detección real, `parryable` no tendría ningún efecto observable; esta spec es el punto natural para cerrarlo, ya que introduce el primer proyectil enemigo real (spec 12 solo diferido por "no hay proyectiles enemigos hasta Fase 2")._
- **Sí:** `ShieldHitbox` como `Area2D` (no `StaticBody2D` sólido). _Razón: un `Area2D` nunca detiene físicamente el movimiento — así un proyectil `parryable=false` puede "atravesar" el escudo sin código extra en `projectile.gd`; solo el `body_entered` decide si se bloquea o no._
- **Sí:** `ShieldHitbox.monitoring` sincronizado a `is_blocking` cada frame (no un nodo siempre activo con chequeo interno). _Razón: mismo patrón que el tinte de `disc.modulate` en spec 12 — reusa el flag ya existente, sin lógica duplicada de "¿puedo bloquear ahora?"._
- **Sí:** bloqueo destruye el proyectil sin reflejarlo ni redirigirlo, emitiendo `EventBus.disc_blocked(false)`. _Razón: decisión del usuario — mantiene el bloqueo con un único efecto claro (igual criterio que `recall()` en spec 11); reflejar el proyectil es una mecánica más grande que merece su propia spec si se decide agregarla._
- **Sí:** `perfect` siempre `false` en esta spec (sin ventana de parry perfecto). _Razón: spec 12 ya decidió diferir el parry perfecto a una spec propia; esta spec no reabre esa decisión._
- **Sí:** proyectil sin daño real al jugador (`HealthComponent` no existe, tarea 2.1 sin hacer) — solo se destruye al chocar. _Razón: decisión del usuario — evita adelantar lógica de vida a medias; cuando llegue 2.1, el daño se conecta ahí sin tocar `projectile.gd`._
- **Sí:** `TrainingDummy` como obstáculo sólido para el disco (capa `enemies`, ya en la matriz de spec 03), sin cambios en `disc.gd`. _Razón: decisión del usuario — reusa el rebote genérico contra cualquier cuerpo en `walls`/`enemies` que ya implementa spec 09, cero código nuevo._
- **Sí:** `TrainingDummy` sin `HealthComponent`/FSM/`NavigationAgent2D`, como nodo standalone en `entities/enemies/`. _Razón: `EnemyBase` (tarea 2.2) no existe todavía; el dummy es una herramienta de testeo del bloqueo, no un enemigo real — se reemplaza o se adapta cuando llegue 2.2._
- **Sí:** `lifetime` de seguridad en `ProjectileData` (`3.0s` default). _Razón: decisión del usuario — mismo patrón anti-atasco que `flight_timeout` del disco (spec 11); evita proyectiles volando para siempre si no chocan con nada._
- **Sí:** `ProjectileData` como `Resource` (`speed`, `lifetime`, `parryable`), sin campo `damage`. _Razón: regla `CLAUDE.md` anti-números-mágicos + convención anti-especulación (specs 07/11/12) — `damage` no tiene consumidor hoy (sin `HealthComponent`); se agrega en la spec de daño (2.1)._
- **No:** `EnemyBase`, FSM, `NavigationAgent2D`, `EnemyData` — tarea `2.2`, fuera de alcance.
- **No:** Lancer real (proyectil-disco, keep-range, recarga) — tarea `2.6`; este proyectil es genérico y reusable, no el Lancer.
- **No:** SFX/VFX de disparo, impacto o bloqueo — Juice v1 (tarea `1.9`).
- **No:** cambios a `docs/tasks.md` — no hay tarea explícita para esta feature (mismo criterio que specs 06/12).

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                     | Mitigación                                                                                                                                                                                                                                                                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TrainingDummy` como obstáculo sólido para el disco podría interferir con el steering de retorno (`RETURNING`, spec 10) si el jugador lo coloca entre el disco y el `ShieldPivot` — el disco podría rebotar en vez de converger.                                                                                           | No bloqueante: mismo comportamiento que cualquier pared entre el disco y el jugador (spec 09/10 ya lo permiten); se ajusta la posición del dummy en el editor durante playtesting si molesta.                                                                                                                              |
| Sin `HealthComponent`, un proyectil que "golpea" al jugador no tiene ninguna consecuencia visible (solo desaparece) — puede sentirse anticlimático o hacer difícil notar si el bloqueo realmente funcionó vs. si el proyectil simplemente iba a fallar.                                                                    | No bloqueante: aceptado para esta spec de testeo; Juice v1 (tarea `1.9`) y el pase de daño (2.1) agregarán feedback real más adelante.                                                                                                                                                                                     |
| `ShieldHitbox.monitoring` se activa/desactiva cada frame; si `is_blocking` cambia varias veces en frames consecutivos mientras un proyectil está justo en el borde del área, podría haber un frame de carrera donde el `body_entered` no dispare (Area2D solo emite en el frame de entrada, no mientras permanece dentro). | No bloqueante: comportamiento estándar de `Area2D`; en la práctica el proyectil cruza el área en 1-2 frames a las velocidades configuradas (`speed` default `400px/s`), ventana de colisión suficiente. Si se nota inconsistente en playtesting, se ajusta `speed`/tamaño del `CollisionShape2D` sin cambiar arquitectura. |
| Placeholders SVG nuevos (`training_dummy_placeholder.svg`, `projectile_placeholder.svg`) sin arte final — visualmente pueden confundirse con otros elementos de la arena hasta que llegue el arte real (tarea `4.7`).                                                                                                      | No bloqueante: mismo criterio que `player_placeholder.svg`/`disc_placeholder.svg`; son temporales por diseño.                                                                                                                                                                                                              |

## What is **not** in this spec

- `HealthComponent`/`HurtboxComponent` y daño real al jugador o al `TrainingDummy`.
- `EnemyBase`, FSM de enemigos, `NavigationAgent2D`, `EnemyData`.
- Ventana de parry perfecto (`perfect` siempre `false`).
- Lancer real (proyectil-disco propio, keep-range, recarga).
- Reflejar o redirigir el proyectil al bloquearlo.
- SFX/VFX de disparo, impacto o bloqueo.
- Arte final del proyectil o del dummy (solo placeholders).
- Cambios a `docs/tasks.md`.
- Cambios a la física/steering del disco del jugador (`disc.gd`).

Cada una de estas, si llega, tendrá su propia spec.
