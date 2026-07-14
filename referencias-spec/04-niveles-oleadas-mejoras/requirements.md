# Requirements — 04 Niveles, Oleadas y Mejoras

## Objetivo
Loop de juego completo: niveles con oleadas → pantalla de mejoras (1 de 3) → siguiente nivel. Estructura híbrida.

## Requisitos (EARS)
- **4.1** THE SYSTEM SHALL definir niveles como datos: `LevelData` (arena, lista de WaveData, recompensa) y `WaveData` (entradas {enemy_id, cantidad, delay, zona de spawn}).
- **4.2** WHEN empiece un nivel, THE SYSTEM SHALL spawnear las oleadas en secuencia; la siguiente inicia al limpiar la anterior; con portales de spawn telegrafiados (el jugador ve dónde aparecerán 1s antes).
- **4.3** WHEN se limpie la última oleada, THE SYSTEM SHALL emitir `level_completed`, abrir la salida con VFX y mostrar la pantalla de mejoras.
- **4.4** THE SYSTEM SHALL ofrecer al completar cada nivel una elección de 1 entre 3 `UpgradeData` aleatorias sin repetir las ya activas (salvo mejoras apilables marcadas como tal).
- **4.5** THE SYSTEM SHALL incluir mínimo 10 mejoras en v1.0: +1 rebote (apilable), disco explosivo, disco perforante, doble disco, dash extendido, imán mayor, +1 vida, retorno teledirigido, **parry ampliado** (ventana 0.15→0.25s), **escudo espejo** (el bloqueo normal también refleja, con daño ×1).
- **4.6** WHEN el jugador muera, THE SYSTEM SHALL reiniciar el mundo desde el nivel 1, limpiando mejoras de la run y conservando la moneda acumulada.
- **4.7** THE SYSTEM SHALL calificar cada nivel con 1–3 estrellas según tiempo, daño recibido y combo máximo (umbrales en LevelData).
- **4.8** THE SYSTEM SHALL encadenar el flujo del mundo 1: niveles 1→4 de oleadas con dificultad creciente (el nivel 5/jefe llega en la spec 05).

## Criterio de aceptación
Se puede jugar el mundo 1 (4 niveles) de corrido: la elección de mejoras cambia sensiblemente cómo se juega, morir reinicia conservando moneda, y las estrellas se calculan bien.
