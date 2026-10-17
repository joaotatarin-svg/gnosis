extends Node
## O texto do jogo: a Voz, o Rei, introduções de Éon, as tentações dos Arcontes,
## os Anéis, o roubo, o Centro, a Mente e os finais. Autoload `Narrative`.
## Guia de voz, glossário e limites de caixa: docs/ESTILO_TEXTO.md.
## Mapa das 68 telas e roteiro das cenas: docs/ROTEIRO.md.
## REGRA DE OURO: nada aqui entrega a virada (a Voz = Yaldabaoth; os Anéis = a
## Sophia) antes do roubo na tela 64.
##
## Cada fala é {speaker, text}. Algumas falas das cenas encenadas trazem também
## `cue` (ex.: "rings_fly", "mask_falls") — a DialogueBox ignora; é a marcação
## para a encenação (Onda 2) disparar o efeito na fala certa. Ver ROTEIRO.md.

const VOZ := "A Voz"
const REI := "O Rei"
const YAL := "Yaldabaoth"
const SOPHIA := "Sophia"
const NARRADOR := ""          # rubrica sem falante (a caixa mostra só o texto)

const ORDINAIS := ["primeiro", "segundo", "terceiro", "quarto", "quinto", "sexto", "sétimo"]

var refusals: int = 0        # tentações recusadas
var concessions: int = 0     # tentações aceitas (suborno de faíscas)
var ending: String = ""      # "ascensao" / "ruptura" / "semente"


## Falas que só devem tocar UMA vez por run (intro, chegada de Éon, tentação):
## com os checkpoints, a tela recarrega ao morrer — sem isto, tudo repetiria.
var seen: Dictionary = {}


func once(key: String) -> bool:
	if seen.has(key):
		return false
	seen[key] = true
	return true


func reset() -> void:
	seen.clear()
	refusals = 0
	concessions = 0
	ending = ""


func _l(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text}


## Fala com marcação de encenação (`cue`) para a cena da Onda 2.
func _c(speaker: String, text: String, cue: String) -> Dictionary:
	return {"speaker": speaker, "text": text, "cue": cue}


## "uma faísca" / "37 faísca(s)" — a fala nunca diz "0 faíscas".
func _faiscas(n: int) -> String:
	return "uma faísca escorre" if n == 1 else "%d faíscas escorrem" % n


# --- A MORTE NÃO PEGA (checkpoint) -------------------------------------------
## Antes do roubo é a VOZ que te recompõe — solícita, mas possessiva e urgente
## demais (na 2ª jogada se entende: o carcereiro precisa da chave viva). No
## Centro, sem a Voz, são os cacos dela mesma. Na Mente, os Anéis a refazem
## CONTRA o dono das mãos. `lost` = faíscas que escorreram na queda.
func death_revive(screen: int, deaths: int, lost: int) -> Array:
	if RunManager.is_final(screen):
		return [
			_l(YAL, "MORRE. Por que tu não morres?"),
			_l(SOPHIA, "(Os sete Anéis param de girar... descem... e me costuram de volta, caco por caco.)"),
			_l(SOPHIA, "Eles lembram de mim. Mesmo nas mãos dele, eles lembram."),
		]
	if screen > RunManager.LAST_ARCHON_SCREEN:
		return [
			_l(SOPHIA, "(Escuro. Nenhuma voz. Só os cacos, quentes, me juntando do chão.)"),
			_l(SOPHIA, "Já fui despedaçada antes. Agora eu sei. E não foi assim que acabou."),
		]
	var pool := [
		[
			_l(VOZ, "Não. Não, não, não. Levanta."),
			_l(VOZ, "Agarra a minha voz e sobe por ela. Não te tirei das cinzas para te perder numa vala do Kenoma."),
		],
		[
			_l(VOZ, "De novo... Fica quieta. Eu seguro a tua faísca. Ela não escapa de mim."),
			_l(VOZ, "Cada volta custa caro. Paga com faíscas, não contigo. Tu vales cada uma delas."),
		],
		[
			_l(VOZ, "Levanta. Eu preciso de ti inteira."),
			_l(VOZ, "O corpo lembra da queda? Que lembre também de quem o ergueu. Todas as vezes."),
		],
		[
			_l(VOZ, "Quantas vezes forem precisas, faísca perdida. Não sei desistir de ti. Não agora, tão perto."),
			_l(VOZ, "Sobe. Tronos não se vencem deitada."),
		],
	]
	var lines: Array = pool[(maxi(1, deaths) - 1) % pool.size()].duplicate()
	if lost > 0:
		lines.append(_l(NARRADOR, "(A luz te costura de volta. %s da tua mão aberta.)" % _faiscas(lost)))
	return lines


# --- ATO 1: O LIMIAR (tela 1) ----------------------------------------------------

## Abertura do run (tela 1), logo depois do prólogo em cards (que termina sem
## dizer "acorda" — quem diz é a Voz).
func intro() -> Array:
	return [
		_l(VOZ, "Acorda."),
		_l(VOZ, "As cinzas sob os teus pés eram a tua gente."),
		_l(VOZ, "A dor que sentes é a única coisa verdadeira que este mundo te deu. Foi ela que quebrou o feitiço."),
		_l(SOPHIA, "...Quem és tu?"),
		_l(VOZ, "Alguém que te procurou por muito tempo. Chama-me Voz. E não temas: não te deixarei sozinha."),
	]


## O Rei sai da névoa (tela 1). A Voz o apresenta como amigo; um rito força o
## duelo. Encenação: docs/ROTEIRO.md, cena A.
func king_intro() -> Array:
	return [
		_c(VOZ, "Olha. Alguém vem da névoa. Não temas: eu o conheço. É um rei antigo, e é gentil.", "fog_thickens"),
		_c(REI, "Faísca perdida... que bom que acordaste. Há eras eu guardo este limiar.", "king_emerges"),
		_l(REI, "Mas o limiar tem uma lei: só passa quem me toca com a própria luz. Mostra-me a tua."),
		_l(VOZ, "É um rito. Bate nele de coração leve. Ele não te quer mal."),
		_c(REI, "(ergue o orbe; a máscara se acende) Vem.", "mask_lights"),
	]


