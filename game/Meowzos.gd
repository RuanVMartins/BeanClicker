extends Node
## JEFF MEOWZOS — gato sphynx bilionário, dono do cassino e agiota licenciado (por ele mesmo).
## Autoload "Meowzos". Dono de dois sistemas:
##   1. Empréstimos com juros compostos por minuto, prazo e penhora de bens.
##   2. Falas contextuais (humor ácido) que qualquer UI pode exibir via sinal `said`.
##
## Balanceamento dos empréstimos:
##   O valor emprestado é medido em "minutos de renda" (CPS x 60), então escala
##   com o jogo inteiro sem tabela nova. Os juros são absurdos de propósito: a
##   única forma de lucrar com um empréstimo é investir em estruturas cedo
##   (Consignado) ou ganhar no cassino (Agiotagem). É uma armadilha honesta.

signal said(text: String, mood: String)
signal loan_changed
signal loan_defaulted(report: Dictionary)

const MIN_UNIT: float = 200.0      # piso de "renda por minuto" no começo do jogo
const BLACKLIST_TIME: float = 300.0

const LOAN_TIERS: Array[Dictionary] = [
	{
		"id": "consignado", "name": "Consignado Felino",
		"minutes": 10.0, "rate": 0.03, "term": 600.0,
		"pitch": "Desconto direto na ração. Você nem sente. (Sente sim.)",
	},
	{
		"id": "pessoal", "name": "Crédito Pré-Aprovado",
		"minutes": 30.0, "rate": 0.07, "term": 360.0,
		"pitch": "Aprovado antes de você pedir. Antes de você nascer, na verdade.",
	},
	{
		"id": "raiz", "name": "Agiotagem Raiz",
		"minutes": 90.0, "rate": 0.15, "term": 240.0,
		"pitch": "Sem papelada, sem perguntas. Só um primo meu que sabe onde você mora.",
	},
]

# ── Estado do empréstimo ──
var loan_active: bool = false
var loan_tier: String = ""
var loan_principal: float = 0.0
var loan_debt: float = 0.0
var loan_rate: float = 0.0          # por minuto
var loan_time_left: float = 0.0
var loan_term: float = 0.0
var blacklist_time: float = 0.0
var loans_taken: int = 0
var loans_defaulted: int = 0

var _reminders_sent: Dictionary = {}
var _lose_streak: int = 0
var _last_line: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.bet_settled.connect(_on_bet_settled)
	GameManager.bailout_paid.connect(func(amount: float):
		say_key("bailout", {"amount": NumberFormatter.format_number(amount)}, "smug"))


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if blacklist_time > 0.0:
		blacklist_time = maxf(0.0, blacklist_time - delta)
	if not loan_active:
		return
	# Juros compostos contínuos: debt *= (1 + r)^(dt / 60)
	loan_debt *= pow(1.0 + loan_rate, delta / 60.0)
	loan_time_left -= delta
	_check_reminders()
	if loan_time_left <= 0.0:
		_default()


# ╔══════════════════════════════════════╗
# ║          EMPRÉSTIMOS                 ║
# ╚══════════════════════════════════════╝

func _credit_unit() -> float:
	var unit := maxf(GameManager.cps * 60.0, MIN_UNIT)
	if GameManager.has_perk("amigo_agiota"):
		unit *= 2.0
	return floor(unit)


func get_offer(index: int) -> Dictionary:
	var t: Dictionary = LOAN_TIERS[index].duplicate()
	var rate: float = t["rate"]
	if GameManager.has_perk("amigo_agiota"):
		rate *= 0.5
	t["rate"] = rate
	t["amount"] = floor(_credit_unit() * float(t["minutes"]))
	t["owed_at_term"] = float(t["amount"]) * pow(1.0 + rate, float(t["term"]) / 60.0)
	return t


func can_borrow() -> bool:
	return not loan_active and blacklist_time <= 0.0


func take_loan(index: int) -> bool:
	if not can_borrow():
		say_key("blacklisted" if blacklist_time > 0.0 else "already_owing", {}, "angry")
		return false
	var offer := get_offer(index)
	loan_active = true
	loan_tier = offer["id"]
	loan_principal = offer["amount"]
	loan_debt = offer["amount"]
	loan_rate = offer["rate"]
	loan_term = offer["term"]
	loan_time_left = offer["term"]
	loans_taken += 1
	_reminders_sent.clear()
	GameManager.add_coins(loan_principal)
	GameManager.unlock_achievement("loan_first")
	say_key("loan_taken", {"amount": NumberFormatter.format_number(loan_principal)}, "smug")
	loan_changed.emit()
	return true


