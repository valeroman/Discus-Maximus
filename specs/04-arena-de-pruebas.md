# SPEC 04 — Arena de pruebas: TileMapLayer isométrico con paredes

> **Status:** Aprobado
> **Depends on:** [03-capas-fisica.md](03-capas-fisica.md)
> **Date:** 2026-07-15
> **Objective:** Crear `levels/test_arena.tscn` con dos `TileMapLayer` isométricos (suelo + paredes con colisión usando la capa física `walls`) y una `Camera2D` estática, usando tiles placeholder SVG propios, para tener un espacio jugable donde probar el movimiento del jugador (tarea 1.1) y los rebotes del disco (tarea 1.4).

## Scope

**In:**

- Crear 2 tiles placeholder SVG propios (paleta synthwave del proyecto):
  - `assets/tiles/floor_tile.svg` — rombo isométrico, tono oscuro/cian tenue (suelo).
  - `assets/tiles/wall_tile.svg` — rombo isométrico, magenta/ámbar (pared), visualmente distinguible del suelo.
- Crear `assets/tiles/test_arena_tileset.tres`: un `TileSet` con `tile_shape = TILE_SHAPE_ISOMETRIC`, tamaño de grilla 128×64, con 2 tiles (suelo y pared) y 1 Physics Layer configurado con `collision_layer = walls` (bit 2) / `collision_mask = 0` (según la matriz de `specs/03-capas-fisica.md`), con el polígono de colisión (rombo completo) asignado únicamente al tile de pared.
- Crear `levels/test_arena.tscn`:
  - Nodo raíz `Node2D` llamado `TestArena`.
  - `TileMapLayer` hijo `Floor`: rellena un área interior de 12×8 tiles con el tile de suelo, `y_sort_enabled = false`.
  - `TileMapLayer` hijo `Walls`: perímetro de 1 tile de grosor rodeando el área de `Floor` (arena total 14×10 tiles) con el tile de pared, `y_sort_enabled = true`.
  - `Camera2D` hijo `Camera`: posicionada en el centro de la arena, `current = true`, zoom ajustado para que toda la arena sea visible sin recortes.
- Agregar la tarea `1.2` (ya existe en `docs/tasks.md`) — marcarla `[x]` al finalizar.

**Out of scope (para specs futuras):**

- Cualquier script (`.gd`) — ni en la arena ni en el TileSet. Esta spec es 100% escena + assets, sin lógica.
- Jugador (`player.tscn`, tarea 1.1) — la arena no lo instancia; se prueba manualmente abriendo la escena en el editor o con una escena de prueba separada.
- Pilares u obstáculos interiores — arena es un rectángulo cerrado simple (decisión ya tomada).
- Asignación de `collision_layer`/`collision_mask` para jugador, disco o enemigos — ya documentada en la matriz de la spec 03, se aplicará cuando esas escenas se creen.
- Shader de emisión neón / glow en los tiles (`design.md §4`) — placeholder plano, sin post-procesado.
- Iluminación (`CanvasModulate`, `Light2D`) o `WorldEnvironment`.
- Estética final de los tiles — son placeholders explícitos, se reemplazan en un pase de arte posterior.

## Data model

Esta spec no introduce clases GDScript nuevas, pero sí un recurso nativo de Godot (`TileSet`) y dos assets visuales. Se documentan aquí para referencia:

**`assets/tiles/test_arena_tileset.tres`** (`TileSet`):

| Propiedad        | Valor                                                                                                 |
| ---------------- | ----------------------------------------------------------------------------------------------------- |
| `tile_shape`     | `TileSet.TILE_SHAPE_ISOMETRIC`                                                                        |
| `tile_size`      | `Vector2i(128, 64)`                                                                                   |
| Physics Layers   | 1 layer: `collision_layer = 2` (bit de `walls`), `collision_mask = 0`                                 |
| Tile 0 (`floor`) | Fuente: `floor_tile.svg`. Sin polígono de colisión.                                                   |
| Tile 1 (`wall`)  | Fuente: `wall_tile.svg`. Polígono de colisión = rombo completo del tile, asignado al Physics Layer 0. |

**`levels/test_arena.tscn`** (árbol de nodos):

```
TestArena (Node2D)
├── Floor (TileMapLayer)       # tile_set = test_arena_tileset.tres, y_sort_enabled = false
│                              # celdas (1,1)..(12,8) = tile "floor" (12×8 interior)
├── Walls (TileMapLayer)       # tile_set = test_arena_tileset.tres, y_sort_enabled = true
│                              # perímetro de 1 tile: columnas 0 y 13, filas 0 y 9 = tile "wall"
└── Camera (Camera2D)          # current = true, position = centro de la arena, zoom ajustado
```

