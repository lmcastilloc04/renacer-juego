class_name UIStyle
extends RefCounted
## Ayudas de estilo compartidas (colores, botones redondeados, degradados).


static func box(color: Color, radius: int = 10, border_color: Color = Color(0, 0, 0, 0), border_w: int = 0, margin_h: float = 8.0, margin_v: float = 4.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border_color
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func style_button(b: Button, color: Color, font_size: int, text_color: Color) -> void:
	var border: Color = color.darkened(0.35)
	b.add_theme_stylebox_override("normal", box(color, 10, border, 2, 10.0, 5.0))
	b.add_theme_stylebox_override("hover", box(color.lightened(0.18), 10, Color.WHITE, 2, 10.0, 5.0))
	b.add_theme_stylebox_override("pressed", box(color.darkened(0.15), 10, border, 2, 10.0, 5.0))
	b.add_theme_stylebox_override("disabled", box(color, 10, border, 2, 10.0, 5.0))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 10, Color("fff3b0"), 3, 10.0, 5.0))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, text_color)
	b.add_theme_font_size_override("font_size", font_size)


## Fondo con degradado vertical. colors = lista de Color de arriba hacia abajo.
static func gradient_rect(colors: Array) -> TextureRect:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	tex.width = 4
	tex.height = 128
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	return tr
