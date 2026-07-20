# SPEC 18 — Juice v1: estela del disco, SFX placeholder (5 eventos), shake leve al rebotar

> **Status:** Implementado
> **Depends on:** [01-autoloads-base.md](01-autoloads-base.md), [08-disc-fsm-lanzamiento.md](08-disc-fsm-lanzamiento.md), [09-rebote-disco-paredes.md](09-rebote-disco-paredes.md), [14-bloqueo-frontal-knockback-shake.md](14-bloqueo-frontal-knockback-shake.md), [15-parry-perfecto-reflejo-slowmo.md](15-parry-perfecto-reflejo-slowmo.md)
> **Date:** 2026-07-20
> **Objective:** Agregar una estela de partículas (`CPUParticles2D`) al disco mientras vuela/retorna, cablear `AudioManager.play_sfx(id)` a los 5 eventos de disco (lanzar/rebotar/recoger/bloquear/parry) y `Juice.shake()` a un nuevo shake leve al rebotar — todo disparado por `AudioManager`/`Juice` suscribiéndose ellos mismos a `EventBus` (sin que `disc.gd`/`player.gd` llamen nada nuevo), salvo la estela, que vive como nodo hijo de `Disc` controlado directamente por `disc.gd` por necesitar seguimiento continuo de posición.

## Scope

**In:**

- `entities/disc/disc_stats.gd`: agregar `@export var bounce_shake_intensity: float = 2.0`.
- `data/disc_stats.tres`: setear `bounce_shake_intensity = 2.0` (conservando los 7 campos previos).
- `autoload/event_bus.gd`: modificar la firma de `disc_bounced` para agregar un 3er parámetro: `signal disc_bounced(position: Vector2, bounces_left: int, shake_intensity: float)`. Nadie más escucha esta señal hoy (verificado), así que el cambio es seguro.
- `entities/disc/disc.gd`:
  - En la rama de rebote de `_physics_process`, actualizar el `emit` a `EventBus.disc_bounced.emit(collision.get_position(), bounces_left, stats.bounce_shake_intensity)`.
  - Agregar `@onready var trail: CPUParticles2D = $Trail`.
  - En `throw()`: `trail.emitting = true`.
  - En `_return_to_held()`: `trail.emitting = false`.
- `entities/disc/disc.tscn`: agregar nodo `Trail` (`CPUParticles2D`, hijo de `Disc`), `emitting = false` por defecto, sin textura (quad blanco tintado), color cian `#00f0ff` con alpha, `local_coords = false` (para que las partículas queden fijas en el mundo y formen estela, en vez de seguir al disco).
- `autoload/juice.gd`: en `_ready()`, conectar `EventBus.disc_bounced` a un handler que llama `shake(shake_intensity)`. `hit_stop()`, `slowmo()`, `flash_sprite()` sin cambios.
- `autoload/audio_manager.gd`: en `_ready()`, conectar `EventBus.disc_thrown`, `disc_bounced`, `disc_caught`, `disc_blocked` a handlers que llaman `play_sfx(id)` con los ids `"throw"`, `"bounce"`, `"catch"`, y `"parry"`/`"block"` (según el bool `perfect` de `disc_blocked`). `play_sfx()` **sigue siendo `pass`** (sin reproducción real todavía).
- Verificación manual en `test_arena.tscn` (F6): confirmar visualmente la estela y, por consola/breakpoint, que `play_sfx()` recibe el id correcto en cada uno de los 5 eventos.

**Out of scope (para specs futuras):**

- Assets de audio reales (`.ogg`) o tonos sintéticos placeholder — `play_sfx()` sigue sin sonido audible; eso llega en la tarea `4.6` ("pase completo de SFX").
- Implementación real de `Juice.hit_stop()` — sigue `pass`.
- Cambios a `Juice.slowmo()`/`Juice.flash_sprite()` o a las llamadas directas ya existentes en `player.gd` para el shake/slowmo/flash de bloqueo y parry (specs 14/15) — no se tocan.
- Escalado de intensidad de shake según el número de rebote restante (`bounces_left`) — shake fijo, mismo valor en todos los rebotes.
- Toggle de accesibilidad para reducir shake/partículas (`reduce_effects` de `CLAUDE.md`) — Fase 5.6, mismo criterio que spec 17.
- GPUParticles2D o Line2D como alternativa a la estela — se descartó, `CPUParticles2D` decidido.
- Cualquier VFX/SFX de combate (daño, muerte de enemigo, hit-stop) — Fase 2.
- Nuevas señales en `EventBus` más allá de agregar el parámetro `shake_intensity` a `disc_bounced`.

