extends Node
## Gerenciador central do estado econômico do jogo.
## Autoload registrado como "GameManager".
##
## Regras de ouro da economia:
##  - Só renda PRODUTIVA (clique, CPS, offline) conta para a Falência (prestígio).
##    Dinheiro de aposta move o saldo, mas não o histórico — senão o cassino vira
##    uma impressora de Fundos Offshore (exploit da versão anterior).
##  - Toda transação de aposta passa por place_bet()/settle_bet(), para que
##    estatísticas, conquistas e o Jeff Meowzos vejam tudo.

const SaveScript = preload("res://SaveSystem.gd")

# ══════════════════════════════════════
# SINAIS
# ══════════════════════════════════════
signal coins_changed(new_amount: float)
signal cps_changed(new_cps: float)
signal building_changed(index: int)
signal buildings_reset
signal upgrade_changed(index: int)
signal prestige_changed
signal perks_changed
signal rainbow_activated
signal achievement_unlocked(id: String, name: String, desc: String)
signal bets_unlocked_changed(is_unlocked: bool)
signal bet_settled(game_id: String, bet: float, payout: float, net: float)
signal bailout_paid(amount: float)

const TICK_INTERVAL: float = 0.1
const AUTOSAVE_INTERVAL: float = 30.0
const BETS_UPGRADE_COST: float = 1000.0
const BAILOUT_COOLDOWN: float = 600.0
const REPOSSESSION_RATE: float = 0.5   # Penhora avalia cada estrutura em 50% do preço

# ══════════════════════════════════════
# ESTADO
# ══════════════════════════════════════
var coins: float = 0.0:
	set(value):
		coins = maxf(0.0, value)
		coins_changed.emit(coins)

var lifetime_earned: float = 0.0   # Produção histórica (nunca reseta) — base da Falência
var run_earned: float = 0.0        # Produção nesta carreira
var click_power: float = 1.0
var click_cps_percent: float = 0.0
var cps: float = 0.0
var global_multiplier: float = 1.0
var rainbow_active: bool = false

var buildings: Array[Dictionary] = []
var upgrades: Array[Dictionary] = []

# Falência / Prestígio
var offshore_total: int = 0        # Fundos Offshore históricos (dão bônus de CPS)
var offshore_bank: int = 0         # Fundos não gastos (moeda dos Benefícios de CEO)
var prestige_count: int = 0
var perks: Dictionary = {}         # perk_id -> true

# Conquistas
var achievements: Dictionary = {}  # id -> bool

# Cassino
var bets_unlocked: bool = false
var bets_total_count: int = 0
var bets_total_wagered: float = 0.0
var bets_net_result: float = 0.0
var bets_highest_win: float = 0.0
var bailout_timer: float = 0.0

# Estatísticas gerais
var total_clicks: int = 0
var play_time: float = 0.0
var last_save_unix: float = 0.0

# Relatório de renda offline pendente (a UI consome e zera)
var pending_offline_report: Dictionary = {}

var _booted: bool = false
var _tick_accum: float = 0.0
var _autosave_accum: float = 0.0


# ╔══════════════════════════════════════╗
# ║             BOOT                     ║
# ╚══════════════════════════════════════╝
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_buildings()
	_init_upgrades()
	for id in GameData.ACHIEVEMENTS.keys():
		achievements[id] = false


## Carrega o save e calcula renda offline. Idempotente; chamado pela cena principal
## depois que todos os autoloads (incluindo o Meowzos) existem.
func boot() -> void:
	if _booted:
		return
	_booted = true
	SaveScript.load_game()
	recalculate()
	_compute_offline_income()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _booted:
			SaveScript.save_game()


func _process(delta: float) -> void:
	if not _booted:
		return
	play_time += delta
	if bailout_timer > 0.0:
		bailout_timer = maxf(0.0, bailout_timer - delta)

	_tick_accum += delta
	if _tick_accum >= TICK_INTERVAL:
		if cps > 0.0:
			earn(cps * _tick_accum)
		_tick_accum = 0.0

	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL:
		_autosave_accum = 0.0
		SaveScript.save_game()


