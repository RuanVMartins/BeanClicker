class_name TutorialOverlay
extends Control
## PROGRAMA DE INTEGRAÇÃO DE NOVOS COLABORADORES — o tutorial do jogo.
## O Jeff Meowzos guia o jogador por passos que reagem ao que ele faz:
## cada passo destaca um elemento da tela (moldura dourada pulsando + seta) e
## avança sozinho quando a ação é feita. Passos "Entendi" são só explicação.
## Passos com "portão" (cassino, falência) esperam em silêncio até fazer sentido.
## O progresso fica no save; dá para pular e rever pelo Relatório.

signal finished

const CARD_POS := Vector2(14, -250)     # mesmo lugar do Jeff ambulante (canto inferior esquerdo)
const CARD_WIDTH: float = 470.0

var main: Node                           # referência à cena principal (para achar os alvos)
var _steps: Array[Dictionary] = []
var _card: PanelContainer
var _bubble: MeowzosBubble
var _progress_label: Label
var _hint_label: Label
var _ok_btn: Button
var _skip_btn: Button
var _target: Control
var _t: float = 0.0
var _check_accum: float = 0.0
var _shown_step: int = -1
var _click_base: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_steps()
	_build_card()
	visible = not GameManager.tutorial_done
	_card.visible = false
	# Conta só os cliques feitos a partir de agora (save carregado pode já ter cliques)
	_click_base = GameManager.total_clicks


# ══════════════════════════════════════
# PASSOS
# ══════════════════════════════════════

func _build_steps() -> void:
	var gm := GameManager
	_steps = [
		{
			"id": "click", "mood": "smug",
			"text": "Bem-vindo à empresa! Primeira tarefa: clique no Grande Bean 10 vezes. Mais-valia não se extrai sozinha.",
			"target": func(): return main.bean_button,
			"done": func(): return gm.total_clicks - _click_base >= 10,
			"counter": func(): return "%d/10 cliques" % mini(gm.total_clicks - _click_base, 10),
		},
		{
			"id": "buy_mini", "mood": "smug",
			"text": "Agora contrate um Mini Bean na loja. Estagiário clonado: trabalha 24 horas e não pede nada.",
			"target": func(): return main.shop.get_building_button(0),
			"price": func(): return gm.get_building_price(0),
			"done": func(): return int(gm.buildings[0]["count"]) >= 1,
		},
		{
			"id": "upgrade", "mood": "neutral",
			"text": "Melhorias liberadas! Compre uma: elas multiplicam a produção. Ética não multiplica nada, já testei.",
			"gate": func(): return main.shop.has_visible_upgrades(),
			"target": func(): return main.shop.get_upgrade_grid(),
			"price": func(): return _cheapest_upgrade_price(),
			"done": func(): return gm.upgrades.any(func(u): return u["purchased"]),
		},
		{
			"id": "passive", "mood": "smug", "info": true,
			"text": "Esse painel é a sua cotação. A renda passiva (▲/s) cai na conta mesmo quando você não clica. Ninguém trabalha e todo mundo ganha. Digo, você ganha.",
			"target": func(): return main.hud_panel,
		},
		{
			"id": "buy_farmer", "mood": "neutral",
			"text": "Compre um Fazendeiro Felino. Quanto mais caro o ativo, mais ele rende. É a lógica do mercado: quem tem, ganha.",
			"target": func(): return main.shop.get_building_button(1),
			"price": func(): return gm.get_building_price(1),
			"done": func(): return int(gm.buildings[1]["count"]) >= 1,
		},
		{
			"id": "fishing", "mood": "smug",
			"text": "Hora de relaxar no meu lago: aperte ≈ PESCA (ou P) e pesque um peixe. O valor do peixe cresce junto com a sua renda.",
			"target": func(): return main.fishing_action,
			"done": func(): return Fishing.total_caught >= 1,
		},
		{
			"id": "casino", "mood": "shock",
			"text": "Juntou 1.000 moedas? Então abra o meu cassino. Entre, a casa é sua. O dinheiro é meu.",
			"gate": func(): return gm.bets_unlocked or gm.can_afford(gm.BETS_UPGRADE_COST),
			"target": func(): return main.casino_action,
			"done": func(): return main.bets_menu.visible or gm.bets_total_count > 0,
		},
		{
			"id": "credit", "mood": "smug", "info": true,
			"text": "Faltou dinheiro? Meu escritório de crédito empresta na hora, com juros por minuto. Se não pagar no prazo, eu levo suas estruturas. Com carinho.",
			"target": func(): return main.loan_action,
		},
		{
			"id": "prestige", "mood": "shock", "info": true,
			"text": "Sua empresa já vale o suficiente para FALIR. Você perde tudo, mas desvia Fundos Offshore e volta produzindo mais. É assim que os grandes fazem.",
			"gate": func(): return gm.calculate_prestige_gain() > 0 or gm.prestige_count > 0,
			"target": func(): return main.prestige_action,
			"done": func(): return gm.prestige_count > 0,
		},
	]


