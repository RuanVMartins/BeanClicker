class_name PrestigeScreen
extends Control
## FALÊNCIA DECLARADA — tela de prestígio.
## Esquerda: o "pedido de falência" (documento jurídico com carimbo).
## Direita: loja de Benefícios Executivos, pagos com Fundos Offshore.

signal bankrupted(report: Dictionary)

var _overlay: ColorRect
var _doc_lines: VBoxContainer
var _sign_btn: Button
var _progress: ProgressBar
var _progress_label: Label
var _bank_label: Label
var _perk_rows: Array[Dictionary] = []
var _stamp: Label
var _confirm_armed: bool = false
var _paper: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := UIKit.modal(self, Vector2(900, 540), UIKit.RISK)
	_overlay = parts[0]
	var panel: PanelContainer = parts[1]

	var root := UIKit.vbox(10)
	panel.add_child(root)

	var head := UIKit.hbox(8)
	root.add_child(head)
	head.add_child(UIKit.title("FALÊNCIA DECLARADA", 26, UIKit.RISK))
	head.add_child(UIKit.spacer())
	var close := UIKit.button("✕", "ghost", 16, Vector2(36, 32))
	close.pressed.connect(close_screen)
	head.add_child(close)
	root.add_child(UIKit.wrap_label("Quebre a empresa, perdoe as dívidas, desvie o lucro e volte como um CEO mais agressivo. É legal? Tecnicamente.", 13, UIKit.MUTED))

	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# ── Documento ──
	_paper = UIKit.panel(UIKit.shadowed(UIKit.box(Color("#EFE6D0"), Color("#8C7A55"), 4, 1, 18), 10, 0.5))
	_paper.custom_minimum_size = Vector2(400, 0)
	cols.add_child(_paper)
	var doc := UIKit.vbox(6)
	_paper.add_child(doc)
	doc.add_child(UIKit.title("PEDIDO DE FALÊNCIA Nº %s" % str(randi_range(1000, 9999)), 16, Color("#3B2A12"), HORIZONTAL_ALIGNMENT_CENTER))
	doc.add_child(UIKit.label("Tribunal de Pequenas Causas Felinas — Vara do Capital", 10, Color("#6B5A3A"), HORIZONTAL_ALIGNMENT_CENTER))
	var sep := HSeparator.new()
	sep.modulate = Color(0.3, 0.2, 0.1, 0.6)
	doc.add_child(sep)
	_doc_lines = UIKit.vbox(5)
	doc.add_child(_doc_lines)
	doc.add_child(UIKit.spacer(false))
	_progress_label = UIKit.label("", 11, Color("#4A3A1E"))
	doc.add_child(_progress_label)
	_progress = UIKit.progress(8, Color("#B3261E"))
	doc.add_child(_progress)
	_sign_btn = UIKit.button("", "danger", 16, Vector2(0, 46))
	_sign_btn.pressed.connect(_on_sign_pressed)
	doc.add_child(_sign_btn)

	_stamp = UIKit.title("FALIDO", 64, Color(0.75, 0.1, 0.1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_stamp.visible = false
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp.rotation = -0.3
	_paper.add_child(_stamp)

	# ── Benefícios Executivos ──
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rh := UIKit.hbox(6)
	right.add_child(rh)
	rh.add_child(UIKit.title("BENEFÍCIOS EXECUTIVOS", 16, UIKit.CYAN))
	rh.add_child(UIKit.spacer())
	_bank_label = UIKit.title("", 15, UIKit.GOLD)
	rh.add_child(_bank_label)
	right.add_child(UIKit.label("Comprados com Fundos Offshore. Permanentes. Imorais.", 11, UIKit.MUTED))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for p in GameData.CEO_PERKS:
		list.add_child(_create_perk_row(p))

	GameManager.perks_changed.connect(_refresh)


func _create_perk_row(def: Dictionary) -> PanelContainer:
	var row := UIKit.panel(UIKit.box(Color(0.1, 0.085, 0.15), Color(0.3, 0.25, 0.42, 0.6), 8, 1, 8))
	var h := UIKit.hbox(10)
	row.add_child(h)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(def["name"], 14, UIKit.INK))
	v.add_child(UIKit.wrap_label(def["effect"], 11, UIKit.PROFIT))
	v.add_child(UIKit.wrap_label("\"%s\"" % def["flavor"], 10, UIKit.DIM))
	var btn := UIKit.button("", "purple", 12, Vector2(92, 36))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		if GameManager.buy_perk(def["id"]):
			UIKit.pop(row, 1.04)
			Meowzos.say("'%s'? Excelente escolha. Ninguém vai investigar. Provavelmente." % def["name"], "smug"))
	h.add_child(btn)
	_perk_rows.append({"id": def["id"], "cost": def["cost"], "btn": btn, "row": row})
	return row


