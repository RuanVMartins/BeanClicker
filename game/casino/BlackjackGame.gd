extends CasinoGame
## 21 FELINO — blackjack de baralho infinito.
## Regras: dealer compra até 17; Blackjack natural paga 3:2; "Dobrar" com 2 cartas;
## empate devolve. Toda vitória paga 5% de "taxa de conveniência" sobre o LUCRO.
## Correções da versão antiga: Blackjack do dealer agora empata com o seu
## (antes você recebia 2.5x mesmo com o dealer tendo 21), e o dealer compra
## com suspense em vez de instantaneamente.

const SUITS: Array[String] = ["♠", "♥", "♦", "♣"]
const COMMISSION: float = 0.05

var _dealer_box: HBoxContainer
var _player_box: HBoxContainer
var _dealer_score: Label
var _player_score: Label
var _result: Label
var _deal_btn: Button
var _hit_btn: Button
var _stand_btn: Button
var _double_btn: Button
var _player: Array[Dictionary] = []
var _dealer: Array[Dictionary] = []
var _bet: float = 0.0
var _in_round: bool = false


func game_id() -> String:
	return "blackjack"


func tab_title() -> String:
	return "21 Felino"


func intro_key() -> String:
	return "tab_blackjack"


func rules_text() -> String:
	return "Dealer para no 17  •  Blackjack 3:2  •  Taxa de 5% no lucro"