Convención de coordenadas de celda: grilla total de 14 columnas (0–13) × 10 filas (0–9). `Floor` ocupa el interior (columnas 1–12, filas 1–8); `Walls` ocupa únicamente el perímetro (columna 0, columna 13, fila 0, fila 9), dejando el interior vacío en esa capa.

## Implementation plan

1. Crear la carpeta `assets/tiles/`.
2. Crear `assets/tiles/floor_tile.svg`: rombo isométrico de 128×64, color de fondo oscuro (`#0d0221` o variante) con borde/relleno cian tenue (`#00f0ff` a baja opacidad) para dar textura sutil.
3. Crear `assets/tiles/wall_tile.svg`: rombo isométrico de 128×64, tono magenta/ámbar (`#ff2079` / `#ffb800`) claramente distinguible del suelo.
4. Abrir el proyecto en el editor de Godot para que ambos SVG se importen como `Texture2D` (import por defecto).
5. Crear `assets/tiles/test_arena_tileset.tres`: un recurso `TileSet` nuevo con `tile_shape = Isometric`, `tile_size = (128, 64)`.
6. En el `TileSet`, agregar 2 `TileSetAtlasSource` (uno por textura: `floor_tile.svg`, `wall_tile.svg`), cada uno con 1 tile.
7. Agregar 1 Physics Layer al `TileSet` con `collision_layer` = bit de `walls` (bit 2) y `collision_mask = 0` (sin bits), según la matriz de `specs/03-capas-fisica.md`.
8. En el tile de `wall_tile.svg`, dibujar el polígono de colisión (rombo completo) en el Physics Layer 0. El tile de `floor_tile.svg` no lleva polígono.
9. Crear la carpeta `levels/` y la escena `levels/test_arena.tscn` con nodo raíz `Node2D` llamado `TestArena`.
10. Agregar el hijo `TileMapLayer` llamado `Floor`, asignarle `tile_set = test_arena_tileset.tres`, `y_sort_enabled = false`, y pintar el tile "floor" en las celdas (1,1) a (12,8).
11. Agregar el hijo `TileMapLayer` llamado `Walls`, mismo `tile_set`, `y_sort_enabled = true`, y pintar el tile "wall" en el perímetro: columna 0, columna 13, fila 0, fila 9.
12. Agregar el hijo `Camera2D` llamado `Camera`, posicionarlo en el centro de la arena (usar `Floor.map_to_local()` sobre la celda central como referencia) y ajustar `zoom` hasta que toda la arena sea visible en la vista de juego (ventana por defecto), con `current = true`.
13. Abrir `test_arena.tscn` en el editor y en el modo "Play Scene" (F6) verificar que se ve el suelo, el perímetro de paredes, y que no hay errores en consola.
14. Verificar en el editor (seleccionando la capa `Walls` y activando "Visible Collision Shapes" o revisando el tile en el TileSet editor) que el polígono de colisión del tile de pared está presente y coincide con la capa física `walls`.
15. Marcar la tarea `1.2` como `[x]` en `docs/tasks.md`.

## Acceptance criteria

- [ ] Existen `assets/tiles/floor_tile.svg` y `assets/tiles/wall_tile.svg`, ambos rombos isométricos de 128×64 con colores distinguibles entre sí (paleta synthwave del proyecto).
- [ ] Existe `assets/tiles/test_arena_tileset.tres` con `tile_shape = Isometric`, `tile_size = (128, 64)`, y 2 tiles (`floor`, `wall`).
- [ ] El `TileSet` tiene exactamente 1 Physics Layer con `collision_layer` = solo el bit `walls` (bit 2) y `collision_mask = 0`.
- [ ] Solo el tile `wall` tiene polígono de colisión asignado a ese Physics Layer; el tile `floor` no tiene colisión.
- [ ] Existe `levels/test_arena.tscn` con nodo raíz `Node2D` `TestArena`, e hijos `Floor` (`TileMapLayer`), `Walls` (`TileMapLayer`) y `Camera` (`Camera2D`).
- [ ] `Floor` tiene `y_sort_enabled = false` y rellena un interior de 12×8 tiles con el tile `floor`.
- [ ] `Walls` tiene `y_sort_enabled = true` y rellena únicamente el perímetro de 1 tile alrededor del interior (arena total 14×10), con el tile `wall`. El interior de `Walls` está vacío.
- [ ] `Camera` tiene `current = true`, está posicionada en el centro de la arena, y al ejecutar la escena (F6) se ve toda la arena sin recortes.
- [ ] Al ejecutar la escena en el editor no aparecen errores ni warnings en la consola de Godot.
- [ ] Activar "Visible Collision Shapes" en el editor muestra los polígonos de colisión únicamente sobre las celdas de `Walls`, con la forma del rombo completo del tile.
- [ ] Ninguna escena de jugador, disco o enemigo fue creada, modificada ni instanciada en `test_arena.tscn`.
- [ ] `docs/tasks.md` tiene la tarea `1.2` marcada como `[x]`.

