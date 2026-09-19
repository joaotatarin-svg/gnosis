extends Node
## GNOSE — o sistema que ENSINA o gnosticismo ao jogador (estilo God of War /
## Mímir): Estelas de lore espalhadas pelas telas, conversa de caminhada
## (legendas sem pausar o jogo) e o caderno "Crônicas" (entradas desbloqueadas,
## persistem entre runs em user://chronicles.json). Autoload `Gnosis`.
##
## CONTRATO com o Level (scripts/levels/level.gd chama estes três métodos):
##  - setup_screen(level, screen, rest_points): no fim do _ready do Level, antes
##    das waves. `rest_points` = posições no mundo (pés no chão, y ≈ 298) dos
##    descansos entre zonas de combate, da esquerda pra direita. Aqui entram a
##    Estela da tela e a legenda de chegada.
##  - zone_started(screen, zone, total): waves de uma zona nasceram.
##  - zone_cleared(screen, zone, total): a zona foi limpa (zone == total-1 =
##    tela limpa). Hora da conversa de caminhada.
## Além disso: boss_card(id, screen) (letterbox ao nascer o chefe) e a API das
## Crônicas: chronicles_count() / chronicles_total() / unlock(id) / is_unlocked(id).
##
## PEDAGOGIA: as 18 Estelas contam o mito na ordem dos textos antigos (Mônada →
## Pleroma → Sophia → o Cego → Kenoma → Arcontes → barro e faísca → gnose →
## fontes históricas → Chamado → retorno). Elas dão a versão do PLEROMA; a Voz
## (que é o Demiurgo — segredo até a tela 64) conta a mesma cosmologia com o
## viés dela nas legendas. O jogador aprende pela contradição.

const SAVE_PATH := "user://chronicles.json"

