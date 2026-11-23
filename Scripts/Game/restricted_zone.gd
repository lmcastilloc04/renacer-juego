@tool
class_name RestrictedZone
extends Node2D
## Zona restringida (cinta de peligro). Si el jugador entra, pierde puntos y recibe un aviso.
## El nodo marca la ESQUINA SUPERIOR IZQUIERDA; "size" es el tamaño en pixeles.

@export var size: Vector2 = Vector2(64, 88):
	set(value):
		size = value
		queue_redraw()
@export var zone_name: String = "Zona restringida"
@export_multiline var reason: String = "Peligro de derrumbe."
@export var penalty: int = 5

const COOLDOWN: float = 4.0

var _inside: bool = false
var _cooldown: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	add_to_group("zonas")


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var inside: bool = Rect2(global_position, size).has_point(player.global_position)
	if inside and not _inside and _cooldown <= 0.0:
		_cooldown = COOLDOWN
		GameManager.add_score(-penalty, "zona restringida")
		GameManager.stat("zone_entries")
		GameManager.toast("warning", zone_name, "%s -%d puntos" % [reason, penalty])
		if player.has_method("flash_hurt"):
			player.call("flash_hurt")
	_inside = inside


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(1.0, 0.2, 0.2, 0.10))
	var pts: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		draw_line(pts[i], pts[i + 1], Color("f1f1f1"), 2.0)
		draw_dashed_line(pts[i], pts[i + 1], Color("e63946"), 2.0, 5.0)
