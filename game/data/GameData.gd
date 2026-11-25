class_name GameData
extends RefCounted
## Definições estáticas do jogo (dados puros, sem estado).
## Separar dados de lógica deixa o balanceamento editável num lugar só.

# ══════════════════════════════════════
# ESTRUTURAS (produção passiva)
# Curva de preço: base * 1.15^n  |  razão preço/CPS cresce ~10x por tier
# ══════════════════════════════════════
const BUILDINGS: Array[Dictionary] = [
	{
		"id": "mini_bean", "name": "Mini Bean", "subtitle": "Estagiário Clonado",
		"desc": "Clones incansáveis do Grande Bean. Trabalham na escala 6x1 pelo sonho da efetivação, que nunca vem.",
		"icon": "res://images/BeansIdle.png", "base_price": 15.0, "base_cps": 0.1,
	},
	{
		"id": "fazendeiro", "name": "Fazendeiro Felino", "subtitle": "Agrofelino Familiar",
		"desc": "Gato lavrador de chapéu de palha. Cultiva Bean Coins na esperança de um dia pagar o aluguel do arranhador.",
		"icon": "res://images/fazendeiro.png", "base_price": 100.0, "base_cps": 1.0,
	},
	{
		"id": "plantacao", "name": "Plantação de Moedas", "subtitle": "Agronegócio Transgênico",
		"desc": "Arbustos geneticamente modificados que brotam moedas direto do adubo. O agro é tech, o agro é pop, o agro é isento.",
		"icon": "res://images/plantacao.png", "base_price": 1_100.0, "base_cps": 8.0,
	},
	{
		"id": "mina", "name": "Mina Clandestina", "subtitle": "Extração 'Sustentável'",
		"desc": "Galerias escuras onde gatos mineiros quebram rochas. O laudo de segurança foi assinado pelo próprio Bean.",
		"icon": "res://images/mina.png", "base_price": 12_000.0, "base_cps": 47.0,
	},
	{
		"id": "fabrica", "name": "Complexo Industrial", "subtitle": "Linha de Produção 24/7",
		"desc": "Chaminés a todo vapor fundindo moedas em velocidade recorde. O sindicato virou uma sala de descompressão com pufe.",
		"icon": "res://images/fabrica.png", "base_price": 130_000.0, "base_cps": 260.0,
	},
	{
		"id": "banco", "name": "Banco do Bean", "subtitle": "Instituição Financeira",
		"desc": "Empresta o dinheiro de uns para outros e cobra tarifa dos dois. Não produz nada, por isso rende tanto.",
		"icon": "res://images/stock_tesouro.png", "base_price": 1_400_000.0, "base_cps": 1_400.0,
	},
	{
		"id": "racao", "name": "Ração Ultraprocessada S.A.", "subtitle": "Indústria Alimentícia",
		"desc": "0% atum, 100% sabor de atum. Aprovada por 9 em cada 10 veterinários patrocinados.",
		"icon": "res://images/stock_raco3.png", "base_price": 20_000_000.0, "base_cps": 7_800.0,
	},
	{
		"id": "miaucoin", "name": "Fazenda de MiauCoin", "subtitle": "Criptoativo Lastreado em Vibes",
		"desc": "Uma moeda lastreada em absolutamente nada. Igual às outras, só que com mais confiança e menos regulação.",
		"icon": "res://images/stock_doge.png", "base_price": 330_000_000.0, "base_cps": 44_000.0,
	},
]

# Prefixos de ID dos upgrades por estrutura (mantém compatibilidade com saves v2)
const BUILDING_UPGRADE_PREFIX: Dictionary = {
	"mini_bean": "mb", "fazendeiro": "faz", "plantacao": "plant", "mina": "mina",
	"fabrica": "fab", "banco": "banco", "racao": "racao", "miaucoin": "miau",
}

