extends Node
## GNOSE — o sistema que ENSINA o gnosticismo ao jogador (estilo God of War /
## Mímir): Estelas de lore espalhadas pelas telas, conversa de caminhada
## (legendas sem pausar o jogo) e o caderno "Crônicas" (entradas desbloqueadas,
## persistem entre runs em user://chronicles.json). Autoload `Gnosis`.
##
## CONTRATO com o Level (scripts/levels/level.gd chama estes três métodos):
##  - setup_screen(level, screen, rest_points): no fim do _ready do Level, antes
##    das waves. `rest_points` = posições no mundo (pés no chão, y ≈ 298) dos
##    descansos entre zonas de combate, da esquerda para a direita. Aqui entram a
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

## `var` só para as QAs gravarem em user://qa/ (REVISAO #9); o jogo não muda.
var SAVE_PATH: String = "user://chronicles.json"

## As 18 Estelas: id · tela · Éon · título · linhas · fonte histórica · dica
## (onde fica, mostrada trancada nas Crônicas).
const STELAS: Array = [
	{"id": "monada", "screen": 1, "eon": "O Limiar", "title": "A Mônada, o Inefável",
		"lines": [
			"Antes dos mundos, antes de o tempo contar, havia o Um.",
			"Não tinha nome, porque ninguém existia antes dele para nomeá-lo; não tinha medida, porque nada o limitava.",
			"O Apócrifo de João o chama Mônada, Espírito Invisível, Pai do Todo. Os valentinianos o chamavam Abismo, e ao seu Pensamento, Silêncio.",
			"Não era vazio: era uma plenitude tão inteira que nada lhe faltava.",
			"Dele tudo veio — não por ordem, mas por transbordar, como luz que não cabe em si.",
			"Quem acorda no Kenoma acorda longe dele. Mas não fora dele.",
		],
		"source": "Apócrifo de João (NHC II,1, 2–4); Irineu, Contra as Heresias I,1,1.",
		"hint": "O Limiar, perto das cinzas do despertar."},
	{"id": "pleroma", "screen": 3, "eon": "Torpor", "title": "O Pleroma e os Éons",
		"lines": [
			"Do Abismo e do seu Silêncio vieram Mente e Verdade; destes, Palavra e Vida; destes, Homem e Igreja.",
			"Cada um era um Éon — não um lugar, mas uma idade da Luz, uma face do Inefável. E os Éons vinham em pares: as sizígias.",
			"Trinta Éons, dizia a escola de Valentino, e juntos formavam o Pleroma, a Plenitude, onde nada dorme e nada esquece.",
			"Não foram fabricados: emanaram, como o calor emana do fogo.",
			"Os sete andares que sobes também se chamam Éons. É uma paródia.",
			"O Torpor não é um Éon. É o que resta quando um Éon se esquece de si.",
		],
		"source": "Irineu, Contra as Heresias I,1,1–3 (o sistema de Ptolomeu, discípulo de Valentino).",
		"hint": "Torpor · Travessia I, no descanso entre os combates."},
	{"id": "sophia", "screen": 8, "eon": "Torpor", "title": "Sophia, a Sabedoria",
		"lines": [
			"O último dos Éons, o mais jovem, chamava-se Sophia: Sabedoria.",
			"Para os valentinianos, ela quis compreender o Pai sozinha. Para o Apócrifo de João, quis gerar sem o consentimento do Espírito e sem o seu par.",
			"Não foi só soberba. Foi amor sem medida: a vontade de ver a Fonte de frente.",
			"Do desejo sem par nasceu algo que não devia nascer. Ela o afastou de si e o escondeu numa nuvem de luz, com um trono no meio, para que nenhum Éon o visse.",
			"Os valentinianos contavam que, caída, ela chorou: das lágrimas veio a água; do riso, a luz; da tristeza e do medo, a matéria.",
			"Todo torpor começa assim: alguém amou tanto que esqueceu de si.",
		],
		"source": "Apócrifo de João (NHC II,1, 9–10); Irineu I,2–4; Hipólito, Refutação VI,29–36.",
		"hint": "Torpor · Travessia V, antes da antessala de Athoth."},
	{"id": "cego", "screen": 12, "eon": "Fome", "title": "O Aborto Cego",
		"lines": [
			"O filho de Sophia nasceu disforme: aparência de serpente e de leão, olhos como relâmpagos de fogo.",
			"Ela o chamou Yaldabaoth. Os textos o chamam também Saklas, o Tolo, e Samael, “o deus dos cegos”.",
			"Cego porque nunca viu o Pleroma de onde a mãe veio. Cego porque se acreditou o único.",
			"“Eu sou deus, e não há outro além de mim”, proclamou. Os textos respondem: a frase é ignorância, não poder.",
			"Levou consigo um poder da mãe, e com ele fez um mundo copiando, às cegas, o Pleroma que nunca viu.",
			"A Fome é o primeiro sinal de um deus cego: precisa de tudo, e nada o enche.",
		],
		"source": "Apócrifo de João (NHC II,1, 10–13); Hipóstase dos Arcontes (NHC II,4, 87 e 94–95).",
		"hint": "Fome · Travessia I, logo depois dos mercados."},
	{"id": "kenoma", "screen": 15, "eon": "Fome", "title": "O Kenoma e a Hyle",
		"lines": [
			"Pleroma quer dizer plenitude. Kenoma quer dizer vazio: a deficiência, a falta.",
			"Não é o nada. É o cheio que nunca satisfaz: um mercado sem fim onde ninguém se alimenta.",
			"A matéria — hyle — nasceu das paixões de Sophia: da tristeza, do medo, da perplexidade.",
			"“A deficiência veio a existir porque o Pai não era conhecido; quando o Pai é conhecido, a deficiência deixa de existir.”",
			"Há textos que desprezam a carne e outros que a tratam com piedade. Para os valentinianos, ela guarda o luto de uma mãe.",
			"Quem come no Kenoma come sombra de pão. Quem lembra já provou o pão de verdade.",
		],
		"source": "Irineu I,4–5; Evangelho da Verdade (NHC I,3, 24–25).",
		"hint": "Fome · O Desafio, no santuário do Campeão."},
	{"id": "arcontes", "screen": 17, "eon": "Fome", "title": "Os Sete Arcontes e as Esferas",
		"lines": [
			"Yaldabaoth gerou governantes — arcontes — à sua semelhança, e pôs sete reis sobre os sete céus.",
			"Os antigos ligavam os sete céus aos sete astros errantes, da Lua a Saturno.",
			"Athoth, Harmas, Galila, Yabel, Belias e Armupiel vêm da lista de autoridades do Apócrifo de João; Astaphaios, da lista dos sete reis.",
			"Nos textos, cada um recebe uma potência. Aqui, cada porta cobra uma paixão: sono, fome, lei, silêncio, reflexo, podridão, coroa.",
			"No Poimandres hermético, a alma que sobe devolve um vício a cada esfera, até chegar livre à oitava.",
			"Não são demônios. São funcionários de um engano — e todo funcionário sonha com o cargo do chefe.",
		],
		"source": "Apócrifo de João (NHC II,1, 10–12; BG 8502,2); Orígenes, Contra Celso VI,31; Poimandres (Corpus Hermeticum I,25–26).",
		"hint": "Fome · Travessia V, depois do santuário."},
	{"id": "heimarmene", "screen": 21, "eon": "Corrente", "title": "Heimarmene, o Destino em Corrente",
		"lines": [
			"Os arcontes geraram o Destino — Heimarmene — e o amarraram aos astros.",
			"Cada nascimento sob um signo; cada vida numa órbita; cada morte no dia marcado.",
			"Diz o Apócrifo que é a mais dura das cadeias: por ela deuses, anjos, demônios e homens ficaram presos a medidas, estações e tempos.",
			"“Até o batismo, o Destino é verdadeiro; depois dele, os astrólogos já não acertam”, ensinava Teódoto.",
			"A gnose não nega os astros. Nega que eles tenham a última palavra.",
			"A lei deste Éon é essa corrente: bela, polida — e ainda corrente.",
		],
		"source": "Apócrifo de João (NHC II,1, 28); Clemente de Alexandria, Excertos de Teódoto 69–78.",
		"hint": "Corrente · Travessia I, depois dos primeiros selos."},
	{"id": "barro", "screen": 25, "eon": "Corrente", "title": "O Homem de Barro e a Faísca",
		"lines": [
			"A imagem do Homem perfeito brilhou nas águas de baixo, e os arcontes quiseram copiá-la: “Façamos um homem à imagem de Deus e à nossa semelhança”.",
			"Moldaram-no, mas ele não se erguia: ficava no chão, imóvel, sem alma. Outros relatos dizem que se arrastava como um verme.",
			"Então a Luz agiu por astúcia: fez o Cego soprar no rosto do homem o poder que ele tinha levado da mãe.",
			"E o homem se ergueu, mais luminoso que os seus criadores. Os arcontes tiveram inveja e o lançaram no fundo da matéria.",
			"Cada pessoa carrega essa faísca: um pedaço da Luz que o carcereiro não quis dar, e deu.",
			"A corrente prende o barro. Nunca prendeu a faísca.",
		],
		"source": "Apócrifo de João (NHC II,1, 14–21); Hipóstase dos Arcontes (NHC II,4, 87–88); Irineu I,24,1 (Saturnino).",
		"hint": "Corrente · Travessia IV, entre as duas zonas."},
	{"id": "gnose", "screen": 30, "eon": "Silêncio", "title": "A Gnose: saber é lembrar",
		"lines": [
			"Gnose não é crença nem obra. É conhecimento — do tipo que se tem de um rosto amado, não de uma fórmula.",
			"“Quem éramos, o que nos tornamos; onde estávamos, para onde fomos lançados; para onde nos apressamos, de que somos libertos.” (Teódoto)",
			"“Quem não conhece a si mesmo nada conhece; quem conhece a si mesmo já conhece a profundeza do Todo.” (Livro de Tomé, o Atleta)",
			"Por isso o Silêncio é o Éon mais perigoso: não se pode lembrar do que foi apagado.",
			"Mas a faísca não esquece. Só espera que alguém lhe pergunte o nome.",
		],
		"source": "Excertos de Teódoto 78,2; Livro de Tomé, o Atleta (NHC II,7, 138); Evangelho da Verdade (NHC I,3).",
		"hint": "Silêncio · Travessia I, entre as primeiras estantes vazias."},
	{"id": "nag_hammadi", "screen": 33, "eon": "Silêncio", "title": "Nag Hammadi, 1945",
		"lines": [
			"Por mais de mil e quinhentos anos, quase tudo o que se sabia dos gnósticos vinha dos seus adversários.",
			"Em dezembro de 1945, perto de Nag Hammadi, no Egito, o camponês Muhammad Ali al-Samman cavava adubo ao pé de um penhasco e achou um jarro.",
			"Dentro: doze códices de papiro encadernados em couro, e folhas de um décimo terceiro, copiados em copta no século IV.",
			"Cinquenta e dois tratados. O Apócrifo de João. O Evangelho de Tomé. O Evangelho da Verdade. A Hipóstase dos Arcontes.",
			"Conta-se que algumas folhas acabaram no forno da casa antes que alguém soubesse o que eram.",
			"Uma biblioteca inteira ficou em silêncio no barro por dezesseis séculos. E ainda assim falou.",
		],
		"source": "James M. Robinson (org.), The Nag Hammadi Library in English (1977), introdução.",
		"hint": "Silêncio · O Desafio, no santuário do Campeão."},
	{"id": "apocrifo", "screen": 35, "eon": "Silêncio", "title": "O Apócrifo de João",
		"lines": [
			"É o mito inteiro, do Um ao homem, contado como revelação a João, filho de Zebedeu.",
			"Sobreviveu em quatro cópias — três em Nag Hammadi, uma num códice de Berlim —, sinal de que era muito lido.",
			"Nele o Salvador conta a origem de Yaldabaoth, os nomes dos arcontes, a criação de Adão e a corrente do Destino.",
			"Ensina que a alma que não conhece volta a nascer, de prisão em prisão, até despertar; e termina com um hino: “Levanta-te e lembra-te”.",
			"Algo muito próximo dele já circulava por volta de 180: Irineu resume o seu mito para combatê-lo. O combate ajudou a preservá-lo.",
			"As páginas em branco deste Éon são o que restaria sem o jarro. Lê enquanto podes.",
		],
		"source": "NHC II,1; III,1; IV,1; Códice de Berlim (BG 8502,2); Irineu, Contra as Heresias I,29.",
		"hint": "Silêncio · Travessia V, antes da antessala de Yabel."},
	{"id": "pistis", "screen": 39, "eon": "Espelho", "title": "Pistis Sophia e os Arrependimentos",
		"lines": [
			"Há um livro em que Sophia, caída no caos, canta treze arrependimentos.",
			"Ela viu lá embaixo uma luz — a força com rosto de leão do Arrogante — e pensou que fosse a Luz de cima. Desceu atrás dela.",
			"Os poderes do caos a cercaram. Ela cantou: “Ó Luz das luzes, em quem confiei desde o princípio, ouve o meu arrependimento”.",
			"A cada canto, um discípulo — muitas vezes Maria Madalena — responde com um salmo que o interpreta.",
			"Sophia não é salva por força. É salva por lembrar a quem chamar.",
			"O Espelho deste Éon é aquela luz falsa vista de cima. O reflexo não é a Luz. Nunca foi.",
		],
		"source": "Pistis Sophia (Códice Askew, séc. III–IV), livros I–II.",
		"hint": "Espelho · Travessia I, depois das águas paradas."},
	{"id": "mestres", "screen": 43, "eon": "Espelho", "title": "Valentino e Basílides",
		"lines": [
			"Nem todos os gnósticos foram anônimos. Dois mestres ensinaram em Alexandria e em Roma, no século II.",
			"Segundo Hipólito, Basílides falava de um Deus que “não é”, tão além do ser que nem “existir” se diz dele. Segundo Irineu, os céus eram 365.",
			"Valentino, poeta e mestre, esperou ser bispo de Roma, conta Tertuliano. A escola dele levou o mito de Sophia pelo Mediterrâneo.",
			"Para os valentinianos havia três naturezas: a matéria, que se dissolve; a alma, que escolhe; o espírito, que retorna.",
			"Escreveram comentários, salmos, cartas e homilias — quase tudo perdido.",
			"O que sabemos deles é um reflexo nas palavras de quem os combateu. Mesmo assim, brilha.",
		],
		"source": "Irineu I,1–8 e I,24; Hipólito, Refutação VII,20–27; Clemente, Stromata; Tertuliano, Contra os Valentinianos 4.",
		"hint": "Espelho · Travessia IV, depois do santuário."},
	{"id": "tome", "screen": 48, "eon": "Praga", "title": "O Evangelho de Tomé",
		"lines": [
			"“Estas são as palavras secretas que Jesus, o vivo, disse, e que Dídimo Judas Tomé escreveu.”",
			"Cento e catorze ditos. Sem nascimento, sem milagres, sem paixão: só a voz, e o ouvido de quem entende. Se é gnóstico, os estudiosos discutem.",
			"“O Reino está dentro de vós e fora de vós. Quando vos conhecerdes, sereis conhecidos.”",
			"“Se trouxerdes à luz o que está dentro de vós, isso vos salvará. Se não o tiverdes, isso vos matará.”",
			"“O Reino do Pai está espalhado sobre a terra, e os homens não o veem.”",
			"Na Praga tudo apodrece por fora. O dito de Tomé pergunta o que apodrece por dentro.",
		],
		"source": "Evangelho de Tomé (NHC II,2), ditos 1, 3, 70 e 113.",
		"hint": "Praga · Travessia I, logo depois do pântano."},
	{"id": "perola", "screen": 52, "eon": "Praga", "title": "O Hino da Pérola",
		"lines": [
			"Um príncipe do Oriente é enviado ao Egito para buscar uma pérola guardada por uma serpente.",
			"Os pais lhe tiram o manto de luz e prometem: “Quando voltares com a pérola, tu o vestirás de novo”.",
			"No Egito ele come a comida deles, veste as roupas deles — e esquece. Esquece a pérola, esquece o rei, esquece quem é.",
			"Então uma carta voa até ele como uma águia: “Desperta e levanta-te do teu sono. Lembra-te de que és filho de reis. Lembra-te da pérola”.",
			"Ele acorda, encanta a serpente com o nome do pai, toma a pérola e sobe. O manto vem ao seu encontro, e ele se reconhece nele.",
			"O veneno deste pântano é a comida do Egito. A carta é qualquer coisa que te faça lembrar.",
		],
		"source": "Atos de Tomé 108–113 (o “Hino da Pérola”, em siríaco, séc. II–III).",
		"hint": "Praga · Travessia IV, depois do santuário."},
	{"id": "chamado", "screen": 57, "eon": "Coroa", "title": "O Chamado e o Despertar",
		"lines": [
			"Os textos concordam num ponto: a faísca não acorda sozinha. Algo a chama.",
			"“Levanta-te e lembra-te”, diz o hino do Apócrifo de João. “Desperta”, diz a carta da Pérola. O chamado ecoa também entre mandeus e maniqueus.",
			"“Quem tem a gnose, quando é chamado, ouve, responde e se volta para quem o chama”, diz o Evangelho da Verdade.",
			"O Chamado vem de fora do Kenoma: de um enviado disfarçado, de uma carta, de uma dor que rompe o feitiço.",
			"Quem chama não pode subir por ti. O Chamado verdadeiro desperta, e deixa ir.",
			"A Coroa deste Éon espera um rei. O Despertar espera que ninguém se sente.",
		],
		"source": "Apócrifo de João (NHC II,1, 30–31, o hino da Providência); Evangelho da Verdade (NHC I,3, 21–22); Atos de Tomé 110.",
		"hint": "Coroa · Travessia I, depois dos tronos vazios."},
	{"id": "docetismo", "screen": 61, "eon": "Coroa", "title": "Docetismo: o corpo aparente",
		"lines": [
			"Alguns grupos ensinavam que o Salvador viveu entre os homens só em aparência — dokein, em grego, “parecer”.",
			"Basílides, segundo Irineu, dizia que outro foi crucificado em seu lugar; o Apocalipse de Pedro de Nag Hammadi o mostra rindo acima da cruz.",
			"Outros discordaram com força: se ele não sofreu de verdade, o que salvou de verdade? Nem todo gnóstico era docetista.",
			"A disputa durou séculos, e não é preciso tomar partido para ouvi-la.",
			"Ela pergunta o que este Éon pergunta: se o corpo é aparência, por que a dor é tão real?",
			"O corpo que lê esta pedra sangra. Talvez a resposta esteja no sangue.",
		],
		"source": "Irineu I,24,4 (Basílides); Segundo Tratado do Grande Set (NHC VII,2, 56); Apocalipse de Pedro (NHC VII,3, 81–83).",
		"hint": "Coroa · Travessia IV, entre as duas zonas."},
	{"id": "retorno", "screen": 66, "eon": "O Centro", "title": "A Salvação como Retorno",
		"lines": [
			"Para o gnóstico, a salvação não é perdão nem prêmio. É retorno — restauração — de cada faísca à Plenitude.",
			"Sophia, ao lembrar, é recebida de volta. E o filho cego? Para os valentinianos, sobe ao lugar da mãe; Sobre a Origem do Mundo o lança ao abismo.",
			"“Descobristes o princípio, para buscardes o fim? Onde está o princípio, ali estará o fim”, diz o Evangelho de Tomé.",
			"Ninguém volta sozinho: o Chamado vai buscando os que ainda dormem, um a um, até que o Kenoma se esvazie.",
			"Aqui no Centro não há voz, nem trono, nem coroa. Só o caminho de volta.",
			"Escolher como voltar — subir, sentar ou plantar — nunca coube a deus nenhum.",
		],
		"source": "Evangelho de Tomé 18; Irineu I,7,1; Sobre a Origem do Mundo (NHC II,5, 126–127); Tratado Tripartite (NHC I,5).",
		"hint": "O Centro II, na segunda câmara de ecos."},
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
var persist_enabled: bool = true  # ferramentas (QA/shot) desligam para não sujar o disco
var _caption: CaptionBar
var _by_screen: Dictionary = {}   # tela -> Estela


func _ready() -> void:
	for e in STELAS:
		_by_screen[int(e.screen)] = e
	if GameManager.demo and SAVE_PATH == "user://chronicles.json":
		SAVE_PATH = GameManager.DEMO_DIR + "chronicles.json"   # demo: save separado (#27)
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
	Audio.play_sfx("stele_unlock")
	# Conquistas de Crônicas (1ª Estela, 18/18) — autoload leve, se existir.
	var ach := get_node_or_null("/root/Achievements")
	if ach != null and ach.has_method("check_progress"):
		ach.call("check_progress")
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


## Lê as Crônicas com recuperação (principal → .tmp → .bak; REVISAO #3) — o
## mesmo esquema atômico do SaveManager.
func _load() -> void:
	unlocked.clear()
	var got: Dictionary = SaveManager.read_json_safe(SAVE_PATH)
	if got.data is Dictionary:
		if got.from != "main":
			push_warning("Gnosis: chronicles.json danificado — Crônicas recuperadas de %s." % got.path)
		var ids = got.data.get("unlocked", [])
		if typeof(ids) != TYPE_ARRAY:
			ids = []
		# REVISAO #5: str(id) — um número ou lixo na lista descarta SÓ aquele
		# item (String(3) dava erro e apagava todas as Crônicas lidas).
		for id in ids:
			var sid := str(id)
			if entry(sid).size() > 0 and not unlocked.has(sid):
				unlocked.append(sid)


func _save() -> void:
	if not persist_enabled:
		return
	SaveManager.write_json_atomic(SAVE_PATH, {"version": 1, "unlocked": unlocked})


# --- contrato com o Level -----------------------------------------------------

## O Desafio Codex (CodexSession) é um sandbox de 3 encontros: sem Estelas,
## legendas ou cards — o fluxo dele tem resultado próprio e temporizado.
func _sandbox() -> bool:
	return CodexSession.active


func setup_screen(level: Node2D, screen: int, rest_points: Array) -> void:
	_caption.clear()
	if _sandbox():
		return
	var e := stela_for_screen(screen)
	if not e.is_empty() and not rest_points.is_empty() and level != null:
		var s := Stela.new()
		s.entry = e
		level.add_child(s)
		s.global_position = _stela_pos(screen, rest_points)
		# A pedra é cenário do chão: ATRÁS dos lutadores (como os props, z -1).
		# Com z 1 ela cobria a Sophia nas cenas das telas 64 e 68 (QA da Encenação 5).
		s.z_index = -1
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
	if _sandbox():
		return
	if Narrative.once("walk_c_%d_%d" % [screen, zone]):
		_caption.say_lines(Narrative.walk_cleared(screen, zone))


## Fala avulsa (outros sistemas podem usar).
func caption(speaker: String, text: String) -> void:
	_caption.say(speaker, text)


## Várias falas {speaker, text} na fila de legendas (sem pausar o jogo). Usada
## pelos ganchos da Onda 2: fase 2 dos Arcontes, lembranças dos ecos, 7º Anel,
## Adormecidos e a Voz depois de Soter. Nada no Desafio Codex (sandbox).
func captions(lines: Array) -> void:
	if _sandbox():
		return
	_caption.say_lines(lines)


## Card de chefe ao nascer: id do Bestiário ("rei", "arconte_sono", ...,
## "demiurgo" na batalha dupla) ou "campeao" (Desafio do Éon).
func boss_card(id: String, screen: int) -> void:
	if _sandbox():
		return
	if id == "campeao":
		var n := RunManager.eon_name(screen)
		var fem := n in ["Fome", "Corrente", "Praga", "Coroa"]
		Cinematic.boss_card("O CAMPEÃO", "Guardião do santuário %s %s" % ["da" if fem else "do", n])
		return
	var t: Dictionary = BOSS_TITLES.get(id, {})
	if t.is_empty():
		return
	Cinematic.boss_card(String(t.name), String(t.title))
