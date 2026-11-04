extends CasinoGame
## CORRIDA DE RATOS — "igual ao mercado de trabalho, só que mais honesto".
## O vencedor é sorteado ANTES da largada pelas probabilidades abaixo; a corrida
## é teatro. Pagamento = 0,94 / probabilidade → RTP 94% em qualquer rato.
## O Herdeiro Nepo larga 25% à frente (privilégio visual) e é o favorito.

const RACERS: Array[Dictionary] = [
	{"name": "Herdeiro Nepo", "p": 0.34, "color": Color("#E0B840"), "head_start": 0.25,
		"bio": "Largou na frente porque o pai é dono da pista."},
	{"name": "Coach Quântico", "p": 0.26, "color": Color("#B57BFF"), "head_start": 0.0,
		"bio": "Visualizou a vitória. Agora só falta correr."},
	{"name": "Estagiário Motivado", "p": 0.19, "color": Color("#5CF2FF"), "head_start": 0.0,
		"bio": "Corre por exposição e um vale-refeição de 12 moedas."},
	{"name": "CLT Exausto", "p": 0.13, "color": Color("#FF9F43"), "head_start": 0.0,
		"bio": "Trabalhou o turno da noite antes da corrida."},
	{"name": "Influencer de Cripto", "p": 0.08, "color": Color("#48F29A"), "head_start": 0.0,
		"bio": "Garante que vai 'to the moon'. Geralmente vai pro ralo."},
]
const RTP: float = 0.94
const TEX_RAT: Texture2D = preload("res://images/rat.png")
const RACE_TIME: float = 5.0

var _track: Control
var _runners: Array[Control] = []
var _rat_icons: Array[TextureRect] = []
var _lanes: Array[ColorRect] = []
var _pick_buttons: Array[Button] = []
var _selected: int = 0
var _start_btn: Button
var _result: Label
var _racing: bool = false
var _t: float = 0.0
var _finish_times: Array[float] = []
var _wobble: Array[Vector2] = []
var _winner: int = 0
var _bet: float = 0.0


func game_id() -> String:
	return "rats"


func tab_title() -> String:
	return "Ratos"


func intro_key() -> String:
	return "tab_rats"


func rules_text() -> String:
	return "Escolha um rato  •  odds fixas  •  RTP 94%"


func _payout(i: int) -> float:
	return floor(RTP / float(RACERS[i]["p"]) * 100.0) / 100.0


func build() -> void:
	add_theme_constant_override("separation", 8)
	add_child(header("CORRIDA DE RATOS"))

	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 190)
	_track.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track.clip_contents = true
	add_child(_track)
	_track.resized.connect(_layout_track)
	for i in range(RACERS.size()):
		var lane := ColorRect.new()
		lane.color = Color("#7A6040") if i % 2 == 0 else Color("#6C5437")
		lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_track.add_child(lane)
		_lanes.append(lane)
		var r := _make_runner(i)
		_track.add_child(r)
		_runners.append(r)
	var finish := ColorRect.new()
	finish.name = "Finish"
	finish.color = Color(1, 1, 1, 0.6)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(finish)

	var picks := GridContainer.new()
	picks.columns = 5
	picks.add_theme_constant_override("h_separation", 5)
	add_child(picks)
	for i in range(RACERS.size()):
		var def: Dictionary = RACERS[i]
		var b := UIKit.button("%s\n%.2fx" % [def["name"], _payout(i)], "ghost", 11, Vector2(0, 46))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.tooltip_text = "%s\nChance: %s  •  Paga %.2fx" % [def["bio"], NumberFormatter.format_percent(def["p"]), _payout(i)]
		b.add_theme_color_override("font_color", def["color"])
		b.pressed.connect(_select.bind(i))
		picks.add_child(b)
		_pick_buttons.append(b)

	_result = result_label()
	add_child(_result)
	_start_btn = big_button("LARGAR!")
	_start_btn.pressed.connect(_on_start)
	add_child(_start_btn)
	_select(0)


