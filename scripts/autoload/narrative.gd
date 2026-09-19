extends Node
## O texto do jogo: a Voz, o Rei, introduções de Éon, as tentações dos Arcontes,
## os Anéis, o roubo, o Centro, a Mente e os finais. Autoload `Narrative`.
## Conteúdo denso — ver docs/LORE.md. REGRA DE OURO: nada aqui entrega a virada
## (a Voz = o Demiurgo; os Anéis = a Sophia) antes da tela 50.

const VOZ := "A Voz"

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


## A MORTE NÃO PEGA (checkpoint). Antes do roubo é a VOZ que te recompõe —
## solícita, mas possessiva e urgente demais (a 2ª jogada entende por quê:
## o carcereiro precisa da chave viva). No Centro, sem a Voz, são os cacos
## dela mesma. Na Mente, os Anéis a refazem CONTRA o dono das mãos.
## `lost` = faíscas que escorreram na queda.
func death_revive(screen: int, deaths: int, lost: int) -> Array:
	if RunManager.is_final(screen):
		return [
			_l("Yaldabaoth", "MORRE. Por que tu não MORRES?"),
			_l("Sophia", "(os sete Anéis param de girar... descem... e me costuram de volta, caco por caco)"),
			_l("Sophia", "Eles lembram de mim. Mesmo nas mãos dele — eles lembram."),
		]
	if screen > RunManager.LAST_ARCHON_SCREEN:
		return [
			_l("Sophia", "(escuro. nenhuma voz. só os cacos, quentes, me juntando do chão)"),
			_l("Sophia", "Eu já fui despedaçada antes. Eu sei disso agora... porque não foi assim que acabou."),
		]
	var pool := [
		[
			_l(VOZ, "Não. Não, não, não. LEVANTA."),
			_l(VOZ, "Agarra a minha voz e sobe por ela. Eu não te achei no meio das cinzas pra te perder numa vala do Kenoma."),
			_l(VOZ, "(a luz te costura de volta; %d faíscas escorrem da tua mão aberta)" % lost),
		],
		[
			_l(VOZ, "De novo... Fica quieta. Eu seguro a tua faísca — ela NÃO escapa de mim."),
			_l(VOZ, "Custa caro, cada volta. Paga com as faíscas, não contigo. Tu vales cada fagulha."),
		],
		[
			_l(VOZ, "Levanta. Eu preciso de ti INTEIRA."),
			_l(VOZ, "O corpo lembra da queda? Que lembre também de quem te ergueu. Todas as vezes."),
		],
		[
			_l(VOZ, "Quantas vezes forem precisas. Eu não sei desistir de ti — não agora. Não tão perto."),
			_l(VOZ, "Sobe. Os tronos não se vencem deitada."),
		],
	]
	return pool[(maxi(1, deaths) - 1) % pool.size()]


func reset() -> void:
	seen.clear()
	refusals = 0
	concessions = 0
	ending = ""


func _l(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text}


## Abertura do run (tela 1): acorda sem memória.
func intro() -> Array:
	return [
		_l(VOZ, "Acorda. As cinzas sob teus pés eram a tua gente."),
		_l(VOZ, "A dor que sentes é a única coisa real que este mundo já te deu. Ela quebrou o feitiço."),
		_l(VOZ, "Sobe. Cada faísca que libertares lembrará o que tu és. E eu... eu lembrarei contigo."),
	]


## O Rei sai da névoa (tela 1). A Voz o apresenta como amigo; um gatilho força o duelo.
func king_intro() -> Array:
	return [
		_l(VOZ, "Olha. Alguém vem da névoa. Não temas — eu o conheço. É um rei antigo, e é gentil."),
		_l("O Rei", "Faísca perdida... que bom que acordaste. Vem. Eu guardo este limiar há eras."),
		_l("O Rei", "Mas o limiar tem uma lei: só passa quem me toca com a própria luz. Mostra-me a tua."),
		_l(VOZ, "É um rito. Bate nele — de coração leve. Ele não te quer mal."),
	]


## O Rei "cai" (tela 1): o selo racha e os 7 Arcontes acordam.
func king_fall() -> Array:
	return [
		_l("O Rei", "...Ah. Tua luz é maior do que eu lembrava. (a máscara racha; ele afunda na névoa)"),
		_l(VOZ, "Sentiste? O selo dele se partiu. Lá em cima, sete tronos acabaram de acordar."),
		_l(VOZ, "Sete Arcontes. Sete Anéis. Reúne todos, e eu te mostro como desfazer este mundo de mentira."),
	]


