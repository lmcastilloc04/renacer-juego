class_name GoalMarker
extends Node2D
## Marca visible de la META: zona con borde punteado, bandera y letrero.
## Es ambar mientras faltan objetivos y VERDE y brillante cuando ya se puede pasar de mapa.
## El nodo esta en la ESQUINA SUPERIOR IZQUIERDA de la zona; "size" es su tamaño en pixeles.

@export var size: Vector2 = Vector2(32, 48)
@export var label: String = "META"


func _ready() -> void:
	z_index = 3
	add_to_group("metas")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var is_ready: bool = GameManager.goal_ready
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(t * (5.0 if is_ready else 2.0))
	var col: Color = Color("06d6a0") if is_ready else Color("ffb703")

	# Relleno que late y borde punteado
	draw_rect(Rect2(Vector2.ZERO, size), Color(col.r, col.g, col.b, 0.10 + 0.16 * pulse))
	var pts: Array[Vector2] = [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y), Vector2.ZERO]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], Color(col.r, col.g, col.b, 0.95), 1.5, 4.0)

	# Bandera
	var c: Vector2 = size / 2.0
	draw_line(c + Vector2(0, 10), c + Vector2(0, -14), Color("f1f1f1"), 1.5)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(12, -10), c + Vector2(0, -6)]), col)

	# Letrero
	var font: Font = ThemeDB.fallback_font
	var text: String = ("¡" + label + "!") if is_ready else label
	var pos := Vector2(0, -4)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, 3, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, col)
