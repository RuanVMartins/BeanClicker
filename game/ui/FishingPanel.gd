class_name FishingPanel
extends Control
## PESQUE-PAGUE DO JEFF — interface da pescaria.
## Esquerda: o lago (desenhado em código), a barra de tensão e o botão de ação.
## Direita: a cesta, a Cotação do Pescado (oscila como ação) e a loja de varas.
## Atalho: ESPAÇO faz a ação do momento (lançar / puxar / fisgar).

signal sfx(name: String)

enum State { IDLE, CASTING, WAITING, BITE, REELING, RESULT }

const TEX_BEAN: Texture2D = preload("res://images/BeansIdle.png")
const REEL_TIMEOUT: float = 6.0
const WAIT_QUIPS: Array[String] = [
	"Esperando... o peixe está lendo os termos de uso.",
	"Esperando... o peixe pediu para pensar e responder até sexta.",
	"Esperando... o peixe está em reunião.",
	"Esperando... o peixe foi no RH reclamar da isca.",
	"Esperando... a isca é de marca própria. Paciência.",
]

var _overlay: ColorRect
var _lake: LakeView
var _tension: TensionBar
var _status: Label
var _action_btn: Button
var _bubble: MeowzosBubble
var _cooler_header: Label
var _cooler_list: VBoxContainer
var _cooler_total: Label
var _sell_btn: Button
var _price_label: Label
var _spark: Sparkline
var _rod_name: Label
var _rod_next: Label
var _rod_btn: Button
var _stats_label: Label

var _state: State = State.IDLE
var _timer: float = 0.0
var _rarity: int = 0
var _hits_left: int = 0
var _marker: float = 0.0
var _dir: float = 1.0
var _speed: float = 1.0
var _zone_center: float = 0.5
var _zone_w: float = 0.3
var _refresh_accum: float = 0.0


# ══════════════════════════════════════
# DESENHO DE PEIXE (compartilhado)
# ══════════════════════════════════════

static func draw_fish(ci: CanvasItem, c: Vector2, length: float, color: Color, facing_right: bool = true, outline: Color = Color(0, 0, 0, 0.7)) -> void:
	var s := 1.0 if facing_right else -1.0
	var rx := length * 0.36
	var ry := length * 0.19
	var body := PackedVector2Array()
	for i in range(18):
		var a := TAU * i / 18.0
		body.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	var tail_root := c + Vector2(-rx * 0.85 * s, 0)
	var tail := PackedVector2Array([
		tail_root,
		c + Vector2(-rx * 1.5 * s, -ry * 1.15),
		c + Vector2(-rx * 1.32 * s, 0),
		c + Vector2(-rx * 1.5 * s, ry * 1.15),
	])
	var fin := PackedVector2Array([
		c + Vector2(-rx * 0.15 * s, -ry * 0.9),
		c + Vector2(-rx * 0.55 * s, -ry * 1.6),
		c + Vector2(rx * 0.2 * s, -ry * 0.95),
	])
	ci.draw_colored_polygon(fin, color.darkened(0.25))
	ci.draw_colored_polygon(tail, color.darkened(0.2))
	ci.draw_colored_polygon(body, color)
	# Barriga mais clara
	var belly := PackedVector2Array()
	for i in range(10):
		var a := PI * i / 9.0
		belly.append(c + Vector2(cos(a) * rx * 0.8, sin(a) * ry * 0.75 + ry * 0.05))
	ci.draw_colored_polygon(belly, color.lightened(0.25))
	body.append(body[0])
	ci.draw_polyline(body, outline, maxf(1.0, length * 0.03), true)
	var eye := c + Vector2(rx * 0.55 * s, -ry * 0.25)
	ci.draw_circle(eye, maxf(1.5, length * 0.05), Color.WHITE)
	ci.draw_circle(eye + Vector2(length * 0.012 * s, 0), maxf(1.0, length * 0.028), Color.BLACK)


class FishIcon extends Control:
	var color: Color = Color.WHITE

	func _draw() -> void:
		FishingPanel.draw_fish(self, size * 0.5 + Vector2(2, 0), size.x * 0.95, color)


