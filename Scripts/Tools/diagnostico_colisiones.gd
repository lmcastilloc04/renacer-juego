@tool
extends EditorScript
## ============================================================
##  DIAGNOSTICO DE COLISIONES
## ============================================================
## Para que sirve: encuentra "paredes invisibles". Apaga la colision de las capas viejas
## del mapa de Zelda (Mountain y Renacer, que estan ocultas pero siguen bloqueando)
## y cuenta cuantas casillas SOLIDAS tiene cada capa dentro de las 2 pantallas de la ciudad.
##
## COMO USARLO:
##   1) Abre Scenes/node_2d.tscn.   2) Con este script abierto: Archivo > Ejecutar.
##   3) Lee la pestana Salida.      4) Guarda la escena (Ctrl+S).
##
## Tip extra: en el menu Depurar activa "Formas de colision visibles" y juega:
## veras en azul todo lo que bloquea al jugador.

## Zona de juego (pantallas A y B) en coordenadas de Scene_Game.
const ZONA: Rect2 = Rect2(-288, 1392, 512, 176)
const CAPAS_VIEJAS: Array[String] = ["TileMapLayer_Mountain", "TileMapLayer_Renacer"]


func _run() -> void:
	var raiz: Node = get_scene()
	if raiz == null:
		push_error("Abre primero la escena node_2d.tscn y vuelve a ejecutar el script.")
		return
	print("---- DIAGNOSTICO DE COLISIONES ----")
	for hijo in raiz.get_children():
		if hijo is TileMapLayer:
			var capa := hijo as TileMapLayer
			if String(capa.name) in CAPAS_VIEJAS and capa.collision_enabled:
				capa.collision_enabled = false
				print("  * Apagada la colision de la capa vieja: ", capa.name)
			var solidas: int = 0
			for celda in capa.get_used_cells():
				var datos := capa.get_cell_tile_data(celda)
				if datos != null and datos.get_collision_polygons_count(0) > 0:
					var pos: Vector2 = capa.position + capa.map_to_local(celda)
					if ZONA.has_point(pos):
						solidas += 1
			print("  ", capa.name, " -> colision activa: ", capa.collision_enabled, " | casillas solidas en la ciudad: ", solidas)
		elif hijo is CollisionObject2D and not (hijo is CharacterBody2D):
			print("  Objeto con colision: ", hijo.name, " en ", (hijo as Node2D).position)
	print("---- Listo. Guarda la escena con Ctrl+S. ----")