func _init_buildings() -> void:
	buildings.clear()
	for def in GameData.BUILDINGS:
		var b: Dictionary = def.duplicate()
		b["count"] = 0
		buildings.append(b)


func _init_upgrades() -> void:
	upgrades.clear()
	for def in GameData.SPECIAL_UPGRADES:
		var u: Dictionary = def.duplicate()
		u["purchased"] = false
		upgrades.append(u)

	# Upgrades de estrutura gerados a partir das tabelas (4 tiers x 8 estruturas)
	for def in GameData.BUILDINGS:
		var bid: String = def["id"]
		var prefix: String = GameData.BUILDING_UPGRADE_PREFIX[bid]
		var texts: Array = GameData.BUILDING_UPGRADE_TEXT[bid]
		for tier in range(GameData.BUILDING_UPGRADE_TIERS.size()):
			upgrades.append({
				"id": "%s_%d" % [prefix, tier + 1],
				"name": texts[tier][0],
				"desc": texts[tier][1],
				"short_effect": "%s produz 2x mais" % def["name"],
				"icon": def["icon"],
				"price": float(def["base_price"]) * GameData.BUILDING_UPGRADE_PRICE_MULT[tier],
				"type": "building_mult",
				"target": bid,
				"value": 2.0,
				"req_building": bid,
				"req_count": GameData.BUILDING_UPGRADE_TIERS[tier],
				"purchased": false,
			})
	# Ordena por preço: a loja fica legível sem lógica extra na UI
	upgrades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["price"]) < float(b["price"]))


# ╔══════════════════════════════════════╗
# ║          MOEDAS                      ║
# ╚══════════════════════════════════════╝

## Renda produtiva: conta para o histórico de Falência.
func earn(amount: float) -> void:
	if amount <= 0.0:
		return
	run_earned += amount
	var before := lifetime_earned
	lifetime_earned += amount
	coins += amount
	if before < 1e6 and lifetime_earned >= 1e6:
		unlock_achievement("earn_1m")
	if before < 1e9 and lifetime_earned >= 1e9:
		unlock_achievement("earn_1b")


## Gasto: falha se não houver saldo.
func spend(amount: float) -> bool:
	if amount <= 0.0 or coins + 0.0001 < amount:
		return false
	coins -= amount
	return true


## Movimentação não produtiva (empréstimos, cassino): mexe no saldo, não no histórico.
func add_coins(amount: float) -> void:
	coins += amount


func get_coins() -> float:
	return coins


func click() -> float:
	var value := get_click_value()
	total_clicks += 1
	earn(value)
	return value


# ╔══════════════════════════════════════╗
# ║          ESTRUTURAS                  ║
# ╚══════════════════════════════════════╝

func _building_discount() -> float:
	return 0.9 if has_perk("demissao") else 1.0


func get_building_price(index: int) -> float:
	return get_bulk_price(index, 1)


## Preço de comprar `amount` unidades de uma vez (soma da PG 1.15^n).
func get_bulk_price(index: int, amount: int) -> float:
	var b: Dictionary = buildings[index]
	var base: float = float(b["base_price"]) * pow(1.15, float(b["count"]))
	var total: float = base * (pow(1.15, float(amount)) - 1.0) / 0.15
	return ceil(total * _building_discount())


## Quantas unidades cabem no saldo atual (para o modo "MAX").
func get_max_affordable(index: int) -> int:
	var b: Dictionary = buildings[index]
	var base: float = float(b["base_price"]) * pow(1.15, float(b["count"])) * _building_discount()
	if coins < base:
		return 0
	var n: int = int(floor(log(coins * 0.15 / base + 1.0) / log(1.15)))
	while n > 0 and get_bulk_price(index, n) > coins:
		n -= 1
	return n


func get_building_cps_per_unit(index: int) -> float:
	var b: Dictionary = buildings[index]
	var mult: float = 1.0
	for u in upgrades:
		if u["purchased"] and u["type"] == "building_mult" and u.get("target", "") == b["id"]:
			mult *= float(u["value"])
	return float(b["base_cps"]) * mult * get_production_multiplier()


func get_building_cps_final(index: int) -> float:
	return get_building_cps_per_unit(index) * float(buildings[index]["count"])


