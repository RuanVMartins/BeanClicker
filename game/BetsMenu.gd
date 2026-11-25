extends Control
class_name BetsMenu
## CASSINO DO JEFF MEOWZOS — moldura do cassino.
## Cuida de: abrir/fechar, seletor de aposta, abas, estatísticas da sessão,
## partículas e o balão do Meowzos. Os jogos são módulos (casino/*.gd) que
## herdam CasinoGame e conversam com este menu por request_bet()/settle().
##
## Tabela de RTP (retorno ao jogador) — a casa sempre ganha, mas com estilos
## diferentes de volatilidade para cada perfil de apostador:
##   Caça-Níquel  ~93,6%  (alta volatilidade, jackpot 250x)
##   Foguetinho    96,0%  (escolha o próprio risco)
##   21 Felino    ~97%    (habilidade importa; 5% de taxa nas vitórias)
##   Roleta        92,3%  (o zero é da casa)
##   Raspadinha    91,0%  (o "imposto do otimismo")
##   Ratos         94,0%  (odds fixas, favorito com vantagem visual)
##   Pirâmide      96,0%  (cada nível: 72% de chance; saque quando quiser)
##  +3% em prêmios com o Benefício "Crupiê Subornado".

signal sfx_triggered(sfx_name: String)
signal loan_office_requested
signal menu_closed

const GAME_SCRIPTS: Array = [
	preload("res://casino/SlotGame.gd"),
	preload("res://casino/CrashGame.gd"),
	preload("res://casino/BlackjackGame.gd"),
	preload("res://casino/RouletteGame.gd"),
	preload("res://casino/ScratchGame.gd"),
	preload("res://casino/RatRaceGame.gd"),
	preload("res://casino/PyramidGame.gd"),
]
const TEX_COIN: Texture2D = preload("res://images/BeansCoins.png")

var current_bet: float = 10.0
var active_tab: int = 0

var _overlay: ColorRect
var _panel: PanelContainer
var _bubble: MeowzosBubble
var _coins_label: Label
var _debt_label: Label
var _close_btn: Button
var _bet_label: Label
var _bet_hint: Label
var _slider: HSlider
var _chip_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _games: Array[CasinoGame] = []
var _game_holder: PanelContainer
var _credit_btn: Button
var _stats_label: Label
var _particles: CPUParticles2D
var _marquee: Marquee
var _slider_lock: bool = false

# Sessão
var session_net: float = 0.0
var session_bets: int = 0
var session_best: float = 0.0
var _last_bet_was_all_in: bool = false


func _process(_delta: float) -> void:
	if visible and _marquee:
		_marquee.position = _panel.position - Vector2(11, 11)
		_marquee.size = _panel.size + Vector2(22, 22)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.01, 0.04, 0.8)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = UIKit.panel(UIKit.deco(UIKit.NIGHT, UIKit.GOLD, 14))
	add_child(_panel)
	# Letreiro de lâmpadas em volta da moldura (por fora, para não roubar espaço)
	_marquee = Marquee.new()
	_marquee.inset = 4.0
	_marquee.spacing = 20.0
	add_child(_marquee)

	var root := UIKit.vbox(8)
	_panel.add_child(root)
	_build_header(root)

	_bubble = MeowzosBubble.new(Vector2(70, 88), 14, true)
	root.add_child(_bubble)

	var body := UIKit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_build_sidebar(body)
	_build_games_area(body)

	_particles = _make_particles()
	add_child(_particles)

	GameManager.coins_changed.connect(_on_coins_changed)
	Meowzos.loan_changed.connect(_update_header)


# ══════════════════════════════════════
# CONSTRUÇÃO
# ══════════════════════════════════════

