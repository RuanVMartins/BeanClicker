class_name UIKit
extends RefCounted
## Kit de UI "Cassino Corporativo".
## Identidade visual: metade terminal de bolsa (LCD âmbar, fonte mono, sparklines),
## metade máquina de cassino (teclas físicas que afundam, molduras art déco com
## sombra dura, letreiro de lâmpadas). Nada de cantos arredondados genéricos.

# ── Paleta ──
const GOLD := Color("#E0B840")
const GOLD_LIGHT := Color("#FFE08A")
const GOLD_DARK := Color("#8A6A1C")
const NIGHT := Color("#14121F")
const NIGHT_2 := Color("#1C1830")
const FELT := Color("#241E38")
const FELT_GREEN := Color("#0F3B2E")
const INK := Color("#F4EEDF")
const MUTED := Color("#A39CB8")
const DIM := Color("#6E6688")
const PROFIT := Color("#48F29A")
const RISK := Color("#FF4D4D")
const CYAN := Color("#5CF2FF")
const PURPLE := Color("#B57BFF")
const ORANGE := Color("#FF9F43")
const AMBER := Color("#FFB000")       # LED âmbar dos terminais de cotação
const LCD := Color("#07090A")
const HARD_SHADOW := Color(0, 0, 0, 0.6)

const TEX_COIN: Texture2D = preload("res://images/BeansCoins.png")

static var _theme: Theme
static var _display_font: Font
static var _mono_font: Font


# ══════════════════════════════════════
# FONTES
# ══════════════════════════════════════

## Títulos: sem serifa condensada com espaçamento largo (letreiro art déco).
static func display_font() -> Font:
	if _display_font == null:
		var base := SystemFont.new()
		base.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Black", "Arial Black", "Impact", "Sans-Serif"])
		base.font_weight = 700
		var v := FontVariation.new()
		v.base_font = base
		v.spacing_glyph = 1
		_display_font = v
	return _display_font


## Números e cotações: monoespaçada, como num terminal de corretora.
static func mono_font() -> Font:
	if _mono_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Lucida Console", "Courier New", "Monospace"])
		f.font_weight = 700
		_mono_font = f
	return _mono_font


# ══════════════════════════════════════
# STYLEBOXES
# ══════════════════════════════════════

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), radius: int = 3, border_w: int = 1, pad: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w if border.a > 0.0 else 0)
	# Cantos "de máquina": raios médios viram 4px. Pílulas/círculos (>=12) ficam.
	s.set_corner_radius_all(4 if radius > 4 and radius < 12 else radius)
	s.anti_aliasing = true
	if pad > 0.0:
		s.set_content_margin_all(pad)
	return s


## Sombra "carimbada": sem desfoque, deslocada para baixo. Visual impresso, não glow.
static func shadowed(s: StyleBoxFlat, _size: int = 0, alpha: float = 0.6) -> StyleBoxFlat:
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 5)
	s.shadow_color = Color(0, 0, 0, alpha)
	return s


## Moldura art déco: borda dupla simulada (borda grossa + filete interno via expand).
static func deco(bg: Color, border: Color = GOLD, pad: float = 12.0) -> StyleBoxFlat:
	var s := box(bg, border, 2, 2, pad)
	s.border_width_top = 3
	s.border_width_bottom = 3
	return shadowed(s)


## Tela de LCD: preto esverdeado, borda interna escura em cima (vidro rebaixado).
static func lcd(pad: float = 10.0) -> StyleBoxFlat:
	var s := box(Color(LCD, 0.94), Color("#2C2A20"), 2, 1, pad)
	s.border_width_top = 3
	s.border_color = Color("#3A3320")
	return s


## Tecla física de máquina de cassino: borda inferior grossa = profundidade.
## Retorna [normal, hover, pressed, disabled].
static func key_styles(face: Color, edge: Color, hover_edge: Color) -> Array[StyleBoxFlat]:
	var normal := box(face, edge.darkened(0.35), 4, 1, 0)
	normal.border_width_bottom = 5
	normal.border_color = edge.darkened(0.45)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 5
	normal.content_margin_bottom = 7
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(0, 2)
	normal.shadow_color = Color(0, 0, 0, 0.5)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = face.lightened(0.12)
	hover.border_color = hover_edge.darkened(0.25)
	hover.set_border_width_all(1)
	hover.border_width_bottom = 5

	# Afundada: perde a borda de baixo e o conteúdo desce 3px
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = face.darkened(0.15)
	pressed.border_width_bottom = 1
	pressed.border_width_top = 2
	pressed.border_color = hover_edge.darkened(0.3)
	pressed.content_margin_top = 9
	pressed.content_margin_bottom = 3
	pressed.shadow_size = 0

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = face.darkened(0.55)
	disabled.border_color = Color(edge, 0.25)
	disabled.border_width_bottom = 2
	disabled.shadow_size = 0
	return [normal, hover, pressed, disabled]