## Introdução de cada Éon (primeira tela do ato).
func eon_intro(eon: int) -> Array:
	match eon:
		0: return [
			_l(VOZ, "Éon do Torpor. Aqui os mortos não sabem que morreram — a cidade sonha por eles."),
			_l(VOZ, "Não odeies os que dormem. Tu dormias ontem."),
		]
		1: return [
			_l(VOZ, "Éon da Fome. Estes mercados devoram quem compra. Tudo aqui tem preço — até a saudade."),
			_l(VOZ, "O Arconte daqui te oferecerá o que perdeste. Lembra: réplica não é retorno."),
		]
		2: return [
			_l(VOZ, "Éon da Corrente. A lei deste lugar não protege — prende. Cada selo é um cadeado."),
			_l(VOZ, "Quebra os selos. A ordem do carcereiro não é ordem, é medo com coroa."),
		]
		3: return [
			_l(VOZ, "Éon do Silêncio. Uma biblioteca de livros em branco. Aqui, a verdade foi calada página por página."),
			_l(VOZ, "Escuta o que não é dito. É assim que se lê este lugar."),
		]
		4: return [
			_l(VOZ, "Éon do Espelho. Cuidado, Portadora. Aqui tu és o inimigo."),
			_l(VOZ, "O reflexo lutará com a tua força e a tua fúria. Vence quem se conhece."),
		]
		5: return [
			_l(VOZ, "Éon da Praga. As faíscas aqui apagam devagar, como velas num pântano."),
			_l(VOZ, "O desespero é a última arma deles. Não é a tua."),
		]
		6: return [
			_l(VOZ, "Éon da Coroa. O último degrau. O Arconte daqui quase tocou o trono do Cego."),
			_l(VOZ, "Ele te oferecerá poder. É a mais velha das mentiras — e a mais doce."),
		]
	return []


## Tentação do Arconte (antes da luta). Cada um oferece a sua mentira.
func temptation(boss_id: String) -> Array:
	match boss_id:
		"arconte_sono": return [
			_l("Athoth", "Portadora... por que sangrar? Dorme. Devolvo-te o sonho onde ninguém morreu."),
			_l(VOZ, "Se dormires agora, nunca mais acordas. Escolhe."),
		]
		"arconte_fome": return [
			_l("Harmas", "Tua casa. Tua gente. Teu riso. Tenho tudo aqui, quentinho. Fica, e devolvo tudo."),
			_l(VOZ, "É cera com cheiro de memória. Escolhe."),
		]
		"arconte_corrente": return [
			_l("Galila", "Sem lei, tudo cai. Ajoelha, e faço de ti o meu selo mais belo."),
			_l(VOZ, "Corrente polida ainda é corrente. Escolhe."),
		]
		"arconte_silencio": return [
			_l("Yabel", "...(ele não fala. Ele te oferece o descanso de nunca mais precisar responder.)"),
			_l(VOZ, "O silêncio dele é um túmulo confortável. Escolhe."),
		]
		"arconte_espelho": return [
			_l("Astaphaios", "Olha. Tu, antes das cinzas. Feliz. Podes ficar deste lado do vidro pra sempre."),
			_l(VOZ, "É o golpe mais cruel de todos. Eu sei. Escolhe."),
		]
		"arconte_praga": return [
			_l("Belias", "Tudo apodrece, Portadora. Até faíscas. Rende-te agora e poupa-te o fim."),
			_l(VOZ, "Ele confunde cansaço com verdade. Escolhe."),
		]
		"arconte_coroa": return [
			_l("Armupiel", "O Cego está velho. Toma minha coroa, senta no trono deste andar. Sê deusa, como eu quase fui."),
			_l(VOZ, "Reinar na prisão ainda é estar preso. Escolhe."),
		]
	return [_l(VOZ, "Ele mente. Escolhe.")]


func refusal_response() -> Array:
	refusals += 1
	return [_l(VOZ, "Bem. A recusa também é uma lâmina — e tu a estás afiando.")]


func concession_response() -> Array:
	concessions += 1
	return [
		_l(VOZ, "...Aceitaste o suborno dele. As faíscas pesam no bolso e na alma."),
		_l(VOZ, "Não te julgarei. Mas lembra: tudo que os Arcontes dão, eles cobram."),
	]


