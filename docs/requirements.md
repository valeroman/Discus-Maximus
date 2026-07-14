# Requirements — DISCUS MAXIMUS

> Documento maestro de referencia (biblia de diseño). Las specs implementables por fase están en specs/01..07 y el roadmap de prompts en roadmap.md.

> Juego de acción arcade 2D isométrico de combate con disco. Inspirado en la mecánica clásica de discos letales, con universo, nombre y estética 100% originales.
> Motor: **Godot 4.x** · Plataformas: **Web (HTML5) + Móvil (Android/iOS)** · Estructura: **Híbrida (niveles + mejoras)**

---

## 1. Visión del producto

Un juego arcade hiperadictivo de sesiones cortas (5–10 min por mundo) donde el jugador combate en arenas isométricas usando un único disco de energía que lanza y recupera. La progresión combina **niveles diseñados** (mundos con jefes) y **mejoras seleccionables** entre niveles, con dificultad creciente.

### Pilares de diseño
1. **Un disco, una decisión**: mientras el disco viaja, el jugador está indefenso. Tensión constante.
2. **Rebotes con maestría**: matar varios enemigos en carambola es la fantasía central.
3. **"Una partida más"**: niveles de 60–120 segundos, reinicio instantáneo, progresión visible.
4. **Game feel primero**: screen shake, hit-stop, slow-motion y partículas en cada acción.

---

## 2. Requisitos funcionales (formato EARS)

### RF-1 · Movimiento del jugador
- **1.1** WHEN el jugador use WASD/flechas (PC) o joystick virtual (móvil), THE SYSTEM SHALL mover al personaje en 8 direcciones a velocidad constante con aceleración/frenado suaves.
- **1.2** WHEN el jugador toque el botón/gesto de dash, THE SYSTEM SHALL ejecutar un dash corto con 0.2s de invulnerabilidad (i-frames) y cooldown de 2s.
- **1.3** THE SYSTEM SHALL representar el mundo en perspectiva isométrica 2D con orden de dibujado correcto (Y-sort).

### RF-2 · Mecánica del disco
- **2.1** WHEN el jugador apunte (mouse en PC, arrastre/segundo stick en móvil) y lance, THE SYSTEM SHALL disparar el disco en línea recta a alta velocidad.
- **2.2** WHILE el disco viaja, THE SYSTEM SHALL impedir que el jugador lance de nuevo (el jugador queda desarmado).
- **2.3** WHEN el disco colisione con una pared, THE SYSTEM SHALL reflejarlo (rebote físico) hasta un máximo de N rebotes (base: 2, ampliable por mejoras).
- **2.4** WHEN el disco agote sus rebotes o el jugador pulse "recall", THE SYSTEM SHALL hacer que el disco regrese al jugador siguiendo una curva de retorno, dañando enemigos en el trayecto de vuelta.
- **2.5** WHEN el disco impacte a un enemigo, THE SYSTEM SHALL aplicar daño, hit-stop de ~0.05s y knockback.
- **2.6** WHEN el jugador recupere el disco, THE SYSTEM SHALL emitir feedback claro (sonido + flash del personaje).

### RF-3 · Enemigos
- **3.1** THE SYSTEM SHALL incluir al menos 4 arquetipos en v1.0:
  - **Rusher**: rápido, ataque cuerpo a cuerpo, poca vida.
  - **Lancer**: lanza su propio disco a distancia, mantiene rango.
  - **Warden**: escudo frontal; solo recibe daño por la espalda o por disco rebotado.
  - **Splitter**: al morir se divide en 2 unidades pequeñas.
- **3.2** THE SYSTEM SHALL implementar la IA con máquinas de estados (idle / chase / attack / recover / dead).
- **3.3** WHEN un enemigo muera, THE SYSTEM SHALL soltar chispas de energía (moneda) que el jugador recoge por imán de proximidad.
- **3.4** THE SYSTEM SHALL escalar vida/daño/velocidad de enemigos según el índice de mundo y nivel.

### RF-4 · Jefes
- **4.1** THE SYSTEM SHALL incluir 1 jefe por mundo (mínimo 3 jefes en v1.0), cada uno con 2–3 fases y patrones telegrafiados.
- **4.2** WHEN el jefe cambie de fase, THE SYSTEM SHALL comunicarlo con VFX + cambio de música/intensidad.

