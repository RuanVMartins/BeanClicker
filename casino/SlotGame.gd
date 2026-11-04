extends CasinoGame
## CAÇA-NÍQUEL CORPORATIVO — 3 rolos com símbolos do próprio império.
## Rolos ponderados (pesos 7/5/4/3/2/1 de 22). Pagamentos (aposta x):
##   3x Moeda 8 | 3x Fazendeiro 15 | 3x Plantação 25 | 3x Mina 40 | 3x Fábrica 90 | 3x Bean Cósmico 250
##   2x Bean Cósmico = 6x | 1x Bean Cósmico = devolve a aposta ("prêmio de consolação")
## RTP exato: 93,6%. Taxa de acerto ~18% — perde-se muito, ganha-se grande.

const SYMBOLS: Array[Dictionary] = [
	{"id": "moeda", "name": "Moeda", "tex": preload("res://images/BeansCoins.png"), "w": 7, "pay": 8.0},
	{"id": "fazendeiro", "name": "Fazendeiro", "tex": preload("res://images/fazendeiro.png"), "w": 5, "pay": 15.0},
	{"id": "plantacao", "name": "Plantação", "tex": preload("res://images/plantacao.png"), "w": 4, "pay": 25.0},
	{"id": "mina", "name": "Mina", "tex": preload("res://images/mina.png"), "w": 3, "pay": 40.0},
	{"id": "fabrica", "name": "Fábrica", "tex": preload("res://images/fabrica.png"), "w": 2, "pay": 90.0},
	{"id": "bean", "name": "Bean Cósmico", "tex": preload("res://images/BeansRainbow.png"), "w": 1, "pay": 250.0},
]
const STOP_TIMES: Array[float] = [0.75, 1.1, 1.45]
const FLICKER: float = 0.06

var _reels: Array[TextureRect] = []
var _reel_panels: Array[PanelContainer] = []
var _spin_btn: Button
var _auto_btn: Button
var _result: Label
var _spinning: bool = false
var _spin_t: float = 0.0
var _flicker_t: float = 0.0
var _final: Array[int] = [0, 0, 0]
var _stopped: Array[bool] = [true, true, true]
var _bet: float = 0.0
var _auto_left: int = 0


func game_id() -> String:
	return "slot"


func tab_title() -> String:
	return "Caça-Níquel"


func intro_key() -> String:
	return "tab_slot"


func rules_text() -> String:
	return "3 iguais pagam até 250x  •  Bean Cósmico é coringa de consolo"


func build() -> void:
	add_theme_constant_override("separation", 10)
	add_child(header("CAÇA-NÍQUEL CORPORATIVO"))

	var reels_row := UIKit.hbox(14)
	reels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reels_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(reels_row)
	for i in range(3):
		var p := UIKit.panel(UIKit.shadowed(UIKit.box(Color(0.97, 0.94, 0.86), UIKit.GOLD, 12, 4, 10), 8, 0.5))
		p.custom_minimum_size = Vector2(150, 150)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		reels_row.add_child(p)
		var tr := UIKit.texture_rect(SYMBOLS[0]["tex"], Vector2(124, 124))
		p.add_child(tr)
		_reels.append(tr)
		_reel_panels.append(p)

	# Tabela de pagamentos em ícones
	var pay_row := UIKit.hbox(10)
	pay_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pay_row)
	for s in SYMBOLS:
		var h := UIKit.hbox(2)
		h.add_child(UIKit.texture_rect(s["tex"], Vector2(22, 22)))
		h.add_child(UIKit.label("x%d" % int(s["pay"]), 12, UIKit.GOLD_LIGHT))
		pay_row.add_child(h)

	_result = result_label()
	add_child(_result)

	var btns := UIKit.hbox(8)
	add_child(btns)
	_spin_btn = big_button("PUXAR ALAVANCA")
	_spin_btn.pressed.connect(_on_spin)
	btns.add_child(_spin_btn)
	_auto_btn = big_button("AUTO x10", "purple")
	_auto_btn.size_flags_horizontal = Control.SIZE_FILL
	_auto_btn.custom_minimum_size = Vector2(150, 46)
	_auto_btn.tooltip_text = "Gira 10 vezes seguidas. Pensar dá trabalho, o Jeff Meowzos entende."
	_auto_btn.pressed.connect(_on_auto)
	btns.add_child(_auto_btn)

	for i in range(3):
		_reels[i].texture = SYMBOLS[randi() % SYMBOLS.size()]["tex"]