func get_total_buildings() -> int:
	var total := 0
	for b in buildings:
		total += int(b["count"])
	return total


## Compra `amount` unidades (ou o máximo possível se amount <= 0). Retorna quantas comprou.
func buy_building(index: int, amount: int = 1) -> int:
	var n: int = amount if amount > 0 else get_max_affordable(index)
	if n <= 0:
		return 0
	var price := get_bulk_price(index, n)
	if not spend(price):
		return 0
	buildings[index]["count"] += n
	recalculate()
	building_changed.emit(index)
	_check_building_achievements()
	return n


func _check_building_achievements() -> void:
	var total := get_total_buildings()
	for threshold in [20, 40, 60, 80, 100, 200]:
		if total >= threshold:
			unlock_achievement("count_%d" % threshold)


## Penhora estruturas até cobrir `value` moedas. Leva as mais caras primeiro.
## Limites (para a penhora doer sem travar o jogo):
##  - Mini Beans são impenhoráveis: "bem de família" — afinal, "aqui somos uma família".
##  - Sempre sobram 25% de cada estrutura. O que não couber vira calote perdoado.
## Retorna {"recovered": float, "taken": {name: count}}.
func repossess_buildings(value: float) -> Dictionary:
	var remaining := value
	var taken: Dictionary = {}
	for i in range(buildings.size() - 1, 0, -1):
		var floor_count: int = int(ceil(int(buildings[i]["count"]) * 0.25))
		while remaining > 0.0 and int(buildings[i]["count"]) > floor_count:
			buildings[i]["count"] -= 1
			var unit_value: float = float(buildings[i]["base_price"]) * pow(1.15, float(buildings[i]["count"])) * REPOSSESSION_RATE
			remaining -= unit_value
			var bname: String = buildings[i]["name"]
			taken[bname] = int(taken.get(bname, 0)) + 1
	recalculate()
	buildings_reset.emit()
	return {"recovered": value - maxf(remaining, 0.0), "taken": taken}


# ╔══════════════════════════════════════╗
# ║          UPGRADES                    ║
# ╚══════════════════════════════════════╝

func get_upgrade_price(index: int) -> float:
	var mult := 0.75 if has_perk("monopolio") else 1.0
	return ceil(float(upgrades[index]["price"]) * mult)


func is_upgrade_visible(index: int) -> bool:
	var u: Dictionary = upgrades[index]
	if u["purchased"]:
		return false
	var req_id: String = str(u["req_building"])
	for b in buildings:
		if b["id"] == req_id:
			return int(b["count"]) >= int(u["req_count"])
	return false


func buy_upgrade(index: int) -> bool:
	var u: Dictionary = upgrades[index]
	if u["purchased"] or not is_upgrade_visible(index):
		return false
	if not spend(get_upgrade_price(index)):
		return false
	u["purchased"] = true
	recalculate()
	upgrade_changed.emit(index)
	if str(u["type"]).begins_with("click"):
		unlock_achievement("up_click")
	if u.get("rainbow", false):
		rainbow_active = true
		rainbow_activated.emit()
		unlock_achievement("up_rainbow")
	return true


# ╔══════════════════════════════════════╗
# ║          MULTIPLICADORES & CPS       ║
# ╚══════════════════════════════════════╝

## Multiplicador de prestígio: Fundos Offshore + número de falências.
func get_prestige_multiplier() -> float:
	return (1.0 + offshore_total * GameData.PRESTIGE_PER_FUND) * (1.0 + prestige_count * GameData.PRESTIGE_PER_BANKRUPTCY)


func get_achievement_multiplier() -> float:
	return 1.0 + get_unlocked_achievement_count() * GameData.ACHIEVEMENT_BONUS


## Tudo que multiplica produção, exceto upgrades de estrutura.
func get_production_multiplier() -> float:
	var perk_mult := 1.25 if has_perk("lobby") else 1.0
	return global_multiplier * get_prestige_multiplier() * get_achievement_multiplier() * perk_mult


func recalculate() -> void:
	click_power = 1.0
	click_cps_percent = 0.03 if has_perk("dedo_ceo") else 0.0
	global_multiplier = 1.0
	rainbow_active = false
	for u in upgrades:
		if not u["purchased"]:
			continue
		match str(u["type"]):
			"click_flat":
				click_power += float(u["value"])
			"click_percent":
				click_cps_percent += float(u["value"])
			"global_mult":
				global_multiplier *= float(u["value"])
				if u.get("rainbow", false):
					rainbow_active = true

	cps = 0.0
	for i in range(buildings.size()):
		cps += get_building_cps_final(i)
	cps_changed.emit(cps)


func get_click_value() -> float:
	return click_power * get_achievement_multiplier() + cps * click_cps_percent


# ╔══════════════════════════════════════╗
# ║     FALÊNCIA DECLARADA (PRESTÍGIO)   ║
# ╚══════════════════════════════════════╝

func calculate_prestige_gain() -> int:
	var level: int = int(floor(sqrt(lifetime_earned / GameData.PRESTIGE_BASE)))
	return maxi(0, level - offshore_total)


## Quanto falta produzir para o próximo Fundo Offshore.
func get_next_fund_progress() -> float:
	var level: int = int(floor(sqrt(lifetime_earned / GameData.PRESTIGE_BASE)))
	var cur: float = pow(float(level), 2.0) * GameData.PRESTIGE_BASE
	var nxt: float = pow(float(level + 1), 2.0) * GameData.PRESTIGE_BASE
	return clampf((lifetime_earned - cur) / (nxt - cur), 0.0, 1.0)


func get_ceo_title(count: int = -1) -> String:
	var c := prestige_count if count < 0 else count
	var title: String = GameData.CEO_TITLES[0][1]
	for entry in GameData.CEO_TITLES:
		if c >= int(entry[0]):
			title = entry[1]
	return title


## Declara falência. Retorna o relatório para a UI.
func do_prestige() -> Dictionary:
	var gain := calculate_prestige_gain()
	if gain <= 0:
		return {}
	var report := {
		"gain": gain,
		"liquidated": coins,
		"buildings": get_total_buildings(),
		"debt_forgiven": Meowzos.loan_debt if Meowzos.loan_active else 0.0,
	}

	offshore_total += gain
	offshore_bank += gain
	prestige_count += 1

	# Paraquedas Dourado: mantém 10% de cada estrutura
	var kept: Array[int] = []
	for b in buildings:
		kept.append(int(floor(int(b["count"]) * 0.1)) if has_perk("paraquedas") else 0)

	coins = 0.0
	run_earned = 0.0
	_init_buildings()
	for i in range(buildings.size()):
		buildings[i]["count"] = kept[i]
	_init_upgrades()

	if has_perk("heranca"):
		coins = 25_000.0
		if not bets_unlocked:
			bets_unlocked = true
			bets_unlocked_changed.emit(true)

	Meowzos.forgive_all()
	recalculate()

	unlock_achievement("prestige_1")
	if prestige_count >= 3:
		unlock_achievement("prestige_3")
	if prestige_count >= 10:
		unlock_achievement("prestige_10")

	SaveScript.save_game()
	prestige_changed.emit()
	buildings_reset.emit()
	return report


func has_perk(id: String) -> bool:
	return perks.get(id, false)


func get_perk_def(id: String) -> Dictionary:
	for p in GameData.CEO_PERKS:
		if p["id"] == id:
			return p
	return {}


func buy_perk(id: String) -> bool:
	var def := get_perk_def(id)
	if def.is_empty() or has_perk(id) or offshore_bank < int(def["cost"]):
		return false
	offshore_bank -= int(def["cost"])
	perks[id] = true
	if id == "heranca" and not bets_unlocked:
		bets_unlocked = true
		bets_unlocked_changed.emit(true)
	unlock_achievement("perk_1")
	recalculate()
	perks_changed.emit()
	SaveScript.save_game()
	return true


# ╔══════════════════════════════════════╗
# ║          RENDA OFFLINE               ║
# ╚══════════════════════════════════════╝

func _compute_offline_income() -> void:
	if last_save_unix <= 0.0 or cps <= 0.0:
		return
	var elapsed: float = Time.get_unix_time_from_system() - last_save_unix
	if elapsed < GameData.OFFLINE_MIN_SECONDS:
		return
	var has_paraiso := has_perk("paraiso")
	var cap: float = GameData.OFFLINE_CAP_PERK if has_paraiso else GameData.OFFLINE_CAP_BASE
	var rate: float = GameData.OFFLINE_RATE_PERK if has_paraiso else GameData.OFFLINE_RATE_BASE
	var counted := minf(elapsed, cap)
	var gross: float = cps * counted
	var net: float = gross * rate
	earn(net)
	pending_offline_report = {
		"elapsed": elapsed, "counted": counted, "gross": gross, "net": net, "rate": rate,
	}


# ╔══════════════════════════════════════╗
# ║          CASSINO                     ║
# ╚══════════════════════════════════════╝

func can_afford_bets_upgrade() -> bool:
	return coins >= BETS_UPGRADE_COST and not bets_unlocked


func buy_bets_upgrade() -> bool:
	if bets_unlocked or not spend(BETS_UPGRADE_COST):
		return false
	bets_unlocked = true
	bets_unlocked_changed.emit(true)
	SaveScript.save_game()
	return true


## Debita uma aposta. Retorna false se não houver saldo.
func place_bet(amount: float) -> bool:
	amount = floor(amount)
	if amount < 1.0 or not spend(amount):
		return false
	bets_total_count += 1
	bets_total_wagered += amount
	unlock_achievement("bet_first")
	if bets_total_count >= 100:
		unlock_achievement("bet_100")
	return true


## Liquida uma aposta. `payout` é o valor BRUTO devolvido (0 = perdeu tudo).
## Aplica o bônus do Crupiê Subornado. Retorna o pagamento final creditado.
func settle_bet(game_id: String, bet: float, payout: float) -> float:
	var final_payout := payout
	if payout > bet and has_perk("crupie"):
		final_payout = payout * 1.03
	final_payout = floor(final_payout)
	if final_payout > 0.0:
		add_coins(final_payout)
	var net := final_payout - bet
	bets_net_result += net
	if final_payout > bets_highest_win:
		bets_highest_win = final_payout
	bet_settled.emit(game_id, bet, final_payout, net)
	_check_bailout()
	return final_payout


func _check_bailout() -> void:
	if coins >= 1.0 or not has_perk("bailout") or bailout_timer > 0.0:
		return
	var amount := maxf(1000.0, cps * 600.0)
	bailout_timer = BAILOUT_COOLDOWN
	add_coins(amount)
	unlock_achievement("bailout")
	bailout_paid.emit(amount)


# ╔══════════════════════════════════════╗
# ║          CONQUISTAS                  ║
# ╚══════════════════════════════════════╝

func unlock_achievement(id: String) -> void:
	if not achievements.has(id) or achievements[id]:
		return
	achievements[id] = true
	var def: Dictionary = GameData.ACHIEVEMENTS[id]
	if _booted:
		recalculate()   # cada conquista dá +1% de CPS
	achievement_unlocked.emit(id, str(def["name"]), str(def["desc"]))


func get_unlocked_achievement_count() -> int:
	var n := 0
	for id in achievements:
		if achievements[id]:
			n += 1
	return n


# ╔══════════════════════════════════════╗
# ║          RESET TOTAL                 ║
# ╚══════════════════════════════════════╝

## Apaga tudo (opção "Novo Jogo"). Não confundir com Falência.
func hard_reset() -> void:
	coins = 0.0
	lifetime_earned = 0.0
	run_earned = 0.0
	offshore_total = 0
	offshore_bank = 0
	prestige_count = 0
	perks.clear()
	for id in achievements.keys():
		achievements[id] = false
	bets_unlocked = false
	bets_total_count = 0
	bets_total_wagered = 0.0
	bets_net_result = 0.0
	bets_highest_win = 0.0
	total_clicks = 0
	play_time = 0.0
	_init_buildings()
	_init_upgrades()
	Meowzos.forgive_all()
	Meowzos.blacklist_time = 0.0
	recalculate()
	SaveScript.save_game()
	prestige_changed.emit()
	buildings_reset.emit()
	bets_unlocked_changed.emit(false)
