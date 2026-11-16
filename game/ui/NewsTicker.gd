class_name NewsTicker
extends PanelContainer
## "JORNAL DO CAPITAL" — faixa de manchetes satíricas rolando, estilo canal de notícias.
## Algumas manchetes são dinâmicas e comentam o estado do império do jogador.

const SPEED: float = 70.0

var _clip: Control
var _label: Label
var _x: float = 0.0
var _queue: Array[String] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.04, 0.08, 0.88), UIKit.GOLD_DARK, 6, 1))
	custom_minimum_size = Vector2(0, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var h := UIKit.hbox(0)
	add_child(h)

	var tag := UIKit.panel(UIKit.box(Color("#B3261E"), Color(0, 0, 0, 0), 5, 0, 0))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_m := UIKit.margin(4)
	tag_m.add_theme_constant_override("margin_left", 10)
	tag_m.add_theme_constant_override("margin_right", 10)
	tag.add_child(tag_m)
	tag_m.add_child(UIKit.title("JORNAL DO CAPITAL", 12, Color.WHITE))
	h.add_child(tag)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_clip)

	_label = UIKit.ticker("", 13, Color("#F2E6C2"))
	_clip.add_child(_label)
	_next_headline()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_x -= SPEED * delta
	_label.position = Vector2(_x, (_clip.size.y - _label.size.y) * 0.5)
	if _x + _label.size.x < 0.0:
		_next_headline()


func _next_headline() -> void:
	if _queue.is_empty():
		_queue.assign(GameData.HEADLINES.duplicate())
		_queue.shuffle()
	var text: String = _dynamic_headline() if randf() < 0.3 else _queue.pop_back()
	_label.text = "   ●   " + text
	_label.reset_size()
	_x = maxf(_clip.size.x, 400.0)


func _dynamic_headline() -> String:
	var gm := GameManager
	var options: Array[String] = []
	var mb: int = int(gm.buildings[0]["count"])
	if mb > 0:
		options.append("%d Mini Beans assinam contrato de 'parceria' sem carteira assinada. 'É empreendedorismo', diz RH." % mb)
	if gm.cps > 0.0:
		options.append("Império do jogador fatura %s/s. Estagiários recebem um adesivo de 'Colaborador do Mês'." % NumberFormatter.format_cps(gm.cps))
	if Meowzos.loan_active:
		options.append("Dívida do jogador com Jeff Meowzos chega a %s. Agiota nega ser agiota: 'sou fintech'." % NumberFormatter.format_number(Meowzos.loan_debt))
	if gm.bets_net_result < -1000.0:
		options.append("Cassino agradece contribuição de %s do jogador para a reforma do lustre de ouro." % NumberFormatter.format_number(-gm.bets_net_result))
	elif gm.bets_net_result > 1000.0:
		options.append("Jogador lucra %s no cassino. Jeff Meowzos instala 3 novas máquinas 'só por precaução'." % NumberFormatter.format_number(gm.bets_net_result))
	if gm.prestige_count > 0:
		options.append("'%s' declara falência pela %dª vez e é capa da revista Empreendedor de Sucesso." % [gm.get_ceo_title(), gm.prestige_count])
	if options.is_empty():
		return GameData.HEADLINES[randi() % GameData.HEADLINES.size()]
	return options[randi() % options.size()]