## O Anel de um Arconte se condensa e uma magia nova desperta.
func ring_gained(boss_id: String, skill_name: String, count: int) -> Array:
	var who := boss_id.trim_prefix("arconte_")
	var lines := [
		_l(VOZ, "A essência dele se condensa... um Anel. O %dº. Sente: a paixão do Arconte agora obedece a ti — %s." % [count, skill_name]),
	]
	match who:
		"sono": lines.append(_l(VOZ, "Estranho... ao tocar o Anel, tu lembraste de algo. Um quarto branco. Não importa. Sobe."))
		"espelho": lines.append(_l(VOZ, "Este Anel pesa mais que os outros, não? Coisa de espelho. Ignora."))
		"coroa": lines.append(_l(VOZ, "Sete. Todos os sete. Vem. Sobe ao santuário — é hora do ritual."))
		_: lines.append(_l(VOZ, "Faltam %d. Sobe." % (7 - count)))
	return lines


## Encontros com Soter, o Ungido (telas 10, 24, 38). Ele não luta — abençoa.
func soter_meeting(n: int) -> Array:
	match n:
		0: return [
			_l("Soter", "Paz, Portadora. Não saques a lâmina — o Cego não me vê, e contigo não brigo."),
			_l("Soter", "Eu conheci tua gente. Carrego os nomes deles, se um dia quiseres ouvi-los."),
			_l("Soter", "Não posso subir por ti. Mas posso ungir o que já é teu. Escolhe."),
		]
		1: return [
			_l("Soter", "De novo tu. Mais fundo, mais forte... e mais cansada. Senta um instante. O mundo espera."),
			_l("Soter", "Sabes por que não luto? Porque toda lâmina, até a mais justa, ensina a mão a fechar."),
			_l("Soter", "A tua ainda sabe abrir. Guarda isso. Escolhe a bênção."),
		]
		2: return [
			_l("Soter", "Última vez que nos vemos deste lado, Portadora. Lá em cima, nem eu alcanço."),
			_l("Soter", "Quando venceres — e vais vencer — lembra dos que dormem. A pergunta final não será sobre força."),
			_l("Soter", "Vai. E que a tua faísca seja maior que a tua fúria. Escolhe."),
		]
	return []


func soter_blessings() -> Array:
	return ["Cura plena", "Arma desperta (+1 nível)", "Vigor (+25 vida máx)"]


## Encontro único com Velkar, o Arrependido (tela 45).
func velkar_meeting() -> Array:
	return [
		_l("Velkar", "Não recues a lâmina por mim, Portadora. Já fui Arconte. Larguei a corrente... e ela levou meu braço junto."),
		_l("Velkar", "Guardei almas por eras achando que era lei. Era medo. O Cego também tem medo — todo carcereiro tem."),
		_l("Velkar", "Vou te dizer o que Soter não diz: lá em cima não há tirano nenhum. Há uma criança cega, num trono grande demais, chamando pela mãe."),
		_l("Velkar", "Quando fores acabar com ele... acaba direito. Toma — faíscas que colhi quando era monstro. Que pesem menos nas tuas mãos que nas minhas."),
		_l(VOZ, "...Até um Arconte acorda. Guarda isso pro final, Portadora."),
	]


## O ROUBO + A MÁSCARA CAI (tela 50, após o 7º Arconte). O Rei reaparece e leva
## os sete Anéis; a voz-amiga se revela o Demiurgo.
func theft() -> Array:
	return [
		_l(VOZ, "Chegaste. Minha fiel... trouxeste todos os sete. Fizeste tudo tão bem."),
		_l("O Rei", "(sai da névoa, inteiro, a máscara sem rachadura) Tão bem que nunca desconfiaste."),
		_l("O Rei", "(os sete Anéis arrancam-se de ti e voam pras mãos dele) A voz que te guiou desde o primeiro dia..."),
		_l("Yaldabaoth", "...era EU. Nunca houve amigo. Só o carcereiro — e a chave que ele forjou: tu."),
		_l("Yaldabaoth", "Os sete Anéis são o meu corpo. E tu os reuniste nas minhas mãos. Obrigado, faísca."),
		_l("???", "(por baixo da voz dele, fraca, vinda de DENTRO dos Anéis) ...espera... eu... lembro..."),
		_l("Yaldabaoth", "(ele SE TORNA os Anéis — um motor de anéis girando — e afunda no chão) Desce, se tiveres coragem. O Centro te espera."),
	]


