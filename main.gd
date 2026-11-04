extends Node2D
## Cena principal do BeanClicker: HUD, Grande Bean, barra de ações, jornal,
## Jeff Meowzos ambulante, loja e telas modais.
## A lógica de economia vive no GameManager; aqui só tem apresentação.

const SHOP_WIDTH: float = 390.0
const MAX_ENTITIES: int = 60
const MAX_ENTITIES_PER_TYPE: int = 12
const MEOWZOS_MIN_INTERVAL: float = 55.0
const MEOWZOS_MAX_INTERVAL: float = 95.0
const MEOWZOS_SHOW_TIME: float = 7.5

@onready var ui: Control = $CanvasLayer/UI
@onready var modal_layer: CanvasLayer = $ModalLayer
@onready var entities_root: Node2D = $MiniBeansContainer
@onready var click_sound: AudioStreamPlayer = $CanvasLayer/ClickSound
@onready var buy_sound: AudioStreamPlayer = $CanvasLayer/BuySound
@onready var prestige_sound: AudioStreamPlayer = $CanvasLayer/PrestigeSound
@onready var bets_menu: BetsMenu = $CasinoLayer/BetsMenu

const TEX_IDLE: Texture2D = preload("res://images/BeansIdle.png")
const TEX_MINING: Texture2D = preload("res://images/BeansMining.png")
const TEX_COIN: Texture2D = preload("res://images/BeansCoins.png")
const SFX_CLICK: AudioStream = preload("res://clique.mp3")
const SFX_BUY: AudioStream = preload("res://comprar.mp3")
const SFX_BGM: AudioStream = preload("res://background.mp3")
const BUILDING_SCENE: PackedScene = preload("res://BuildingEntity.tscn")

# HUD
var play_area: Control
var coins_label: Label
var cps_label: Label
var click_label: Label
var change_label: Label
var sparkline: Sparkline
var title_label: Label
var debt_chip: Button
var bean_button: TextureButton
var _displayed_coins: float = 0.0

# Barra de ações
var casino_action: Button
var loan_action: Button
var prestige_action: Button
var report_action: Button
var _prestige_glow: Tween

# Componentes
var shop: ShopPanel
var ticker: NewsTicker
var meowzos_popup: PanelContainer
var meowzos_bubble: MeowzosBubble
var prestige_screen: PrestigeScreen
var loan_office: LoanOffice
var achievements_panel: AchievementsPanel
var toast_box: VBoxContainer

var _entities: Dictionary = {}   # building_id -> Array[Node]
var _meowzos_timer: float = 20.0
var _meowzos_hide_timer: float = 0.0
var _hud_accum: float = 0.0


# ╔══════════════════════════════════════╗
# ║             _READY                   ║
# ╚══════════════════════════════════════╝
func _ready() -> void:
	# A herança de Theme não atravessa CanvasLayer: cada raiz de UI recebe o tema
	var theme := UIKit.build_theme()
	get_window().theme = theme
	ui.theme = theme
	bets_menu.theme = theme
	GameManager.boot()

	_build_background_vignette()
	_build_play_area()
	_build_shop()
	_build_modals()
	_setup_audio()

	GameManager.cps_changed.connect(func(_c: float): _update_hud_static())
	GameManager.prestige_changed.connect(_on_prestige_changed)
	GameManager.perks_changed.connect(_update_hud_static)
	GameManager.bets_unlocked_changed.connect(func(_u: bool): _update_hud_static())
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)
	GameManager.buildings_reset.connect(_sync_all_entities)
	GameManager.building_changed.connect(_sync_entities_for)
	GameManager.bailout_paid.connect(func(amount: float):
		_toast("SOCORRO ESTATAL", "O governo depositou %s. Lucro privado, prejuízo público." % NumberFormatter.format_number(amount), UIKit.CYAN))
	Meowzos.said.connect(_on_meowzos_said)
	Meowzos.loan_changed.connect(_update_hud_static)
	Meowzos.loan_defaulted.connect(_on_loan_defaulted)
	bets_menu.loan_office_requested.connect(func(): loan_office.open())
	bets_menu.sfx_triggered.connect(_on_casino_sfx)

	_displayed_coins = GameManager.coins
	_sync_all_entities()
	_update_hud_static()

	if not GameManager.pending_offline_report.is_empty():
		_show_offline_report.call_deferred(GameManager.pending_offline_report)
		GameManager.pending_offline_report = {}


