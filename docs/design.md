# Design — DISCUS MAXIMUS (Godot 4.x · 2D isométrico · Web + Móvil)

## 1. Decisiones de arquitectura

| Decisión | Elección | Justificación |
|---|---|---|
| Renderer | **Compatibility (GLES3/WebGL2)** | Máxima compatibilidad web + móvil y mejor rendimiento en gama baja. |
| Perspectiva | TileMapLayer isométrico + `Y-sort` | Isométrico nativo de Godot; entidades como escenas top-down con sprites en ángulo iso. |
| Física del disco | `CharacterBody2D` + `move_and_collide` con reflexión manual (`velocity.bounce(normal)`) | Control total del rebote; las físicas de RigidBody2D son impredecibles para gameplay arcade. |
| Comunicación | **Señales + EventBus autoload** | Cero acoplamiento: UI, audio y VFX escuchan eventos, no referencian nodos de gameplay. |
| Datos de balance | **Custom Resources (.tres)** | EnemyData, UpgradeData, WaveData, LevelData editables desde el inspector. |
| Guardado | JSON en `user://` | Funciona igual en móvil y web (IndexedDB automático en HTML5). |

## 2. Estructura del proyecto

```
res://
├── autoload/
│   ├── event_bus.gd          # Señales globales (enemy_died, disc_thrown, level_completed…)
│   ├── game_state.gd         # Run actual: vida, mejoras activas, combo, moneda
│   ├── save_manager.gd       # Persistencia JSON
│   ├── audio_manager.gd      # Pools de SFX + música con capas
│   └── juice.gd              # screen shake, hit-stop, slow-motion (Engine.time_scale)
├── entities/
│   ├── player/               # player.tscn + player.gd + estados
│   ├── disc/                 # disc.tscn (FLYING → RETURNING → HELD)
│   └── enemies/
│       ├── enemy_base.tscn   # Clase base con FSM + EnemyData export
│       ├── rusher/ lancer/ warden/ splitter/
│       └── bosses/boss_1..3/
├── systems/
│   ├── wave_manager.gd       # Spawnea oleadas desde WaveData
│   ├── upgrade_system.gd     # Pool de mejoras, tirada de 3, aplicación por composición
│   └── combo_system.gd
├── levels/
│   ├── level_base.tscn       # Arena + spawns + WaveManager + triggers
│   └── world_1..3/level_1..5.tscn
├── ui/                       # hud, main_menu, world_select, upgrade_picker, forge, pause, results
├── data/                     # .tres de enemigos, mejoras, oleadas, niveles
└── assets/                   # sprites, tiles iso, sfx, music, fonts, shaders
```

## 3. Sistemas clave

### 3.1 Disco (máquina de estados)
```
HELD ──lanzar──▶ FLYING ──(rebotes agotados | recall | timeout)──▶ RETURNING ──llega──▶ HELD
```
- **FLYING**: velocidad ~900 px/s; en colisión con pared → `velocity = velocity.bounce(collision.get_normal())`, `bounces_left -= 1`. Contra enemigo → daño + perfora (sigue) o rebota según mejoras.
- **RETURNING**: interpolación con steering hacia el jugador (curva, no línea recta) — daña a su paso. Ignora paredes (atraviesa como energía) para evitar que quede atascado.
- El jugador expone `has_disc: bool`; el HUD lo refleja con un icono (lleno/vacío).

### 3.2 IA enemiga (FSM sobre enemy_base)
Estados: `IDLE → CHASE → ATTACK → RECOVER`, con `NavigationAgent2D` para pathfinding en la arena. Cada arquetipo sobreescribe `attack()`:
- Rusher: lunge cuerpo a cuerpo con telegraph de 0.4s.
- Lancer: mantiene distancia (steering "keep range") y lanza proyectil-disco propio con recarga.
- Warden: nodo `ShieldHitbox` frontal que anula daño; el daño trasero o de disco en retorno sí cuenta.
- Splitter: en `die()` instancia 2 mini-splitters con la mitad de stats.

Escalado: `stat_final = stat_base * (1 + 0.15 * mundo + 0.05 * nivel)` — coeficientes en un solo Resource de balance.

### 3.3 Jefes
Escena por jefe con FSM de fases (`PHASE_1/2/3` según % de vida). Patrones telegrafiados con `AnimationPlayer` (flash + área de peligro visible 0.5s antes). Ejemplos v1.0:
1. **Overseer** (mundo 1): lanza abanicos de discos, invoca Rushers.
2. **Twin Warden** (mundo 2): dos entidades con escudo que rotan; hay que rebotar el disco entre ambas.
3. **Core Prime** (mundo 3): arena que se encoge, fases con anillos láser rotatorios.

### 3.4 Mejoras (composición, no herencia)
`UpgradeData (Resource)`: id, nombre, icono, rareza, `modifiers: Dictionary` (p. ej. `{"disc_bounces": +1}`) y `behavior_script` opcional para mejoras con lógica (disco explosivo → al impactar instancia `explosion.tscn`). `GameState.active_upgrades` es la lista de la run; el disco/jugador consultan stats vía `GameState.get_stat("disc_bounces")`.

### 3.5 Oleadas y niveles
`LevelData`: arena, lista de `WaveData`. `WaveData`: array de `{enemy_id, cantidad, delay, spawn_zone}`. `WaveManager` emite `wave_started/wave_cleared/level_completed` por EventBus. Nivel 5 de cada mundo carga la escena del jefe.

### 3.6 Input dual (PC/web ↔ táctil)
Autodetección: `DisplayServer.is_touchscreen_available()`. 
- PC: WASD + mouse (apuntar = dirección al cursor), click lanza, click derecho recall, espacio dash.
- Táctil: `TouchScreenJoystick` (izq.) para mover; en la mitad derecha, **drag & release** dibuja línea de puntería con preview de rebotes (raycast) y al soltar lanza; tap corto derecho = recall; botón dash.
El preview de trayectoria con rebotes es clave en móvil: convierte la puntería en algo táctico y satisfactorio.

### 3.7 Juice (autoload)
- `shake(intensity)`: trauma acumulativo con decaimiento en la cámara.
- `hit_stop(0.05)`: `Engine.time_scale = 0.05` durante ms reales (timer con `ignore_time_scale`).
- `slowmo(0.3, 0.6)`: para carambolas y último enemigo del nivel.
- Shader de flash blanco en sprites al recibir daño; partículas GPU para estelas del disco, muertes y recogidas.

## 4. Estética (original, sin IP de terceros)
- Paleta synthwave propia: fondo #0d0221, cian #00f0ff, magenta #ff2079, ámbar #ffb800 para peligro.
- Tiles isométricos con emisión neón (shader glow barato: WorldEnvironment con glow solo en web/desktop; en móvil, sprites con halo pre-renderizado para rendimiento).
- Personaje y enemigos: siluetas geométricas limpias con líneas de energía — legibles a tamaño móvil.

## 5. Rendimiento web/móvil
- Object pooling para proyectiles, partículas y enemigos.
- Texturas atlas ≤ 2048px; audio OGG; música en streaming.
- Límite de 25 enemigos simultáneos; partículas GPU con fallback CPU.
- Export web con threads desactivados (compatibilidad Safari/itch.io).

## 6. Flujo de escenas
```
Main Menu → World Select → Level (waves) → Upgrade Picker → siguiente Level → … → Boss → Results → World Select
                └── Forge (meta-progresión)          └── Death → Retry (reinicia mundo, conserva moneda)
```
