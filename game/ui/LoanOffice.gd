class_name LoanOffice
extends Control
## ESCRITÓRIO DE CRÉDITO DO JEFF MEOWZOS.
## Mostra as 3 ofertas (sempre recalculadas pelo CPS atual), a dívida ativa com
## contagem regressiva e botões de quitação. Transparência total nos números —
## o humor está em o jogador aceitar mesmo assim.

var _overlay: ColorRect
var _bubble: MeowzosBubble
var _offers_box: VBoxContainer
var _debt_panel: PanelContainer
var _debt_label: Label
var _debt_detail: Label
var _debt_bar: ProgressBar
var _pay_all_btn: Button
var _pay_half_btn: Button
var _offer_widgets: Array[Dictionary] = []
var _status_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := UIKit.modal(self, Vector2(760, 0), UIKit.ORANGE)
	_overlay = parts[0]
	var panel: PanelContainer = parts[1]

	var root := UIKit.vbox(10)
	panel.add_child(root)

	var head := UIKit.hbox(8)
	root.add_child(head)
	head.add_child(UIKit.title("ESCRITÓRIO DE CRÉDITO", 24, UIKit.ORANGE))
	head.add_child(UIKit.spacer())
	var close := UIKit.button("✕", "ghost", 16, Vector2(36, 32))
	close.pressed.connect(close_screen)
	head.add_child(close)

	_bubble = MeowzosBubble.new(Vector2(90, 112), 14, true)
	root.add_child(_bubble)

	# Dívida ativa
	_debt_panel = UIKit.panel(UIKit.box(Color("#2A0E12"), UIKit.RISK, 10, 2, 12))
	root.add_child(_debt_panel)
	var dv := UIKit.vbox(6)
	_debt_panel.add_child(dv)
	_debt_label = UIKit.title("", 22, UIKit.RISK)
	dv.add_child(_debt_label)
	_debt_detail = UIKit.wrap_label("", 12, Color("#FFB3B3"))
	dv.add_child(_debt_detail)
	_debt_bar = UIKit.progress(8, UIKit.RISK)
	dv.add_child(_debt_bar)
	var pay_row := UIKit.hbox(8)
	dv.add_child(pay_row)
	_pay_half_btn = UIKit.button("Pagar 50%", "ghost", 13, Vector2(140, 36))
	_pay_half_btn.pressed.connect(func(): Meowzos.repay(Meowzos.loan_debt * 0.5); _refresh())
	pay_row.add_child(_pay_half_btn)
	_pay_all_btn = UIKit.button("QUITAR TUDO", "success", 13, Vector2(180, 36))
	_pay_all_btn.pressed.connect(func(): Meowzos.repay(Meowzos.loan_debt); _refresh())
	pay_row.add_child(_pay_all_btn)

	_status_label = UIKit.wrap_label("", 12, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_status_label)

	_offers_box = UIKit.vbox(8)
	root.add_child(_offers_box)
	for i in range(Meowzos.LOAN_TIERS.size()):
		_offers_box.add_child(_create_offer_row(i))

	root.add_child(UIKit.wrap_label("Letras miúdas: juros compostos por minuto. Ao vencer o prazo, o Jeff Meowzos leva seu caixa e penhora até 75% de cada estrutura (as mais caras primeiro, avaliadas em 50%). Mini Beans são impenhoráveis: bem de família. Falência perdoa tudo. Isso não é um conselho financeiro. É uma ameaça financeira.", 10, UIKit.DIM))

	Meowzos.loan_changed.connect(_on_loan_changed)


func _on_loan_changed() -> void:
	if _is_open:
		_refresh()


