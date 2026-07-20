# SPEC 19 — Números de daño flotantes (popup visual + EventBus, verificado con TrainingDummy)

> **Status:** Aprobado
> **Depends on:** [01-autoloads-base.md](01-autoloads-base.md), [08-disc-fsm-lanzamiento.md](08-disc-fsm-lanzamiento.md), [13-proyectil-generico-training-dummy.md](13-proyectil-generico-training-dummy.md), [18-juice-v1-estela-sfx-shake.md](18-juice-v1-estela-sfx-shake.md)
> **Date:** 2026-07-20
> **Objective:** Agregar `EventBus.damage_dealt(position, amount, is_crit)` y un popup de número flotante (`Label` con subida + desvanecimiento, spawneado por `Juice`) que aparece al golpear a un enemigo, verificado manualmente con `TrainingDummy` emitiendo un valor fijo (alternando crítico/normal) al ser golpeado por el disco, ya que el sistema de daño real (tarea `2.1`) todavía no existe.

## Scope

**In:**

- `autoload/event_bus.gd`: nuevo signal `damage_dealt(position: Vector2, amount: float, is_crit: bool)`.
- `entities/vfx/damage_number.tscn` + `entities/vfx/damage_number.gd` (nuevos): `Label` con animación de subida (`position.y` decrece) y desvanecimiento (`modulate.a` 1→0) vía `Tween`, ~0.6s, `queue_free()` al terminar. Color/tamaño normal vs crítico (blanco/cian vs rosa y más grande) según `is_crit`.
- `autoload/juice.gd`: en `_ready()`, conectar `EventBus.damage_dealt` a un handler que instancia `damage_number.tscn` en `get_tree().current_scene`, en la posición recibida, pasándole `amount`/`is_crit`.
- `entities/enemies/training_dummy.gd`: nuevo método `on_disc_hit()` que emite `EventBus.damage_dealt(global_position, 10.0, is_crit)` con un valor fijo (`10.0`), alternando `is_crit` en cada llamada (para verificar visualmente ambos estilos) — placeholder temporal, no es lógica de daño real.
- `entities/disc/disc.gd`: en la rama de colisión de `_physics_process`, si `collision.get_collider()` es `TrainingDummy`, llamar a `collider.on_disc_hit()`.
- Verificación manual en `test_arena.tscn` (F6): golpear el dummy repetidas veces con el disco y confirmar que aparecen números alternando normal/crítico, suben y se desvanecen, sin errores en consola.

**Out of scope (para specs futuras):**

- `HealthComponent`/`HurtboxComponent` real y cualquier cálculo de daño verdadero (tarea `2.1`) — el valor `10.0` es fijo y hardcodeado solo para esta spec.
- Campo `damage` en `DiscStats`/`ProjectileData` — no se agrega, no hay daño real que calcular todavía.
- Números flotantes para daño al jugador (`player_damaged`) — solo enemigos, según lo acordado.
- Pooling de nodos para los números — se usa `instantiate()`/`queue_free()` simple.
- Lógica real de crítico ligada a parry (`parry_damage_multiplier`, spec 15) — la alternancia de `is_crit` en `training_dummy.gd` es solo para verificar el estilo visual, no una regla de combate.
- `EnemyBase`/enemigos reales (tarea `2.2`) — el trigger vive en `TrainingDummy` porque es el único "enemigo" existente hoy.
- Elementos de HUD/UI de pantalla — el número vive en coordenadas de mundo, no en `ui/`.
- Toggle de accesibilidad para ocultar números de daño (`reduce_effects`) — Fase `5.6`, mismo criterio que specs 17/18.
- i18n — no aplica, son solo números.

## Data model

**`autoload/event_bus.gd`** (signal nuevo):

```gdscript
signal damage_dealt(position: Vector2, amount: float, is_crit: bool)
```

**`entities/vfx/damage_number.gd`** (nuevo):

```gdscript
class_name DamageNumber
extends Node2D

const RISE_DISTANCE := 40.0
const DURATION := 0.6

@onready var label: Label = $Label

func setup(amount: float, is_crit: bool) -> void:
	label.text = str(int(round(amount)))
	if is_crit:
		label.add_theme_color_override("font_color", Color("#ff2079"))
		label.add_theme_font_size_override("font_size", 28)
	else:
		label.add_theme_color_override("font_color", Color("#00f0ff"))
		label.add_theme_font_size_override("font_size", 18)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
	tween.tween_property(label, "modulate:a", 0.0, DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
```