## O Rei "cai" (tela 1): o selo racha e os sete Arcontes acordam.
func king_fall() -> Array:
	return [
		_c(REI, "(a máscara racha) ...Ah. A tua luz é maior do que eu lembrava.", "mask_cracks"),
		_c(VOZ, "Sentiste? O selo dele se partiu. Lá em cima, sete tronos acabam de acordar.", "king_sinks"),
		_l(VOZ, "Sete Arcontes, sete Anéis. Reúne-os todos, e eu te mostro como desfazer este mundo de mentira."),
	]


# --- ATO 2: OS SETE ÉONS -------------------------------------------------------

## Introdução de cada Éon (primeira tela do ato, caixa de diálogo).
func eon_intro(eon: int) -> Array:
	match eon:
		0: return [
			_l(VOZ, "O Éon do Torpor. Aqui os mortos não sabem que morreram; a cidade sonha por eles."),
			_l(VOZ, "Não odeies os que dormem. Ontem tu dormias."),
		]
		1: return [
			_l(VOZ, "O Éon da Fome. Estes mercados devoram quem compra. Tudo aqui tem preço, até a saudade."),
			_l(VOZ, "O Arconte daqui vai te oferecer o que perdeste. Lembra: cópia não é volta."),
		]
		2: return [
			_l(VOZ, "O Éon da Corrente. A lei deste lugar não protege: prende. Cada selo é um cadeado."),
			_l(VOZ, "Quebra os selos. A ordem do carcereiro não é ordem; é medo com coroa."),
		]
		3: return [
			_l(VOZ, "O Éon do Silêncio. Uma biblioteca de livros em branco: aqui calaram a verdade página por página."),
			_l(VOZ, "Escuta o que não é dito. É assim que se lê este lugar."),
		]
		4: return [
			_l(VOZ, "O Éon do Espelho. Cuidado, Portadora: aqui o inimigo és tu."),
			_l(VOZ, "O reflexo luta com a tua força e com a tua fúria. Vence quem se conhece."),
		]
		5: return [
			_l(VOZ, "O Éon da Praga. As faíscas aqui se apagam devagar, como velas num pântano."),
			_l(VOZ, "O desespero é a última arma deles. Não é a tua."),
		]
		6: return [
			_l(VOZ, "O Éon da Coroa. O último degrau. O Arconte daqui quase tocou o trono do Cego."),
			_l(VOZ, "Ele vai te oferecer poder: a mais velha das mentiras, e a mais doce."),
		]
	return []


## Tentação do Arconte (antes da luta). Cada um oferece a sua mentira, na sua
## própria voz; a Voz fecha sempre com "Escolhe." (botões Recusar / Ceder).
func temptation(boss_id: String) -> Array:
	match boss_id:
		"arconte_sono": return [
			_l("Athoth", "Portadora... por que sangrar?... Deita. Eu te devolvo o sonho... onde ninguém morreu."),
			_l(VOZ, "Se dormires agora, nunca mais acordas. Escolhe."),
		]
		"arconte_fome": return [
			_l("Harmas", "Ah, a fome que tu trazes! A tua casa, a tua gente, o teu riso: guardei tudo, quentinho. Fica, e é teu."),
			_l(VOZ, "É cera com cheiro de lembrança. Escolhe."),
		]
		"arconte_corrente": return [
			_l("Galila", "Consta que estás fora do teu lugar. Ajoelha-te, e serás registrada como o meu selo mais belo."),
			_l(VOZ, "Corrente polida ainda é corrente. Escolhe."),
		]
		"arconte_silencio": return [
			_l("Yabel", "(não fala; estende a mão costurada e oferece o descanso de nunca mais precisar responder)"),
			_l(VOZ, "O silêncio dele é um túmulo confortável. Escolhe."),
		]
		"arconte_espelho": return [
			_l("Astaphaios", "Olha. Somos nós, antes das cinzas, sorrindo. Deste lado do vidro podemos ficar assim para sempre."),
			_l(VOZ, "É o golpe mais cruel de todos. Eu sei. Escolhe."),
		]
		"arconte_praga": return [
			_l("Belias", "Tudo apodrece, Portadora... até as faíscas. Estou só cansado de fingir que não. Rende-te e poupa-te o fim."),
			_l(VOZ, "Ele confunde cansaço com verdade. Escolhe."),
		]
		"arconte_coroa": return [
			_l("Armupiel", "Eu, Armupiel, Sétimo Trono: o Cego está velho. Toma a minha coroa. Sê deusa, como eu quase fui."),
			_l(VOZ, "Reinar na prisão ainda é estar preso. Escolhe."),
		]
	return [_l(VOZ, "Ele mente. Escolhe.")]


func refusal_response() -> Array:
	refusals += 1
	return [_l(VOZ, "Bem. A recusa também é uma lâmina, e tu a estás afiando.")]


func concession_response() -> Array:
	concessions += 1
	return [
		_l(VOZ, "...Aceitaste o suborno dele. As faíscas pesam no bolso. E na alma."),
		_l(VOZ, "Não te julgo. Mas lembra: tudo o que um Arconte dá, ele cobra."),
	]