# ══════════════════════════════════════
# CARTÃO DO JEFF
# ══════════════════════════════════════

func _build_card() -> void:
	_card = UIKit.panel(UIKit.shadowed(UIKit.box(Color(0.07, 0.05, 0.1, 0.97), UIKit.GOLD, 12, 2, 10), 12, 0.6))
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = CARD_POS.x
	_card.offset_right = CARD_POS.x + CARD_WIDTH
	_card.offset_top = CARD_POS.y
	_card.offset_bottom = -108
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)

	var v := UIKit.vbox(6)
	_card.add_child(v)
	var head := UIKit.hbox(6)
	v.add_child(head)
	head.add_child(UIKit.caption("Integração de novos colaboradores", UIKit.GOLD))
	head.add_child(UIKit.spacer())
	_progress_label = UIKit.caption("", UIKit.MUTED)
	head.add_child(_progress_label)

	_bubble = MeowzosBubble.new(Vector2(70, 88), 13, false)
	v.add_child(_bubble)

	# Dica de dinheiro nos passos de compra: sem ela o botão destacado fica
	# desativado e parece que o jogo travou.
	_hint_label = UIKit.wrap_label("", 13, UIKit.AMBER)
	_hint_label.visible = false
	v.add_child(_hint_label)

	var row := UIKit.hbox(8)
	v.add_child(row)
	_skip_btn = UIKit.button("Pular integração", "ghost", 11, Vector2(0, 30))
	_skip_btn.tooltip_text = "Encerra o tutorial. Dá para rever depois no Relatório (R)."
	_skip_btn.pressed.connect(skip)
	row.add_child(_skip_btn)
	row.add_child(UIKit.spacer())
	_ok_btn = UIKit.button("ENTENDI", "gold", 13, Vector2(120, 32))
	_ok_btn.pressed.connect(_on_ok)
	row.add_child(_ok_btn)
	# Em janelas menores o cartão cobre parte do Grande Bean: ele deixa o
	# clique passar e só os próprios botões o capturam.
	_let_clicks_through(_card)


func _let_clicks_through(node: Node) -> void:
	if node is Control and not node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_let_clicks_through(c)


# ══════════════════════════════════════
# CICLO
# ══════════════════════════════════════

func is_showing() -> bool:
	return visible and _card.visible


func current_step() -> Dictionary:
	var i := GameManager.tutorial_step
	return _steps[i] if i >= 0 and i < _steps.size() else {}


func _process(delta: float) -> void:
	if GameManager.tutorial_done or main == null:
		return
	_t += delta
	_check_accum += delta
	if _check_accum >= 0.2:
		_check_accum = 0.0
		_evaluate()
	queue_redraw()


