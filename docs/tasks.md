# Tasks — DISCUS MAXIMUS · Plan de implementación incremental

> Formato compatible con la metodología spec-impl: tareas atómicas, ordenadas, cada una deja el juego en estado ejecutable. Marca `[x]` al completar. Cada fase termina en un hito jugable.

---

## Fase 0 · Fundaciones (hito: proyecto corre en web)
- [ ] 0.1 Crear proyecto Godot 4.x, renderer Compatibility, resolución base 1280×720, stretch `canvas_items` / aspect `expand`.
- [ ] 0.2 Estructura de carpetas según design.md + `.gitignore` + repositorio Git.
- [x] 0.3 Registrar autoloads vacíos: EventBus, GameState, SaveManager, AudioManager, Juice.
- [x] 0.4 Configurar Input Map: move_*, aim, throw, recall, dash, pause.
- [ ] 0.5 Export preset HTML5 y prueba de build vacía en navegador.
- [x] 0.6 Definir y nombrar las 7 capas de física (Project Settings) + matriz de colisión de referencia.

## Fase 1 · Núcleo jugable: jugador + disco (hito: lanzar y recuperar se siente BIEN)
- [x] 1.1 Player: CharacterBody2D, movimiento 8 direcciones con aceleración/fricción, sprite placeholder.
- [x] 1.2 Arena de pruebas: TileMapLayer isométrico con paredes con colisión, Y-sort activo.
- [x] 1.3 Disc: escena con FSM HELD/FLYING/RETURNING; lanzamiento hacia el cursor.
- [x] 1.4 Rebote en paredes con `bounce(normal)` y contador de rebotes.
- [x] 1.5 Retorno con steering curvo hacia el jugador + recogida (señal `disc_caught`).
- [ ] 1.6 Recall manual y timeout de seguridad.
- [ ] 1.7 Preview de puntería: Line2D con raycast que muestra trayectoria + primer rebote.
- [x] 1.8 Dash con i-frames y cooldown.
- [ ] 1.9 Juice v1: estela del disco (partículas), SFX placeholder de lanzar/rebotar/recoger, micro screen shake al rebotar.
- [ ] ✅ **Checkpoint**: 10 minutos jugando solo a lanzar el disco deben ser divertidos. Si no, iterar aquí antes de seguir.

## Fase 2 · Combate (hito: matar oleadas es satisfactorio)
- [ ] 2.1 Sistema de vida/daño compartido (componente `HealthComponent` + `HurtboxComponent`).
- [ ] 2.2 EnemyBase con FSM + NavigationAgent2D + EnemyData resource.
- [ ] 2.3 Rusher completo (telegraph + lunge + muerte con partículas).
- [ ] 2.4 Daño al jugador, vidas en HUD provisional, flash de daño, muerte y reinicio de nivel.
- [ ] 2.5 Hit-stop y knockback en impactos de disco.
- [ ] 2.6 Lancer (proyectil enemigo + keep-range).
- [ ] 2.7 Warden (escudo frontal; vulnerable por espalda y disco en retorno).
- [ ] 2.8 Splitter.
- [ ] 2.9 Chispas de energía (moneda) con imán de recogida.
- [ ] 2.10 ComboSystem + contador en HUD + celebración de carambola con slow-motion.

## Fase 3 · Estructura de juego (hito: loop completo nivel→mejora→nivel)
- [ ] 3.1 WaveManager + WaveData/LevelData resources; señales por EventBus.
- [ ] 3.2 LevelBase con zonas de spawn, puertas que se abren al limpiar oleadas.
- [ ] 3.3 Pantalla de mejoras: tirada de 3 UpgradeData, selección, aplicación vía GameState.
- [ ] 3.4 Implementar 8 mejoras: +1 rebote, disco explosivo, perforante, doble disco, dash extendido, imán mayor, +1 vida, retorno teledirigido.
- [ ] 3.5 GameState de run: vida, mejoras, combo, moneda; reset al morir conservando moneda.
- [ ] 3.6 Flujo mundo 1: 4 niveles de oleadas encadenados con dificultad creciente.
- [ ] 3.7 Pantallas de victoria/derrota con estadísticas y retry instantáneo.

## Fase 4 · Jefe y mundo 1 completo (hito: demo publicable)
- [ ] 4.1 Boss 1 "Overseer": FSM de 2 fases, patrones telegrafiados, barra de vida.
- [ ] 4.2 Estrellas por nivel (tiempo/daño/combo) + SaveManager (progreso, estrellas, moneda, ajustes).
- [ ] 4.3 Menú principal + selector de niveles del mundo 1 + pausa.
- [ ] 4.4 La Forja: 4 desbloqueos permanentes con moneda.
- [ ] 4.5 Controles táctiles: joystick virtual + drag-aim con preview + botones dash/recall; autodetección de plataforma.
- [ ] 4.6 Música mundo 1 con capa de jefe; pase completo de SFX.
- [ ] 4.7 Arte v1 del mundo 1: tiles iso, jugador, 4 enemigos, jefe, VFX neón.
- [ ] 4.8 i18n ES/EN de toda la UI.
- [ ] 4.9 Optimización: pooling, límites de partículas, perfilado en móvil real y en navegador.
- [ ] 4.10 🚀 **Publicar demo (mundo 1) en itch.io como HTML5** y recoger feedback real.

## Fase 5 · Contenido y pulido (hito: v1.0)
- [ ] 5.1 Mundo 2: nueva arena, mezcla de arquetipos, 2 variantes élite de enemigos.
- [ ] 5.2 Boss 2 "Twin Warden".
- [ ] 5.3 Mundo 3 + Boss 3 "Core Prime" (arena que se encoge).
- [ ] 5.4 6 mejoras adicionales + 2 mejoras "legendarias" raras.
- [ ] 5.5 Balance global desde resources (playtesting con métricas: dónde mueren, qué mejoras eligen).
- [ ] 5.6 Accesibilidad: reducir shake/flash, tamaño de UI, remapeo.
- [ ] 5.7 Export Android (keystore, iconos, tiendas) y ajustes de rendimiento final.
- [ ] 5.8 Trailer/GIFs de carambolas para marketing + página de itch/tiendas.

## Backlog v1.1+
- [ ] Leaderboard online · Modo infinito (oleadas sin fin) · Desafíos diarios con seed · Duelo local 1v1 · Skins de disco cosmétivas por logros.
