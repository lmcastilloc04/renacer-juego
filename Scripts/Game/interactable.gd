@tool
class_name Interactable
extends Node2D
## Cosas con las que el jugador interactua con la tecla F. Se dibujan por codigo con
## casillas del tileset (no necesitan escena ni Sprite2D). Hay tres tipos:
##   PERSON : habla (dialogo). Si es "evacuable", al hablarle camina a la zona segura.
##            Si un edificio cae con una persona sin evacuar cerca, se pierden puntos.
##   SIGN   : senal informativa con un mensaje educativo.
##   SUPPLY : recurso que se recoge (da puntos y, si se configura, bombas).
## El nodo esta en los PIES del personaje/objeto (origen abajo al centro).

enum Kind { PERSON, SIGN, SUPPLY }

const TEXTURE: Texture2D = preload("res://Assets/Kenney/tilemap_packed.png")
const WALK_SPEED: float = 36.0

@export var kind: Kind = Kind.PERSON:
	set(value):
		kind = value
		queue_redraw()
@export var display_name: String = "Vecino"
## PERSON: casilla "de frente" del personaje (col 24 + fila inicial). SIGN/SUPPLY: casilla (arriba) del objeto.
@export var tile: Vector2i = Vector2i(24, 0):
	set(value):
		tile = value
		queue_redraw()
## Alto en casillas (las senales altas usan 2).
@export_range(1, 2) var tile_rows: int = 1:
	set(value):
		tile_rows = value
		queue_redraw()
## Frases del dialogo. En personas evacuables: [0] al evacuar, [1] cuando ya estan a salvo.
@export var lines: PackedStringArray = PackedStringArray()
@export var evacuable: bool = false
## Puntos por los que camina al evacuar (coordenadas locales de Scene_Game).
@export var safe_path: PackedVector2Array = PackedVector2Array()
@export var reward_points: int = 10
@export var reward_bombs: int = 0

var evacuated: bool = false
var injured: bool = false
var collected: bool = false
var _walking: bool = false
var _walk_col: int = 24
var _walk_frame: int = 0
var _walk_time: float = 0.0
var _line_index: int = 0
var _read_once: bool = false
var _walk_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	add_to_group("interactuables")
	if kind == Kind.PERSON and evacuable:
		add_to_group("civiles")


func _process(delta: float) -> void:
	if _walking:
		_walk_time += delta
		if _walk_time >= 0.18:
			_walk_time = 0.0
			_walk_frame = 1 - _walk_frame
	queue_redraw()


# ---------------------------------------------------------------- interaccion (tecla F)
func can_interact() -> bool:
	return not collected and not injured and not _walking


func get_prompt() -> String:
	match kind:
		Kind.PERSON:
			return "Hablar"
		Kind.SIGN:
			return "Leer"
	return "Recoger"


## Punto (global) sobre el que se muestra el globo de dialogo o la etiqueta "F".
func get_bubble_anchor() -> Vector2:
	var height: float = 16.0
	if kind == Kind.SIGN:
		height = 16.0 * float(tile_rows)
	return global_position + Vector2(0.0, -height - 4.0)


func interact() -> void:
	if not can_interact():
		return
	match kind:
		Kind.PERSON:
			_talk()
		Kind.SIGN:
			_read_sign()
		Kind.SUPPLY:
			_collect()


func _line(index: int, fallback: String) -> String:
	return lines[index] if lines.size() > index else fallback


func _talk() -> void:
	if evacuable:
		if evacuated:
			GameManager.show_dialog(display_name, _line(1, "Ya estoy a salvo, ¡gracias por ayudarme!"), tile, self)
		else:
			GameManager.show_dialog(display_name, _line(0, "¡Gracias! Me voy a la zona segura."), tile, self)
			_start_evacuation()
		return
	var text: String = "..."
	if lines.size() > 0:
		text = lines[_line_index % lines.size()]
	_line_index += 1
	GameManager.show_dialog(display_name, text, tile, self)