## O Anel de um Arconte se condensa e uma magia nova desperta (caixa de diálogo).
func ring_gained(boss_id: String, skill_name: String, count: int) -> Array:
	var who := boss_id.trim_prefix("arconte_")
	var ord: String = ORDINAIS[clampi(count - 1, 0, ORDINAIS.size() - 1)]
	var lines := [
		_l(VOZ, "A essência dele se condensa... o %s Anel. A paixão do Arconte agora te obedece: %s." % [ord, skill_name]),
	]
	match who:
		"sono":
			lines.append(_l(SOPHIA, "(Ao tocar o Anel: uma nuvem branca, e um trono pequeno dentro dela.)"))
			lines.append(_l(VOZ, "Sonhos do Torpor. Passam. Sobe."))
		"fome":
			lines.append(_l(SOPHIA, "(O segundo Anel encosta no primeiro, e os dois esquentam.)"))
			lines.append(_l(VOZ, "Faltam cinco. Sobe."))
		"corrente": lines.append(_l(VOZ, "Galila te classificou e perdeu. Faltam quatro."))
		"silencio": lines.append(_l(VOZ, "Ouve: as tuas magias voltaram a falar. Faltam três."))
		"espelho": lines.append(_l(VOZ, "Este pesa mais que os outros, não pesa? Coisa de espelho. Ignora."))
		"praga": lines.append(_l(VOZ, "Só falta a Coroa. Agora, Portadora, não pares por nada."))
		"coroa": lines.append(_l(VOZ, "Sete. Todos os sete... Não te mexas. Fica bem aí."))
		_: lines.append(_l(VOZ, "Sobe."))
	return lines


## Encontros com Soter, o Ungido (telas 17, 35 e 53). Ele não luta — abençoa.
## O Cego não o vê: durante o encontro, a Voz não diz nada.
func soter_meeting(n: int) -> Array:
	match n:
		0: return [
			_l("Soter", "Paz, Portadora. Baixa o cajado: o Cego não me vê, e contigo não brigo."),
			_l("Soter", "Disseram-te que a tua gente está nas cinzas? Eu conheço a tua gente. Não está ali."),
			_l("Soter", "Não posso subir por ti. Mas posso ungir o que já é teu. Escolhe."),
		]
		1: return [
			_l("Soter", "De novo tu. Mais fundo, mais forte... e mais cansada. Senta-te um instante. O mundo espera."),
			_l("Soter", "Sabes por que não luto? Porque toda lâmina, até a mais justa, ensina a mão a fechar."),
			_l("Soter", "A tua ainda sabe abrir. Guarda isso. Escolhe a bênção."),
		]
		2: return [
			_l("Soter", "É a última vez que nos vemos deste lado, Portadora. Lá em cima, nem eu alcanço."),
			_l("Soter", "Quando venceres, e vais vencer, lembra-te dos que dormem. A pergunta final não será sobre força."),
			_l("Soter", "Vai. E que a tua faísca seja maior que a tua fúria. Escolhe."),
		]
	return []


func soter_blessings() -> Array:
	return ["Cura plena", "Arma desperta (+1 nível)", "Vigor (+25 de vida máx.)"]


## Encontro único com Velkar, o Arrependido (tela 61, Éon da Coroa).
func velkar_meeting() -> Array:
	return [
		_l("Velkar", "Não ergas o cajado por mim, Portadora. Já fui Arconte. Larguei a corrente... e ela levou o meu braço junto."),
		_l("Velkar", "Guardei almas por eras achando que era lei. Era medo. O Cego também tem medo. Todo carcereiro tem."),
		_l("Velkar", "Vou te dizer o que Soter não diz. Lá em cima não há tirano nenhum."),
		_l("Velkar", "Há uma criança cega, num trono grande demais, chamando pela mãe."),
		_l("Velkar", "Quando fores acabar com ele, acaba direito. Toma: faíscas que colhi quando era monstro."),
		_l(VOZ, "...Arcontes caídos contam histórias tristes. É tudo o que lhes resta. Sobe."),
	]


# --- ATO 3: O ROUBO + A MÁSCARA CAI (tela 64) ----------------------------------
## Após o 7º Arconte. O Rei reaparece e leva os sete Anéis; a voz-amiga se
## revela Yaldabaoth. Encenação: docs/ROTEIRO.md, cena B. Os `cue` marcam onde
## a cena dispara: o Rei sai da névoa · as 7 gemas do HUD voam uma a uma · a voz
## do Rei vira a Voz · a máscara cai · ele vira motor de anéis e afunda.
func theft() -> Array:
	return [
		_c(REI, "(sai da névoa, inteiro, a máscara sem uma rachadura) Faísca perdida... fizeste tudo tão bem.", "king_emerges"),
		_l(SOPHIA, "Tu caíste. Eu te vi cair."),
		_l(REI, "Caí, para que tu subisses. Alguém tinha de te pôr no caminho... e de te pedir os Anéis no fim dele."),
		_c(REI, "(estende a mão; os sete Anéis se arrancam dos teus dedos, um a um) Vem. Vem... vem.", "rings_fly"),
		_l(SOPHIA, "Voz! Faz alguma coisa!"),
		_c(REI, "Estou fazendo, Portadora. Sobe... ah, não. Agora já não precisas subir.", "voice_merge"),
		_c(YAL, "(a máscara cai; atrás dela, nada, só um olho cego) Eu sou o Cego de quem te falei. E não há outro além de mim.", "mask_falls"),
		_l(YAL, "Sete Arcontes, sete Anéis: o meu corpo, partido para que ninguém o achasse. E tu o remontaste nas minhas mãos."),
		_l("Uma voz nos Anéis", "...espera... eu... lembro..."),
		_c(YAL, "(vira um motor de anéis e afunda no chão) Desce, se tiveres coragem. No Centro não há voz nenhuma para te guiar.", "sink"),
	]


# --- ATO 4: O CENTRO (telas 65–67) ----------------------------------------------

