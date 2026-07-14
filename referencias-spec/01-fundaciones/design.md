# Design — 01 Fundaciones

## Autoloads (API pública inicial)
- **EventBus** (`event_bus.gd`): solo señales. Iniciales: `disc_thrown`, `disc_caught`, `disc_blocked(perfect: bool)`, `enemy_died(enemy)`, `player_damaged(hp)`, `player_died`, `wave_started(n)`, `wave_cleared(n)`, `level_completed`, `combo_changed(mult)`, `currency_collected(amount)`.
- **GameState** (`game_state.gd`): estado de la run — `hp`, `max_hp`, `currency_run`, `active_upgrades: Array`, `combo: int`; método `get_stat(name: String) -> float` que suma stat base + modificadores de mejoras activas.
- **SaveManager**: `save_game()` / `load_game()` sobre `user://save.json` (stub funcional).
- **AudioManager**: `play_sfx(id)`, `play_music(id)`, pools de AudioStreamPlayer (stub).
- **Juice**: `shake(amount)`, `hit_stop(seconds)`, `slowmo(scale, duration)` (stub).

## Arena de pruebas
`levels/test_arena.tscn`: `TileMapLayer` isométrico (tile placeholder 64×32 con borde neón), paredes con colisión en capa `walls`, `Y-sort` activo, `Camera2D` con límites.

## Capas de física (nombrarlas en Project Settings)
1 player · 2 walls · 3 enemies · 4 player_disc · 5 enemy_projectiles · 6 pickups · 7 shield

## Export HTML5
Preset con `threads = off`, compresión activada, canvas resize adaptativo.
