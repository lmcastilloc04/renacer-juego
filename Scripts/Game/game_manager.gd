extends Node
## Autoload "GameManager": estado global del juego (puntaje, bombas, trivia) y
## "centralita" de avisos: popups (toast), dialogos e interaccion con lo que hay cerca.

signal score_changed(new_score: int)
signal bombs_changed(new_bombs: int)
signal buildings_changed(cleared: int, total: int)
signal civilians_changed(saved: int, total: int)
## Texto del mapa actual (ej. "Mapa 2/6") para el HUD.
signal level_changed(text: String)
## Lista de objetivos del mapa: [{"text": String, "done": bool, "goal": bool}, ...]
signal objectives_changed(items: Array)
## Popup corto. kind: "info", "success", "warning" o "error". Si title va vacio se usa uno por defecto.
signal toast_requested(kind: String, title: String, text: String)
## Globo de dialogo junto a "source" (persona, senal o edificio). portrait = casilla del tileset
## (Vector2i(-1, -1) = sin retrato). El globo desaparece si el jugador se aleja.
signal dialog_requested(speaker: String, text: String, portrait: Vector2i, source: Node2D)

const START_BOMBS: int = 8
## Distancia maxima (px) para interactuar con personas, senales y objetos.
const RANGE_OBJECT: float = 24.0
## Distancia maxima (px) al borde de un edificio para evaluarlo.
const RANGE_BUILDING: float = 40.0

var score: int = 0
var pre_correct: int = -1      # aciertos en la trivia inicial
var post_correct: int = -1     # aciertos en la trivia final
var total_questions: int = 0
var mission_finished: bool = false
var bombs: int = START_BOMBS
var buildings_cleared: int = 0
var civilians_saved: int = 0
var civilians_injured: int = 0
var level_label: String = ""
## Objetivos del mapa y la META (para el panel de objetivos y la flecha del HUD).
var objectives: Array = []
var goal_ready: bool = false
var goal_world: Vector2 = Vector2.ZERO
var goal_label: String = "META"
## Contadores de decisiones del jugador (se usan en los resumenes y la retroalimentacion).
var stats: Dictionary = {}
var audio: AudioBank


func _ready() -> void:
	audio = AudioBank.new()
	add_child(audio)


## Tecla M: enciende o apaga la musica de fondo.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_M:
		var on: bool = audio.toggle_music()
		toast("info", "Música", "Activada" if on else "Silenciada", "")


func add_score(points: int, reason: String = "") -> void:
	score += points
	score_changed.emit(score)
	if reason != "":
		print("[Puntaje] %+d -> %s (total %d)" % [points, reason, score])


# ------------------------------------------------------------------ sonido
## Efecto de sonido (ver Assets/Audio/sfx). Ej: GameManager.sfx("explosion")
func sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	audio.sfx(sound, volume_db, pitch)


## Musica de fondo en bucle (ver Assets/Audio/music): "calma", "tension" o "esperanza".
func play_music(track: String, fade: float = 1.2) -> void:
	audio.play_music(track, fade)


func stop_music(fade: float = 1.0) -> void:
	audio.stop_music(fade)


# ------------------------------------------------------------------ avisos
## sound: "auto" = sonido segun el tipo de popup; "" = en silencio; o el nombre de un efecto.
func toast(kind: String, title: String, text: String = "", sound: String = "auto") -> void:
	toast_requested.emit(kind, title, text)
	if sound == "auto":
		match kind:
			"success":
				sfx("success", -2.0)
			"warning":
				sfx("warning", -3.0)
			"error":
				sfx("error", -1.0)
	elif sound != "":
		sfx(sound)


## Version corta (compatible con el codigo anterior): el color decide el tipo de popup.
func say(text: String, color: Color = Color.WHITE) -> void:
	toast(_kind_for_color(color), "", text)


func show_dialog(speaker: String, text: String, portrait: Vector2i = Vector2i(-1, -1), source: Node2D = null) -> void:
	dialog_requested.emit(speaker, text, portrait, source)
	sfx("dialog", -4.0, randf_range(0.92, 1.12))


