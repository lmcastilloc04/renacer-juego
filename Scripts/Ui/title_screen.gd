extends Node
## Pantalla de inicio de "Renacer". Se construye por codigo:
## crea una escena con un nodo raiz tipo Node, pegale este script y guardala como
## res://Scenes/UI/title_screen.tscn

const GAME_SCENE: String = "res://Scenes/node_2d.tscn"
const MUSIC_PATH: String = "res://PackPlayerOctorok/08_Music/title_screen.wav"
const CLICK_PATH: String = "res://PackPlayerOctorok/07_Effects Sounds/Rupee - Cursor.wav"

const HOW_TO_TEXT: String = "[center][color=#ffd166][b]¿Cómo se juega?[/b][/color][/center]\n" \
	+ "Eres un especialista que ayuda a recuperar una ciudad tras un terremoto. Debes despejar los edificios dañados de forma responsable y llegar a la plaza del final.\n\n" \
	+ "[color=#ffd166][b]Controles[/b][/color]\n" \
	+ "W A S D o flechas: moverte\n" \
	+ "F: evaluar el edificio más cercano\n" \
	+ "E: colocar una bomba (explota a los 2,5 segundos)\n" \
	+ "[color=#4cc9f0][b]1. Reconoce el riesgo:[/b][/color] acércate a un edificio y presiona F. Verás cuántos pisos tiene y un círculo rojo que marca la zona de peligro.\n" \
	+ "[color=#ffb703][b]2. Despeja el camino:[/b][/color] cada piso necesita una bomba. Colócalas junto al edificio y sal del círculo rojo antes de que explote la última.\n" \
	+ "[color=#06d6a0][b]3. Reconstruye la esperanza:[/b][/color] cuando termines, llega a la plaza del final para abrir las rutas de emergencia.\n\n" \
	+ "[color=#ef476f][b]Ojo:[/b][/color] algunos edificios tienen la estructura comprometida (al evaluarlos se ven grietas). No se deben demoler: déjalos en pie.\n\n" \
	+ "[color=#ffd166][b]Puntos[/b][/color]\n" \
	+ "Ganas por evaluar y por demoler con responsabilidad. Pierdes por quedarte cerca de una explosión, por demoler sin evaluar o por derribar un edificio inseguro. Tienes 8 bombas.\n\n" \
	+ "[color=#ffd166]Trivia:[/color] responderás preguntas antes y después de jugar."

var _root: Control
var _scenery: SceneryDraw
var _title: Label
var _play_button: Button
var _how_overlay: Control
var _how_ok: Button
var _click_player: AudioStreamPlayer
var _starting: bool = false


func _ready() -> void:
	get_tree().paused = false
	var layer := CanvasLayer.new()
	layer.scale = Vector2(0.5, 0.5)
	add_child(layer)
	_root = Control.new()
	layer.add_child(_root)
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	_build_background()
	_build_menu()
	_build_how_to()
	_setup_audio()
	_play_intro_animation()
	_play_button.grab_focus()


func _fit_to_viewport() -> void:
	_root.size = get_viewport().get_visible_rect().size * 2.0


# ---------------------------------------------------------------- construccion
func _build_background() -> void:
	var sky := UIStyle.gradient_rect([Color("1b1464"), Color("7b2ff7"), Color("f107a3"), Color("ff9a3c"), Color("ffe08a")])
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(sky)
	_scenery = SceneryDraw.new()
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_scenery)


