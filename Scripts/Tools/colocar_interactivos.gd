@tool
extends EditorScript
## ============================================================
##  COLOCAR INTERACTIVOS - personas, senales, recursos y zona restringida del mapa 1
## ============================================================
## COMO USARLO:
##   1) Abre Scenes/node_2d.tscn en el editor.
##   2) Con ESTE script abierto: Archivo > Ejecutar (Ctrl+Shift+X).
##   3) Revisa la pestana Salida: debe decir "Interactivos colocados".
##   4) Guarda la escena (Ctrl+S).
## Puedes ejecutarlo varias veces: reemplaza los nodos con el mismo nombre.
##
## COMO EDITARLO:
##   Cada elemento de las listas de abajo es un personaje u objeto.
##   "pos" son los PIES del personaje (coordenadas de Scene_Game); "tile" es la casilla del
##   tileset (columna, fila); "ruta" son los puntos por donde camina al evacuar.
##   Tambien puedes seleccionar cualquier nodo en la escena y editar sus propiedades en el Inspector.

const SCRIPT_INTERACTUABLE: String = "res://Scripts/Game/interactable.gd"
const SCRIPT_ZONA: String = "res://Scripts/Game/restricted_zone.gd"
const PERSONA: int = 0
const SENAL: int = 1
const RECURSO: int = 2

## Personas. evacuable=true: hay que ponerlas a salvo antes de demoler cerca de ellas.
const PERSONAS: Array[Dictionary] = [
	{"nombre": "NPC_Mora", "titulo": "Ing. Mora", "pos": Vector2(-152, 1456), "tile": Vector2i(24, 9), "evacuable": false, "ruta": [], "lineas": ["¡Bienvenido, especialista! Soy el ingeniero Mora. Antes de demoler un edificio, evalúalo con F: sabrás cuántos pisos tiene y qué tan lejos debes estar.", "Cada piso necesita una bomba. Colócalas junto al edificio con E y sal del círculo rojo antes de la última explosión.", "Revisa que no haya personas cerca. Si alguien está en la zona de peligro, habla con él para que se ponga a salvo.", "Y ojo: no todo edificio dañado se puede derribar. Si ves uno muy inclinado y agrietado, déjalo en pie y pide a un especialista."]},
	{"nombre": "NPC_Lucia", "titulo": "Vecina Lucía", "pos": Vector2(-232, 1484), "tile": Vector2i(24, 3), "evacuable": true, "ruta": [Vector2(-248, 1484), Vector2(-248, 1548)], "lineas": ["¡Gracias por venir! Mi casa se agrietó y tengo miedo de que se caiga. Me voy ahora mismo a la zona segura.", "Ya estoy a salvo. Gracias por avisarme antes de derribar el edificio."]},
	{"nombre": "NPC_Mario", "titulo": "Don Mario", "pos": Vector2(-72, 1484), "tile": Vector2i(24, 12), "evacuable": true, "ruta": [Vector2(-72, 1548)], "lineas": ["Menos mal que llegó ayuda. Me alejo del edificio por la acera de abajo, lejos de los escombros.", "Estoy a salvo. Recuerde: nunca se acerque a un edificio dañado, puede caer sin aviso."]},
	{"nombre": "NPC_Andres", "titulo": "Vecino Andrés", "pos": Vector2(24, 1484), "tile": Vector2i(24, 0), "evacuable": true, "ruta": [Vector2(24, 1548)], "lineas": ["Escuché crujidos en ese edificio de tres pisos. ¡Voy a ponerme a salvo ya mismo!", "Ya estoy lejos. Cuanto más alto es el edificio, más lejos hay que estar cuando cae."]},
	{"nombre": "NPC_Rojas", "titulo": "Inspectora Rojas", "pos": Vector2(152, 1472), "tile": Vector2i(24, 6), "evacuable": false, "ruta": [], "lineas": ["Ese edificio inclinado tiene la estructura comprometida: está agrietado y se ladea. No lo toques.", "Demolerlo sin un estudio especializado podría arrastrar a los vecinos. Evalúalo con F y déjalo en pie.", "En una emergencia real, solo personal capacitado decide qué se demuele."]},
]

