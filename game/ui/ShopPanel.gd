class_name ShopPanel
extends PanelContainer
## "MERCADO DE ATIVOS" — loja lateral.
## Melhorias aparecem como grade de ícones (estilo vitrine) e estruturas como cards
## com barra de progresso até o preço — o jogador SEMPRE vê quanto falta,
## o que é a alavanca de "só mais um pouquinho" de todo idle game.
## Modo de compra x1 / x10 / x100 / MAX.

signal building_bought(index: int, amount: int)
signal upgrade_bought(index: int)
signal casino_pressed

const BUY_MODES: Array[int] = [1, 10, 100, 0]   # 0 = MAX

var buy_mode: int = 1
var _building_cards: Array[Dictionary] = []
var _upgrade_buttons: Array[Button] = []
var _upgrade_grid: GridContainer
var _upgrade_header: Label
var _mode_buttons: Array[Button] = []
var _casino_btn: Button
var _texture_cache: Dictionary = {}
var _refresh_accum: float = 0.0


func _ready() -> void:
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.06, 0.05, 0.09, 0.97)
	border.border_color = UIKit.GOLD_DARK
	border.border_width_left = 2
	border.shadow_size = 16
	border.shadow_color = Color(0, 0, 0, 0.6)
	add_theme_stylebox_override("panel", border)

	var m := UIKit.margin(10)
	add_child(m)
	var root := UIKit.vbox(8)
	m.add_child(root)

	root.add_child(UIKit.title("MERCADO DE ATIVOS", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := UIKit.caption("Pregão felino · Compre barato, explore caro", UIKit.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	_casino_btn = UIKit.button("", "gold", 14, Vector2(0, 42))
	_casino_btn.pressed.connect(func(): casino_pressed.emit())
	root.add_child(_casino_btn)

	# Melhorias (grade de ícones)
	_upgrade_header = UIKit.caption("Melhorias", UIKit.CYAN)
	root.add_child(_upgrade_header)
	_upgrade_grid = GridContainer.new()
	_upgrade_grid.columns = 7
	_upgrade_grid.add_theme_constant_override("h_separation", 5)
	_upgrade_grid.add_theme_constant_override("v_separation", 5)
	root.add_child(_upgrade_grid)

	# Cabeçalho das estruturas + seletor de quantidade
	var head := UIKit.hbox(4)
	root.add_child(head)
	var lbl := UIKit.caption("Estruturas · lote", UIKit.GOLD_LIGHT)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(lbl)
	head.add_child(UIKit.spacer())
	for mode in BUY_MODES:
		var b := UIKit.button("MAX" if mode == 0 else "x%d" % mode, "ghost", 11, Vector2(42, 24))
		b.toggle_mode = true
		b.pressed.connect(_set_buy_mode.bind(mode))
		head.add_child(b)
		_mode_buttons.append(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for i in range(GameManager.buildings.size()):
		var card := _create_building_card(i)
		list.add_child(card["btn"])
		_building_cards.append(card)

	_rebuild_upgrades()
	_set_buy_mode(1)

	GameManager.upgrade_changed.connect(func(_i: int): _rebuild_upgrades())
	# Bug corrigido: comprar estrutura não revelava melhorias na 1ª carreira
	GameManager.building_changed.connect(func(_i: int): _rebuild_upgrades(); refresh(true))
	GameManager.buildings_reset.connect(func(): _rebuild_upgrades(); refresh(true))
	GameManager.prestige_changed.connect(func(): _rebuild_upgrades(); refresh(true))
	GameManager.perks_changed.connect(func(): refresh(true))
	GameManager.bets_unlocked_changed.connect(func(_u: bool): refresh(true))


func _process(delta: float) -> void:
	# Atualização a 8 Hz: barato e suficiente para barras de progresso fluidas
	_refresh_accum += delta
	if _refresh_accum >= 0.125:
		_refresh_accum = 0.0
		refresh(false)


func _tex(path: String) -> Texture2D:
	if not _texture_cache.has(path):
		_texture_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _texture_cache[path]


func _set_buy_mode(mode: int) -> void:
	buy_mode = mode
	for i in range(_mode_buttons.size()):
		_mode_buttons[i].set_pressed_no_signal(BUY_MODES[i] == mode)
	refresh(true)


# ══════════════════════════════════════
# CARDS DE ESTRUTURA
# ══════════════════════════════════════

func _create_building_card(index: int) -> Dictionary:
	var b: Dictionary = GameManager.buildings[index]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 72)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Card de ativo: tarja lateral grossa, sombra dura, afunda ao clicar
	btn.add_theme_stylebox_override("normal", _card_style(Color("#15121F"), UIKit.GOLD_DARK))
	btn.add_theme_stylebox_override("hover", _card_style(Color("#1E1A2C"), UIKit.GOLD))
	var pressed := _card_style(Color("#0E0C15"), UIKit.GOLD_LIGHT)
	pressed.shadow_size = 0
	pressed.expand_margin_top = -2
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("hover_pressed", pressed)
	btn.add_theme_stylebox_override("disabled", _card_style(Color(0.055, 0.047, 0.08, 0.92), Color("#2E2840")))
	btn.pressed.connect(_on_building_pressed.bind(index))

	var m := UIKit.margin(8)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(m)
	var h := UIKit.hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)

	var icon_panel := UIKit.panel(UIKit.box(Color(0.04, 0.035, 0.07), Color(0.28, 0.23, 0.38, 0.7), 8, 1, 3))
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.custom_minimum_size = Vector2(54, 54)
	h.add_child(icon_panel)
	var icon := UIKit.texture_rect(_tex(b["icon"]), Vector2(48, 48))
	icon_panel.add_child(icon)

	var v := UIKit.vbox(1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_l := UIKit.label(b["name"], 14, UIKit.INK)
	name_l.clip_text = true
	v.add_child(name_l)
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var price_l := UIKit.ticker("", 13, UIKit.AMBER)
	row.add_child(price_l)
	var prod_l := UIKit.ticker("", 11, UIKit.PROFIT)
	prod_l.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(prod_l)
	var bar := UIKit.progress(4)
	bar.size_flags_vertical = Control.SIZE_SHRINK_END
	v.add_child(UIKit.spacer(false))
	v.add_child(bar)

	var count_l := UIKit.ticker("0", 22, UIKit.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	count_l.custom_minimum_size = Vector2(44, 0)
	count_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(count_l)

	return {"btn": btn, "icon": icon, "name": name_l, "price": price_l, "prod": prod_l, "bar": bar, "count": count_l}


func _amount_for(index: int) -> int:
	if buy_mode == 0:
		return maxi(1, GameManager.get_max_affordable(index))
	return buy_mode


func _on_building_pressed(index: int) -> void:
	var amount := buy_mode if buy_mode > 0 else 0
	var bought := GameManager.buy_building(index, amount)
	if bought > 0:
		UIKit.pop(_building_cards[index]["btn"], 1.04)
		building_bought.emit(index, bought)


## Estruturas ainda não alcançadas aparecem como "???" (só a próxima é revelada).
func _is_revealed(index: int) -> bool:
	if index == 0 or int(GameManager.buildings[index]["count"]) > 0:
		return true
	return int(GameManager.buildings[index - 1]["count"]) > 0 or GameManager.lifetime_earned >= float(GameManager.buildings[index]["base_price"]) * 0.5


func refresh(full: bool) -> void:
	var gm := GameManager
	var coins := gm.coins
	var shown_locked := false
	var needs_full := false
	_update_casino_button()   # Bug corrigido: antes só atualizava ao comprar algo
	for i in range(_building_cards.size()):
		var c: Dictionary = _building_cards[i]
		var b: Dictionary = gm.buildings[i]
		var revealed := _is_revealed(i)
		# Revelou entre duas atualizações completas: força nome/ícone/tooltip novos
		if c.get("revealed", revealed) != revealed and not full:
			needs_full = true
		c["revealed"] = revealed
		var btn: Button = c["btn"]
		# Mostra todas as reveladas + uma única silhueta misteriosa
		btn.visible = revealed or not shown_locked
		if not revealed:
			shown_locked = true
		var amount := _amount_for(i)
		var price := gm.get_bulk_price(i, amount)
		var affordable := gm.can_afford(price)
		btn.disabled = not affordable
		(c["bar"] as ProgressBar).value = clampf(coins / maxf(price, 1.0), 0.0, 1.0)
		(c["price"] as Label).text = "BNC " + NumberFormatter.format_number(price)
		(c["price"] as Label).add_theme_color_override("font_color", UIKit.AMBER if affordable else Color(0.85, 0.42, 0.38))

		if not full:
			continue
		var count: int = int(b["count"])
		(c["count"] as Label).text = str(count)
		(c["count"] as Label).add_theme_color_override("font_color", UIKit.PROFIT if count > 0 else UIKit.DIM)
		(c["icon"] as TextureRect).modulate = Color.WHITE if revealed else Color(0, 0, 0, 0.85)
		var per := gm.get_building_cps_per_unit(i)
		if revealed:
			(c["name"] as Label).text = ("%s  x%d" % [b["name"], amount]) if amount > 1 else str(b["name"])
			(c["prod"] as Label).text = "DIV +%s/s" % NumberFormatter.format_cps(per)
			var share := gm.get_building_cps_final(i) / maxf(gm.cps, 0.0001)
			btn.tooltip_text = "%s — %s\n\n\"%s\"\n\n• Cada unidade: +%s/s\n• Total (%d): +%s/s (%s da produção)\n• Preço (x%d): %s" % [
				b["name"], b["subtitle"], b["desc"], NumberFormatter.format_cps(per), count,
				NumberFormatter.format_cps(gm.get_building_cps_final(i)), NumberFormatter.format_percent(share),
				amount, NumberFormatter.format_number(price)]
		else:
			(c["name"] as Label).text = "???"
			(c["prod"] as Label).text = "Ativo confidencial"
			btn.tooltip_text = "Continue explorando para descobrir este ativo."

	_refresh_upgrade_affordability()
	if needs_full:
		refresh(true)


func _update_casino_button() -> void:
	if GameManager.bets_unlocked:
		_casino_btn.text = "♠  ENTRAR NO CASSINO DO JEFF MEOWZOS  ♠"
		_casino_btn.disabled = false
		_casino_btn.tooltip_text = "Sete jogos de azar e um escritório de crédito. O que pode dar errado?"
	else:
		_casino_btn.text = "♠  Abrir Cassino Clandestino (%s)" % NumberFormatter.format_number(GameManager.BETS_UPGRADE_COST)
		_casino_btn.disabled = not GameManager.can_afford(GameManager.BETS_UPGRADE_COST)
		_casino_btn.tooltip_text = "Um gato sphynx de terno oferece 'oportunidades de investimento'."


# ══════════════════════════════════════
# MELHORIAS
# ══════════════════════════════════════

func _rebuild_upgrades() -> void:
	for c in _upgrade_grid.get_children():
		c.queue_free()
	_upgrade_buttons.clear()
	var any := false
	for i in range(GameManager.upgrades.size()):
		if not GameManager.is_upgrade_visible(i):
			continue
		any = true
		var u: Dictionary = GameManager.upgrades[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(44, 44)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var border := UIKit.PURPLE if str(u["type"]) != "building_mult" else UIKit.CYAN
		UIKit.apply_key(btn, Color("#1B1628"), border.darkened(0.2), UIKit.GOLD)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb: StyleBoxFlat = btn.get_theme_stylebox(st)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
		btn.icon = _tex(u["icon"])
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.set_meta("upgrade_index", i)
		btn.tooltip_text = "%s\n%s\n\n\"%s\"\n\nPreço: %s" % [
			u["name"], u["short_effect"], u["desc"], NumberFormatter.format_number(GameManager.get_upgrade_price(i))]
		btn.pressed.connect(_on_upgrade_pressed.bind(i))
		_upgrade_grid.add_child(btn)
		_upgrade_buttons.append(btn)
	_upgrade_header.text = ("MELHORIAS · %d DISPONÍVEIS" % _upgrade_buttons.size()) if any else "MELHORIAS · COMPRE ESTRUTURAS PARA LIBERAR"
	_refresh_upgrade_affordability()


func _refresh_upgrade_affordability() -> void:
	for btn in _upgrade_buttons:
		var idx: int = btn.get_meta("upgrade_index")
		var ok := GameManager.can_afford(GameManager.get_upgrade_price(idx))
		btn.disabled = not ok
		btn.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)


func _on_upgrade_pressed(index: int) -> void:
	if GameManager.buy_upgrade(index):
		upgrade_bought.emit(index)


## Estilo do card de ativo: tarja esquerda grossa na cor de destaque.
func _card_style(bg: Color, accent: Color) -> StyleBoxFlat:
	var st := UIKit.box(bg, accent, 3, 1)
	st.border_width_left = 5
	st.border_width_top = 0
	st.border_width_right = 0
	st.border_width_bottom = 1
	st.shadow_size = 1
	st.shadow_offset = Vector2(0, 3)
	st.shadow_color = UIKit.HARD_SHADOW
	return st