func _build_menu() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	_root.add_child(vbox)

	var top_space := Control.new()
	top_space.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(top_space)

	_title = _make_title("RENACER", 56, Color("ffd166"), 8)
	vbox.add_child(_title)
	vbox.add_child(_make_title("Reconstruyendo esperanza", 22, Color.WHITE, 6))
	var tag := _make_title("\"No se trata de destruir lo que quedó, sino de construir una oportunidad para empezar de nuevo.\"", 14, Color("fff6d6"), 4)
	tag.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(tag)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(gap)

	_play_button = Button.new()
	_play_button.text = "JUGAR"
	_play_button.custom_minimum_size = Vector2(240, 42)
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_button.pivot_offset = Vector2(120.0, 21.0)
	UIStyle.style_button(_play_button, Color("06d6a0"), 22, Color("0b2e2a"))
	_play_button.pressed.connect(_on_play_pressed)
	vbox.add_child(_play_button)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)
	var how := _small_button("Cómo jugar", Color("ffb703"), Color("3b2a00"))
	how.pressed.connect(_on_how_pressed)
	row.add_child(how)
	# En la version web no tiene sentido el boton Salir.
	if not OS.has_feature("web"):
		var quit := _small_button("Salir", Color("ef476f"), Color.WHITE)
		quit.pressed.connect(_on_quit_pressed)
		row.add_child(quit)

	# Relleno flexible: empuja el aviso hacia el fondo del menu
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(fill)

	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 24)
	footer_margin.add_theme_constant_override("margin_right", 24)
	vbox.add_child(footer_margin)

	var footer := Label.new()
	footer.text = "Videojuego serio · Simulación educativa. No reemplaza la capacitación ni los procedimientos oficiales de emergencia."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.custom_minimum_size = Vector2(0, 36)
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color("e6e8ff"))
	footer_margin.add_child(footer)

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 18)
	vbox.add_child(bottom_pad)


func _make_title(text: String, font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("2d1b69"))
	l.add_theme_constant_override("outline_size", outline)
	return l


func _small_button(text: String, color: Color, text_color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 30)
	UIStyle.style_button(b, color, 16, text_color)
	return b


func _build_how_to() -> void:
	_how_overlay = Control.new()
	_how_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_how_overlay.visible = false
	_root.add_child(_how_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_how_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_how_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color("2d1b69"), 18, Color("ffd166"), 4, 16.0, 12.0))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 14)
	rt.add_theme_color_override("default_color", Color.WHITE)
	rt.text = HOW_TO_TEXT
	scroll.add_child(rt)

	_how_ok = _small_button("¡Entendido!", Color("06d6a0"), Color("0b2e2a"))
	_how_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_how_ok.pressed.connect(_on_how_closed)
	box.add_child(_how_ok)


func _setup_audio() -> void:
	if ResourceLoader.exists(MUSIC_PATH):
		var music := AudioStreamPlayer.new()
		music.stream = load(MUSIC_PATH)
		music.volume_db = -8.0
		music.autoplay = true
		music.finished.connect(music.play)   # repetir en bucle
		add_child(music)
	if ResourceLoader.exists(CLICK_PATH):
		_click_player = AudioStreamPlayer.new()
		_click_player.stream = load(CLICK_PATH)
		add_child(_click_player)


