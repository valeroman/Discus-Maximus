# SPEC 15 — Parry perfecto: ventana 0.15s, reflejo ×2 daño, slowmo + VFX cian

> **Status:** Implementado
> **Depends on:** [12-bloqueo-estado-block.md](12-bloqueo-estado-block.md), [13-proyectil-generico-training-dummy.md](13-proyectil-generico-training-dummy.md), [14-bloqueo-frontal-knockback-shake.md](14-bloqueo-frontal-knockback-shake.md)
> **Date:** 2026-07-17
> **Objective:** Agregar una ventana de parry perfecto de 0.15s (`parry_window`, nuevo `ParryWindowTimer` en `Player`, mismo patrón que `dash_timer`) al inicio de cada bloqueo (`BLOCK`, specs 12/14): si un `Projectile` `parryable` entra al `ShieldHitbox` dentro de esa ventana, en vez de destruirse (spec 13/14) se refleja (`velocity = -velocity`, sin knockback ni shake de spec 14) con el daño duplicado (`ProjectileData.damage` nuevo, dato sin consumidor real todavía — no hay `HealthComponent`) y dispara `Juice.slowmo()` y `Juice.flash_sprite()` reales por primera vez (hoy `pass`) con tinte cian (`#00f0ff`) sobre el sprite del `Player`; fuera de esa ventana, el bloqueo se comporta exactamente igual que hoy (destruye + knockback + shake).

## Scope

**In:**

- `entities/player/player_stats.gd`: agregar 4 campos a `PlayerStats`:
  - `@export var parry_window: float = 0.15` (ventana de parry perfecto, s, desde que arranca `BLOCK`).
  - `@export var parry_damage_multiplier: float = 2.0` (multiplicador de daño del proyectil reflejado).
  - `@export var parry_slowmo_scale: float = 0.15` (`Engine.time_scale` durante el slowmo).
  - `@export var parry_slowmo_duration: float = 0.25` (segundos reales — no escalados — que dura el slowmo).
- `data/player_stats.tres`: setear los 4 campos nuevos (conservando los 9 campos previos).
- `entities/projectile/projectile_data.gd`: agregar `@export var damage: float = 10.0` a `ProjectileData` (dato sin receptor real todavía — no hay `HealthComponent`/`HurtboxComponent`, tarea `2.1` pendiente).
- `data/projectile_data.tres`: setear `damage = 10.0`.
- `entities/projectile/projectile.gd`:
  - Nueva var runtime `var damage: float = 0.0`, copiada desde `stats.damage` en `launch()` (nunca se muta `stats.damage` directamente — el `Resource` es compartido entre instancias).
  - Nuevo método `reflect(multiplier: float) -> void`: invierte `velocity` (`velocity = -velocity`), multiplica `damage` por `multiplier`, y agrega la capa `enemies` al `collision_mask` (`set_collision_mask_value(3, true)`) para que la trayectoria de vuelta pueda impactar al `TrainingDummy` que lo disparó. No llama a `queue_free()` — el proyectil sigue vivo y en vuelo.
- `entities/player/player.tscn`: agregar `ParryWindowTimer` (`Timer`, `one_shot = true`) como hijo de `Player`, mismo nivel que `DashTimer`/`DashCooldownTimer`.
- `entities/player/player.gd`:
  - `@onready var parry_window_timer: Timer = $ParryWindowTimer`.
  - En `_physics_process`, al detectar el flanco `is_blocking` `false → true`, iniciar `parry_window_timer.start(stats.parry_window)`.
  - `_on_shield_hitbox_body_entered`: si `body is Projectile and body.stats.parryable`, ramificar según `not parry_window_timer.is_stopped()`:
    - **Dentro de la ventana (parry perfecto):** `body.reflect(stats.parry_damage_multiplier)`, `Juice.slowmo(stats.parry_slowmo_scale, stats.parry_slowmo_duration)`, `Juice.flash_sprite(sprite)`, `EventBus.disc_blocked.emit(true)`. Sin knockback (`velocity` del `Player` no cambia) ni `Juice.shake()`.
    - **Fuera de la ventana (bloqueo normal):** comportamiento actual sin cambios (spec 14) — knockback, `Juice.shake()`, `body.block()` (que emite `disc_blocked(false)`).