## Data model

**`entities/disc/disc_stats.gd`** (campo nuevo):

```gdscript
class_name DiscStats
extends Resource

@export var fly_speed: float = 900.0
@export var max_bounces: int = 2
@export var return_speed: float = 700.0
@export var return_turn_rate: float = 4.0
@export var catch_radius: float = 20.0
@export var flight_timeout: float = 4.0
@export var aim_preview_max_distance: float = 1500.0
@export var bounce_shake_intensity: float = 2.0   # px, shake leve de Juice al rebotar (tarea 1.9)
```

**`data/disc_stats.tres`**: se agrega `bounce_shake_intensity = 2.0`, conservando los 7 campos previos.

**`autoload/event_bus.gd`** (solo `disc_bounced` cambia):

```gdscript
signal disc_bounced(position: Vector2, bounces_left: int, shake_intensity: float)
```

**`entities/disc/disc.gd`** (cambios sobre el archivo existente):

```gdscript
@onready var trail: CPUParticles2D = $Trail

func throw(direction: Vector2) -> void:
	var origin := global_position
	reparent(get_tree().current_scene, false)
	global_position = origin
	state = State.FLYING
	velocity = direction.normalized() * stats.fly_speed
	bounces_left = stats.max_bounces + int(GameState.get_stat("disc_bounces"))
	flight_time = 0.0
	trail.emitting = true
	EventBus.disc_thrown.emit(origin, direction)

# ... dentro de _physics_process, rama FLYING con colisión y bounces_left > 0:
			EventBus.disc_bounced.emit(collision.get_position(), bounces_left, stats.bounce_shake_intensity)

func _return_to_held() -> void:
	state = State.RETURNING
	velocity = Vector2.ZERO
	reparent(held_parent, false)
	position = held_position
	rotation = 0.0
	state = State.HELD
	trail.emitting = false
	EventBus.disc_caught.emit()
```

**`entities/disc/disc.tscn`** (nodo nuevo, hijo de `Disc`):

```
[node name="Trail" type="CPUParticles2D" parent="."]
emitting = false
amount = 20
lifetime = 0.35
local_coords = false
direction = Vector2(0, 0)
spread = 180.0
gravity = Vector2(0, 0)
initial_velocity_min = 0.0
initial_velocity_max = 0.0
scale_amount_min = 8.0
scale_amount_max = 10.0
scale_amount_curve = SubResource("Curve_trail_scale")   # 1.0 → 0.0 sobre la vida de la partícula
color_ramp = SubResource("Gradient_trail_fade")          # cian opaco → transparente
```

> **Nota post-verificación (paso 7):** los valores originales (`scale_amount_min/max = 0.3/0.5`, color fijo) resultaban en un quad sub-píxel, invisible en pantalla. Decisión del usuario durante la verificación F6: subir la escala a un rango visible (8.0–10.0) y agregar `scale_amount_curve`/`color_ramp` para un look de "estela de misil" (se achica y desvanece), manteniendo `CPUParticles2D` sin textura y color cian — sin cambiar ninguna decisión arquitectónica del spec.

**`autoload/juice.gd`** (agregar `_ready()`; `shake()`/`hit_stop()`/`slowmo()`/`flash_sprite()` sin cambios en su cuerpo):

```gdscript
func _ready() -> void:
	EventBus.disc_bounced.connect(_on_disc_bounced)

func _on_disc_bounced(_position: Vector2, _bounces_left: int, shake_intensity: float) -> void:
	shake(shake_intensity)
```

**`autoload/audio_manager.gd`** (agregar `_ready()` y handlers; `play_sfx()` sigue `pass`):

```gdscript
func _ready() -> void:
	EventBus.disc_thrown.connect(func(_origin, _direction): play_sfx("throw"))
	EventBus.disc_bounced.connect(func(_position, _bounces_left, _shake_intensity): play_sfx("bounce"))
	EventBus.disc_caught.connect(func(): play_sfx("catch"))
	EventBus.disc_blocked.connect(_on_disc_blocked)

func _on_disc_blocked(perfect: bool) -> void:
	play_sfx("parry" if perfect else "block")
```

