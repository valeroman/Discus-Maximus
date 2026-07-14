# SPEC 03 — Capas de física 2D: nombres y matriz de colisión

> **Status:** Aprobado
> **Depends on:** [01-autoloads-base.md](01-autoloads-base.md), [02-input-map-teclado-mouse.md](02-input-map-teclado-mouse.md)
> **Date:** 2026-07-14
> **Objective:** Nombrar las 7 capas de física 2D en Project Settings (`player`, `walls`, `enemies`, `player_disc`, `enemy_projectiles`, `pickups`, `shield`) y documentar la matriz de colisión (layer/mask) de referencia que usarán las escenas de Fase 1-2 cuando se creen.

## Scope

**In:**

- Definir en `project.godot` (sección `[layer_names]`, subsección `2d_physics`) los nombres de las 7 capas físicas:
  1. `player`
  2. `walls`
  3. `enemies`
  4. `player_disc`
  5. `enemy_projectiles`
  6. `pickups`
  7. `shield`
- Documentar en esta spec la matriz de colisión de referencia (qué `collision_layer`/`collision_mask` debe usar cada tipo de entidad cuando su escena se cree), para que las specs de Fase 1-2 (jugador, disco, paredes, enemigos, proyectiles, pickups) la apliquen sin tener que re-decidirla.
- Agregar la tarea `0.6` a `docs/tasks.md` (Fase 0) y marcarla `[x]` al finalizar esta spec.

**Out of scope (para specs futuras):**

- Crear o modificar cualquier escena (`.tscn`) o nodo con `CollisionShape2D`/`CollisionPolygon2D` — ninguna existe todavía (tareas 1.1-1.3 sin empezar).
- Asignar `collision_layer`/`collision_mask` reales en código o en el editor — se hará en cada spec de entidad (jugador, disco, paredes, enemigos, proyectiles, pickups, escudo del Warden) usando la matriz aquí documentada como referencia.
- Lógica de bloqueo/parry del jugador o del escudo del Warden — solo se reserva la capa `shield` para cuando esas mecánicas se implementen (Fase 1 disco/bloqueo, Fase 2 tarea `2.7` Warden).
- Capas de física 3D, capas de render (`layer_names/2d_render`), o grupos de nodos (`Node.groups`) — fuera de alcance, no relacionado con física.

## Data model

Esta spec no introduce estructuras de datos nuevas (no hay `Resource` ni clases) — solo modifica la sección `[layer_names]` de `project.godot` (configuración nativa de Godot) y documenta la matriz de colisión de referencia.

**Nombres de capas** (`project.godot`):

```ini
[layer_names]

2d_physics/1="player"
2d_physics/2="walls"
2d_physics/3="enemies"
2d_physics/4="player_disc"
2d_physics/5="enemy_projectiles"
2d_physics/6="pickups"
2d_physics/7="shield"
```

**Matriz de colisión de referencia** (`collision_layer` = en qué capa está el nodo; `collision_mask` = qué capas detecta/con qué colisiona):

| Entidad                                  | `collision_layer`   | `collision_mask` (detecta a...)                                                                   |
| ---------------------------------------- | ------------------- | ------------------------------------------------------------------------------------------------- |
| Player                                   | `player`            | `walls`, `enemies`, `enemy_projectiles`, `pickups`                                                |
| Walls (TileMapLayer)                     | `walls`             | _(ninguna — cuerpo estático, no necesita detectar nada)_                                          |
| Enemies                                  | `enemies`           | `walls`, `player`, `player_disc`                                                                  |
| Player Disc                              | `player_disc`       | `walls`, `enemies`, `shield`                                                                      |
| Enemy Projectiles                        | `enemy_projectiles` | `walls`, `player`, `shield`                                                                       |
| Pickups (Area2D)                         | `pickups`           | `player`                                                                                          |
| Shield (bloqueo jugador / escudo Warden) | `shield`            | _(ninguna — es detectado por `player_disc` y `enemy_projectiles`, no necesita detectar él mismo)_ |

Convenciones:

- El disco (`player_disc`) **no** colisiona físicamente con `player`: la recogida al volver (`disc_caught`) se resuelve por lógica de distancia/`Area2D` propia del disco en su spec (1.5), no por esta matriz de capas físicas.
- `enemies` no colisiona con `enemy_projectiles` ni con otros `enemies`: los proyectiles enemigos no dañan a otros enemigos, y la evasión entre enemigos (si aplica) se resuelve con `NavigationAgent2D`, no con física de colisión.
- `shield` es una sola capa compartida entre el hitbox de bloqueo del jugador y el escudo frontal del Warden (`design.md §3.3`) — ambos son mecánicamente "superficie que detiene disco/proyectil en vez de recibir daño normal".