func _process(delta: float) -> void:
	# Contador animado: o número "corre" até o valor real (dopamina barata)
	var target := GameManager.coins
	_displayed_coins = lerpf(_displayed_coins, target, clampf(delta * 10.0, 0.0, 1.0))
	if absf(_displayed_coins - target) < 1.0:
		_displayed_coins = target
	coins_label.text = NumberFormatter.format_number(_displayed_coins)

	_hud_accum += delta
	if _hud_accum >= 0.25:
		_hud_accum = 0.0
		_update_hud_dynamic()

	_tick_meowzos(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		for screen in [prestige_screen, loan_office, achievements_panel]:
			if screen.is_open():
				screen.close_screen()
				return
		if bets_menu.visible:
			bets_menu.close()


# ╔══════════════════════════════════════╗
# ║          CONSTRUÇÃO DA UI            ║
# ╚══════════════════════════════════════╝

func _build_background_vignette() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.03, 0.1, 0.0))
	grad.set_color(1, Color(0.05, 0.03, 0.1, 0.72))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.38, 0.45)
	tex.fill_to = Vector2(1.05, 1.05)
	var vignette := TextureRect.new()
	vignette.texture = tex
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$BackgroundLayer.add_child(vignette)


func _build_play_area() -> void:
	play_area = Control.new()
	play_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_area.offset_right = -SHOP_WIDTH
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(play_area)

	# ── HUD: terminal de cotação da Bean Coin (BNC) ──
	var hud_style := UIKit.shadowed(UIKit.lcd(12))
	hud_style.border_color = UIKit.GOLD_DARK
	hud_style.set_border_width_all(2)
	hud_style.border_width_top = 3
	var hud := UIKit.panel(hud_style)
	hud.position = Vector2(14, 12)
	hud.custom_minimum_size = Vector2(300, 0)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.add_child(hud)
	var hv := UIKit.vbox(3)
	hud.add_child(hv)

	var head := UIKit.hbox(6)
	hv.add_child(head)
	head.add_child(UIKit.caption("BNC · Bean Coin · Bolsa Felina", Color(UIKit.AMBER, 0.6)))
	head.add_child(UIKit.spacer())
	var live := UIKit.caption("● ao vivo", UIKit.RISK)
	head.add_child(live)
	var blink := create_tween().set_loops()
	blink.tween_property(live, "modulate:a", 0.25, 0.6)
	blink.tween_property(live, "modulate:a", 1.0, 0.6)

	var coin_row := UIKit.hbox(8)
	hv.add_child(coin_row)
	coin_row.add_child(UIKit.texture_rect(TEX_COIN, Vector2(34, 34)))
	coins_label = UIKit.ticker("0", 36, UIKit.AMBER)
	coins_label.add_theme_constant_override("outline_size", 0)
	coin_row.add_child(coins_label)

	var stats_row := UIKit.hbox(10)
	hv.add_child(stats_row)
	cps_label = UIKit.ticker("", 13, UIKit.PROFIT)
	stats_row.add_child(cps_label)
	change_label = UIKit.ticker("", 13, UIKit.MUTED)
	stats_row.add_child(change_label)
	stats_row.add_child(UIKit.spacer())
	click_label = UIKit.ticker("", 12, UIKit.MUTED)
	stats_row.add_child(click_label)

	sparkline = Sparkline.new()
	sparkline.custom_minimum_size = Vector2(0, 34)
	sparkline.source = func() -> float: return GameManager.coins
	hv.add_child(sparkline)

	title_label = UIKit.caption("", UIKit.PURPLE)
	hv.add_child(title_label)
	debt_chip = UIKit.button("", "danger", 12, Vector2(0, 28))
	debt_chip.visible = false
	debt_chip.pressed.connect(func(): loan_office.open())
	hv.add_child(debt_chip)

	# ── Grande Bean ──
	bean_button = TextureButton.new()
	bean_button.texture_normal = TEX_IDLE
	bean_button.ignore_texture_size = true
	bean_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bean_button.anchor_left = 0.5
	bean_button.anchor_right = 0.5
	bean_button.anchor_top = 0.47
	bean_button.anchor_bottom = 0.47
	bean_button.offset_left = -140
	bean_button.offset_right = 140
	bean_button.offset_top = -150
	bean_button.offset_bottom = 150
	bean_button.pivot_offset = Vector2(140, 150)
	bean_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bean_button.tooltip_text = "O Grande Bean. Clique para extrair mais-valia."
	bean_button.pressed.connect(_on_bean_clicked)
	play_area.add_child(bean_button)
	var breathe := create_tween().set_loops()
	breathe.tween_property(bean_button, "scale", Vector2(1.02, 0.985), 1.4).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(bean_button, "scale", Vector2(0.995, 1.01), 1.4).set_trans(Tween.TRANS_SINE)

	# ── Jornal ──
	ticker = NewsTicker.new()
	ticker.anchor_left = 0.0
	ticker.anchor_right = 1.0
	ticker.anchor_top = 1.0
	ticker.anchor_bottom = 1.0
	ticker.offset_left = 14
	ticker.offset_right = -14
	ticker.offset_top = -98
	ticker.offset_bottom = -68
	play_area.add_child(ticker)

	# ── Barra de ações ──
	var bar := UIKit.hbox(8)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 14
	bar.offset_right = -14
	bar.offset_top = -60
	bar.offset_bottom = -12
	play_area.add_child(bar)
	casino_action = _action_button("♠ CASSINO", "gold", bar)
	casino_action.pressed.connect(_open_casino)
	loan_action = _action_button("$ CRÉDITO", "ghost", bar)
	loan_action.add_theme_color_override("font_color", UIKit.ORANGE)
	loan_action.pressed.connect(func(): loan_office.open())
	prestige_action = _action_button("▼ FALÊNCIA", "danger", bar)
	prestige_action.pressed.connect(func(): prestige_screen.open())
	report_action = _action_button("★ RELATÓRIO", "purple", bar)
	report_action.pressed.connect(func(): achievements_panel.open())

	# ── Jeff Meowzos ambulante ──
	meowzos_popup = UIKit.panel(UIKit.shadowed(UIKit.box(Color(0.07, 0.05, 0.1, 0.94), UIKit.ORANGE, 12, 2, 8), 12, 0.6))
	meowzos_popup.anchor_top = 1.0
	meowzos_popup.anchor_bottom = 1.0
	meowzos_popup.offset_left = 14
	meowzos_popup.offset_right = 470
	meowzos_popup.offset_top = -250
	meowzos_popup.offset_bottom = -108
	meowzos_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN
	meowzos_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	meowzos_popup.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	meowzos_popup.tooltip_text = "Clique para visitar o escritório de crédito do Jeff Meowzos."
	meowzos_popup.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_hide_meowzos_popup()
			loan_office.open())
	meowzos_popup.visible = false
	play_area.add_child(meowzos_popup)
	meowzos_bubble = MeowzosBubble.new(Vector2(84, 106), 13, false)
	meowzos_popup.add_child(meowzos_bubble)

	# ── Toasts ──
	toast_box = UIKit.vbox(8)
	toast_box.anchor_left = 1.0
	toast_box.anchor_right = 1.0
	toast_box.offset_left = -374
	toast_box.offset_right = -14
	toast_box.offset_top = 12
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.add_child(toast_box)


