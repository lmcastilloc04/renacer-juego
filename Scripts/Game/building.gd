@tool
class_name Building
extends StaticBody2D
## Edificio demolible, DANADO por el terremoto. Cada edificio tiene una ALTURA (pisos) que decide:
##   - cuantas cargas (bombas) necesita para caer = numero de pisos
##   - que tan lejos debe estar el jugador al caer = radio de peligro (circulo rojo)
## Algunos edificios NO son seguros de demoler (estructura comprometida): se ven mas
## destruidos y ladeados. Hay que evaluarlos (tecla F) y dejarlos en pie.
## Antes de demoler hay que EVACUAR a las personas que esten dentro del radio de peligro.
## Al editar "Floors" o "Safe To Demolish" en el Inspector se actualiza en el editor.
##
## El edificio se DIBUJA por codigo con piezas del tileset (techo, ventanas, puerta).

const TEXTURE: Texture2D = preload("res://Assets/Kenney/tilemap_packed.png")

const WIDTH: float = 48.0
const ROOF_H: float = 24.0
const FLOOR_H: float = 16.0
## Parte baja del edificio, respecto al centro del lote (el edificio "crece" hacia arriba).
const BASE_Y: float = 30.0

## Recorte del techo en tilemap_packed.png segun los pisos (columna x, fila y en pixeles).
const ROOF_X: Dictionary = {1: 272.0, 2: 272.0, 3: 320.0}
const ROOF_Y: Dictionary = {1: 64.0, 2: 0.0, 3: 0.0}
const WALL_COLORS: Dictionary = {1: Color("e9d8a6"), 2: Color("e0b0a0"), 3: Color("b8b5d6")}
const OUTLINE_COLOR: Color = Color("4a3f5c")
const DARK_COLOR: Color = Color("2b2233")    # huecos en el techo
const HOLE_COLOR: Color = Color("1c172b")    # ventanas rotas
const CRACK_COLOR: Color = Color("331f26")
const WINDOW_TILE: Vector2i = Vector2i(13, 13)
const DOOR_TILE: Vector2i = Vector2i(13, 10)
const DOOR_OPEN_TILE: Vector2i = Vector2i(13, 11)
## Estado de cada ventana segun un numero 0-4: 0 entera, 1 rota, 2 hueco.
const WINDOW_STATES: Array = [0, 1, 0, 2, 1]

enum State { STANDING, RUBBLE }

@export_range(1, 3) var floors: int = 1:
	set(value):
		floors = clampi(value, 1, 3)
		_refresh()
@export var safe_to_demolish: bool = true:
	set(value):
		safe_to_demolish = value
		_refresh()
@export_multiline var unsafe_reason: String = "Estructura comprometida: requiere un especialista."

var state: State = State.STANDING
var evaluated: bool = false
var hits: int = 0
var _unsafe_warned: bool = false
var _shake_offset: Vector2 = Vector2.ZERO

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("edificios")
	_refresh()


## Alto total del edificio en pixeles (techo + pisos).
func building_height() -> float:
	return ROOF_H + FLOOR_H * float(floors)


## Rectangulo del edificio, en coordenadas locales.
func _rect() -> Rect2:
	var h: float = building_height()
	return Rect2(-WIDTH / 2.0, BASE_Y - h, WIDTH, h)


## Centro del edificio en coordenadas globales.
func center() -> Vector2:
	return global_position + _rect().get_center()


## Radio (px) alrededor del centro del edificio donde hay peligro al caer.
func danger_radius() -> float:
	return 48.0 + 16.0 * float(floors)


## Distancia desde un punto hasta el borde del edificio (0 si esta dentro).
func distance_to_rect(point: Vector2) -> float:
	var local: Vector2 = point - global_position
	var r: Rect2 = _rect()
	var dx: float = maxf(maxf(r.position.x - local.x, local.x - r.end.x), 0.0)
	var dy: float = maxf(maxf(r.position.y - local.y, local.y - r.end.y), 0.0)
	return Vector2(dx, dy).length()


## Personas aun sin evacuar dentro del radio de peligro.
func _civilians_near() -> Array:
	var out: Array = []
	for c in get_tree().get_nodes_in_group("civiles"):
		if c.get("evacuated") == false and c.get("injured") == false:
			if (c as Node2D).global_position.distance_to(center()) <= danger_radius():
				out.append(c)
	return out


# ---------------------------------------------------------------- interaccion (tecla F)
func get_prompt() -> String:
	if state != State.STANDING:
		return "Escombros"
	return "Ver evaluación" if evaluated else "Evaluar"


## Punto (global) sobre el que se muestra el globo de dialogo o la etiqueta "F".
func get_bubble_anchor() -> Vector2:
	return global_position + Vector2(0.0, _rect().position.y - 4.0)


func interact() -> void:
	evaluate()