## As 18 Estelas: id · tela · Éon · título · linhas · fonte histórica · dica
## (onde fica, mostrada trancada nas Crônicas).
const STELAS: Array = [
	{"id": "monada", "screen": 1, "eon": "O Limiar", "title": "A Mônada, o Inefável",
		"lines": [
			"Antes dos mundos, antes de o tempo contar, havia o Um.",
			"Não tinha nome, porque nome é limite; não tinha forma, porque forma é fronteira.",
			"Os antigos o chamavam Mônada, Pai invisível, Abismo, Silêncio.",
			"Não era vazio: era plenitude tão inteira que nada lhe faltava.",
			"Deste Silêncio tudo emanou — não por ordem, mas por transbordar.",
			"Quem acorda no Kenoma acorda longe dele. Mas não fora dele.",
		],
		"source": "Apócrifo de João (NHC II,1); Evangelho da Verdade (NHC I,3).",
		"hint": "O Limiar, à esquerda das cinzas onde acordaste."},
	{"id": "pleroma", "screen": 3, "eon": "Torpor", "title": "O Pleroma e os Éons",
		"lines": [
			"Do Um saiu o Pensamento; e do Pensamento, os pares: Mente e Verdade, Palavra e Vida, Homem e Igreja.",
			"Cada par era um Éon: não um lugar, mas uma idade da Luz, uma face do Inefável.",
			"Juntos formavam o Pleroma — a Plenitude — onde nada dorme e nada esquece.",
			"Os Éons não foram feitos: emanaram, como o calor emana do fogo.",
			"Os sete andares que sobes também se chamam Éons. É uma paródia.",
			"O Torpor não é um Éon. É o que resta quando um Éon se esquece de si.",
		],
		"source": "Irineu, Contra as Heresias I,1 (o sistema valentiniano); Apócrifo de João.",
		"hint": "Torpor, na segunda travessia, entre as zonas."},
	{"id": "sophia", "screen": 8, "eon": "Torpor", "title": "Sophia, a Sabedoria",
		"lines": [
			"O último dos Éons, o mais jovem, chamava-se Sophia: Sabedoria.",
			"Ela quis conhecer a Fonte sozinha — sem o par que a equilibrava, sem o consentimento do Todo.",
			"Não foi só orgulho. Foi amor sem medida: a vontade de ver o Pai de frente.",
			"Do desejo sem par nasceu algo que não devia nascer. Ela olhou para o que gerou... e o escondeu numa nuvem.",
			"Dizem os textos que ela chorou, e das lágrimas veio a água; do riso, a luz; do medo, a matéria.",
			"Todo torpor começa assim: alguém amou tanto que esqueceu de si.",
		],
		"source": "Apócrifo de João (NHC II,1, 9–10); Irineu I,2–4; Hipólito, Refutação VI.",
		"hint": "Torpor, na travessia antes da antessala de Athoth."},
	{"id": "cego", "screen": 12, "eon": "Fome", "title": "O Aborto Cego",
		"lines": [
			"O filho de Sophia nasceu sem par e sem forma: cabeça de leão, corpo de serpente, olhos de fogo.",
			"Ela o chamou Yaldabaoth. Os textos o chamam também Saklas, o Tolo, e Samael, o deus cego.",
			"Cego porque nunca viu o Pleroma de onde a mãe veio. Cego porque acreditou ser o único.",
			"'Eu sou deus e não há outro além de mim', gritou — e o grito era ignorância, não poder.",
			"Roubou da mãe uma parcela de luz e com ela fez um mundo à sua imagem: cego.",
			"A Fome é o primeiro sinal de um deus cego: precisa de tudo e nada o enche.",
		],
		"source": "Apócrifo de João (NHC II,1, 10–11); Hipóstase dos Arcontes (NHC II,4).",
		"hint": "Fome, na travessia logo após a chegada aos mercados."},
	{"id": "kenoma", "screen": 15, "eon": "Fome", "title": "O Kenoma e a Hyle",
		"lines": [
			"Pleroma quer dizer plenitude. Kenoma quer dizer vazio, deficiência, falta.",
			"Não é o nada: é o cheio que nunca satisfaz. Um mercado sem fim onde ninguém se alimenta.",
			"A matéria — hyle — nasceu das paixões de Sophia: da tristeza, do medo, da perplexidade.",
			"Por isso o mundo pesa. Por isso a carne tem fome. Não por culpa: por origem.",
			"Os gnósticos não odiavam o corpo. Reconheciam nele o luto de uma mãe.",
			"Quem come no Kenoma come sombra de pão. Quem lembra já provou o pão de verdade.",
		],
		"source": "Irineu I,4–5; Evangelho da Verdade (NHC I,3).",
		"hint": "Fome, no santuário do Campeão."},
	{"id": "arcontes", "screen": 17, "eon": "Fome", "title": "Os Sete Arcontes e as Esferas",
		"lines": [
			"Yaldabaoth gerou sete governantes — arcontes — à sua semelhança, e a cada um deu um céu.",
			"Sete céus, sete esferas: os sete astros errantes que os antigos viam girar — Lua, Mercúrio, Vênus, Sol, Marte, Júpiter, Saturno.",
			"Athoth, Harmas, Galila, Yabel, Astaphaios, Belias, Armupiel: assim os nomeia o Apócrifo de João.",
			"Cada um guarda uma porta; cada porta cobra uma paixão: o sono, a fome, a lei, o silêncio, o reflexo, a podridão, a coroa.",
			"Não são demônios. São funcionários de um engano — e todo funcionário sonha com o cargo do chefe.",
			"Quem sobe as sete esferas devolve a cada arconte o que ele exigiu. E sai mais leve.",
		],
		"source": "Apócrifo de João (NHC II,1, 10–12); Orígenes, Contra Celso VI (a escada dos ofitas).",
		"hint": "Fome, na travessia depois do santuário."},
	{"id": "heimarmene", "screen": 21, "eon": "Corrente", "title": "Heimarmene, o Destino em Corrente",
		"lines": [
			"Os arcontes fizeram o Destino — Heimarmene — e o amarraram aos astros.",
			"Cada nascimento sob um signo; cada vida numa órbita; cada morte no dia marcado.",
			"'É a mais pesada das correntes', diz o Apócrifo, 'e por ela deuses, anjos e homens foram presos.'",
			"A lei deste Éon é essa corrente: bela, polida — e ainda corrente.",
			"A gnose não nega os astros. Nega que eles tenham a última palavra.",
			"Quem lembra de onde veio não pertence a signo nenhum.",
		],
		"source": "Apócrifo de João (NHC II,1, 28); Excertos de Teódoto 69–78.",
		"hint": "Corrente, na travessia logo após os primeiros selos."},
	{"id": "barro", "screen": 25, "eon": "Corrente", "title": "O Homem de Barro e a Faísca",
		"lines": [
			"Os arcontes viram na água o reflexo do Homem perfeito e quiseram copiá-lo.",
			"Fizeram um corpo de barro — a imagem — mas ele não se erguia: rastejava, sem alma, como um verme.",
			"Então Sophia agiu por astúcia: fez o Cego soprar no barro a luz que ele havia roubado dela.",
			"E o homem ergueu-se, mais luminoso que seus criadores. Os arcontes tiveram inveja — e o lançaram no fundo da matéria.",
			"Cada pessoa carrega essa faísca: um pedaço da Luz que o carcereiro não quis dar, e deu.",
			"A corrente prende o barro. Nunca prendeu a faísca.",
		],
		"source": "Apócrifo de João (NHC II,1, 15–20); Hipóstase dos Arcontes (NHC II,4).",
		"hint": "Corrente, na travessia entre as duas últimas zonas."},
	{"id": "gnose", "screen": 30, "eon": "Silêncio", "title": "A Gnose: saber é lembrar",
		"lines": [
			"Gnose não é crença. Não é obra. É conhecimento — do tipo que se tem de um rosto amado, não de uma fórmula.",
			"Conhecer quem tu eras, onde estavas, para onde foste lançada e de onde deves voltar.",
			"'Quem conhece a si mesmo conhece o Todo', dizem os textos. O caminho não sobe: volta.",
			"Por isso o Silêncio é o Éon mais perigoso: não se pode lembrar do que foi apagado.",
			"Mas a faísca não esquece. Só espera que alguém lhe pergunte o nome.",
		],
		"source": "Evangelho da Verdade (NHC I,3); Excertos de Teódoto 78; Evangelho de Tomé 3.",
		"hint": "Silêncio, nas primeiras estantes vazias."},
	{"id": "nag_hammadi", "screen": 33, "eon": "Silêncio", "title": "Nag Hammadi, 1945",
		"lines": [
			"Durante mil e seiscentos anos, quase tudo que se sabia dos gnósticos vinha dos seus inimigos.",
			"Em dezembro de 1945, perto de Nag Hammadi, no Egito, um camponês chamado Muhammad Ali al-Samman cavava adubo e achou um jarro.",
			"Dentro: treze códices de papiro, encadernados em couro, escritos em copta no século IV.",
			"Cinquenta e dois textos. O Apócrifo de João. O Evangelho de Tomé. O Evangelho da Verdade. A Hipóstase dos Arcontes.",
			"Algumas páginas foram queimadas no forno da mãe dele antes que alguém percebesse o que eram.",
			"Uma biblioteca inteira ficou em silêncio no barro por dezesseis séculos. E ainda assim falou.",
		],
		"source": "História da descoberta (James M. Robinson, The Nag Hammadi Library, 1977).",
		"hint": "Silêncio, no santuário do Campeão."},
	{"id": "apocrifo", "screen": 35, "eon": "Silêncio", "title": "O Apócrifo de João",
		"lines": [
			"É o mito completo, do Um ao homem, contado como revelação a João, filho de Zebedeu.",
			"Sobreviveu em quatro cópias — três em Nag Hammadi, uma em Berlim — sinal de que era muito lido.",
			"Nele o Salvador conta a João a origem de Yaldabaoth, os nomes dos arcontes, a criação de Adão e a corrente do Destino.",
			"E termina com uma promessa: quem lembrar será recolhido; quem esquecer tornará a nascer até lembrar.",
			"Escrito antes de 180 d.C. — Irineu já o cita para combatê-lo. O combate o preservou.",
			"As páginas em branco deste Éon são o que restaria sem o jarro. Lê enquanto podes.",
		],
		"source": "NHC II,1 / III,1 / IV,1; Códice de Berlim (BG 8502,2).",
		"hint": "Silêncio, na travessia antes da antessala de Yabel."},
	{"id": "pistis", "screen": 39, "eon": "Espelho", "title": "Pistis Sophia e os Arrependimentos",
		"lines": [
			"Há um livro em que Sophia, caída no caos, canta treze arrependimentos.",
			"Ela olhou para baixo, viu uma luz refletida nas águas e pensou que era a Luz de cima. Desceu atrás do reflexo.",
			"Os arcontes a cercaram. Ela cantou: 'Ó Luz das luzes, em quem confiei desde o princípio, ouve-me.'",
			"Cada canto é respondido com um salmo; cada salmo é lido como uma chave.",
			"Sophia não é salva por força. É salva por lembrar a quem chamar.",
			"O Espelho deste Éon é a água daquela queda. O reflexo não é ela. Nunca foi.",
		],
		"source": "Pistis Sophia (Códice Askew, séc. IV), livros I–II.",
		"hint": "Espelho, na travessia logo após as águas paradas."},
	{"id": "mestres", "screen": 43, "eon": "Espelho", "title": "Valentino e Basílides",
		"lines": [
			"Nem todos os gnósticos foram anônimos. Dois nomes se ergueram em Alexandria e Roma no século II.",
			"Basílides ensinou um Deus que 'não é' — tão além do ser que nem 'existir' se pode dizer dele. Dele emanaram 365 céus.",
			"Valentino, poeta e mestre, quase foi bispo de Roma. Sua escola espalhou o mito de Sophia pelo Mediterrâneo.",
			"Para os valentinianos havia três naturezas: a matéria, que se dissolve; a alma, que escolhe; o espírito, que retorna.",
			"Ambos foram chamados hereges. Ambos escreveram evangelhos, salmos e cartas — quase tudo perdido.",
			"O que sabemos deles é um reflexo nas palavras de quem os combateu. Mesmo assim, brilha.",
		],
		"source": "Irineu, Contra as Heresias I; Clemente de Alexandria, Stromata; Hipólito VII.",
		"hint": "Espelho, na travessia depois do santuário."},
	{"id": "tome", "screen": 48, "eon": "Praga", "title": "O Evangelho de Tomé",
		"lines": [
			"'Estas são as palavras secretas que Jesus, o vivo, disse, e Dídimo Judas Tomé escreveu.'",
			"Cento e catorze ditos. Sem nascimento, sem milagres, sem cruz — só a voz, e o ouvido de quem entende.",
			"'O Reino está dentro de vós e fora de vós. Quando vos conhecerdes, sereis conhecidos.'",
			"'Se trouxerdes à luz o que está dentro de vós, isso vos salvará. Se não, isso vos destruirá.'",
			"'O Reino do Pai está espalhado sobre a terra, e os homens não o veem.'",
			"Na Praga tudo apodrece por fora. O dito de Tomé pergunta o que apodrece por dentro.",
		],
		"source": "Evangelho de Tomé (NHC II,2), lógia 1, 3, 70 e 113.",
		"hint": "Praga, na travessia logo após a chegada ao pântano."},
	{"id": "perola", "screen": 52, "eon": "Praga", "title": "O Hino da Pérola",
		"lines": [
			"Um príncipe do Oriente é enviado ao Egito para buscar uma pérola guardada por uma serpente.",
			"Os pais tiram-lhe o manto de luz e prometem: 'Quando voltares com a pérola, o vestirás de novo.'",
			"No Egito ele come a comida deles, veste as roupas deles — e esquece. Esquece a pérola, esquece o rei, esquece o próprio nome.",
			"Então uma carta voa até ele em forma de águia e fala: 'Lembra-te de que és filho de reis. Lembra-te da pérola.'",
			"Ele acorda, encanta a serpente, toma a pérola e sobe. O manto vem ao seu encontro — e ele se reconhece nele.",
			"O veneno deste pântano é a comida do Egito. A carta é qualquer coisa que te faça lembrar.",
		],
		"source": "Atos de Tomé 108–113 (o 'Hino da Pérola', séc. III).",
		"hint": "Praga, na travessia depois do santuário."},
	{"id": "chamado", "screen": 57, "eon": "Coroa", "title": "O Chamado e o Despertar",
		"lines": [
			"Todos os textos concordam num ponto: a faísca não acorda sozinha. Algo a chama.",
			"'Levanta-te, tu que dormes, e lembra-te.' A frase ecoa dos mandeus aos maniqueus, de Tomé ao Apócrifo.",
			"O Chamado vem de fora do Kenoma — de um Éon que desce disfarçado, de uma carta, de uma dor que rompe o feitiço.",
			"Quem chama não pode subir por ti. Só pode lembrar-te de que há subida.",
			"Desconfia da voz que chama e depois não solta.",
			"A Coroa deste Éon espera um rei. O Despertar espera que ninguém sente.",
		],
		"source": "Apócrifo de João (hino final, NHC II,1, 30–31); Evangelho da Verdade 22.",
		"hint": "Coroa, na travessia logo após os tronos vazios."},
	{"id": "docetismo", "screen": 61, "eon": "Coroa", "title": "Docetismo: o corpo aparente",
		"lines": [
			"Alguns gnósticos ensinavam que o Salvador desceu ao Kenoma só em aparência — dokein, 'parecer'.",
			"Sem carne verdadeira, nada de matéria o tocava; a cruz, para eles, foi um véu, não uma ferida.",
			"Outros discordaram com força: se ele não sofreu de verdade, o que salvou de verdade?",
			"A disputa durou séculos, e não é preciso tomar partido para ouvi-la.",
			"Ela pergunta o que este Éon pergunta: se o corpo é aparência, por que a dor é tão real?",
			"O corpo que lê esta pedra sangra. Talvez a resposta esteja no sangue.",
		],
		"source": "Irineu I,24 (Basílides); Segundo Tratado do Grande Set (NHC VII,2); Apocalipse de Pedro (NHC VII,3).",
		"hint": "Coroa, na travessia entre as duas últimas zonas."},
	{"id": "retorno", "screen": 66, "eon": "O Centro", "title": "A Salvação como Retorno",
		"lines": [
			"Para o gnóstico, a salvação não é perdão nem prêmio. É retorno — apokatastasis — de cada faísca à Plenitude.",
			"Sophia, ao lembrar, é recebida de volta. Seu filho cego, dizem uns, é corrigido; dizem outros, dissolvido; outros ainda, deixado a reinar sobre um mundo cada vez mais vazio.",
			"'Quem tiver ouvidos, ouça. O fim está onde o princípio está', diz Tomé.",
			"Ninguém volta sozinho: o Chamado vai buscando os que ainda dormem, um a um, até que o Kenoma se esvazie.",
			"Aqui no Centro não há voz, nem trono, nem coroa. Só o caminho de volta.",
			"Escolher como voltar — subir, sentar ou plantar — nunca coube a deus nenhum.",
		],
		"source": "Evangelho de Tomé 18; Tratado Tripartite (NHC I,5); Irineu I,7.",
		"hint": "O Centro, na segunda câmara de ecos."},
]