static func apply_key(b: Button, face: Color, edge: Color, hover_edge: Color, skew: float = 0.0) -> void:
	var st := key_styles(face, edge, hover_edge)
	for s in st:
		s.skew = Vector2(skew, 0)
	b.add_theme_stylebox_override("normal", st[0])
	b.add_theme_stylebox_override("hover", st[1])
	b.add_theme_stylebox_override("pressed", st[2])
	b.add_theme_stylebox_override("hover_pressed", st[2])
	b.add_theme_stylebox_override("disabled", st[3])
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Inclina um botão já estilizado (bilhete de aposta / etiqueta de preço).
static func skew_button(b: Button, amount: float = 0.18) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var s := b.get_theme_stylebox(state)
		if s is StyleBoxFlat:
			var c: StyleBoxFlat = s.duplicate()
			c.skew = Vector2(amount, 0)
			b.add_theme_stylebox_override(state, c)


# ══════════════════════════════════════
# THEME GLOBAL
# ══════════════════════════════════════

static func build_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 14

	# Botões: tecla neutra de grafite
	var st := key_styles(Color("#2A2638"), Color("#4A4460"), GOLD)
	t.set_stylebox("normal", "Button", st[0])
	t.set_stylebox("hover", "Button", st[1])
	t.set_stylebox("pressed", "Button", st[2])
	t.set_stylebox("hover_pressed", "Button", st[2])
	t.set_stylebox("disabled", "Button", st[3])
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD_LIGHT)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_focus_color", "Button", INK)
	t.set_font("font", "Button", display_font())

	# OptionButton herda o visual de tecla
	for s in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s, "Button"))
	t.set_font("font", "OptionButton", mono_font())

	# Painéis: moldura art déco
	t.set_stylebox("panel", "PanelContainer", deco(NIGHT, Color(0.33, 0.28, 0.45, 0.8), 8))
	t.set_stylebox("panel", "Panel", deco(NIGHT, Color(0.33, 0.28, 0.45, 0.8), 0))

	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))

	# Tooltip: fita de cotação
	var tip := box(Color(LCD, 0.97), GOLD_DARK, 0, 1, 10)
	tip.border_width_left = 4
	tip.border_color = GOLD
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Color("#F2E6C2"))
	t.set_font_size("font_size", "TooltipLabel", 13)

	# Slider: trilho rebaixado + ficha/moeda como puxador
	var track := box(Color("#0A0910"), Color("#3A3450"), 2, 1)
	track.border_width_top = 2
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(GOLD_DARK, Color(0, 0, 0, 0), 2)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi: StyleBoxFlat = fill.duplicate()
	fill_hi.bg_color = GOLD
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	var chip := _coin_icon(26)
	if chip:
		t.set_icon("grabber", "HSlider", chip)
		t.set_icon("grabber_highlight", "HSlider", _coin_icon(30))
		t.set_icon("grabber_disabled", "HSlider", _coin_icon(26, 0.4))

	# ProgressBar: barra de LED
	t.set_stylebox("background", "ProgressBar", box(Color("#09080E"), Color("#2A2638"), 1, 1))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, Color(0, 0, 0, 0), 1))

	# Scrollbar fininha dourada
	var grab := box(Color(GOLD_DARK, 0.8), Color(0, 0, 0, 0), 1)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab_hi: StyleBoxFlat = grab.duplicate()
	grab_hi.bg_color = GOLD
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)
	var sc_bg := box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 1)
	sc_bg.content_margin_left = 3
	sc_bg.content_margin_right = 3
	t.set_stylebox("scroll", "VScrollBar", sc_bg)

	t.set_stylebox("normal", "LineEdit", lcd(6))
	t.set_stylebox("focus", "LineEdit", box(LCD, GOLD, 2, 1, 6))
	t.set_color("font_color", "LineEdit", AMBER)

	_theme = t
	return t


static func _coin_icon(px: int, alpha: float = 1.0) -> Texture2D:
	var img := TEX_COIN.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img = img.duplicate()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	if alpha < 1.0:
		img.convert(Image.FORMAT_RGBA8)
		for y in range(px):
			for x in range(px):
				var c := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, c.a * alpha))
	return ImageTexture.create_from_image(img)


