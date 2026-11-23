class_name TriviaUI
extends CanvasLayer
## Trivia colorida construida 100% por codigo.
## Uso:
##   var quiz := TriviaUI.new()
##   quiz.setup("Titulo", TriviaData.QUESTIONS, "texto extra", Color("4cc9f0"))
##   add_child(quiz)
##   var r: Array = await quiz.finished   # r[0] = aciertos, r[1] = total

signal finished(correct: int, total: int)

const FONT_BODY: int = 16     # el layer va a escala 0.5 => se ve como 8 px
const FONT_SMALL: int = 14
const FONT_QUESTION: int = 17

var title_text: String = "Trivia"
var questions: Array = []
var extra_text: String = ""
var accent: Color = Color("4cc9f0")

var col_dark := Color("1b1b3a")
var col_cream := Color("fff6d6")
var col_ok := Color("57cc99")
var col_bad := Color("e63946")
var option_colors: Array = [Color("ff6b6b"), Color("ffb703"), Color("2ec4b6"), Color("4cc9f0")]

var _index: int = 0
var _correct: int = 0
var _answered: bool = false
var _in_result: bool = false

var _root: Control
var _pill_label: Label
var _counter_label: Label
var _progress: ProgressBar
var _question_card: PanelContainer
var _question_label: Label
var _options_box: VBoxContainer
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _next_button: Button
var _stars: StarRating


func _init() -> void:
	layer = 100
	scale = Vector2(0.5, 0.5)
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(p_title: String, p_questions: Array, p_extra: String = "", p_accent: Color = Color("4cc9f0")) -> void:
	title_text = p_title
	questions = p_questions.duplicate(true)
	questions.shuffle()
	extra_text = p_extra
	accent = p_accent


func _ready() -> void:
	print("[Trivia] abre: ", title_text)
	_build_ui()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	get_tree().paused = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.3)
	_show_question()


func _fit_to_viewport() -> void:
	# El layer esta a escala 0.5, por eso el area virtual es el doble.
	_root.size = get_viewport().get_visible_rect().size * 2.0


# ---------------------------------------------------------------- construccion
func _build_ui() -> void:
	_root = Control.new()
	add_child(_root)

	var bg := UIStyle.gradient_rect([Color("2d1b69"), Color("5b3cc4"), Color("11998e")])
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	var deco := DecoCircles.new()
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(deco)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_root.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Fila superior: etiqueta de color + contador
	var top := HBoxContainer.new()
	vbox.add_child(top)
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIStyle.box(accent, 14, accent.darkened(0.3), 2, 12.0, 2.0))
	top.add_child(pill)
	_pill_label = _make_label(FONT_BODY, col_dark)
	_pill_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pill_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_child(_pill_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_counter_label = _make_label(FONT_BODY, Color.WHITE)
	_counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counter_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(_counter_label)

	# Barra de progreso
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 10)
	_progress.max_value = maxf(1.0, float(questions.size()))
	_progress.add_theme_stylebox_override("background", UIStyle.box(Color(1, 1, 1, 0.2), 6))
	_progress.add_theme_stylebox_override("fill", UIStyle.box(Color("ffd166"), 6))
	vbox.add_child(_progress)

	# Tarjeta de la pregunta
	_question_card = PanelContainer.new()
	_question_card.add_theme_stylebox_override("panel", UIStyle.box(col_cream, 14, accent, 3, 12.0, 8.0))
	vbox.add_child(_question_card)
	_question_label = _make_label(FONT_QUESTION, col_dark)
	_question_card.add_child(_question_label)

	# Opciones
	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 5)
	vbox.add_child(_options_box)

	# Fila inferior: explicacion + boton siguiente
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	_feedback_panel = PanelContainer.new()
	_feedback_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0, 0, 0, 0.35), 12, Color(1, 1, 1, 0.25), 2, 10.0, 6.0))
	row.add_child(_feedback_panel)
	_feedback_label = _make_label(FONT_SMALL, Color.WHITE)
	_feedback_panel.add_child(_feedback_label)
	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(120, 44)
	_next_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	UIStyle.style_button(_next_button, Color("57cc99"), FONT_BODY, col_dark)
	_next_button.pressed.connect(_on_next_pressed)
	row.add_child(_next_button)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _clear_options() -> void:
	for c in _options_box.get_children():
		_options_box.remove_child(c)
		c.queue_free()


# ---------------------------------------------------------------- preguntas
func _show_question() -> void:
	_answered = false
	_feedback_panel.visible = false
	_next_button.visible = false
	_clear_options()

	var q: Dictionary = questions[_index]
	_pill_label.text = title_text
	_counter_label.text = "Pregunta %d de %d" % [_index + 1, questions.size()]
	_progress.value = _index
	_question_label.text = q["question"]
	_question_card.modulate.a = 0.0
	create_tween().tween_property(_question_card, "modulate:a", 1.0, 0.25)

	var order: Array = range(q["options"].size())
	order.shuffle()
	var n: int = 0
	var first: Button = null
	for i in order:
		var b := Button.new()
		b.text = "%d) %s" % [n + 1, q["options"][i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 30)
		UIStyle.style_button(b, option_colors[n % option_colors.size()], FONT_BODY, col_dark)
		b.set_meta("is_correct", i == q["correct"])
		b.pressed.connect(_on_option_pressed.bind(b))
		b.modulate.a = 0.0
		_options_box.add_child(b)
		create_tween().tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.07 * float(n))
		n += 1
		if first == null:
			first = b
	if first != null:
		first.grab_focus()