## Barra de tensão: o marcador vai e volta; acerte a zona colorida.
class TensionBar extends Control:
	var marker: float = 0.0
	var zone_center: float = 0.5
	var zone_w: float = 0.3
	var color: Color = Color.WHITE
	var hits_left: int = 1

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#07090A"))
		draw_rect(r, Color("#3A3320"), false, 2.0)
		var zx := (zone_center - zone_w * 0.5) * size.x
		draw_rect(Rect2(zx, 3, zone_w * size.x, size.y - 6), Color(color, 0.35))
		draw_rect(Rect2(zx, 3, zone_w * size.x, size.y - 6), color, false, 2.0)
		var mx := marker * size.x
		draw_rect(Rect2(mx - 3, -3, 6, size.y + 6), Color.WHITE)
		draw_rect(Rect2(mx - 1, -3, 2, size.y + 6), Color("#FF4D4D"))
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(8, size.y - 7), "ACERTOS RESTANTES: %d" % hits_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))


## O lago: céu noturno, lua, píer com o Grande Bean, linha, boia e peixe saltando.
class LakeView extends Control:
	var t: float = 0.0
	var mode: String = "idle"      # idle | cast | float | bite | reel
	var bobber: Vector2 = Vector2.ZERO
	var cast_from: Vector2 = Vector2.ZERO
	var cast_to: Vector2 = Vector2.ZERO
	var cast_t: float = 1.0
	var jump_t: float = -1.0
	var jump_color: Color = Color.WHITE
	var jump_size: float = 60.0
	var bean: TextureRect

	func _ready() -> void:
		clip_contents = true
		bean = TextureRect.new()
		bean.texture = FishingPanel.TEX_BEAN
		bean.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bean.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bean.size = Vector2(78, 96)
		bean.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bean)
		resized.connect(_layout)

	func _layout() -> void:
		bean.position = Vector2(30, water_y() - 92)
		if mode == "idle":
			bobber = rod_tip()

	func water_y() -> float:
		return size.y * 0.5

	func rod_tip() -> Vector2:
		return Vector2(150, water_y() - 120)

	func start_cast(target_x: float) -> void:
		cast_from = rod_tip()
		cast_to = Vector2(target_x, water_y() + 18)
		cast_t = 0.0
		mode = "cast"

	func jump(color: Color, length: float) -> void:
		jump_t = 0.0
		jump_color = color
		jump_size = length

	func _process(delta: float) -> void:
		t += delta
		if mode == "cast":
			cast_t = minf(1.0, cast_t + delta * 2.2)
			var p := cast_from.lerp(cast_to, cast_t)
			p.y -= sin(cast_t * PI) * 90.0
			bobber = p
			if cast_t >= 1.0:
				mode = "float"
		if jump_t >= 0.0:
			jump_t += delta
			if jump_t > 1.1:
				jump_t = -1.0
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var wy := water_y()
		# Céu noturno de cassino
		for i in range(8):
			var k := float(i) / 8.0
			draw_rect(Rect2(0, wy * k, w, wy / 8.0 + 1), Color("#140F24").lerp(Color("#2A1E45"), k))
		draw_circle(Vector2(w - 90, 46), 26, Color("#FFF2C4"))
		draw_circle(Vector2(w - 80, 40), 24, Color("#211833"))
		for i in range(14):
			var sx := fmod(i * 97.3, w - 20) + 10
			var sy := fmod(i * 53.7, wy - 40) + 10
			draw_circle(Vector2(sx, sy), 1.2 + 0.6 * sin(t * 2.0 + i), Color(1, 1, 1, 0.55))
		# Skyline de cassinos ao fundo
		var bx := 220.0
		var heights := [60, 95, 70, 120, 80, 105, 65, 90]
		for i in range(heights.size()):
			var bh: float = heights[i]
			var bw := 46.0
			draw_rect(Rect2(bx, wy - bh, bw, bh), Color("#1A1230"))
			for wx in range(3):
				for wyy in range(int(bh / 18.0)):
					if int(i * 7 + wx * 3 + wyy) % 3 != 0:
						draw_rect(Rect2(bx + 8 + wx * 12, wy - bh + 8 + wyy * 18, 5, 7), Color("#E0B840", 0.55))
			bx += bw + 18.0
		# Água
		for i in range(10):
			var k := float(i) / 10.0
			draw_rect(Rect2(0, wy + (h - wy) * k, w, (h - wy) / 10.0 + 1), Color("#0F3B4A").lerp(Color("#06141C"), k))
		for row in range(6):
			var yy := wy + 14 + row * ((h - wy) / 6.0)
			var pts := PackedVector2Array()
			var x := 0.0
			while x <= w:
				pts.append(Vector2(x, yy + sin(x * 0.03 + t * (1.2 + row * 0.2) + row) * (2.0 + row * 0.6)))
				x += 12.0
			draw_polyline(pts, Color(0.55, 0.85, 1.0, 0.08 + row * 0.015), 1.5, true)
		# Reflexo dourado da lua
		for i in range(5):
			var ry := wy + 20 + i * 16
			var rw := 40.0 - i * 5 + sin(t * 2.0 + i) * 6.0
			draw_line(Vector2(w - 90 - rw * 0.5, ry), Vector2(w - 90 + rw * 0.5, ry), Color("#FFE08A", 0.35 - i * 0.05), 2.0)
		# Píer
		draw_rect(Rect2(0, wy - 6, 175, 14), Color("#5A3E26"))
		draw_rect(Rect2(0, wy - 6, 175, 4), Color("#7A5636"))
		for px in [20.0, 80.0, 140.0]:
			draw_rect(Rect2(px, wy + 8, 10, 60), Color("#3E2A18"))
		# Luz de contorno atrás do Bean (gato preto some no fundo escuro sem isso)
		draw_circle(Vector2(68, wy - 48), 58, Color(1.0, 0.85, 0.5, 0.10))
		draw_circle(Vector2(68, wy - 48), 42, Color(1.0, 0.85, 0.5, 0.10))
		# Vara
		var tip := rod_tip()
		draw_line(Vector2(84, wy - 52), tip, Color("#C9A66B"), 4.0)
		draw_line(Vector2(84, wy - 52), tip, Color("#6B4A24"), 1.5)
		# Boia e linha
		if mode == "idle":
			return
		var b := bobber
		if mode == "float":
			b.y += sin(t * 2.4) * 2.5
		elif mode == "bite":
			b.y += 6.0 + sin(t * 26.0) * 6.0
			for k in range(3):
				var rr := fmod(t * 60.0 + k * 20.0, 60.0)
				draw_arc(Vector2(bobber.x, bobber.y + 4), rr, 0, TAU, 32, Color(1, 1, 1, 0.5 - rr / 120.0), 2.0)
		elif mode == "reel":
			b += Vector2(sin(t * 31.0) * 3.0, 6.0 + cos(t * 23.0) * 3.0)
		var mid := (tip + b) * 0.5 + Vector2(0, 0 if mode == "reel" else 26)
		var curve := PackedVector2Array()
		for i in range(13):
			var k := float(i) / 12.0
			curve.append(tip.lerp(mid, k).lerp(mid.lerp(b, k), k))
		draw_polyline(curve, Color(1, 1, 1, 0.65), 1.2, true)
		if mode != "cast":
			draw_arc(Vector2(b.x, b.y + 6), 12 + sin(t * 3.0) * 2.0, 0, TAU, 24, Color(1, 1, 1, 0.18), 1.5)
		draw_circle(b, 7, Color("#F2F2F2"))
		draw_circle(b + Vector2(0, -3), 7, Color("#E53935"))
		draw_circle(b + Vector2(-2, -5), 2, Color(1, 1, 1, 0.7))
		# Peixe saltando da água ao ser fisgado
		if jump_t >= 0.0:
			var k := jump_t / 1.1
			var jp := Vector2(bobber.x + (k - 0.5) * 80.0, wy + 10 - sin(k * PI) * 110.0)
			FishingPanel.draw_fish(self, jp, jump_size, jump_color, true)


