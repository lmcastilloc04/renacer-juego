class_name GameHUD
extends CanvasLayer
## Interfaz de juego, compacta:
##   - barra de estadisticas de una sola linea (arriba a la izquierda)
##   - popups (toast) pequenos abajo a la derecha, maximo 2 a la vez
##   - globo de dialogo junto al personaje/edificio, SOLO mientras el jugador esta cerca
##   - etiqueta "F  Hablar" sobre lo que se puede usar
## Como la trivia, trabaja a escala 0.5: el area virtual es el doble de la pantalla,
## asi el texto se ve nitido.

const TILESET: Texture2D = preload("res://Assets/Kenney/tilemap_packed.png")
const KIND_COLORS: Dictionary = {
	"info": Color("4cc9f0"),
	"success": Color("06d6a0"),
	"warning": Color("ffb703"),
	"error": Color("ef476f"),
}
const KIND_TITLES: Dictionary = {
	"info": "Información",
	"success": "¡Bien hecho!",
	"warning": "Atención",
	"error": "¡Cuidado!",
}
const PANEL_BG: Color = Color(0.09, 0.07, 0.2, 0.9)
const GOLD: Color = Color("ffd166")
const BUBBLE_BG: Color = Color("fff6e0")
const BUBBLE_BORDER: Color = Color("2d1b69")
const INK: Color = Color("2b2233")
const MAX_TOASTS: int = 2
## Distancia (px del juego) a la que el globo desaparece si el jugador se aleja.
const BUBBLE_RANGE: float = 70.0

var _root: Control
var _score: Label
var _bombs: Label
var _buildings: Label
var _civilians: Label
var _toasts: VBoxContainer
var _bubble: PanelContainer
var _bubble_name: Label
var _bubble_text: Label
var _portrait: Portrait
var _tail: BubbleTail
var _bubble_source: Node2D
var _bubble_tween: Tween
var _prompt: PanelContainer
var _prompt_text: Label


func _init() -> void:
	layer = 10
	scale = Vector2(0.5, 0.5)


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	_build_stats()
	_build_toasts()
	_build_prompt()
	_build_bubble()

	GameManager.score_changed.connect(_on_score)
	GameManager.bombs_changed.connect(_on_bombs)
	GameManager.buildings_changed.connect(_on_buildings)
	GameManager.civilians_changed.connect(_on_civilians)
	GameManager.toast_requested.connect(_add_toast)
	GameManager.dialog_requested.connect(_on_dialog)

	_on_score(GameManager.score)
	_on_bombs(GameManager.bombs)
	_on_buildings(GameManager.buildings_cleared, GameManager.total_buildings())
	_on_civilians(GameManager.civilians_saved, GameManager.total_civilians())
	_add_toast("info", "Controles", "WASD mover · E bomba · F usar · M música")


func _fit_to_viewport() -> void:
	# El layer esta a escala 0.5, por eso el area virtual es el doble.
	_root.size = get_viewport().get_visible_rect().size * 2.0
	if _toasts != null:
		_toasts.position = Vector2(_root.size.x - 214.0, _root.size.y - 148.0)


# ---------------------------------------------------------------- construccion
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_stats() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(8, 8)
	panel.add_theme_stylebox_override("panel", UIStyle.box(PANEL_BG, 8, GOLD, 1, 8.0, 3.0))
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	_score = _label(12, GOLD)
	_bombs = _label(12, Color("ffb703"))
	_buildings = _label(12, Color("4cc9f0"))
	_civilians = _label(12, Color("06d6a0"))
	for l in [_score, _bombs, _buildings, _civilians]:
		row.add_child(l)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Contenedor de altura fija, pegado abajo a la derecha: los popups se apilan hacia arriba.
	_toasts.custom_minimum_size = Vector2(206, 140)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 4)
	_root.add_child(_toasts)
	_toasts.position = Vector2(_root.size.x - 214.0, _root.size.y - 148.0)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_stylebox_override("panel", UIStyle.box(PANEL_BG, 10, GOLD, 1, 6.0, 2.0))
	_prompt.visible = false
	_root.add_child(_prompt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_prompt.add_child(row)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIStyle.box(GOLD, 4, Color(0, 0, 0, 0), 0, 5.0, 0.0))
	row.add_child(chip)
	var chip_label := _label(11, Color("2d1b69"))
	chip_label.text = "F"
	chip.add_child(chip_label)
	_prompt_text = _label(11, Color.WHITE)
	row.add_child(_prompt_text)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", UIStyle.box(BUBBLE_BG, 8, BUBBLE_BORDER, 2, 8.0, 5.0))
	_bubble.visible = false
	_root.add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_bubble.add_child(row)
	_portrait = Portrait.new()
	_portrait.texture = TILESET
	_portrait.custom_minimum_size = Vector2(30, 30)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	_bubble_name = _label(11, Color("7b2cbf"))
	col.add_child(_bubble_name)
	_bubble_text = _label(11, INK)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.custom_minimum_size = Vector2(130, 0)
	col.add_child(_bubble_text)

	_tail = BubbleTail.new()
	_tail.custom_minimum_size = Vector2(12, 7)
	_tail.size = Vector2(12, 7)
	_tail.fill = BUBBLE_BG
	_tail.border = BUBBLE_BORDER
	_tail.visible = false
	_root.add_child(_tail)