- `autoload/juice.gd`:
  - Implementar `slowmo(scale: float, duration: float) -> void` real: setea `Engine.time_scale = scale` y lo restaura a `1.0` tras `duration` segundos **reales** (`get_tree().create_timer(duration, false, false, true)`, con `ignore_time_scale = true` para que la propia duración del slowmo no quede afectada por el `time_scale` que acaba de bajar).
  - Implementar `flash_sprite(sprite: CanvasItem) -> void` real: tiñe `sprite.modulate` a `Color("#00f0ff")` y lo devuelve a `Color.WHITE` en un lapso corto vía `Tween` (mismo patrón que `shake()`, spec 14).
  - `hit_stop()` sigue como `pass` (no se toca).
- Verificación manual en `test_arena.tscn` (F6).

**Out of scope (specs futuras):**

- `HealthComponent`/`HurtboxComponent` y cualquier consumo real de `damage` — tarea `2.1`. El daño ×2 es solo un número en runtime (`Projectile.damage`), verificable por `print()`/pestaña "Remote", sin efecto de vida real ni en el `Player` ni en el `TrainingDummy`.
- HP/vida del `TrainingDummy` — no se agrega ni siquiera como adelanto mínimo (a diferencia de `Juice.shake()` en spec 14); el impacto contra el dummy es solo colisión física (se destruye como cualquier proyectil contra un cuerpo sólido), sin ningún contador de golpes ni diferencia visible entre daño simple y ×2 más allá del propio destruirse.
- Detección de ángulo/cono frontal-espalda — sigue sin agregarse (igual que spec 14); "parry" solo aplica a lo que entra en `ShieldHitbox`.
- Tap dedicado o input independiente para el parry — la ventana se deriva del flanco de `is_blocking` ya existente, sin nueva acción en el Input Map.
- Reflejar/redirigir hacia el cursor o hacia una referencia guardada del emisor — el reflejo es únicamente `velocity = -velocity` (decisión tomada).
- Cambiar `parryable` del proyectil reflejado — se deja tal cual viene del `Resource` compartido (decisión tomada, sin consumidor que lo necesite hoy).
- Accesibilidad / toggle para reducir slowmo o flash (`CLAUDE.md` menciona reducir efectos) — Fase 4, no se agrega ningún ajuste de settings aquí.
- SFX del parry — pase de audio, Fase 4.
- Partículas, estela u otro VFX más allá del flash de sprite (`Juice.hit_stop()` sigue stub) — Juice v1 completo, tarea `1.9`.
- Controles táctiles — no aplica.
- Cambios a `docs/tasks.md` — no hay tarea explícita para "parry perfecto" en el plan (mismo criterio que specs 06/12/13/14); se deja intacto.
- Cambios a la física/steering del disco del jugador (`disc.gd`) — el parry es exclusivo del `Projectile` enemigo vía `ShieldHitbox`, sin tocar `disc.gd`.

## Data model

**`entities/player/player_stats.gd`** (4 campos nuevos, resto intacto):

```gdscript
class_name PlayerStats
extends Resource

@export var move_speed: float = 320.0
@export var acceleration_time: float = 0.1
@export var friction_time: float = 0.1

@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 2.0

@export var block_speed_multiplier: float = 0.4

@export var block_knockback_speed: float = 250.0
@export var block_shake_intensity: float = 4.0

@export var parry_window: float = 0.15              # s, ventana de parry perfecto desde que arranca BLOCK
@export var parry_damage_multiplier: float = 2.0     # multiplicador de daño del proyectil reflejado
@export var parry_slowmo_scale: float = 0.15         # Engine.time_scale durante el slowmo del parry
@export var parry_slowmo_duration: float = 0.25      # s reales (no escalados) que dura el slowmo
```

