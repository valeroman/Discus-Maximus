# Design — 05 Jefes y Meta-progresión

## BossBase (`entities/bosses/boss_base.tscn`)
Extiende el patrón de EnemyBase pero con FSM de PATRONES: cada patrón es un método corrutina (`await`) que encadena telegraph → ejecución → recover. Selector de patrón por fase con pesos. `PhaseController`: umbrales de % vida → señal `phase_changed(n)`.

### Telegraphs
`danger_zone.tscn`: Polygon2D/círculo semitransparente magenta que se rellena en el tiempo de aviso; al completarse, activa la hitbox. Reutilizado por los 3 jefes.

### Overseer — patrones
Abanico (5–9 proyectiles parryables) · Invocación (2–4 Rushers por portales) · Embestida (línea de peligro 0.8s → dash del jefe). Fase 2: abanicos dobles + embestida en L.

### Twin Warden — patrones
Ambos orbitan el centro en espejo con escudos hacia afuera → el punto débil siempre está "entre" ellos: el rebote pared→espalda es la solución. Vida compartida (un HealthComponent, dos cuerpos). Patrón láser conjunto: haz entre ambos que barre la arena (saltar con dash). Fase 2: orbitan más rápido y disparan mientras rotan.

### Core Prime — patrones
`ArenaShrinker`: anillos exteriores del TileMap se vuelven letales por fase. Láseres rotatorios (2→4). "Lluvia de discos": proyectiles caen sobre la posición del jugador con sombra de aviso; bloquear en movimiento es la única supervivencia. Núcleo expuesto solo tras cada ciclo de patrones (ventana de daño clara).

## Élites
Flag `elite` en EnemyData: +80% vida, tinte dorado, twist por script (`elite_behavior`). Aparecen desde el mundo 2.

## La Forja (`ui/forge.tscn`)
Lista de `ForgeUpgradeData` (costo, nivel máx., modifiers permanentes). GameState combina: stats base + Forja + mejoras de la run en `get_stat()`. Compras vía SaveManager.

## Save (`user://save.json`)
{ version, worlds_unlocked, stars: {level_id: n}, currency_total, forge: {id: nivel}, best_scores, settings }
Escritura atómica (archivo temporal + rename). En web persiste vía IndexedDB automáticamente.
