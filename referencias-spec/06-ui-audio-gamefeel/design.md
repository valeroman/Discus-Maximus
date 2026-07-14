# Design — 06 UI, Audio y Game Feel

## Navegación de escenas
`SceneManager` (método en un autoload existente o nuevo): transiciones con fade de 0.2s. Flujo: MainMenu → WorldSelect → Run → (UpgradePicker overlay) → Results → WorldSelect. Pause como overlay con `get_tree().paused` y process_mode correcto en UI.

## HUD
CanvasLayer con contenedores anclados; icono de disco con 3 estados (lleno/contorno/escudo); combo con tween de escala al subir y drenaje visual del tiempo restante; corazones de vida con animación de pérdida.

## Audio
AudioManager definitivo: buses Master/Music/SFX; pool de 12 AudioStreamPlayer para SFX con variación de pitch ±10% (evita fatiga); música con 2 stems (base + intensidad) sincronizados por reloj, crossfade por volumen en señal `phase_changed`/inicio de jefe. Formato OGG.

## Game feel — tabla de eventos
| Evento | Shake | Hit-stop | Slowmo | Otros |
|---|---|---|---|---|
| Rebote de disco | 1 | — | — | SFX pitch según rebotes restantes |
| Impacto a enemigo | 2 | 0.05s | — | flash blanco + knockback |
| Parry | 2 | 0.08s | 0.3×/0.25s | VFX cian + SFX metálico |
| Carambola | 3 | — | 0.3×/0.4s | texto grande + bonus |
| Daño al jugador | 4 | 0.1s | — | flash rojo + vibración móvil |
| Muerte de jefe | 5 | — | 0.2×/1s | explosión + fade a resultados |

## Arte (original)
Shader de glow: en desktop/web WorldEnvironment con glow; en móvil, sprites con halo pre-renderizado (detección por plataforma). Tiles iso 64×32 con línea de emisión. Animaciones del personaje: idle/run/throw/block/dash (8 direcciones simuladas con flip + 4 ángulos).

## i18n
`locales/strings.csv` con columnas es/en; `tr("KEY")` en toda la UI; selector de idioma en ajustes (autodetecta locale la primera vez).