func _pick() -> int:
	var total := 0
	for s in SYMBOLS:
		total += int(s["w"])
	var r := randi() % total
	for i in range(SYMBOLS.size()):
		r -= int(SYMBOLS[i]["w"])
		if r < 0:
			return i
	return 0


func _on_spin() -> void:
	if _spinning:
		return
	_start_spin()


func _on_auto() -> void:
	if _auto_left > 0:
		_auto_left = 0
		_auto_btn.text = "AUTO x10"
		return
	if _spinning:
		return
	_auto_left = 10
	_auto_btn.text = "PARAR (10)"
	_start_spin()


func _start_spin() -> void:
	_bet = take_bet()
	if _bet <= 0.0:
		_stop_auto()
		return
	set_busy(true)
	_spinning = true
	_spin_t = 0.0
	_stopped = [false, false, false]
	_final = [_pick(), _pick(), _pick()]
	_spin_btn.disabled = true
	_result.text = ""
	for p in _reel_panels:
		p.modulate = Color.WHITE


func _process(delta: float) -> void:
	if not _spinning:
		return
	_spin_t += delta
	_flicker_t += delta
	var flick := _flicker_t >= FLICKER
	if flick:
		_flicker_t = 0.0
	for i in range(3):
		if _stopped[i]:
			continue
		if _spin_t >= STOP_TIMES[i]:
			_stopped[i] = true
			_reels[i].texture = SYMBOLS[_final[i]]["tex"]
			UIKit.pop(_reel_panels[i], 1.08, 0.2)
			menu.emit_sfx("click")
		elif flick:
			_reels[i].texture = SYMBOLS[randi() % SYMBOLS.size()]["tex"]
	if _stopped[2]:
		_spinning = false
		_evaluate()


func _evaluate() -> void:
	var a := _final[0]
	var b := _final[1]
	var c := _final[2]
	var bean_idx := SYMBOLS.size() - 1
	var mult := 0.0
	var text := ""
	if a == b and b == c:
		mult = SYMBOLS[a]["pay"]
		text = "3x %s! PAGOU %dx" % [SYMBOLS[a]["name"], int(mult)]
		for p in _reel_panels:
			UIKit.flash(p, Color(1.5, 1.4, 0.6), 0.8)
		GameManager.unlock_achievement("bet_jackpot")
	else:
		var beans := [a, b, c].count(bean_idx)
		if beans == 2:
			mult = 6.0
			text = "2 Beans Cósmicos! 6x"
		elif beans == 1:
			mult = 1.0
			text = "Prêmio de consolação: sua aposta de volta."
	var paid := settle(_bet, _bet * mult)
	if mult > 1.0:
		show_result(_result, "%s  (+%s)" % [text, NumberFormatter.format_number(paid - _bet)], UIKit.PROFIT)
	elif mult == 1.0:
		show_result(_result, text, UIKit.MUTED)
	else:
		show_result(_result, "Nada. A casa agradece a doação.", UIKit.RISK)
		_near_miss_tease(a, b, c)

	_spin_btn.disabled = false
	if _auto_left > 0:
		_auto_left -= 1
		_auto_btn.text = "PARAR (%d)" % _auto_left if _auto_left > 0 else "AUTO x10"
		if _auto_left > 0:
			await wait(0.45)
			if _auto_left > 0 and is_inside_tree():
				_start_spin()
				return
	set_busy(false)


## Dois iguais e um diferente = "quase!" — manipulação de near-miss, tema do jogo.
func _near_miss_tease(a: int, b: int, c: int) -> void:
	if a == b or b == c or a == c:
		_result.text += "  QUASE!"


func _stop_auto() -> void:
	_auto_left = 0
	_auto_btn.text = "AUTO x10"
	set_busy(false)