# ---------------------------------------------------------------- estadisticas
func _on_score(value: int) -> void:
	_score.text = "Puntos %d" % value


func _on_bombs(value: int) -> void:
	_bombs.text = "Bombas %d" % value


func _on_buildings(cleared: int, total: int) -> void:
	_buildings.text = "Edificios %d/%d" % [cleared, total]


func _on_civilians(saved: int, total: int) -> void:
	_civilians.text = "A salvo %d/%d" % [saved, total]


# ---------------------------------------------------------------- popups
func _add_toast(kind: String, title: String, text: String) -> void:
	var color: Color = KIND_COLORS.get(kind, KIND_COLORS["info"])
	if title == "":
		title = KIND_TITLES.get(kind, "Información")
	# Maximo de popups a la vez: se quita el mas viejo
	while _toasts.get_child_count() >= MAX_TOASTS:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(206, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.box(PANEL_BG, 8, color, 2, 7.0, 4.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	var icon := ToastIcon.new()
	icon.kind = kind
	icon.color = color
	icon.custom_minimum_size = Vector2(18, 18)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var title_label := _label(12, color)
	title_label.text = title
	col.add_child(title_label)
	if text != "":
		var body := _label(11, Color(1, 1, 1, 0.92))
		body.text = text
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(150, 0)
		col.add_child(body)

	_toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(clampf(2.0 + float(text.length()) * 0.035, 2.4, 6.0))
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)


# ---------------------------------------------------------------- globo de dialogo
func _on_dialog(speaker: String, text: String, portrait: Vector2i, source: Node2D) -> void:
	_bubble_source = source
	_bubble_name.text = speaker
	_bubble_text.text = text
	_portrait.tile = portrait
	_portrait.visible = portrait.x >= 0
	_portrait.queue_redraw()
	_bubble.size = Vector2.ZERO   # se encoge al tamaño que pida el texto
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_tail.modulate.a = 0.0
	if _bubble_tween != null:
		_bubble_tween.kill()
	_bubble_tween = create_tween().set_parallel(true)
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.12)
	_bubble_tween.tween_property(_tail, "modulate:a", 1.0, 0.12)
	_bubble_tween.chain().tween_interval(clampf(2.5 + float(text.length()) * 0.05, 3.5, 9.0))
	_bubble_tween.chain().tween_callback(_hide_bubble)


func _hide_bubble() -> void:
	_bubble.visible = false
	_tail.visible = false
	_bubble_source = null


## Punto del mundo sobre el que se ancla un globo o etiqueta.
func _anchor_world(node: Node2D) -> Vector2:
	if node.has_method("get_bubble_anchor"):
		return node.call("get_bubble_anchor")
	return node.global_position + Vector2(0.0, -28.0)


## Convierte una posicion del mundo a coordenadas de este HUD (area virtual x2).
func _world_to_hud(world: Vector2) -> Vector2:
	return (get_viewport().get_canvas_transform() * world) * 2.0