**`data/player_stats.tres`**: agregar los 4 campos nuevos (conservando los 9 previos: `move_speed`, `acceleration_time`, `friction_time`, `dash_speed`, `dash_duration`, `dash_cooldown`, `block_speed_multiplier`, `block_knockback_speed`, `block_shake_intensity`).

**`entities/projectile/projectile_data.gd`** (1 campo nuevo, resto intacto):

```gdscript
class_name ProjectileData
extends Resource

@export var speed: float = 400.0
@export var lifetime: float = 3.0
@export var parryable: bool = true
@export var damage: float = 10.0   # daño base; sin receptor real todavía (falta HealthComponent, 2.1)
```

**`data/projectile_data.tres`**: agregar `damage = 10.0` (conservando `speed`, `lifetime`, `parryable`).

**`entities/projectile/projectile.gd`** (var runtime + método nuevo; `launch()`/`_physics_process` casi intactos):

```gdscript
class_name Projectile
extends CharacterBody2D

@export var stats: ProjectileData

var _lifetime_left: float = 0.0
var damage: float = 0.0

func launch(direction: Vector2) -> void:
	velocity = direction.normalized() * stats.speed
	_lifetime_left = stats.lifetime
	damage = stats.damage

func reflect(multiplier: float) -> void:
	velocity = -velocity
	damage *= multiplier
	set_collision_mask_value(3, true)   # capa "enemies" — para impactar contra el TrainingDummy al volver

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

**`entities/player/player.tscn`** (nuevo nodo, mismo nivel que `DashTimer`/`DashCooldownTimer`):

```
[node name="ParryWindowTimer" type="Timer" parent="."]
one_shot = true
```

**`entities/player/player.gd`** (var `@onready` nueva + cambios en `_physics_process`/handler; resto intacto):

```gdscript
@onready var parry_window_timer: Timer = $ParryWindowTimer

func _physics_process(delta: float) -> void:
	# ... (dash, sin cambios) ...

	var was_blocking := is_blocking
	is_blocking = Input.is_action_pressed("block") and has_disc and not is_invulnerable
	if is_blocking and not was_blocking:
		parry_window_timer.start(stats.parry_window)
	shield_hitbox.monitoring = is_blocking

	# ... (resto de _physics_process, sin cambios) ...

func _on_shield_hitbox_body_entered(body: Node2D) -> void:
	if body is Projectile and body.stats.parryable:
		if not parry_window_timer.is_stopped():
			body.reflect(stats.parry_damage_multiplier)
			Juice.slowmo(stats.parry_slowmo_scale, stats.parry_slowmo_duration)
			Juice.flash_sprite(sprite)
			EventBus.disc_blocked.emit(true)
		else:
			velocity = body.velocity.normalized() * stats.block_knockback_speed
			Juice.shake(stats.block_shake_intensity)
			body.block()
```

**`autoload/juice.gd`** (`slowmo()` y `flash_sprite()` reales; `shake()` sin cambios, `hit_stop()` sigue `pass`):

```gdscript
extends Node

func shake(intensity: float) -> void:
	# ... sin cambios (spec 14) ...

func hit_stop(duration: float) -> void:
	pass

func slowmo(scale: float, duration: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, false, false, true).timeout
	Engine.time_scale = 1.0

func flash_sprite(sprite: CanvasItem) -> void:
	var original_modulate := sprite.modulate
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color("#00f0ff"), 0.05)
	tween.tween_property(sprite, "modulate", original_modulate, 0.15)
