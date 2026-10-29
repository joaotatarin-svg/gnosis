class_name BestiaryLore
extends RefCounted
## LORE DO BESTIÁRIO (backlog #35) e regras de DESBLOQUEIO por encontro (#17/#26).
## Cada entrada: 2 linhas de lore (registro das Estelas: impessoal, presente,
## sem "tu" nem "você") + 1 dica tática (registro de sistema: imperativo de
## "você"). Grafia e pontuação conforme docs/ESTILO_TEXTO.md.
## Nada aqui revela a virada: as entradas do fim (Rei caído, Colosso,
## Yaldabaoth) só abrem depois de vistas.
##
## Desbloqueio (sem depender de um único sistema):
##   1. `Bestiary.seen(id)` / `CodexSession.is_unlocked(i)` /
##      `Progression.is_boss_beaten(id)` — APIs do Técnico, se existirem;
##   2. senão (ou save antigo sem lista de vistos), a MELHOR TELA alcançada
##      (`RunManager.best_screen`): quem chegou lá passou por elas;
##   3. um final visto (ou `--bestiario-tudo` na linha de comando) abre tudo.

const ENTRIES := {
	"sophia": [
		"A faísca que acordou sem memória no Limiar.",
		"Atravessa os sete Éons para lembrar quem é.",
		"A arma desperta nos santuários: cada nível abre combos novos.",
	],
	# --- criaturas comuns ---
	"larva": [
		"Restos de luz que o Kenoma não terminou de apagar.",
		"Rastejam para onde ainda há calor.",
		"Fracas e lentas: um combo leve resolve.",
	],
	"sombra": [
		"Uma faísca que esqueceu o próprio nome.",
		"Vaga depressa, sem rumo, atrás de quem ainda brilha.",
		"Rápida: espere a investida passar e responda.",
	],
	"servo": [
		"Forjado em hyle e obediência pelo Demiurgo.",
		"Carrega a lâmina como quem carrega uma ordem.",
		"Apare o golpe dourado e puna a abertura.",
	],
	"acolito": [
		"Acende fogos-fátuos para que ninguém ache o caminho de volta.",
		"Nunca deixa a presa chegar perto: atira e recua.",
		"Ele foge quando você se aproxima: esquive das setas e feche a distância.",
	],
	"larva_ardente": [
		"Uma larva que guardou fogo demais.",
		"Corre até a luz mais próxima e se desfaz em chamas.",
		"A explosão não pode ser aparada: esquive.",
	],
	"espinho": [
		"Guardião de casca espinhosa, posto nas portas dos Éons.",
		"Lento para se erguer, pesado para cair.",
		"Quando ele erguer os braços, saia: a pancada esmaga o chão.",
	],
	"canino": [
		"Uma besta criada para farejar faíscas.",
		"Não late. Investe.",
		"Esquive da investida e golpeie enquanto ele freia.",
	],
	"cornudo": [
		"Ceifador de chifres que colhe a luz como trigo maduro.",
		"Não guarda raiva; só cumpre a colheita.",
		"Apare o golpe dourado e responda com o combo.",
	],
	"escudeiro": [
		"Guarda o Selo com um escudo que não conhece cansaço.",
		"Atrás dele, a ordem; à frente, ninguém.",
		"O golpe leve bate no escudo: use o forte ou uma magia.",
	],
	"espectro": [
		"Um eco que não aprendeu a pousar.",
		"Paira em silêncio e cai sobre quem olha para baixo.",
		"Ao pousar do mergulho, fica um instante no chão: golpeie aí.",
	],
	"alado": [
		"Vigia dos céus baixos do Kenoma.",
		"Do alto, aponta e dispara.",
		"Atira de longe: aproxime-se entre um disparo e outro.",
	],
	"bruto": [
		"Massa de ferro que obedece sem perguntar.",
		"Cada passo faz o chão lembrar o próprio peso.",
		"Não troque golpes com ele: esquive da pancada e volte.",
	],
	"arauto": [
		"Anuncia o Silêncio com uma coroa e um cajado.",
		"A voz não chega; só o disparo.",
		"Atira de longe: feche a distância e não pare de golpear.",
	],
	"fantasma": [
		"Um eco do vazio que não decide onde está.",
		"Some diante da presa e surge às suas costas.",
		"Quando ele sumir, vire-se: ele reaparece atrás de você.",
	],
	"invocador": [
		"Semeia o chão de larvas e reza por elas.",
		"Prefere a distância e a multidão.",
		"Derrube-o primeiro, antes que o chão se encha de larvas.",
	],
	"aberracao": [
		"Uma forma que o Kenoma começou e desistiu de terminar.",
		"Garras, espinhos e pressa.",
		"Investe com força: esquive e contra-ataque.",
	],
	# --- os bots de cada Éon ---
	"sonambulo": [
		"Caminha dormindo pelas catacumbas do Torpor.",
		"Boceja, e quem respira o bocejo fica pesado.",
		"Saia da frente do bocejo: ele deixa você lenta.",
	],
	"glutao": [
		"A Fome feita corpo, com uma boca no lugar do peito.",
		"Nunca está cheio; só está com menos fome.",
		"Cada mordida que acerta o cura: não deixe que ele morda.",
	],
	"carcereiro": [
		"Ninguém sabe do que é acusado; ele também não.",
		"A corrente dele nunca solta o que prende.",
		"A corrente prende você no lugar: esquive quando ele lançar.",
	],
	"mudo": [
		"Guarda a biblioteca de livros em branco.",
		"A boca costurada; o silêncio, contagioso.",
		"Perto dele as magias calam: lute com a arma.",
	],
	"reflexo": [
		"O Espelho devolve tudo, até o golpe.",
		"Recua no instante exato do ataque.",
		"Ele recua do primeiro golpe: avance e emende o combo.",
	],
	"esporos": [
		"Carrega a Praga nas costas, como um jardim podre.",
		"Morto, ainda floresce.",
		"Ao cair, deixa uma poça de veneno: afaste-se dela.",
	],
	"pretoriano": [
		"A guarda pessoal da Coroa.",
		"Não dá as costas a ninguém.",
		"De frente, só o golpe forte fere: ataque pelas costas.",
	],
	"sombra_sophia": [
		"O Espelho tira dela a forma e a enche de vazio.",
		"Luta como ela, e mais depressa do que ela.",
		"Não troque golpes: apare e responda.",
	],
	# --- os sete Arcontes ---
	"arconte_sono": [
		"Athoth, Arconte do Torpor, oferece o sono como quem oferece abrigo.",
		"A névoa dele rouba o movimento.",
		"Saia da névoa: dentro dela você fica lenta.",
	],
	"arconte_fome": [
		"Harmas, Arconte da Fome, vende tudo o que falta.",
		"Uma boca sem fim no lugar do torso.",
		"Quando ele começar a sugar, afaste-se antes da pancada.",
	],
	"arconte_corrente": [
		"Galila, Arconte da Corrente, classifica, julga e prende.",
		"Toda lei deseja uma corrente.",
		"A corrente prende no lugar: esquive do lançamento e da investida.",
	],
	"arconte_silencio": [
		"Yabel, Arconte do Silêncio, não fala: só cala.",
		"A aura dele enterra as magias no vazio.",
		"Na aura, use a arma. Ferido, ele surge às suas costas.",
	],
	"arconte_espelho": [
		"Astaphaios, Arconte do Espelho, devolve as palavras de quem o enfrenta.",
		"Prata, cacos e um “nós” que não é ninguém.",
		"Ferido, chama a Sombra da Sophia: não deixe que ela cerque você.",
	],
	"arconte_praga": [
		"Belias, Arconte da Praga, confunde cansaço com verdade.",
		"Onde passa, a vida esquece de morrer.",
		"A investida deixa poças de veneno: não lute em cima delas.",
	],
	"arconte_coroa": [
		"Armupiel, Arconte da Coroa: quase rei de tudo.",
		"Um trono feito de obediência.",
		"Ferido, chama servos e se blinda: derrube os servos primeiro.",
	],
	# --- o Limiar e o fim ---
	"rei": [
		"O sacerdote branco que guarda o Limiar.",
		"Gentil demais para quem fecha uma passagem.",
		"Apare os golpes dourados; esquive dos vermelhos.",
	],
	"rei_final": [
		"A máscara do Rei, agora sem quem a sustente.",
		"Mais frágil e mais rápida que a do Limiar.",
		"Leia o brilho cedo: o golpe chega mais depressa.",
	],
	"colosso": [
		"O que havia atrás da máscara: um gigante oco.",
		"Os cacos do rosto ainda refletem luz alheia.",
		"Fique fora do alcance da pancada e golpeie na volta.",
	],
	"demiurgo": [
		"Yaldabaoth, o Demiurgo: fez o Kenoma e o chamou de seu.",
		"Cego para tudo o que não é ele.",
		"Nenhuma arma basta sozinha: lembre-se do que arde.",
	],
	# --- aliados ---
	"soter": [
		"Soter, o Ungido, caminha livre pelo Kenoma: o Cego não o vê.",
		"Cura, desperta e pergunta. Nunca luta.",
		"Ele não luta: escolha um dos dons que ele oferece.",
	],
	"velkar": [
		"Velkar, o Arconte que soltou a própria corrente.",
		"Perdeu a coroa e o posto; ficou com a culpa.",
		"Ele não luta: ouça o que ele tem a dizer.",
	],
}