Convenciones:

- `Juice` y `AudioManager` se suscriben a `EventBus` en su propio `_ready()` — ninguna otra escena/script necesita conectar nada ni llamar a `Juice`/`AudioManager` para este spec (a diferencia de `Juice.shake()`/`slowmo()`/`flash_sprite()` en `player.gd`, que siguen siendo llamadas directas de specs anteriores y no se tocan).
- `Trail` es un nodo hijo de `Disc`, gestionado por `disc.gd` directamente (mismo criterio que `AimPreview` en spec 16): sigue al disco en cada reparent sin lógica extra, y su encendido/apagado son solo 2 líneas dentro de funciones ya existentes.
- `local_coords = false` en `Trail` para que las partículas queden ancladas en coordenadas de mundo y formen una estela real detrás del disco en movimiento, en vez de reposicionarse junto con el nodo padre.

## Implementation plan

1. En `entities/disc/disc_stats.gd`, agregar `@export var bounce_shake_intensity: float = 2.0`.
2. Abrir `data/disc_stats.tres` y setear `bounce_shake_intensity = 2.0` (confirmar que los 7 campos previos siguen intactos).
3. En `autoload/event_bus.gd`, cambiar la firma de `disc_bounced` a `signal disc_bounced(position: Vector2, bounces_left: int, shake_intensity: float)`.
4. En `entities/disc/disc.gd`, actualizar el único `emit` de `disc_bounced` para pasar `stats.bounce_shake_intensity` como 3er argumento.
5. En `entities/disc/disc.tscn`, agregar el nodo `Trail` (`CPUParticles2D`, hijo de `Disc`) con la configuración de la sección "Data model".
6. En `entities/disc/disc.gd`, agregar `@onready var trail: CPUParticles2D = $Trail`, y `trail.emitting = true`/`false` en `throw()`/`_return_to_held()` respectivamente.
7. F6 `test_arena.tscn`: lanzar el disco y confirmar que aparece una estela cian detrás mientras vuela; confirmar que la estela deja de emitir apenas el disco es recogido (`disc_caught`).
8. En `autoload/juice.gd`, agregar `_ready()` con la conexión a `EventBus.disc_bounced` → `shake(shake_intensity)`.
9. F6: lanzar el disco contra una pared del perímetro y confirmar un shake de cámara leve (más sutil que el del bloqueo) en cada rebote, sin afectar el shake existente de bloqueo/parry.
10. En `autoload/audio_manager.gd`, agregar `_ready()` con las 4 conexiones (`disc_thrown`, `disc_bounced`, `disc_caught`, `disc_blocked`) y sus handlers, según la sección "Data model".
11. F6: usando un breakpoint o un `print()` temporal dentro de `play_sfx()` (revertido antes de terminar), confirmar que se recibe el id correcto en cada uno de los 5 eventos: `"throw"` al lanzar, `"bounce"` en cada rebote, `"catch"` al recuperar, `"block"` en bloqueo normal, `"parry"` en parry perfecto.
12. Confirmar en consola: sin errores en ningún escenario anterior, repetible varias veces (lanzar/rebotar/recoger/bloquear/parry en cualquier orden).
13. Marcar la tarea `1.9` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [x] `entities/disc/disc_stats.gd` (`DiscStats`) tiene el campo `bounce_shake_intensity` (`float`, default `2.0`), sin remover los 7 campos previos.
- [x] `data/disc_stats.tres` tiene `bounce_shake_intensity = 2.0` y conserva los 7 campos previos.
- [x] `EventBus.disc_bounced` tiene la firma `(position: Vector2, bounces_left: int, shake_intensity: float)`.
- [x] `entities/disc/disc.gd` emite `disc_bounced` pasando `stats.bounce_shake_intensity` como 3er argumento.
- [x] `entities/disc/disc.tscn` tiene el nodo `Trail` (`CPUParticles2D`, hijo de `Disc`), `emitting = false` por defecto, `local_coords = false`, color `#00f0ff`.
- [x] Al lanzar el disco (`throw()`): `trail.emitting` pasa a `true` y se ve una estela cian detrás del disco mientras vuela/retorna.
- [x] Al recuperar el disco (`_return_to_held()`): `trail.emitting` pasa a `false` y la estela deja de emitir.
- [x] `autoload/juice.gd` tiene `_ready()` conectado a `EventBus.disc_bounced`; cada rebote dispara `Juice.shake(bounce_shake_intensity)` (shake más sutil que el de bloqueo, que sigue en `4.0`).
- [x] `Juice.hit_stop()`, `Juice.slowmo()`, `Juice.flash_sprite()` y las llamadas directas existentes en `player.gd` (bloqueo/parry) siguen sin cambios de comportamiento.
- [x] `autoload/audio_manager.gd` tiene `_ready()` conectado a `disc_thrown`, `disc_bounced`, `disc_caught` y `disc_blocked`; cada uno llama `play_sfx()` con el id correcto (`"throw"`, `"bounce"`, `"catch"`, `"block"`/`"parry"` según el bool `perfect`).
- [x] `play_sfx()` sigue siendo `pass` (sin reproducción de audio real) — el placeholder es el cableado, no el sonido.
- [x] No se agrega ninguna señal nueva a `EventBus` más allá de extender la firma de `disc_bounced`.
- [x] No se modifica `player.gd` ni las llamadas directas a `Juice`/`EventBus.disc_blocked` que ya existen ahí (specs 14/15).
- [x] F6 en `test_arena.tscn`: los escenarios del plan (estela visible al lanzar, estela desaparece al recoger, shake leve en cada rebote, ids correctos de SFX en los 5 eventos) se comportan como se describe, sin errores en consola, repetible varias veces.
- [x] `docs/tasks.md` tiene la tarea `1.9` marcada como `[x]`.

