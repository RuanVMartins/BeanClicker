class_name AchievementsPanel
extends Control
## Conquistas + estatísticas ("Relatório Anual aos Acionistas").

var _overlay: ColorRect
var _grid: GridContainer
var _stats: VBoxContainer
var _header: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := UIKit.modal(self, Vector2(860, 520), UIKit.GOLD)
	_overlay = parts[0]
	var panel: PanelContainer = parts[1]
	var root := UIKit.vbox(10)
	panel.add_child(root)

	var head := UIKit.hbox(8)
	root.add_child(head)
	head.add_child(UIKit.title("RELATÓRIO AOS ACIONISTAS", 24, UIKit.GOLD))
	head.add_child(UIKit.spacer())
	var close := UIKit.button("✕", "ghost", 16, Vector2(36, 32))
	close.pressed.connect(func(): _overlay.visible = false)
	head.add_child(close)

	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	_header = UIKit.label("", 13, UIKit.CYAN)
	left.add_child(_header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	var right := UIKit.panel(UIKit.box(UIKit.FELT, Color(0.35, 0.3, 0.48, 0.6), 10, 1, 12))
	right.custom_minimum_size = Vector2(270, 0)
	cols.add_child(right)
	_stats = UIKit.vbox(5)
	right.add_child(_stats)


func open() -> void:
	_refresh()
	_overlay.visible = true


func is_open() -> bool:
	return _overlay.visible


func close_screen() -> void:
	_overlay.visible = false


func _refresh() -> void:
	var gm := GameManager
	for c in _grid.get_children():
		c.queue_free()
	for id in GameData.ACHIEVEMENTS:
		var def: Dictionary = GameData.ACHIEVEMENTS[id]
		var got: bool = gm.achievements.get(id, false)
		var card := UIKit.panel(UIKit.box(Color(0.14, 0.11, 0.06) if got else Color(0.08, 0.07, 0.11), UIKit.GOLD if got else Color(0.25, 0.2, 0.32, 0.6), 8, 1, 8))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UIKit.vbox(1)
		card.add_child(v)
		v.add_child(UIKit.label(("★ " if got else "☆ ") + (str(def["name"]) if got else "???"), 13, UIKit.GOLD_LIGHT if got else UIKit.DIM))
		v.add_child(UIKit.wrap_label(def["desc"], 11, UIKit.MUTED if got else Color(0.4, 0.37, 0.5)))
		_grid.add_child(card)
	_header.text = "Conquistas: %d / %d   (+%d%% de produção — 'Prestígio de LinkedIn')" % [
		gm.get_unlocked_achievement_count(), GameData.ACHIEVEMENTS.size(), gm.get_unlocked_achievement_count()]

	for c in _stats.get_children():
		c.queue_free()
	_stats.add_child(UIKit.title("BALANÇO", 16, UIKit.GOLD))
	var rows: Array = [
		["Cargo", gm.get_ceo_title()],
		["Produção histórica", NumberFormatter.format_number(gm.lifetime_earned)],
		["Produção nesta carreira", NumberFormatter.format_number(gm.run_earned)],
		["Renda passiva", NumberFormatter.format_cps(gm.cps) + "/s"],
		["Valor do clique", NumberFormatter.format_number(gm.get_click_value())],
		["Cliques", NumberFormatter.format_number(gm.total_clicks)],
		["Estruturas", str(gm.get_total_buildings())],
		["Falências", str(gm.prestige_count)],
		["Fundos Offshore", "%d (%d livres)" % [gm.offshore_total, gm.offshore_bank]],
		["Mult. prestígio", "x%.2f" % gm.get_prestige_multiplier()],
		["Apostas feitas", NumberFormatter.format_number(gm.bets_total_count)],
		["Total apostado", NumberFormatter.format_number(gm.bets_total_wagered)],
		["Resultado no cassino", ("+" if gm.bets_net_result >= 0.0 else "") + NumberFormatter.format_number(gm.bets_net_result)],
		["Maior prêmio", NumberFormatter.format_number(gm.bets_highest_win)],
		["Empréstimos / calotes", "%d / %d" % [Meowzos.loans_taken, Meowzos.loans_defaulted]],
		["Peixes pescados / vendidos", "%d / %d" % [Fishing.total_caught, Fishing.total_sold]],
		["Peixes corporativos", str(Fishing.legendary_caught)],
		["Tempo de jogo", NumberFormatter.format_time(gm.play_time)],
	]
	for r in rows:
		var h := UIKit.hbox(4)
		h.add_child(UIKit.label(r[0], 12, UIKit.MUTED))
		h.add_child(UIKit.spacer())
		var val := UIKit.label(r[1], 12, UIKit.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		if r[0] == "Resultado no cassino":
			val.add_theme_color_override("font_color", UIKit.PROFIT if gm.bets_net_result >= 0.0 else UIKit.RISK)
		h.add_child(val)
		_stats.add_child(h)
