@tool
extends EditorScript
## ============================================================
##  CONSTRUIR MAPA - pantallas A y B de la ciudad (Renacer)
## ============================================================
## COMO USARLO:
##   1) Abre la escena Scenes/node_2d.tscn en el editor.
##   2) Con ESTE script abierto: menu  Archivo > Ejecutar  (Ctrl+Shift+X).
##   3) Guarda la escena (Ctrl+S).
## Se puede ejecutar las veces que quieras: borra y vuelve a pintar.
##
## COMO EDITARLO:
##   Cada linea de la funcion _pintar_mapa() es una instruccion:
##     _poner(capa, x, y, TILE)             -> una casilla
##     _rellenar(capa, x0, y0, x1, y1, TILE) -> un rectangulo lleno
##     _marco(capa, x, y, ancho, alto, MARCO) -> rectangulo con borde (3x3)
##   Las coordenadas x,y son del MAPA: pantalla A = x 0-15, pantalla B = x 16-31,
##   y = 0-10 (cada pantalla mide 16 x 11 casillas de 16 px).

## Casilla del mapa que corresponde a la esquina superior izquierda de la pantalla A.
const ORIGEN: Vector2i = Vector2i(-162, -1)
## Id del "source" dentro de kenney_tileset.tres (en tu TileSet es el 0).
const FUENTE: int = 0
const TAM: int = 16

# ---- Casillas del tileset (columna, fila) segun la guia de coordenadas ----
const ASFALTO: Vector2i = Vector2i(9, 16)
const RAYA: Vector2i = Vector2i(1, 16)
const ACERA: Vector2i = Vector2i(9, 1)
const PASTO: Vector2i = Vector2i(1, 1)
const ARBOL_VERDE: Vector2i = Vector2i(22, 8)
const ARBOL_VERDE2: Vector2i = Vector2i(22, 10)
const ARBOL_NARANJA: Vector2i = Vector2i(22, 11)
const ARBOL_NARANJA2: Vector2i = Vector2i(22, 13)
const BARRERA: Vector2i = Vector2i(5, 8)
const BARRERA2: Vector2i = Vector2i(6, 8)
const BASURERO: Vector2i = Vector2i(9, 9)
const BUZON: Vector2i = Vector2i(8, 11)
const FAROLA_ARRIBA: Vector2i = Vector2i(3, 6)
const FAROLA_ABAJO: Vector2i = Vector2i(3, 7)
const FAROLA_V_ARRIBA: Vector2i = Vector2i(7, 6)
const FAROLA_V_ABAJO: Vector2i = Vector2i(7, 7)
const ESCOMBRO1: Vector2i = Vector2i(0, 10)
const ESCOMBRO2: Vector2i = Vector2i(1, 10)
const ESCOMBRO3: Vector2i = Vector2i(0, 11)

# ---- Marcos 3x3: esquinas, bordes y centro (orden: sup-izq, sup, sup-der, izq, centro, der, inf-izq, inf, inf-der) ----
const MARCO_LOTE: Array[Vector2i] = [Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3), Vector2i(8, 4), Vector2i(9, 4), Vector2i(10, 4), Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5)]
const MARCO_PLAZA: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]
const MARCO_AGUA: Array[Vector2i] = [Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7), Vector2i(8, 8), Vector2i(9, 8), Vector2i(10, 8)]

# ---- Autos (ocupan 2x2 casillas; orden: sup-izq, sup-der, inf-izq, inf-der) ----
const TAXI: Array[Vector2i] = [Vector2i(15, 14), Vector2i(16, 14), Vector2i(15, 15), Vector2i(16, 15)]
const AUTO_ROJO: Array[Vector2i] = [Vector2i(15, 16), Vector2i(16, 16), Vector2i(15, 17), Vector2i(16, 17)]

## Donde empieza el jugador y la zona de meta (en casillas del mapa).
const INICIO_JUGADOR: Vector2i = Vector2i(8, 2)
const META_RECT: Rect2i = Rect2i(28, 6, 2, 3)

var _suelo: TileMapLayer
var _obst: TileMapLayer
var _deco: TileMapLayer