func _read_sign() -> void:
	GameManager.show_dialog(display_name, _line(0, ""), tile, self)
	if not _read_once:
		_read_once = true
		GameManager.stat("signs_read")
		GameManager.add_score(reward_points, "leer senal")
		GameManager.toast("success", "Aprendiste algo", "+%d puntos" % reward_points)


func _collect() -> void:
	collected = true
	GameManager.stat("supplies")
	GameManager.add_score(reward_points, "recuperar recurso")
	if reward_bombs > 0:
		GameManager.add_bombs(reward_bombs)
	var gain: String = "+%d puntos" % reward_points
	if reward_bombs > 0:
		gain = "+%d bomba, +%d puntos" % [reward_bombs, reward_points]
	GameManager.toast("success", display_name, gain, "pickup")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(hide)


# ---------------------------------------------------------------- evacuacion
func _start_evacuation() -> void:
	_walking = true
	_walk_tween = create_tween()
	var prev: Vector2 = position
	for p in safe_path:
		var target: Vector2 = p
		_walk_tween.tween_callback(_face.bind(target - prev))
		_walk_tween.tween_property(self, "position", target, maxf(prev.distance_to(target) / WALK_SPEED, 0.05))
		prev = target
	_walk_tween.tween_callback(_on_arrived)


func _face(dir: Vector2) -> void:
	if absf(dir.x) > absf(dir.y):
		_walk_col = 26 if dir.x > 0.0 else 23
	else:
		_walk_col = 24 if dir.y > 0.0 else 25


func _on_arrived() -> void:
	_walking = false
	evacuated = true
	GameManager.civilian_saved()
	GameManager.add_score(reward_points, "evacuar persona")
	GameManager.toast("success", "Persona a salvo", "%s está a salvo. +%d" % [display_name, reward_points], "saved")


## Un edificio cayo con esta persona dentro del radio de peligro.
func hit_by_collapse() -> void:
	if evacuated or injured:
		return
	injured = true
	GameManager.civilian_hurt()
	_walking = false
	if _walk_tween != null:
		_walk_tween.kill()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(hide)


# ---------------------------------------------------------------- dibujo
func _draw() -> void:
	match kind:
		Kind.PERSON:
			_draw_person()
		Kind.SIGN:
			_draw_sign()
		Kind.SUPPLY:
			_draw_supply()


func _shadow() -> void:
	draw_set_transform(Vector2(0.0, -1.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tile(col: int, row: int, dest: Vector2) -> void:
	draw_texture_rect_region(TEXTURE, Rect2(dest, Vector2(16, 16)), Rect2(Vector2(col, row) * 16.0, Vector2(16, 16)))


func _draw_person() -> void:
	_shadow()
	var col: int = tile.x
	var row: int = tile.y
	if _walking:
		col = _walk_col
		row = tile.y + 1 + _walk_frame
	_draw_tile(col, row, Vector2(-8, -16))
	# Marcador "!" sobre quien necesita ser evacuado
	if evacuable and not evacuated and not _walking:
		var bob: float = sin(float(Time.get_ticks_msec()) / 250.0) * 1.5
		var c := Vector2(0.0, -26.0 + bob)
		draw_circle(c, 5.0, Color("ffb703"))
		draw_arc(c, 5.0, 0.0, TAU, 20, Color("2b2233"), 1.0)
		draw_line(c + Vector2(0, -2.5), c + Vector2(0, 0.5), Color("2b2233"), 1.5)
		draw_circle(c + Vector2(0, 2.5), 0.9, Color("2b2233"))


func _draw_sign() -> void:
	_shadow()
	for r in tile_rows:
		_draw_tile(tile.x, tile.y + r, Vector2(-8, -16.0 * float(tile_rows - r)))


func _draw_supply() -> void:
	_shadow()
	_draw_tile(tile.x, tile.y, Vector2(-8, -16))
	# Destello para que se note que se puede recoger
	var a: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 300.0)
	var s := Color(1.0, 0.92, 0.45, a)
	draw_line(Vector2(4, -14), Vector2(8, -14), s, 1.0)
	draw_line(Vector2(6, -16), Vector2(6, -12), s, 1.0)