## O Centro (tela 51): sem os Anéis, sem a Voz.
func center_intro() -> Array:
	return [
		_l("Sophia", "...Silêncio. Pela primeira vez, nenhuma voz na minha cabeça."),
		_l("Sophia", "Os Anéis se foram. Mas os Arcontes... eu os sinto aqui embaixo. Cascas dele. Ecos."),
		_l("Sophia", "Cada eco que eu quebrar me devolve um caco do que eu era. Vamos lembrar."),
	]


## Um eco quebrado devolve um caco de memória (texto curto, aviso no HUD).
func echo_shard(boss_id: String, skill_name: String) -> String:
	return "Caco de memória: %s volta a ti" % skill_name


## A batalha final (tela 54): o choque, a mente dele.
func final_pre() -> Array:
	return [
		_l("Sophia", "(um clarão; o chão some; o mundo vira o INTERIOR de uma mente) ...Estou dentro dele."),
		_l("Yaldabaoth", "Duas caras. A que tu amaste e a que tu temes. Ambas são eu. Derruba uma, e a outra a refaz."),
		_l("Sophia", "Então caem as duas. Juntas."),
	]


func final_form_fell(form_name: String) -> String:
	return "%s caiu — derruba a outra ANTES que se refaça!" % form_name


func final_revive(form_name: String) -> String:
	return "%s se refez." % form_name


## Após as DUAS formas do Demiurgo caírem. Os Anéis se fundem à Sophia e ela
## recupera a memória de quem é. O reclamar.
func final_lines() -> Array:
	return [
		_l("Sophia", "(as duas formas caem juntas; os sete Anéis param... e VOAM pra dentro dela) ...Ah. AH. Agora eu vejo."),
		_l("Sophia", "Os Anéis são EU. Cacos meus que tu arrancaste e forjaste em correntes — pra prender o mundo inteiro dentro do teu universo."),
		_l("Sophia", "Eu entrei aqui de propósito, pra te impedir. E o poder dos Anéis me fez esquecer até disso — me fez te CAÇAR, remontando a mim mesma sem saber."),
		_l("Yaldabaoth", "...mãe? eu não queria ser cego. eu só queria que alguém olhasse pra mim."),
		_l("Sophia", "Eu estou olhando. (os cacos se fundem; ela volta a ser inteira) Volta pra dentro de quem te fez — não pra morrer: pra ser reclamado."),
		_l("Sophia", "Agora, a última escolha, que nenhum deus fez por nós: o que fazer com um mundo de adormecidos?"),
	]


func final_choices(sleepers: int) -> Array:
	var semente_ok := sleepers >= 4
	return [
		"Ascensão — abrir o Pleroma",
		"Ruptura — tomar o trono",
		{"text": "Semente — plantar a gnose", "enabled": semente_ok,
			"hint": "Desperte ao menos 4 Adormecidos pelo caminho"},
	]


## Textos de fim por escolha.
func apply_ending(index: int) -> void:
	match index:
		0:
			ending = "ascensao"
			GameManager.end_title = "ASCENSÃO"
			GameManager.end_subtitle = "Toda faísca voltou à Fonte. O Kenoma se desfez como um sonho ao acordar.\nVerdade total. Mundo nenhum. A luz não olhou para trás."
		1:
			ending = "ruptura"
			GameManager.end_title = "RUPTURA"
			GameManager.end_subtitle = "Sentaste no trono ainda morno. A coroa serviu.\nNo Kenoma, nada mudou — só o nome do carcereiro. Um dia, alguém subirá os Éons... atrás de ti."
		2:
			ending = "semente"
			GameManager.end_title = "SEMENTE"
			GameManager.end_subtitle = "Recusaste o trono e a porta. Desceste de volta, de faísca em faísca,\nacordando um por um. Sem apocalipse, sem prisão: liberdade lenta — a única que dura."
	if ending != "" and not RunManager.endings_seen.has(ending):
		RunManager.endings_seen.append(ending)


# --- CONVERSA DE CAMINHADA (legendas sem pausar — ver Gnosis/CaptionBar) --------
## A Voz comenta cada Éon com o viés DELA (o Pleroma abandonou as faíscas, a Luz
## de cima não olha pra baixo, "eu fiquei"); a Sophia responde a si mesma e as
## dúvidas crescem Éon a Éon, alimentadas pelas Estelas (que dão a versão do
## Pleroma). REGRA DE OURO mantida: nada aqui entrega a virada antes da 64.
## Cada fala é um {speaker, text}; `Gnosis` garante que nenhuma repete no run.