## El jugador inspecciona el edificio.
func evaluate() -> void:
	if state != State.STANDING:
		GameManager.show_dialog("Escombros", "Aquí ya solo quedan escombros.", Vector2i(-1, -1), self)
		return
	var first_time: bool = not evaluated
	GameManager.sfx("evaluate", -2.0)
	evaluated = true
	queue_redraw()
	if safe_to_demolish:
		if first_time:
			GameManager.add_score(10, "evaluar edificio")
		var text: String = "%d piso(s): necesita %d carga(s). Sal del círculo rojo al detonar." % [floors, floors]
		var near: int = _civilians_near().size()
		if near > 0:
			text += " ¡Hay %d persona(s) cerca: evacúalas!" % near
		GameManager.show_dialog("Evaluación", text, Vector2i(-1, -1), self)
	else:
		if first_time:
			GameManager.add_score(25, "detectar estructura comprometida")
			GameManager.stat("unsafe_detected")
		GameManager.show_dialog("Evaluación", unsafe_reason + " NO lo demuelas.", Vector2i(-1, -1), self)


## Llamado por la bomba cuando la explosion alcanza al edificio.
func receive_blast() -> void:
	if state != State.STANDING:
		return
	_shake()
	if not safe_to_demolish:
		if not _unsafe_warned:
			_unsafe_warned = true
			GameManager.add_score(-40, "demolicion insegura")
			GameManager.stat("unsafe_attempts")
			GameManager.toast("error", "Demolición insegura", "Estructura comprometida. -40 puntos")
		return
	hits += 1
	if hits < floors:
		GameManager.toast("warning", "Daño %d/%d" % [hits, floors], "Faltan %d carga(s)." % (floors - hits), "")
		return
	_collapse()


func _collapse() -> void:
	state = State.RUBBLE
	GameManager.sfx("collapse")
	_shape.set_deferred("disabled", true)

	var points: int = 0
	var text: String = ""
	if evaluated:
		points = 40 * floors
		text = "Lo evaluaste antes. +%d puntos" % points
		GameManager.stat("eval_before")
	else:
		GameManager.stat("demo_no_eval")
		points = 15 * floors - 25
		text = "No lo evaluaste. %+d puntos" % points
	GameManager.add_score(points, "demolicion")
	GameManager.toast("success" if evaluated else "warning", "Edificio despejado", text, "")

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(center()) <= danger_radius():
		GameManager.add_score(-30, "demasiado cerca al caer")
		GameManager.stat("too_close")
		GameManager.toast("error", "¡Demasiado cerca!", "Estabas en el círculo rojo. -30")
		if player.has_method("flash_hurt"):
			player.call("flash_hurt")

	var hurt: Array = _civilians_near()
	if hurt.size() > 0:
		GameManager.add_score(-50 * hurt.size(), "personas en zona de peligro")
		GameManager.toast("error", "¡Había personas en la zona!", "Debiste evacuarlas. -%d puntos" % (50 * hurt.size()))
		for c in hurt:
			c.call("hit_by_collapse")

	GameManager.building_cleared()
	_refresh()


# ---------------------------------------------------------------- dibujo
func _refresh() -> void:
	if not is_node_ready():
		return
	# La colision se ajusta a la altura del edificio
	var r: Rect2 = _rect()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	_shape.shape = shape
	_shape.position = r.get_center()
	# Versiones anteriores usaban un Sprite2D: ya no hace falta, lo ocultamos si existe
	var old_sprite := get_node_or_null("Sprite2D") as Node2D
	if old_sprite != null:
		old_sprite.visible = false
	queue_redraw()


func _shake() -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_callback(_set_shake.bind(Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))))
		tw.tween_interval(0.04)
	tw.tween_callback(_set_shake.bind(Vector2.ZERO))


func _set_shake(value: Vector2) -> void:
	_shake_offset = value
	queue_redraw()


func _tile(dest: Vector2, tile: Vector2i) -> void:
	draw_texture_rect_region(TEXTURE, Rect2(dest, Vector2(16, 16)), Rect2(Vector2(tile) * 16.0, Vector2(16, 16)))


func _poly(origin: Vector2, pts: Array, color: Color) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(origin + (p as Vector2))
	draw_colored_polygon(arr, color)


func _crack(origin: Vector2, pts: Array) -> void:
	var arr := PackedVector2Array()
	for p in pts:
		arr.append(origin + (p as Vector2))
	draw_polyline(arr, CRACK_COLOR, 1.0)


func _draw() -> void:
	if state == State.RUBBLE:
		_draw_rubble()
		return

	var h: float = building_height()
	var severe: bool = not safe_to_demolish
	# El edificio inseguro se ve ladeado (inclinado 2.5 grados desde la base)
	var tilt: float = deg_to_rad(2.5) if severe else 0.0
	draw_set_transform(Vector2(0.0, BASE_Y), tilt, Vector2.ONE)
	_draw_body(Vector2(-WIDTH / 2.0, -h) + _shake_offset, h, severe)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_overlay()