**`entities/vfx/damage_number.tscn`** (nuevo, estructura mínima):

```
[node name="DamageNumber" type="Node2D"]
script = ExtResource("damage_number.gd")

[node name="Label" type="Label" parent="."]
horizontal_alignment = 1   # centrado
```

**`autoload/juice.gd`** (agregar en `_ready()`; resto sin cambios):

```gdscript
const DamageNumberScene := preload("res://entities/vfx/damage_number.tscn")

func _ready() -> void:
	EventBus.disc_bounced.connect(_on_disc_bounced)
	EventBus.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(position: Vector2, amount: float, is_crit: bool) -> void:
	var number: DamageNumber = DamageNumberScene.instantiate()
	get_tree().current_scene.add_child(number)
	number.global_position = position
	number.setup(amount, is_crit)
```

**`entities/enemies/training_dummy.gd`** (agregar sobre el archivo existente de spec 13):

```gdscript
var _next_hit_is_crit: bool = false

func on_disc_hit() -> void:
	EventBus.damage_dealt.emit(global_position, 10.0, _next_hit_is_crit)
	_next_hit_is_crit = not _next_hit_is_crit
```

**`entities/disc/disc.gd`** (cambio dentro de la rama de colisión de `_physics_process`):

```gdscript
var collision := move_and_collide(velocity * _delta)
if collision:
	var collider := collision.get_collider()
	if collider is TrainingDummy:
		collider.on_disc_hit()
	if bounces_left > 0:
		# ... resto sin cambios
```

Convenciones:

- `10.0` en `training_dummy.gd` es un valor fijo de verificación, no un stat de `DiscStats`/`ProjectileData` — no aplica la regla de "nada de números mágicos" de `CLAUDE.md` porque no es balance real, es un placeholder que la tarea `2.1` reemplaza.
- `_next_hit_is_crit` alterna en cada golpe solo para poder ver ambos estilos visuales en F6; no representa ninguna regla de combate real (parry, crítico, etc.).
- `Juice` sigue el mismo patrón de auto-suscripción a `EventBus` en `_ready()` que ya usa para `disc_bounced` (spec 18).

## Implementation plan

1. En `autoload/event_bus.gd`, agregar `signal damage_dealt(position: Vector2, amount: float, is_crit: bool)`.
2. Crear la carpeta `entities/vfx/` y el script `entities/vfx/damage_number.gd` con `class_name DamageNumber`, `setup(amount, is_crit)` (texto, color, tamaño) y el `Tween` de subida + desvanecimiento + `queue_free()`.
3. Crear `entities/vfx/damage_number.tscn`: nodo raíz `Node2D` con el script de DamageNumber, hijo `Label` centrado.
4. En `autoload/juice.gd`, agregar `const DamageNumberScene := preload(...)`, conectar `EventBus.damage_dealt` en `_ready()` y agregar `_on_damage_dealt()` que instancia, posiciona y llama `setup()`.
5. En `entities/enemies/training_dummy.gd`, agregar `var _next_hit_is_crit: bool = false` y `func on_disc_hit()` que emite `damage_dealt` con valor fijo `10.0` y alterna `_next_hit_is_crit`.
6. En `entities/disc/disc.gd`, dentro de la rama de colisión de `_physics_process`, detectar si `collision.get_collider()` es `TrainingDummy` y llamar `collider.on_disc_hit()`.
7. F6 `test_arena.tscn`: lanzar el disco contra el `TrainingDummy` y confirmar que aparece un número (`10`) sobre el dummy, sube y se desvanece en ~0.6s.
8. F6: golpear el dummy varias veces seguidas y confirmar que el color/tamaño alterna entre normal (cian, `10`) y crítico (rosa, más grande), sin superponerse de forma rota ni dejar nodos huérfanos.
9. F6: confirmar que golpear una pared normal (sin `TrainingDummy`) sigue rebotando el disco exactamente igual que antes (spec 09), sin ningún número flotante.
10. Confirmar en consola: sin errores, repetible varias veces (golpear dummy en cualquier momento del vuelo/retorno del disco).

