# SPEC 01 — Autoloads base: EventBus, GameState, SaveManager, AudioManager, Juice

> **Status:** Implementado
> **Depends on:** —
> **Date:** 2026-07-14
> **Objective:** Crear el esqueleto de los 5 autoloads del proyecto (EventBus, GameState, SaveManager, AudioManager, Juice) con su API pública en stubs (señales declaradas, métodos sin lógica) y registrarlos en Project Settings.

## Scope

**In:**

- Crear `res://autoload/event_bus.gd` con las señales de EventBus (set completo v1.0).
- Crear `res://autoload/game_state.gd` con propiedades de estado de run y métodos stub.
- Crear `res://autoload/save_manager.gd` con métodos stub (sin I/O de archivos).
- Crear `res://autoload/audio_manager.gd` con métodos stub (sin pools ni assets reales).
- Crear `res://autoload/juice.gd` con métodos stub (sin lógica de shake/hit-stop/slowmo real).
- Registrar los 5 scripts como autoloads (singletons) en Project Settings → Autoload, con los nombres `EventBus`, `GameState`, `SaveManager`, `AudioManager`, `Juice`.
- Marcar la tarea `0.3` como `[x]` en `docs/tasks.md` al finalizar.

**Out of scope (for future specs):**

- Emisión real de señales desde jugador/disco/enemigos/oleadas (llegará con las specs de Fase 1-3).
- Lógica real de Juice (shake con trauma/decaimiento, `Engine.time_scale` para hit-stop/slowmo, shader de flash).
- Lectura/escritura real de `user://save.json` y su schema versionado.
- Pools de audio reales y assets `.ogg` (AudioManager solo define la interfaz).
- `UpgradeData`, `EnemyData`, etc. como `Resource` — `GameState.apply_upgrade()` recibirá el tipo cuando esas specs existan; por ahora se tipa genérico (sin tipo estricto, ya que la clase aún no existe).

## Data model

```gdscript
# res://autoload/event_bus.gd — EventBus
signal disc_thrown(origin: Vector2, direction: Vector2)
signal disc_bounced(position: Vector2, bounces_left: int)
signal disc_caught()
signal disc_recalled()
signal disc_blocked(perfect: bool)
signal enemy_died(enemy: Node2D)
signal player_damaged(hp: int)
signal player_died()
signal wave_started(wave_number: int)
signal wave_cleared(wave_number: int)
signal level_completed()
signal boss_phase_changed(phase: int)
signal upgrade_selected(upgrade_id: String)
signal combo_changed(mult: float)
signal currency_collected(amount: int)
```

```gdscript
# res://autoload/game_state.gd — GameState
var hp: int
var max_hp: int
var currency_run: int
var combo: int
var active_upgrades: Array = []

func get_stat(stat_name: String) -> float:
    return 0.0

func reset_run() -> void:
    pass

func add_currency(amount: int) -> void:
    pass

func apply_upgrade(upgrade_data) -> void:
    pass
```

```gdscript
# res://autoload/save_manager.gd — SaveManager
func save_game() -> void:
    pass

func load_game() -> void:
    pass

func has_save() -> bool:
    return false
```

```gdscript
# res://autoload/audio_manager.gd — AudioManager
func play_sfx(sfx_id: String) -> void:
    pass

func play_music(track_id: String) -> void:
    pass

func stop_music() -> void:
    pass

func set_sfx_volume(v: float) -> void:
    pass

func set_music_volume(v: float) -> void:
    pass
```

```gdscript
# res://autoload/juice.gd — Juice
func shake(intensity: float) -> void:
    pass

func hit_stop(duration: float) -> void:
    pass

func slowmo(scale: float, duration: float) -> void:
    pass

func flash_sprite(sprite: CanvasItem) -> void:
    pass
```

Convenciones:

- `apply_upgrade(upgrade_data)` queda sin tipo estricto porque `UpgradeData` (Resource) aún no existe; se tipará cuando su spec lo defina.
- `has_save()` devuelve `false` de forma fija (stub), no `pass`, porque el tipo de retorno `bool` lo exige.
- `get_stat()` devuelve `0.0` de forma fija (stub), no `pass`, por la misma razón: GDScript 4 trata "no todos los caminos retornan un valor" en una función con tipo de retorno explícito como error de parseo, no advertencia.

## Implementation plan