## Botões da barra: teclas inclinadas, como bilhetes de aposta.
func _action_button(text: String, kind: String, parent: Control) -> Button:
	var b := UIKit.button(text, kind, 14, Vector2(0, 46))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.skew_button(b, 0.16)
	parent.add_child(b)
	return b


func _build_shop() -> void:
	shop = ShopPanel.new()
	shop.anchor_left = 1.0
	shop.anchor_right = 1.0
	shop.anchor_bottom = 1.0
	shop.offset_left = -SHOP_WIDTH
	ui.add_child(shop)
	shop.building_bought.connect(_on_building_bought)
	shop.upgrade_bought.connect(func(_i: int): _play(buy_sound, 1.15))
	shop.casino_pressed.connect(_open_casino)


func _build_modals() -> void:
	prestige_screen = PrestigeScreen.new()
	modal_layer.add_child(prestige_screen)
	prestige_screen.bankrupted.connect(func(_r: Dictionary): _play(prestige_sound))
	loan_office = LoanOffice.new()
	modal_layer.add_child(loan_office)
	achievements_panel = AchievementsPanel.new()
	modal_layer.add_child(achievements_panel)


func _setup_audio() -> void:
	click_sound.stream = SFX_CLICK
	click_sound.volume_db = -10.0
	click_sound.max_polyphony = 4
	buy_sound.stream = SFX_BUY
	buy_sound.volume_db = -6.0
	prestige_sound.stream = SFX_BUY
	prestige_sound.volume_db = -2.0
	prestige_sound.pitch_scale = 0.6
	var bgm := AudioStreamPlayer.new()
	bgm.name = "BGMPlayer"
	bgm.stream = SFX_BGM
	bgm.volume_db = -16.0
	bgm.autoplay = true
	bgm.finished.connect(func(): bgm.play())
	add_child(bgm)