# 4 tiers por estrutura: [nome, descrição]. Requisitos: 1, 5, 25, 50 unidades.
# Preço: base_price * [10, 50, 500, 5000]. Efeito: x2 cada.
const BUILDING_UPGRADE_TIERS: Array[int] = [1, 5, 25, 50]
const BUILDING_UPGRADE_PRICE_MULT: Array[float] = [10.0, 50.0, 500.0, 5000.0]
const BUILDING_UPGRADE_TEXT: Dictionary = {
	"mini_bean": [
		["Pausa pro Café", "Cafeína barata no bebedouro reduz os bocejos. Pausa de 4 minutos, descontada do salário."],
		["Jornada 6x1 Noturna", "Elimina o descanso semanal em troca de um tapinha nas costas e um 'você é essencial'."],
		["Pizza na Sexta", "Substitui o aumento salarial por uma pizza de mussarela para 40 gatos. Moral +200%, custo -99%."],
		["Vaga 'Família'", "'Aqui somos uma família.' E família não cobra hora extra, né?"],
	],
	"fazendeiro": [
		["Enxada Forjada", "Aço temperado que não emperra nas raízes. Financiada em 48x no cartão do próprio fazendeiro."],
		["Catnip Estimulante", "Erva de gato na ração matinal. Ninguém reclama do turno quando está chapado."],
		["Defensivo Gourmet", "Proibido em 47 países. Aqui chamamos de 'defensivo agrícola' e seguimos a vida."],
		["Grilagem Sustentável", "Expande a fazenda para terras 'sem dono'. Os donos discordam, mas não têm advogado."],
	],
	"plantacao": [
		["Irrigação por Gotejamento", "Tubulação automatizada que nutre as mudas sem desperdiçar água. A do vizinho, no caso."],
		["Estufa Solar UV", "Fotossíntese 24 horas por dia. As plantas também foram convencidas a fazer hora extra."],
		["Semente Patenteada", "Germina uma vez só. Ano que vem o fazendeiro compra de novo. Genial."],
		["Monocultura Infinita", "Biodiversidade é custo. Tudo vira moeda até onde a vista alcança."],
	],
	"mina": [
		["Brocas de Tungstênio", "Pontas ultrarresistentes. Mais resistentes que os mineiros, inclusive."],
		["Dinamite Cirúrgica", "Detonações 'calculadas'. O cálculo foi feito no guardanapo, mas está lá."],
		["Barragem 'Segura'", "Laudo aprovado por um engenheiro que é primo do dono. O que pode dar errado?"],
		["EPI Opcional", "Capacete agora é 'recomendação'. Economia de 3 moedas por gato. Por mês."],
	],
	"fabrica": [
		["Esteiras Duplas", "Fluxo contínuo direto dos fornos para os cofres do Bean. Sem gargalos, sem pausas, sem alma."],
		["Automação 4.0", "Braços robóticos que não pedem café nem fazem greve. O RH chorou de alegria."],
		["Turno Sem Banheiro", "Pausas fisiológicas agora são 'oportunidades de crescimento pessoal'."],
		["Isenção Fiscal Eterna", "Prometemos 10 empregos. Geramos 2 robôs. O prefeito cortou a fita mesmo assim."],
	],
	"banco": [
		["Tarifa de Manutenção", "Cobra para guardar, cobra para sacar, cobra para olhar o extrato."],
		["Cheque Especial 400%", "Juros que fariam o Jeff Meowzos corar. Ele aprovou com lágrimas nos olhos."],
		["Venda Casada", "Quer abrir conta? Leve junto um seguro de vida para o seu peixinho dourado."],
		["Grande Demais Pra Quebrar", "Se der errado, o governo paga. Se der certo, o lucro é nosso."],
	],
	"racao": [
		["Sabor Artificial de Atum", "0% atum, 100% sabor de atum. A diferença se chama margem de lucro."],
		["Embalagem Família Menor", "Mesmo preço, 30% menos ração. Chamamos de 'reduflação' para soar técnico."],
		["Influencer Pet", "Um gato com 3M de seguidores diz que ama. Ele nunca comeu a ração."],
		["Lobby Nutricional", "A pirâmide alimentar felina agora tem ração no topo, no meio e na base."],
	],
	"miaucoin": [
		["Whitepaper Bonito", "40 páginas de buzzwords e um gráfico subindo. Investidores choram de emoção."],
		["Pump & Dump", "Compra, hypa, vende. Repete até a CVM acordar."],
		["Lastro em Vibes", "A moeda vale o quanto você acredita. E você acredita MUITO."],
		["NFT do Bean", "Um JPEG do Bean vendido 12 vezes para a mesma pessoa."],
	],
}