```

Convenciones:

- `Projectile.damage` es runtime, copiado de `stats.damage` en `launch()`: `reflect()` multiplica esa var, nunca `stats.damage` (el `Resource` `.tres` es compartido por todas las instancias que use el mismo `TrainingDummy`; mutarlo corrompería el valor base para el resto).
- `parry_window_timer` sigue el mismo patrón que `dash_timer`: `one_shot = true`, se reinicia con `.start(wait_time)` en cada flanco de subida de `is_blocking`; al agotarse solo (comportamiento nativo de `Timer` `one_shot`), `is_stopped()` pasa a `true` y la ventana se considera cerrada sin lógica adicional.
- `flash_sprite()` guarda `sprite.modulate` original antes de tintar (no asume `Color.WHITE` fijo), por si un sprite ya tuviera otro tinte activo (ej. el flicker de dash en `is_invulnerable`); en la práctica hoy siempre es blanco, pero evita una asunción frágil.
- `Juice.slowmo()` usa `get_tree().create_timer(duration, false, false, true)` con `ignore_time_scale = true` para que la duración del propio efecto no se alargue por el `time_scale` reducido que acaba de aplicar.

## Implementation plan

1. En `entities/player/player_stats.gd`, agregar `parry_window`, `parry_damage_multiplier`, `parry_slowmo_scale`, `parry_slowmo_duration`.
2. Abrir `data/player_stats.tres` en el editor y setear los 4 campos nuevos (confirmar que los 9 previos siguen intactos).
3. En `entities/projectile/projectile_data.gd`, agregar `@export var damage: float = 10.0`.
4. Abrir `data/projectile_data.tres` en el editor y setear `damage = 10.0` (confirmar que `speed`, `lifetime`, `parryable` siguen intactos).
5. En `entities/projectile/projectile.gd`, agregar `var damage: float = 0.0`, copiarla desde `stats.damage` en `launch()`, y agregar el método `reflect(multiplier)`.
6. En `entities/player/player.tscn`, agregar el nodo `ParryWindowTimer` (`Timer`, `one_shot = true`) como hijo de `Player`.
7. En `entities/player/player.gd`, agregar `@onready var parry_window_timer`, el flanco de detección `is_blocking` `false → true` que llama `.start(stats.parry_window)`, y modificar `_on_shield_hitbox_body_entered` para ramificar entre parry perfecto y bloqueo normal.
8. En `autoload/juice.gd`, implementar `slowmo(scale, duration)` real con `Engine.time_scale` + timer real-time (`ignore_time_scale = true`).
9. En `autoload/juice.gd`, implementar `flash_sprite(sprite)` real con `Tween` sobre `modulate`.
10. F6 `test_arena.tscn`: con disco en mano, presionar y **mantener** `block` (Left Shift) justo cuando un proyectil `parryable` esté a punto de entrar en `ShieldHitbox` (dentro de los primeros ~0.15s de bloqueo) → confirmar que el proyectil **no** se destruye, invierte su trayectoria, el juego entra en slowmo brevemente, el sprite del `Player` destella cian, y no hay knockback ni shake.
11. F6: repetir dejando pasar más de 0.15s de `block` sostenido antes de que el proyectil llegue → confirmar que el comportamiento es el bloqueo normal de spec 14 (destruye, knockback, shake, sin slowmo ni flash).
12. F6: verificar que el proyectil reflejado, si su trayectoria de vuelta cruza al `TrainingDummy` que lo disparó, colisiona contra él y se destruye ahí (en vez de atravesarlo).
13. F6: agregar un `print()` temporal en `reflect()` (o revisar en pestaña "Remote") confirmando que `damage` se duplica correctamente (`10.0 → 20.0` con los defaults) tras un parry perfecto. Retirar el `print()` al terminar.
14. F6: repetir varios parries perfectos consecutivos → confirmar que `Engine.time_scale` siempre vuelve a `1.0` al terminar cada slowmo (sin quedar "trabado" en cámara lenta) y que el flash de sprite no se acumula ni deja el sprite tintado permanentemente.
15. Confirmar en consola: sin errores (en particular, ningún acceso a `body` inválido tras `reflect()`, que no llama `queue_free()`).
16. Marcar el spec como `Implemented` (no hay tarea en `docs/tasks.md` que marcar).

## Acceptance criteria

- [ ] `PlayerStats` tiene `parry_window` (`0.15`), `parry_damage_multiplier` (`2.0`), `parry_slowmo_scale` (`0.15`), `parry_slowmo_duration` (`0.25`) sin remover los 9 campos previos.
- [ ] `data/player_stats.tres` tiene los 4 campos nuevos seteados (y conserva `move_speed`, `acceleration_time`, `friction_time`, `dash_speed`, `dash_duration`, `dash_cooldown`, `block_speed_multiplier`, `block_knockback_speed`, `block_shake_intensity`).
- [ ] `ProjectileData` tiene `damage` (`float`, default `10.0`) sin remover `speed`, `lifetime`, `parryable`; `data/projectile_data.tres` tiene los 4 campos.
- [ ] `Projectile` tiene una var runtime `damage` copiada de `stats.damage` en `launch()`; `reflect(multiplier)` la multiplica sin tocar `stats.damage` (el `Resource` compartido queda intacto tras cualquier cantidad de reflejos).
- [ ] `Player` tiene un `ParryWindowTimer` (`Timer`, `one_shot = true`) que se reinicia (`.start(stats.parry_window)`) cada vez que `is_blocking` pasa de `false` a `true`.
- [ ] Un `Projectile` `parryable = true` que entra en `ShieldHitbox` **mientras `parry_window_timer` sigue corriendo** (dentro de los `parry_window` segundos desde que arrancó `BLOCK`): no se destruye, invierte `velocity` (`reflect()`), su `damage` runtime queda multiplicado por `parry_damage_multiplier`, gana la capa `enemies` en su `collision_mask`, se llama `Juice.slowmo(stats.parry_slowmo_scale, stats.parry_slowmo_duration)` y `Juice.flash_sprite(sprite)`, se emite `EventBus.disc_blocked(true)`, y **no** se aplica knockback al `Player` ni `Juice.shake()`.
- [ ] Un `Projectile` `parryable = true` que entra en `ShieldHitbox` **con `parry_window_timer` ya detenido** (fuera de la ventana): se comporta exactamente igual que spec 14 (destruye, knockback, `Juice.shake()`, `EventBus.disc_blocked(false)`), sin slowmo ni flash.
- [ ] `Juice.slowmo(scale, duration)` tiene una implementación real: al llamarla, `Engine.time_scale` cambia a `scale` y vuelve a `1.0` tras `duration` segundos reales (no escalados por el propio `time_scale`).
- [ ] `Juice.flash_sprite(sprite)` tiene una implementación real: al llamarla, `sprite.modulate` cambia brevemente hacia `#00f0ff` y vuelve a su valor original.
- [ ] `Juice.hit_stop()` sigue siendo `pass` (sin cambios); `Juice.shake()` sin cambios de comportamiento (spec 14).
- [ ] Un proyectil reflejado cuya trayectoria de vuelta cruza al `TrainingDummy` que lo disparó colisiona contra él y se destruye ahí (en vez de atravesarlo), sin ningún efecto de vida/HP.
- [ ] No se agrega `HealthComponent`, `HurtboxComponent`, HP en `TrainingDummy`, ni ninguna señal nueva a `EventBus` (`disc_blocked` ya existía con el parámetro `perfect`).
- [ ] No se agrega input/acción nueva al Input Map; la ventana se deriva únicamente del flanco de `is_blocking`.
- [ ] `docs/tasks.md` no se modifica.
- [ ] F6 en `test_arena.tscn`: los 5 escenarios del plan (parry dentro de ventana, bloqueo normal fuera de ventana, colisión del reflejo contra el dummy, daño duplicado verificado por print/Remote, slowmo/flash sin quedar "trabados" tras varios parries consecutivos) se comportan como se describe, sin errores en consola, repetible varias veces.

