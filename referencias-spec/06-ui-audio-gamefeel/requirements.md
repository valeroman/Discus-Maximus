# Requirements — 06 UI, Audio y Game Feel

## Objetivo
Todas las pantallas, HUD definitivo, audio completo, arte final y el pulido que convierte un prototipo en un juego adictivo.

## Requisitos (EARS)
- **6.1** THE SYSTEM SHALL incluir: menú principal, selector de mundos/niveles (con estrellas), HUD, pantalla de mejoras (ya existente, con arte final), pausa, resultados de nivel/mundo, derrota, La Forja y ajustes.
- **6.2** El HUD SHALL mostrar: vidas, estado del disco (en mano/fuera/bloqueando), cooldown de dash, combo con multiplicador, moneda, oleada actual y barra de jefe cuando aplique.
- **6.3** THE SYSTEM SHALL soportar i18n ES/EN con el sistema de traducciones de Godot (CSV); todo texto de UI pasa por claves.
- **6.4** THE SYSTEM SHALL incluir música por mundo en loop con capa de intensidad para jefes (2 stems sincronizados) y SFX para todas las acciones (lanzar, rebote, impacto, retorno, recogida, bloqueo, parry, daño, muerte, UI, portales, jefe).
- **6.5** THE SYSTEM SHALL aplicar el paquete de game feel definitivo: screen shake escalado por evento, hit-stop, slow-motion en carambolas/parry/último enemigo, flash de daño, partículas de estela/muerte/recogida, y animación de "squash" al recoger el disco.
- **6.6** THE SYSTEM SHALL incluir accesibilidad: reducir shake/flash, tamaño de HUD, remapeo de teclas, volúmenes independientes (música/SFX).
- **6.7** THE SYSTEM SHALL reemplazar todos los placeholders por arte original: paleta synthwave propia (fondo #0d0221, cian #00f0ff, magenta #ff2079, ámbar #ffb800), tiles isométricos con emisión neón, personaje/enemigos de siluetas geométricas legibles a tamaño móvil.
- **6.8** WHEN el jugador muera, THE SYSTEM SHALL permitir reintentar en ≤ 2 segundos (sin pantallas de carga largas: la fricción mata la adicción).

## Criterio de aceptación
Un tester nuevo entiende todo sin explicación, el retry es instantáneo, y grabar un clip de 15s de una carambola con parry se ve digno de compartir.