# Upgrades especiais (clique e globais)
#   click_flat    → +valor fixo por clique
#   click_percent → +% do CPS por clique
#   global_mult   → ×valor em toda produção
const SPECIAL_UPGRADES: Array[Dictionary] = [
	{
		"id": "click_1", "name": "Dedo Biônico", "short_effect": "+1 por clique",
		"desc": "Prótese ergonômica contra LER. O plano de saúde não cobre, mas o Bean parcelou pra você.",
		"icon": "res://images/BeansMining.png", "price": 100.0, "type": "click_flat", "value": 1.0,
		"req_building": "mini_bean", "req_count": 1,
	},
	{
		"id": "click_2", "name": "Dedo de Titânio", "short_effect": "+1 por clique",
		"desc": "Reforço cibernético de alta liga. Cada clique atinge a tela com a força de uma prensa hidráulica.",
		"icon": "res://images/BeansMining.png", "price": 500.0, "type": "click_flat", "value": 1.0,
		"req_building": "mini_bean", "req_count": 1,
	},
	{
		"id": "click_3", "name": "Toque de Midas", "short_effect": "+5% do CPS por clique",
		"desc": "O Bean abençoou sua mão. Cada clique converte renda passiva em lucro imediato.",
		"icon": "res://images/BeansCoins.png", "price": 10_000.0, "type": "click_percent", "value": 0.05,
		"req_building": "mini_bean", "req_count": 10,
	},
	{
		"id": "click_4", "name": "Mouse Banhado a Ouro", "short_effect": "+5% do CPS por clique",
		"desc": "Não clica melhor. Mas você se sente superior clicando, e isso é o que importa.",
		"icon": "res://images/BeansCoins.png", "price": 5_000_000.0, "type": "click_percent", "value": 0.05,
		"req_building": "fabrica", "req_count": 10,
	},
	{
		"id": "rainbow", "name": "Bean Cósmico", "short_effect": "x1.5 CPS global + Operários Neon",
		"desc": "A mente do Bean transcende a economia terrena. Todos os operários brilham em neon psicodélico.",
		"icon": "res://images/BeansRainbow.png", "price": 50_000.0, "type": "global_mult", "value": 1.5,
		"req_building": "mini_bean", "req_count": 10, "rainbow": true,
	},
	{
		"id": "reforma", "name": "Reforma Trabalhista", "short_effect": "x1.25 CPS global",
		"desc": "Flexibiliza direitos até eles virarem um conceito abstrato. Os estagiários aplaudem (obrigatório).",
		"icon": "res://images/fabrica.png", "price": 10_000_000.0, "type": "global_mult", "value": 1.25,
		"req_building": "fabrica", "req_count": 15,
	},
	{
		"id": "terceirizacao", "name": "Terceirização Total", "short_effect": "x1.5 CPS global",
		"desc": "Ninguém mais trabalha para o Bean. Todo mundo trabalha para uma empresa que trabalha para o Bean.",
		"icon": "res://images/stock_tesouro.png", "price": 2_000_000_000.0, "type": "global_mult", "value": 1.5,
		"req_building": "banco", "req_count": 15,
	},
]

# ══════════════════════════════════════
# FALÊNCIA DECLARADA (Prestígio)
# ══════════════════════════════════════
const PRESTIGE_BASE: float = 1_000_000.0       # 1º Fundo Offshore com 1M produzido na vida
const PRESTIGE_PER_FUND: float = 0.02          # +2% CPS por Fundo Offshore (total histórico)
const PRESTIGE_PER_BANKRUPTCY: float = 0.05    # +5% CPS por falência ("Agressividade Corporativa")
const ACHIEVEMENT_BONUS: float = 0.01          # +1% CPS por conquista ("Prestígio de LinkedIn")