## Chegada à tela (após os diálogos de entrada). 1–2 falas.
func walk_arrival(screen: int) -> Array:
	var role := RunManager.screen_role(screen)
	if role == "king":
		return [
			_l(VOZ, "As cinzas ainda estão quentes. Anda — a névoa não espera por ninguém."),
			_l("Sophia", "(uma pedra escrita, ali atrás. Alguém deixou palavras pra quem acordasse.)"),
		]
	if role == "final":
		return [_l("Sophia", "Dentro dele. Ele é grande demais pra alguém tão pequeno.")]
	if role == "center":
		match screen - RunManager.CENTER_FIRST:
			0: return [_l("Sophia", "Sem voz. Sem Anéis. Só eu e os ecos dele.")]
			1: return [_l("Sophia", "Os ecos têm o rosto dos Arcontes. Mas se movem como ele.")]
			_: return [_l("Sophia", "Cada eco quebrado me devolve um caco. Estou me remontando de dentro pra fora.")]
	var off := RunManager.eon_offset(screen)
	var pool: Array = _arrival_pool(RunManager.eon_index(screen))
	if off < 0 or off >= pool.size():
		return []
	return pool[off]


## Zona limpa. 1 fala (a última zona das telas de chefe fica com o diálogo).
func walk_cleared(screen: int, zone: int) -> Array:
	var role := RunManager.screen_role(screen)
	if role in ["king", "archon", "final"]:
		return []
	if role == "center":
		var c := [
			_l("Sophia", "Um caco a mais. Eu lembro do quarto branco. Era o berçário dele."),
			_l("Sophia", "Ele me chamou de chave. Chaves abrem. Ele esqueceu que abrem dos dois lados."),
			_l("Sophia", "Os ecos não gritam quando caem. Choram."),
		]
		return [c[(screen - RunManager.CENTER_FIRST) % c.size()]]
	var pool: Array = _cleared_pool(RunManager.eon_index(screen))
	if pool.is_empty():
		return []
	# Determinístico por tela+zona, varrendo o pool inteiro ao longo do Éon.
	var k := (RunManager.eon_offset(screen) * 3 + zone) % pool.size()
	return [pool[k]]


