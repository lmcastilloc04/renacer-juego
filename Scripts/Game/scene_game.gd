extends Node2D
## Script de la raiz "Scene_Game": controla el flujo del juego.
## 1) Trivia inicial  ->  2) Juego  ->  3) Trivia final (al llegar a la zona meta)  ->  4) Pantalla de inicio

const TITLE_SCENE: String = "res://Scenes/UI/title_screen.tscn"
## El jugador debe alejarse al menos esto (en px) de su punto de inicio para que cuente la meta.
const MIN_DISTANCE_TO_FINISH: float = 96.0

var _playing: bool = false
var _start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	GameManager.reset_game()
	await get_tree().process_frame
	await _run_pre_quiz()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_start_pos = player.global_position
	else:
		push_warning("No encuentro al jugador (grupo 'player').")
	_playing = true
	add_child(GameHUD.new())   # puntaje, bombas y mensajes
	GameManager.play_music("calma")   # musica de fondo de la partida
	print("[Juego] empieza la partida. Jugador en ", _start_pos)


func _run_pre_quiz() -> void:
	var quiz := TriviaUI.new()
	quiz.setup(
		"Antes de empezar",
		TriviaData.QUESTIONS,
		"Al final responderás de nuevo estas preguntas para ver cuánto aprendiste.",
		Color("4cc9f0")
	)
	add_child(quiz)
	var result: Array = await quiz.finished
	GameManager.pre_correct = result[0]
	GameManager.total_questions = result[1]


func finish_mission() -> void:
	if not _playing:
		print("[Juego] meta ignorada: la partida aun no empieza")
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var dist: float = player.global_position.distance_to(_start_pos)
		if dist < MIN_DISTANCE_TO_FINISH:
			print("[Juego] meta ignorada: el jugador casi no se ha movido (", dist, " px). Revisa que la zona meta NO este sobre el punto de inicio.")
			return
	if GameManager.mission_finished:
		return
	GameManager.mission_finished = true
	print("[Juego] mision terminada: arranca la trivia final")
	GameManager.sfx("victory")
	GameManager.play_music("esperanza", 2.0)

	var extra := "Antes: %d/%d.  Puntaje de la misión: %d.  Edificios despejados: %d.\n\"No se trata de destruir lo que quedó, sino de construir una oportunidad para empezar de nuevo.\"" % [
		GameManager.pre_correct, GameManager.total_questions, GameManager.score, GameManager.buildings_cleared
	]
	var quiz := TriviaUI.new()
	quiz.setup("Trivia final", TriviaData.QUESTIONS, extra, Color("ff9f1c"))
	add_child(quiz)
	var result: Array = await quiz.finished
	GameManager.post_correct = result[0]
	print("Trivia: antes %d/%d -> despues %d/%d" % [
		GameManager.pre_correct, GameManager.total_questions,
		GameManager.post_correct, result[1]
	])

	GameManager.stop_music(0.8)
	# Volver a la pantalla de inicio (si existe)
	if ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file(TITLE_SCENE)
