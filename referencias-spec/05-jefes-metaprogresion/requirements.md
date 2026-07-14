# Requirements — 05 Jefes y Meta-progresión

## Objetivo
Jefes con fases, los mundos 2 y 3 completos, y meta-progresión permanente (La Forja). Al cerrar el jefe 1, el mundo 1 es una demo publicable.

## Requisitos (EARS)
- **5.1** THE SYSTEM SHALL implementar un `BossBase` con FSM de fases por % de vida, patrones telegrafiados (zona de peligro visible ≥0.5s antes) y barra de vida propia en pantalla.
- **5.2** THE SYSTEM SHALL incluir 3 jefes:
  - **Overseer** (mundo 1): abanicos de proyectiles parryables + invoca Rushers + embestida telegrafiada. 2 fases.
  - **Twin Warden** (mundo 2): dos entidades con escudo frontal que rotan en espejo; el daño real requiere rebotar el disco entre ambas o parry-reflejar sus proyectiles. Comparten vida. 2 fases.
  - **Core Prime** (mundo 3): arena que se encoge por anillos, láseres rotatorios (esquivables con dash), fase final de "lluvia de discos" donde el bloqueo es obligatorio. 3 fases.
- **5.3** WHEN un jefe cambie de fase, THE SYSTEM SHALL comunicarlo con VFX + rugido + subida de capa musical.
- **5.4** WHEN un jefe muera, THE SYSTEM SHALL dar recompensa grande de moneda + desbloquear el siguiente mundo + celebración (slowmo + explosión + resultados).
- **5.5** THE SYSTEM SHALL implementar los mundos 2 y 3 (4 niveles + jefe cada uno) con nuevas combinaciones y 2 variantes élite de enemigos (más vida + un twist: Rusher élite deja rastro dañino; Lancer élite dispara ráfaga de 3).
- **5.6** THE SYSTEM SHALL implementar **La Forja** (menú): gastar moneda permanente en desbloqueos persistentes — vida base +1 (×2 niveles), mejora inicial garantizada, ventana de parry base +0.05s, skin de disco cosmética.
- **5.7** THE SYSTEM SHALL guardar y restaurar: mundos desbloqueados, estrellas por nivel, moneda total, compras de Forja, mejor puntuación por mundo.

## Criterio de aceptación
Los 3 mundos se juegan de principio a fin; cada jefe exige dominar una mecánica distinta (rebotes / escudo-parry / dash+bloqueo); la Forja hace que perder también progrese.