## Cards de chefe: nome grande + título (letterbox), por type_id.
const BOSS_TITLES: Dictionary = {
	"rei": {"name": "O REI", "title": "Guardião do Limiar"},
	"arconte_sono": {"name": "ATHOTH", "title": "Arconte do Torpor  ·  Primeira Esfera"},
	"arconte_fome": {"name": "HARMAS", "title": "Arconte da Fome  ·  Segunda Esfera"},
	"arconte_corrente": {"name": "GALILA", "title": "Arconte da Corrente  ·  Terceira Esfera"},
	"arconte_silencio": {"name": "YABEL", "title": "Arconte do Silêncio  ·  Quarta Esfera"},
	"arconte_espelho": {"name": "ASTAPHAIOS", "title": "Arconte do Espelho  ·  Quinta Esfera"},
	"arconte_praga": {"name": "BELIAS", "title": "Arconte da Praga  ·  Sexta Esfera"},
	"arconte_coroa": {"name": "ARMUPIEL", "title": "Arconte da Coroa  ·  Sétima Esfera"},
	"rei_final": {"name": "O REI ENFRAQUECIDO", "title": "A Mentira  ·  Yaldabaoth"},
	"colosso": {"name": "O COLOSSO OCO", "title": "A Verdade  ·  Yaldabaoth"},
	"demiurgo": {"name": "YALDABAOTH", "title": "O Rei enfraquecido e o Colosso Oco  ·  as duas faces"},
}