## Falas de chegada por Éon, indexadas pelo offset da tela (0..8).
func _arrival_pool(eon: int) -> Array:
	match eon:
		0: return [
			[_l("Sophia", "Eles dormem de pé. Ninguém aqui sabe que a cidade acabou.")],
			[_l(VOZ, "Vês? Os que dormem não sofrem. Quem acorda, sim. Mas só quem acorda sobe.")],
			[_l("Sophia", "A pedra dizia que antes de tudo havia um Silêncio inteiro. Por que isso me parece... uma lembrança?")],
			[_l(VOZ, "Não confies demais nas pedras. Quem as escreveu já não está aqui pra explicar.")],
			[_l(VOZ, "O Campeão de Athoth guarda o santuário. Acorda-o a golpes.")],
			[_l("Sophia", "Se o Pleroma é tão cheio, por que ninguém de lá veio buscar os que dormem?"),
			 _l(VOZ, "Porque a Luz de cima não olha pra baixo. Eu olho.")],
			[_l(VOZ, "Sente a névoa? É o bafo de Athoth. Ela quer que tu deites.")],
			[_l(VOZ, "A antessala. Atrás dela, o primeiro trono. Não deites. Nunca deites.")],
			[_l("Sophia", "Um trono num quarto de sonho. Ele nem abriu os olhos.")],
		]
		1: return [
			[_l("Sophia", "Mercados. Cheiro de pão. Ninguém come — todos mastigam.")],
			[_l(VOZ, "A hyle, a matéria bruta, tem fome de tudo que brilha. Tu brilhas. Cuidado.")],
			[_l("Sophia", "As pedras chamam este lugar de Kenoma: o vazio. Mas está cheio até a borda."),
			 _l(VOZ, "Cheio de falta. É o que 'vazio' quer dizer.")],
			[_l(VOZ, "Harmas cobra por cada lembrança. Não compres nada. Nem a saudade.")],
			[_l(VOZ, "O Glutão-campeão come o que mata. Não morras perto dele.")],
			[_l("Sophia", "Se o Cego fez este mundo por engano, quem deixou o engano durar?"),
			 _l(VOZ, "Os de cima. Eles chamam isso de paciência.")],
			[_l(VOZ, "Soter anda por aqui. Não o escutes demais — ele fala bonito e não luta.")],
			[_l(VOZ, "A boca do trono já está aberta. Entra com a lâmina na frente.")],
			[_l("Sophia", "Ele tem um mercado inteiro na barriga. E ainda olha pra mim com fome.")],
		]
		2: return [
			[_l("Sophia", "Selos por toda parte. Cada porta tem um cadeado e cada cadeado, um nome.")],
			[_l(VOZ, "Heimarmene, os antigos chamavam. O destino como corrente. Aqui, é literal.")],
			[_l("Sophia", "A pedra diz que os astros são os elos. Sete elos, sete céus, sete Arcontes."),
			 _l(VOZ, "E tu já partiste dois. Continua.")],
			[_l(VOZ, "Galila não te odeia. Ele te classifica. É pior.")],
			[_l(VOZ, "O Carcereiro-campeão prende primeiro, pergunta depois. A esquiva quebra a corrente.")],
			[_l("Sophia", "Se a lei daqui é medo com coroa, quem é o rei?"),
			 _l(VOZ, "O Cego, no alto. Ninguém mais. Sobe.")],
			[_l("Sophia", "As pedras dizem que o sopro dentro do barro veio de fora deste mundo. Então eu também vim?"),
			 _l(VOZ, "Vieste de mim. Eu te achei. Não esqueças a ordem das coisas.")],
			[_l(VOZ, "Última porta antes do trono. As correntes dele cantam quando têm medo.")],
			[_l("Sophia", "Um trono feito de elos. Ele se acorrentou a si mesmo pra não cair.")],
		]
		3: return [
			[_l("Sophia", "Livros em branco. Milhares. Alguém apagou uma biblioteca inteira.")],
			[_l(VOZ, "O Logos — a Palavra — foi calado aqui. Yabel costurou a própria boca pra dar exemplo.")],
			[_l("Sophia", "As pedras falam de livros enterrados num jarro, achados por acaso. Verdades sobrevivem enterradas."),
			 _l(VOZ, "Sobrevivem. Não é o mesmo que vencer.")],
			[_l(VOZ, "Aqui as magias calam. Confia na lâmina, que não precisa falar.")],
			[_l(VOZ, "O Bibliotecário-campeão cala tudo num raio. Fica longe e bate rápido.")],
			[_l("Sophia", "O que não é dito... eu tenho ouvido. Uma voz por baixo da tua. Fraca."),
			 _l(VOZ, "Eco. Este Éon é cheio deles. Ignora.")],
			[_l("Sophia", "Se lembrar é saber, eu quero lembrar. Mesmo o que dói."),
			 _l(VOZ, "Lembrar tem hora. Agora é hora de subir.")],
			[_l(VOZ, "A antessala do Silêncio. Nem eu falo lá dentro. Ouve os passos.")],
			[_l("Sophia", "Ele não vai falar. E eu vou ter que responder mesmo assim.")],
		]
		4: return [
			[_l("Sophia", "Água parada por toda parte. E em cada poça, eu.")],
			[_l(VOZ, "A Sabedoria da pedra olhou pra baixo, viu o próprio rosto na água e desceu atrás dele. Não repitas.")],
			[_l("Sophia", "O nome na pedra é o meu. Sophia."),
			 _l(VOZ, "É um nome comum. Sabedoria. Metade das mães do Kenoma põe esse nome.")],
			[_l(VOZ, "Astaphaios te dará o que mais queres: tu, antes de tudo. É o golpe mais cruel.")],
			[_l(VOZ, "O Reflexo-campeão recua quando bates. Bate onde ele vai estar.")],
			[_l("Sophia", "Se eu sou o reflexo de alguém... quem está do outro lado do vidro?"),
			 _l(VOZ, "Ninguém. Vidro é vidro. Anda.")],
			[_l("Sophia", "A pedra diz que ela se arrependeu treze vezes e cantou. Eu ainda não cantei nenhuma.")],
			[_l(VOZ, "Última sala antes do vidro grande. Não olhes pra ti mais do que o necessário.")],
			[_l("Sophia", "Ele tem o meu rosto. A Voz diz que é truque. A Voz diz muita coisa.")],
		]
		5: return [
			[_l("Sophia", "Pântano. As faíscas afundam devagar, como velas.")],
			[_l(VOZ, "A matéria apodrece. É a única lei que o Cego não escreveu — e a única que o assusta.")],
			[_l("Sophia", "A pedra diz que o Reino está dentro e fora. Dentro deste pântano?"),
			 _l(VOZ, "Dentro de ti. Fora daqui. Anda.")],
			[_l(VOZ, "Belias não mente. Ele só está cansado e acha que o cansaço é a verdade.")],
			[_l(VOZ, "O Portador-campeão deixa esporos ao morrer. Mata e sai.")],
			[_l("Sophia", "Um príncipe desceu pra buscar uma pérola e esqueceu de tudo. Até uma carta o lembrar."),
			 _l(VOZ, "Bonito. Ninguém te mandou carta nenhuma. Tens a mim.")],
			[_l("Sophia", "Velkar disse que lá em cima não há tirano — há uma criança. Tu nunca me disseste isso."),
			 _l(VOZ, "Velkar largou a corrente e perdeu o braço. Não é conselheiro de ninguém.")],
			[_l(VOZ, "Última antessala podre. Depois disso, a Coroa. Aguenta.")],
			[_l("Sophia", "Ele já está morrendo há eras. Só não deixa ninguém terminar.")],
		]
		6: return [
			[_l("Sophia", "Um trono em cada esquina. Todos vazios. Todos esperando alguém sentar.")],
			[_l(VOZ, "O último degrau. Armupiel quase tocou o trono do Cego. 'Quase' é a palavra que o define.")],
			[_l("Sophia", "A pedra fala de um Chamado: uma voz de fora que acorda quem dorme. Foi assim que tu me achaste?"),
			 _l(VOZ, "Foi. Eu chamei. Tu ouviste. É tudo que importa.")],
			[_l(VOZ, "Poder é a mais velha das mentiras — e a mais doce. Ele vai te oferecer.")],
			[_l(VOZ, "O Pretoriano-campeão tem broquel. Pesado ou magia, por trás.")],
			[_l("Sophia", "As pedras dizem que o corpo é aparência e a faísca é o real. Então o que estou salvando?"),
			 _l(VOZ, "A faísca. Sempre a faísca. O corpo serve pra subir.")],
			[_l("Sophia", "Seis Anéis giram na minha mão como se se conhecessem. Como se fossem partes de uma só coisa."),
			 _l(VOZ, "São. São a chave. Falta o sétimo dente.")],
			[_l(VOZ, "A antessala da Coroa. Depois dela, o sétimo. E depois... o ritual. Eu prometi te mostrar.")],
			[_l("Sophia", "Uma coroa alta demais pra cabeça que a carrega. Ele sabe. Por isso grita.")],
		]
	return []