func build() -> void:
	add_theme_constant_override("separation", 8)
	add_child(header("21 FELINO"))

	var d_row := UIKit.hbox(10)
	add_child(d_row)
	var dl := UIKit.label("DEALER", 12, UIKit.MUTED)
	dl.custom_minimum_size = Vector2(70, 0)
	d_row.add_child(dl)
	_dealer_box = UIKit.hbox(6)
	_dealer_box.custom_minimum_size = Vector2(0, 96)
	_dealer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_row.add_child(_dealer_box)
	_dealer_score = UIKit.title("", 22, UIKit.INK)
	d_row.add_child(_dealer_score)

	var mid := UIKit.label("— Jeff Meowzos embaralha com as patas. Ninguém confere. —", 11, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(mid)

	var p_row := UIKit.hbox(10)
	add_child(p_row)
	var pl := UIKit.label("VOCÊ", 12, UIKit.MUTED)
	pl.custom_minimum_size = Vector2(70, 0)
	p_row.add_child(pl)
	_player_box = UIKit.hbox(6)
	_player_box.custom_minimum_size = Vector2(0, 96)
	_player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_row.add_child(_player_box)
	_player_score = UIKit.title("", 22, UIKit.INK)
	p_row.add_child(_player_score)

	add_child(UIKit.spacer(false))
	_result = result_label()
	add_child(_result)

	var btns := UIKit.hbox(8)
	add_child(btns)
	_deal_btn = big_button("DISTRIBUIR")
	_deal_btn.pressed.connect(_on_deal)
	btns.add_child(_deal_btn)
	_hit_btn = big_button("PEDIR", "success")
	_hit_btn.pressed.connect(_on_hit)
	btns.add_child(_hit_btn)
	_stand_btn = big_button("PARAR", "default")
	_stand_btn.pressed.connect(_on_stand)
	btns.add_child(_stand_btn)
	_double_btn = big_button("DOBRAR", "purple")
	_double_btn.tooltip_text = "Dobra a aposta, recebe exatamente mais uma carta e para."
	_double_btn.pressed.connect(_on_double)
	btns.add_child(_double_btn)
	_set_round_buttons(false)


func _draw_card() -> Dictionary:
	return {"rank": randi_range(1, 13), "suit": SUITS[randi() % 4]}


func _hand_value(hand: Array[Dictionary]) -> int:
	var total := 0
	var aces := 0
	for c in hand:
		var r: int = c["rank"]
		if r == 1:
			aces += 1
			total += 11
		else:
			total += mini(r, 10)
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


func _card_widget(card: Dictionary, hidden: bool) -> PanelContainer:
	var p: PanelContainer
	if hidden:
		p = UIKit.panel(UIKit.box(Color("#5B1F7A"), UIKit.GOLD, 8, 2, 6))
	else:
		p = UIKit.panel(UIKit.shadowed(UIKit.box(Color("#FBF7EC"), Color("#3B2A12"), 8, 1, 6), 4, 0.4))
	p.custom_minimum_size = Vector2(62, 90)
	var v := UIKit.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	if hidden:
		v.add_child(UIKit.title("?", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var red: bool = card["suit"] == "♥" or card["suit"] == "♦"
		var col := Color("#C0392B") if red else Color("#1B1B24")
		v.add_child(UIKit.title(_rank_text(card["rank"]), 26, col, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label(card["suit"], 22, col, HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _rank_text(r: int) -> String:
	match r:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
	return str(r)


func _render(reveal: bool) -> void:
	for c in _dealer_box.get_children():
		c.queue_free()
	for c in _player_box.get_children():
		c.queue_free()
	for i in range(_dealer.size()):
		_dealer_box.add_child(_card_widget(_dealer[i], i == 1 and not reveal))
	for c in _player:
		_player_box.add_child(_card_widget(c, false))
	_player_score.text = str(_hand_value(_player)) if not _player.is_empty() else ""
	if reveal:
		_dealer_score.text = str(_hand_value(_dealer))
	elif _dealer.size() > 0:
		var first: Array[Dictionary] = [_dealer[0]]
		_dealer_score.text = "%d + ?" % _hand_value(first)
	else:
		_dealer_score.text = ""


func _pop_last(box: HBoxContainer) -> void:
	await get_tree().process_frame
	if box.get_child_count() > 0:
		UIKit.pop(box.get_child(box.get_child_count() - 1), 1.15, 0.2)


func _set_round_buttons(active: bool) -> void:
	_deal_btn.disabled = active
	_hit_btn.disabled = not active
	_stand_btn.disabled = not active
	_double_btn.disabled = not active or _player.size() != 2 or not GameManager.can_afford(_bet)


func _on_deal() -> void:
	if _in_round:
		return
	_bet = take_bet()
	if _bet <= 0.0:
		return
	set_busy(true)
	_in_round = true
	_result.text = ""
	_player = [_draw_card(), _draw_card()]
	_dealer = [_draw_card(), _draw_card()]
	_render(false)
	menu.emit_sfx("click")
	var p := _hand_value(_player)
	var d := _hand_value(_dealer)
	if p == 21 or d == 21:
		_set_round_buttons(false)
		_deal_btn.disabled = true
		await wait(0.6)
		_render(true)
		if p == 21 and d == 21:
			_finish("push", "Dois Blackjacks. Empate. O Jeff Meowzos chama isso de 'sinergia'.")
		elif p == 21:
			GameManager.unlock_achievement("bet_twenty_one")
			_finish("blackjack", "BLACKJACK NATURAL!")
		else:
			_finish("lose", "Blackjack do dealer. Ele jura que não marcou as cartas.")
		return
	_set_round_buttons(true)


func _on_hit() -> void:
	if not _in_round:
		return
	_player.append(_draw_card())
	_render(false)
	_pop_last(_player_box)
	menu.emit_sfx("click")
	_set_round_buttons(true)
	var p := _hand_value(_player)
	if p > 21:
		_set_round_buttons(false)
		_deal_btn.disabled = true
		await wait(0.4)
		_render(true)
		_finish("lose", "ESTOUROU com %d. Ganância é virtude só para CEOs." % p)
	elif p == 21:
		_on_stand()


func _on_double() -> void:
	if not _in_round or _player.size() != 2:
		return
	var extra := take_bet(_bet)
	if extra <= 0.0:
		return
	_bet += extra
	_player.append(_draw_card())
	_render(false)
	_pop_last(_player_box)
	if _hand_value(_player) > 21:
		_set_round_buttons(false)
		_deal_btn.disabled = true
		await wait(0.4)
		_render(true)
		_finish("lose", "Dobrou e estourou. Coragem não é estratégia.")
	else:
		_on_stand()


func _on_stand() -> void:
	if not _in_round:
		return
	_set_round_buttons(false)
	_deal_btn.disabled = true
	_render(true)
	await wait(0.5)
	while _hand_value(_dealer) < 17:
		_dealer.append(_draw_card())
		_render(true)
		_pop_last(_dealer_box)
		menu.emit_sfx("click")
		await wait(0.55)
	var p := _hand_value(_player)
	var d := _hand_value(_dealer)
	if d > 21:
		_finish("win", "Dealer estourou com %d!" % d)
	elif p > d:
		_finish("win", "Você venceu: %d contra %d." % [p, d])
	elif p == d:
		_finish("push", "Empate em %d. Ninguém feliz." % p)
	else:
		_finish("lose", "Dealer venceu: %d contra %d." % [d, p])


func _finish(outcome: String, text: String) -> void:
	var payout := 0.0
	match outcome:
		"blackjack":
			payout = _bet + _bet * 1.5 * (1.0 - COMMISSION)
		"win":
			payout = _bet + _bet * (1.0 - COMMISSION)
		"push":
			payout = _bet
	var paid := settle(_bet, payout)
	var net := paid - _bet
	if net > 0.0:
		var fee := (paid - _bet) / (1.0 - COMMISSION) * COMMISSION
		show_result(_result, "%s  +%s  (taxa de conveniência: -%s)" % [text, NumberFormatter.format_number(net), NumberFormatter.format_number(fee)], UIKit.PROFIT)
	elif net == 0.0:
		show_result(_result, text, UIKit.MUTED)
	else:
		show_result(_result, "%s  -%s" % [text, NumberFormatter.format_number(_bet)], UIKit.RISK)
	_in_round = false
	await wait(0.8)
	_set_round_buttons(false)
	set_busy(false)