var unlocked: Array = []          # ids das Crônicas lidas (persistem entre runs)
var _caption: CaptionBar
var _by_screen: Dictionary = {}   # tela -> Estela


func _ready() -> void:
	for e in STELAS:
		_by_screen[int(e.screen)] = e
	_load()
	_caption = CaptionBar.new()
	add_child(_caption)


# --- Crônicas (API pública) ---------------------------------------------------

func chronicles_count() -> int:
	return unlocked.size()


func chronicles_total() -> int:
	return STELAS.size()


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


## Desbloqueia e salva. Retorna true se era inédita.
func unlock(id: String) -> bool:
	if id == "" or unlocked.has(id):
		return false
	unlocked.append(id)
	_save()
	return true


func entries() -> Array:
	return STELAS


func entry(id: String) -> Dictionary:
	for e in STELAS:
		if String(e.id) == id:
			return e
	return {}


func stela_for_screen(screen: int) -> Dictionary:
	return _by_screen.get(screen, {})


func _load() -> void:
	unlocked.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		for id in data.get("unlocked", []):
			if entry(String(id)).size() > 0 and not unlocked.has(String(id)):
				unlocked.append(String(id))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": 1, "unlocked": unlocked}))
	f.close()


# --- contrato com o Level -----------------------------------------------------