## Acceptance criteria

- [ ] `autoload/event_bus.gd` tiene `signal damage_dealt(position: Vector2, amount: float, is_crit: bool)`.
- [ ] Existe `entities/vfx/damage_number.gd` (`class_name DamageNumber`) con `setup(amount, is_crit)` que fija texto, color y tamaño de fuente.
- [ ] Existe `entities/vfx/damage_number.tscn` (`Node2D` raíz + `Label` hijo) usando ese script.
- [ ] `autoload/juice.gd` conecta `EventBus.damage_dealt` en `_ready()` y, al recibirlo, instancia `DamageNumber` en `get_tree().current_scene`, en la posición recibida.
- [ ] El número instanciado sube (`position.y` decrece) y se desvanece (`modulate.a` → 0) en ~0.6s, y se libera (`queue_free()`) al terminar — no quedan nodos huérfanos acumulándose.
- [ ] Con `is_crit == false`: número en cian (`#00f0ff`), tamaño de fuente `18`.
- [ ] Con `is_crit == true`: número en rosa (`#ff2079`), tamaño de fuente `28` (mayor que el normal).
- [ ] `entities/enemies/training_dummy.gd` tiene `on_disc_hit()` que emite `damage_dealt(global_position, 10.0, _next_hit_is_crit)` y alterna `_next_hit_is_crit` en cada llamada.
- [ ] `entities/disc/disc.gd` llama `collider.on_disc_hit()` cuando `collision.get_collider()` es `TrainingDummy`, sin alterar la lógica existente de rebote/retorno.
- [ ] Golpear una pared del perímetro (no `TrainingDummy`) no dispara ningún número flotante ni llama `on_disc_hit()`.
- [ ] No se agrega ningún campo `damage` a `DiscStats` ni a `ProjectileData`.
- [ ] No se modifica `EventBus.player_damaged` ni ninguna lógica de daño al jugador.
- [ ] F6 en `test_arena.tscn`: los escenarios del plan (número visible al golpear el dummy, alternancia normal/crítico en golpes sucesivos, rebote en pared sin cambios, sin errores en consola) se comportan como se describe, repetible varias veces.

## Decisions

- **Sí:** esta spec solo construye el popup visual + `EventBus.damage_dealt`, verificado con un trigger placeholder — no construye `HealthComponent`/`HurtboxComponent`. _Razón: decisión del usuario — la tarea `2.1` no existe todavía; construirla completa aquí sería overengineering fuera del pedido original ("números de daño flotantes"). La conexión a daño real llega cuando `2.1` esté implementada, sin cambiar el contrato de `damage_dealt`._
- **No:** agregar cálculo de daño real disco→enemigo (`damage` en `DiscStats`, colisión con daño de verdad). _Razón: descartado por el usuario en favor de la opción "solo visual + signal"._
- **No:** posponer esta spec hasta que `2.1`/`2.2` existan. _Razón: descartado por el usuario — prefiere tener el componente visual listo y desacoplado ahora, conectable después._
- **Sí:** números flotantes solo para enemigos, no para el jugador. _Razón: decisión del usuario — `EventBus.player_damaged(hp: int)` queda intacto; evita decidir ahora si cambiar su firma para incluir el delta de daño._
- **Sí:** instanciar/destruir simple (`instantiate()` + `queue_free()`), sin pooling. _Razón: decisión del usuario — mismo criterio que la estela de disco (spec 18); con pocos enemigos simultáneos el costo es insignificante incluso en web/móvil (RNF-5)._
- **Sí:** `Juice` (autoload) escucha `damage_dealt` e instancia el popup, en vez de un manager nuevo. _Razón: decisión del usuario — mismo patrón de auto-suscripción a `EventBus` que ya usa `Juice`/`AudioManager` desde la spec 18; `Juice` ya es el autoload de game feel, no hace falta uno nuevo._
- **Sí:** la escena vive en `entities/vfx/damage_number.tscn` (carpeta nueva), no en `ui/`. _Razón: decisión del usuario — el número vive en coordenadas de mundo, no es un elemento de HUD; mismo criterio pragmático que `entities/projectile/` (tampoco estaba en el `design.md` original, se agregó según necesidad)._
- **Sí:** `TrainingDummy.on_disc_hit()` (llamado desde `disc.gd` al detectar la colisión) dispara la verificación, no una tecla de debug aparte. _Razón: decisión del usuario — se integra al flujo real de juego (golpear con el disco) en vez de un atajo desconectado del gameplay._
- **Sí:** `TrainingDummy` alterna `is_crit` en cada golpe. _Razón: decisión técnica derivada — necesario para poder verificar visualmente ambos estilos (normal/crítico) en F6; no representa ninguna regla de crítico real (eso es trabajo futuro de combate)._
- **Sí:** valor de daño fijo `10.0` hardcodeado en `training_dummy.gd`, no un campo de `Resource`. _Razón: es un placeholder de verificación, no balance real — crear un stat ahora sería trabajo que la tarea `2.1` va a reemplazar de todos modos; no aplica la regla de "nada de números mágicos" de `CLAUDE.md` porque no es un valor de balance persistente._
- **Sí:** blanco/cian (`#00f0ff`) para daño normal, rosa (`#ff2079`) y fuente mayor para crítico, ~0.6s de duración. _Razón: decisión del usuario — sigue la paleta synthwave de `CLAUDE.md`._
- **No:** modificar `disc.gd` más allá de detectar `TrainingDummy` y llamar `on_disc_hit()`. _Razón: mantener el cambio mínimo — cualquier lógica de daño real le compete a la tarea `2.1`, no a esta spec._
- **No:** toggle de accesibilidad para ocultar los números (`reduce_effects`). _Razón: fuera de alcance — pertenece a la Fase `5.6`, mismo criterio que specs 17/18._
- **No:** i18n de los números flotantes. _Razón: no aplica — son solo dígitos, sin texto traducible._