# Benefícios Executivos: comprados com Fundos Offshore, permanentes.
const CEO_PERKS: Array[Dictionary] = [
	{"id": "heranca", "name": "Herança do Papai", "cost": 1,
		"effect": "Começa cada carreira com 25.000 moedas e o cassino já liberado.",
		"flavor": "Self-made man. Com uma pequena ajuda de 25 mil."},
	{"id": "dedo_ceo", "name": "Dedo do CEO", "cost": 2,
		"effect": "Cliques valem +3% do CPS.",
		"flavor": "Um clique seu vale mais que o mês de um estagiário. Literalmente."},
	{"id": "demissao", "name": "Demissão em Massa", "cost": 3,
		"effect": "Estruturas custam 10% menos.",
		"flavor": "Reestruturação estratégica de capital humano. Tradução: rua."},
	{"id": "paraiso", "name": "Paraíso Fiscal", "cost": 3,
		"effect": "Renda offline sobe de 25% para 75%, com limite de 8h (era 2h).",
		"flavor": "Seu dinheiro trabalha enquanto você dorme. Nas Ilhas Cayman."},
	{"id": "amigo_agiota", "name": "Amigo do Agiota", "cost": 4,
		"effect": "Juros do Jeff Meowzos pela metade e limite de crédito em dobro.",
		"flavor": "Vocês jogam sinuca juntos. Ele ainda te cobra, mas com carinho."},
	{"id": "monopolio", "name": "Monopólio", "cost": 4,
		"effect": "Melhorias custam 25% menos.",
		"flavor": "Concorrência é para quem não tem amigos no CADE."},
	{"id": "lobby", "name": "Lobby em Brasília", "cost": 6,
		"effect": "x1.25 em toda a produção.",
		"flavor": "Um jantar, três emendas e uma lei com o seu nome."},
	{"id": "bailout", "name": "Socorro Estatal", "cost": 6,
		"effect": "Se o saldo zerar, o governo deposita 10 min de CPS (recarga de 10 min).",
		"flavor": "Lucros privados, prejuízos públicos."},
	{"id": "crupie", "name": "Crupiê Subornado", "cost": 8,
		"effect": "+3% em todos os prêmios do cassino.",
		"flavor": "Ele ainda trabalha para a casa. Só que agora também trabalha para você."},
	{"id": "calote", "name": "Calote Profissional", "cost": 10,
		"effect": "Na inadimplência, o Jeff Meowzos só leva o caixa. Suas estruturas ficam.",
		"flavor": "Seu CPF já é tão sujo que virou CNPJ."},
	{"id": "paraquedas", "name": "Paraquedas Dourado", "cost": 12,
		"effect": "Ao declarar falência, mantém 10% de cada estrutura.",
		"flavor": "A empresa afundou. Você saiu de jatinho."},
]

# Títulos do CEO por número de falências
const CEO_TITLES: Array = [
	[0, "Gerente de Cultivo"],
	[1, "CEO Recém-Falido"],
	[2, "CEO Reincidente"],
	[3, "Empreendedor Serial"],
	[5, "Magnata Laranja"],
	[8, "Too Big To Fail"],
	[12, "Entidade Offshore"],
	[20, "O Próprio Mercado"],
]

# ══════════════════════════════════════
# RENDA OFFLINE
# ══════════════════════════════════════
const OFFLINE_RATE_BASE: float = 0.25
const OFFLINE_RATE_PERK: float = 0.75
const OFFLINE_CAP_BASE: float = 2.0 * 3600.0
const OFFLINE_CAP_PERK: float = 8.0 * 3600.0
const OFFLINE_MIN_SECONDS: float = 60.0