func _build_header(root: VBoxContainer) -> void:
	var h := UIKit.hbox(10)
	root.add_child(h)
	var tv := UIKit.vbox(0)
	h.add_child(tv)
	tv.add_child(UIKit.title("CASSINO DO JEFF MEOWZOS", 24, UIKit.GOLD))
	tv.add_child(UIKit.label("Crédito fácil, consciência difícil. Proibido para menores de 18 moedas.", 11, UIKit.MUTED))
	h.add_child(UIKit.spacer())
	var cv := UIKit.vbox(0)
	h.add_child(cv)
	_coins_label = UIKit.title("", 20, UIKit.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	cv.add_child(_coins_label)
	_debt_label = UIKit.label("", 12, UIKit.RISK, HORIZONTAL_ALIGNMENT_RIGHT)
	cv.add_child(_debt_label)
	_close_btn = UIKit.button("✕", "ghost", 18, Vector2(40, 36))
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_close_btn.tooltip_text = "Sair (a porta é aquela que não tem placa)"
	_close_btn.pressed.connect(close)
	h.add_child(_close_btn)


func _build_sidebar(body: HBoxContainer) -> void:
	var side := UIKit.vbox(8)
	side.custom_minimum_size = Vector2(232, 0)
	body.add_child(side)

	var bet_panel := UIKit.panel(UIKit.box(UIKit.FELT, Color(0.4, 0.33, 0.55, 0.6), 10, 1, 10))
	side.add_child(bet_panel)
	var bv := UIKit.vbox(6)
	bet_panel.add_child(bv)
	bv.add_child(UIKit.label("SUA APOSTA", 11, UIKit.MUTED))
	_bet_label = UIKit.title("10", 26, UIKit.GOLD_LIGHT)
	bv.add_child(_bet_label)
	_bet_hint = UIKit.label("", 11, UIKit.DIM)
	bv.add_child(_bet_hint)

	_slider = HSlider.new()
	_slider.min_value = 1.0
	_slider.max_value = 100.0
	_slider.step = 1.0
	_slider.exp_edit = true   # escala logarítmica: precisão em apostas pequenas E grandes
	_slider.custom_minimum_size = Vector2(0, 22)
	_slider.value_changed.connect(_on_slider_changed)
	bv.add_child(_slider)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	bv.add_child(grid)
	var chips := [["1/2", "half"], ["2x", "double"], ["1%", 0.01], ["10%", 0.1], ["25%", 0.25], ["50%", 0.5], ["MIN", "min"], ["ALL-IN", 1.0]]
	for c in chips:
		var b := UIKit.button(c[0], "danger" if str(c[0]) == "ALL-IN" else "ghost", 11, Vector2(0, 30))
		b.add_theme_font_override("font", UIKit.mono_font())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_chip.bind(c[1]))
		grid.add_child(b)
		_chip_buttons.append(b)

	_credit_btn = UIKit.button("$ ESCRITÓRIO DE CRÉDITO", "default", 13, Vector2(0, 40))
	_credit_btn.add_theme_color_override("font_color", UIKit.ORANGE)
	_credit_btn.add_theme_font_override("font", UIKit.display_font())
	_credit_btn.pressed.connect(func(): loan_office_requested.emit())
	side.add_child(_credit_btn)

	var stats_panel := UIKit.panel(UIKit.box(Color(0.06, 0.05, 0.09), Color(0.3, 0.25, 0.42, 0.5), 10, 1, 10))
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(stats_panel)
	_stats_label = UIKit.wrap_label("", 12, UIKit.MUTED)
	stats_panel.add_child(_stats_label)


func _build_games_area(body: HBoxContainer) -> void:
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

	var tabs := UIKit.hbox(4)
	right.add_child(tabs)

	_game_holder = UIKit.panel(UIKit.box(UIKit.FELT_GREEN, UIKit.GOLD_DARK, 12, 2, 12))
	_game_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_game_holder)

	for i in range(GAME_SCRIPTS.size()):
		var game: CasinoGame = GAME_SCRIPTS[i].new()
		game.menu = self
		game.visible = false
		game.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_game_holder.add_child(game)
		game.build()
		_games.append(game)

		var tb := UIKit.button(game.tab_title(), "ghost", 12, Vector2(0, 32))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		UIKit.skew_button(tb, 0.14)
		tb.pressed.connect(_switch_tab.bind(i))
		tabs.add_child(tb)
		_tab_buttons.append(tb)


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 48
	p.lifetime = 1.6
	p.explosiveness = 0.85
	p.texture = TEX_COIN
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.14
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 700)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.z_index = 50
	return p