func _create_offer_row(index: int) -> PanelContainer:
	var row := UIKit.panel(UIKit.box(Color(0.12, 0.09, 0.07), Color(UIKit.ORANGE, 0.5), 10, 1, 10))
	var h := UIKit.hbox(12)
	row.add_child(h)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_l := UIKit.label("", 15, UIKit.GOLD_LIGHT)
	v.add_child(name_l)
	var terms := UIKit.label("", 12, UIKit.INK)
	v.add_child(terms)
	var pitch := UIKit.wrap_label("", 11, UIKit.DIM)
	v.add_child(pitch)
	var btn := UIKit.button("", "gold", 14, Vector2(170, 44))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		if Meowzos.take_loan(index):
			UIKit.pop(row, 1.05)
		_refresh())
	h.add_child(btn)
	_offer_widgets.append({"row": row, "name": name_l, "terms": terms, "pitch": pitch, "btn": btn})
	return row


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
	_refresh()
	_is_open = true
	_overlay.visible = true
	if _overlay.modulate.a > 0.99:
		_overlay.modulate.a = 0.0
	_fade_to(1.0, 0.2, false)
	if Meowzos.loan_active:
		_bubble.speak(Meowzos.line("idle_debt", {"debt": NumberFormatter.format_number(Meowzos.loan_debt)}), "neutral")
	elif Meowzos.blacklist_time > 0.0:
		_bubble.speak(Meowzos.line("blacklisted"), "angry")
	else:
		_bubble.speak(Meowzos.line("loan_offer"), "smug")


func close_screen() -> void:
	_is_open = false
	_fade_to(0.0, 0.15, true)


func is_open() -> bool:
	return _is_open


var _accum: float = 0.0
func _process(delta: float) -> void:
	if not _is_open:
		return
	_accum += delta
	if _accum >= 0.25:
		_accum = 0.0
		_refresh()


func _refresh() -> void:
	var active := Meowzos.loan_active
	_debt_panel.visible = active
	if active:
		_debt_label.text = "DÍVIDA: %s" % NumberFormatter.format_number(Meowzos.loan_debt)
		_debt_detail.text = "Emprestado: %s  •  Juros: %s ao minuto  •  Vence em %s" % [
			NumberFormatter.format_number(Meowzos.loan_principal),
			NumberFormatter.format_percent(Meowzos.loan_rate),
			NumberFormatter.format_time(Meowzos.loan_time_left)]
		_debt_bar.value = Meowzos.loan_time_left / maxf(Meowzos.loan_term, 1.0)
		_pay_all_btn.disabled = not GameManager.can_afford(Meowzos.loan_debt)
		_pay_all_btn.text = "QUITAR TUDO (%s)" % NumberFormatter.format_number(Meowzos.loan_debt)
		_pay_half_btn.disabled = GameManager.coins < 1.0

	if Meowzos.blacklist_time > 0.0:
		_status_label.text = "Nome sujo no SPC Felino. Novo crédito em %s." % NumberFormatter.format_time(Meowzos.blacklist_time)
	elif active:
		_status_label.text = "Um empréstimo por vez. Até agiota tem compliance."
	else:
		_status_label.text = "Valores calculados sobre sua renda atual (%s/min). Quanto mais você produz, mais ele te deixa dever." % NumberFormatter.format_number(maxf(GameManager.cps * 60.0, Meowzos.MIN_UNIT))

	for i in range(_offer_widgets.size()):
		var w: Dictionary = _offer_widgets[i]
		var o := Meowzos.get_offer(i)
		(w["name"] as Label).text = str(o["name"])
		(w["terms"] as Label).text = "Recebe %s  •  %s ao minuto  •  Prazo %s  •  Deve %s no fim" % [
			NumberFormatter.format_number(o["amount"]), NumberFormatter.format_percent(o["rate"]),
			NumberFormatter.format_time(o["term"]), NumberFormatter.format_number(o["owed_at_term"])]
		(w["pitch"] as Label).text = "\"%s\"" % o["pitch"]
		var btn: Button = w["btn"]
		btn.text = "PEGAR %s" % NumberFormatter.format_number(o["amount"])
		btn.disabled = not Meowzos.can_borrow()