## O Centro (tela 65): sem os Anéis, sem a Voz. Encenação da descida: cena C.
func center_intro() -> Array:
	return [
		_l(SOPHIA, "...Silêncio. Desde as cinzas, é a primeira vez que não há voz nenhuma na minha cabeça."),
		_l(SOPHIA, "Ele levou os Anéis. Mas os Arcontes estão aqui embaixo: cascas dele, ecos."),
		_l(SOPHIA, "Cada eco que eu quebrar me devolve um caco do que fui. Então vamos lembrar."),
	]


## Um eco quebrado devolve um caco de memória (toast do HUD, registro de sistema).
func echo_shard(_boss_id: String, skill_name: String) -> String:
	return "Caco de memória recuperado: %s" % skill_name


# --- ATO 5: A MENTE (tela 68) ---------------------------------------------------

## A batalha final: o choque, a mente dele.
func final_pre() -> Array:
	return [
		_l(SOPHIA, "(Um clarão. O chão some. O mundo vira o interior de uma mente.) ...Estou dentro dele."),
		_l(YAL, "Duas faces: a que amaste e a que temes. As duas sou eu. Derruba uma, e a outra a refaz."),
		_l(SOPHIA, "Então caem as duas. Juntas."),
	]


## Toasts da batalha dupla (registro de sistema: imperativo de "você").
func final_form_fell(form_name: String) -> String:
	return "%s caiu. Derrube a outra antes que se refaça!" % form_name


func final_revive(form_name: String) -> String:
	return "%s se refez." % form_name


## A ANAGNÓRISE (após as DUAS formas caírem): os Anéis voltam à Sophia e ela
## recupera a memória de quem é. Reclamar, não matar. Encenação: cena D.
func final_lines() -> Array:
	return [
		_c(SOPHIA, "(as duas formas caem juntas; os sete Anéis param no ar... e voam para dentro dela) Ah...", "rings_return"),
		_c(SOPHIA, "Agora eu vejo. Os Anéis são eu: cacos meus, que tu arrancaste e forjaste em correntes.", "flash"),
		_l(SOPHIA, "Eu entrei aqui de propósito, para te deter. E os Anéis me fizeram esquecer até disso."),
		_l(SOPHIA, "Fizeram-me caçar a mim mesma. Para ti."),
		_c(YAL, "...mãe? eu não queria ser cego. eu só queria que alguém olhasse para mim.", "colossus_shrinks"),
		_l(SOPHIA, "Eu estou olhando. Fui eu que te escondi numa nuvem. Não devia ter escondido."),
		_c(SOPHIA, "(ela abre a mão) Volta para dentro de quem te fez. Não para morrer. Para voltar para casa.", "reclaim"),
		_l(SOPHIA, "Agora, a última escolha, que nenhum deus fez por nós: o que fazer com um mundo de adormecidos?"),
	]


func final_choices(sleepers: int) -> Array:
	var semente_ok := sleepers >= 4
	return [
		"Ascensão — abrir o Pleroma",
		"Ruptura — tomar o trono",
		{"text": "Semente — plantar a gnose", "enabled": semente_ok,
			"hint": "Exige 4 Adormecidos despertos pelo caminho"},
	]


## Títulos e subtítulos do fim (cartão de abertura do epílogo e EndScreen).
func apply_ending(index: int) -> void:
	match index:
		0:
			ending = "ascensao"
			GameManager.end_title = "ASCENSÃO"
			GameManager.end_subtitle = "Toda faísca voltou à Fonte. O Kenoma se desfez como um sonho ao acordar.\nVerdade inteira. Mundo nenhum. A Luz não olhou para trás."
		1:
			ending = "ruptura"
			GameManager.end_title = "RUPTURA"
			GameManager.end_subtitle = "Sophia sentou-se no trono ainda morno. A coroa serviu.\nNo Kenoma nada mudou, só o nome do carcereiro."
		2:
			ending = "semente"
			GameManager.end_title = "SEMENTE"
			GameManager.end_subtitle = "Sophia recusou o trono e a porta. Desceu de volta, de faísca em faísca.\nSem apocalipse e sem prisão: liberdade lenta, a única que dura."
	if ending != "" and not RunManager.endings_seen.has(ending):
		RunManager.endings_seen.append(ending)


# --- CONVERSA DE CAMINHADA (legendas sem pausar — ver Gnosis/CaptionBar) --------
## A Voz comenta cada Éon com o viés DELA (o Pleroma abandonou as faíscas; "eu
## olho por ti"; "vieste de mim"); a Sophia responde a si mesma e a dúvida cresce
## Éon a Éon, alimentada pelas Estelas (a versão do Pleroma). Regras:
##  - nada entrega a virada antes da tela 64;
##  - a Sophia só cita uma Estela na tela SEGUINTE à da pedra (ou depois);
##  - cada fala tem lugar fixo (Éon × tela × zona): NENHUMA repete no run.
## Mapa completo em docs/ROTEIRO.md.

## Chegada à tela (após os diálogos de entrada). 1–2 falas.
func walk_arrival(screen: int) -> Array:
	var role := RunManager.screen_role(screen)
	if role == "king":
		return [
			_l(VOZ, "As cinzas ainda estão quentes. Anda: a névoa não espera ninguém."),
			_l(SOPHIA, "(Uma pedra escrita, logo adiante. Alguém deixou palavras para quem acordasse.)"),
		]
	if role == "final":
		return [_l(SOPHIA, "Tudo aqui é grande demais. Como um quarto de criança visto do chão.")]
	if role == "center":
		match screen - RunManager.CENTER_FIRST:
			0: return [_l(SOPHIA, "(O chão é feito de engrenagens. Giram devagar, como se respirassem.)")]
			1: return [_l(SOPHIA, "Os ecos têm o rosto dos Arcontes. Mas se movem como ele.")]
			_: return [_l(SOPHIA, "Estou me remontando de dentro para fora. Falta pouco.")]
	var off := RunManager.eon_offset(screen)
	var pool: Array = _arrival_pool(RunManager.eon_index(screen))
	if off < 0 or off >= pool.size():
		return []
	return pool[off]


