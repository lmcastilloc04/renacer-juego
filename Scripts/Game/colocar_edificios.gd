@tool
extends EditorScript
## ============================================================
##  COLOCAR EDIFICIOS - pone los 4 edificios sobre los lotes del mapa
## ============================================================
## Esta version NO usa building.tscn: arma cada edificio por codigo
## (cuerpo + colision) y le asigna el script building.gd. El dibujo lo hace el propio script.
##
## COMO USARLO:
##   1) Abre Scenes/node_2d.tscn en el editor (y cierra la pestana "Building" si la tienes abierta).
##   2) Con ESTE script abierto: Archivo > Ejecutar (Ctrl+Shift+X).
##   3) Revisa la pestana Salida: debe decir "Edificios colocados: 4".
##   4) Guarda la escena (Ctrl+S).
## Puedes ejecutarlo varias veces: reemplaza los edificios con el mismo nombre.
##
## COMO EDITARLO:
##   Cambia "pisos" (1 a 3) o "seguro" (true/false) en la lista de abajo.
##   Tambien puedes seleccionar un edificio y cambiar Floors / Safe To Demolish en el Inspector.

## Ruta del script del edificio (cambiala si lo moviste de carpeta).
const SCRIPT_EDIFICIO: String = "res://Scripts/Game/building.gd"

## "pos" = centro del lote, en coordenadas de Scene_Game.
const EDIFICIOS: Array[Dictionary] = [
	{"nombre": "Edificio_A1", "pos": Vector2(-224, 1440), "pisos": 1, "seguro": true},
	{"nombre": "Edificio_A2", "pos": Vector2(-96, 1440), "pisos": 2, "seguro": true},
	{"nombre": "Edificio_B1", "pos": Vector2(24, 1440), "pisos": 3, "seguro": true},
	{"nombre": "Edificio_B2", "pos": Vector2(112, 1440), "pisos": 2, "seguro": false},
]


func _run() -> void:
	var raiz: Node = get_scene()
	if raiz == null:
		push_error("Abre primero la escena node_2d.tscn y vuelve a ejecutar el script.")
		return
	var script := load(SCRIPT_EDIFICIO) as Script
	if script == null:
		push_error("No puedo cargar " + SCRIPT_EDIFICIO + ". Revisa la ruta de SCRIPT_EDIFICIO (clic derecho en el archivo > Copiar ruta).")
		return

	var colocados: int = 0
	for datos in EDIFICIOS:
		var nombre: String = datos["nombre"]
		var viejo := raiz.get_node_or_null(NodePath(nombre))
		if viejo != null:
			raiz.remove_child(viejo)
			viejo.free()

		var cuerpo := StaticBody2D.new()
		cuerpo.name = nombre
		cuerpo.set_script(script)
		cuerpo.set("floors", datos["pisos"])
		cuerpo.set("safe_to_demolish", datos["seguro"])
		cuerpo.position = datos["pos"]

		var colision := CollisionShape2D.new()
		colision.name = "CollisionShape2D"
		var forma := RectangleShape2D.new()
		forma.size = Vector2(48, 64)
		colision.shape = forma
		cuerpo.add_child(colision)

		raiz.add_child(cuerpo)
		# El dueño debe ser la escena para que se guarde junto con ella
		cuerpo.owner = raiz
		colision.owner = raiz
		colocados += 1

	print("Edificios colocados: ", colocados, ". Guarda la escena con Ctrl+S.")