## Risks

| Riesgo                                                                                                                                                                                                                                                                             | Mitigación                                                                                                                                                                                                                                                                                                                            |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `disc.gd` puede llamar `on_disc_hit()` más de una vez por un mismo "golpe" si, tras rebotar, el disco vuelve a colisionar con el `TrainingDummy` en un frame físico siguiente (ej. rebote en un ángulo que lo devuelve hacia el dummy).                                            | No bloqueante: mismo comportamiento de colisión ya existente desde antes de esta spec (el rebote en el dummy funciona igual que en una pared); si se detecta en playtesting, se agrega un cooldown/flag de "invulnerabilidad de golpe" cuando exista `HealthComponent` real (tarea `2.1`), sin cambiar el contrato de `damage_dealt`. |
| `TrainingDummy.on_disc_hit()` es un hook placeholder que quedará obsoleto en cuanto la tarea `2.1`/`2.2` introduzca `HealthComponent`/`HurtboxComponent` reales — alguien podría olvidar removerlo y terminar con dos caminos de "daño" coexistiendo (el real y este placeholder). | No bloqueante: documentado aquí y en la sección de Decisions como placeholder explícito; la spec que implemente `2.1` debe reemplazar `on_disc_hit()` por el flujo real de `HurtboxComponent`, no agregarse encima.                                                                                                                   |
| Con múltiples enemigos golpeados casi al mismo tiempo (futuro, tarea `2.2`+), varios `DamageNumber` pueden instanciarse en posiciones muy cercanas y superponerse visualmente, volviéndose ilegibles.                                                                              | No bloqueante hoy: con un solo `TrainingDummy` no ocurre; si se vuelve perceptible con oleadas reales, se ajusta con un offset horizontal aleatorio o apilado vertical en una spec de esa tarea, sin cambiar la arquitectura de esta.                                                                                                 |

## What is **not** in this spec

- `HealthComponent`/`HurtboxComponent` real o cualquier cálculo de daño verdadero (tarea `2.1`).
- Campo `damage` en `DiscStats`/`ProjectileData`.
- Números flotantes para daño al jugador (`player_damaged`).
- Pooling de nodos para los números.
- Lógica real de crítico ligada a parry (`parry_damage_multiplier`, spec 15).
- `EnemyBase`/enemigos reales (tarea `2.2`).
- Elementos de HUD/UI de pantalla.
- Toggle de accesibilidad para ocultar números de daño (`reduce_effects`).
- i18n de los números.

Cada una de estas, si llega, tendrá su propia spec.
