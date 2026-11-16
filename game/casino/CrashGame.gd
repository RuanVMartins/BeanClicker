extends CasinoGame
## FOGUETINHO (Crash) — "igual a uma startup: sobe rápido e explode sem aviso".
##
## Correção de balanceamento: a versão antiga sorteava o crash com
## 1.01 + u^2.8 * 8.99, o que dava RTP de ~127% sacando em 4-5x (dinheiro
## infinito). Agora usamos a fórmula padrão do gênero:
##     crash = 0.96 / (1 - u)        → P(crash >= m) = 0.96 / m
## Ou seja, QUALQUER estratégia de saque tem RTP 96%. 4% das rodadas explodem
## em 1.00x. O jogador escolhe a volatilidade, a casa mantém a margem.

const HOUSE_EDGE: float = 0.04
const GROWTH: float = 0.11          # m(t) = e^(0.11 t): 2x em 6.3s, 10x em 21s
const MAX_CRASH: float = 250.0
const AUTO_OPTIONS: Array[float] = [0.0, 1.5, 2.0, 3.0, 5.0, 10.0]

enum State { READY, FLYING, DONE }

var _state: State = State.READY
var _graph: CrashGraph
var _mult_label: Label
var _action_btn: Button
var _auto_opt: OptionButton
var _history_row: HBoxContainer
var _result: Label
var _t: float = 0.0
var _mult: float = 1.0
var _crash_at: float = 1.0
var _bet: float = 0.0
var _auto_target: float = 0.0


class CrashGraph extends Control:
	var points: PackedVector2Array = PackedVector2Array()
	var crashed: bool = false
	var cashed_at: float = 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.03, 0.06, 0.05, 0.9))
		var max_t := 8.0
		var max_m := 2.0
		if points.size() > 0:
			max_t = maxf(max_t, points[-1].x * 1.1)
			max_m = maxf(max_m, points[-1].y * 1.15)
		# Grade horizontal com rótulos de multiplicador
		var font := ThemeDB.fallback_font
		var steps: Array[float] = [1.0, 1.5, 2.0, 3.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0]
		for m in steps:
			if m > max_m:
				break
			var y := size.y - (m - 1.0) / (max_m - 1.0) * (size.y - 20.0) - 10.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.07), 1.0)
			draw_string(font, Vector2(6, y - 3), ("%dx" % int(m)) if m == floor(m) else ("%.1fx" % m), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.35))
		if points.size() < 2:
			return
		var pts := PackedVector2Array()
		for p in points:
			pts.append(Vector2(p.x / max_t * (size.x - 40.0) + 20.0, size.y - (p.y - 1.0) / (max_m - 1.0) * (size.y - 20.0) - 10.0))
		var col := Color("#FF4D4D") if crashed else Color("#48F29A")
		# Área preenchida sob a curva
		var fill := pts.duplicate()
		fill.append(Vector2(pts[-1].x, size.y))
		fill.append(Vector2(pts[0].x, size.y))
		draw_colored_polygon(fill, Color(col, 0.12))
		draw_polyline(pts, col, 3.0, true)
		draw_circle(pts[-1], 6.0, col)
		if cashed_at > 0.0:
			var cy := size.y - (cashed_at - 1.0) / (max_m - 1.0) * (size.y - 20.0) - 10.0
			draw_dashed_line(Vector2(0, cy), Vector2(size.x, cy), Color("#FFE08A"), 1.5, 6.0)


func game_id() -> String:
	return "crash"


func tab_title() -> String:
	return "Foguetinho"


func intro_key() -> String:
	return "tab_crash"


func rules_text() -> String:
	return "Saque antes da explosão  •  RTP 96% em qualquer estratégia"


