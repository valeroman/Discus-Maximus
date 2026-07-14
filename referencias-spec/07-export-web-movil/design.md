# Design — 07 Controles táctiles, Optimización y Export

## Input abstraction
`InputAdapter` (autoload o nodo en Player): expone `get_move_vector()`, `get_aim_vector()`, `wants_throw/block/dash/recall()`. Implementaciones: `KeyboardMouseAdapter` y `TouchAdapter`. Selección por `DisplayServer.is_touchscreen_available()` con override en ajustes.

## Esquema táctil
- **Joystick izquierdo**: flotante (aparece donde toca el pulgar), radio muerto 10%.
- **Zona derecha**: al tocar y arrastrar → aparece el preview de trayectoria (idéntico al de PC); soltar = lanzar. Tap corto = recall. Mantener sin arrastrar 0.2s = bloquear (el escudo apunta hacia el último aim); soltar = bajar escudo. El parry en táctil se dispara al iniciar el hold → misma ventana de 0.15s.
- **Botón dash**: esquina inferior derecha, tamaño mínimo 88px.
- Multitouch obligatorio; probar gestos simultáneos (mover + apuntar + dash).

## Pooling (`systems/object_pool.gd`)
Pool genérico por PackedScene con `acquire()/release()`; precalentado por nivel según WaveData. Aplicar a: proyectiles, chispas, números de daño, partículas de muerte, enemigos.

## Presupuesto de rendimiento
Draw calls < 100 · Física: colisiones simples (círculos) · GPUParticles con fallback CPUParticles en móvil si FPS < 50 durante 3s (QualityManager degrada: glow → halos, partículas 100%→50%) · Texturas en atlas ≤ 2048 · Audio OGG, música por streaming.

## Export
- **Web**: preset threads off, extensiones WebGL2; probar en itch.io embebido; loader personalizado.
- **Android**: keystore de release, iconos adaptativos, landscape sensor, target SDK vigente, ProGuard off (Godot), prueba en dispositivo real de gama media.
- Auto-pause: `NOTIFICATION_APPLICATION_FOCUS_OUT` → pausa (si no está en menú).

## Autosave
SaveManager escucha `level_completed`, compras de Forja y cambios de ajustes → `save_game()` (escritura atómica).
