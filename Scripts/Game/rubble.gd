class_name Rubble
extends StaticBody2D
## Escombros que bloquean el paso. Son SOLIDOS: el jugador no los atraviesa.
## Se retiran con una bomba colocada cerca (retiro controlado de escombros).
## El nodo marca la ESQUINA SUPERIOR IZQUIERDA; "size_cells" es el tamaño en casillas.

const TEXTURE: Texture2D = preload("res://Assets/Kenney/tilemap_packed.png")
const PIECES: Array[Vector2i] = [Vector2i(0, 10), Vector2i(1, 10), Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 10)]

@export var size_cells: Vector2i = Vector2i(2, 5)
## true = bloquea la ruta hacia la meta (hay que retirarlo si o si)
@export var route: bool = true
@export var reward_points: int = 10

var cleared: bool = false
var _pieces: Array = []
var _fade: float = 1.0


func _ready() -> void:
	add_to_group("escombros")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size_cells) * 16.0
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = shape.size / 2.0
	add_child(col)
	# Montón de piezas, siempre igual para el mismo lugar
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(position)
	for cx in size_cells.x:
		for cy in size_cells.y:
			for k in 2:
				_pieces.append([PIECES[rng.randi() % PIECES.size()], Vector2(cx * 16 + rng.randi_range(-3, 3), cy * 16 + rng.randi_range(-3, 3))])
	queue_redraw()


func get_rect() -> Rect2:
	return Rect2(global_position, Vector2(size_cells) * 16.0)


## Distancia desde un punto hasta el borde de los escombros (0 si esta dentro).
func distance_to_rect(point: Vector2) -> float:
	var r: Rect2 = get_rect()
	var dx: float = maxf(maxf(r.position.x - point.x, point.x - r.end.x), 0.0)
	var dy: float = maxf(maxf(r.position.y - point.y, point.y - r.end.y), 0.0)
	return Vector2(dx, dy).length()


## Una bomba exploto cerca: los escombros se retiran.
func receive_blast() -> void:
	if cleared:
		return
	cleared = true
	remove_from_group("escombros")
	for c in get_children():
		if c is CollisionShape2D:
			(c as CollisionShape2D).set_deferred("disabled", true)
	GameManager.add_score(reward_points, "retirar escombros")
	GameManager.stat("rubble_cleared")
	GameManager.toast("success", "Camino despejado", "Retiraste los escombros. +%d puntos" % reward_points, "")
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, 0.5)
	tw.tween_callback(queue_free)


func _set_fade(value: float) -> void:
	_fade = value
	queue_redraw()


func _draw() -> void:
	for p in _pieces:
		var tile: Vector2i = p[0]
		var pos: Vector2 = p[1]
		draw_texture_rect_region(TEXTURE, Rect2(pos, Vector2(16, 16)), Rect2(Vector2(tile) * 16.0, Vector2(16, 16)), Color(1, 1, 1, _fade))