## Zona limpa: no máximo 1 fala, por posição fixa (offset da tela × zona).
## Telas de chefe ficam com o diálogo; o Desafio abre o santuário (sem fala).
func walk_cleared(screen: int, zone: int) -> Array:
	var role := RunManager.screen_role(screen)
	if role in ["king", "archon", "final", "trial"]:
		return []
	if role == "center":
		var c := [
			_l(SOPHIA, "Um caco a mais. A nuvem branca... fui eu que a fiz. Para esconder alguém."),
			_l(SOPHIA, "Ele me chamou de chave. Chaves abrem, e ele esqueceu que abrem dos dois lados."),
			_l(SOPHIA, "Os ecos não gritam quando caem. Choram."),
		]
		return [c[clampi(screen - RunManager.CENTER_FIRST, 0, c.size() - 1)]] if zone == 0 else []
	var pool: Array = _cleared_pool(RunManager.eon_index(screen))
	var off := RunManager.eon_offset(screen)
	if off < 0 or off >= pool.size():
		return []
	var here: Array = pool[off]
	if zone < 0 or zone >= here.size():
		return []
	return [here[zone]]


## Falas de chegada por Éon, indexadas pelo offset da tela (0..8):
## 0 chegada · 1–3 travessias · 4 Desafio · 5–6 travessias · 7 antessala · 8 Arconte.
func _arrival_pool(eon: int) -> Array:
	match eon:
		0: return [   # TORPOR (telas 2–10) · Estelas 3 (Pleroma) e 8 (Sophia)
			[_l(SOPHIA, "Eles dormem de pé. Ninguém aqui sabe que a cidade acabou.")],
			[_l(VOZ, "Vês? Os que dormem não sofrem. Quem acorda, sim. Mas só quem acorda sobe.")],
			[_l(SOPHIA, "A pedra falava de um Silêncio antes de tudo. Por que isso me soa como lembrança?"),
			 _l(VOZ, "Não confies demais nas pedras. Quem as escreveu já não está aqui para explicar.")],
			[_l(SOPHIA, "Pares de luz, dizia a pedra. Éons. Então quem era o meu par?"),
			 _l(VOZ, "Ninguém sobe em par, Portadora. Sobe-se sozinha. Comigo.")],
			[_l(VOZ, "O Campeão de Athoth guarda o santuário. Acorda-o a golpes.")],
			[_l(SOPHIA, "Se o Pleroma é tão cheio, por que ninguém de lá desce para buscar os que dormem?"),
			 _l(VOZ, "Porque a Luz de cima não olha para baixo. Eu olho.")],
			[_l(VOZ, "Sentes a névoa? É o hálito de Athoth. Ela quer que tu te deites.")],
			[_l(VOZ, "A antessala. Atrás dela, o primeiro trono. Não te deites. Nunca te deites.")],
			[_l(SOPHIA, "Um trono num quarto de sonho. E ele nem abriu os olhos.")],
		]
		1: return [   # FOME (telas 11–19) · Estelas 12 (o Cego), 15 (Kenoma), 17 (Arcontes) · Soter 17
			[_l(SOPHIA, "Cheiro de pão por toda parte. Ninguém come. Todos mastigam.")],
			[_l(VOZ, "A matéria tem fome de tudo o que brilha. E tu brilhas. Cuidado.")],
			[_l(SOPHIA, "Chamam este mundo de Kenoma, o vazio. Mas está cheio até a borda."),
			 _l(VOZ, "Cheio de falta. É isso que ‘vazio’ quer dizer.")],
			[_l(SOPHIA, "A pedra diz que o Cego nasceu sem par e sem forma. Quem deixa um filho assim sozinho?"),
			 _l(VOZ, "Os de cima. Eles chamam isso de paciência.")],
			[_l(VOZ, "O Glutão que guarda o santuário come o que mata. Não morras perto dele.")],
			[_l(SOPHIA, "Tu sabes o meu nome. Por que nunca me dizes o teu?"),
			 _l(VOZ, "Um nome, aqui, vira coleira. Chama-me como sempre: Voz.")],
			[_l(SOPHIA, "Há alguém de branco mais adiante, parado numa luz que não vem de lugar nenhum.")],
			[_l(VOZ, "Aquele de branco... por um instante eu te perdi. Não te afastes assim de mim.")],
			[_l(SOPHIA, "Um mercado inteiro na barriga dele. E ainda me olha com fome.")],
		]
		2: return [   # CORRENTE (telas 20–28) · Estelas 21 (Heimarmene) e 25 (barro e faísca)
			[_l(SOPHIA, "Selos por toda parte. Cada porta tem um cadeado; cada cadeado, um nome.")],
			[_l(VOZ, "Heimarmene, diziam os antigos: o Destino como corrente. Aqui, é corrente mesmo.")],
			[_l(SOPHIA, "A pedra diz que os astros são os elos. Sete elos, sete céus, sete Arcontes."),
			 _l(VOZ, "E tu já partiste dois. Continua.")],
			[_l(VOZ, "Galila não te odeia. Ele te classifica. É pior.")],
			[_l(VOZ, "O Carcereiro do santuário prende primeiro e pergunta depois. Esquiva-te, e a corrente se parte.")],
			[_l(SOPHIA, "Se a lei daqui é medo com coroa, quem usa a coroa?"),
			 _l(VOZ, "O Cego, lá no alto. Ninguém mais. Sobe.")],
			[_l(SOPHIA, "A pedra diz que o sopro no barro veio de fora deste mundo. Então eu também vim?"),
			 _l(VOZ, "Vieste de mim. Eu te achei. Não esqueças a ordem das coisas.")],
			[_l(VOZ, "Última porta antes do trono. As correntes dele cantam quando têm medo.")],
			[_l(SOPHIA, "Um trono feito de elos. Ele se acorrentou a si mesmo para não cair.")],
		]
		3: return [   # SILÊNCIO (telas 29–37) · Estelas 30 (gnose), 33 (Nag Hammadi), 35 (Apócrifo) · Soter 35
			[_l(SOPHIA, "Livros em branco. Milhares. Alguém apagou uma biblioteca inteira.")],
			[_l(VOZ, "Aqui a Palavra foi calada. Yabel costurou a própria boca para dar o exemplo.")],
			[_l(SOPHIA, "O que não é dito... eu tenho ouvido. Uma voz por baixo da tua. Fraca."),
			 _l(VOZ, "Eco. Este Éon está cheio deles. Ignora.")],
			[_l(VOZ, "Aqui as magias se calam. Confia no cajado: ele não precisa falar.")],
			[_l(VOZ, "O Bibliotecário do santuário cala tudo ao redor. Fica longe e bate rápido.")],
			[_l(SOPHIA, "A pedra fala de livros enterrados num jarro, achados por acaso. A verdade sobrevive enterrada."),
			 _l(VOZ, "Sobrevive. Não é o mesmo que vencer.")],
			[_l(SOPHIA, "Se lembrar é saber, eu quero lembrar. Mesmo o que dói."),
			 _l(VOZ, "Lembrar tem hora. Agora é hora de subir.")],
			[_l(VOZ, "Não me calei por medo. Não falo com quem não luta, só isso."),
			 _l(VOZ, "A antessala do Silêncio. Lá dentro, nem eu falo.")],
			[_l(SOPHIA, "Ele não vai falar. E eu vou ter de responder mesmo assim.")],
		]
		4: return [   # ESPELHO (telas 38–46) · Estelas 39 (Pistis Sophia) e 43 (Valentino e Basílides)
			[_l(SOPHIA, "Água parada por toda parte. E em cada poça, eu.")],
			[_l(VOZ, "Conheces a história? A Sabedoria viu o próprio rosto na água e desceu atrás dele."),
			 _l(VOZ, "Vaidade. Não repitas.")],
			[_l(SOPHIA, "O nome na pedra é o meu. Sophia."),
			 _l(VOZ, "Nome comum. Sabedoria. Metade das mães do Kenoma dá esse nome às filhas.")],
			[_l(VOZ, "Astaphaios vai te dar o que mais queres: tu, antes de tudo. É o golpe mais cruel.")],
			[_l(VOZ, "O Reflexo do santuário recua quando bates. Bate onde ele vai estar.")],
			[_l(SOPHIA, "A pedra diz que não foi o rosto dela na água. Foi uma luz falsa, vista de cima."),
			 _l(VOZ, "Pedras repetem o que querem. Água é água. Sobe.")],
			[_l(SOPHIA, "Ela se arrependeu treze vezes, e cantou. Eu ainda não cantei nenhuma.")],
			[_l(VOZ, "Última sala antes do vidro grande. Não te olhes mais do que o necessário.")],
			[_l(SOPHIA, "Ele tem o meu rosto. A Voz diz que é truque. A Voz diz muita coisa.")],
		]
		5: return [   # PRAGA (telas 47–55) · Estelas 48 (Tomé) e 52 (Hino da Pérola) · Soter 53
			[_l(SOPHIA, "Pântano. As faíscas afundam devagar, como velas.")],
			[_l(VOZ, "A matéria apodrece. É a única lei que o Cego não escreveu, e a única que o assusta.")],
			[_l(SOPHIA, "A pedra diz que o Reino está dentro e fora. Dentro deste pântano?"),
			 _l(VOZ, "Dentro de ti. Fora daqui. Sobe.")],
			[_l(VOZ, "Belias não mente. Está cansado, e acha que o cansaço é a verdade.")],
			[_l(VOZ, "O Portador de Esporos do santuário envenena até depois de morto. Mata-o e afasta-te.")],
			[_l(VOZ, "Cinco Anéis. Mais dois, e eu te mostro o fim de tudo isto.")],
			[_l(SOPHIA, "Um príncipe desceu para buscar uma pérola e esqueceu quem era. Até que uma carta o lembrou."),
			 _l(VOZ, "Bonito. Ninguém te mandou carta nenhuma. Tens a mim.")],
			[_l(VOZ, "Última antessala podre. Depois dela, a Coroa. Aguenta.")],
			[_l(SOPHIA, "Ele está morrendo há eras. Só não deixa ninguém terminar.")],
		]
		6: return [   # COROA (telas 56–64) · Estelas 57 (o Chamado) e 61 (docetismo) · Velkar 61 · o roubo 64
			[_l(SOPHIA, "Um trono em cada esquina. Todos vazios. Todos à espera de quem se sente.")],
			[_l(VOZ, "O último degrau. Armupiel quase tocou o trono do Cego. ‘Quase’ é a palavra que o define.")],
			[_l(SOPHIA, "A pedra fala de um Chamado: uma voz de fora que acorda quem dorme. Foi assim que me achaste?"),
			 _l(VOZ, "Foi. Eu chamei; tu ouviste. É tudo o que importa.")],
			[_l(VOZ, "Aqui os servos se ajoelham até para morrer. Não te acostumes a ver gente de joelhos.")],
			[_l(VOZ, "O Pretoriano do santuário tem broquel. Golpe pesado, ou pelas costas.")],
			[_l(SOPHIA, "Seis Anéis giram na minha mão como se se conhecessem. Partes de uma coisa só."),
			 _l(VOZ, "São. São a chave. Falta o sétimo dente.")],
			[_l(SOPHIA, "Velkar disse que lá em cima há uma criança. Tu nunca me disseste isso."),
			 _l(VOZ, "Porque não há. Há um trono, e o trono é teu inimigo.")],
			[_l(VOZ, "A antessala da Coroa. Depois dela, o sétimo. E depois... o ritual. Prometi mostrar-te.")],
			[_l(SOPHIA, "Uma coroa alta demais para a cabeça que a carrega. Ele sabe. Por isso grita.")],
		]
	return []