## Categoria curta (sobretítulo da ficha), em caixa alta na tela.
static func category(id: String) -> String:
	if id == "sophia":
		return "A faísca"
	if id in ["soter", "velkar"]:
		return "Aliado"
	if id == "rei" or id == "rei_final":
		return "O Limiar" if id == "rei" else "A Mente"
	if id == "colosso" or id == "demiurgo":
		return "A Mente"
	for i in Bestiary.bosses.size():
		if Bestiary.bosses[i].id == id:
			return "Arconte  ·  " + RunManager.EON_NAMES[i]
	var bot := Bestiary.EON_BOTS.find(id)
	if bot >= 0:
		return "Guardião  ·  " + RunManager.EON_NAMES[bot]
	if id == "sombra_sophia":
		return "Arconte  ·  Espelho"
	return "Criatura do Kenoma"


static func has_entry(id: String) -> bool:
	return ENTRIES.has(id)


## [linha 1, linha 2] da lore (vazio se não houver).
static func lore(id: String) -> PackedStringArray:
	var e: Array = ENTRIES.get(id, [])
	if e.size() < 3:
		return PackedStringArray()
	return PackedStringArray([e[0], e[1]])


static func tip(id: String) -> String:
	var e: Array = ENTRIES.get(id, [])
	return String(e[2]) if e.size() >= 3 else ""


