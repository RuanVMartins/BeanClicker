class_name SaveSystem
extends RefCounted
## Persistência em JSON com versionamento e migração de saves antigos (v2 → v3).

const SAVE_VERSION: int = 3
static var save_path: String = "user://beanclicker_save.json"


## Busca autoloads pela árvore (e não pelo identificador global) para que este
## script compile em qualquer contexto, inclusive ferramentas e testes.
static func _node(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node(autoload_name)


static func save_game() -> bool:
	var gm = _node("GameManager")
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"coins": gm.coins,
		"lifetime_earned": gm.lifetime_earned,
		"run_earned": gm.run_earned,
		"offshore_total": gm.offshore_total,
		"offshore_bank": gm.offshore_bank,
		"prestige_count": gm.prestige_count,
		"perks": gm.perks.keys(),
		"bets_unlocked": gm.bets_unlocked,
		"bets_total_count": gm.bets_total_count,
		"bets_total_wagered": gm.bets_total_wagered,
		"bets_net_result": gm.bets_net_result,
		"bets_highest_win": gm.bets_highest_win,
		"bailout_timer": gm.bailout_timer,
		"total_clicks": gm.total_clicks,
		"play_time": gm.play_time,
		"tutorial_step": gm.tutorial_step,
		"tutorial_done": gm.tutorial_done,
		"buildings": {},
		"upgrades": [],
		"achievements": [],
		"meowzos": _node("Meowzos").to_save(),
		"fishing": _node("Fishing").to_save(),
	}
	for b in gm.buildings:
		data["buildings"][b["id"]] = int(b["count"])
	for u in gm.upgrades:
		if u["purchased"]:
			data["upgrades"].append(u["id"])
	for id in gm.achievements:
		if gm.achievements[id]:
			data["achievements"].append(id)

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_warning("SaveSystem: não foi possível gravar em %s" % save_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	gm.last_save_unix = data["saved_at"]
	return true


static func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK or not json.data is Dictionary:
		push_warning("SaveSystem: save corrompido, ignorando.")
		return false

	var d: Dictionary = json.data
	if int(d.get("version", 1)) < 3:
		d = _migrate_v2(d)

	var gm = _node("GameManager")
	gm.coins = float(d.get("coins", 0.0))
	gm.lifetime_earned = float(d.get("lifetime_earned", 0.0))
	gm.run_earned = float(d.get("run_earned", 0.0))
	gm.offshore_total = int(d.get("offshore_total", 0))
	gm.offshore_bank = int(d.get("offshore_bank", 0))
	gm.prestige_count = int(d.get("prestige_count", 0))
	gm.bets_unlocked = bool(d.get("bets_unlocked", false))
	gm.bets_total_count = int(d.get("bets_total_count", 0))
	gm.bets_total_wagered = float(d.get("bets_total_wagered", 0.0))
	gm.bets_net_result = float(d.get("bets_net_result", 0.0))
	gm.bets_highest_win = float(d.get("bets_highest_win", 0.0))
	gm.bailout_timer = float(d.get("bailout_timer", 0.0))
	gm.total_clicks = int(d.get("total_clicks", 0))
	gm.play_time = float(d.get("play_time", 0.0))
	gm.last_save_unix = float(d.get("saved_at", 0.0))
	gm.tutorial_step = int(d.get("tutorial_step", 0))
	# Saves de antes do tutorial: quem já jogou um pouco não é obrigado a refazer o básico
	gm.tutorial_done = bool(d.get("tutorial_done", gm.lifetime_earned > 5000.0))

	gm.perks.clear()
	for p in d.get("perks", []):
		gm.perks[str(p)] = true

	var saved_b: Dictionary = d.get("buildings", {})
	for b in gm.buildings:
		b["count"] = int(saved_b.get(b["id"], 0))

	var saved_u: Array = d.get("upgrades", [])
	for u in gm.upgrades:
		u["purchased"] = saved_u.has(u["id"])

	for a in d.get("achievements", []):
		if gm.achievements.has(str(a)):
			gm.achievements[str(a)] = true

	var gat = d.get("meowzos", d.get("gatuno", {}))
	if gat is Dictionary:
		_node("Meowzos").from_save(gat)

	var fish = d.get("fishing", {})
	if fish is Dictionary:
		_node("Fishing").from_save(fish)

	gm.recalculate()
	return true


## Converte o formato v2 (arrays de {id,count}, Grãos Celestiais) para v3.
static func _migrate_v2(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var chips := int(d.get("heavenly_chips", 0))
	out["offshore_total"] = chips
	out["offshore_bank"] = chips   # Grãos antigos viram Fundos gastáveis
	out["lifetime_earned"] = float(d.get("total_cookies_all_time", 0.0))
	out["bets_net_result"] = float(d.get("bets_total_won", 0.0))

	var b_dict := {}
	for sb in d.get("buildings", []):
		if sb is Dictionary:
			b_dict[str(sb.get("id", ""))] = int(sb.get("count", 0))
	out["buildings"] = b_dict

	var u_list: Array = []
	for su in d.get("upgrades", []):
		if su is Dictionary and bool(su.get("purchased", false)):
			u_list.append(str(su.get("id", "")))
	out["upgrades"] = u_list

	var a_list: Array = []
	var ach = d.get("achievements", {})
	if ach is Dictionary:
		for id in ach:
			if bool(ach[id]):
				a_list.append(id)
	out["achievements"] = a_list
	out["saved_at"] = 0.0   # sem renda offline na migração
	return out