## Implementation plan

1. Abrir `project.godot` y localizar (o crear) la sección `[layer_names]`.
2. Definir las 7 claves `2d_physics/1` a `2d_physics/7` con los nombres `player`, `walls`, `enemies`, `player_disc`, `enemy_projectiles`, `pickups`, `shield` en ese orden.
3. Abrir el proyecto en el editor de Godot y verificar en Project Settings → General → Layer Names → 2D Physics que las 7 capas aparecen con los nombres correctos en las posiciones 1-7.
4. Agregar la tarea `0.6 Definir y nombrar las 7 capas de física (Project Settings) + matriz de colisión de referencia.` a `docs/tasks.md`, en la Fase 0, después de la tarea `0.5`.
5. Marcar la tarea `0.6` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] `project.godot` tiene una sección `[layer_names]` con exactamente 7 claves `2d_physics/1` a `2d_physics/7`.
- [ ] `2d_physics/1` = `"player"`, `2d_physics/2` = `"walls"`, `2d_physics/3` = `"enemies"`, `2d_physics/4` = `"player_disc"`, `2d_physics/5` = `"enemy_projectiles"`, `2d_physics/6` = `"pickups"`, `2d_physics/7` = `"shield"`.
- [ ] Project Settings → General → Layer Names → 2D Physics (editor de Godot) muestra las 7 capas con esos nombres en esas posiciones, sin errores al abrir el proyecto.
- [ ] Esta spec documenta la matriz de colisión de referencia (tabla `collision_layer`/`collision_mask` por entidad) en su sección "Data model".
- [ ] `docs/tasks.md` tiene la tarea `0.6` agregada en Fase 0 y marcada como `[x]`.
- [ ] Ninguna escena, script ni nodo del proyecto fue creado o modificado (alcance limitado a `project.godot` y `docs/tasks.md`).

## Decisions

- **Sí:** capa `shield` compartida entre bloqueo del jugador y escudo del Warden. _Razón: ambos mecanismos son equivalentes a nivel de física (detienen disco/proyectil en vez de aplicar daño normal); usar capas separadas gastaría dos de las 7 disponibles en el mismo concepto. Decisión tomada junto al usuario tras plantear alternativas (solo jugador / solo enemigo)._
- **Sí:** documentar la matriz de colisión completa (layer + mask por entidad) en esta spec, aunque las escenas no existan todavía. _Razón: evita que cada spec futura de Fase 1-2 re-decida qué colisiona con qué, y fija el contrato una sola vez — mismo patrón que la spec 01 fijó las señales de EventBus por adelantado._
- **No:** crear o tocar ninguna escena/nodo con `CollisionShape2D` en esta spec. _Razón: ninguna escena de jugador/disco/enemigos existe aún (tareas 1.1-1.3 sin empezar); asignar `collision_layer`/`collision_mask` reales le corresponde a la spec de cada entidad cuando se cree._
- **No:** que `enemy_projectiles` colisione con `enemies`. _Razón: los proyectiles enemigos (Lancer, tarea 2.6) no deben dañar a otros enemigos; es el comportamiento estándar del género._
- **No:** que `player_disc` colisione físicamente con `player`. _Razón: la recogida del disco al volver (`disc_caught`) se resuelve por lógica de distancia/`Area2D` propia en la spec 1.5, no por la matriz de capas físicas — evita doble mecanismo de detección para lo mismo._
- **Sí:** agregar la tarea `0.6` a `docs/tasks.md` en vez de reutilizar una tarea existente. _Razón: no había ninguna tarea explícita para "definir capas de física" en el plan original; se detectó el hueco durante esta spec._

## What is **not** in this spec

- Crear o modificar cualquier escena (`.tscn`) o nodo con `CollisionShape2D`/`CollisionPolygon2D`.
- Asignar `collision_layer`/`collision_mask` reales en el editor o en código para jugador, disco, paredes, enemigos, proyectiles, pickups o escudo del Warden.
- Lógica real de bloqueo/parry del jugador o del escudo del Warden.
- Capas de render 2D (`layer_names/2d_render`), física 3D, o grupos de nodos (`Node.groups`).

Cada una de estas, cuando llegue, tendrá su propia spec.
