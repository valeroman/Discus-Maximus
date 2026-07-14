# DISCUS MAXIMUS

Arcade 2D isométrico de combate con un disco de energía (lanzar/rebotar/recuperar).
Godot 4.7 · GL Compatibility · Web (HTML5) + Móvil (Android/iOS) · Estética synthwave original.

## Documentos de referencia (leer antes de implementar)
- `docs/requirements.md` — biblia de diseño (EARS: RF-1..10, RNF-1..5). Fuente de verdad del QUÉ.
- `docs/design.md` — arquitectura, estructura de carpetas, sistemas clave. Fuente de verdad del CÓMO.
- `docs/tasks.md` — plan incremental por fases (0→5). Marcar `[x]` al completar cada tarea.
- `specs/NN-slug.md` — specs implementables, generadas con `/spec` (metodología spec-driven de Fernando Herrera, skill instalada en `.agents/skills/`). Consultar la spec activa antes de codear. Solo se implementa una spec cuando su estado es `Approved`/`Aprobado` (ver `/spec-impl`).

## Reglas de arquitectura (no negociables)
- **Desacoplamiento por señales**: UI/audio/VFX escuchan el `EventBus` autoload; nunca referencian nodos de gameplay directamente.
- **Balance en Resources (.tres)**: vida, daño, velocidad, oleadas, mejoras → editables sin tocar código. Nada de números mágicos hardcodeados.
- **Mejoras por composición, no herencia**: `UpgradeData` con `modifiers` + `behavior_script` opcional; stats se consultan vía `GameState.get_stat()`.
- **Física del disco manual**: `CharacterBody2D` + `move_and_collide` + `velocity.bounce(normal)`. No RigidBody2D para gameplay.
- **Game feel primero**: cada impacto lleva screen shake + hit-stop + flash + partículas (autoload `Juice`), con opción de reducir efectos (accesibilidad).
- **Assets 100% originales**: sin IP de terceros. Paleta neón propia (#0d0221 / #00f0ff / #ff2079 / #ffb800).
- **Rendimiento web/móvil**: object pooling, ≤25 enemigos simultáneos, atlas ≤2048px, audio OGG, 60 FPS objetivo. Build web ≤30 MB.
- **i18n ES/EN** desde el inicio.

## Estructura del proyecto
res://autoload · entities (player/disc/enemies) · systems (wave/upgrade/combo) · levels · ui · data (.tres) · assets.
Detalle completo en `docs/design.md §2`.

## Flujo de trabajo (spec-driven)
1. `/spec <descripción>` → define y guarda la spec en `specs/NN-slug.md` (estado inicial `Draft`).
2. Revisar y cambiar el estado a `Approved` manualmente cuando esté lista.
3. `/spec-impl NN-slug` → crea branch `spec-NN-slug` e implementa paso a paso con pausas para revisar diffs.
4. Al completar: marcar la spec como `Implemented` y la tarea correspondiente como `[x]` en `docs/tasks.md`.

**Pendiente:** `/spec-impl` requiere un repo git (crea branches). El proyecto aún no está inicializado como repo git — inicializarlo antes de usar `/spec-impl`.

## Estado actual
- [x] 0.1 (parcial) Proyecto Godot 4.7, GL Compatibility, stretch canvas_items/expand.
- [ ] Resto de Fase 0 y siguientes → ver `docs/tasks.md`.
- [ ] Inicializar repo git (requerido por `/spec-impl`).

## Convenciones
- GDScript, `snake_case` archivos, `PascalCase` clases/nodos.
- Al empezar una tarea, buscar/crear la spec correspondiente en `specs/`; al terminar, marcar `[x]` en `docs/tasks.md`.
