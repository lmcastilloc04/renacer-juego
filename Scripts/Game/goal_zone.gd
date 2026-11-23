extends Area2D
## Zona de meta: al entrar el jugador, termina la mision y arranca la trivia final.
## IMPORTANTE: en el Inspector, Collision > Mask debe tener marcada la capa 2 (la del jugador).
## Este nodo debe ser hijo de Scene_Game (no de una capa de mapa) y estar LEJOS del punto de inicio del jugador.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print("[Meta] tocada por: ", body.name, "  en la posicion global ", global_position)
	if GameManager.pre_correct < 0:
		# La trivia inicial aun no termino: ignorar.
		return
	if body.is_in_group("player"):
		var game := get_tree().current_scene
		if game != null and game.has_method("finish_mission"):
			game.finish_mission()
