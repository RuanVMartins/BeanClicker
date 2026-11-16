extends CasinoGame
## ROLETA CLANDESTINA — 13 casas (0 a 12). Ímpares vermelhos, pares pretos, 0 verde.
## Correção de design: na versão antiga "Vermelho" e "Ímpar" eram a MESMA aposta
## (a roda colore por paridade). Substituí Par/Ímpar por Baixo (1-6) / Alto (7-12),
## que é independente da cor.
## Pagamentos: apostas simples 2x (6/13), número exato ou verde 12x (1/13).
## RTP de todas as apostas: 12/13 = 92,3%. O zero é o aluguel do Jeff Meowzos.

const TEX_WHEEL: Texture2D = preload("res://images/roulette_wheel.png")
const POCKETS: int = 13
const BETS: Array[Dictionary] = [
	{"id": "red", "label": "VERMELHO", "pay": 2.0, "color": Color("#C0392B")},
	{"id": "black", "label": "PRETO", "pay": 2.0, "color": Color("#2B2B36")},
	{"id": "low", "label": "BAIXO 1-6", "pay": 2.0, "color": Color("#2C4A7A")},
	{"id": "high", "label": "ALTO 7-12", "pay": 2.0, "color": Color("#2C4A7A")},
	{"id": "green", "label": "VERDE 0", "pay": 12.0, "color": Color("#1E8449")},
	{"id": "number", "label": "NÚMERO", "pay": 12.0, "color": Color("#8A6A1C")},
]

var _wheel: TextureRect
var _bet_buttons: Array[Button] = []
var _number_opt: OptionButton
var _selected: int = 0
var _spin_btn: Button
var _result: Label
var _history: HBoxContainer
var _spinning: bool = false


func game_id() -> String:
	return "roulette"


func tab_title() -> String:
	return "Roleta"


func intro_key() -> String:
	return "tab_roulette"


func rules_text() -> String:
	return "Simples pagam 2x  •  Número/Verde pagam 12x  •  O zero é da casa"


func build() -> void:
	add_theme_constant_override("separation", 8)
	add_child(header("ROLETA CLANDESTINA"))

	var body := UIKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	var wheel_col := UIKit.vbox(2)
	body.add_child(wheel_col)
	wheel_col.add_child(UIKit.title("▼", 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(250, 250)
	wheel_col.add_child(holder)
	_wheel = UIKit.texture_rect(TEX_WHEEL, Vector2(250, 250))
	_wheel.size = Vector2(250, 250)
	_wheel.pivot_offset = Vector2(125, 125)
	holder.add_child(_wheel)
	_history = UIKit.hbox(3)
	_history.alignment = BoxContainer.ALIGNMENT_CENTER
	wheel_col.add_child(_history)

	var controls := UIKit.vbox(8)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(controls)
	controls.add_child(UIKit.label("ESCOLHA SUA APOSTA", 11, UIKit.MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	controls.add_child(grid)
	for i in range(BETS.size()):
		var def: Dictionary = BETS[i]
		var b := Button.new()
		b.text = "%s  (%dx)" % [def["label"], int(def["pay"])]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col: Color = def["color"]
		UIKit.apply_key(b, col, col.darkened(0.4), UIKit.GOLD_LIGHT)
		b.add_theme_font_override("font", UIKit.display_font())
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", UIKit.GOLD_LIGHT)
		b.pressed.connect(_select.bind(i))
		grid.add_child(b)
		_bet_buttons.append(b)

	var num_row := UIKit.hbox(6)
	controls.add_child(num_row)
	num_row.add_child(UIKit.label("Número exato:", 12, UIKit.MUTED))
	_number_opt = OptionButton.new()
	for n in range(1, POCKETS):
		_number_opt.add_item("%d  (%s)" % [n, "vermelho" if n % 2 == 1 else "preto"], n)
	_number_opt.select(6)
	_number_opt.item_selected.connect(func(_i: int): _select(5))
	num_row.add_child(_number_opt)

	controls.add_child(UIKit.spacer(false))
	_result = result_label()
	controls.add_child(_result)
	_spin_btn = big_button("GIRAR A ROLETA")
	_spin_btn.pressed.connect(_on_spin)
	controls.add_child(_spin_btn)
	_select(0)


func _select(i: int) -> void:
	if _spinning:
		return
	_selected = i
	for j in range(_bet_buttons.size()):
		_bet_buttons[j].set_pressed_no_signal(j == i)


func _wins(n: int) -> bool:
	match BETS[_selected]["id"]:
		"red":
			return n != 0 and n % 2 == 1
		"black":
			return n != 0 and n % 2 == 0
		"low":
			return n >= 1 and n <= 6
		"high":
			return n >= 7
		"green":
			return n == 0
		"number":
			return n == _number_opt.get_selected_id()
	return false


func _on_spin() -> void:
	if _spinning:
		return
	var bet := take_bet()
	if bet <= 0.0:
		return
	set_busy(true)
	_spinning = true
	_spin_btn.disabled = true
	_result.text = ""
	var n := randi_range(0, POCKETS - 1)

	# A roda tem o 0 no topo e segue em sentido horário; girar -n fatias traz n ao ponteiro.
	var slice := 360.0 / POCKETS
	var current := fmod(_wheel.rotation_degrees, 360.0)
	_wheel.rotation_degrees = current
	var target_mod := fmod(360.0 - n * slice, 360.0)
	var delta := fmod(target_mod - current + 360.0, 360.0)
	var final_angle := current + 360.0 * 5.0 + delta + randf_range(-slice * 0.3, slice * 0.3)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_wheel, "rotation_degrees", final_angle, 3.6)
	_tick_sounds()
	await tw.finished
	_finish(n, bet)


func _tick_sounds() -> void:
	var gap := 0.08
	while _spinning and is_inside_tree():
		menu.emit_sfx("click")
		await wait(gap)
		gap *= 1.12
		if gap > 0.6:
			break


func _finish(n: int, bet: float) -> void:
	var won := _wins(n)
	var pay: float = BETS[_selected]["pay"] if won else 0.0
	var paid := settle(bet, bet * pay)
	var col_name := "VERDE" if n == 0 else ("VERMELHO" if n % 2 == 1 else "PRETO")
	if won:
		show_result(_result, "Deu %d %s! +%s" % [n, col_name, NumberFormatter.format_number(paid - bet)], UIKit.PROFIT)
		if BETS[_selected]["id"] == "number":
			GameManager.unlock_achievement("bet_roulette_number")
	elif n == 0:
		show_result(_result, "ZERO. A casa agradece. -%s" % NumberFormatter.format_number(bet), UIKit.RISK)
	else:
		show_result(_result, "Deu %d %s. -%s" % [n, col_name, NumberFormatter.format_number(bet)], UIKit.RISK)
	_add_history(n)
	_spinning = false
	_spin_btn.disabled = false
	set_busy(false)


func _add_history(n: int) -> void:
	var col := Color("#1E8449") if n == 0 else (Color("#C0392B") if n % 2 == 1 else Color("#2B2B36"))
	var chip := UIKit.panel(UIKit.box(col, Color(1, 1, 1, 0.3), 12, 1, 3))
	chip.custom_minimum_size = Vector2(24, 24)
	chip.add_child(UIKit.label(str(n), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_history.add_child(chip)
	_history.move_child(chip, 0)
	while _history.get_child_count() > 9:
		var last := _history.get_child(_history.get_child_count() - 1)
		_history.remove_child(last)
		last.queue_free()