# ══════════════════════════════════════
# CONSTRUÇÃO
# ══════════════════════════════════════

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := UIKit.modal(self, Vector2(960, 0), UIKit.CYAN)
	_overlay = parts[0]
	var panel: PanelContainer = parts[1]
	var root := UIKit.vbox(6)
	panel.add_child(root)

	var head := UIKit.hbox(8)
	root.add_child(head)
	var tv := UIKit.vbox(0)
	head.add_child(tv)
	tv.add_child(UIKit.title("PESQUE-PAGUE DO JEFF", 24, UIKit.CYAN))
	tv.add_child(UIKit.caption("Lago da Liquidez · você pesca, ele cobra", UIKit.MUTED))
	head.add_child(UIKit.spacer())
	var close := UIKit.button("✕", "ghost", 16, Vector2(40, 36))
	close.pressed.connect(close_screen)
	head.add_child(close)

	_bubble = MeowzosBubble.new(Vector2(44, 55), 13, true)
	root.add_child(_bubble)

	var body := UIKit.hbox(14)
	root.add_child(body)

	# ── Lago ──
	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var frame := UIKit.panel(UIKit.lcd(3))
	left.add_child(frame)
	_lake = LakeView.new()
	_lake.custom_minimum_size = Vector2(580, 236)
	frame.add_child(_lake)
	_tension = TensionBar.new()
	_tension.custom_minimum_size = Vector2(0, 26)
	_tension.modulate.a = 0.0
	left.add_child(_tension)
	_status = UIKit.ticker("Lance a linha. O lago é do Jeff, mas o peixe é seu. Por enquanto.", 14, Color("#F2E6C2"), HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 30)
	left.add_child(_status)
	_action_btn = UIKit.button("LANÇAR LINHA  [ESPAÇO]", "gold", 17, Vector2(0, 50))
	_action_btn.add_theme_font_override("font", UIKit.display_font())
	_action_btn.pressed.connect(_on_action)
	left.add_child(_action_btn)

	# ── Cesta, cotação e varas ──
	var right := UIKit.vbox(8)
	right.custom_minimum_size = Vector2(300, 0)
	body.add_child(right)

	var cooler := UIKit.panel(UIKit.deco(Color("#0C0A14"), Color(0.33, 0.28, 0.45, 0.8), 10))
	cooler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(cooler)
	var cv := UIKit.vbox(5)
	cooler.add_child(cv)
	_cooler_header = UIKit.caption("Cesta", UIKit.GOLD_LIGHT)
	cv.add_child(_cooler_header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(scroll)
	_cooler_list = UIKit.vbox(3)
	_cooler_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cooler_list)
	_cooler_total = UIKit.ticker("", 13, UIKit.AMBER)
	cv.add_child(_cooler_total)

	var market := UIKit.panel(UIKit.lcd(8))
	right.add_child(market)
	var mv := UIKit.vbox(3)
	market.add_child(mv)
	var mrow := UIKit.hbox(6)
	mv.add_child(mrow)
	mrow.add_child(UIKit.caption("Cotação do pescado", Color(UIKit.AMBER, 0.7)))
	mrow.add_child(UIKit.spacer())
	_price_label = UIKit.ticker("", 14, UIKit.PROFIT)
	mrow.add_child(_price_label)
	_spark = Sparkline.new()
	_spark.custom_minimum_size = Vector2(0, 30)
	_spark.source = func() -> float: return Fishing.price_index()
	mv.add_child(_spark)
	_sell_btn = UIKit.button("VENDER TUDO", "success", 14, Vector2(0, 42))
	_sell_btn.add_theme_font_override("font", UIKit.display_font())
	_sell_btn.pressed.connect(_on_sell)
	right.add_child(_sell_btn)

	var rod := UIKit.panel(UIKit.deco(Color("#0C0A14"), Color(UIKit.CYAN, 0.5), 8))
	right.add_child(rod)
	var rv := UIKit.vbox(3)
	rod.add_child(rv)
	_rod_name = UIKit.label("", 12, UIKit.INK)
	_rod_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_rod_name)
	_rod_next = UIKit.wrap_label("", 11, UIKit.MUTED)
	rv.add_child(_rod_next)
	_rod_btn = UIKit.button("", "purple", 12, Vector2(0, 34))
	_rod_btn.pressed.connect(_on_buy_rod)
	rv.add_child(_rod_btn)
	_stats_label = UIKit.caption("", UIKit.DIM)
	right.add_child(_stats_label)

	Fishing.changed.connect(_refresh_side)
	_refresh_side()


# ══════════════════════════════════════
# ABRIR / FECHAR
# ══════════════════════════════════════

# Fechar e reabrir rápido não pode deixar o tween de fechar esconder a janela reaberta
var _is_open: bool = false
var _fade: Tween


func _fade_to(alpha: float, time: float, hide_after: bool) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_overlay, "modulate:a", alpha, time)
	if hide_after:
		_fade.tween_callback(func():
			if not _is_open:
				_overlay.visible = false)


func open() -> void:
	_is_open = true
	_overlay.visible = true
	if _overlay.modulate.a > 0.99:
		_overlay.modulate.a = 0.0
	_fade_to(1.0, 0.2, false)
	_refresh_side()
	if Fishing.cooler_full():
		Meowzos.say_key("fish_full", {}, "smug")
	else:
		Meowzos.say_key("fish_open", {}, "smug")


func close_screen() -> void:
	if _state == State.REELING or _state == State.BITE:
		Meowzos.say("Vai largar o peixe no meio da negociação? Que falta de profissionalismo.", "angry")
		return
	_reset_line()
	_is_open = false
	_fade_to(0.0, 0.15, true)


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_on_action()
		get_viewport().set_input_as_handled()


# ══════════════════════════════════════
# LOOP DA PESCA
# ══════════════════════════════════════

