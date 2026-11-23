extends Node2D
## Script de la raiz "Scene_Game": arranca y cierra la partida.
## 1) Se construye el mapa 1  ->  2) Trivia inicial  ->  3) Misiones: los 6 mapas (LevelManager)
## ->  4) Llegada de los equipos de emergencia  ->  5) Trivia final  ->  6) Resumen y final.

const TITLE_SCENE: String = "res://Scenes/UI/title_screen.tscn"

var _level_manager: LevelManager


func _ready() -> void:
	GameManager.reset_game()
	await get_tree().process_frame

	_level_manager = LevelManager.new()
	_level_manager.final_quiz_requested.connect(_on_final_quiz)
	_level_manager.quit_to_title.connect(go_to_title)
	_level_manager.play_again.connect(_on_play_again)
	add_child(_level_manager)
	_level_manager.prepare()          # el mapa 1 se ve detras de la trivia

	await _run_pre_quiz()
	add_child(GameHUD.new())          # puntaje, bombas y mensajes
	_level_manager.begin()            # muestra la mision del mapa 1 y empieza a jugar


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


## La llama la zona meta (goal_zone.gd) cuando el jugador entra en ella.
func finish_mission() -> void:
	if _level_manager != null:
		_level_manager.try_finish()


func _on_final_quiz() -> void:
	var extra := "Antes: %d/%d.  Puntaje: %d.  Edificios despejados: %d.  Personas a salvo: %d.\n\"No se trata de destruir lo que quedó, sino de construir una oportunidad para empezar de nuevo.\"" % [
		GameManager.pre_correct, GameManager.total_questions, GameManager.score,
		GameManager.get_stat("bld_cleared"), GameManager.get_stat("civ_saved")
	]
	var quiz := TriviaUI.new()
	quiz.setup("Trivia final", TriviaData.QUESTIONS, extra, Color("ff9f1c"))
	add_child(quiz)
	var result: Array = await quiz.finished
	GameManager.post_correct = result[0]
	print("Trivia: antes %d/%d -> despues %d/%d" % [
		GameManager.pre_correct, GameManager.total_questions, GameManager.post_correct, result[1]
	])
	_level_manager.final_quiz_done.emit()


func _on_play_again() -> void:
	GameManager.stop_music(0.4)
	get_tree().reload_current_scene()


func go_to_title() -> void:
	GameManager.stop_music(0.8)
	if ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file(TITLE_SCENE)
