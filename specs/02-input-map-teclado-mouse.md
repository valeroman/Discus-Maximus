# SPEC 02 — Input Map: teclado y mouse

> **Status:** Implementado
> **Depends on:** [01-autoloads-base.md](01-autoloads-base.md)
> **Date:** 2026-07-14
> **Objective:** Definir en `project.godot` las acciones de Input Map (`move_up/down/left/right`, `throw`, `recall`, `block`, `dash`, `pause`) con sus bindings de teclado y mouse por defecto, sin lógica de gameplay ni UI de remapeo.

## Scope

**In:**

- Definir en `project.godot` (sección `[input]`) las 9 acciones de Input Map: `move_up`, `move_down`, `move_left`, `move_right`, `throw`, `recall`, `block`, `dash`, `pause`.
- Bindings por defecto:
  - `move_up`: **W**, **Flecha arriba**
  - `move_down`: **S**, **Flecha abajo**
  - `move_left`: **A**, **Flecha izquierda**
  - `move_right`: **D**, **Flecha derecha**
  - `throw`: **Click izquierdo** del mouse
  - `recall`: **Click derecho** del mouse
  - `block`: **Shift** (izquierdo)
  - `dash`: **Espacio**
  - `pause`: **Escape**
- Marcar la tarea `0.4` como `[x]` en `docs/tasks.md` al finalizar.

**Out of scope (para specs futuras):**

- Acción `aim`: el apuntado se lee de `get_global_mouse_position()` directamente en el script del jugador (spec de Fase 1, jugador/disco).
- Bindings de gamepad/mando.
- Controles táctiles (joystick virtual, drag-aim) — tarea `4.5`.
- UI de remapeo de teclas (pantalla de ajustes) — RNF-5, spec de Fase 4.
- Cualquier lógica que consuma estas acciones (`Input.is_action_pressed`, etc. en jugador/disco) — llegará con las specs de movimiento/disco.

## Data model

Esta spec no introduce estructuras de datos nuevas (no hay `Resource`, clases ni variables) — solo modifica la sección `[input]` de `project.godot`, que es configuración nativa de Godot, no código. Se documenta aquí el mapeo final para referencia:

| Acción       | Bindings                |
| ------------ | ----------------------- |
| `move_up`    | W, Flecha arriba        |
| `move_down`  | S, Flecha abajo         |
| `move_left`  | A, Flecha izquierda     |
| `move_right` | D, Flecha derecha       |
| `throw`      | Click izquierdo (mouse) |
| `recall`     | Click derecho (mouse)   |
| `block`      | Shift izquierdo         |
| `dash`       | Espacio                 |
| `pause`      | Escape                  |

## Implementation plan

1. Abrir `project.godot` y localizar (o crear) la sección `[input]`.
2. Definir la acción `move_up` con eventos `InputEventKey` para **W** y **Flecha arriba**.
3. Definir `move_down` con **S** y **Flecha abajo**.
4. Definir `move_left` con **A** y **Flecha izquierda**.
5. Definir `move_right` con **D** y **Flecha derecha**.
6. Definir `throw` con evento `InputEventMouseButton` para **click izquierdo** (`MOUSE_BUTTON_LEFT`).
7. Definir `recall` con `InputEventMouseButton` para **click derecho** (`MOUSE_BUTTON_RIGHT`).
8. Definir `block` con `InputEventKey` para **Shift izquierdo** (`KEY_SHIFT`).
9. Definir `dash` con `InputEventKey` para **Espacio** (`KEY_SPACE`).
10. Definir `pause` con `InputEventKey` para **Escape** (`KEY_ESCAPE`).
11. Abrir el proyecto en el editor de Godot y verificar en Project Settings → Input Map que las 9 acciones aparecen con sus bindings correctos, sin acciones duplicadas ni huérfanas.
12. Marcar la tarea `0.4` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [x] `project.godot` tiene una sección `[input]` con exactamente 9 acciones: `move_up`, `move_down`, `move_left`, `move_right`, `throw`, `recall`, `block`, `dash`, `pause`.
- [x] `move_up` responde a **W** y **Flecha arriba**.
- [x] `move_down` responde a **S** y **Flecha abajo**.
- [x] `move_left` responde a **A** y **Flecha izquierda**.
- [x] `move_right` responde a **D** y **Flecha derecha**.
- [x] `throw` responde a **click izquierdo** del mouse.
- [x] `recall` responde a **click derecho** del mouse.
- [x] `block` responde a **Shift izquierdo**.
- [x] `dash` responde a **Espacio**.
- [x] `pause` responde a **Escape**.
- [x] Ninguna acción tiene bindings duplicados o en conflicto con otra acción.
- [x] Project Settings → Input Map (editor de Godot) muestra las 9 acciones y sus eventos correctamente, sin errores al abrir el proyecto.
- [x] `docs/tasks.md` tiene la tarea `0.4` marcada como `[x]`.

## Decisions

- **Sí:** editar directamente la sección `[input]` de `project.godot` (equivalente a Project Settings → Input Map). _Razón: es el mecanismo nativo de Godot, sin capas de abstracción extra._
- **No:** crear una acción `aim`. _Razón: el apuntado en PC/web se lee como posición continua del mouse (`get_global_mouse_position()`), no como una acción discreta on/off; en móvil se resuelve con drag táctil (spec 4.5). Ninguno de los dos encaja en el modelo de "acción" de Godot Input Map._
- **Sí:** usar mouse para `throw`/`recall` en PC/web. _Razón: es el estándar del género (twin-stick), definido en `design.md §3.6` y `RF-1.4`; se evaluó sacar el mouse pero se descartó porque rompería el esquema de apuntado sin alternativa mejor, y móvil ya resuelve su propio input táctil por separado (tarea 4.5)._
- **Sí:** doble binding (teclado + flechas) para movimiento. _Razón: cubre preferencia de jugadores distintos sin costo adicional._
- **Sí:** reservar `block` con Shift aunque no exista mecánica de bloqueo real todavía (`disc_blocked` es señal stub de la spec 01). _Razón: fija el input desde ya para no reabrir `project.godot` cuando la mecánica de bloqueo se implemente._
- **No:** bindings de gamepad. _Razón: decisión explícita del usuario — fuera de scope, solo teclado+mouse por ahora._
- **No:** UI de remapeo de teclas (RNF-5). _Razón: es una pantalla de ajustes que pertenece a una spec de Fase 4 (menús); esta spec solo fija los bindings por defecto._