func _on_action() -> void:
	match _state:
		State.IDLE:
			_cast()
		State.WAITING:
			_status_text("Puxou cedo demais. O peixe riu da sua cara e mudou de lago.", UIKit.RISK)
			sfx.emit("lose")
			_finish_round(0.9)
		State.BITE:
			_start_reel()
		State.REELING:
			_try_hook()


func _cast() -> void:
	if Fishing.cooler_full():
		_status_text("Cesta cheia! Venda os peixes antes de pescar mais.", UIKit.RISK)
		UIKit.flash(_sell_btn, Color(1.6, 1.6, 0.8), 0.8)
		Meowzos.say_key("fish_full", {}, "smug")
		return
	_state = State.CASTING
	_lake.start_cast(randf_range(_lake.size.x * 0.42, _lake.size.x * 0.8))
	_timer = 0.5
	_action_btn.disabled = true
	_action_btn.text = "LANÇANDO..."
	sfx.emit("click")


func _process(delta: float) -> void:
	if not is_open():
		return
	_refresh_accum += delta
	if _refresh_accum >= 0.25:
		_refresh_accum = 0.0
		_refresh_market()

	match _state:
		State.CASTING:
			_timer -= delta
			if _timer <= 0.0:
				_state = State.WAITING
				_timer = randf_range(1.4, 4.0)
				_action_btn.disabled = false
				_action_btn.text = "AGUARDE A FISGADA..."
				_set_button_kind("ghost")
				_status_text(WAIT_QUIPS[randi() % WAIT_QUIPS.size()], UIKit.MUTED)
		State.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_bite()
		State.BITE:
			_timer -= delta
			if _timer <= 0.0:
				Fishing.register_escape()
				_status_text("Escapou. Foi trabalhar numa concorrente que paga melhor.", UIKit.RISK)
				Meowzos.say_key("fish_escape", {}, "smug")
				sfx.emit("lose")
				_finish_round(1.0)
		State.REELING:
			_marker += _dir * _speed * delta
			if _marker >= 1.0:
				_marker = 1.0
				_dir = -1.0
			elif _marker <= 0.0:
				_marker = 0.0
				_dir = 1.0
			_tension.marker = _marker
			_tension.queue_redraw()
			_timer -= delta
			if _timer <= 0.0:
				Fishing.register_escape()
				_status_text("O peixe cansou de esperar e foi fazer um MBA.", UIKit.RISK)
				sfx.emit("lose")
				_finish_round(1.0)
		State.RESULT:
			_timer -= delta
			if _timer <= 0.0:
				_reset_line()


func _bite() -> void:
	_state = State.BITE
	_rarity = Fishing.roll_rarity()
	_timer = Fishing.bite_window()
	_lake.mode = "bite"
	_action_btn.text = "PUXA!  [ESPAÇO]"
	_set_button_kind("danger")
	UIKit.pop(_action_btn, 1.08, 0.2)
	var big := _rarity >= Fishing.Rarity.EPICO
	_status_text("ALGO GRANDE MORDEU! PUXA!" if big else "FISGOU! PUXA!", Fishing.RARITY_COLORS[_rarity] if big else UIKit.GOLD_LIGHT)
	sfx.emit("click")


func _start_reel() -> void:
	_state = State.REELING
	_lake.mode = "reel"
	_hits_left = Fishing.RARITY_HITS[_rarity]
	_speed = Fishing.RARITY_SPEED[_rarity]
	_zone_w = Fishing.zone_width(_rarity)
	_marker = 0.0
	_dir = 1.0
	_timer = REEL_TIMEOUT
	_new_zone()
	_tension.color = Fishing.RARITY_COLORS[_rarity]
	var tw := create_tween()
	tw.tween_property(_tension, "modulate:a", 1.0, 0.12)
	_action_btn.text = "FISGAR NA ZONA!  [ESPAÇO]"
	_set_button_kind("success")
	_status_text("Peixe %s na linha! Clique quando o marcador estiver na zona." % Fishing.RARITY_NAMES[_rarity], Fishing.RARITY_COLORS[_rarity])