# ══════════════════════════════════════
# CONQUISTAS (+1% CPS cada)
# ══════════════════════════════════════
const ACHIEVEMENTS: Dictionary = {
	"up_click": {"name": "Dedo Mais Rápido do Oeste", "desc": "Comprou o primeiro upgrade de clique."},
	"up_rainbow": {"name": "Consciência Cósmica", "desc": "Comprou o lendário Bean Cósmico."},
	"count_20": {"name": "O Começo do Exército", "desc": "Alcançou 20 estruturas ativas."},
	"count_40": {"name": "Exploração de Mão de Obra", "desc": "Alcançou 40 estruturas ativas."},
	"count_60": {"name": "Monopólio de Felinos", "desc": "Alcançou 60 estruturas ativas."},
	"count_80": {"name": "Capitalismo Tardio", "desc": "Alcançou 80 estruturas ativas."},
	"count_100": {"name": "Domínio Absoluto do Capital", "desc": "Alcançou 100 estruturas ativas."},
	"count_200": {"name": "Acúmulo Primitivo", "desc": "Alcançou 200 estruturas ativas."},
	"earn_1m": {"name": "Primeiro Milhão", "desc": "Produziu 1 milhão de moedas. Com muito esforço (dos outros)."},
	"earn_1b": {"name": "Bilionário Self-Made", "desc": "Produziu 1 bilhão de moedas. Merecimento puro."},
	"prestige_1": {"name": "Falência Estratégica", "desc": "Declarou falência pela primeira vez."},
	"prestige_3": {"name": "CNPJ Descartável", "desc": "Declarou falência 3 vezes."},
	"prestige_10": {"name": "Falir é um Estilo de Vida", "desc": "Declarou falência 10 vezes."},
	"perk_1": {"name": "Benefício Executivo", "desc": "Comprou seu primeiro benefício de CEO."},
	"bet_first": {"name": "Primeira Fézinha", "desc": "Fez a primeira aposta no cassino."},
	"bet_100": {"name": "Cliente Fidelizado", "desc": "Fez 100 apostas. O Jeff Meowzos mandou flores."},
	"bet_jackpot": {"name": "Jackpot Felino", "desc": "Tirou 3 símbolos iguais no Caça-Níquel."},
	"bet_crash_high": {"name": "Piloto Espacial", "desc": "Sacou no Foguetinho acima de 5.00x."},
	"bet_twenty_one": {"name": "Ás do Baralho", "desc": "Fez um Blackjack natural no 21."},
	"bet_allin_win": {"name": "Tudo ou Nada", "desc": "Apostou tudo e ganhou. Nunca mais faça isso. (Faça.)"},
	"bet_allin_lose": {"name": "Tudo ou Nada (Nada)", "desc": "Apostou tudo e perdeu tudo. Clássico."},
	"bet_rat_longshot": {"name": "Zebra na Pista", "desc": "Ganhou apostando no rato menos cotado."},
	"bet_pyramid_top": {"name": "Topo da Pirâmide", "desc": "Completou os 10 níveis da pirâmide. Alguém lá embaixo pagou."},
	"bet_scratch_big": {"name": "Imposto do Otimismo", "desc": "Tirou 50x ou mais na raspadinha."},
	"bet_roulette_number": {"name": "Na Mosca", "desc": "Acertou o número exato na roleta."},
	"loan_first": {"name": "Pré-Aprovado", "desc": "Pegou o primeiro empréstimo com o Jeff Meowzos."},
	"loan_paid": {"name": "Bom Pagador", "desc": "Quitou um empréstimo. O Jeff Meowzos ficou decepcionado."},
	"loan_default": {"name": "Nome Sujo no SPC Felino", "desc": "Deu calote no Jeff Meowzos. Ele lembra."},
	"bailout": {"name": "Socorro, Governo!", "desc": "Foi resgatado com dinheiro público."},
	"fish_first": {"name": "Primeira Fisgada", "desc": "Pescou o primeiro peixe. Agora você é do agronegócio aquático."},
	"fish_legend": {"name": "Peixe Grande", "desc": "Fisgou um peixe Corporativo. Ele tentou te contratar no barco."},
	"fish_seller": {"name": "Atravessador", "desc": "Vendeu 50 peixes. O Jeff ficou com 10% de cada um."},
	"click_exec": {"name": "Clique Executivo", "desc": "Deu um clique executivo (x8). Trabalhou uma vez e chamou de liderança."},
}