## Decisions

- **Sí:** `Juice`/`AudioManager` se suscriben ellos mismos a `EventBus` en su propio `_ready()`, sin que `disc.gd`/`player.gd` llamen nada nuevo para SFX/shake. _Razón: decisión del usuario — cumple al pie de la letra la regla de `CLAUDE.md` ("UI/audio/VFX escuchan el EventBus autoload; nunca referencian nodos de gameplay directamente"), a diferencia del patrón de llamada directa usado en specs 14/15 (que se deja intacto, no se retrofittea)._
- **No:** retrofittear las llamadas directas existentes en `player.gd` (`Juice.shake/slowmo/flash_sprite` de specs 14/15) al patrón de EventBus. _Razón: decisión del usuario — fuera de alcance, esas llamadas siguen funcionando y tocarlas no aporta a la tarea `1.9`; conviven ambos patrones (legado explícito + nuevo desacoplado) sin problema._
- **Sí:** la estela (`Trail`, `CPUParticles2D`) es un nodo hijo de `Disc`, controlado directamente por `disc.gd` (no vía `EventBus`/`Juice`). _Razón: decisión del usuario tras la aclaración técnica — la estela necesita seguir la posición continua del disco mientras vuela/retorna; las señales de `EventBus` son eventos puntuales, insuficientes para una estela cuadro a cuadro. Mismo criterio que `AimPreview` (spec 16): un nodo dedicado que lee/controla estado cada frame no pasa por EventBus._
- **Sí:** `CPUParticles2D` (no `GPUParticles2D` ni `Line2D`) para la estela. _Razón: decisión del usuario — más predecible y liviano en el renderer GL Compatibility y en web/móvil (RNF-5), y la tarea `1.9` pide explícitamente "partículas"._
- **Sí:** `Trail.local_coords = false`. _Razón: técnica — con `local_coords = true` (default de Godot) las partículas se recalculan junto con la transform del padre y no dejarían un rastro real; `false` las ancla en coordenadas de mundo, produciendo una estela visible detrás del disco en movimiento._
- **Sí:** ampliar la firma de `EventBus.disc_bounced` agregando `shake_intensity: float`, en vez de que `Juice` lea `disc.stats` directamente. _Razón: decisión técnica derivada de la elección de arquitectura — mantiene a `Juice` sin ninguna referencia a nodos de gameplay (ni siquiera de lectura), coherente con la regla de `CLAUDE.md`; el cambio es seguro porque hoy nadie más escucha `disc_bounced`._
- **Sí:** `AudioManager.play_sfx()` sigue como `pass` (sin reproducción real); esta spec solo cablea las 5 llamadas con sus ids. _Razón: decisión del usuario — no hay ningún asset de audio en el proyecto todavía (sin `.ogg`, sin carpeta `assets/audio`); generar tonos sintéticos ahora sería trabajo adicional no pedido por la tarea `1.9`, y la tarea `4.6` ya reserva explícitamente el "pase completo de SFX" con assets reales._
- **Sí:** nuevo stat `bounce_shake_intensity` en `DiscStats` (no un valor hardcodeado en `disc.gd`/`juice.gd`). _Razón: decisión del usuario — sigue la regla de `CLAUDE.md` "nada de números mágicos hardcodeados" y el mismo patrón que `block_shake_intensity` en `PlayerStats` (spec 14)._
- **Sí:** el shake de rebote (`2.0`) queda más sutil que el de bloqueo (`4.0`). _Razón: pedido explícito del usuario ("shake leve") al invocar el spec._
- **Sí:** ampliar el alcance de SFX a los 5 eventos (lanzar/rebotar/recoger/bloquear/parry), no solo los 3 que menciona literalmente la tarea `1.9` en `docs/tasks.md` (lanzar/rebotar/recoger). _Razón: pedido explícito del usuario al invocar `/spec`; es un superconjunto del texto de la tarea, así que igual se marca `[x]` al completarla (mismo criterio ya usado en specs previas que superan la redacción literal de una tarea)._
- **No:** implementar `Juice.hit_stop()`. _Razón: no pedido en este spec; sigue como stub hasta que una tarea futura lo requiera para verificación manual (mismo criterio que specs 14/15 con el resto de `Juice`)._
- **No:** toggle de accesibilidad para reducir shake/partículas (`reduce_effects`). _Razón: fuera de alcance — pertenece a un sistema de settings de Fase 5 (`5.6`) que todavía no existe, mismo criterio que la spec 17 con `aim_preview_enabled`._
- **No:** escalar la intensidad del shake según `bounces_left` u otro factor dinámico. _Razón: no pedido — "shake leve" fijo es suficiente para esta spec; ajustes de balance quedan para playtesting (tarea `5.5`)._