## Senales informativas (dan puntos la primera vez que se leen).
const SENALES: Array[Dictionary] = [
	{"nombre": "Senal_Riesgo", "titulo": "Señal de riesgo", "pos": Vector2(-184, 1550), "tile": Vector2i(4, 6), "filas": 2, "lineas": ["ATENCIÓN: edificios dañados por el sismo. Mantén distancia: mientras más alto es el edificio, más grande es el radio de peligro."]},
	{"nombre": "Senal_ZonaSegura", "titulo": "Zona segura", "pos": Vector2(120, 1550), "tile": Vector2i(5, 6), "filas": 2, "lineas": ["PUNTO DE ENCUENTRO: zona segura para vecinos y equipos de emergencia. Despeja la calle hasta llegar aquí."]},
]

## Recursos que se pueden recoger (puntos y, a veces, bombas).
const RECURSOS: Array[Dictionary] = [
	{"nombre": "Recurso_Viveres", "titulo": "Caja de víveres", "pos": Vector2(-262, 1468), "tile": Vector2i(6, 10), "puntos": 10, "bombas": 1},
	{"nombre": "Recurso_Materiales", "titulo": "Caja de materiales", "pos": Vector2(-8, 1550), "tile": Vector2i(5, 11), "puntos": 10, "bombas": 1},
	{"nombre": "Recurso_Agua", "titulo": "Agua potable", "pos": Vector2(-24, 1484), "tile": Vector2i(10, 11), "puntos": 15, "bombas": 0},
] 

## Zona restringida (esquina superior izquierda y tamano en pixeles).
const ZONA_POS: Vector2 = Vector2(80, 1400)
const ZONA_TAMANO: Vector2 = Vector2(64, 88)


func _run() -> void:
	var raiz: Node = get_scene()
	if raiz == null:
		push_error("Abre primero la escena node_2d.tscn y vuelve a ejecutar el script.")
		return
	var script := load(SCRIPT_INTERACTUABLE) as Script
	var script_zona := load(SCRIPT_ZONA) as Script
	if script == null or script_zona == null:
		push_error("No puedo cargar interactable.gd o restricted_zone.gd. Revisa las rutas al inicio de este script.")
		return

	for d in PERSONAS:
		var n := _crear(raiz, script, d["nombre"], d["pos"])
		n.set("kind", PERSONA)
		n.set("display_name", d["titulo"])
		n.set("tile", d["tile"])
		n.set("lines", PackedStringArray(d["lineas"]))
		n.set("evacuable", d["evacuable"])
		n.set("safe_path", PackedVector2Array(d["ruta"]))
		n.set("reward_points", 15)

	for d in SENALES:
		var n := _crear(raiz, script, d["nombre"], d["pos"])
		n.set("kind", SENAL)
		n.set("display_name", d["titulo"])
		n.set("tile", d["tile"])
		n.set("tile_rows", d["filas"])
		n.set("lines", PackedStringArray(d["lineas"]))
		n.set("reward_points", 5)

	for d in RECURSOS:
		var n := _crear(raiz, script, d["nombre"], d["pos"])
		n.set("kind", RECURSO)
		n.set("display_name", d["titulo"])
		n.set("tile", d["tile"])
		n.set("reward_points", d["puntos"])
		n.set("reward_bombs", d["bombas"])

	var zona := _crear(raiz, script_zona, "Zona_Restringida", ZONA_POS)
	zona.set("size", ZONA_TAMANO)

	print("Interactivos colocados: ", PERSONAS.size() + SENALES.size() + RECURSOS.size(), " + 1 zona restringida. Guarda la escena con Ctrl+S.")


## Crea (o reemplaza) un nodo con el script dado y lo deja guardado dentro de la escena.
func _crear(raiz: Node, script: Script, nombre: String, pos: Vector2) -> Node2D:
	var viejo := raiz.get_node_or_null(NodePath(nombre))
	if viejo != null:
		raiz.remove_child(viejo)
		viejo.free()
	var nodo := Node2D.new()
	nodo.name = nombre
	nodo.set_script(script)
	nodo.position = pos
	raiz.add_child(nodo)
	nodo.owner = raiz
	return nodo