func _run() -> void:
	var raiz: Node = get_scene()
	if raiz == null:
		push_error("Abre primero la escena node_2d.tscn y vuelve a ejecutar el script.")
		return
	var ciudad := raiz.get_node_or_null("TileMapLayer_Ciudad") as TileMapLayer
	if ciudad == null:
		push_error("No encuentro el nodo TileMapLayer_Ciudad en la escena abierta.")
		return

	_suelo = ciudad
	_suelo.clear()
	_obst = _capa(raiz, "TileMapLayer_Obstaculos", ciudad, ciudad.get_index() + 1)
	_deco = _capa(raiz, "TileMapLayer_Decoracion", ciudad, ciudad.get_index() + 2)

	_pintar_mapa()
	_colocar_jugador_y_meta(raiz, ciudad)
	print("Mapa construido. Guarda la escena con Ctrl+S.")


## Busca la capa por nombre o la crea. Usa el mismo TileSet y posicion que la capa Ciudad.
func _capa(raiz: Node, nombre: String, ref: TileMapLayer, indice: int) -> TileMapLayer:
	var capa := raiz.get_node_or_null(nombre) as TileMapLayer
	if capa == null:
		capa = TileMapLayer.new()
		capa.name = nombre
		raiz.add_child(capa)
		capa.owner = raiz
	capa.tile_set = ref.tile_set
	capa.position = ref.position
	raiz.move_child(capa, mini(indice, raiz.get_child_count() - 1))
	capa.clear()
	return capa


func _poner(capa: TileMapLayer, x: int, y: int, tile: Vector2i) -> void:
	capa.set_cell(ORIGEN + Vector2i(x, y), FUENTE, tile)


func _rellenar(capa: TileMapLayer, x0: int, y0: int, x1: int, y1: int, tile: Vector2i) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			_poner(capa, x, y, tile)


func _marco(capa: TileMapLayer, x0: int, y0: int, ancho: int, alto: int, m: Array[Vector2i]) -> void:
	for dx in ancho:
		for dy in alto:
			var col: int = 0 if dx == 0 else (2 if dx == ancho - 1 else 1)
			var fila: int = 0 if dy == 0 else (2 if dy == alto - 1 else 1)
			_poner(capa, x0 + dx, y0 + dy, m[fila * 3 + col])


func _auto(capa: TileMapLayer, x: int, y: int, a: Array[Vector2i]) -> void:
	_poner(capa, x, y, a[0])
	_poner(capa, x + 1, y, a[1])
	_poner(capa, x, y + 1, a[2])
	_poner(capa, x + 1, y + 1, a[3])