### RF-5 · Estructura híbrida (niveles + mejoras)
- **5.1** THE SYSTEM SHALL organizar el contenido en **mundos** (3 en v1.0), cada uno con **5 niveles** (4 de oleadas + 1 de jefe).
- **5.2** WHEN el jugador complete un nivel, THE SYSTEM SHALL ofrecer una elección de **1 entre 3 mejoras aleatorias** (p. ej.: +1 rebote, disco explosivo, doble disco, dash más largo, imán mayor, vida extra, disco perforante, retorno teledirigido).
- **5.3** WHEN el jugador muera, THE SYSTEM SHALL reiniciar el mundo actual desde el nivel 1 conservando solo la moneda permanente (meta-progresión).
- **5.4** THE SYSTEM SHALL permitir gastar moneda permanente en la **Forja** (menú) para desbloqueos persistentes: skins de disco, vida base +1, mejora inicial garantizada.
- **5.5** THE SYSTEM SHALL calificar cada nivel con 1–3 estrellas (tiempo, daño recibido, combo máximo).

### RF-6 · Puntuación y combos
- **6.1** WHEN el jugador elimine enemigos en una ventana de 3s, THE SYSTEM SHALL incrementar un multiplicador de combo visible.
- **6.2** WHEN el jugador elimine 2+ enemigos con un solo lanzamiento, THE SYSTEM SHALL mostrar celebración especial ("¡CARAMBOLA x3!") con slow-motion breve.

### RF-7 · Controles móviles y web
- **7.1** WHEN la plataforma sea táctil, THE SYSTEM SHALL mostrar joystick virtual izquierdo (movimiento) y gesto de arrastrar-soltar derecho (apuntar/lanzar) + botón de dash.
- **7.2** THE SYSTEM SHALL detectar la plataforma automáticamente y alternar esquema de control sin configuración manual.
- **7.3** THE SYSTEM SHALL mantener 60 FPS en gama media móvil y en navegador (Chrome/Firefox/Safari).

### RF-8 · Persistencia
- **8.1** THE SYSTEM SHALL guardar localmente (user://save.json): progreso de mundos, estrellas, moneda, desbloqueos, ajustes y mejor puntuación.
- **8.2** WHEN el juego corra en web, THE SYSTEM SHALL persistir el guardado vía el sistema de archivos virtual de HTML5 (IndexedDB).

### RF-9 · UI/UX
- **9.1** THE SYSTEM SHALL incluir: menú principal, selector de mundos/niveles, HUD (vida, combo, disco listo/fuera, moneda), pantalla de mejoras, pausa, victoria/derrota y la Forja.
- **9.2** THE SYSTEM SHALL soportar español e inglés (i18n desde el inicio).

### RF-10 · Audio y game feel
- **10.1** THE SYSTEM SHALL incluir música por mundo (loop) con capa de intensidad para jefes, y SFX para: lanzar, rebote, impacto, retorno, recogida, daño, muerte, UI.
- **10.2** THE SYSTEM SHALL aplicar screen shake escalado, hit-stop, flash de daño y partículas en todos los impactos, con opción de reducir efectos (accesibilidad).

---

## 3. Requisitos no funcionales
- **RNF-1**: Godot 4.x estable, GDScript, arquitectura por escenas + señales (sin acoplamiento directo entre sistemas).
- **RNF-2**: Build web ≤ 30 MB comprimido; carga inicial ≤ 8s en conexión media.
- **RNF-3**: Assets originales (nada de IP de terceros). Estética neón/synthwave propia.
- **RNF-4**: Todo parámetro de balance (vida, daño, velocidad, oleadas) en Resources (.tres) editables sin tocar código.
- **RNF-5**: Input remapeable; UI escalable a ratios 16:9, 18:9 y 4:3.

---

## 4. Fuera de alcance (v1.0)
- Multijugador (candidato fuerte a v2: duelos 1v1 locales/online).
- Leaderboards online (v1.1 con backend simple).
- Más de 3 mundos.

## 5. Métricas de éxito
- Sesión promedio ≥ 8 min · Retención D1 ≥ 30% (móvil) · ≥ 40% de jugadores completa el mundo 1 · Tasa de reintento tras muerte ≥ 70%.