1. Crear `res://autoload/event_bus.gd` (`extends Node`) con las 15 señales declaradas (sin lógica). El proyecto sigue abriendo sin errores.
2. Crear `res://autoload/game_state.gd` (`extends Node`) con las variables y los 4 métodos stub.
3. Crear `res://autoload/save_manager.gd` (`extends Node`) con los 3 métodos stub.
4. Crear `res://autoload/audio_manager.gd` (`extends Node`) con los 5 métodos stub.
5. Crear `res://autoload/juice.gd` (`extends Node`) con los 4 métodos stub.
6. Registrar los 5 scripts en Project Settings → Autoload (sección `[autoload]` de `project.godot`), en este orden y con estos nombres: `EventBus`, `GameState`, `SaveManager`, `AudioManager`, `Juice`.
7. Abrir el proyecto en el editor de Godot y comprobar que no hay errores de parseo en el panel de salida; confirmar que los 5 nombres aparecen como singletons globales.
8. Marcar la tarea `0.3` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [x] Existen los 5 archivos: `res://autoload/event_bus.gd`, `game_state.gd`, `save_manager.gd`, `audio_manager.gd`, `juice.gd`.
- [x] `event_bus.gd` declara exactamente las 15 señales listadas en el modelo de datos, con esos nombres y parámetros.
- [x] `game_state.gd` expone las 5 variables (`hp`, `max_hp`, `currency_run`, `combo`, `active_upgrades`) y los 4 métodos stub.
- [x] `save_manager.gd` expone `save_game()`, `load_game()`, `has_save()` (este último retorna `false`).
- [x] `audio_manager.gd` expone los 5 métodos stub listados.
- [x] `juice.gd` expone los 4 métodos stub listados.
- [x] Project Settings → Autoload lista `EventBus`, `GameState`, `SaveManager`, `AudioManager`, `Juice` apuntando a sus scripts correspondientes.
- [x] El proyecto se abre y corre (F5 o ejecución de la escena principal) sin errores ni warnings de parseo en el panel de salida.
- [x] Desde cualquier script del proyecto, `EventBus`, `GameState`, `SaveManager`, `AudioManager` y `Juice` son accesibles como globales sin necesidad de `preload`/`get_node`.
- [x] `docs/tasks.md` tiene la tarea `0.3` marcada como `[x]`.

## Decisions

- **Sí:** los 5 autoloads son stub puro (sin lógica real), incluido Juice. _Razón: consistencia entre los 5; la lógica real de cada sistema merece su propia spec dedicada donde se pueda diseñar y probar correctamente._
- **No:** implementar ya `shake`/`hit_stop`/`slowmo` reales en Juice aunque sean autocontenidos. _Razón: mantener esta spec puramente como "esqueleto + registro"; evita mezclar decisiones de tuning (intensidad, curvas de decaimiento) con el trabajo de scaffolding._
- **Sí:** declarar las 15 señales del set completo v1.0 en EventBus desde ahora. _Razón: evita reabrir `event_bus.gd` en cada spec futura de Fase 1-3; el contrato de eventos queda fijado una sola vez._
- **Sí:** alinear nombres y firmas de `enemy_died`, `player_damaged`, `level_completed`, `combo_changed`/`currency_collected` y las variables de `GameState` (`hp`/`max_hp`/`currency_run`/`combo`) exactamente con `referencias-spec/01-fundaciones/design.md`. _Razón: esa carpeta se agregó como documentación de referencia del diseño original; se detectó desfase con la primera versión de esta spec y se corrigió para que ambas fuentes coincidan antes de que Fase 1-3 empiece a emitir estas señales._
- **Sí:** agregar `disc_blocked(perfect: bool)` aunque todavía no exista mecánica de bloqueo/escudo. _Razón: reserva el contrato de EventBus para cuando esa mecánica se implemente, evitando reabrir el archivo entonces._
- **Sí:** mantener `disc_bounced`, `disc_recalled`, `boss_phase_changed`, `upgrade_selected` aunque no aparezcan en `referencias-spec/01-fundaciones`. _Razón: son adiciones útiles (rebote del disco, recall, fases de jefe, mejoras) que no contradicen la referencia, solo la complementan._
- **No:** emitir señales desde algún método de debug en esta spec. _Razón: no hay jugador/disco/enemigos aún — emitir señales sin quien las escuche no aporta valor y añade código a borrar después._
- **No:** que `SaveManager` toque el sistema de archivos (`user://save.json`) en esta spec. _Razón: definir el schema JSON y su versionado merece su propia spec de persistencia; aquí solo se fija la interfaz pública._
- **Sí:** nombres de autoload y rutas de archivo exactamente como en `docs/design.md §2`. _Razón: consistencia con el documento de arquitectura ya aprobado._
- **No:** tipar estrictamente `apply_upgrade(upgrade_data)` con la clase `UpgradeData`. _Razón: esa clase `Resource` todavía no existe; forzar el tipo ahora rompería cuando se cree, o obligaría a adivinar su forma prematuramente._

## What is **not** in this spec

- Lógica real de Juice (shake con trauma/decaimiento, `Engine.time_scale`, shader de flash).
- Emisión real de las señales de EventBus desde jugador/disco/enemigos/oleadas.
- Lectura/escritura real de `user://save.json` y su schema versionado.
- Pools de audio reales, mezcla de capas de música, assets `.ogg`.
- Definición de `UpgradeData`, `EnemyData` u otros `Resource` de balance.

Cada uno de estos, cuando llegue, tendrá su propia spec.