func _pintar_mapa() -> void:
	# ---------- SUELO: aceras, calle, lotes y plaza (sin colision) ----------
	_rellenar(_suelo, 0, 0, 31, 10, ACERA)
	_rellenar(_suelo, 0, 0, 31, 0, PASTO)
	_rellenar(_suelo, 0, 10, 31, 10, PASTO)
	_rellenar(_suelo, 0, 6, 26, 8, ASFALTO)
	_poner(_suelo, 1, 7, RAYA)
	_poner(_suelo, 3, 7, RAYA)
	_poner(_suelo, 5, 7, RAYA)
	_poner(_suelo, 7, 7, RAYA)
	_poner(_suelo, 9, 7, RAYA)
	_poner(_suelo, 11, 7, RAYA)
	_poner(_suelo, 13, 7, RAYA)
	_poner(_suelo, 15, 7, RAYA)
	_poner(_suelo, 17, 7, RAYA)
	_poner(_suelo, 19, 7, RAYA)
	_poner(_suelo, 21, 7, RAYA)
	_poner(_suelo, 23, 7, RAYA)
	_poner(_suelo, 25, 7, RAYA)
	_marco(_suelo, 1, 1, 6, 4, MARCO_LOTE)
	_marco(_suelo, 9, 1, 6, 4, MARCO_LOTE)
	_marco(_suelo, 17, 1, 5, 4, MARCO_LOTE)
	_marco(_suelo, 23, 1, 4, 4, MARCO_LOTE)
	_marco(_suelo, 27, 5, 4, 5, MARCO_PLAZA)

	# ---------- OBSTACULOS: arboles, autos (pegados a la acera, la calle queda libre), barreras, agua (CON colision) ----------
	_poner(_obst, 0, 0, ARBOL_VERDE)
	_poner(_obst, 0, 10, ARBOL_VERDE2)
	_poner(_obst, 1, 0, ARBOL_NARANJA)
	_poner(_obst, 1, 10, ARBOL_NARANJA2)
	_poner(_obst, 2, 0, ARBOL_VERDE2)
	_poner(_obst, 2, 10, ARBOL_VERDE)
	_poner(_obst, 3, 0, ARBOL_NARANJA2)
	_poner(_obst, 3, 10, ARBOL_NARANJA)
	_poner(_obst, 4, 0, ARBOL_VERDE)
	_poner(_obst, 4, 10, ARBOL_VERDE2)
	_poner(_obst, 5, 0, ARBOL_NARANJA)
	_poner(_obst, 5, 10, ARBOL_NARANJA2)
	_poner(_obst, 6, 0, ARBOL_VERDE2)
	_poner(_obst, 6, 10, ARBOL_VERDE)
	_poner(_obst, 7, 0, ARBOL_NARANJA2)
	_poner(_obst, 7, 10, ARBOL_NARANJA)
	_poner(_obst, 8, 0, ARBOL_VERDE)
	_poner(_obst, 8, 10, ARBOL_VERDE2)
	_poner(_obst, 9, 0, ARBOL_NARANJA)
	_poner(_obst, 9, 10, ARBOL_NARANJA2)
	_poner(_obst, 10, 0, ARBOL_VERDE2)
	_poner(_obst, 10, 10, ARBOL_VERDE)
	_poner(_obst, 11, 0, ARBOL_NARANJA2)
	_poner(_obst, 11, 10, ARBOL_NARANJA)
	_poner(_obst, 12, 0, ARBOL_VERDE)
	_poner(_obst, 12, 10, ARBOL_VERDE2)
	_poner(_obst, 13, 0, ARBOL_NARANJA)
	_poner(_obst, 13, 10, ARBOL_NARANJA2)
	_poner(_obst, 14, 0, ARBOL_VERDE2)
	_poner(_obst, 14, 10, ARBOL_VERDE)
	_poner(_obst, 15, 0, ARBOL_NARANJA2)
	_poner(_obst, 15, 10, ARBOL_NARANJA)
	_poner(_obst, 16, 0, ARBOL_VERDE)
	_poner(_obst, 16, 10, ARBOL_VERDE2)
	_poner(_obst, 17, 0, ARBOL_NARANJA)
	_poner(_obst, 17, 10, ARBOL_NARANJA2)
	_poner(_obst, 18, 0, ARBOL_VERDE2)
	_poner(_obst, 18, 10, ARBOL_VERDE)
	_poner(_obst, 19, 0, ARBOL_NARANJA2)
	_poner(_obst, 19, 10, ARBOL_NARANJA)
	_poner(_obst, 20, 0, ARBOL_VERDE)
	_poner(_obst, 20, 10, ARBOL_VERDE2)
	_poner(_obst, 21, 0, ARBOL_NARANJA)
	_poner(_obst, 21, 10, ARBOL_NARANJA2)
	_poner(_obst, 22, 0, ARBOL_VERDE2)
	_poner(_obst, 22, 10, ARBOL_VERDE)
	_poner(_obst, 23, 0, ARBOL_NARANJA2)
	_poner(_obst, 23, 10, ARBOL_NARANJA)
	_poner(_obst, 24, 0, ARBOL_VERDE)
	_poner(_obst, 24, 10, ARBOL_VERDE2)
	_poner(_obst, 25, 0, ARBOL_NARANJA)
	_poner(_obst, 25, 10, ARBOL_NARANJA2)
	_poner(_obst, 26, 0, ARBOL_VERDE2)
	_poner(_obst, 26, 10, ARBOL_VERDE)
	_poner(_obst, 27, 0, ARBOL_NARANJA2)
	_poner(_obst, 27, 10, ARBOL_NARANJA)
	_poner(_obst, 28, 0, ARBOL_VERDE)
	_poner(_obst, 28, 10, ARBOL_VERDE2)
	_poner(_obst, 29, 0, ARBOL_NARANJA)
	_poner(_obst, 29, 10, ARBOL_NARANJA2)
	_poner(_obst, 30, 0, ARBOL_VERDE2)
	_poner(_obst, 30, 10, ARBOL_VERDE)
	_poner(_obst, 31, 0, ARBOL_NARANJA2)
	_poner(_obst, 31, 10, ARBOL_NARANJA)
	_poner(_obst, 0, 1, ARBOL_NARANJA)
	_poner(_obst, 31, 1, ARBOL_VERDE2)
	_poner(_obst, 0, 2, ARBOL_VERDE2)
	_poner(_obst, 31, 2, ARBOL_NARANJA2)
	_poner(_obst, 0, 3, ARBOL_NARANJA2)
	_poner(_obst, 31, 3, ARBOL_VERDE)
	_poner(_obst, 0, 4, ARBOL_VERDE)
	_poner(_obst, 31, 4, ARBOL_NARANJA)
	_poner(_obst, 0, 5, ARBOL_NARANJA)
	_poner(_obst, 31, 5, ARBOL_VERDE2)
	_poner(_obst, 0, 6, BARRERA)
	_poner(_obst, 31, 6, ARBOL_NARANJA2)
	_poner(_obst, 0, 7, BARRERA2)
	_poner(_obst, 31, 7, ARBOL_VERDE)
	_poner(_obst, 0, 8, BARRERA)
	_poner(_obst, 31, 8, ARBOL_NARANJA)
	_poner(_obst, 0, 9, ARBOL_NARANJA)
	_poner(_obst, 31, 9, ARBOL_VERDE2)
	_poner(_obst, 15, 1, ARBOL_NARANJA)
	_poner(_obst, 15, 2, ARBOL_VERDE2)
	_poner(_obst, 15, 3, ARBOL_NARANJA2)
	_poner(_obst, 15, 4, ARBOL_VERDE)
	_auto(_obst, 4, 5, TAXI)
	_auto(_obst, 10, 8, AUTO_ROJO)
	_auto(_obst, 21, 8, AUTO_ROJO)
	_auto(_obst, 24, 5, TAXI)
	_poner(_obst, 7, 5, BASURERO)
	_poner(_obst, 8, 5, BASURERO)
	_poner(_obst, 14, 5, BUZON)
	_poner(_obst, 3, 9, BUZON)
	_poner(_obst, 20, 9, BASURERO)
	_poner(_obst, 11, 5, BARRERA)
	_poner(_obst, 12, 5, BARRERA2)
	_poner(_obst, 21, 5, BARRERA)
	_poner(_obst, 22, 5, BARRERA2)
	_marco(_obst, 28, 1, 3, 3, MARCO_AGUA)

	# ---------- DECORACION: farolas y escombros (sin colision) ----------
	_poner(_deco, 7, 3, FAROLA_ARRIBA)
	_poner(_deco, 7, 4, FAROLA_ABAJO)
	_poner(_deco, 22, 3, FAROLA_V_ARRIBA)
	_poner(_deco, 22, 4, FAROLA_V_ABAJO)
	_poner(_deco, 9, 6, ESCOMBRO2)
	_poner(_deco, 12, 8, ESCOMBRO3)
	_poner(_deco, 7, 7, ESCOMBRO1)
	_poner(_deco, 14, 6, ESCOMBRO1)
	_poner(_deco, 19, 8, ESCOMBRO2)
	_poner(_deco, 17, 6, ESCOMBRO3)
	_poner(_deco, 26, 6, ESCOMBRO1)
	_poner(_deco, 18, 9, ESCOMBRO2)
	_poner(_deco, 6, 5, ESCOMBRO3)
	_poner(_deco, 16, 5, ESCOMBRO1)


## Mueve al jugador al inicio y ajusta la zona de meta (Area2D "Area2D" de la escena).
func _colocar_jugador_y_meta(raiz: Node, ciudad: TileMapLayer) -> void:
	var jugador := raiz.get_node_or_null("FV_player") as Node2D
	if jugador != null:
		jugador.position = _centro_de_casilla(ciudad, INICIO_JUGADOR)
	else:
		push_warning("No encuentro el nodo FV_player.")

	var meta := raiz.get_node_or_null("Area2D") as Area2D
	var forma := raiz.get_node_or_null("Area2D/CollisionShape2D") as CollisionShape2D
	if meta != null and forma != null:
		var esquina: Vector2 = ciudad.position + Vector2(ORIGEN + META_RECT.position) * TAM
		var tamano: Vector2 = Vector2(META_RECT.size) * TAM
		var rect := RectangleShape2D.new()
		rect.size = tamano
		forma.shape = rect
		forma.position = (esquina + tamano / 2.0) - meta.position
	else:
		push_warning("No encuentro Area2D/CollisionShape2D (la zona de meta).")


func _centro_de_casilla(ciudad: TileMapLayer, celda: Vector2i) -> Vector2:
	return ciudad.position + Vector2(ORIGEN + celda) * TAM + Vector2(TAM, TAM) / 2.0