## Falas de zona limpa por Éon: [offset] -> [fala da zona 0, fala da zona 1].
## Offset 4 (Desafio) e 8 (Arconte) ficam vazios; a antessala (7) tem 1 zona.
## Nas travessias de 3 zonas, a 3ª zona fica em silêncio (respiro).
func _cleared_pool(eon: int) -> Array:
	match eon:
		0: return [
			[_l(VOZ, "Bem. Eles voltam ao chão, e o chão ao sono."),
			 _l(SOPHIA, "Eles não gritam. Só se deitam... como se agradecessem.")],
			[_l(VOZ, "Cada faísca que soltas fica mais leve. Sentes? Elas sobem por ti."),
			 _l(SOPHIA, "Sobem por mim... para onde?")],
			[_l(VOZ, "Não pares para pensar aqui. No Torpor, pensar vira cochilo."),
			 _l(SOPHIA, "(Um gosto de leite morno na boca. De onde vem isso?)")],
			[_l(SOPHIA, "Caem de mãos abertas. Ninguém fecha o punho para dormir."),
			 _l(VOZ, "O sono deste Éon tem dedos compridos. Sobe.")],
			[],
			[_l(VOZ, "O Torpor não odeia ninguém. Só quer companhia."),
			 _l(SOPHIA, "Quantos destes já foram faíscas como eu?")],
			[_l(VOZ, "Sentes a névoa engrossar? É medo. Ele sabe que vens."),
			 _l(SOPHIA, "Um Arconte com medo de mim?")],
			[_l(SOPHIA, "(A pedra falava de uma Sabedoria que quis ver a Fonte sozinha. Por que esse nome me dói?)")],
		]
		1: return [
			[_l(VOZ, "Devorados pelos próprios dentes. A fome sempre termina assim."),
			 _l(SOPHIA, "Caem de boca aberta. Ainda com fome.")],
			[_l(VOZ, "Mais faíscas. Sentes como pesam menos? Estás quase leve."),
			 _l(SOPHIA, "Ninguém aqui vende nada. Só troca uma fome por outra.")],
			[_l(VOZ, "Comida, sono, moeda: todas as correntes começam macias."),
			 _l(SOPHIA, "(Também tenho fome. Mas não de pão.)")],
			[_l(VOZ, "Harmas cobra por cada lembrança. Não compres nada. Nem a saudade."),
			 _l(SOPHIA, "E se eu já vendi alguma coisa aqui sem saber?")],
			[],
			[_l(VOZ, "Os mercadores fecham as bancas quando passas. Já te conhecem."),
			 _l(SOPHIA, "Ou têm medo do que eu carrego.")],
			[_l(VOZ, "Não pares. A fome sente o cheiro de quem para."),
			 _l(SOPHIA, "Enquanto ele falava, a Voz não disse nada. Nada.")],
			[_l(SOPHIA, "A pedra diz que o Cego fez os sete à imagem dele. Se eu derrubar os sete... derrubo o quê?")],
		]
		2: return [
			[_l(VOZ, "Os selos caem. A ordem deles era só ferrugem."),
			 _l(SOPHIA, "Gritam ‘lei’ quando morrem. Nenhum diz ‘justiça’.")],
			[_l(VOZ, "Cada selo quebrado é uma corrente a menos no mundo. Tu és boa nisto."),
			 _l(SOPHIA, "Boa em quebrar. A Voz nunca me elogia por outra coisa.")],
			[_l(VOZ, "Não filosofes com o carcereiro. Ele adora."),
			 _l(SOPHIA, "Se o destino é corrente, quem segura a outra ponta?")],
			[_l(VOZ, "Os astros não param de girar por ti. Sobe."),
			 _l(SOPHIA, "(Os dois Anéis tilintam um no outro, como se conversassem.)")],
			[],
			[_l(SOPHIA, "Os elos têm nomes gravados. Nenhum é o meu. Ainda."),
			 _l(VOZ, "Nem será. Eu não deixaria.")],
			[_l(VOZ, "Barro emprestado, Portadora. Não te apegues ao corpo: ele é só a escada."),
			 _l(SOPHIA, "Se o barro é dele e o sopro não é... o que é meu?")],
			[_l(SOPHIA, "Ouço daqui as correntes do trono. Cantam baixo. Parece choro.")],
		]
		3: return [
			[_l(SOPHIA, "Caem sem som. Como páginas."),
			 _l(VOZ, "Um silêncio a menos. O mundo já soa mais alto.")],
			[_l(SOPHIA, "Há uma pergunta que eu não faço, porque tenho medo da resposta."),
			 _l(VOZ, "Então não a faças. Aqui, pergunta vira tinta em branco.")],
			[_l(SOPHIA, "Gnose não é fé nem obra, diz a pedra: é lembrar. E eu não lembro de nada antes das cinzas."),
			 _l(VOZ, "Vais lembrar quando os sete Anéis estiverem juntos. Eu prometo.")],
			[_l(VOZ, "O silêncio gruda nas botas. Sobe."),
			 _l(SOPHIA, "(Um livro caído. Branco. Mas a mão sabe onde estava cada palavra.)")],
			[],
			[_l(VOZ, "Livros enterrados não salvam ninguém. Quem te salva sou eu, que estou aqui."),
			 _l(SOPHIA, "(Dezesseis séculos debaixo da terra, e ainda falam.)")],
			[_l(VOZ, "Mais perto. As estantes acabam logo."),
			 _l(SOPHIA, "Por que tu te calas quando Soter aparece?")],
			[_l(SOPHIA, "Do outro lado da porta, nem o ar se mexe.")],
		]
		4: return [
			[_l(SOPHIA, "Quando caem, os cacos mostram um rosto. Nunca o deles."),
			 _l(VOZ, "Não olhes os cacos. Olha o caminho.")],
			[_l(SOPHIA, "A Voz odeia este Éon mais que os outros. Por quê?"),
			 _l(VOZ, "Porque espelhos mentem melhor do que eu jamais mentiria.")],
			[_l(SOPHIA, "Tenho a força dele, ou ele tem a minha?"),
			 _l(VOZ, "Tens a tua. Chega. Sobe.")],
			[_l(VOZ, "Quatro Anéis. Sentes como eles puxam? Estão com pressa."),
			 _l(SOPHIA, "Puxam. Mas não para cima: uns para os outros.")],
			[],
			[_l(VOZ, "Não te demores na água. Ela devolve mais do que mostra."),
			 _l(SOPHIA, "(No fundo da poça, por um instante: uma nuvem branca, e alguém pequeno chorando nela.)")],
			[_l(VOZ, "Valentino, Basílides... homens mortos discutindo o que nunca viram."),
			 _l(SOPHIA, "Discutiam o mesmo que eu: de onde vim, e para onde volto.")],
			[_l(SOPHIA, "Atrás da porta, alguém respira no mesmo ritmo que eu.")],
		]
		5: return [
			[_l(SOPHIA, "Apodrecem antes de cair. Já estavam mortos havia muito."),
			 _l(VOZ, "A poça some. Bom. Não pises no que ficou.")],
			[_l(SOPHIA, "Quanto do que eu sou é matéria, e quanto é sopro?"),
			 _l(VOZ, "O sopro. Só ele. O resto é barro emprestado.")],
			[_l(VOZ, "A Praga entra pelos pés de quem para. Sobe."),
			 _l(SOPHIA, "(Os vivos daqui não pedem cura. Pedem que acabe logo.)")],
			[_l(SOPHIA, "O que está dentro de mim me salva, diz a pedra. E se o que está dentro for escuro?"),
			 _l(VOZ, "Então eu sou a tua luz. Basta.")],
			[],
			[_l(VOZ, "Não respires fundo aqui. Nem para suspirar."),
			 _l(SOPHIA, "Cinco Anéis, cada um mais quente que o anterior. Como se me reconhecessem.")],
			[_l(SOPHIA, "O manto do príncipe esperava por ele lá em cima. Será que algo me espera?"),
			 _l(SOPHIA, "A pergunta final não será sobre força, ele disse. Sobre o quê, então?")],
			[_l(VOZ, "Respira. Do outro lado, só a Coroa e eu.")],
		]
		6: return [
			[_l(VOZ, "Coroas caem de mais alto e fazem mais barulho. Só isso."),
			 _l(SOPHIA, "Morrem chamando pelo rei. Nenhum sabe o nome dele.")],
			[_l(VOZ, "Quase, Portadora. Quase. Sinto os sete a um passo."),
			 _l(SOPHIA, "A Voz nunca teve tanta pressa. Nunca.")],
			[_l(SOPHIA, "Se a salvação é retorno... eu volto para onde?"),
			 _l(VOZ, "Para mim. Para onde tudo começou.")],
			[_l(VOZ, "Não pares. Nem para ler. Já sabes o bastante."),
			 _l(SOPHIA, "(Sei o bastante para desconfiar. Não o bastante para parar.)")],
			[],
			[_l(VOZ, "O ar aqui cheira a ouro velho e a medo. Sobe."),
			 _l(VOZ, "Velkar fala demais para quem perdeu tudo. Não carregues as palavras dele.")],
			[_l(SOPHIA, "As pedras dizem que o corpo é aparência. Então por que dói tanto?"),
			 _l(VOZ, "Salva a faísca, Portadora. O corpo serve para subir.")],
			[_l(SOPHIA, "(As pedras dizem uma coisa; a Voz, outra. Uma das duas está errada. Ou as duas.)")],
		]
	return []


