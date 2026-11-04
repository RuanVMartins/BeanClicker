extends CasinoGame
## RASPADINHA DO TRABALHADOR — "o imposto voluntário de quem não gosta de matemática".
## O resultado é sorteado na compra (como nas de verdade); a grade só encena.
## Tabela: 0x 76,1% | 1x 12% | 2x 6,5% | 5x 3,5% | 10x 1,35% | 50x 0,4% | 100x 0,15%
## RTP 91%. Cartões perdedores recebem dois "100x" em 55% das vezes:
## near-miss proposital — é exatamente assim que a indústria fisga, e o jogo
## faz piada disso abertamente.

const PRIZES: Array[float] = [1.0, 2.0, 5.0, 10.0, 50.0, 100.0]
const TABLE: Array = [[0.0, 0.761], [1.0, 0.12], [2.0, 0.065], [5.0, 0.035], [10.0, 0.0135], [50.0, 0.004], [100.0, 0.0015]]

var _cells: Array[Button] = []
var _values: Array[float] = []
var _revealed: Array[bool] = []
var _buy_btn: Button
var _reveal_all_btn: Button
var _result: Label
var _bet: float = 0.0
var _outcome: float = 0.0
var _active: bool = false


func game_id() -> String:
	return "scratch"


func tab_title() -> String:
	return "Raspadinha"


func intro_key() -> String:
	return "tab_scratch"


func rules_text() -> String:
	return "3 valores iguais = ganha aquele valor  •  até 100x"


func build() -> void:
	add_theme_constant_override("separation", 8)
	add_child(header("RASPADINHA DO TRABALHADOR"))

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)
	var card := UIKit.panel(UIKit.shadowed(UIKit.box(Color("#F2C94C"), Color("#8A6A1C"), 14, 3, 12), 10, 0.5))
	center.add_child(card)
	var cv := UIKit.vbox(6)
	card.add_child(cv)
	cv.add_child(UIKit.title("SORTE GRANDE DO BEAN", 16, Color("#5A3A00"), HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	cv.add_child(grid)
	for i in range(9):
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 62)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", UIKit.display_font())
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_scratch.bind(i))
		grid.add_child(b)
		_cells.append(b)
		_values.append(0.0)
		_revealed.append(false)
	cv.add_child(UIKit.label("Prêmio sujeito a IR, IOF, taxa de conveniência e humor do Jeff Meowzos.", 9, Color("#5A3A00"), HORIZONTAL_ALIGNMENT_CENTER))

	_result = result_label()
	add_child(_result)

	var btns := UIKit.hbox(8)
	add_child(btns)
	_buy_btn = big_button("COMPRAR RASPADINHA")
	_buy_btn.pressed.connect(_on_buy)
	btns.add_child(_buy_btn)
	_reveal_all_btn = big_button("RASPAR TUDO", "purple")
	_reveal_all_btn.pressed.connect(_reveal_all)
	btns.add_child(_reveal_all_btn)
	_style_cells_covered(true)
	_reveal_all_btn.disabled = true


func _style_cells_covered(blank: bool) -> void:
	for i in range(9):
		var b := _cells[i]
		var cover := UIKit.box(Color("#B8B8C8"), Color("#7A7A8C"), 8, 2, 4)
		b.add_theme_stylebox_override("normal", cover)
		b.add_theme_stylebox_override("hover", UIKit.box(Color("#D0D0DE"), UIKit.GOLD, 8, 2, 4))
		b.add_theme_stylebox_override("pressed", cover)
		b.add_theme_stylebox_override("disabled", UIKit.box(Color("#9A9AAA"), Color("#7A7A8C"), 8, 2, 4))
		b.add_theme_color_override("font_color", Color("#55556A"))
		b.add_theme_color_override("font_disabled_color", Color("#77778A"))
		b.text = "" if blank else "RASPE"
		b.disabled = blank


func _roll_outcome() -> float:
	var r := randf()
	for row in TABLE:
		r -= float(row[1])
		if r <= 0.0:
			return float(row[0])
	return 0.0


## Monta a grade coerente com o resultado: exatamente um valor triplo se ganhou.
func _build_grid(outcome: float) -> void:
	var cells: Array[float] = []
	var counts := {}
	if outcome > 0.0:
		for i in range(3):
			cells.append(outcome)
		counts[outcome] = 3
	elif randf() < 0.55:
		cells.append(100.0)
		cells.append(100.0)
		counts[100.0] = 2
	while cells.size() < 9:
		var v: float = PRIZES[randi() % PRIZES.size()]
		if v == outcome or int(counts.get(v, 0)) >= 2:
			continue
		counts[v] = int(counts.get(v, 0)) + 1
		cells.append(v)
	cells.shuffle()
	for i in range(9):
		_values[i] = cells[i]
		_revealed[i] = false


func _on_buy() -> void:
	if _active:
		return
	_bet = take_bet()
	if _bet <= 0.0:
		return
	set_busy(true)
	_active = true
	_outcome = _roll_outcome()
	_build_grid(_outcome)
	_style_cells_covered(false)
	_buy_btn.disabled = true
	_reveal_all_btn.disabled = false
	_result.text = ""
	menu.emit_sfx("click")


func _scratch(i: int) -> void:
	if not _active or _revealed[i]:
		return
	_revealed[i] = true
	var b := _cells[i]
	var v := _values[i]
	var hot := v >= 50.0
	var bg := Color("#FFF6D8") if not hot else Color("#FFE08A")
	var st := UIKit.box(bg, Color("#8A6A1C"), 8, 2, 4)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	b.text = "%dx" % int(v)
	var col := Color("#B3261E") if hot else Color("#3B2A12")
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_disabled_color", col)
	b.disabled = true
	UIKit.pop(b, 1.15, 0.18)
	menu.emit_sfx("click")
	if not _revealed.has(false):
		_finish()


func _reveal_all() -> void:
	if not _active:
		return
	_reveal_all_btn.disabled = true
	for i in range(9):
		if not _revealed[i]:
			_scratch(i)
			await wait(0.07)


func _finish() -> void:
	_active = false
	_reveal_all_btn.disabled = true
	var paid := settle(_bet, _bet * _outcome)
	if _outcome > 1.0:
		for i in range(9):
			if _values[i] == _outcome:
				UIKit.flash(_cells[i], Color(0.7, 1.6, 0.8), 1.0)
		show_result(_result, "3x %dx! Ganhou %s" % [int(_outcome), NumberFormatter.format_number(paid)], UIKit.PROFIT)
		if _outcome >= 50.0:
			GameManager.unlock_achievement("bet_scratch_big")
	elif _outcome == 1.0:
		show_result(_result, "Ganhou... sua aposta de volta. Uau.", UIKit.MUTED)
	else:
		var near := _values.count(100.0) >= 2
		show_result(_result, "QUASE! Faltou um 100x. (Sempre falta.)" if near else "Não foi dessa vez. Nunca é.", UIKit.RISK)
	await wait(0.6)
	_buy_btn.disabled = false
	set_busy(false)