# ══════════════════════════════════════
# MANCHETES DO JORNAL (ticker)
# ══════════════════════════════════════
const HEADLINES: Array[String] = [
	"Mini Beans entram no 3º turno; sindicato é convertido em sala de descompressão com pufe.",
	"Economista felino garante: 'a riqueza vai escorrer para baixo a qualquer momento agora'.",
	"Jeff Meowzos lança empréstimo com juros de 15% ao MINUTO: 'É para democratizar a dívida'.",
	"Pesquisa: 9 em cada 10 estagiários acreditam que serão efetivados. O décimo é realista.",
	"Bolsa Felina sobe 3% após anúncio de demissão de 4 mil gatos. Mercado comemora.",
	"Coach quântico ensina: 'Se você está pobre é porque não visualizou a riqueza direito'.",
	"Fazendeiro Felino trabalha 16h por dia e é eleito 'Exemplo de Resiliência' pela 5ª vez.",
	"Raspadinha bate recorde de vendas entre quem mais precisa de dinheiro. Coincidência.",
	"Bean compra 3º iate. 'É um investimento em mobilidade urbana', explica assessoria.",
	"Startup promete 'Uber dos estagiários'. Estagiários agora pagam para trabalhar.",
	"Governo corta verba da educação e abre 12 novos cassinos: 'Matemática se aprende na prática'.",
	"MiauCoin cai 90% em 4 minutos. Especialistas: 'Ótima hora para comprar mais'.",
	"Estudo revela que dormir é 'ócio improdutivo'. Mini Beans recebem cafeína intravenosa.",
	"Banco do Bean anuncia lucro recorde e taxa nova: cobrança por respirar perto da agência.",
	"Gato herdeiro de 23 anos dá palestra sobre meritocracia. Ingresso: 3 salários mínimos.",
	"Ração Ultraprocessada S.A. reduz atum para 0%. Embalagem agora diz 'inspirada em atum'.",
	"Falência vira tendência entre CEOs: 'Quebrar a empresa é o novo MBA', diz consultoria.",
	"Mineiros pedem capacete; diretoria oferece 'workshop de mentalidade resistente a impactos'.",
	"Pirâmide financeira felina é rebatizada de 'Marketing Multinível de Impacto'. Agora é legal.",
	"Índice de felicidade dos estagiários sobe após a instalação de uma mesa de pingue-pongue.",
	"Jeff Meowzos é eleito 'Empreendedor do Ano' pela Associação Brasileira de Agiotas.",
	"Sindicato dos Mini Beans pede aumento; Bean responde com post motivacional no LinkedIn.",
	"Cassino Clandestino é declarado 'patrimônio cultural' após doação generosa a vereadores.",
	"'Trabalhe enquanto eles dormem', diz o Bean, que acordou às 14h.",
	"Relatório: o 1% mais rico dos gatos tem 99% dos arranhadores. 'Natural', dizem os 1%.",
	"Nova lei permite pagar estagiários em 'experiência' e 'networking'. Mercado aprova.",
	"Corrida de Ratos é suspensa após o Herdeiro Nepo largar 30 metros à frente. De novo.",
	"Inflação da ração chega a 40%. Governo recomenda 'comer menos e sorrir mais'.",
	"Ex-falido abre curso 'Como Falir Rico'. Turma esgota em 3 minutos.",
	"Robô substitui 300 gatos na fábrica. Bean: 'Nenhum emprego foi perdido, só reposicionado'.",
	"Jeff Meowzos compra o lago municipal e cobra pedágio dos peixes que entram.",
	"Sardinha CLT é promovida a Sardinha PJ. Perde o vale-alimentação, ganha 'autonomia'.",
	"Baleia Bilionária é avistada no Lago da Liquidez. Índice da bolsa oscila 3%.",
]