# ══════════════════════════════════════
# ABRIR / FECHAR
# ══════════════════════════════════════

func open() -> void:
	visible = true
	var vp := get_viewport_rect().size
	var size_target := Vector2(minf(1060.0, vp.x - 24.0), minf(620.0, vp.y - 16.0))
	_panel.custom_minimum_size = size_target
	_panel.size = size_target
	var target := Vector2((vp.x - size_target.x) * 0.5, (vp.y - size_target.y) * 0.5)
	_panel.position = Vector2(target.x, -size_target.y - 40.0)
	_overlay.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.25)
	tw.tween_property(_panel, "position:y", target.y, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	_particles.position = Vector2(vp.x * 0.5, target.y - 10.0)
	_particles.emission_rect_extents = Vector2(size_target.x * 0.45, 4)

	current_bet = clampf(current_bet, 1.0, maxf(1.0, GameManager.coins))
	_update_bet_ui()
	_update_header()
	_update_stats()
	_switch_tab(active_tab, true)
	Meowzos.say_key("casino_open", {}, "smug")


func close() -> void:
	if is_locked():
		Meowzos.say("Calma! Ninguém sai no meio da rodada. Regra da casa. Eu que inventei.", "angry")
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_panel, "position:y", -_panel.size.y - 60.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		visible = false
		menu_closed.emit())


# ══════════════════════════════════════
# ABAS & TRAVAS
# ══════════════════════════════════════

func is_locked() -> bool:
	for g in _games:
		if g.is_busy():
			return true
	return false


func refresh_lock() -> void:
	var locked := is_locked()
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].disabled = locked and i != active_tab
	for b in _chip_buttons:
		b.disabled = locked
	_slider.editable = not locked
	_close_btn.disabled = locked
	_credit_btn.disabled = locked


func _switch_tab(index: int, silent: bool = false) -> void:
	if is_locked() and index != active_tab:
		return
	active_tab = index
	for i in range(_games.size()):
		_games[i].visible = (i == index)
		_tab_buttons[i].set_pressed_no_signal(i == index)
		_tab_buttons[i].add_theme_color_override("font_color", UIKit.GOLD_LIGHT if i == index else UIKit.MUTED)
	_games[index].on_shown()
	if not silent:
		Meowzos.say_key(_games[index].intro_key(), {}, "smug")


# ══════════════════════════════════════
# APOSTA
# ══════════════════════════════════════

func _on_coins_changed(_c: float) -> void:
	if not visible:
		return
	_update_header()
	if not is_locked():
		_update_bet_ui()


func _update_header() -> void:
	_coins_label.text = "%s moedas" % NumberFormatter.format_number(GameManager.coins)
	if Meowzos.loan_active:
		_debt_label.text = "Dívida: %s  •  %s" % [NumberFormatter.format_number(Meowzos.loan_debt), NumberFormatter.format_time(Meowzos.loan_time_left)]
	else:
		_debt_label.text = ""


func _update_bet_ui() -> void:
	var coins := GameManager.coins
	_slider_lock = true
	_slider.max_value = maxf(2.0, floor(coins))
	_slider.value = clampf(current_bet, 1.0, _slider.max_value)
	_slider_lock = false
	_bet_label.text = NumberFormatter.format_number(current_bet)
	var affordable := GameManager.can_afford(current_bet)
	_bet_label.add_theme_color_override("font_color", UIKit.GOLD_LIGHT if affordable else UIKit.RISK)
	var pct := current_bet / maxf(coins, 1.0)
	if not affordable:
		_bet_hint.text = "Saldo insuficiente. O Jeff Meowzos tem uma solução."
	elif GameManager.cps > 0.0:
		_bet_hint.text = "%s do saldo  •  %s de renda" % [NumberFormatter.format_percent(minf(pct, 1.0)), NumberFormatter.format_time(current_bet / GameManager.cps)]
	else:
		_bet_hint.text = "%s do saldo" % NumberFormatter.format_percent(minf(pct, 1.0))