func _new_zone() -> void:
	_zone_center = randf_range(_zone_w * 0.5 + 0.05, 1.0 - _zone_w * 0.5 - 0.05)
	_tension.zone_center = _zone_center
	_tension.zone_w = _zone_w
	_tension.hits_left = _hits_left
	_tension.queue_redraw()


func _try_hook() -> void:
	if absf(_marker - _zone_center) <= _zone_w * 0.5:
		_hits_left -= 1
		sfx.emit("click")
		UIKit.flash(_tension, Color(1.5, 1.5, 1.5), 0.25)
		if _hits_left <= 0:
			_land_fish()
		else:
			_speed *= 1.12
			_timer = REEL_TIMEOUT
			_new_zone()
			_status_text("Boa! Ainda resiste. Mais %d!" % _hits_left, Fishing.RARITY_COLORS[_rarity])
	else:
		Fishing.register_escape()
		UIKit.shake(_tension, 8.0, 0.3)
		_status_text("A linha arrebentou. Material terceirizado, né.", UIKit.RISK)
		Meowzos.say_key("fish_escape", {}, "smug")
		sfx.emit("lose")
		_finish_round(1.1)


func _land_fish() -> void:
	var fish := Fishing.roll_fish(_rarity)
	Fishing.add_catch(fish)
	var col := Color(fish["color"])
	_lake.jump(col, 46.0 + _rarity * 14.0)
	var value := NumberFormatter.format_number(Fishing.net_value(fish))
	_status_text("%s fisgado! %s · %s kg · vale ~%s agora" % [fish["name"], Fishing.RARITY_NAMES[_rarity], str(fish["kg"]).replace(".", ","), value], Fishing.RARITY_COLORS[_rarity])
	match _rarity:
		Fishing.Rarity.LENDARIO:
			Meowzos.say_key("fish_legend", {"fish": fish["name"]}, "shock")
			sfx.emit("big_win")
		Fishing.Rarity.EPICO:
			Meowzos.say_key("fish_big", {"fish": fish["name"]}, "shock")
			sfx.emit("win")
		_:
			if randf() < 0.4:
				Meowzos.say_key("fish_catch", {"fish": fish["name"]}, "smug")
			sfx.emit("win")
	_finish_round(1.3)


func _finish_round(delay: float) -> void:
	_state = State.RESULT
	_timer = delay
	_action_btn.disabled = true
	if _lake.mode != "idle":
		_lake.mode = "float"
	var tw := create_tween()
	tw.tween_property(_tension, "modulate:a", 0.0, 0.2)


func _reset_line() -> void:
	_state = State.IDLE
	_lake.mode = "idle"
	_lake.bobber = _lake.rod_tip()
	_tension.modulate.a = 0.0
	_action_btn.disabled = false
	_action_btn.text = "CESTA CHEIA — VENDA" if Fishing.cooler_full() else "LANÇAR LINHA  [ESPAÇO]"
	_set_button_kind("gold")


func _set_button_kind(kind: String) -> void:
	var palette := {
		"gold": [Color("#C99A22"), Color("#7A5A10"), UIKit.GOLD_LIGHT, Color("#1E1404")],
		"danger": [Color("#9E1F27"), Color("#5A0E14"), Color("#FF6B6B"), Color("#FFE3E3")],
		"success": [Color("#1F7A4C"), Color("#0E3F27"), UIKit.PROFIT, Color("#E6FFF1")],
		"ghost": [Color("#1E1A2C"), Color("#3E3854"), UIKit.GOLD, UIKit.INK],
	}
	var p: Array = palette[kind]
	var font_col: Color = p[3]
	UIKit.apply_key(_action_btn, p[0], p[1], p[2])
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_action_btn.add_theme_color_override(c, font_col)