func _kind_for_color(c: Color) -> String:
	if c.is_equal_approx(Color("06d6a0")):
		return "success"
	if c.is_equal_approx(Color("ef476f")) or c.is_equal_approx(Color.ORANGE_RED):
		return "error"
	if c.is_equal_approx(Color("ffd166")) or c.is_equal_approx(Color("ffb703")) or c.is_equal_approx(Color.YELLOW):
		return "warning"
	return "info"


# ------------------------------------------------------------------ bombas
## Gasta una bomba. Devuelve false si ya no quedan.
func use_bomb() -> bool:
	if bombs <= 0:
		return false
	bombs -= 1
	bombs_changed.emit(bombs)
	sfx("bomb_place")
	return true


func add_bombs(amount: int) -> void:
	bombs += amount
	bombs_changed.emit(bombs)


# ------------------------------------------------------------------ edificios y personas
## Cuantos edificios se pueden demoler de forma segura (los inseguros no cuentan).
func total_buildings() -> int:
	var n: int = 0
	for b in get_tree().get_nodes_in_group("edificios"):
		if b.get("safe_to_demolish") == true:
			n += 1
	return n


func building_cleared() -> void:
	buildings_cleared += 1
	stat("bld_cleared")
	buildings_changed.emit(buildings_cleared, total_buildings())


## Cuantas personas hay que evacuar en el mapa.
func total_civilians() -> int:
	return get_tree().get_nodes_in_group("civiles").size()


func civilian_saved() -> void:
	civilians_saved += 1
	stat("civ_saved")
	civilians_changed.emit(civilians_saved, total_civilians())


func civilian_hurt() -> void:
	civilians_injured += 1
	stat("civ_injured")


# ------------------------------------------------------------------ estadisticas y mapas
func stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func get_stat(key: String) -> int:
	return int(stats.get(key, 0))


func set_objectives(items: Array, all_done: bool) -> void:
	objectives = items
	goal_ready = all_done
	objectives_changed.emit(items)


func set_level_label(text: String) -> void:
	level_label = text
	level_changed.emit(text)


## Al empezar un mapa: bombas del mapa y contadores del mapa en cero.
func reset_level_counters(start_bombs: int) -> void:
	bombs = start_bombs
	buildings_cleared = 0
	civilians_saved = 0
	civilians_injured = 0
	bombs_changed.emit(bombs)
	refresh_counters()


func refresh_counters() -> void:
	buildings_changed.emit(buildings_cleared, total_buildings())
	civilians_changed.emit(civilians_saved, total_civilians())


# ------------------------------------------------------------------ interaccion (tecla F)
## Devuelve lo que el jugador puede usar desde "from": primero personas/objetos cercanos,
## y si no hay, el edificio mas cercano. Null si no hay nada a mano.
func find_target(from: Vector2) -> Node:
	var best: Node = null
	var best_d: float = RANGE_OBJECT
	for o in get_tree().get_nodes_in_group("interactuables"):
		if not o.has_method("can_interact") or not o.call("can_interact"):
			continue
		var d: float = (o as Node2D).global_position.distance_to(from)
		if d <= best_d:
			best_d = d
			best = o
	if best != null:
		return best

	best_d = RANGE_BUILDING
	for b in get_tree().get_nodes_in_group("edificios"):
		if not b.has_method("distance_to_rect"):
			continue
		var d2: float = b.call("distance_to_rect", from)
		if d2 <= best_d:
			best_d = d2
			best = b
	return best


func reset_game() -> void:
	score = 0
	pre_correct = -1
	post_correct = -1
	total_questions = 0
	mission_finished = false
	bombs = START_BOMBS
	buildings_cleared = 0
	civilians_saved = 0
	civilians_injured = 0
	goal_ready = false
	objectives = []
	stats.clear()
	score_changed.emit(score)
	bombs_changed.emit(bombs)