## Falas de zona limpa por Éon (pool varrido ao longo das telas do Éon).
func _cleared_pool(eon: int) -> Array:
	match eon:
		0: return [
			_l(VOZ, "Bem. Eles voltam ao chão, e o chão ao sono."),
			_l("Sophia", "Eles não gritam. Só... deitam. Como se agradecessem."),
			_l(VOZ, "Cada faísca que soltas fica mais leve. Sente? Elas sobem por ti."),
			_l("Sophia", "A Voz diz que as faíscas sobem por mim. Sobem pra onde?"),
			_l(VOZ, "Não pares pra pensar aqui. Pensar, no Torpor, vira cochilo."),
			_l("Sophia", "Eu lembro de um quarto branco. Não sei de onde."),
			_l(VOZ, "Anda. O sono deste Éon tem dedos compridos."),
			_l("Sophia", "(as pedras falam de uma Sabedoria que quis ver a Fonte sozinha. Por que esse nome dói?)"),
		]
		1: return [
			_l(VOZ, "Devorados pelos próprios dentes. A fome sempre acaba assim."),
			_l("Sophia", "Eles caem com a boca aberta. Ainda com fome."),
			_l(VOZ, "Mais faíscas. Sente como pesam menos? Estás quase leve."),
			_l("Sophia", "A pedra disse que os sete foram feitos do Cego, à imagem dele. Se eu derrubar os sete... derrubo o quê?"),
			_l(VOZ, "Pergunta certa, hora errada. Anda."),
			_l("Sophia", "Por que tu nunca me dizes o teu nome?"),
			_l(VOZ, "Um nome aqui vira coleira. Chama-me como sempre: Voz."),
			_l(VOZ, "Comida, sono, moeda — todas as correntes começam macias."),
		]
		2: return [
			_l(VOZ, "Os selos caem. A ordem deles era só ferrugem."),
			_l("Sophia", "Eles gritam 'lei' quando morrem. Nenhum diz 'justiça'."),
			_l(VOZ, "Cada selo quebrado é uma corrente a menos no mundo. Tu és boa nisso."),
			_l("Sophia", "Boa em quebrar. A Voz nunca me elogia por outra coisa."),
			_l(VOZ, "Não filosofa com o carcereiro. Ele adora."),
			_l("Sophia", "Se o destino é corrente, quem segura a outra ponta?"),
			_l(VOZ, "Anda. Os astros não param de girar por ti."),
		]
		3: return [
			_l("Sophia", "Caem sem som. Como páginas."),
			_l(VOZ, "Um silêncio a menos. O mundo já parece mais alto."),
			_l("Sophia", "Há uma pergunta que eu não faço porque tenho medo da resposta."),
			_l(VOZ, "Então não faças. Perguntas aqui viram tinta em branco."),
			_l("Sophia", "A pedra dizia: gnose não é fé nem obra. É lembrar. E eu não lembro de nada antes das cinzas."),
			_l(VOZ, "Lembrarás quando os sete Anéis estiverem juntos. Eu prometo."),
			_l(VOZ, "Anda. O silêncio gruda nas botas."),
		]
		4: return [
			_l("Sophia", "Quando caem, os cacos mostram um rosto. Nunca o deles."),
			_l(VOZ, "Não olhes os cacos. Olha o caminho."),
			_l("Sophia", "A Voz odeia este Éon mais do que os outros. Por quê?"),
			_l(VOZ, "Porque espelhos mentem melhor do que eu jamais mentiria."),
			_l("Sophia", "Eu tenho a força dele? Ou ele tem a minha?"),
			_l(VOZ, "Tu tens a tua. Chega. Sobe."),
			_l("Sophia", "(no fundo da poça, por um instante: um quarto branco, e alguém pequeno chorando)"),
		]
		5: return [
			_l("Sophia", "Eles apodrecem antes de cair. Já estavam mortos há muito."),
			_l(VOZ, "A poça some. Boa. Não pises no que ficou."),
			_l("Sophia", "Quanto do que eu sou é matéria, e quanto é o sopro?"),
			_l(VOZ, "O sopro. Só ele. O resto é barro emprestado."),
			_l(VOZ, "Cinco Anéis. Sente como eles puxam pro alto? Estão com pressa."),
			_l("Sophia", "Os Anéis puxam. Mas não pra cima. Puxam uns pros outros."),
			_l(VOZ, "Anda. A Praga entra pelos pés quando paras."),
		]
		6: return [
			_l(VOZ, "Coroas caem de mais alto e fazem mais barulho. Só isso."),
			_l("Sophia", "Eles morrem chamando pelo rei. Nenhum sabe o nome dele."),
			_l(VOZ, "Quase. Quase, Portadora. Eu sinto os sete a um passo."),
			_l("Sophia", "A Voz nunca teve tanta pressa. Nunca."),
			_l("Sophia", "Se a salvação é retorno... eu volto pra onde?"),
			_l(VOZ, "Pra mim. Pra onde tudo começou. Anda."),
			_l(VOZ, "Não pares. Nem pra ler. Já sabes o bastante."),
			_l("Sophia", "(as pedras dizem uma coisa; a Voz, outra. Uma das duas está errada. Ou as duas.)"),
		]
	return []