func _on_option_pressed(btn: Button) -> void:
	if _answered:
		return
	_answered = true
	var q: Dictionary = questions[_index]
	var ok: bool = btn.get_meta("is_correct")
	if ok:
		_correct += 1
		_feedback_label.text = "¡Muy bien! " + q["explanation"]
	else:
		_feedback_label.text = "¡Casi! " + q["explanation"]
	for b in _options_box.get_children():
		var button := b as Button
		button.disabled = true
		if button.get_meta("is_correct"):
			UIStyle.style_button(button, col_ok, FONT_BODY, col_dark)
		elif button == btn:
			UIStyle.style_button(button, col_bad, FONT_BODY, Color.WHITE)
		else:
			button.modulate.a = 0.5
	_feedback_panel.visible = true
	_next_button.text = "Ver resultado" if _index == questions.size() - 1 else "Siguiente"
	_next_button.visible = true
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	if _in_result:
		_close()
		return
	_index += 1
	if _index >= questions.size():
		_show_result()
	else:
		_show_question()


# ---------------------------------------------------------------- resultado
func _show_result() -> void:
	_in_result = true
	_clear_options()
	var total: int = questions.size()
	var star_count: int = ceili(3.0 * _correct / total)
	_progress.value = total
	_counter_label.text = "¡Terminaste!"
	_question_label.text = "%s\nAciertos: %d de %d" % [_message_for(star_count), _correct, total]
	_question_card.modulate.a = 1.0

	_stars = StarRating.new()
	_stars.filled = star_count
	_stars.custom_minimum_size = Vector2(0, 70)
	_options_box.add_child(_stars)
	if star_count > 0:
		create_tween().tween_property(_stars, "reveal", float(star_count), 0.3 + 0.35 * float(star_count)).set_delay(0.3)
	if star_count >= 2:
		_confetti()

	_feedback_label.text = extra_text
	_feedback_panel.visible = extra_text != ""
	_next_button.text = "Continuar"
	_next_button.visible = true
	_next_button.grab_focus()


func _message_for(star_count: int) -> String:
	match star_count:
		3:
			return "¡Excelente! Estás listo para reconstruir."
		2:
			return "¡Muy bien! Vas por buen camino."
		1:
			return "¡Buen comienzo! Jugando aprenderás más."
		_:
			return "¡No pasa nada! En el juego vas a aprender."


func _confetti() -> void:
	var area: Vector2 = _root.size
	var palette: Array = [Color("ff6b6b"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"), Color("f72585")]
	for i in 40:
		var c := ColorRect.new()
		c.color = palette[randi() % palette.size()]
		c.size = Vector2(randf_range(6.0, 12.0), randf_range(6.0, 12.0))
		c.position = Vector2(randf_range(0.0, area.x), randf_range(-60.0, -10.0))
		c.rotation = randf() * TAU
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(c)
		var dur: float = randf_range(1.6, 3.0)
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(c, "position:y", area.y + 20.0, dur).set_delay(randf() * 0.6)
		t.tween_property(c, "rotation", c.rotation + randf_range(-6.0, 6.0), dur)
		t.chain().tween_callback(c.queue_free)


func _close() -> void:
	print("[Trivia] cierra: ", title_text, " -> aciertos ", _correct, " de ", questions.size())
	get_tree().paused = false
	finished.emit(_correct, questions.size())
	queue_free()


func _input(event: InputEvent) -> void:
	# Atajo: teclas 1, 2, 3, 4 para elegir respuesta.
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _answered or _in_result:
		return
	var idx: int = int(key.keycode) - int(KEY_1)
	if idx >= 0 and idx < _options_box.get_child_count():
		_on_option_pressed(_options_box.get_child(idx) as Button)


# ---------------------------------------------------------------- clases internas
class DecoCircles extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_circle(Vector2(w * 0.06, h * 0.16), 70.0, Color(1.0, 0.42, 0.42, 0.18))
		draw_circle(Vector2(w * 0.94, h * 0.20), 90.0, Color(1.0, 0.72, 0.01, 0.15))
		draw_circle(Vector2(w * 0.88, h * 0.88), 100.0, Color(0.30, 0.79, 0.94, 0.16))
		draw_circle(Vector2(w * 0.10, h * 0.92), 80.0, Color(0.18, 0.77, 0.71, 0.18))


class StarRating extends Control:
	var filled: int = 0
	var reveal: float = 0.0:
		set(v):
			reveal = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _star_points(center: Vector2, scale_f: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 10:
			var r: float = (28.0 if k % 2 == 0 else 12.0) * scale_f
			var a: float = -PI / 2.0 + float(k) * PI / 5.0
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		return pts

	func _draw() -> void:
		var cx: float = size.x * 0.5
		var cy: float = size.y * 0.5
		for i in 3:
			var center := Vector2(cx + float(i - 1) * 76.0, cy)
			draw_colored_polygon(_star_points(center, 1.0), Color(1, 1, 1, 0.22))
			var s: float = clampf(reveal - float(i), 0.0, 1.0)
			if i < filled and s > 0.0:
				draw_colored_polygon(_star_points(center, 1.0 * s), Color("ffd166"))
