# Formato de `levels.json`

Cada mapa es un objeto dentro de `"levels"`. Las posiciones de **casillas** (x, y) cuentan desde la esquina
superior izquierda del mapa; una pantalla mide **16 x 11 casillas** (16 px cada una). Las posiciones en
**pixeles** (`x`, `y` de personas, edificios, zonas...) tambien son del mapa.

| Campo | Que es |
|---|---|
| `name`, `section`, `objective`, `tips`, `lesson` | Textos de la pantalla de mision y del resultado |
| `music` | `calma`, `tension` o `esperanza` |
| `bombs` | Bombas con las que empieza el mapa |
| `width` | Pantallas de ancho (2 o 3) |
| `tremors` | `[min, max]` segundos entre replicas sismicas, o `null` |
| `require` | `buildings` / `civilians`: que hay que cumplir para poder terminar |
| `start` | Casilla de inicio del jugador. `goal` = `[x, y, ancho, alto]` en casillas |
| `ops` | Terreno: `["g\|o\|d", "put\|fill\|frame\|car", ...]` (g = suelo, o = obstaculos con colision, d = decoracion) |
| `buildings` | `x`,`y` (centro, px), `floors` (1-3), `safe` (true/false) |
| `people` | `name`, `x`,`y` (pies, px), `tile`, `evac`, `path` (puntos al evacuar), `lines` |
| `signs`, `supplies`, `zones` | Senales, recursos (`points`, `bombs`) y zonas restringidas |
| `rubble` | Escombros: `x`,`y`,`w`,`h` en casillas; `route: true` = bloquean el camino |

Reglas para que el mapa sea jugable: deja libres las filas 5 a 9 en las uniones entre pantallas, y que
`bombs` + las bombas de los recursos alcance para `pisos de los edificios seguros + escombros que bloquean`.