func setup_screen(level: Node2D, screen: int, rest_points: Array) -> void:
	_caption.clear()
	var e := stela_for_screen(screen)
	if not e.is_empty() and not rest_points.is_empty() and level != null:
		var s := Stela.new()
		s.entry = e
		level.add_child(s)
		s.global_position = _stela_pos(screen, rest_points)
	# Legenda de chegada: uma vez por run (com checkpoint a tela recarrega).
	if Narrative.once("walk_a_%d" % screen):
		_caption.say_lines(Narrative.walk_arrival(screen))


## Onde a Estela fica: num descanso ENTRE zonas quando há (o jogador passa por
## ele obrigatoriamente), 200 px à esquerda do centro do descanso — longe do
## baú (+40), do Adormecido (-90 no descanso 0) e dos Selos (+170 no último).
## Tela de 1 zona (chefe, desafio, antessala, Centro): à direita do descanso 0,
## visível já na chegada.
func _stela_pos(screen: int, rest_points: Array) -> Vector2:
	if rest_points.size() >= 2:
		var idx := 1 + (screen % (rest_points.size() - 1))
		return rest_points[idx] + Vector2(-200.0, 0.0)
	return rest_points[0] + Vector2(150.0, 0.0)


func zone_started(_screen: int, _zone: int, _total: int) -> void:
	pass


func zone_cleared(screen: int, zone: int, _total: int) -> void:
	if Narrative.once("walk_c_%d_%d" % [screen, zone]):
		_caption.say_lines(Narrative.walk_cleared(screen, zone))


## Fala avulsa (outros sistemas podem usar).
func caption(speaker: String, text: String) -> void:
	_caption.say(speaker, text)


## Card de chefe ao nascer: id do Bestiário ("rei", "arconte_sono", ...,
## "demiurgo" na batalha dupla) ou "campeao" (Desafio do Éon).
func boss_card(id: String, screen: int) -> void:
	if id == "campeao":
		var n := RunManager.eon_name(screen)
		var fem := n in ["Fome", "Corrente", "Praga", "Coroa"]
		Cinematic.boss_card("O CAMPEÃO", "Guardião do santuário %s %s" % ["da" if fem else "do", n])
		return
	var t: Dictionary = BOSS_TITLES.get(id, {})
	if t.is_empty():
		return
	Cinematic.boss_card(String(t.name), String(t.title))