## Paga parte ou toda a dívida com o saldo. Retorna o valor pago.
func repay(amount: float) -> float:
	if not loan_active:
		return 0.0
	var pay := minf(minf(amount, loan_debt), GameManager.coins)
	if pay <= 0.0:
		say_key("cant_pay", {}, "angry")
		return 0.0
	GameManager.spend(pay)
	loan_debt -= pay
	if loan_debt <= 0.5:
		_close_loan()
		GameManager.unlock_achievement("loan_paid")
		say_key("loan_paid", {}, "sad")
	else:
		say_key("partial_payment", {"debt": NumberFormatter.format_number(loan_debt)}, "neutral")
	loan_changed.emit()
	return pay


func _close_loan() -> void:
	loan_active = false
	loan_tier = ""
	loan_debt = 0.0
	loan_principal = 0.0
	loan_time_left = 0.0


## Prazo estourou: leva o caixa, depois penhora estruturas (as mais caras primeiro).
func _default() -> void:
	var debt := loan_debt
	var from_cash := minf(GameManager.coins, debt)
	GameManager.spend(from_cash)
	var remaining := debt - from_cash
	var repo := {"recovered": 0.0, "taken": {}}
	if remaining > 0.0 and not GameManager.has_perk("calote"):
		repo = GameManager.repossess_buildings(remaining)
	_close_loan()
	loans_defaulted += 1
	blacklist_time = BLACKLIST_TIME
	GameManager.unlock_achievement("loan_default")

	var report := {
		"debt": debt, "from_cash": from_cash,
		"repossessed": repo["taken"], "recovered": repo["recovered"],
		"forgiven": maxf(0.0, remaining - float(repo["recovered"])),
	}
	var key := "default_buildings" if not (repo["taken"] as Dictionary).is_empty() else "default_cash"
	say_key(key, {"amount": NumberFormatter.format_number(debt)}, "angry")
	loan_changed.emit()
	loan_defaulted.emit(report)


func _check_reminders() -> void:
	var ratio := loan_time_left / maxf(loan_term, 1.0)
	for mark in [0.5, 0.25]:
		if ratio <= mark and not _reminders_sent.has(mark):
			_reminders_sent[mark] = true
			say_key("loan_reminder", {
				"debt": NumberFormatter.format_number(loan_debt),
				"time": NumberFormatter.format_time(loan_time_left),
			}, "neutral")
	if loan_time_left <= 30.0 and not _reminders_sent.has("final"):
		_reminders_sent["final"] = true
		say_key("loan_final", {"debt": NumberFormatter.format_number(loan_debt)}, "angry")


## Falência perdoa tudo. "Calote estratégico" é o nome técnico.
func forgive_all() -> void:
	if loan_active:
		_close_loan()
		loan_changed.emit()


func to_save() -> Dictionary:
	return {
		"loan_active": loan_active, "loan_tier": loan_tier,
		"loan_principal": loan_principal, "loan_debt": loan_debt,
		"loan_rate": loan_rate, "loan_time_left": loan_time_left, "loan_term": loan_term,
		"blacklist_time": blacklist_time, "loans_taken": loans_taken,
		"loans_defaulted": loans_defaulted,
	}


func from_save(d: Dictionary) -> void:
	loan_active = bool(d.get("loan_active", false))
	loan_tier = str(d.get("loan_tier", ""))
	loan_principal = float(d.get("loan_principal", 0.0))
	loan_debt = float(d.get("loan_debt", 0.0))
	loan_rate = float(d.get("loan_rate", 0.0))
	loan_time_left = float(d.get("loan_time_left", 0.0))
	loan_term = float(d.get("loan_term", 0.0))
	blacklist_time = float(d.get("blacklist_time", 0.0))
	loans_taken = int(d.get("loans_taken", 0))
	loans_defaulted = int(d.get("loans_defaulted", 0))
	loan_changed.emit()


# ╔══════════════════════════════════════╗
# ║          FALAS                       ║
# ╚══════════════════════════════════════╝