## Risks

| Riesgo                                                                                                                                                                                                                                                                                                                             | Mitigación                                                                                                                                                                                                                                             |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Juice.shake()` ahora se dispara en cada rebote del disco (antes solo en bloqueo), y su implementación actual crea un nuevo `Tween` por llamada sin cancelar tweens anteriores sobre `camera.offset`; rebotes muy seguidos (ej. contra una esquina) podrían solapar varios tweens y producir un shake más errático de lo esperado. | No bloqueante: mismo riesgo ya latente desde spec 14, solo se vuelve más frecuente; si se percibe en playtesting, se resuelve matando el tween anterior al inicio de `shake()` en una spec de ajuste, sin cambiar el contrato de esta spec.            |
| La estela (`CPUParticles2D` por disco) es trivial hoy, pero mejoras futuras como "disco doble" (tarea `3.4`) multiplicarían el número de sistemas de partículas activos simultáneamente.                                                                                                                                           | No bloqueante: 1 `CPUParticles2D` con `amount = 20` es insignificante en rendimiento incluso en web/móvil (RNF-5); si se vuelve perceptible con múltiples discos, se ajusta `amount`/`lifetime` en una spec de esa tarea, sin cambiar la arquitectura. |
| `AudioManager`/`Juice` se suscriben a `EventBus` en su propio `_ready()`; si en el futuro alguien reordena los autoloads en `project.godot` de forma que `EventBus` quede después de `AudioManager`/`Juice`, las conexiones fallarían silenciosamente (autoload aún no existe al momento de conectar).                             | No bloqueante hoy: el orden actual (`EventBus` primero) ya es correcto y no se toca en esta spec; queda documentado aquí como invariante a preservar.                                                                                                  |

## What is **not** in this spec

- Assets de audio reales (`.ogg`) o tonos sintéticos placeholder — `play_sfx()` sigue sin sonido audible.
- Implementación real de `Juice.hit_stop()`.
- Cambios a `Juice.slowmo()`/`Juice.flash_sprite()` o a las llamadas directas existentes en `player.gd` para bloqueo/parry (specs 14/15).
- Escalado de intensidad de shake según `bounces_left` u otro factor dinámico.
- Toggle de accesibilidad para reducir shake/partículas (`reduce_effects`).
- GPUParticles2D o Line2D como alternativa a la estela.
- VFX/SFX de combate (daño, muerte de enemigo, hit-stop) — Fase 2.
- Nuevas señales en `EventBus` más allá de extender la firma de `disc_bounced`.

Cada una de estas, si llega, tendrá su propia spec.
