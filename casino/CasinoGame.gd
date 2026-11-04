class_name CasinoGame
extends VBoxContainer
## Base de todo minigame do cassino.
## Cada jogo só precisa: montar a UI em build(), chamar take_bet() para debitar e
## settle() para pagar. Débito, estatísticas, conquistas, partículas, som e o
## comentário do Jeff Meowzos são responsabilidade do BetsMenu/GameManager.

var menu: BetsMenu
var _busy: bool = false


func game_id() -> String:
	return "base"


func tab_title() -> String:
	return "Jogo"


## Chave de fala do Meowzos ao abrir a aba.
func intro_key() -> String:
	return ""


## Linha curta exibida sob o título com as regras/pagamentos.
func rules_text() -> String:
	return ""


func build() -> void:
	pass


func on_shown() -> void:
	pass


func is_busy() -> bool:
	return _busy


func set_busy(value: bool) -> void:
	_busy = value
	if menu:
		menu.refresh_lock()


## Debita a aposta atual. Retorna o valor apostado ou 0 se não houver saldo.
func take_bet(amount: float = -1.0) -> float:
	return menu.request_bet(self, amount)


## Paga `payout` bruto (0 = perdeu). Retorna o valor creditado.
func settle(bet: float, payout: float) -> float:
	return menu.settle(self, bet, payout)


# ── Helpers de UI compartilhados ──

func header(text: String) -> HBoxContainer:
	var h := UIKit.hbox(8)
	h.add_child(UIKit.title(text, 18, UIKit.GOLD))
	h.add_child(UIKit.spacer())
	var r := UIKit.label(rules_text(), 11, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	return h


func big_button(text: String, kind: String = "gold") -> Button:
	var b := UIKit.button(text, kind, 16, Vector2(0, 46))
	b.add_theme_font_override("font", UIKit.display_font())
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func result_label() -> Label:
	var l := UIKit.title("", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size = Vector2(0, 26)
	return l


func show_result(l: Label, text: String, color: Color) -> void:
	l.text = text
	l.add_theme_color_override("font_color", color)
	UIKit.pop(l, 1.15, 0.25)


func wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout
