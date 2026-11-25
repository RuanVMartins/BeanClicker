extends Node
## PESQUE-PAGUE DO JEFF — sistema de pescaria (autoload "Fishing").
## O lago é do Jeff Meowzos, a vara é sua e o atravessador também é ele.
##
## Loop: lançar → esperar a fisgada → puxar no tempo certo → acertar a zona de
## tensão (1 a 3 vezes, conforme a raridade) → o peixe vai para a cesta →
## vender quando a "Cotação do Pescado" estiver boa (oscila como uma ação).
##
## Balanceamento (escala com a fortuna):
##   Valor do peixe = renda/segundo do jogador × segundos da raridade × tamanho
##                    × cotação do pescado × (1 − 10% do atravessador)
##   O valor é calculado NA VENDA, então peixe guardado acompanha o seu
##   crescimento — a pesca continua útil do primeiro ao último minuto.
##   Média por peixe ≈ 38 s de renda; pescando sem parar rende ~3x o CPS.
##   É bônus de jogo ativo, não substitui a produção. A cesta (10) impede AFK.

signal changed
signal caught(fish: Dictionary)

enum Rarity { COMUM, RARO, EPICO, LENDARIO }

const RARITY_NAMES: Array[String] = ["COMUM", "RARO", "ÉPICO", "CORPORATIVO"]
const RARITY_COLORS: Array[Color] = [Color("#C9C3D9"), Color("#5CF2FF"), Color("#B57BFF"), Color("#FFC94A")]
const RARITY_WEIGHTS: Array[float] = [0.70, 0.22, 0.065, 0.015]
const RARITY_SECONDS: Array[float] = [8.0, 45.0, 180.0, 720.0]   # segundos de renda
const RARITY_HITS: Array[int] = [1, 1, 2, 3]                     # acertos na zona de tensão
const RARITY_ZONE: Array[float] = [0.30, 0.22, 0.16, 0.12]       # largura da zona (0-1)
const RARITY_SPEED: Array[float] = [0.85, 1.2, 1.55, 1.9]        # velocidade do marcador

const COOLER_CAPACITY: int = 10
const BROKER_FEE: float = 0.10

# [nome, raridade, kg mín, kg máx, cor, descrição]
const FISH: Array = [
	["Sardinha CLT", Rarity.COMUM, 0.1, 0.3, Color("#9FB3C8"), "Vive apertada com outras 300 numa lata. Chamam isso de open space."],
	["Lambari Estagiário", Rarity.COMUM, 0.05, 0.2, Color("#B8C99A"), "Nada 12 horas por dia por um vale-ração."],
	["Tilápia Terceirizada", Rarity.COMUM, 0.5, 1.5, Color("#C7B7A3"), "Faz o trabalho do salmão por um terço do preço."],
	["Bagre do Home Office", Rarity.COMUM, 0.8, 2.5, Color("#8C7E6A"), "Fica no fundo, câmera desligada, mas entrega."],
	["Robalo Gerente Médio", Rarity.RARO, 2.0, 6.0, Color("#6FA8DC"), "Não sabe o que faz, mas marca reunião sobre isso."],
	["Truta Coach Quântica", Rarity.RARO, 1.0, 4.0, Color("#E39BC4"), "Promete multiplicar seu salário com técnicas de respiração."],
	["Pacu Pejotizado", Rarity.RARO, 3.0, 8.0, Color("#A3C46B"), "Tem CNPJ, não tem férias."],
	["Salmão Unicórnio", Rarity.EPICO, 5.0, 12.0, Color("#FF8A65"), "Startup avaliada em 1 bilhão. Nunca deu lucro."],
	["Atum Influencer", Rarity.EPICO, 20.0, 60.0, Color("#4FC3F7"), "2 milhões de seguidores e nenhuma opinião própria."],
	["Peixe-Espada de Fusões", Rarity.EPICO, 15.0, 40.0, Color("#B0BEC5"), "Engole empresas menores inteiras e chama de sinergia."],
	["Tubarão de Wall Street", Rarity.LENDARIO, 200.0, 600.0, Color("#78909C"), "Sente cheiro de liquidez a 3 km de distância."],
	["Baleia Bilionária", Rarity.LENDARIO, 5000.0, 20000.0, Color("#5C6BC0"), "Uma só já mexe no índice da bolsa."],
	["Peixe-Grande do Lobby", Rarity.LENDARIO, 80.0, 300.0, Color("#FFD54F"), "Não se fisga. Se convida para jantar."],
]

# [nome, preço, sorte (multiplica raridades), zona extra, janela extra de fisgada (s), descrição]
const RODS: Array = [
	["Vara de Bambu do Estagiário", 0.0, 1.0, 0.0, 0.0, "Veio no kit de boas-vindas, junto com um crachá."],
	["Vara de Fibra Terceirizada", 15_000.0, 1.4, 0.15, 0.15, "Fabricada por uma empresa que subcontrata outra empresa."],
	["Vara de Carbono Corporativa", 2_500_000.0, 2.0, 0.30, 0.30, "Patrocinada. Tem o logo de três bancos no cabo."],
	["Vara Offshore com Sonar", 750_000_000.0, 3.0, 0.45, 0.45, "Registrada nas Ilhas Cayman. Pesca até em águas internacionais."],
]

