# Design — 03 Enemigos y Combate

## Componentes (`systems/components/`)
- `HealthComponent`: `max_hp`, `hp`, `take_damage(amount, source)`, señales `damaged`, `died`. 
- `HurtboxComponent` (Area2D): recibe de `HitboxComponent`; flag `shielded_arc` opcional (para Warden: ángulo frontal inmune).
- `HitboxComponent` (Area2D): `damage`, `knockback_force`.

## EnemyBase (`entities/enemies/enemy_base.tscn`)
CharacterBody2D + NavigationAgent2D + componentes + `EnemyData` export. FSM en un solo script con `match state:` (suficiente; no sobre-ingeniería). Método virtual `attack()` que cada arquetipo sobreescribe. Separación entre enemigos con steering de evasión simple para que no se apilen.

## Arquetipos
| Enemigo | Vida | Comportamiento clave |
|---|---|---|
| Rusher | 10 | CHASE directo; a <120px telegraph 0.4s (parpadeo) → lunge; RECOVER 1s. Su lunge es bloqueable. |
| Lancer | 15 | Keep-range 250–350px; dispara `projectile.tscn` parryable cada 2.5s con telegraph. |
| Warden | 30 | `shielded_arc = 100°` frontal; rota lento hacia el jugador → flanquear, rebotar el disco o golpear con el RETURNING. |
| Splitter | 12 | En `died` instancia 2 `mini_splitter` (vida 6, más rápidos, sin división). |

## Muerte y moneda
`die()`: partículas de disolución neón + `energy_spark.tscn` (Area2D en capa pickups) × valor del enemigo. Sparks: estado IDLE → (jugador a < radio_imán) → SEEK con aceleración → recogida (`currency_collected`).

## ComboSystem (`systems/combo_system.gd`)
Escucha `enemy_died`; ventana 3s reiniciable; `combo_changed(mult)`. Detección de carambola: el disco lleva `kills_this_flight`; se resetea en HELD; si al recoger ≥2 → `EventBus.multi_kill(kills)`.

## Datos
`data/enemies/*.tres` (uno por arquetipo) + `data/balance.tres` (coeficientes de escalado 0.15/0.05, ventana de combo, radio de imán base).
