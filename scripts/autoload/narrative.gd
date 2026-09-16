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