func _play_intro_animation() -> void:
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.8)

	var sun := create_tween()
	sun.tween_property(_scenery, "sun_t", 1.0, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_title.pivot_offset = Vector2(_root.size.x * 0.5, 36.0)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_title, "scale", Vector2(1.04, 1.04), 1.0).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_title, "scale", Vector2.ONE, 1.0).set_trans(Tween.TRANS_SINE)

	var pulse_btn := create_tween().set_loops()
	pulse_btn.tween_property(_play_button, "scale", Vector2(1.06, 1.06), 0.7).set_trans(Tween.TRANS_SINE)
	pulse_btn.tween_property(_play_button, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- botones
func _click() -> void:
	if _click_player != null:
		_click_player.play()


func _on_play_pressed() -> void:
	if _starting:
		return
	if not ResourceLoader.exists(GAME_SCENE):
		push_error("No encuentro la escena del juego: " + GAME_SCENE)
		return
	_starting = true
	_click()
	var tw := create_tween()
	tw.tween_property(_root, "modulate", Color(0, 0, 0, 1), 0.5)
	await tw.finished
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_how_pressed() -> void:
	_click()
	_how_overlay.visible = true
	_how_ok.grab_focus()


func _on_how_closed() -> void:
	_click()
	_how_overlay.visible = false
	_play_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---------------------------------------------------------------- paisaje animado
class SceneryDraw extends Control:
	# Izquierda: ciudad danada (gris). Derecha: ciudad reconstruida (colores).
	var heights: Array = [70, 104, 58, 92, 122, 66, 98, 82, 112, 62, 102, 76, 126, 88]
	var new_colors: Array = [Color("ff6b6b"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0")]
	var sun_t: float = 0.0
	var t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var horizon: float = h * 0.78
		_draw_sun(w, h, horizon)
		_draw_clouds(w, h)
		_draw_city(w, h, horizon)

	func _draw_sun(w: float, h: float, horizon: float) -> void:
		var pos := Vector2(w * 0.5, lerpf(horizon + 70.0, h * 0.30, sun_t))
		for i in 4:
			draw_circle(pos, 70.0 + float(i) * 24.0, Color(1.0, 0.85, 0.35, 0.10))
		for i in 14:
			var a: float = t * 0.25 + TAU * float(i) / 14.0
			draw_line(pos + Vector2.from_angle(a) * 68.0, pos + Vector2.from_angle(a) * 92.0, Color(1.0, 0.93, 0.65, 0.7), 4.0)
		draw_circle(pos, 58.0, Color("ffd166"))
		draw_circle(pos, 46.0, Color("ffe8a3"))

	func _draw_clouds(w: float, h: float) -> void:
		var specs: Array = [[0.0, 0.16, 10.0], [160.0, 0.30, 6.0], [300.0, 0.10, 8.0]]
		var c := Color(1, 1, 1, 0.55)
		for s in specs:
			var x: float = fposmod(float(s[0]) + t * float(s[2]), w + 240.0) - 120.0
			var y: float = h * float(s[1])
			draw_circle(Vector2(x, y), 20.0, c)
			draw_circle(Vector2(x + 24.0, y - 8.0), 26.0, c)
			draw_circle(Vector2(x + 52.0, y), 20.0, c)

	func _draw_city(w: float, h: float, horizon: float) -> void:
		var n: int = heights.size()
		var bw: float = w / float(n)
		var half: int = int(float(n) * 0.5)
		for i in n:
			var bx: float = float(i) * bw
			var bh: float = float(heights[i]) * h / 352.0
			var top: float = horizon - bh
			if i < half:
				var pts := PackedVector2Array([
					Vector2(bx, horizon), Vector2(bx, top + 16.0), Vector2(bx + bw * 0.25, top),
					Vector2(bx + bw * 0.45, top + 20.0), Vector2(bx + bw * 0.7, top + 6.0),
					Vector2(bx + bw - 3.0, top + 24.0), Vector2(bx + bw - 3.0, horizon)
				])
				draw_colored_polygon(pts, Color("4a4e69"))
				draw_line(Vector2(bx + bw * 0.4, top + 20.0), Vector2(bx + bw * 0.55, top + bh * 0.55), Color("22223b"), 2.0)
			else:
				var col: Color = new_colors[i % new_colors.size()]
				draw_rect(Rect2(bx, top, bw - 3.0, bh), col)
				draw_rect(Rect2(bx, top, bw - 3.0, 6.0), col.lightened(0.25))
				var rows: int = int(bh / 22.0)
				for r in rows:
					for c in 2:
						var wx: float = bx + 8.0 + float(c) * (bw * 0.4)
						var wy: float = top + 14.0 + float(r) * 22.0
						var lit: bool = sin(t * 1.4 + float(i) * 2.3 + float(r) * 1.7 + float(c)) > -0.3
						var wcol: Color = Color("fff3b0") if lit else col.darkened(0.35)
						draw_rect(Rect2(wx, wy, 9.0, 12.0), wcol)
		draw_rect(Rect2(0.0, horizon, w, h - horizon), Color("22223b"))
		draw_rect(Rect2(0.0, horizon, w, 5.0), Color("4a4e69"))
