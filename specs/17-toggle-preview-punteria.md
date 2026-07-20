# SPEC 17 — Toggle de accesibilidad: activar/desactivar el preview de puntería

> **Status:** Aprobado
> **Depends on:** [16-preview-punteria-rebote.md](16-preview-punteria-rebote.md), [02-input-map-teclado-mouse.md](02-input-map-teclado-mouse.md), [01-autoloads-base.md](01-autoloads-base.md)
> **Date:** 2026-07-20
> **Objective:** Agregar un autoload `Settings` con el flag `aim_preview_enabled: bool = false` (no persistente, se resetea a `false` en cada sesión) y la acción de Input Map `toggle_aim_preview` (tecla `V`) para que el jugador active/desactive en caliente el preview de puntería de la spec 16, sin ningún indicador visual del estado.

## Scope

**In:**

- `autoload/settings.gd` (nuevo autoload): `extends Node` con `var aim_preview_enabled: bool = false`.
- `project.godot`: registrar el autoload `Settings="*res://autoload/settings.gd"` (sección `[autoload]`, mismo patrón que `EventBus`/`GameState`/`SaveManager`/`Juice`).
- `project.godot`: nueva acción de Input Map `toggle_aim_preview` con binding `V` (sección `[input]`).
- `entities/player/aim_preview.gd`: en `_physics_process`, al inicio, si `Input.is_action_just_pressed("toggle_aim_preview")` → `Settings.aim_preview_enabled = not Settings.aim_preview_enabled`.
- `entities/player/aim_preview.gd`: la condición que decide mostrar/ocultar los segmentos pasa de `player.has_disc and not player.is_blocking` a `Settings.aim_preview_enabled and player.has_disc and not player.is_blocking`.
- Verificación manual en `test_arena.tscn` (F6): confirmar que el preview arranca oculto por defecto, y que `V` lo activa/desactiva en caliente sin importar el estado de `has_disc`/`is_blocking` (el toggle solo habilita/deshabilita la posibilidad de que se muestre).

**Out of scope (para specs futuras):**

- Menú de ajustes real / UI de settings (Fase 4) — esto es solo la tecla directa, sin pantalla.
- Persistencia en disco del toggle (`SaveManager` real) — se resetea a `false` en cada apertura del juego.
- Otros toggles de accesibilidad (ej. `reduce_effects` de `CLAUDE.md`) — quedan para specs futuras; esta spec solo fija la convención de que crecen dentro de `Settings`, no los implementa.
- Cualquier indicador visual del estado del toggle (HUD, ícono, mensaje en pantalla) — ninguno, según lo acordado.
- Remapeo de la tecla `V` (RNF-5, UI de remapeo de Fase 4).
- Cambios a la lógica de raycast/rebote de la spec 16 (`_cast`, cálculo de segmentos) — solo se agrega la condición de habilitación.

## Data model

**`autoload/settings.gd`** (nuevo autoload):

```gdscript
extends Node

var aim_preview_enabled: bool = false   # toggle en caliente, no persistente (tarea futura de accesibilidad, CLAUDE.md)
```

**`project.godot`** (cambios de configuración, no código):

```
[autoload]
...
Settings="*res://autoload/settings.gd"

[input]
...
toggle_aim_preview={
"deadzone": 0.5,
"events": [InputEventKey con physical_keycode = KEY_V]
}
```

**`entities/player/aim_preview.gd`** (cambio sobre el archivo existente de la spec 16):

```gdscript
func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_aim_preview"):
		Settings.aim_preview_enabled = not Settings.aim_preview_enabled

	if not (Settings.aim_preview_enabled and player.has_disc and not player.is_blocking):
		segment1.visible = false
		segment2.visible = false
		return
	# resto sin cambios (spec 16)
```

Convenciones:

- `Settings` es un autoload global (como `EventBus`/`GameState`), accesible desde cualquier script sin `get_node`.
- El toggle se lee/escribe cada frame en `_physics_process` de `aim_preview.gd` — no se agrega ninguna señal nueva a `EventBus` (el toggle no necesita notificar a otros sistemas, solo afecta la visibilidad local del preview).
- `aim_preview_enabled` no se guarda en `SaveManager`; al reiniciar el juego vuelve a `false`.

## Implementation plan

1. Crear `autoload/settings.gd` con `var aim_preview_enabled: bool = false`.
2. Registrar `Settings="*res://autoload/settings.gd"` en `project.godot` (`[autoload]`).
3. Agregar la acción `toggle_aim_preview` (tecla `V`) en `project.godot` (`[input]`).
4. En `entities/player/aim_preview.gd`, agregar al inicio de `_physics_process` el toggle: `if Input.is_action_just_pressed("toggle_aim_preview"): Settings.aim_preview_enabled = not Settings.aim_preview_enabled`.
5. En `entities/player/aim_preview.gd`, actualizar la condición de visibilidad de `has_disc and not is_blocking` a `Settings.aim_preview_enabled and has_disc and not is_blocking`.
6. F6 `test_arena.tscn`: confirmar que al iniciar (con `has_disc = true`) el preview está **oculto** por defecto.
7. F6: presionar `V` y confirmar que el preview aparece; presionar `V` de nuevo y confirmar que se oculta.
8. F6: con el toggle activado, repetir los escenarios de la spec 16 (ocultamiento al bloquear/lanzar, reaparición al recuperar el disco) y confirmar que siguen funcionando igual.
9. F6: cerrar y reabrir el proyecto, confirmar que el toggle vuelve a `false` (no persiste).
10. Confirmar en consola: sin errores en ningún escenario.

