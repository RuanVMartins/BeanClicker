extends CasinoGame
## ESQUEMA PIRÂMIDE ("Marketing Multinível de Impacto").
## Entre no esquema e recrute nível por nível. Cada recrutamento tem 72% de
## chance de dar certo; se falhar, a pirâmide desaba e você perde tudo.
## Saque quando quiser. Multiplicador no nível n = 0,96 / 0,72^n
## (1.33x, 1.85x, 2.57x ... 25.6x no nível 10) → RTP 96% em qualquer ponto de saque.

const SUCCESS: float = 0.72
const EDGE: float = 0.96
const LEVELS: Array[String] = [
	"1 cunhado", "2 amigos", "4 primos", "8 colegas de firma", "16 vizinhos",
	"32 do grupo da família", "64 contatos do LinkedIn", "128 desconhecidos",
	"256 aposentados", "512 'investidores'",
]

var _rows: Array[PanelContainer] = []
var _row_labels: Array[Label] = []
var _enter_btn: Button
var _recruit_btn: Button
var _cash_btn: Button
var _result: Label
var _level: int = 0
var _bet: float = 0.0
var _active: bool = false
var _recruiting: bool = false   # evita recrutamento duplo durante a animação


func game_id() -> String:
	return "pyramid"


func tab_title() -> String:
	return "Pirâmide"


func intro_key() -> String:
	return "tab_pyramid"


func rules_text() -> String:
	return "72% por nível  •  saque quando quiser  •  até 25x"


func mult(level: int) -> float:
	if level <= 0:
		return 0.0
	return floor(EDGE / pow(SUCCESS, level) * 100.0) / 100.0


func build() -> void:
	add_theme_constant_override("separation", 6)
	add_child(header("ESQUEMA PIRÂMIDE"))

	var pyramid := UIKit.vbox(3)
	pyramid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pyramid.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pyramid)
	# Você no topo; cada nível recrutado alarga a base logo abaixo
	for i in range(LEVELS.size()):
		var level := i + 1
		var row := UIKit.panel(UIKit.box(Color(0.1, 0.08, 0.14), Color(0.3, 0.25, 0.42, 0.5), 6, 1, 3))
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.custom_minimum_size = Vector2(150 + i * 44, 24)
		var l := UIKit.label("%d. %s   x%.2f" % [level, LEVELS[i], mult(level)], 11, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		row.add_child(l)
		pyramid.add_child(row)
		_rows.append(row)
		_row_labels.append(l)

	_result = result_label()
	add_child(_result)

	var btns := UIKit.hbox(8)
	add_child(btns)
	_enter_btn = big_button("ENTRAR NO ESQUEMA")
	_enter_btn.pressed.connect(_on_enter)
	btns.add_child(_enter_btn)
	_recruit_btn = big_button("RECRUTAR (72%)", "success")
	_recruit_btn.pressed.connect(_on_recruit)
	btns.add_child(_recruit_btn)
	_cash_btn = big_button("SACAR", "purple")
	_cash_btn.pressed.connect(_on_cash)
	btns.add_child(_cash_btn)
	_refresh()


func _refresh() -> void:
	for i in range(_rows.size()):
		var level := i + 1
		var row := _rows[i]
		var col: Color
		if _active and level <= _level:
			col = UIKit.PROFIT
		elif _active and level == _level + 1:
			col = UIKit.GOLD
		else:
			col = Color(0.3, 0.25, 0.42, 0.5)
		var bg := Color(0.08, 0.2, 0.13) if (_active and level <= _level) else Color(0.1, 0.08, 0.14)
		row.add_theme_stylebox_override("panel", UIKit.box(bg, col, 6, 2 if level == _level + 1 and _active else 1, 3))
		_row_labels[i].add_theme_color_override("font_color", UIKit.INK if (_active and level <= _level + 1) else UIKit.MUTED)
	_enter_btn.disabled = _active
	_recruit_btn.disabled = not _active or _level >= LEVELS.size()
	_cash_btn.disabled = not _active or _level == 0
	_cash_btn.text = "SACAR %s" % NumberFormatter.format_number(_bet * mult(_level)) if (_active and _level > 0) else "SACAR"


func _on_enter() -> void:
	if _active:
		return
	_bet = take_bet()
	if _bet <= 0.0:
		return
	set_busy(true)
	_active = true
	_level = 0
	_result.text = ""
	show_result(_result, "Bem-vindo à família! Agora recrute.", UIKit.GOLD_LIGHT)
	_refresh()


func _on_recruit() -> void:
	if not _active or _recruiting or _level >= LEVELS.size():
		return
	_recruiting = true
	_recruit_btn.disabled = true
	_cash_btn.disabled = true
	menu.emit_sfx("click")
	await wait(0.35)
	_recruiting = false
	if randf() < SUCCESS:
		_level += 1
		UIKit.pop(_rows[_level - 1], 1.1, 0.2)
		if _level >= LEVELS.size():
			GameManager.unlock_achievement("bet_pyramid_top")
			show_result(_result, "TOPO DA PIRÂMIDE! Alguém lá embaixo vai pagar por isso.", UIKit.GOLD)
			_refresh()
			await wait(0.6)
			_on_cash()
			return
		show_result(_result, "Recrutou %s! Agora vale x%.2f" % [LEVELS[_level - 1], mult(_level)], UIKit.PROFIT)
	else:
		var victims := LEVELS[_level] if _level < LEVELS.size() else "todos"
		for r in _rows:
			UIKit.shake(r, 8.0, 0.35)
		settle(_bet, 0.0)
		show_result(_result, "A pirâmide DESABOU. %s pediram reembolso. -%s" % [victims,NumberFormatter.format_number(_bet)], UIKit.RISK)
		_active = false
		_level = 0
		await wait(0.9)
		set_busy(false)
	_refresh()


func _on_cash() -> void:
	if not _active or _recruiting or _level == 0:
		return
	var paid := settle(_bet, _bet * mult(_level))
	show_result(_result, "Saiu antes do colapso no nível %d! +%s" % [_level, NumberFormatter.format_number(paid - _bet)], UIKit.PROFIT)
	_active = false
	_level = 0
	_refresh()
	set_busy(false)
