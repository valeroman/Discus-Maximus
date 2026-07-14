# Design — 04 Niveles, Oleadas y Mejoras

## WaveManager (`systems/wave_manager.gd`)
Nodo en LevelBase. Recibe `LevelData`; por cada `WaveData` instancia portales (`spawn_portal.tscn`: telegraph 1s → spawn). Cuenta vivos suscrito a `enemy_died`; al llegar a 0 → siguiente oleada o `level_completed`. Emite `wave_started(n)/wave_cleared(n)` para HUD.

## LevelBase (`levels/level_base.tscn`)
Arena (TileMapLayer + NavigationRegion2D) + Marker2D de zonas de spawn (norte/sur/este/oeste/centro) + puerta de salida (se abre con level_completed) + WaveManager + spawn del jugador.

## Sistema de mejoras
`UpgradeData (Resource)`: id, nombre, descripción, icono, rareza (común/rara/legendaria), `stackable: bool`, `modifiers: Dictionary` (ej. `{"disc_bounces": 1}`), `behavior: Script` opcional.
- Modificadores puros → los suma `GameState.get_stat()` automáticamente.
- Con comportamiento (explosivo, doble disco, escudo espejo) → GameState instancia el behavior script que se conecta a señales del EventBus (composición pura, cero ifs en el disco).
- `UpgradePicker` (UI): pausa el árbol, muestra 3 cartas (tirada ponderada por rareza, excluye no-apilables ya activas), aplica y reanuda.

## Mejoras destacadas
- **Doble disco**: segundo disco con cooldown propio; permite bloquear con uno mientras el otro vuela (rompe la vulnerabilidad → rareza legendaria).
- **Escudo espejo**: convierte el bloqueo normal en reflejo ×1 (el parry sigue siendo ×2).
- **Retorno teledirigido**: en RETURNING el disco persigue al enemigo más cercano en su ruta.

## Run flow
`GameState.start_run(world)` → carga nivel 1 → ... → `end_run(victory: bool)`. Muerte: `currency_run` se bancariza a `currency_total` (SaveManager) y se limpian mejoras.

## Estrellas
Al `level_completed`: tiempo < T_gold (+1), daño recibido == 0 (+1), combo_max ≥ C (+1). Umbrales por nivel en LevelData. Persistencia por SaveManager.

## Datos del mundo 1
`data/levels/world1_level1..4.tres`: L1 solo Rushers (enseña lanzar) · L2 + Lancers (enseña bloquear/parry) · L3 + Wardens (enseña rebotes/retorno) · L4 mezcla + Splitters, oleada final intensa.
