# Requirements — 02 Jugador, Disco y Escudo

## Objetivo
El corazón del juego: moverse, lanzar el disco con rebotes, recuperarlo, y usarlo como ESCUDO con bloqueo y parry. Esta spec define la mecánica que hace único al juego.

## Requisitos (EARS)

### Movimiento
- **2.1** WHEN el jugador use las teclas de movimiento, THE SYSTEM SHALL moverlo en 8 direcciones con aceleración y fricción suaves (velocidad máxima en ~0.1s).
- **2.2** WHEN el jugador pulse `dash`, THE SYSTEM SHALL ejecutar un dash de ~0.15s con invulnerabilidad (i-frames) y cooldown de 2s, con feedback visual del cooldown.

### Disco como arma
- **2.3** WHEN el jugador apunte y pulse `throw` teniendo el disco, THE SYSTEM SHALL lanzarlo en línea recta a alta velocidad (~900 px/s).
- **2.4** WHILE el disco esté fuera (FLYING o RETURNING), THE SYSTEM SHALL impedir lanzar de nuevo Y TAMBIÉN impedir bloquear: sin disco no hay escudo. El jugador queda totalmente vulnerable — esta vulnerabilidad es intencional y central al diseño.
- **2.5** WHEN el disco choque con una pared, THE SYSTEM SHALL reflejarlo físicamente; rebotes base: 2 (modificable por mejoras vía `GameState.get_stat`).
- **2.6** WHEN el disco agote rebotes, el jugador pulse `recall`, o pasen 4s, THE SYSTEM SHALL iniciar el retorno: el disco vuela hacia el jugador en curva, atraviesa paredes y daña enemigos a su paso.
- **2.7** WHEN el disco llegue al jugador, THE SYSTEM SHALL recogerlo con feedback claro (flash + SFX + señal `disc_caught`).
- **2.8** WHILE el jugador apunte, THE SYSTEM SHALL mostrar preview de trayectoria con el primer rebote calculado (raycast).

### Disco como escudo (mecánica distintiva)
- **2.9** WHILE el jugador mantenga `block` teniendo el disco, THE SYSTEM SHALL alzar el disco como escudo frontal orientado a la dirección de apuntado: bloquea proyectiles y ataques cuerpo a cuerpo frontales sin recibir daño.
- **2.10** WHILE bloquea, THE SYSTEM SHALL reducir la velocidad de movimiento al 40% e impedir lanzar (hay que soltar `block` para atacar). Trade-off deliberado.
- **2.11** WHEN un proyectil impacte el escudo dentro de los primeros 0.15s tras pulsar `block` (**parry perfecto**), THE SYSTEM SHALL reflejar el proyectil hacia la dirección de apuntado con daño ×2, slow-motion breve y VFX distintivo.
- **2.12** WHEN un bloqueo normal (no parry) absorba un golpe, THE SYSTEM SHALL aplicar knockback leve al jugador y micro screen-shake; el bloqueo no consume recursos en v1.0.
- **2.13** El estado del disco (en mano / fuera / bloqueando) SHALL ser legible de un vistazo: pose del personaje + icono en HUD.

## Criterio de aceptación (CHECKPOINT CRÍTICO)
Jugar 10 minutos en la arena solo lanzando, rebotando, bloqueando y haciendo parry a proyectiles de un dummy debe ser divertido por sí mismo. Si no lo es, se itera aquí antes de continuar.