func _play(player: AudioStreamPlayer, pitch: float = 1.0) -> void:
	if player and player.stream:
		player.pitch_scale = pitch
		player.play()


# ╔══════════════════════════════════════╗
# ║          HUD                         ║
# ╚══════════════════════════════════════╝

## Coisas que só mudam com eventos (CPS, título, multiplicadores).
func _update_hud_static() -> void:
	var gm := GameManager
	cps_label.text = "▲ %s/s" % NumberFormatter.format_cps(gm.cps)
	click_label.text = "CLIQUE %s" % NumberFormatter.format_number(gm.get_click_value())
	var bits: Array[String] = [gm.get_ceo_title()]
	if gm.prestige_count > 0 or gm.offshore_total > 0:
		bits.append("x%.2f prestígio" % gm.get_prestige_multiplier())
	if gm.offshore_bank > 0:
		bits.append("%d Fundos livres" % gm.offshore_bank)
	title_label.text = "  ·  ".join(bits).to_upper()
	casino_action.disabled = not gm.bets_unlocked
	casino_action.tooltip_text = "Sete jogos. Uma casa. Adivinha quem ganha." if gm.bets_unlocked else "Desbloqueie o cassino na loja (1.000 moedas)."
	_update_hud_dynamic()


## Coisas que mudam com o tempo (dívida, falência disponível).
func _update_hud_dynamic() -> void:
	var ch := sparkline.change_ratio()
	if absf(ch) < 0.0005:
		change_label.text = "= 0,0%"
		change_label.add_theme_color_override("font_color", UIKit.MUTED)
	else:
		change_label.text = ("%s %+.1f%%" % ["▲" if ch > 0.0 else "▼", ch * 100.0]).replace(".", ",")
		change_label.add_theme_color_override("font_color", UIKit.PROFIT if ch > 0.0 else UIKit.RISK)
	change_label.tooltip_text = "Variação do saldo no último minuto."
	if Meowzos.loan_active:
		debt_chip.visible = true
		debt_chip.text = "  DÍVIDA %s  •  vence em %s  " % [NumberFormatter.format_number(Meowzos.loan_debt), NumberFormatter.format_time(Meowzos.loan_time_left)]
		loan_action.text = "$ DÍVIDA %s" % NumberFormatter.format_time(Meowzos.loan_time_left)
	else:
		debt_chip.visible = false
		loan_action.text = "$ CRÉDITO"

	var gain := GameManager.calculate_prestige_gain()
	if gain > 0:
		prestige_action.text = "▼ FALIR (+%d)" % gain
		if _prestige_glow == null:
			_prestige_glow = create_tween().set_loops()
			_prestige_glow.tween_property(prestige_action, "modulate", Color(1.3, 0.9, 0.9), 0.6)
			_prestige_glow.tween_property(prestige_action, "modulate", Color.WHITE, 0.6)
	else:
		prestige_action.text = "▼ FALÊNCIA"
		if _prestige_glow:
			_prestige_glow.kill()
			_prestige_glow = null
			prestige_action.modulate = Color.WHITE


# ╔══════════════════════════════════════╗
# ║          INTERAÇÕES                  ║
# ╚══════════════════════════════════════╝

func _on_bean_clicked() -> void:
	var value := GameManager.click()
	_play(click_sound, randf_range(0.92, 1.1))
	bean_button.texture_normal = TEX_MINING
	get_tree().create_timer(0.09).timeout.connect(func(): bean_button.texture_normal = TEX_IDLE)
	var tw := create_tween()
	tw.tween_property(bean_button, "scale", Vector2(0.9, 0.93), 0.04)
	tw.tween_property(bean_button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var mouse := ui.get_local_mouse_position()
	UIKit.float_text(ui, "+" + NumberFormatter.format_number(value), mouse + Vector2(randf_range(-20, 20), -20))
	_coin_burst(mouse, 3)


## Moedinhas que espirram do clique.
func _coin_burst(pos: Vector2, count: int) -> void:
	for i in range(count):
		var c := UIKit.texture_rect(TEX_COIN, Vector2(18, 18))
		c.size = Vector2(18, 18)
		c.position = pos - Vector2(9, 9)
		ui.add_child(c)
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.4, -0.4)).normalized()
		var dist := randf_range(50.0, 110.0)
		var tw := c.create_tween().set_parallel(true)
		tw.tween_property(c, "position", c.position + dir * dist + Vector2(0, 40), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 0.0, 0.55).set_delay(0.15)
		tw.tween_property(c, "rotation", randf_range(-3.0, 3.0), 0.55)
		tw.chain().tween_callback(c.queue_free)