const LINES: Dictionary = {
	"casino_open": [
		"Bem-vindo de volta! Seu lugar de sempre está quentinho. Literalmente, ninguém mais senta aí.",
		"Ah, meu cliente favorito! O favorito é sempre o que ainda tem saldo.",
		"Entra, entra. Relógio aqui não tem. Janela também não. É de propósito.",
		"Psiu. A casa sempre ganha. Mas hoje, quem sabe, a casa tá de folga. (Não está.)",
		"Bem-vindo! Seu dinheiro chega na minha conta em 1 dia útil. O meu na sua? Prazo indeterminado.",
	],
	"tab_slot": [
		"Caça-Níquel: luzes, barulho e matemática contra você. Arte moderna.",
		"Puxa a alavanca! Cada giro é uma pequena doação para o meu iate.",
	],
	"tab_crash": [
		"Foguetinho! Igual a uma startup: sobe rápido, explode sem aviso.",
		"Saca antes de explodir. Ou não. Eu gosto de surpresas.",
		"Eu tenho um foguete de verdade. Maior. Bem maior. Você entendeu o formato.",
	],
	"tab_blackjack": [
		"21 Felino. Eu cobro só 5% de 'taxa de conveniência' nas vitórias. Conveniente pra mim.",
		"O dealer para no 17. Eu nunca paro de lucrar.",
	],
	"tab_roulette": [
		"Roleta! O zero é meu. Sempre foi. Desde o descobrimento.",
		"Vermelho ou preto? Tanto faz, o verde é que paga meu aluguel.",
	],
	"tab_scratch": [
		"Raspadinha: o imposto voluntário de quem não gosta de matemática.",
		"Raspa, raspa! A esperança é a última que morre. Ela morre aqui, na verdade.",
	],
	"tab_rats": [
		"Corrida de Ratos! Igual ao mercado de trabalho, só que mais honesto.",
		"O Herdeiro Nepo largou na frente. Não pergunte por quê. O pai dele é dono da pista.",
	],
	"tab_pyramid": [
		"Esquema Pirâmide! Ops, 'Marketing Multinível de Impacto'. Agora é legal.",
		"Recrute mais gente e suba. Alguém lá embaixo sempre paga a conta.",
	],
	"win_small": [
		"Ganhou {amount}. Viu? É fácil. Agora aposta tudo.",
		"Olha só, {amount}! O vício começa assim. Digo, o sucesso.",
		"Parabéns pelos {amount}. Vou colocar na sua conta. Digo, na minha conta. Brincadeira.",
		"Ganhou! Isso se chama 'reforço intermitente'. Eu li num livro de psicologia.",
	],
	"win_big": [
		"{amount}?! Seguranças, fiquem de olho nesse gato.",
		"Que vitória! Vou fingir que estou feliz por você enquanto recalculo as odds.",
		"{amount} de lucro! Agora você é o tipo de cliente que a gente manda limusine buscar.",
	],
	"jackpot": [
		"JACKPOT! Tira foto! Vai pro mural! Ninguém precisa saber dos outros 10 mil que perderam.",
		"JACKPOT DE {amount}! Toca a sirene! A sirene serve pra atrair os outros otários. Digo, clientes.",
	],
	"lose": [
		"Perdeu. Faz parte. A parte que vem pra mim.",
		"Quase! 'Quase' é minha palavra favorita. Rende muito.",
		"Não foi dessa vez. Mas a próxima tem 100% de chance de ser uma nova tentativa.",
		"Relaxa, dinheiro não traz felicidade. Pra você. Pra mim traz.",
		"O segredo é não parar. Quem para no prejuízo, fica no prejuízo.",
	],
	"lose_big": [
		"{amount} pro ralo. Ou pro meu bolso, que é tipo um ralo com juros.",
		"Ui. Essa doeu até em mim. Mentira, eu tô ótimo.",
		"Perdeu {amount}. Quer um copo d'água? É 50 moedas.",
	],
	"lose_streak": [
		"{n} derrotas seguidas. Estatisticamente, a próxima é sua! (Isso é falácia do apostador, mas fica entre nós.)",
		"Sequência ruim? Um empréstimozinho resolve. Taxa camarada. Camarada pra mim.",
		"Você está a UMA aposta de recuperar tudo. Sempre está. Esse é o truque.",
	],
	"all_in": [
		"TUDO?! Isso que é visão de CEO!",
		"All-in! Adoro gente que não tem plano B.",
	],
	"broke": [
		"Zerou, hein? Meu escritório de crédito está aberto. 24h. Inclusive no Natal.",
		"Saldo zero. A boa notícia: não tem mais nada pra perder. A má: eu empresto.",
	],
	"tie": [
		"Empate. Ninguém ganhou, ninguém perdeu. Que tédio. Joga de novo.",
	],
	"loan_offer": [
		"Precisando de capital? Juros baixíssimos. Baixíssimos comparados aos de agosto.",
		"Dinheiro na mão agora, preocupação depois. É o lema do país.",
		"Crédito fácil! Fácil de pegar. O pagar a gente discute depois.",
	],
	"loan_taken": [
		"{amount} na sua conta! Assina aqui, aqui e aqui. Esse último é a alma, mas é só formalidade.",
		"Pronto, {amount}. Os juros já estão rodando. Tic-tac.",
		"Negócio fechado! {amount} pra você. Meu primo Leão vai acompanhar seu progresso de perto.",
	],
	"loan_reminder": [
		"Só lembrando: você me deve {debt}. Faltam {time}. Sem pressão. (Pressão.)",
		"Oi sumido! Passando pra lembrar dos {debt}. Prazo: {time}. Beijos do Leão.",
	],
	"loan_final": [
		"30 SEGUNDOS. {debt}. O Leão já está estacionando na frente da sua fábrica.",
		"Última chamada, parceiro: {debt}. Depois disso eu viro um gato bem menos simpático.",
	],
	"loan_paid": [
		"Quitou? Tudo? ...Que decepção. Volte sempre.",
		"Dívida paga. Nossa relação era tão bonita enquanto você me devia.",
	],
	"partial_payment": [
		"Pagamento parcial recebido. Ainda faltam {debt}. Os juros agradecem a companhia.",
	],
	"cant_pay": [
		"Pagar com o quê? Com amor? Eu aceito Pix, não sentimento.",
	],
	"already_owing": [
		"Um empréstimo de cada vez, campeão. Até eu tenho limites. Poucos, mas tenho.",
	],
	"blacklisted": [
		"Seu nome tá sujo no SPC Felino. Volta daqui a pouco com cara de arrependido.",
	],
	"default_cash": [
		"Venceu o prazo. Peguei {amount} do seu caixa. Nada pessoal. Tudo comercial.",
	],
	"default_buildings": [
		"Calote de {amount}?! O Leão já levou umas fábricas. Considere isso 'renegociação compulsória'.",
		"Inadimplência! Penhorei suas estruturas. Tá tudo no contrato, letra tamanho 2.",
	],
	"bailout": [
		"O governo depositou {amount} pra você. Lucro privado, prejuízo público. Lindo, né?",
	],
	"prestige": [
		"Falência declarada! Os credores choram, os fundos offshore sorriem. Bem-vindo à elite.",
		"Quebrou a empresa? Parabéns! Agora você é um 'empreendedor experiente'.",
	],
	"offline": [
		"Enquanto você dormia, seus estagiários trabalharam. Eu cobrei só {fee} de 'taxa de administração'.",
		"Você sumiu e a fábrica não parou. Ninguém notou sua ausência. Isso é eficiência.",
	],
	"idle_economy": [
		"Inflação? Não existe inflação. Existe você ganhando pouco.",
		"Sabe o que gera riqueza? Trabalho. Dos outros.",
		"Meritocracia é quando o mérito é ter nascido no lugar certo.",
		"Já pensou em empreender? É igual trabalhar, só que sem salário e com mais boleto.",
		"Hoje o mercado acordou nervoso. Demitiram 4 mil gatos e ele se acalmou.",
		"Dica de investimento: compre baixo, venda alto, e terceirize a culpa.",
		"Seus Mini Beans pediram aumento. Eu sugeri uma palestra sobre gratidão.",
		"Sabe a diferença entre um agiota e um banco? O terno.",
		"Riqueza não se cria nem se destrói. Ela só muda de bolso. Do seu pro meu.",
		"Tá sobrando dinheiro? No cassino ele rende mais. Rende pra mim, mas rende.",
		"O segredo do sucesso é acordar às 5h. E ter herdado uma fazenda.",
		"Crise é oportunidade. Principalmente pra quem tem dinheiro durante a crise.",
		"Eu não sou careca. Sou aerodinâmico. Ajuda na reentrada da atmosfera.",
		"Meus estagiários ganham garrafinha pra não perder tempo indo ao banheiro. Sustentabilidade.",
		"Sabe por que não tenho pelo? Porque cada fio era um custo operacional.",
		"Pagar imposto é para quem não tem contador criativo.",
		"Tá parado? Vai pescar no meu lago. Eu cobro, mas é relaxante.",
	],
	"fish_open": [
		"Bem-vindo ao meu lago. A água é grátis. O peixe, a vara e a venda, não.",
		"Pesque à vontade! Eu fico só com 10% de atravessador. Por peixe. Pra sempre.",
		"Pescaria é terapia. A minha terapia é cobrar a sua.",
	],
	"fish_catch": [
		"Um {fish}! Vou anotar na sua conta. Digo, no seu currículo.",
		"{fish} fisgado. Mais um trabalhador do mar que vai virar lucro de terra.",
		"Bela pescaria. Lembre que a peixaria é minha também.",
	],
	"fish_big": [
		"{fish}?! Esse aí eu queria no meu aquário de escritório.",
		"Olha o tamanho desse {fish}! Vai pagar umas taxas lindas.",
	],
	"fish_legend": [
		"UM {fish}?! Ele me deve dinheiro! Segura firme que eu cobro na venda!",
		"{fish} CORPORATIVO! Esse peixe tem mais patrimônio que o lago inteiro!",
	],
	"fish_escape": [
		"Escapou. Igual aos seus direitos trabalhistas.",
		"O peixe fugiu. Pelo menos não pediu indenização.",
		"Perdeu o peixe. Mas não perdeu a taxa de uso do lago, que eu já cobrei.",
	],
	"fish_sell": [
		"Venda concluída! Fiquei com {fee} de atravessador. Não fiz nada, por isso cobro.",
		"{fee} pra mim. É o preço de existir um intermediário entre você e o dinheiro.",
	],
	"fish_full": [
		"Cesta cheia! Venda logo, peixe parado é capital improdutivo.",
		"Não cabe mais nada na cesta. Igual ao seu cartão de crédito.",
	],
	"fish_rod": [
		"{rod}! Ótima compra. A vara anterior eu revendo como 'seminova'.",
		"Vara nova, mesmas taxas. Bem-vindo ao upgrade.",
	],
	"idle_debt": [
		"Tô de olho, hein. {debt} não se pagam sozinhos. Na verdade eles crescem sozinhos.",
		"Lembrete amigável: {debt}. O 'amigável' tem prazo de validade.",
	],
	"idle_rich": [
		"Tanto dinheiro parado... sabe o que é isso? Desperdício. O cassino tá logo ali.",
		"Com esse saldo você podia ser meu sócio. Ou minha vítima. Os dois pagam bem.",
	],
}