## Decisions

- **Sí:** crear tiles placeholder como SVG propios (`floor_tile.svg`, `wall_tile.svg`) en vez de usar el checker "missing texture" de Godot o un color sólido sin forma. _Razón: decisión del usuario — ya aporta algo de la estética synthwave final sin depender de herramientas externas de generación de imágenes, siguiendo el mismo enfoque que `icon.svg`._
- **Sí:** tile size 128×64 para el footprint isométrico. _Razón: decisión del usuario — buena legibilidad en móvil y menos tiles necesarios para cubrir pantalla, frente a la alternativa 64×32._
- **Sí:** arena rectangular cerrada simple, interior 12×8, sin pilares interiores. _Razón: decisión del usuario — suficiente para probar movimiento del jugador (1.1) y rebote contra el perímetro; los pilares para carambola se evalúan en la spec del disco/rebote (1.4) si hacen falta, no se adelantan aquí._
- **Sí:** colisión de paredes vía Physics Layer nativo del `TileSet` (polígono asignado al tile), no `StaticBody2D`/`CollisionShape2D` manual por instancia. _Razón: decisión del usuario — es el mecanismo nativo de Godot 4 para `TileMapLayer`, cero código y escalable si la arena crece._
- **Sí:** `y_sort_enabled = true` solo en la capa `Walls`, no en `Floor` ni en el nodo raíz. _Razón: decisión del usuario — el suelo es plano y no necesita ordenarse; las paredes sí, porque a futuro el jugador/enemigos pasarán por delante/detrás de ellas visualmente._
- **No:** wall tile con altura falsa ("fake-3D", textura más alta que el rombo simulando una pared vertical). _Razón: es un placeholder explícito — mismo tratamiento plano que el suelo, solo con otro color. El pase de arte real (con altura/perspectiva de pared) se hace después, fuera de esta spec._
- **No:** instanciar jugador, disco o cualquier entidad en esta escena. _Razón: la tarea 1.1 (jugador) aún no existe; esta arena es un espacio de prueba standalone que se abre directamente en el editor (F6) para verificar visualmente, no una escena jugable con lógica todavía._
- **No:** shader de glow neón, `Light2D` o `WorldEnvironment` en esta spec. _Razón: es efecto visual de pulido (`design.md §4`), no bloquea la prueba de movimiento/colisión; se aplicará en un pase de juice/arte posterior._

## Identified risks

- **Alineación isométrica de las celdas.** Godot calcula la posición de cada celda en pantalla a partir de `tile_shape = Isometric` y `tile_size`; si las 12×8 celdas de `Floor` no calzan visualmente sin huecos ni superposición, o el perímetro de `Walls` no encaja exacto alrededor, hay que revisar `tile_size` y el offset del atlas antes de seguir. Mitigación: verificar visualmente en el editor (paso 13 del plan) antes de marcar la tarea como completa.
- **Zoom de cámara no genérico.** El zoom fijado a mano en esta spec depende del tamaño de ventana configurado (`project.godot` no define `window/size` explícito, usa el default de Godot). Si el usuario cambia la resolución de la ventana más adelante, puede que la arena ya no se vea completa. Mitigación: no es bloqueante para esta spec (es una cámara de prueba, no la cámara final del juego); la cámara real seguirá al jugador en una spec futura.
- **Reutilización del `TileSet` entre specs futuras.** Si specs posteriores (niveles reales, `world_1..3/level_1..5.tscn`) necesitan tiles distintos (más variedad, alturas, decorado), este `TileSet` placeholder de 2 tiles puede quedar obsoleto o requerir expansión. Mitigación: no se resuelve aquí — se anota para que la spec de niveles reales decida si extiende este `TileSet` o crea uno nuevo.