# --- EPÍLOGO (cards após o final escolhido — ver Cinematic.epilogue) -----------
## Textos curtos por final, na voz do narrador (a mesma das Estelas). O título e
## o subtítulo já estão no GameManager (apply_ending). Cada item vira um card.
func epilogue_cards(which: String) -> Array:
	match which:
		"ascensao": return [
			"As sete esferas se apagaram como lamparinas ao amanhecer. Os Arcontes, sem luz para roubar, voltaram a ser o que sempre foram: nomes.",
			"Yaldabaoth voltou para dentro de quem o fez. Não como castigo: como filho que encontrou o colo.",
			"No Pleroma ninguém conta esta história. Lá não há passado a contar; só a Plenitude, inteira outra vez.",
		]
		"ruptura": return [
			"A coroa pesava menos do que ele dizia. Isso devia ter sido o aviso.",
			"Os sete tronos ganharam sete cascas novas, ou as mesmas com outros nomes. O Kenoma não notou a diferença.",
			"Um dia alguém vai acordar entre cinzas e ouvir uma voz gentil oferecendo ajuda. Tu já sabes o que essa voz vai dizer.",
		]
		"semente": return [
			"Não subiu, nem sentou. Desceu, Éon por Éon, batendo à porta dos que dormem.",
			"Os Arcontes continuam de pé. Mas cada Adormecido desperto é um degrau que eles já não controlam.",
			"É a estrada lenta de Tomé: o Reino espalhado sobre a terra, e cada vez mais gente a vê-lo.",
		]
	return ["A faísca lembrou. O resto é silêncio."]
