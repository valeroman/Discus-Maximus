# Requirements — 03 Enemigos y Combate

## Objetivo
Sistema de combate completo: componentes de vida/daño, 4 arquetipos de enemigos con IA, moneda y combos.

## Requisitos (EARS)
- **3.1** THE SYSTEM SHALL implementar componentes reutilizables: `HealthComponent` (vida, señal died), `HurtboxComponent` (recibe daño), `HitboxComponent` (inflige daño) usados por jugador, enemigos y jefes.
- **3.2** THE SYSTEM SHALL implementar `EnemyBase` con FSM (IDLE/CHASE/ATTACK/RECOVER/DEAD) + NavigationAgent2D + `EnemyData` resource (vida, daño, velocidad, valor de moneda).
- **3.3** THE SYSTEM SHALL incluir 4 arquetipos:
  - **Rusher**: rápido, lunge cuerpo a cuerpo con telegraph de 0.4s, poca vida.
  - **Lancer**: mantiene distancia y lanza proyectil-disco `parryable` (sinergia con el escudo del jugador).
  - **Warden**: escudo frontal propio; SOLO recibe daño por la espalda o por el disco en estado RETURNING. Enseña a usar rebotes y retornos.
  - **Splitter**: al morir se divide en 2 mini-splitters con la mitad de stats.
- **3.4** WHEN el disco (FLYING o RETURNING) o un proyectil parryado impacte a un enemigo, THE SYSTEM SHALL aplicar daño + hit-stop 0.05s + knockback + flash blanco.
- **3.5** WHEN un enemigo golpee al jugador sin bloqueo, THE SYSTEM SHALL restar 1 vida, aplicar i-frames de 1s y feedback (flash rojo + shake fuerte). Con 0 vidas → `player_died`.
- **3.6** WHEN un enemigo muera, THE SYSTEM SHALL soltar chispas de energía que vuelan al jugador por imán de proximidad (radio ampliable por mejoras) y emitir `enemy_died`.
- **3.7** WHEN el jugador elimine enemigos en ventana de 3s, THE SYSTEM SHALL incrementar el multiplicador de combo; al expirar, se reinicia.
- **3.8** WHEN un solo lanzamiento elimine 2+ enemigos, THE SYSTEM SHALL celebrar la carambola: texto "¡CARAMBOLA xN!", slow-motion 0.3s y bonus de moneda.
- **3.9** THE SYSTEM SHALL escalar stats por dificultad: `stat_final = stat_base * (1 + 0.15*mundo + 0.05*nivel)`, coeficientes en un único resource de balance.

## Criterio de aceptación
Arena con mezcla de los 4 arquetipos spawneados manualmente: el combate es legible, justo y satisfactorio; el Warden obliga a usar rebotes o el retorno; los proyectiles del Lancer se pueden bloquear y parryar.