var cooler: Array[Dictionary] = []
var rod_tier: int = 0
var total_caught: int = 0
var total_sold: int = 0
var total_escaped: int = 0
var best_sale: float = 0.0
var legendary_caught: int = 0


# ══════════════════════════════════════
# PEIXES
# ══════════════════════════════════════

func roll_rarity() -> int:
	var luck: float = RODS[rod_tier][2]
	var weights: Array[float] = []
	var total := 0.0
	for i in range(RARITY_WEIGHTS.size()):
		var w: float = RARITY_WEIGHTS[i] * (1.0 if i == 0 else luck)
		weights.append(w)
		total += w
	var r := randf() * total
	for i in range(weights.size()):
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


func roll_fish(rarity: int) -> Dictionary:
	var pool: Array = []
	for f in FISH:
		if int(f[1]) == rarity:
			pool.append(f)
	var def: Array = pool[randi() % pool.size()]
	var kg_min: float = def[2]
	var kg_max: float = def[3]
	# Distribuição puxada para o meio; peixes enormes são raros
	var t := (randf() + randf()) * 0.5
	var kg := lerpf(kg_min, kg_max, t)
	var size_mult := lerpf(0.65, 1.6, (kg - kg_min) / maxf(kg_max - kg_min, 0.001))
	return {
		"name": def[0], "rarity": rarity, "kg": snappedf(kg, 0.01),
		"size_mult": size_mult, "color": (def[4] as Color).to_html(), "desc": def[5],
	}


## Renda de referência: CPS, ou cliques no começo do jogo.
func income_unit() -> float:
	return maxf(GameManager.cps, maxf(GameManager.get_click_value() * 2.0, 1.0))


## Cotação do Pescado: oscila entre ~0,63x e ~1,37x, contínua no tempo real.
func price_index() -> float:
	var t := Time.get_unix_time_from_system()
	return 1.0 + 0.25 * sin(t * TAU / 97.0) + 0.12 * sin(t * TAU / 31.0 + 1.3)


## Valor bruto (antes do atravessador) de um peixe agora.
func gross_value(fish: Dictionary) -> float:
	return income_unit() * RARITY_SECONDS[int(fish["rarity"])] * float(fish["size_mult"]) * price_index()


func net_value(fish: Dictionary) -> float:
	return floorf(gross_value(fish) * (1.0 - BROKER_FEE))


func cooler_value() -> float:
	var total := 0.0
	for f in cooler:
		total += net_value(f)
	return total


func cooler_full() -> bool:
	return cooler.size() >= COOLER_CAPACITY


func zone_width(rarity: int) -> float:
	return RARITY_ZONE[rarity] * (1.0 + float(RODS[rod_tier][3]))


func bite_window() -> float:
	return 0.95 + float(RODS[rod_tier][4])


# ══════════════════════════════════════
# AÇÕES
# ══════════════════════════════════════

func add_catch(fish: Dictionary) -> bool:
	if cooler_full():
		return false
	cooler.append(fish)
	total_caught += 1
	GameManager.unlock_achievement("fish_first")
	if int(fish["rarity"]) == Rarity.LENDARIO:
		legendary_caught += 1
		GameManager.unlock_achievement("fish_legend")
	caught.emit(fish)
	changed.emit()
	return true


func register_escape() -> void:
	total_escaped += 1


## Vende a cesta inteira. Retorna {"net": float, "fee": float, "count": int}.
## Venda de peixe é trabalho, então conta como renda produtiva (Falência).
func sell_all() -> Dictionary:
	if cooler.is_empty():
		return {}
	var gross := 0.0
	for f in cooler:
		gross += gross_value(f)
	var fee: float = floorf(gross * BROKER_FEE)
	var net: float = floorf(gross) - fee
	var count := cooler.size()
	cooler.clear()
	total_sold += count
	best_sale = maxf(best_sale, net)
	GameManager.earn(net)
	if total_sold >= 50:
		GameManager.unlock_achievement("fish_seller")
	changed.emit()
	return {"net": net, "fee": fee, "count": count}


func next_rod() -> Array:
	if rod_tier + 1 >= RODS.size():
		return []
	return RODS[rod_tier + 1]


func buy_next_rod() -> bool:
	var nxt := next_rod()
	if nxt.is_empty() or not GameManager.spend(float(nxt[1])):
		return false
	rod_tier += 1
	changed.emit()
	return true


# ══════════════════════════════════════
# SAVE
# ══════════════════════════════════════

func to_save() -> Dictionary:
	return {
		"cooler": cooler, "rod_tier": rod_tier, "total_caught": total_caught,
		"total_sold": total_sold, "total_escaped": total_escaped,
		"best_sale": best_sale, "legendary_caught": legendary_caught,
	}


func from_save(d: Dictionary) -> void:
	cooler.clear()
	for f in d.get("cooler", []):
		if f is Dictionary:
			cooler.append(f)
	rod_tier = clampi(int(d.get("rod_tier", 0)), 0, RODS.size() - 1)
	total_caught = int(d.get("total_caught", 0))
	total_sold = int(d.get("total_sold", 0))
	total_escaped = int(d.get("total_escaped", 0))
	best_sale = float(d.get("best_sale", 0.0))
	legendary_caught = int(d.get("legendary_caught", 0))
	changed.emit()


## Falência não leva sua vara (é pessoa física), mas a cesta vai junto com a empresa.
func on_bankruptcy() -> void:
	cooler.clear()
	changed.emit()