func _on_building_bought(_index: int, _amount: int) -> void:
	_play(buy_sound, randf_range(0.95, 1.08))
	_update_hud_static()


func _open_casino() -> void:
	if not GameManager.bets_unlocked:
		if GameManager.buy_bets_upgrade():
			_play(buy_sound)
			_update_hud_static()
		else:
			return
	_hide_meowzos_popup()
	bets_menu.open()


func _on_prestige_changed() -> void:
	_displayed_coins = GameManager.coins
	_update_hud_static()


func _on_casino_sfx(sfx_name: String) -> void:
	match sfx_name:
		"win":
			_play(buy_sound, 1.2)
		"big_win":
			_play(prestige_sound, 1.0)
		"lose":
			_play(click_sound, 0.6)
		_:
			_play(click_sound, randf_range(1.1, 1.4))


# ╔══════════════════════════════════════╗
# ║          ENTIDADES VISUAIS           ║
# ╚══════════════════════════════════════╝

func _total_entities() -> int:
	var n := 0
	for k in _entities:
		n += (_entities[k] as Array).size()
	return n


func _sync_all_entities() -> void:
	for i in range(GameManager.buildings.size()):
		_sync_entities_for(i)


## Garante que cada tipo tenha min(quantidade, limite) bonecos na tela.
func _sync_entities_for(index: int) -> void:
	var b: Dictionary = GameManager.buildings[index]
	var id: String = b["id"]
	if not _entities.has(id):
		_entities[id] = []
	var list: Array = _entities[id]
	var desired := mini(int(b["count"]), MAX_ENTITIES_PER_TYPE)
	while list.size() > desired:
		var e = list.pop_back()
		if is_instance_valid(e):
			e.vanish()
	while list.size() < desired and _total_entities() < MAX_ENTITIES:
		var e: Node2D = BUILDING_SCENE.instantiate()
		e.set("building_id", id)
		e.set("icon_path", b["icon"])
		e.set("target_size", 80.0 if id == "mini_bean" else 90.0)
		e.position = _random_entity_position()
		entities_root.add_child(e)
		list.append(e)


func _random_entity_position() -> Vector2:
	var vp := get_viewport_rect().size
	var play_w := vp.x - SHOP_WIDTH
	var bean_center := Vector2(play_w * 0.5, vp.y * 0.47)
	var pos := Vector2.ZERO
	for attempt in range(12):
		pos = Vector2(randf_range(50.0, play_w - 50.0), randf_range(170.0, vp.y - 140.0))
		if pos.distance_to(bean_center) > 170.0:
			break
	return pos


# ╔══════════════════════════════════════╗
# ║          JEFF MEOWZOS AMBULANTE        ║
# ╚══════════════════════════════════════╝

func _tick_meowzos(delta: float) -> void:
	if meowzos_popup.visible:
		_meowzos_hide_timer -= delta
		if _meowzos_hide_timer <= 0.0:
			_hide_meowzos_popup()
		return
	if bets_menu.visible or _any_modal_open():
		return
	_meowzos_timer -= delta
	if _meowzos_timer <= 0.0:
		_show_meowzos_popup(Meowzos.ambient_line(), "smug")


func _on_meowzos_said(text: String, mood: String) -> void:
	# Dentro do cassino ou do escritório, ele já tem palco próprio
	if bets_menu.visible or loan_office.is_open():
		return
	_show_meowzos_popup(text, mood)


func _show_meowzos_popup(text: String, mood: String) -> void:
	_meowzos_timer = randf_range(MEOWZOS_MIN_INTERVAL, MEOWZOS_MAX_INTERVAL)
	_meowzos_hide_timer = MEOWZOS_SHOW_TIME + text.length() * 0.03
	if not meowzos_popup.visible:
		meowzos_popup.visible = true
		meowzos_popup.modulate.a = 0.0
		meowzos_popup.position.x = -60.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(meowzos_popup, "modulate:a", 1.0, 0.2)
		tw.tween_property(meowzos_popup, "position:x", 14.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	meowzos_bubble.speak(text, mood)


func _hide_meowzos_popup() -> void:
	if not meowzos_popup.visible:
		return
	var tw := create_tween()
	tw.tween_property(meowzos_popup, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): meowzos_popup.visible = false)