func _draw_body(top: Vector2, h: float, severe: bool) -> void:
	var rx: float = float(ROOF_X[floors])
	var ry: float = float(ROOF_Y[floors])
	# Techo: franja superior + 8 px de alero, con huecos por el sismo
	draw_texture_rect_region(TEXTURE, Rect2(top, Vector2(WIDTH, 16)), Rect2(rx, ry, WIDTH, 16))
	draw_texture_rect_region(TEXTURE, Rect2(top + Vector2(0, 16), Vector2(WIDTH, 8)), Rect2(rx, ry + 56.0, WIDTH, 8))
	_poly(top, [Vector2(34, 0), Vector2(48, 0), Vector2(48, 9), Vector2(42, 5), Vector2(38, 10)], DARK_COLOR)
	if severe:
		_poly(top, [Vector2(30, 0), Vector2(48, 0), Vector2(48, 14), Vector2(40, 8), Vector2(36, 15), Vector2(33, 7)], DARK_COLOR)
		_poly(top, [Vector2(0, 0), Vector2(9, 0), Vector2(5, 8), Vector2(0, 11)], DARK_COLOR)

	# Pared (mas oscura mientras mas dañada)
	var wall := Rect2(top + Vector2(0, ROOF_H), Vector2(WIDTH, FLOOR_H * float(floors)))
	var wall_color: Color = WALL_COLORS[floors]
	draw_rect(wall, wall_color.darkened(0.3 if severe else 0.15))
	draw_rect(wall, OUTLINE_COLOR, false, 1.0)
	draw_line(wall.position, wall.position + Vector2(WIDTH, 0), Color("6e5a64"), 1.0)

	# Ventanas (algunas rotas o vacias) y puerta en la planta baja
	var variant_seed: int = floori(absf(position.x) / 16.0)
	for f in floors:
		var y: float = wall.position.y + FLOOR_H * float(f)
		var ground: bool = f == floors - 1
		for c in 3:
			var cell := Vector2(wall.position.x + 16.0 * float(c), y)
			if ground and c == 1:
				_tile(cell, DOOR_OPEN_TILE if severe else DOOR_TILE)
				continue
			_tile(cell, WINDOW_TILE)
			var n: int = (f * 3 + c * 5 + floors * 2 + variant_seed + (1 if severe else 0)) % 5
			var wstate: int = WINDOW_STATES[n]
			if severe and wstate == 0:
				wstate = 2
			if wstate == 1:
				_poly(cell, [Vector2(4, 4), Vector2(12, 4), Vector2(12, 8), Vector2(8, 7), Vector2(7, 12), Vector2(4, 12)], HOLE_COLOR)
			elif wstate == 2:
				draw_rect(Rect2(cell + Vector2(4, 4), Vector2(8, 8)), HOLE_COLOR)

	# Grietas
	var o: Vector2 = wall.position
	var tall: bool = floors > 1
	_crack(o, [Vector2(10, 2), Vector2(14, 10), Vector2(11, 16)] + ([Vector2(17, 24)] if tall else []))
	if severe:
		_crack(o, [Vector2(34, 0), Vector2(31, 7), Vector2(36, 14)] + ([Vector2(32, 22)] if tall else []))
		_crack(o, [Vector2(2, 6), Vector2(8, 12)] + ([Vector2(6, 20)] if tall else []))

	# Escombros en las esquinas de la base
	_tile(top + Vector2(-9, h - 10), Vector2i(1, 10))
	_tile(top + Vector2(WIDTH - 8, h - 9), Vector2i(0, 11))


func _draw_overlay() -> void:
	var r: Rect2 = _rect()
	# Etiqueta de altura: "?" hasta evaluar
	var font: Font = ThemeDB.fallback_font
	var label: String = "%d piso(s)" % floors if (evaluated or Engine.is_editor_hint()) else "?"
	var label_color: Color = Color.WHITE
	if evaluated and not safe_to_demolish:
		label = "NO DEMOLER"
		label_color = Color("ffb703")
	var label_pos := Vector2(-30, r.position.y - 4)
	draw_string_outline(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 60, 8, 3, Color.BLACK)
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 60, 8, label_color)
	# Circulo de peligro: aparece al evaluar (siempre visible en el editor)
	if evaluated or Engine.is_editor_hint():
		var ring: Color = Color(1.0, 0.25, 0.25, 0.85) if safe_to_demolish else Color(1.0, 0.7, 0.1, 0.85)
		draw_arc(r.get_center(), danger_radius(), 0.0, TAU, 64, ring, 1.0)


func _draw_rubble() -> void:
	# (columna, fila) del tileset -> posicion relativa a la base del edificio
	var pieces: Array = [
		[Vector2i(0, 10), Vector2(-22, -14)], [Vector2i(1, 10), Vector2(-6, -24)],
		[Vector2i(0, 11), Vector2(6, -12)], [Vector2i(1, 10), Vector2(-18, -2)],
		[Vector2i(0, 10), Vector2(8, 0)], [Vector2i(0, 11), Vector2(-6, -8)],
	]
	for p in pieces:
		var tile: Vector2i = p[0]
		var pos: Vector2 = p[1]
		_tile(pos + Vector2(0, BASE_Y - 8.0), tile)