Nota: no hay una tarea numerada en `docs/tasks.md` específica para este toggle (la tarea `5.6` de accesibilidad es más amplia — shake/flash/UI/remapeo — y todavía no corresponde marcarla completa por esto solo), así que este plan no incluye un paso de marcar `docs/tasks.md`.

## Acceptance criteria

- [ ] Existe `autoload/settings.gd` con `var aim_preview_enabled: bool = false`.
- [ ] `project.godot` registra el autoload `Settings` (`[autoload]`), sin remover `EventBus`/`GameState`/`SaveManager`/`AudioManager`/`Juice`.
- [ ] `project.godot` tiene la acción `toggle_aim_preview` con binding **V**, sin conflicto con las 9 acciones existentes (spec 02).
- [ ] Al presionar `toggle_aim_preview` (`V`), `Settings.aim_preview_enabled` alterna entre `true`/`false`.
- [ ] Con `aim_preview_enabled == false` (estado inicial por defecto): `Segment1` y `Segment2` quedan ocultos aunque `player.has_disc == true` y `player.is_blocking == false`.
- [ ] Con `aim_preview_enabled == true`: el preview se comporta exactamente igual que en la spec 16 (visible/oculto según `has_disc`/`is_blocking`, segmento 2 con rebote, fallback a `aim_preview_max_distance`).
- [ ] Al reiniciar el proyecto/juego, `aim_preview_enabled` vuelve a `false` (no persiste en `SaveManager` ni en disco).
- [ ] No aparece ningún indicador visual (HUD, texto, ícono) del estado del toggle.
- [ ] No se modifica la lógica de raycast/rebote de `aim_preview.gd` (`_cast`, cálculo de `end1`/`end2`) más allá de agregar la condición del toggle.
- [ ] No se agrega ninguna señal nueva a `EventBus`.
- [ ] F6 en `test_arena.tscn`: los escenarios del plan (oculto por defecto, toggle on/off con `V`, comportamiento idéntico a spec 16 cuando está activado, reset a `false` al reabrir) se comportan como se describe, sin errores en consola.

## Decisions

- **Sí:** tecla directa (`toggle_aim_preview` → `V`) en vez de esperar a un menú de ajustes real. _Razón: decisión del usuario — no existe UI de settings todavía (Fase 4), y una tecla resuelve el control inmediato sin bloquear la mejora hasta esa fase._
- **Sí:** el toggle no persiste entre sesiones (siempre arranca en `false`). _Razón: decisión del usuario — evita implementar persistencia real en `SaveManager` (hoy stub vacío) solo para este flag; se revisará si/cuando se construya el sistema de guardado real._
- **Sí:** nuevo autoload `Settings` (no una variable local en `aim_preview.gd`) para alojar el flag. _Razón: decisión del usuario — anticipa que otros toggles de accesibilidad (ej. `reduce_effects` de `CLAUDE.md`) van a converger ahí mismo, siguiendo el mismo patrón que `EventBus`/`GameState`/`SaveManager`/`Juice`, en vez de crear un autoload nuevo por cada flag futuro._
- **No:** agregar ya otros campos placeholder (ej. `reduce_effects`) al autoload `Settings`. _Razón: decisión del usuario (Opción A) — se fija la convención de dónde van a vivir, pero no se anticipa lógica no pedida todavía; cada toggle futuro llega con su propia spec._
- **No:** persistencia en disco vía `SaveManager`. _Razón: fuera de alcance — `SaveManager.save_game()`/`load_game()` son stubs sin implementación real; conectarlos es trabajo de otra spec._
- **No:** indicador visual del estado (HUD, ícono, texto en pantalla). _Razón: decisión del usuario — sin UI/HUD todavía, y no se pidió ninguno._
- **No:** UI de remapeo de la tecla `V`. _Razón: pertenece a RNF-5 / Fase 4, mismo criterio que spec 02._
- **No:** marcar ninguna tarea de `docs/tasks.md` al finalizar. _Razón: no existe una tarea numerada que corresponda exactamente a este toggle; la tarea `5.6` (accesibilidad) es más amplia y no debe marcarse completa por esto solo._

## Risks

| Riesgo                                                                                                                                                                                                                                       | Mitigación                                                                                                                                                                                   |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sin indicador visual, el jugador puede no saber que la tecla `V` existe y pensar que el preview "no funciona" si nunca la presiona.                                                                                                          | No bloqueante: esta spec decide explícitamente no mostrar indicador (fuera de alcance); se resuelve con onboarding/tutorial en una spec de UI futura si se detecta confusión en playtesting. |
| El flag `Settings.aim_preview_enabled` vive en un autoload, por lo que sobrevive a recargas de escena (F5 dentro del mismo proceso) y solo vuelve a `false` al cerrar y reabrir el juego — un jugador podría esperar que cada F5 lo resetee. | No bloqueante: comportamiento esperado de un autoload de Godot; documentado aquí para que no se interprete como bug durante QA.                                                              |

## What is **not** in this spec

- Menú de ajustes real / UI de settings (Fase 4).
- Persistencia en disco del toggle (`SaveManager` real).
- Otros toggles de accesibilidad (`reduce_effects`, etc.) — solo se fija la convención de dónde vivirán.
- Indicador visual del estado del toggle (HUD, ícono, texto).
- Remapeo de la tecla `V`.
- Cambios a la lógica de raycast/rebote de `aim_preview.gd` más allá de la condición de habilitación.

Cada una de estas, si llega, tendrá su propia spec.