func _any_modal_open() -> bool:
	return prestige_screen.is_open() or loan_office.is_open() or achievements_panel.is_open()


# ╔══════════════════════════════════════╗
# ║          NOTIFICAÇÕES                ║
# ╚══════════════════════════════════════╝

func _toast(head: String, body: String, accent: Color = UIKit.GOLD, duration: float = 4.0) -> void:
	var p := UIKit.panel(UIKit.shadowed(UIKit.box(Color(0.08, 0.06, 0.12, 0.97), accent, 10, 2, 12), 10, 0.5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(2)
	p.add_child(v)
	v.add_child(UIKit.title(head, 12, accent, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.wrap_label(body, 13, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	toast_box.add_child(p)
	# No máximo 3 notificações: as mais antigas saem (evita parede de toasts no load)
	while toast_box.get_child_count() > 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _on_achievement_unlocked(_id: String, a_name: String, desc: String) -> void:
	_play(buy_sound, 1.3)
	_toast("★ CONQUISTA: " + a_name.to_upper(), desc + "  (+1% produção)", UIKit.GOLD)
	_update_hud_static()


func _on_loan_defaulted(report: Dictionary) -> void:
	var parts: Array[String] = []
	parts.append("Dívida de %s executada." % NumberFormatter.format_number(report["debt"]))
	if float(report["from_cash"]) > 0.0:
		parts.append("Caixa confiscado: %s." % NumberFormatter.format_number(report["from_cash"]))
	var taken: Dictionary = report["repossessed"]
	if not taken.is_empty():
		var items: Array[String] = []
		for k in taken:
			items.append("%dx %s" % [taken[k], k])
		parts.append("Penhorado: " + ", ".join(items) + ".")
	parts.append("Nome sujo por %s." % NumberFormatter.format_time(Meowzos.BLACKLIST_TIME))
	_toast("PENHORA EXECUTADA", " ".join(parts), UIKit.RISK, 7.0)
	UIKit.shake(play_area, 12.0, 0.4)
	_play(prestige_sound, 0.5)


func _show_offline_report(r: Dictionary) -> void:
	var parts := UIKit.modal(modal_layer, Vector2(520, 0), UIKit.ORANGE)
	var overlay: ColorRect = parts[0]
	var panel: PanelContainer = parts[1]
	var v := UIKit.vbox(10)
	panel.add_child(v)
	v.add_child(UIKit.title("RELATÓRIO DE AUSÊNCIA", 22, UIKit.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	var bubble := MeowzosBubble.new(Vector2(80, 100), 13, false)
	v.add_child(bubble)
	var fee := 1.0 - float(r["rate"])
	var rows: Array = [
		["Tempo fora", NumberFormatter.format_time(r["elapsed"])],
		["Tempo contabilizado", NumberFormatter.format_time(r["counted"])],
		["Produção bruta", NumberFormatter.format_number(r["gross"])],
		["Taxa de administração (%s)" % NumberFormatter.format_percent(fee), "-" + NumberFormatter.format_number(float(r["gross"]) - float(r["net"]))],
	]
	for row in rows:
		var h := UIKit.hbox(4)
		h.add_child(UIKit.label(row[0], 13, UIKit.MUTED))
		h.add_child(UIKit.spacer())
		h.add_child(UIKit.label(row[1], 13, UIKit.INK))
		v.add_child(h)
	var total := UIKit.hbox(4)
	total.add_child(UIKit.title("VOCÊ RECEBE", 16, UIKit.GOLD))
	total.add_child(UIKit.spacer())
	total.add_child(UIKit.title("+" + NumberFormatter.format_number(r["net"]), 18, UIKit.PROFIT))
	v.add_child(total)
	var ok := UIKit.button("Que generoso, Jeff Meowzos", "gold", 15, Vector2(0, 44))
	ok.pressed.connect(func(): overlay.queue_free())
	v.add_child(ok)
	overlay.visible = true
	bubble.speak(Meowzos.line("offline", {"fee": NumberFormatter.format_percent(fee)}), "smug")