## Decisions

- **Sí:** ventana de parry derivada del flanco `is_blocking` `false→true` (`ParryWindowTimer`, `one_shot`, mismo patrón que `dash_timer`), no una acción/tap dedicado. _Razón: decisión del usuario — reusa el input sostenido de `BLOCK` ya existente (spec 12) sin agregar una acción nueva al Input Map ni distinguir "tap" de "hold" en el input._
- **Sí:** reflejo = `velocity = -velocity` (rebote 180° exacto), no redirección hacia el cursor ni hacia una referencia guardada del emisor. _Razón: decisión del usuario — es la lectura más simple ("se lo devuelvo por donde vino"); no acopla `Projectile` a `Player`/input ni requiere que guarde una referencia a su `TrainingDummy` emisor._
- **Sí:** `ProjectileData.damage` nuevo, pero sin ningún receptor real (`HealthComponent` no existe, tarea `2.1` sin hacer). _Razón: decisión del usuario — mantiene la convención anti-especulación del proyecto (spec 13: "`damage` no tiene consumidor hoy"); se verifica el ×2 solo por dato/print, sin adelantar HP a medias ni en el `Player` ni en el `TrainingDummy`._
- **Sí:** `Projectile.damage` como var runtime copiada en `launch()`, nunca mutando `stats.damage`. _Razón: `ProjectileData` es un `Resource` compartido entre todas las instancias que dispare un mismo `TrainingDummy` (spec 13); mutar el campo del `Resource` directamente corrompería el valor base para disparos futuros — bug clásico de Godot con `Resource` compartidos._
- **Sí:** el proyectil reflejado suma la capa `enemies` a su `collision_mask` (`set_collision_mask_value(3, true)`). _Razón: decisión del usuario — sin este cambio el reflejo atravesaría al `TrainingDummy` sin chocar (su mask actual es `walls`,`player`,`shield`), dejando el "reflejo" sin ninguna prueba visual; el cambio es solo en la instancia reflejada, no en el proyectil genérico ni en `projectile.tscn`._
- **Sí:** el parry perfecto anula el knockback y `Juice.shake()` de spec 14 (no se suman). _Razón: decisión del usuario — el feedback de "devolver el golpe" (slowmo + flash cian) es conceptualmente distinto al de "absorber el impacto" (recule + shake); combinarlos se sentía sobrecargado._
- **Sí:** `Juice.slowmo()` real ahora vía `Engine.time_scale` + `get_tree().create_timer(..., ignore_time_scale=true)`, adelantando una porción mínima de la tarea `1.9`. _Razón: mismo criterio que adelantar `Juice.shake()` en spec 14 — sin un efecto real, la verificación manual F6 no podría confirmar el feedback del parry; se acota a `slowmo()`+`flash_sprite()`, dejando `hit_stop()` como stub._
- **Sí:** `Juice.flash_sprite()` real ahora, aplicado al sprite del `Player` (no al `Disc`/`ShieldPivot`). _Razón: decisión del usuario — el `Disc` ya se tinta cian mientras `is_blocking` (spec 12); tintar además el `Player` distingue visualmente "estoy bloqueando" de "acabo de parryear perfecto"._
- **Sí:** `parry_window`, `parry_damage_multiplier`, `parry_slowmo_scale`, `parry_slowmo_duration` como campos de `PlayerStats`. _Razón: regla `CLAUDE.md` anti-números-mágicos, mismo patrón que `block_knockback_speed`/`block_shake_intensity` (spec 14) — son la recompensa por el timing del jugador, ajustables en el editor sin tocar código; `Juice` se mantiene genérico y reutilizable._
- **Sí:** `EventBus.disc_blocked.emit(true)` se llama directo desde `player.gd` en la rama de parry perfecto, sin tocar `Projectile.block()`. _Razón: `block()` acopla destrucción + señal; el parry no destruye el proyectil, así que emitir desde donde se decide "esto fue perfecto" es más simple que agregar una rama condicional dentro de `Projectile`._
- **No:** `parryable = false` forzado en el proyectil reflejado. _Razón: decisión del usuario — hoy nada más que el `Player` tiene `ShieldHitbox`; el campo no tiene consumidor nuevo, forzarlo sería lógica sin efecto observable._
- **No:** HP/vida en `TrainingDummy`, ni siquiera mínimo. _Razón: decisión del usuario — a diferencia de `Juice.shake()` en spec 14, esto sí tocaría terreno de la tarea `2.1` (sistema de vida); se prefiere dejar el ×2 como dato puro y verificarlo por print/Remote._
- **No:** detección de ángulo/cono frontal-espalda. _Razón: sin cambios respecto a spec 14 — "frontal" sigue siendo puramente geométrico vía `ShieldHitbox`._
- **No:** accesibilidad/toggle para reducir slowmo o flash. _Razón: fuera de alcance — pertenece a un sistema de settings de Fase 4 que todavía no existe; se agregaría ahí cuando llegue, sin tocar `Juice.slowmo()`/`flash_sprite()` de esta spec._
- **No:** marcar `docs/tasks.md`. _Razón: no hay tarea explícita para "parry perfecto" en el plan; mismo criterio que specs 06/12/13/14._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                                                                                                                       | Mitigación                                                                                                                                                                                                                                                                                                        |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Engine.time_scale` es global: si un parry ocurre mientras otro sistema (ej. un `Tween`/`Timer` que no ignora `time_scale`) está en curso, ese sistema también se ralentiza durante `parry_slowmo_duration` — incluido el `FireTimer` del `TrainingDummy` o el propio `Tween` de `Juice.shake()`/`flash_sprite()` si se solapan.                                                                                             | No bloqueante: es el comportamiento esperado de un "bullet time" arcade (todo se ralentiza, no solo el enemigo); si en playtesting algún `Tween` de VFX se siente "chicloso" al solaparse con slowmo, se ajusta puntualmente con `ignore_time_scale` en ese `Tween`, sin cambiar el contrato de `Juice.slowmo()`. |
| Dos parries perfectos muy seguidos (parry, dash-cancela-block, vuelve a parryar) podrían solapar dos llamadas a `Juice.slowmo()`, cada una con su propio timer real-time restaurando `Engine.time_scale = 1.0` al terminar — la segunda podría "cortar" antes de tiempo el slowmo de la primera si sus duraciones no calzan.                                                                                                 | No bloqueante para esta spec: el `fire_interval` del `TrainingDummy` (2s) hace este solape muy improbable en pruebas manuales; si se nota en combate real con más proyectiles, se resuelve centralizando el estado de slowmo en `Juice` (ej. un solo timer que se reinicia) sin cambiar la firma de `slowmo()`.   |
| El proyectil reflejado ganando la capa `enemies` en su `collision_mask` es un cambio de estado silencioso (no hay ningún flag visible tipo `is_reflected`); si una spec futura necesita distinguir "proyectil enemigo original" de "reflejado por el jugador" (ej. para no dañar al propio `TrainingDummy` con daño no-letal, o para VFX distintos), tendrá que inferirlo del `collision_mask` en vez de un campo explícito. | No bloqueante: no hay ningún requisito hoy de distinguirlos más allá de la colisión; si aparece esa necesidad, se agrega un campo explícito (`is_reflected: bool`) en la spec que lo necesite, sin romper el contrato actual de `reflect()`.                                                                      |
| Sin `HealthComponent`, el ×2 de daño en el proyectil reflejado no tiene ninguna consecuencia visible más allá de un número en runtime — la verificación F6 depende de `print()`/"Remote", que es menos convincente que ver algo "morir" en menos golpes.                                                                                                                                                                     | No bloqueante: aceptado explícitamente por el usuario (mismo criterio que spec 13/14 con daño al jugador); la tarea `2.1` conectará este valor a un receptor real sin tocar `projectile.gd`.                                                                                                                      |

## What is **not** in this spec

- `HealthComponent`/`HurtboxComponent`, HP en `TrainingDummy`, y cualquier consumo real de `damage`.
- Detección de ángulo/cono frontal-espalda explícita.
- Tap/input dedicado para el parry (usa el flanco de `is_blocking`).
- Redirección del reflejo hacia el cursor o hacia el emisor (solo `-velocity`).
- Forzar `parryable = false` en el proyectil reflejado.
- Accesibilidad / toggle de reducción de efectos.
- SFX del parry.
- Partículas, estela, u otro VFX más allá del flash de sprite (`Juice.hit_stop()` sigue stub).
- Controles táctiles.
- Cambios a `docs/tasks.md`.
- Cambios a `disc.gd`.

Cada una de estas, si llega, tendrá su propia spec.