func _source_distance(player: Node2D, source: Node2D) -> float:
	if source.has_method("distance_to_rect"):
		return source.call("distance_to_rect", player.global_position)
	return source.global_position.distance_to(player.global_position)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D

	# Globo: solo mientras el jugador siga cerca de quien habla
	if _bubble.visible:
		var keep: bool = true
		if _bubble_source != null:
			if not is_instance_valid(_bubble_source) or not _bubble_source.visible:
				keep = false
			elif player != null and _source_distance(player, _bubble_source) > BUBBLE_RANGE:
				keep = false
		if keep:
			_place_bubble()
		else:
			_hide_bubble()

	# Etiqueta "F  Hablar": solo si hay algo al alcance y no hay un globo abierto
	var target: Node = null
	if player != null:
		target = GameManager.find_target(player.global_position)
	if target != null and target.has_method("get_prompt") and not _bubble.visible:
		_prompt_text.text = String(target.call("get_prompt"))
		_prompt.size = Vector2.ZERO
		var a: Vector2 = _world_to_hud(_anchor_world(target as Node2D))
		_prompt.position = Vector2(
			clampf(a.x - _prompt.size.x / 2.0, 6.0, _root.size.x - _prompt.size.x - 6.0),
			maxf(a.y - _prompt.size.y - 4.0, 34.0))
		_prompt.visible = true
	else:
		_prompt.visible = false


func _place_bubble() -> void:
	var sz: Vector2 = _bubble.size
	var area: Vector2 = _root.size
	if _bubble_source == null:
		_bubble.position = Vector2((area.x - sz.x) / 2.0, area.y - sz.y - 14.0)
		_tail.visible = false
		return
	var a: Vector2 = _world_to_hud(_anchor_world(_bubble_source))
	var x: float = clampf(a.x - sz.x / 2.0, 6.0, area.x - sz.x - 6.0)
	var y: float = maxf(a.y - sz.y - 9.0, 34.0)
	_bubble.position = Vector2(x, y)
	_tail.position = Vector2(clampf(a.x - 6.0, x + 8.0, x + sz.x - 20.0), y + sz.y - 1.0)
	_tail.visible = true


# ---------------------------------------------------------------- controles de dibujo
## Icono redondo del popup (se dibuja por codigo para no depender de la tipografia).
class ToastIcon extends Control:
	var kind: String = "info"
	var color: Color = Color.WHITE

	func _draw() -> void:
		var c: Vector2 = size / 2.0
		var r: float = minf(size.x, size.y) / 2.0
		draw_circle(c, r, color)
		var dark := Color(0.09, 0.07, 0.2)
		match kind:
			"success":
				draw_polyline(PackedVector2Array([c + Vector2(-r * 0.45, 0.0), c + Vector2(-r * 0.1, r * 0.4), c + Vector2(r * 0.5, -r * 0.35)]), dark, 2.0)
			"error":
				draw_line(c + Vector2(-r * 0.4, -r * 0.4), c + Vector2(r * 0.4, r * 0.4), dark, 2.0)
				draw_line(c + Vector2(r * 0.4, -r * 0.4), c + Vector2(-r * 0.4, r * 0.4), dark, 2.0)
			"warning":
				draw_line(c + Vector2(0.0, -r * 0.55), c + Vector2(0.0, r * 0.1), dark, 2.2)
				draw_circle(c + Vector2(0.0, r * 0.5), 1.4, dark)
			_:
				draw_circle(c + Vector2(0.0, -r * 0.5), 1.4, dark)
				draw_line(c + Vector2(0.0, -r * 0.1), c + Vector2(0.0, r * 0.55), dark, 2.2)


## Retrato del globo: una casilla del tileset ampliada.
class Portrait extends Control:
	var texture: Texture2D
	var tile: Vector2i = Vector2i(-1, -1)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("e6dcff"))
		draw_rect(Rect2(Vector2.ZERO, size), Color("2d1b69"), false, 1.0)
		if texture != null and tile.x >= 0:
			draw_texture_rect_region(texture, Rect2(Vector2(1, 1), size - Vector2(2, 2)), Rect2(Vector2(tile) * 16.0, Vector2(16, 16)))


## Colita del globo (triangulo apuntando al personaje).
class BubbleTail extends Control:
	var fill: Color = Color.WHITE
	var border: Color = Color.BLACK

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x / 2.0, size.y)])
		draw_colored_polygon(pts, fill)
		draw_line(pts[0], pts[2], border, 2.0)
		draw_line(pts[1], pts[2], border, 2.0)