# --- EPÍLOGO (cards após o final escolhido — ver Cinematic.epilogue) -----------
## Textos curtos por final; o título e o subtítulo já estão no GameManager
## (apply_ending). Cada item vira um card.
func epilogue_cards(which: String) -> Array:
	match which:
		"ascensao": return [
			"As sete esferas apagaram-se como lamparinas ao amanhecer. Os Arcontes, sem luz para roubar, tornaram-se o que sempre foram: nomes.",
			"Yaldabaoth voltou para dentro de quem o fez. Não como castigo. Como filho que encontrou o colo.",
			"No Pleroma ninguém contou esta história. Lá não há passado a contar — só a Plenitude, inteira de novo.",
		]
		"ruptura": return [
			"A coroa pesava menos do que ele dizia. Isso devia ter sido o aviso.",
			"Os sete tronos foram ocupados por sete cascas novas — ou pelas mesmas, com outros nomes. O Kenoma não percebeu a diferença.",
			"Um dia alguém acordará entre cinzas e ouvirá uma voz gentil oferecer ajuda. Tu já sabes o que essa voz vai dizer.",
		]
		"semente": return [
			"Não subiu e não sentou. Desceu, tela por tela, batendo à porta dos que dormem.",
			"Os Arcontes continuam de pé. Mas cada Adormecido acordado é um degrau que eles não controlam.",
			"É a estrada lenta de Tomé: o Reino espalhado sobre a terra — e cada vez mais gente a vê-lo.",
		]
	return ["A faísca lembrou. O resto é silêncio."]