func line(key: String, vars: Dictionary = {}) -> String:
	var pool: Array = LINES.get(key, [])
	if pool.is_empty():
		return ""
	var text: String = pool[randi() % pool.size()]
	if pool.size() > 1:
		var guard := 0
		while text == _last_line and guard < 4:
			text = pool[randi() % pool.size()]
			guard += 1
	_last_line = text
	for k in vars:
		text = text.replace("{%s}" % k, str(vars[k]))
	return text


func say(text: String, mood: String = "neutral") -> void:
	if text != "":
		said.emit(text, mood)


func say_key(key: String, vars: Dictionary = {}, mood: String = "neutral") -> void:
	say(line(key, vars), mood)


## Fala ambiente para a tela principal (escolhe o tema pelo estado do jogador).
func ambient_line() -> String:
	if loan_active:
		return line("idle_debt", {"debt": NumberFormatter.format_number(loan_debt)})
	if GameManager.bets_unlocked and GameManager.cps > 0.0 and GameManager.coins > GameManager.cps * 600.0 and randf() < 0.35:
		return line("idle_rich")
	if randf() < 0.2 and can_borrow():
		return line("loan_offer")
	return line("idle_economy")


## Reage a toda aposta liquidada (o cassino só precisa liquidar; o Meowzos comenta).
func _on_bet_settled(_game_id: String, bet: float, payout: float, net: float) -> void:
	var amt := NumberFormatter.format_number(absf(net))
	if net > 0.0:
		_lose_streak = 0
		if payout >= bet * 10.0:
			say_key("jackpot", {"amount": amt}, "shock")
		elif net >= maxf(bet * 3.0, GameManager.cps * 300.0):
			say_key("win_big", {"amount": amt}, "shock")
		else:
			say_key("win_small", {"amount": amt}, "smug")
	elif net == 0.0:
		say_key("tie", {}, "neutral")
	else:
		_lose_streak += 1
		if GameManager.coins < 1.0:
			say_key("broke", {}, "smug")
		elif _lose_streak >= 4 and _lose_streak % 2 == 0:
			say_key("lose_streak", {"n": _lose_streak}, "smug")
		elif bet >= maxf(GameManager.coins, GameManager.cps * 300.0):
			say_key("lose_big", {"amount": amt}, "smug")
		else:
			say_key("lose", {}, "smug")
