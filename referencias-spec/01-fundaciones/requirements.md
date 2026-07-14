# Requirements — 01 Fundaciones

## Objetivo
Proyecto Godot 4.x configurado, ejecutable en editor y exportable a HTML5, con la arquitectura base lista.

## Requisitos (EARS)
- **1.1** THE SYSTEM SHALL usar Godot 4.x con renderer **Compatibility** (WebGL2/GLES3) para máxima compatibilidad web y móvil.
- **1.2** THE SYSTEM SHALL usar resolución base 1280×720, stretch mode `canvas_items`, aspect `expand`.
- **1.3** THE SYSTEM SHALL registrar los autoloads: `EventBus`, `GameState`, `SaveManager`, `AudioManager`, `Juice` (con su API pública definida, implementación stub).
- **1.4** THE SYSTEM SHALL definir el Input Map: `move_up/down/left/right`, `throw`, `recall`, `block`, `dash`, `pause` con bindings de teclado y mouse.
- **1.5** THE SYSTEM SHALL tener la estructura de carpetas del CLAUDE.md creada.
- **1.6** WHEN se exporte a HTML5, THE SYSTEM SHALL generar una build que carga y corre en Chrome y Firefox (threads desactivados para compatibilidad con Safari/itch.io).
- **1.7** THE SYSTEM SHALL incluir una escena `main.tscn` que arranca en una arena de pruebas vacía isométrica.

## Criterio de aceptación
Build HTML5 vacía corre en navegador a 60 FPS mostrando la arena de pruebas.