func open() -> void:
	_confirm_armed = false
	_stamp.visible = false
	_refresh()
	_is_open = true
	_overlay.visible = true
	if _overlay.modulate.a > 0.99:
		_overlay.modulate.a = 0.0
	_fade_to(1.0, 0.2, false)


func close_screen() -> void:
	_is_open = false
	_fade_to(0.0, 0.15, true)


func is_open() -> bool:
	return _is_open

# Fechar e reabrir rápido não pode deixar o tween de fechar esconder a janela reaberta
var _is_open: bool = false
var _fade: Tween


func _fade_to(alpha: float, time: float, hide_after: bool) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_overlay, "modulate:a", alpha, time)
	if hide_after:
		_fade.tween_callback(func():
			if not _is_open:
				_overlay.visible = false)



func _process(_delta: float) -> void:
	if _is_open:
		_progress.value = GameManager.get_next_fund_progress()


func _refresh() -> void:
	var gm := GameManager
	var gain := gm.calculate_prestige_gain()
	for c in _doc_lines.get_children():
		c.queue_free()
	var ink := Color("#2B1D0A")
	var new_total := gm.offshore_total + gain
	var bonus_now := gm.get_prestige_multiplier()
	var bonus_after := (1.0 + new_total * GameData.PRESTIGE_PER_FUND) * (1.0 + (gm.prestige_count + 1) * GameData.PRESTIGE_PER_BANKRUPTCY)
	var lines: Array = [
		["Requerente:", "%s (falência nº %d)" % [gm.get_ceo_title(), gm.prestige_count + 1]],
		["Novo título:", gm.get_ceo_title(gm.prestige_count + 1)],
		["Caixa a 'liquidar':", NumberFormatter.format_number(gm.coins) + " moedas"],
		["Estruturas sacrificadas:", "%d unidades" % gm.get_total_buildings()],
		["Dívidas com agiota:", ("PERDOADAS (%s)" % NumberFormatter.format_number(Meowzos.loan_debt)) if Meowzos.loan_active else "nenhuma"],
		["Desviado p/ offshore:", "+%d Fundos" % gain],
		["Multiplicador de CPS:", "x%.2f  →  x%.2f" % [bonus_now, bonus_after]],
	]
	for l in lines:
		var h := UIKit.hbox(6)
		var k := UIKit.label(l[0], 12, Color("#6B5A3A"))
		k.custom_minimum_size = Vector2(150, 0)
		h.add_child(k)
		var val := UIKit.label(l[1], 12, ink)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(val)
		_doc_lines.add_child(h)
	if gm.has_perk("paraquedas"):
		_doc_lines.add_child(UIKit.label("Cláusula Paraquedas Dourado: 10% das estruturas preservadas.", 11, Color("#1E6B3A")))

	var lvl := int(floor(sqrt(gm.lifetime_earned / GameData.PRESTIGE_BASE)))
	var next_at := pow(float(lvl + 1), 2.0) * GameData.PRESTIGE_BASE
	_progress_label.text = "Próximo Fundo Offshore em %s produzidos (histórico: %s)" % [
		NumberFormatter.format_number(next_at), NumberFormatter.format_number(gm.lifetime_earned)]

	_confirm_armed = false
	if gain > 0:
		_sign_btn.disabled = false
		_sign_btn.text = "ASSINAR COM A PATA  (+%d Fundos)" % gain
	else:
		_sign_btn.disabled = true
		_sign_btn.text = "Você ainda é pobre demais para falir"

	_bank_label.text = "%d Fundos" % gm.offshore_bank
	for r in _perk_rows:
		var btn: Button = r["btn"]
		var owned := gm.has_perk(r["id"])
		if owned:
			btn.text = "ADQUIRIDO"
			btn.disabled = true
			(r["row"] as PanelContainer).modulate = Color(0.75, 1.0, 0.85)
		else:
			btn.text = "%d Fundo%s" % [r["cost"], "s" if int(r["cost"]) > 1 else ""]
			btn.disabled = gm.offshore_bank < int(r["cost"])
			(r["row"] as PanelContainer).modulate = Color.WHITE


func _on_sign_pressed() -> void:
	if not _confirm_armed:
		_confirm_armed = true
		_sign_btn.text = "CERTEZA? Clique de novo para quebrar tudo"
		UIKit.shake(_sign_btn, 4.0, 0.25)
		return
	var report := GameManager.do_prestige()
	if report.is_empty():
		return
	_stamp.visible = true
	_stamp.scale = Vector2(3, 3)
	_stamp.modulate.a = 0.0
	_stamp.pivot_offset = _stamp.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_stamp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.15)
	UIKit.shake(_paper, 10.0, 0.35)
	Meowzos.say_key("prestige", {}, "shock")
	bankrupted.emit(report)
	await get_tree().create_timer(1.1).timeout
	_refresh()
	_stamp.visible = true