## Corredor = sprite do rato + nome. A arte original olha para a esquerda;
## a pista corre para a direita, então o TextureRect é espelhado com flip_h.
func _make_runner(i: int) -> HBoxContainer:
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rat := TextureRect.new()
	rat.texture = TEX_RAT
	rat.flip_h = true
	rat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rat.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rat.custom_minimum_size = Vector2(66, 24)
	rat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rat)
	_rat_icons.append(rat)
	var name_l := UIKit.label(RACERS[i]["name"], 12, RACERS[i]["color"], HORIZONTAL_ALIGNMENT_LEFT, 3)
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	return row


func _layout_track() -> void:
	var h := _track.size.y / RACERS.size()
	for i in range(RACERS.size()):
		_lanes[i].position = Vector2(0, i * h)
		_lanes[i].size = Vector2(_track.size.x, h)
		if not _racing:
			_place_runner(i, float(RACERS[i]["head_start"]))
	var finish: ColorRect = _track.get_node("Finish")
	finish.position = Vector2(_track.size.x - 26.0, 0)
	finish.size = Vector2(4, _track.size.y)


func _place_runner(i: int, progress: float) -> void:
	var h := _track.size.y / RACERS.size()
	var r := _runners[i]
	var w := _track.size.x - r.size.x - 30.0
	r.position = Vector2(8.0 + progress * maxf(w, 10.0), i * h + (h - r.size.y) * 0.5)


func _select(i: int) -> void:
	if _racing:
		return
	_selected = i
	for j in range(_pick_buttons.size()):
		_pick_buttons[j].set_pressed_no_signal(j == i)


func _pick_winner() -> int:
	var r := randf()
	for i in range(RACERS.size()):
		r -= float(RACERS[i]["p"])
		if r <= 0.0:
			return i
	return 0


func _on_start() -> void:
	if _racing:
		return
	_bet = take_bet()
	if _bet <= 0.0:
		return
	set_busy(true)
	_racing = true
	_start_btn.disabled = true
	_result.text = ""
	_winner = _pick_winner()
	_finish_times.clear()
	_wobble.clear()
	for i in range(RACERS.size()):
		var ft := RACE_TIME if i == _winner else RACE_TIME + randf_range(0.25, 1.6)
		_finish_times.append(ft)
		_wobble.append(Vector2(randf_range(2.0, 5.0), randf_range(0.0, TAU)))
	_t = 0.0
	menu.emit_sfx("click")


func _process(delta: float) -> void:
	if not _racing:
		return
	_t += delta
	for i in range(RACERS.size()):
		var hs: float = RACERS[i]["head_start"]
		var lin := clampf(_t / _finish_times[i], 0.0, 1.0)
		# Ritmo irregular: arrancadas e cansaço, mas termina exatamente no tempo sorteado
		var wob := sin(_t * _wobble[i].x + _wobble[i].y) * 0.05 * sin(lin * PI)
		var p := clampf(hs + (1.0 - hs) * (lin + wob), 0.0, 1.0)
		_place_runner(i, p)
		# Galope: o rato balança enquanto não cruzou a linha
		var rat := _rat_icons[i]
		rat.pivot_offset = rat.size * 0.5
		rat.rotation = sin(_t * (14.0 + i * 1.7) + _wobble[i].y) * 0.09 * (1.0 - lin)
		rat.scale = Vector2(1.0, 1.0 + sin(_t * 20.0 + i) * 0.06 * (1.0 - lin))
	if _t >= RACE_TIME:
		_racing = false
		_finish()


func _finish() -> void:
	var won := _winner == _selected
	var paid := settle(_bet, _bet * _payout(_selected) if won else 0.0)
	UIKit.pop(_runners[_winner], 1.3, 0.3)
	if won:
		show_result(_result, "%s VENCEU! +%s" % [RACERS[_winner]["name"], NumberFormatter.format_number(paid - _bet)], UIKit.PROFIT)
		if _selected == RACERS.size() - 1:
			GameManager.unlock_achievement("bet_rat_longshot")
	else:
		var quip := " Surpresa nenhuma." if _winner == 0 else ""
		show_result(_result, "%s venceu.%s -%s" % [RACERS[_winner]["name"], quip, NumberFormatter.format_number(_bet)], UIKit.RISK)
	await wait(1.6)
	for i in range(RACERS.size()):
		_place_runner(i, float(RACERS[i]["head_start"]))
		_rat_icons[i].rotation = 0.0
		_rat_icons[i].scale = Vector2.ONE
	_start_btn.disabled = false
	set_busy(false)