func build() -> void:
	add_theme_constant_override("separation", 8)
	add_child(header("FOGUETINHO"))

	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(0, 220)
	area.clip_contents = true
	add_child(area)
	_graph = CrashGraph.new()
	_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(_graph)
	_mult_label = UIKit.title("1.00x", 56, UIKit.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_mult_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mult_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	area.add_child(_mult_label)

	_history_row = UIKit.hbox(4)
	add_child(_history_row)

	_result = result_label()
	add_child(_result)

	var row := UIKit.hbox(8)
	add_child(row)
	var auto_box := UIKit.vbox(0)
	row.add_child(auto_box)
	auto_box.add_child(UIKit.label("Auto-saque", 10, UIKit.MUTED))
	_auto_opt = OptionButton.new()
	_auto_opt.custom_minimum_size = Vector2(120, 32)
	for v in AUTO_OPTIONS:
		_auto_opt.add_item("Manual" if v == 0.0 else "%.1fx" % v)
	_auto_opt.select(2)
	auto_box.add_child(_auto_opt)
	_action_btn = big_button("DECOLAR")
	_action_btn.pressed.connect(_on_action)
	row.add_child(_action_btn)


func _on_action() -> void:
	match _state:
		State.READY:
			_launch()
		State.FLYING:
			_cash_out()


func _launch() -> void:
	_bet = take_bet()
	if _bet <= 0.0:
		return
	set_busy(true)
	_auto_target = AUTO_OPTIONS[_auto_opt.selected]
	_auto_opt.disabled = true
	var u := randf()
	_crash_at = clampf(floor((1.0 - HOUSE_EDGE) / maxf(1.0 - u, 0.0001) * 100.0) / 100.0, 1.0, MAX_CRASH)
	_t = 0.0
	_mult = 1.0
	_graph.points = PackedVector2Array([Vector2(0, 1)])
	_graph.crashed = false
	_graph.cashed_at = 0.0
	_mult_label.add_theme_color_override("font_color", UIKit.GOLD_LIGHT)
	_result.text = ""
	_state = State.FLYING
	menu.emit_sfx("click")


func _process(delta: float) -> void:
	if _state != State.FLYING:
		return
	_t += delta
	_mult = exp(GROWTH * _t)
	# Auto-saque tem prioridade quando o alvo fica abaixo do ponto de crash
	if _auto_target > 0.0 and _mult >= _auto_target and _auto_target <= _crash_at:
		_mult = _auto_target
		_graph.points.append(Vector2(_t, _mult))
		_cash_out()
		return
	if _mult >= _crash_at:
		_mult = _crash_at
		_graph.points.append(Vector2(_t, _mult))
		_explode()
		return
	_graph.points.append(Vector2(_t, _mult))
	_graph.queue_redraw()
	_mult_label.text = "%.2fx" % _mult
	_action_btn.text = "SACAR  %s" % NumberFormatter.format_number(_bet * _mult)


func _cash_out() -> void:
	if _state != State.FLYING:
		return
	_state = State.DONE
	var paid := settle(_bet, _bet * _mult)
	_graph.cashed_at = _mult
	_graph.queue_redraw()
	_mult_label.add_theme_color_override("font_color", UIKit.PROFIT)
	show_result(_result, "SACOU EM %.2fx  (+%s)  •  ia explodir em %.2fx" % [_mult, NumberFormatter.format_number(paid - _bet), _crash_at], UIKit.PROFIT)
	if _mult >= 5.0:
		GameManager.unlock_achievement("bet_crash_high")
	_action_btn.disabled = true
	# Mostra onde o foguete ia explodir — para doer (ou aliviar)
	_add_history(_crash_at)
	await wait(1.4)
	_reset()


func _explode() -> void:
	_state = State.DONE
	_graph.crashed = true
	_graph.queue_redraw()
	_mult_label.text = "BOOM  %.2fx" % _crash_at
	_mult_label.add_theme_color_override("font_color", UIKit.RISK)
	UIKit.shake(_mult_label, 10.0, 0.4)
	settle(_bet, 0.0)
	show_result(_result, "O foguete explodiu. Igual a sua startup. -%s" % NumberFormatter.format_number(_bet), UIKit.RISK)
	_action_btn.disabled = true
	_add_history(_crash_at)
	await wait(1.6)
	_reset()


func _reset() -> void:
	_state = State.READY
	_action_btn.disabled = false
	_action_btn.text = "DECOLAR"
	_auto_opt.disabled = false
	set_busy(false)


func _add_history(m: float) -> void:
	var col := UIKit.RISK if m < 2.0 else (UIKit.PROFIT if m < 10.0 else UIKit.GOLD)
	var chip := UIKit.panel(UIKit.box(Color(col, 0.18), col, 6, 1, 4))
	chip.add_child(UIKit.label("%.2fx" % m, 11, col))
	_history_row.add_child(chip)
	_history_row.move_child(chip, 0)
	while _history_row.get_child_count() > 10:
		var last := _history_row.get_child(_history_row.get_child_count() - 1)
		_history_row.remove_child(last)
		last.queue_free()
