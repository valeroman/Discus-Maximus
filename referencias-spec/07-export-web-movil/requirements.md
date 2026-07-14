# Requirements — 07 Controles táctiles, Optimización y Export (v1.0)

## Objetivo
Controles táctiles de calidad, rendimiento sólido y builds publicables en web (itch.io) y Android.

## Requisitos (EARS)
- **7.1** WHEN la plataforma tenga pantalla táctil, THE SYSTEM SHALL activar automáticamente el esquema táctil: joystick virtual izquierdo (movimiento) + zona derecha con **drag & release** para apuntar/lanzar (con el preview de trayectoria y rebote visible durante el drag) + botón de dash + botón mantener = bloquear / tap = recall.
- **7.2** THE SYSTEM SHALL escalar y reposicionar el HUD y los controles para ratios 16:9, 18:9, 19.5:9 y 4:3, con zonas seguras (notch).
- **7.3** THE SYSTEM SHALL mantener 60 FPS en móvil de gama media y en navegador; ante caídas, SHALL degradar partículas/glow antes que gameplay.
- **7.4** THE SYSTEM SHALL usar object pooling para proyectiles, chispas, partículas y enemigos; límite de 25 enemigos simultáneos.
- **7.5** THE SYSTEM SHALL producir build HTML5 ≤ 30 MB comprimida, threads off, con pantalla de carga con la identidad del juego.
- **7.6** THE SYSTEM SHALL producir build Android firmada (keystore) con iconos, splash y orientación landscape bloqueada; táctil verificado en dispositivo real.
- **7.7** WHEN el juego pierda el foco (web) o pase a segundo plano (móvil), THE SYSTEM SHALL pausar automáticamente.
- **7.8** THE SYSTEM SHALL guardar automáticamente tras cada nivel, compra o cambio de ajustes (a prueba de cierres de pestaña).

## Criterio de aceptación (v1.0)
El juego corre a 60 FPS en un móvil de gama media y en Chrome/Firefox/Safari; una persona lo juega completo en su teléfono solo con el pulgar izquierdo y derecho, sin tutorial de controles.
