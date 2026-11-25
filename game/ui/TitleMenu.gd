class_name TitleMenu
extends Control
## Menu principal / pausa. Simples de propósito: o jogo é um clicker.
## Aparece ao abrir o jogo e com ESC durante a partida (pausa a economia).
## Continuar · Novo jogo · Opções (volume e tela cheia) · Créditos · Sair.

signal resumed
signal new_game_requested

const SETTINGS_PATH: String = "user://settings.cfg"
const TEX_BEAN: Texture2D = preload("res://images/BeansIdle.png")
const TEX_JEFF: Texture2D = preload("res://images/jeff_meowzos.svg")

var _root_box: VBoxContainer
var _main_page: VBoxContainer
var _options_page: VBoxContainer
var _credits_page: VBoxContainer
var _confirm_page: VBoxContainer
var _continue_btn: Button
var _music_slider: HSlider
var _sfx_slider: HSlider
var _fullscreen_btn: CheckButton
var _is_open: bool = false
var _first_open: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_build()
	_load_settings()
	visible = false


# ══════════════════════════════════════
# CONSTRUÇÃO
# ══════════════════════════════════════

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.07, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Arte dos dois protagonistas nas laterais.
	# Luz quente atrás do Bean: gato preto some no fundo escuro sem esse contorno.
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.82, 0.45, 0.35))
	grad.set_color(1, Color(1.0, 0.82, 0.45, 0.0))
	var glow_tex := GradientTexture2D.new()
	glow_tex.gradient = grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	var glow := TextureRect.new()
	glow.texture = glow_tex
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.anchor_top = 1.0
	glow.anchor_bottom = 1.0
	glow.offset_left = -20
	glow.offset_right = 380
	glow.offset_top = -420
	glow.offset_bottom = -20
	add_child(glow)
	var bean := UIKit.texture_rect(TEX_BEAN, Vector2(300, 360))
	bean.anchor_top = 1.0
	bean.anchor_bottom = 1.0
	bean.offset_left = 30
	bean.offset_right = 330
	bean.offset_top = -380
	bean.offset_bottom = -20
	bean.modulate = Color(1, 1, 1, 0.9)
	add_child(bean)
	var jeff := UIKit.texture_rect(TEX_JEFF, Vector2(300, 375))
	jeff.anchor_left = 1.0
	jeff.anchor_right = 1.0
	jeff.anchor_top = 1.0
	jeff.anchor_bottom = 1.0
	jeff.offset_left = -330
	jeff.offset_right = -30
	jeff.offset_top = -395
	jeff.offset_bottom = -20
	add_child(jeff)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UIKit.panel(UIKit.deco(UIKit.NIGHT, UIKit.GOLD, 22))
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	_root_box = UIKit.vbox(10)
	panel.add_child(_root_box)

	var title := UIKit.title("BEANCLICKER", 48, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_root_box.add_child(title)
	var sub := UIKit.caption("O cassino do Jeff Meowzos", UIKit.ORANGE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root_box.add_child(sub)
	_root_box.add_child(HSeparator.new())

	_main_page = _page()
	_continue_btn = _menu_button(_main_page, "CONTINUAR", "gold", close_menu)
	_menu_button(_main_page, "NOVO JOGO", "ghost", _on_new_game)
	_menu_button(_main_page, "OPÇÕES", "ghost", func(): _show(_options_page))
	_menu_button(_main_page, "CRÉDITOS", "ghost", func(): _show(_credits_page))
	_menu_button(_main_page, "SAIR", "danger", _on_quit)

	_options_page = _page()
	_options_page.add_child(UIKit.caption("Volume da música", UIKit.MUTED))
	_music_slider = _volume_slider("Music")
	_options_page.add_child(_music_slider)
	_options_page.add_child(UIKit.caption("Volume dos efeitos", UIKit.MUTED))
	_sfx_slider = _volume_slider("SFX")
	_options_page.add_child(_sfx_slider)
	_fullscreen_btn = CheckButton.new()
	_fullscreen_btn.text = "Tela cheia"
	_fullscreen_btn.focus_mode = Control.FOCUS_NONE
	_fullscreen_btn.toggled.connect(_on_fullscreen)
	_options_page.add_child(_fullscreen_btn)
	_menu_button(_options_page, "VOLTAR", "ghost", func():
		_save_settings()
		_show(_main_page))

	_credits_page = _page()
	_credits_page.add_child(UIKit.label("Projeto PAC · Godot 4.7", 12, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var team := [
		["Abner", "Game design e balanceamento"],
		["Athos", "Engenharia e sistema de save"],
		["Lucas Scheibe", "UI/UX e sistema de apostas"],
		["Raoni", "Matemática dos mini-jogos"],
		["Ruan Vitor", "Arte, sprites e animações"],
		["Vitor Kill", "Áudio, GDD e QA"],
	]
	for t in team:
		var row := UIKit.hbox(8)
		row.add_child(UIKit.label(t[0], 14, UIKit.GOLD_LIGHT))
		row.add_child(UIKit.spacer())
		row.add_child(UIKit.label(t[1], 12, UIKit.INK))
		_credits_page.add_child(row)
	_menu_button(_credits_page, "VOLTAR", "ghost", func(): _show(_main_page))

	_confirm_page = _page()
	var warn := UIKit.wrap_label("Começar do zero apaga todo o seu progresso: moedas, estruturas, Fundos Offshore, conquistas e a cesta de peixes. O Jeff adora um recomeço.", 13, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	warn.custom_minimum_size = Vector2(380, 0)
	_confirm_page.add_child(warn)
	_menu_button(_confirm_page, "APAGAR E COMEÇAR", "danger", _confirm_new_game)
	_menu_button(_confirm_page, "CANCELAR", "ghost", func(): _show(_main_page))

	_root_box.add_child(UIKit.label("v2.1 · ESC abre este menu durante o jogo", 10, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_show(_main_page)


func _page() -> VBoxContainer:
	var p := UIKit.vbox(8)
	_root_box.add_child(p)
	return p


func _menu_button(parent: Control, text: String, kind: String, action: Callable) -> Button:
	var b := UIKit.button(text, kind, 16, Vector2(0, 44))
	b.add_theme_font_override("font", UIKit.display_font())
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _volume_slider(bus: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(0, 26)
	s.value_changed.connect(func(v: float): _set_bus_volume(bus, v))
	return s


func _show(page: Control) -> void:
	for p in [_main_page, _options_page, _credits_page, _confirm_page]:
		p.visible = (p == page)


# ══════════════════════════════════════
# ABRIR / FECHAR (pausa)
# ══════════════════════════════════════

func open_menu() -> void:
	_is_open = true
	visible = true
	_show(_main_page)
	_continue_btn.text = "JOGAR" if _first_open and GameManager.lifetime_earned <= 0.0 else "CONTINUAR"
	get_tree().paused = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func close_menu() -> void:
	if not _is_open:
		return
	_is_open = false
	_first_open = false
	_save_settings()
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		if not _is_open:
			visible = false)
	resumed.emit()


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed("ui_cancel"):
		if _main_page.visible:
			close_menu()
		else:
			_show(_main_page)
		get_viewport().set_input_as_handled()


func _on_new_game() -> void:
	if GameManager.lifetime_earned <= 0.0 and GameManager.get_total_buildings() == 0:
		close_menu()
		return
	_show(_confirm_page)


func _confirm_new_game() -> void:
	new_game_requested.emit()
	close_menu()


func _on_quit() -> void:
	SaveSystem.save_game()
	get_tree().quit()


# ══════════════════════════════════════
# ÁUDIO E CONFIGURAÇÕES
# ══════════════════════════════════════

## Cria os barramentos "Music" e "SFX" para o volume ser ajustável separadamente.
func _setup_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


func _set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _on_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_music_slider.value = float(cfg.get_value("audio", "music", 0.8))
	_sfx_slider.value = float(cfg.get_value("audio", "sfx", 1.0))
	_set_bus_volume("Music", _music_slider.value)
	_set_bus_volume("SFX", _sfx_slider.value)
	var fs: bool = bool(cfg.get_value("video", "fullscreen", false))
	_fullscreen_btn.set_pressed_no_signal(fs)
	if fs:
		_on_fullscreen(true)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", _music_slider.value)
	cfg.set_value("audio", "sfx", _sfx_slider.value)
	cfg.set_value("video", "fullscreen", _fullscreen_btn.button_pressed)
	cfg.save(SETTINGS_PATH)