# --- desbloqueio ---------------------------------------------------------------

## Tudo aberto: um final visto, ou `--bestiario-tudo` (ferramentas/QA).
static func all_unlocked() -> bool:
	if "--bestiario-tudo" in OS.get_cmdline_user_args():
		return true
	return RunManager.endings_seen.size() > 0


## A criatura/personagem `id` já foi encontrada?
static func is_seen(id: String) -> bool:
	if id == "sophia" or all_unlocked():
		return true
	if Bestiary.has_method("seen") and bool(Bestiary.call("seen", id)):
		return true
	if Progression.has_method("is_boss_beaten") and bool(Progression.call("is_boss_beaten", id)):
		return true
	# Save sem a lista de vistos (ou sem a API): deduz pela melhor tela.
	var api_has_data := Bestiary.has_method("seen_ids") and not (Bestiary.call("seen_ids") as Array).is_empty()
	if api_has_data and not _is_story_id(id):
		return false
	return seen_by_progress(id, RunManager.best_screen)


## Aliados e chefes de roteiro: aparecem em telas fixas (a dedução é exata).
static func _is_story_id(id: String) -> bool:
	return id in ["soter", "velkar", "rei", "rei_final", "colosso"] or Bestiary.is_boss_id(id)


## Dedução pura (testável) pela melhor tela alcançada `best`.
static func seen_by_progress(id: String, best: int) -> bool:
	var first := RunManager.FIRST_EON_SCREEN
	var L := RunManager.EON_LEN
	match id:
		"sophia": return true
		"rei": return best > RunManager.KING_SCREEN
		"rei_final", "colosso": return best >= RunManager.MAX_SCREEN
		"demiurgo": return false                     # só com um final visto
		"soter": return best > first + 1 * L + 6     # 1º encontro: Fome, offset 6
		"velkar": return best > first + 6 * L + 5    # Coroa, offset 5
		"sombra_sophia": return best >= first + 4 * L + L - 1
	for i in Bestiary.bosses.size():
		if Bestiary.bosses[i].id == id:
			return best >= first + i * L + L - 1       # chegou à tela do Arconte
	var bot := Bestiary.EON_BOTS.find(id)
	if bot >= 0:
		return best >= first + bot * L
	var t: Dictionary = Bestiary.get_type(id)
	if t.is_empty() or String(t.get("id", "")) != id:     # get_type cai na larva se não achar
		return false
	# Mesmas faixas do `Bestiary.types_for_screen` (run ativo): tier por Éon.
	var tier := int(t.get("tier", 9))
	var need_eon := {1: 0, 2: 1, 3: 3, 4: 5}.get(tier, 99) as int
	return best >= first + need_eon * L


## Arconte `i` (0..6) liberado para a Provação (vencido na campanha).
static func boss_trial_unlocked(i: int) -> bool:
	if i < 0 or i >= Bestiary.bosses.size():
		return false
	if all_unlocked():
		return true
	if CodexSession.has_method("is_unlocked"):
		return bool(CodexSession.call("is_unlocked", i))
	var archon := RunManager.FIRST_EON_SCREEN + i * RunManager.EON_LEN + RunManager.EON_LEN - 1
	return RunManager.best_screen > archon


## Índices dos Arcontes liberados para a Provação.
static func trial_bosses() -> Array[int]:
	var out: Array[int] = []
	for i in Bestiary.bosses.size():
		if boss_trial_unlocked(i):
			out.append(i)
	return out