func _on_slider_changed(v: float) -> void:
	if _slider_lock:
		return
	current_bet = maxf(1.0, floor(v))
	_update_bet_ui()


func _on_chip(kind) -> void:
	var coins := maxf(1.0, floor(GameManager.coins))
	match kind:
		"half":
			current_bet = floor(current_bet * 0.5)
		"double":
			current_bet = current_bet * 2.0
		"min":
			current_bet = 1.0
		_:
			current_bet = floor(coins * float(kind))
	current_bet = clampf(current_bet, 1.0, coins)
	_update_bet_ui()
	UIKit.pop(_bet_label, 1.12)
	if typeof(kind) == TYPE_FLOAT and float(kind) >= 1.0:
		Meowzos.say_key("all_in", {}, "shock")


## Chamado pelos jogos. Debita e retorna o valor (0 se falhar).
func request_bet(game: CasinoGame, amount: float = -1.0) -> float:
	var bet: float = floorf(current_bet if amount < 0.0 else amount)
	if bet < 1.0 or not GameManager.can_afford(bet):
		Meowzos.say("Saldo insuficiente! Mas olha que coincidência: meu escritório de crédito está bem ali.", "smug")
		UIKit.shake(_bet_label, 6.0)
		UIKit.flash(_credit_btn, Color(1.6, 1.2, 0.6), 0.8)
		sfx_triggered.emit("lose")
		return 0.0
	_last_bet_was_all_in = bet >= floor(GameManager.coins) and GameManager.coins >= 100.0
	if not GameManager.place_bet(bet):
		return 0.0
	session_bets += 1
	_update_stats()
	sfx_triggered.emit("click")
	return bet


## Chamado pelos jogos ao fim de cada rodada.
func settle(game: CasinoGame, bet: float, payout: float) -> float:
	var final_payout := GameManager.settle_bet(game.game_id(), bet, payout)
	var net := final_payout - bet
	session_net += net
	session_best = maxf(session_best, final_payout)
	if net > 0.0:
		_particles.amount = clampi(int(16 + 8 * (final_payout / maxf(bet, 1.0))), 16, 96)
		_particles.restart()
		if final_payout >= bet * 5.0:
			_marquee.celebrate(2.0)
		sfx_triggered.emit("big_win" if final_payout >= bet * 5.0 else "win")
		UIKit.flash(_coins_label, Color(0.6, 1.6, 0.8), 0.6)
		if _last_bet_was_all_in:
			GameManager.unlock_achievement("bet_allin_win")
	elif net < 0.0:
		sfx_triggered.emit("lose")
		UIKit.flash(_coins_label, Color(1.6, 0.6, 0.6), 0.6)
		if _last_bet_was_all_in and final_payout <= 0.0:
			GameManager.unlock_achievement("bet_allin_lose")
	_last_bet_was_all_in = false
	_update_stats()
	_update_bet_ui()
	return final_payout


func _update_stats() -> void:
	var gm := GameManager
	var net_color := "+" if session_net >= 0.0 else ""
	_stats_label.text = "SESSÃO\nApostas: %d\nResultado: %s%s\nMaior prêmio: %s\n\nVITALÍCIO\nApostado: %s\nResultado: %s%s\nRTP pessoal: %s" % [
		session_bets, net_color, NumberFormatter.format_number(session_net), NumberFormatter.format_number(session_best),
		NumberFormatter.format_number(gm.bets_total_wagered),
		"+" if gm.bets_net_result >= 0.0 else "", NumberFormatter.format_number(gm.bets_net_result),
		NumberFormatter.format_percent((gm.bets_total_wagered + gm.bets_net_result) / maxf(gm.bets_total_wagered, 1.0)) if gm.bets_total_wagered > 0.0 else "—",
	]


func emit_sfx(sfx: String) -> void:
	sfx_triggered.emit(sfx)