func _status_text(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


# ══════════════════════════════════════
# CESTA, MERCADO E VARAS
# ══════════════════════════════════════

func _on_sell() -> void:
	var r := Fishing.sell_all()
	if r.is_empty():
		_status_text("A cesta está vazia. Nem o Jeff consegue cobrar taxa de nada. (Ainda.)", UIKit.MUTED)
		return
	sfx.emit("big_win" if float(r["net"]) > GameManager.cps * 600.0 else "win")
	UIKit.pop(_sell_btn, 1.08)
	_status_text("Vendeu %d peixes por %s. O Jeff ficou com %s de 'atravessador'." % [
		r["count"], NumberFormatter.format_number(r["net"]), NumberFormatter.format_number(r["fee"])], UIKit.PROFIT)
	Meowzos.say_key("fish_sell", {"fee": NumberFormatter.format_number(r["fee"])}, "smug")
	if _state == State.IDLE:
		_reset_line()


func _on_buy_rod() -> void:
	if Fishing.buy_next_rod():
		sfx.emit("win")
		Meowzos.say_key("fish_rod", {"rod": Fishing.RODS[Fishing.rod_tier][0]}, "smug")
		UIKit.pop(_rod_btn, 1.08)


func _refresh_side() -> void:
	if _cooler_list == null:
		return
	for c in _cooler_list.get_children():
		c.queue_free()
	for f in Fishing.cooler:
		var row := UIKit.hbox(6)
		var icon := FishIcon.new()
		icon.color = Color(f["color"])
		icon.custom_minimum_size = Vector2(34, 18)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var nm := UIKit.label(str(f["name"]), 12, Fishing.RARITY_COLORS[int(f["rarity"])])
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		row.add_child(nm)
		var val := UIKit.ticker(NumberFormatter.format_number(Fishing.net_value(f)), 11, UIKit.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
		val.set_meta("fish", f)
		row.add_child(val)
		row.tooltip_text = "%s (%s) · %s kg\n\"%s\"" % [f["name"], Fishing.RARITY_NAMES[int(f["rarity"])], str(f["kg"]).replace(".", ","), f["desc"]]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		_cooler_list.add_child(row)
	if Fishing.cooler.is_empty():
		_cooler_list.add_child(UIKit.wrap_label("Vazia. Igual à promessa de aumento.", 11, UIKit.DIM))
	_cooler_header.text = "CESTA  %d/%d" % [Fishing.cooler.size(), Fishing.COOLER_CAPACITY]
	_cooler_header.add_theme_color_override("font_color", UIKit.RISK if Fishing.cooler_full() else UIKit.GOLD_LIGHT)

	var rod: Array = Fishing.RODS[Fishing.rod_tier]
	_rod_name.text = "Vara: %s" % rod[0]
	var nxt := Fishing.next_rod()
	if nxt.is_empty():
		_rod_next.text = "Você tem a melhor vara do lago. O Jeff está processando você por concorrência desleal."
		_rod_btn.visible = false
	else:
		_rod_next.text = "Próxima: %s — sorte x%.1f, zona +%d%%. \"%s\"" % [nxt[0], nxt[2], int(float(nxt[3]) * 100.0), nxt[5]]
		_rod_btn.visible = true
		_rod_btn.text = "COMPRAR  BNC %s" % NumberFormatter.format_number(nxt[1])
	_stats_label.text = "pescados %d · vendidos %d · fugiram %d" % [Fishing.total_caught, Fishing.total_sold, Fishing.total_escaped]
	if _state == State.IDLE:
		_action_btn.text = "CESTA CHEIA — VENDA" if Fishing.cooler_full() else "LANÇAR LINHA  [ESPAÇO]"
	_refresh_market()


func _refresh_market() -> void:
	var idx := Fishing.price_index()
	var up := idx >= 1.0
	_price_label.text = "%s %.2fx" % ["▲" if up else "▼", idx]
	_price_label.text = _price_label.text.replace(".", ",")
	_price_label.add_theme_color_override("font_color", UIKit.PROFIT if up else UIKit.RISK)
	var total := Fishing.cooler_value()
	_cooler_total.text = "Valor na cesta: BNC %s" % NumberFormatter.format_number(total)
	_sell_btn.disabled = Fishing.cooler.is_empty()
	_sell_btn.text = "VENDER TUDO  (−10% p/ o Jeff)" if not Fishing.cooler.is_empty() else "CESTA VAZIA"
	for row in _cooler_list.get_children():
		if row.get_child_count() >= 3:
			var val: Label = row.get_child(2)
			if val.has_meta("fish"):
				val.text = NumberFormatter.format_number(Fishing.net_value(val.get_meta("fish")))
	var nxt := Fishing.next_rod()
	if not nxt.is_empty():
		_rod_btn.disabled = not GameManager.can_afford(float(nxt[1]))