func _evaluate() -> void:
	var step := current_step()
	if step.is_empty():
		_complete_all()
		return
	# Escondido enquanto alguma janela cobre a tela principal
	var blocked: bool = main.bets_menu.visible or main._any_modal_open()
	var gate_ok: bool = not step.has("gate") or bool(step["gate"].call())
	if step.has("done") and bool(step["done"].call()):
		_advance()
		return
	var show := gate_ok and not blocked
	if show and _shown_step != GameManager.tutorial_step:
		_present(step)
	_card.visible = show
	if show and step.has("counter"):
		_progress_label.text = "Passo %d/%d · %s" % [GameManager.tutorial_step + 1, _steps.size(), step["counter"].call()]
	_target = step["target"].call() if show else null
	# Passo de compra sem dinheiro: aponta para o Bean e diz quanto falta
	_hint_label.visible = false
	if show and step.has("price"):
		var price: float = float(step["price"].call())
		if price > 0.0 and not GameManager.can_afford(price):
			_hint_label.text = "Você tem %s de %s moedas. Clique no Grande Bean para juntar o resto." % [
				NumberFormatter.format_number(floorf(GameManager.coins)), NumberFormatter.format_number(price)]
			_target = main.bean_button
		else:
			_hint_label.text = "Já dá! Clique no item destacado na loja."
		_hint_label.visible = true


func _present(step: Dictionary) -> void:
	_shown_step = GameManager.tutorial_step
	_progress_label.text = "Passo %d/%d" % [GameManager.tutorial_step + 1, _steps.size()]
	_ok_btn.visible = step.get("info", false)
	# Compra do tutorial é sempre de 1 unidade (x10/x100 deixaria o preço fora de alcance)
	if step.has("price") and main.shop.buy_mode != 1:
		main.shop._set_buy_mode(1)
	_card.visible = true
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	_bubble.speak(step["text"], step.get("mood", "neutral"))


func _cheapest_upgrade_price() -> float:
	var best: float = -1.0
	for i in range(GameManager.upgrades.size()):
		if GameManager.is_upgrade_visible(i):
			var p: float = GameManager.get_upgrade_price(i)
			if best < 0.0 or p < best:
				best = p
	return best


func _on_ok() -> void:
	_advance()


func _advance() -> void:
	GameManager.tutorial_step += 1
	_shown_step = -1
	_target = null
	_card.visible = false
	if GameManager.tutorial_step >= _steps.size():
		_complete_all()


func _complete_all() -> void:
	if GameManager.tutorial_done:
		return
	GameManager.tutorial_done = true
	GameManager.unlock_achievement("tutorial_done")
	_card.visible = false
	visible = false
	Meowzos.say("Integração concluída! Você agora sabe exatamente como ser explorado. Bem-vindo à família.", "smug")
	finished.emit()


func skip() -> void:
	GameManager.tutorial_done = true
	_card.visible = false
	visible = false
	Meowzos.say("Pulou a integração? Gosto de quem não lê os termos de uso. Volte no Relatório se se perder.", "smug")


## Recomeça do zero (botão "Rever integração" no Relatório).
func restart() -> void:
	GameManager.tutorial_done = false
	GameManager.tutorial_step = 0
	_shown_step = -1
	_click_base = GameManager.total_clicks
	visible = true


# ══════════════════════════════════════
# DESTAQUE
# ══════════════════════════════════════

func _draw() -> void:
	if not is_showing() or _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return
	var r := _target.get_global_rect().grow(6.0)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_rect(r.grow(4.0 + pulse * 3.0), Color(UIKit.GOLD, 0.10 + pulse * 0.10), true)
	draw_rect(r, Color(UIKit.GOLD_LIGHT, 0.65 + pulse * 0.35), false, 3.0)
	# Seta apontando para o alvo (acima dele; abaixo se estiver no topo da tela)
	var above := r.position.y > 60.0
	var bob := absf(sin(_t * 6.0)) * 8.0
	var tip := Vector2(r.get_center().x, (r.position.y - 6.0 - bob) if above else (r.end.y + 6.0 + bob))
	var base_y: float = (tip.y - 26.0) if above else (tip.y + 26.0)
	var arrow := PackedVector2Array([tip, Vector2(tip.x - 14, base_y), Vector2(tip.x + 14, base_y)])
	draw_colored_polygon(arrow, UIKit.GOLD_LIGHT)
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), Color(0, 0, 0, 0.7), 2.0, true)
