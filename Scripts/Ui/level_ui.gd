class_name LevelUI
extends CanvasLayer
## Pantallas a pantalla completa del juego: inicio de mapa (misión), mapa completado,
## misión fallida y final. Trabajan a escala 0.5 como la trivia (texto nítido) y pausan el juego.
## Uso:  await ui.show_briefing(...)   /   var id: String = await ui.show_complete(...)

signal chosen(id: String)

const GOLD: Color = Color("ffd166")
const CYAN: Color = Color("4cc9f0")
const GREEN: Color = Color("06d6a0")
const AMBER: Color = Color("ffb703")
const RED: Color = Color("ef476f")
const PANEL: Color = Color(0.1, 0.08, 0.24, 0.98)

var _root: Control
var _dim: ColorRect
var _stars: Stars


func _init() -> void:
	layer = 90
	scale = Vector2(0.5, 0.5)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	_root.size = get_viewport().get_visible_rect().size * 2.0


# ---------------------------------------------------------------- pantallas
## Inicio de mapa: nivel, nombre, objetivo y consejos.
func show_briefing(lv: Dictionary, idx: int, total: int) -> void:
	var box := _begin(CYAN)
	_text(box, String(lv["section"]).to_upper(), 12, GOLD)
	_text(box, "Mapa %d de %d: %s" % [idx + 1, total, lv["name"]], 22, Color.WHITE)
	_rule(box)
	_text(box, "OBJETIVO", 12, CYAN)
	_text(box, String(lv["objective"]), 15, Color.WHITE)
	_rule(box)
	for t in lv["tips"]:
		_text(box, "-  " + String(t), 13, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_button(box, "Comenzar", GREEN, "go")
	await chosen


## Mapa completado. summary: name, stars, points, total, good[], bad[], lesson, last.
func show_complete(summary: Dictionary) -> String:
	var box := _begin(GREEN)
	_text(box, "¡MAPA COMPLETADO!", 13, GREEN)
	_text(box, String(summary["name"]), 22, Color.WHITE)
	_add_stars(box, int(summary["stars"]))
	_text(box, "Puntos del mapa: %+d     Total: %d" % [summary["points"], summary["total"]], 15, GOLD)
	_lists(box, summary["good"], summary["bad"])
	_text(box, "Aprendizaje: " + String(summary["lesson"]), 12, CYAN)
	_button(box, "Siguiente mapa", GREEN, "next")
	_confetti()
	return await chosen


## Misión fallida. Devuelve "retry" o "menu".
func show_failed(reason: String, lesson: String) -> String:
	var box := _begin(RED)
	_text(box, "MISIÓN FALLIDA", 13, RED)
	_text(box, "Inténtalo de nuevo", 22, Color.WHITE)
	_rule(box)
	_text(box, reason, 15, Color.WHITE)
	_text(box, "Recuerda: " + lesson, 12, CYAN)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_button(row, "Reintentar", AMBER, "retry")
	_button(row, "Menú principal", Color("5a4fcf"), "menu")
	return await chosen


## Final del juego en dos paginas. Devuelve "again" o "menu".
func show_ending(summary: Dictionary) -> String:
	# Pagina 1: resumen
	var box := _begin(GOLD)
	_text(box, "RENACER: RECONSTRUYENDO ESPERANZA", 12, GOLD)
	_text(box, "¡Ciudad reconstruida!", 23, Color.WHITE)
	_add_stars(box, int(summary["stars"]))
	_text(box, "Puntaje final: %d     Edificios despejados: %s     Personas a salvo: %s" % [summary["score"], summary["buildings"], summary["people"]], 13, GOLD)
	_text(box, String(summary["trivia"]), 13, CYAN)
	_lists(box, summary["good"], summary["bad"])
	_button(box, "Continuar", GREEN, "next")
	_confetti()
	await chosen
	# Pagina 2: mensaje y opciones
	var box2 := _begin(GOLD)
	_text(box2, "MENSAJE FINAL", 12, GOLD)
	_text(box2, "\"No se trata de destruir lo que quedó, sino de construir una oportunidad para empezar de nuevo.\"", 18, Color.WHITE)
	_rule(box2)
	_text(box2, "Esta es una simulación educativa: en una emergencia real, solo el personal capacitado decide qué se demuele. La prevención, la cooperación y las decisiones responsables ayudan a recuperar una comunidad.", 13, Color(1, 1, 1, 0.85))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	box2.add_child(row)
	_button(row, "Jugar de nuevo", GREEN, "again")
	_button(row, "Menú principal", Color("5a4fcf"), "menu")
	return await chosen


# ---------------------------------------------------------------- construccion
func _begin(accent: Color) -> VBoxContainer:
	_clear()
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.03, 0.12, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.box(PANEL, 16, accent, 3, 22.0, 14.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	get_tree().paused = true
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.25)
	return box


func _clear() -> void:
	if _dim != null:
		_dim.queue_free()
		_dim = null
	_stars = null


func _choose(id: String) -> void:
	GameManager.sfx("ui_click")
	_clear()
	get_tree().paused = false
	chosen.emit(id)


func _text(parent: Node, text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(380, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _rule(parent: Node) -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.14)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)


func _button(parent: Node, text: String, color: Color, id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 34)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Texto oscuro sobre botones claros, blanco sobre botones oscuros
	UIStyle.style_button(b, color, 16, Color("0b2e2a") if color.get_luminance() > 0.45 else Color.WHITE)
	b.pressed.connect(_choose.bind(id))
	parent.add_child(b)
	b.call_deferred("grab_focus")
	return b


func _add_stars(parent: Node, count: int) -> void:
	_stars = Stars.new()
	_stars.custom_minimum_size = Vector2(0, 44)
	_stars.filled = count
	parent.add_child(_stars)
	var tw := create_tween()
	tw.tween_property(_stars, "reveal", float(count), 0.3 + 0.4 * float(count))


## Dos columnas: "Bien hecho" y "Para mejorar" (maximo 3 lineas cada una).
func _lists(parent: Node, good: Array, bad: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	for side in 2:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var items: Array = good if side == 0 else bad
		var head := Label.new()
		head.text = "Bien hecho" if side == 0 else "Para mejorar"
		head.add_theme_font_size_override("font_size", 12)
		head.add_theme_color_override("font_color", GREEN if side == 0 else AMBER)
		col.add_child(head)
		if items.is_empty():
			var none := Label.new()
			none.text = "-"
			none.add_theme_font_size_override("font_size", 12)
			none.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			col.add_child(none)
		for i in mini(items.size(), 3):
			var l := Label.new()
			l.text = "- " + String(items[i])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(185, 0)
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
			col.add_child(l)


func _confetti() -> void:
	var area: Vector2 = _root.size
	var palette: Array = [Color("ff6b6b"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"), Color("f72585")]
	for i in 30:
		var c := ColorRect.new()
		c.color = palette[randi() % palette.size()]
		c.size = Vector2(randf_range(5.0, 10.0), randf_range(5.0, 10.0))
		c.position = Vector2(randf_range(0.0, area.x), randf_range(-60.0, -10.0))
		c.rotation = randf() * TAU
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dim.add_child(c)
		var dur: float = randf_range(1.6, 2.8)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(c, "position:y", area.y + 20.0, dur).set_delay(randf() * 0.5)
		t.tween_property(c, "rotation", c.rotation + randf_range(-6.0, 6.0), dur)
		t.chain().tween_callback(c.queue_free)


## Tres estrellas que se van llenando.
class Stars extends Control:
	var filled: int = 0
	var reveal: float = 0.0:
		set(v):
			reveal = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _star(center: Vector2, scale_f: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 10:
			var r: float = (16.0 if k % 2 == 0 else 7.0) * scale_f
			var a: float = -PI / 2.0 + float(k) * PI / 5.0
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		return pts

	func _draw() -> void:
		var cx: float = size.x * 0.5
		var cy: float = size.y * 0.5
		for i in 3:
			var center := Vector2(cx + float(i - 1) * 46.0, cy)
			draw_colored_polygon(_star(center, 1.0), Color(1, 1, 1, 0.2))
			var s: float = clampf(reveal - float(i), 0.0, 1.0)
			if i < filled and s > 0.0:
				draw_colored_polygon(_star(center, s), Color("ffd166"))