# ══════════════════════════════════════
# FÁBRICAS DE WIDGETS
# ══════════════════════════════════════

static func label(text: String, size: int = 14, color: Color = INK, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size: int = 20, color: Color = GOLD, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, align, 4)
	l.add_theme_font_override("font", display_font())
	return l


## Número de cotação: mono, cor de LED.
static func ticker(text: String, size: int = 16, color: Color = AMBER, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, align)
	l.add_theme_font_override("font", mono_font())
	return l


## Rótulo pequeno em caixa alta (cabeçalhos de seção estilo terminal).
static func caption(text: String, color: Color = MUTED) -> Label:
	var l := label(text.to_upper(), 10, color)
	l.add_theme_font_override("font", mono_font())
	return l


static func wrap_label(text: String, size: int = 13, color: Color = MUTED, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## kind: default | gold | danger | success | ghost | purple
static func button(text: String, kind: String = "default", font_size: int = 14, min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# [face, edge, hover_edge, font]
	var palette := {
		"gold": [Color("#C99A22"), Color("#7A5A10"), GOLD_LIGHT, Color("#1E1404")],
		"danger": [Color("#9E1F27"), Color("#5A0E14"), Color("#FF6B6B"), Color("#FFE3E3")],
		"success": [Color("#1F7A4C"), Color("#0E3F27"), PROFIT, Color("#E6FFF1")],
		"purple": [Color("#5B2D8A"), Color("#2E1448"), Color("#DDB8FF"), Color("#F3E8FF")],
		"ghost": [Color("#1E1A2C"), Color("#3E3854"), GOLD, INK],
	}
	if palette.has(kind):
		var p: Array = palette[kind]
		var font_col: Color = p[3]
		apply_key(b, p[0], p[1], p[2])
		b.add_theme_color_override("font_color", font_col)
		b.add_theme_color_override("font_pressed_color", font_col)
		b.add_theme_color_override("font_hover_pressed_color", font_col)
		b.add_theme_color_override("font_hover_color", Color.BLACK if kind == "gold" else font_col.lightened(0.2))
		b.add_theme_color_override("font_disabled_color", Color(font_col, 0.35))
	return b


static func panel(style: StyleBox = null) -> PanelContainer:
	var p := PanelContainer.new()
	if style:
		p.add_theme_stylebox_override("panel", style)
	return p


static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func margin(all: int = 8) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + side, all)
	return m


static func spacer(horizontal: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func texture_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func progress(min_h: float = 6.0, fill_color: Color = GOLD) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, min_h)
	p.max_value = 1.0
	p.step = 0.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("fill", box(fill_color, Color(0, 0, 0, 0), 1))
	return p


## Overlay modal: fundo escuro + painel com moldura art déco. Retorna [overlay, painel].
static func modal(parent: Node, min_size: Vector2, border: Color = GOLD) -> Array:
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.05, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.theme = build_theme()
	parent.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var p := panel(deco(NIGHT, border, 18))
	p.custom_minimum_size = min_size
	center.add_child(p)
	return [overlay, p]


# ══════════════════════════════════════
# JUICE
# ══════════════════════════════════════

static func pop(node: Control, strength: float = 1.12, time: float = 0.18) -> void:
	if not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(strength, strength), time * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func shake(node: Control, amount: float = 6.0, time: float = 0.3) -> void:
	if not is_instance_valid(node):
		return
	var origin := node.position
	var tw := node.create_tween()
	var steps := 6
	for i in range(steps):
		var off := Vector2(randf_range(-amount, amount), randf_range(-amount * 0.5, amount * 0.5)) * (1.0 - float(i) / steps)
		tw.tween_property(node, "position", origin + off, time / steps)
	tw.tween_property(node, "position", origin, 0.04)


static func flash(node: CanvasItem, color: Color, time: float = 0.35) -> void:
	if not is_instance_valid(node):
		return
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, time)


static func float_text(parent: Node, text: String, pos: Vector2, color: Color = GOLD_LIGHT, size: int = 22, rise: float = 70.0, time: float = 0.9) -> void:
	var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER, 5)
	l.add_theme_font_override("font", mono_font())
	l.z_index = 200
	parent.add_child(l)
	l.position = pos - Vector2(60, 12)
	l.custom_minimum_size = Vector2(120, 0)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - rise, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(l.queue_free)
