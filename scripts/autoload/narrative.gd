extends Node
## O texto do jogo: a Voz, o Rei, introduções de Éon, as tentações dos Arcontes,
## os Anéis, os santuários, o roubo, o Centro, a Mente e os finais. Autoload `Narrative`.
## Guia de voz, glossário e limites de caixa: docs/ESTILO_TEXTO.md.
## Mapa das 68 telas, cenas e ganchos da Onda 2: docs/ROTEIRO.md.
## Direção emocional (Onda 1): a Voz precisa ser AMADA para o roubo doer — ela
## planta afeto (santuários, piadas, a "janela para o rio") e o roubo COLHE cada
## plantio. As lembranças quentes são falsas (dadas pela Voz); as frias, que
## vazam dos Anéis e voltam no Centro, são verdadeiras.
## REGRA DE OURO: nada aqui entrega a virada (a Voz = Yaldabaoth; os Anéis = a
## Sophia) antes do roubo na tela 64.
##
## Cada fala é {speaker, text}. Algumas falas das cenas encenadas trazem também
## `cue` (ex.: "rings_fly", "mask_falls", "wait_2s") — a DialogueBox ignora; é a
## marcação para a encenação (Onda 2) disparar o efeito na fala certa.

const VOZ := "A Voz"
const REI := "O Rei"
const YAL := "Yaldabaoth"
## O Cego PEQUENO (cena D): quem sobra dentro do Colosso. Falante próprio — o
## retrato do Rei de máscara (YAL) contradizia a criança na tela (QA2 #6).
const CEGO := "O Cego"
const SOPHIA := "Sophia"
const NARRADOR := ""          # rubrica sem falante (a caixa mostra só o texto)

# Moods do retrato (campo `mood`, ver _m). Constantes: o AudioQA lê os cues das
# falas `_c(...)` por regex e confundiria um mood literal no fim da linha com um cue.
const M_ARREPENDIDO := "arrependido"
const M_CHOQUE := "choque"
const M_DETERMINADA := "determinada"
const M_IRONICO := "ironico"
const M_MEDO := "medo"
const M_OLHANDO := "olhando"     # o Cego pequeno olha para ela (retrato cego_pequeno_olhando)
const M_QUEBRADO := "quebrado"
const M_REGIO := "regio"
const M_REVELADO := "revelado"
const M_SERENA := "serena"
const M_TERNURA := "ternura"
const M_TRISTE := "triste"

const ORDINAIS := ["primeiro", "segundo", "terceiro", "quarto", "quinto", "sexto", "sétimo"]

var refusals: int = 0        # tentações recusadas
var concessions: int = 0     # tentações aceitas (suborno de faíscas)
var ending: String = ""      # "ascensao" / "ruptura" / "semente"
var final_deaths: int = 0    # quedas dentro da Mente (tela 68) — as falas mudam


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
	final_deaths = 0
	rei_exposed = false
	rei_duel_detach()


func _l(speaker: String, text: String) -> Dictionary:
	return {"speaker": speaker, "text": text}


## Fala com marcação de encenação (`cue`) para a cena da Onda 2.
func _c(speaker: String, text: String, cue: String) -> Dictionary:
	return {"speaker": speaker, "text": text, "cue": cue}


## RETRATO POR EMOÇÃO (Onda 3): marca a fala com `mood`, que a DialogueBox (ui3)
## usa para escolher o retrato. Sem `mood`, vale o neutro do falante. Valores
## (docs/pedidos/encenacao3.md): Sophia neutra/determinada/triste/raiva/medo/
## ternura/choque/serena · Rei e Yaldabaoth regio/ironico/revelado/quebrado ·
## Soter sereno/triste · Velkar elmo/arrependido. A Voz NUNCA leva mood (retrato
## nenhum: a regra de ouro — nada liga a Voz ao Rei antes do roubo).
func _m(line: Dictionary, mood: String) -> Dictionary:
	line["mood"] = mood
	return line


## LEGENDA URGENTE (Onda 6): a CaptionBar segura toda legenda enquanto há
## combate por perto e só solta na calma. As falas DA PRÓPRIA LUTA (fase de
## chefe, 7º Anel) levam `urgent` e passam — por isso são curtas (1 linha).
func _u(line: Dictionary) -> Dictionary:
	line["urgent"] = true
	return line


## "Uma faísca escorre" / "37 faíscas escorrem" — a fala nunca diz "0 faíscas".
## Começa frase (vem depois de um ponto): maiúscula.
func _faiscas(n: int) -> String:
	return "Uma faísca escorre" if n == 1 else "%d faíscas escorrem" % n


# --- A MORTE NÃO PEGA (checkpoint) -------------------------------------------
## Antes do roubo é a VOZ que te recompõe, e o tom muda com o número de quedas:
## ternura em pânico (1–2) → cuidado que vira posse (3–6) → a máscara range
## (7–12) → o ciclo (13+). No Centro, sem a Voz, são os cacos dela mesma (pelo
## número de cacos recuperados). Na Mente, os Anéis a refazem CONTRA o dono das
## mãos (contador próprio). `lost` = faíscas que escorreram na queda.
## Chamada UMA vez por queda (level._on_player_died): conta as quedas da Mente.
func death_revive(screen: int, deaths: int, lost: int) -> Array:
	if RunManager.is_final(screen):
		final_deaths += 1
		match final_deaths:
			1: return [
				_l(YAL, "MORRE. Por que tu não morres?"),
				_l(SOPHIA, "(Os Anéis param de girar... descem... e me costuram de volta, caco por caco.)"),
				_l(SOPHIA, "Eles lembram de mim. Mesmo nas mãos dele."),
			]
			2: return [
				_l(YAL, "Eu os forjei! Eles são MEUS!"),
				_l(SOPHIA, "Tu os forjaste. Mas foi de mim que os tiraste."),
			]
			3: return [
				_l(YAL, "(na voz antiga, gentil) Fica no chão, Portadora. Eu cuido de tudo. Como sempre."),
				_l(SOPHIA, "Não. Já não é a tua voz que me levanta."),
			]
		return [
			_l(YAL, "...Por que eles te escolhem?"),
			_l(SOPHIA, "Porque eu nunca os prendi."),
		]
	if screen > RunManager.LAST_ARCHON_SCREEN:
		var cacos: int = Progression.restored_rings.size()
		if cacos == 0:
			return [
				_l(SOPHIA, "(Escuro. Nenhuma voz. Só os cacos, quentes, me juntando do chão.)"),
				_l(SOPHIA, "Ninguém me levanta. ...Então eu levanto."),
			]
		if cacos <= 2:
			return [
				_l(SOPHIA, "(Os cacos que já voltaram me costuram. Têm a minha letra.)"),
				_l(SOPHIA, "Já fui despedaçada antes. Não foi assim que acabou."),
			]
		if cacos <= 4:
			return [
				_l(SOPHIA, "Ina cantava errado. Merou carregava água. Tasso via os astros."),
				_l(SOPHIA, "Eu levanto por eles."),
			]
		return [
			_l(SOPHIA, "(Quase inteira. Os cacos não me erguem por obrigação.)"),
			_l(SOPHIA, "Me erguem por saudade."),
		]
	var lines: Array = []
	# 1ª queda diante do Rei (tela 1): a Voz consola e aponta a mentira dele
	# (camada escondida: a Voz É o Rei, e a queda dele é o plano dela).
	if RunManager.is_king_screen(screen) and once("morte_rei"):
		lines = [
			_l(VOZ, "Shh. Já passou. Ele bate forte pra quem fala tão bonito."),
			_l(VOZ, "Levanta. E repara no tal rei que jamais se curva."),
		]
	# 1ª queda diante de um Arconte: a posse aparece sem disfarce.
	elif RunManager.is_archon_screen(screen) and once("morte_arconte_%d" % screen):
		lines = [
			_l(VOZ, "Ele não fica contigo. Ninguém fica contigo. Só eu."),
			_l(VOZ, "Sobe. Os tronos não se vencem deitada."),
		]
	else:
		var d: int = maxi(1, deaths)
		var tier: Array
		if d <= 2:
			tier = [
				[_l(VOZ, "Não. Não, não, não. LEVANTA."),
				 _l(VOZ, "Agarra a minha voz e sobe por ela. Não te perco numa vala do Kenoma.")],
				[_l(VOZ, "Shh. Já passou. Tenho-te."),
				 _l(VOZ, "Respira. Ou o que quer que tu faças no lugar disso.")],
			]
		elif d <= 6:
			tier = [
				[_l(VOZ, "De novo. Fica quieta. Eu seguro a tua faísca: ela não escapa de mim.")],
				[_l(VOZ, "Cada volta custa caro. Paga com faíscas, não contigo. Tu vales cada uma delas.")],
				[_l(VOZ, "O corpo lembra da queda? Que lembre também de quem o ergueu. Todas as vezes.")],
			]
		elif d <= 12:
			tier = [
				[_l(VOZ, "Levanta. Eu preciso de ti inteira."),
				 _l(VOZ, "...De ti. Eu preciso de ti. Foi o que eu quis dizer.")],
				[_l(VOZ, "Não morras antes da hora. ...Antes de acabarmos. Antes de acabarmos juntos.")],
				[_l(VOZ, "Quantas vezes forem precisas, faísca perdida. Não sei desistir de ti. Não agora.")],
			]
		else:
			tier = [
				[_l(VOZ, "Tu cais, e eu refaço-te. Já fizemos isto antes, tu e eu. Muito antes.")],
				[_l(VOZ, "Eu refaria o mundo inteiro para te pôr de pé."),
				 _l(VOZ, "...Não me olhes assim. É modo de dizer.")],
			]
		lines = tier[(d - 1) % tier.size()].duplicate()
	if lost > 0:
		lines.append(_l(NARRADOR, "(A luz te costura de volta. A tela recomeça, e as faíscas dela também. %s da tua mão aberta.)" % _faiscas(lost)))
	return lines


# --- ATO 1: O LIMIAR (tela 1) ----------------------------------------------------

## REESCRITA DO LIMIAR (29/10, texto fechado em C:\gnosis-wt\_caps\narrativa\AMOSTRA_LIMIAR.md
## v3): PT-BR com "você"; Sophia seca e irônica; a Voz calorosa ("a gente"); o
## Rei arrogante com "nós" majestático e sem contração. O texto é EXATAMENTE o
## da amostra: a voz gravada é achada por sha1(falante|texto)[:12].

## Abertura do run (tela 1), logo depois do prólogo em cards. Só o escuro e o
## "Acorda." na caixa — logo depois, o controle (backlog #6). O resto vira
## LEGENDA de caminhada: `walk_arrival` da tela 1 e `limiar_stela*` (Gnosis).
func intro() -> Array:
	return [
		_c(NARRADOR, "(Escuro. Um coração batendo. Depois, gosto de cinza.)", "heartbeat"),
		_l(VOZ, "Ei. Ei! Acorda. ...Isso, devagar. Eu tô aqui."),
	]


## Perto da Estela da tela 1 (Gnosis): a Voz ensina a ler a pedra e planta a
## desconfiança. Depois de ler, a Sophia comenta a Mônada (só se leu).
func limiar_stela() -> Array:
	return [_l(VOZ, "Uma pedra escrita. Leia, se quiser. Só não acredite em tudo.")]


func limiar_stela_read() -> Array:
	return [_l(SOPHIA, "\"Antes de tudo, havia o Um.\" Um o quê? Um alguém?")]


## Cena A (tela 1): a névoa engrossa (a piada da Voz que o roubo vai colher),
## o Rei sai dela e diz a MENTIRA ("um rei jamais se curva"). A caminhada da
## tela 1 tem só ~660 px (≈ 3,6 s): o trio da névoa abre a caixa para não ser
## cortado. Marco: 10 falas (≤ 12, regra 3 do Guardião).
func king_intro() -> Array:
	return [
		_c(VOZ, "A névoa está engrossando. Fica perto de mim.", "fog_thickens"),
		_l(SOPHIA, "Você é uma voz. Perto como?"),
		_l(VOZ, "...Perto da minha voz, então."),
		_l(VOZ, "Vem alguém. Calma, esse eu conheço. Muita pose, joelho fraco."),
		_m(_c(REI, "Ah. Acordou. Nós estávamos esperando.", "king_emerges"), M_REGIO),
		_l(SOPHIA, "Nós quem? Só tem você aí."),
		_m(_l(REI, "Rei fala no plural. Somos importantes demais para o singular."), M_IRONICO),
		_m(_c(REI, "Lei do Limiar: só passa quem nos tocar com a própria luz.", "mask_lights"), M_REGIO),
		_l(SOPHIA, "Tocar. Com o cajado serve?"),
		_m(_l(REI, "Tente. E não tema: um rei jamais se curva."), M_IRONICO),
	]


## O Rei "cai" (tela 1): a mentira cai com ele, a máscara racha, o selo se
## parte e os sete Arcontes acordam. Duas versões das 2 primeiras falas: com a
## mentira já exposta no duelo (`rei_exposed`) ou caindo agora, de joelhos.
## Fecha num gancho ("lembrávamos").
func king_fall(exposed: int = -1) -> Array:
	var lines: Array = []
	# exposed: -1 = o que aconteceu no duelo (rei_exposed) · 0 não · 1 sim (sondas).
	var ex: bool = rei_exposed if exposed < 0 else exposed == 1
	if ex:
		lines.append(_m(_l(REI, "Aquela reverência de antes? Foi proposital."), M_IRONICO))
		lines.append(_l(SOPHIA, "Claro. Superproposital."))
	else:
		lines.append(_m(_l(REI, "Nós não estamos ajoelhados. Estamos... descansando."), M_IRONICO))
		lines.append(_l(SOPHIA, "De joelhos. Na minha frente. Jamais, né?"))
	lines.append_array([
		_m(_c(REI, "(a máscara racha) Sua luz... é maior do que nós lembrávamos.", "mask_cracks"), M_QUEBRADO),
		_l(SOPHIA, "Lembravam? Eu acordei agora há pouco."),
		_m(_c(REI, "Pergunte aos sete. Eles lembram por nós.", "king_sinks"), M_IRONICO),
		_l(VOZ, "Sentiu? O selo dele rachou. Sete tronos acabaram de acordar."),
		_l(SOPHIA, "Isso é bom ou é muito ruim?"),
		_l(VOZ, "Sete Arcontes, um por andar. Cada um guarda um Anel."),
		_l(SOPHIA, "E se eu juntar os sete?"),
		_l(VOZ, "A gente quebra esta prisão. Você e eu."),
		_l(SOPHIA, "(Lembravam. Quem lembra de alguém que acabou de acordar?)"),
	])
	return lines


# --- DUELO DO REI (tela 1): falas de combate C1–C6 ----------------------------
## A arrogância do Rei vira o manual da própria luta (AMOSTRA_LIMIAR §1.4).
## ORÇAMENTO FECHADO: ≤ 6 legendas por luta, ≥ 12 s entre o início de uma e da
## seguinte; cada dica 1 vez por run (`seen`). Nunca por cima do telégrafo: a
## fala sai ≥ 1 s antes da preparação (sinal `move_will_start(id, lead)` do
## Chefes6, se existir) ou na RECUPERAÇÃO do golpe (padrão, sem atrasar nada).
## Liga: `rei_duel_attach(rei)` (Gnosis.boss_card("rei")). API para o Chefes6 e
## as sondas: `rei_duel(evento, dados)` com "parried" · "recovered" {id} ·
## "will_start" {id, lead} · "knelt" · "lie_exposed" · "phase" {n}.
## C1 só se ela ainda não aparou nada · C2 Raio · C3 Mão · C4 fase 2 · C5 fase 3
## · C6a dica-pergunta (degrau 2: 2º ajoelhar ou ≥ 45 s; desligável por
## GameManager.hints_enabled, se existir) · C6b a acusação (muda se a C6a já
## tocou ou se não houver vaga — o carimbo/HUD do Chefes6 basta).
const REI_BUDGET := 6
const REI_GAP := 12.0
const REI_HINT_AFTER := 45.0
const REI_LEAD_MIN := 1.0
var rei_exposed: bool = false   # a mentira do Rei caiu NESTA luta (king_fall usa)
var _rei: Node = null
var _rei_brain: Node = null
var _rei_clock: float = 0.0     # tempo de jogo da luta (para com a pausa)
var _rei_said: int = 0
var _rei_last: float = -999.0
var _rei_parried: bool = false
var _rei_kneels: int = 0
var _rei_lead_api: bool = false
var _rei_prev_state: int = -1
var _rei_prev_low: bool = false
var _rei_eye: Node = null


func _rei_line(id: String) -> Dictionary:
	match id:
		"C1": return _u(_l(SOPHIA, "Amarelo... da próxima, eu aparo."))
		"C2": return _u(_l(REI, "Nossa luz rasteja. Pule."))
		"C3": return _u(_l(REI, "Esta mão, nem você apara."))
		"C4": return _u(_l(REI, "Chega de cortesia. Olhe o chão."))
		"C5": return _u(_l(REI, "Sempre atrás de você."))
		"C6a": return _u(_l(SOPHIA, "Ele se curvou? Jamais, né?"))
		"C6b": return _u(_l(SOPHIA, "Jamais, né?"))
	return {}


## Liga o duelo a este Rei (zera a luta; as dicas já ditas no run não voltam).
func rei_duel_attach(rei: Node) -> void:
	rei_duel_detach()
	if rei == null or not is_instance_valid(rei):
		return
	_rei = rei
	rei_exposed = false
	_rei_clock = 0.0
	_rei_said = 0
	_rei_last = -999.0
	_rei_parried = false
	_rei_kneels = 0
	_rei_prev_state = -1
	_rei_prev_low = false
	_rei_brain = rei.get("brain")
	_rei_lead_api = false
	if _rei_brain != null:
		if _rei_brain.has_signal("lie_exposed"):
			_rei_brain.connect("lie_exposed", _on_rei_lie)
		else:
			# PROVISÓRIO até o Chefes6 expor `lie_exposed`: o 1º golpe no olho
			# enquanto ele está ajoelhado (o olho só recebe golpe embaixo).
			_rei_eye = _rei_brain.get("_eye_box")
			if _rei_eye != null and _rei_eye.has_signal("hit_received"):
				_rei_eye.connect("hit_received", _on_rei_eye_hit)
		if _rei_brain.has_signal("move_will_start"):
			_rei_brain.connect("move_will_start", _on_rei_will_start)
			_rei_lead_api = true
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_signal("riposte_window_opened"):
		pl.connect("riposte_window_opened", _on_rei_parried)


func rei_duel_detach() -> void:
	if _rei_brain != null and is_instance_valid(_rei_brain):
		if _rei_brain.has_signal("lie_exposed") and _rei_brain.is_connected("lie_exposed", _on_rei_lie):
			_rei_brain.disconnect("lie_exposed", _on_rei_lie)
		if _rei_brain.has_signal("move_will_start") and _rei_brain.is_connected("move_will_start", _on_rei_will_start):
			_rei_brain.disconnect("move_will_start", _on_rei_will_start)
	if _rei_eye != null and is_instance_valid(_rei_eye) and _rei_eye.is_connected("hit_received", _on_rei_eye_hit):
		_rei_eye.disconnect("hit_received", _on_rei_eye_hit)
	if is_inside_tree():
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null and pl.has_signal("riposte_window_opened") and pl.is_connected("riposte_window_opened", _on_rei_parried):
			pl.disconnect("riposte_window_opened", _on_rei_parried)
	_rei = null
	_rei_brain = null
	_rei_eye = null


## A luta do Rei está ligada? (sondas)
func rei_duel_active() -> bool:
	return _rei != null and is_instance_valid(_rei)


## Quantas falas de combate a luta já gastou (sondas).
func rei_duel_spent() -> int:
	return _rei_said


func _on_rei_lie(_id: String = "rei") -> void:
	rei_duel("lie_exposed")


func _on_rei_eye_hit(_dmg: int, _src: Vector2, _kb: float, _unb: bool, _attacker: Node) -> void:
	if _rei_brain != null and is_instance_valid(_rei_brain) and bool(_rei_brain.get("_low")):
		rei_duel("lie_exposed")


func _on_rei_will_start(id: String, lead: float) -> void:
	rei_duel("will_start", {"id": id, "lead": lead})


func _on_rei_parried() -> void:
	rei_duel("parried")


func _process(delta: float) -> void:
	if _rei == null:
		return
	if not is_instance_valid(_rei) or not _rei.is_inside_tree():
		rei_duel_detach()
		return
	_rei_clock += delta
	# Lê o estado do Rei: recuperação de um golpe e o AJOELHAR (golpe com
	# `expose` na recuperação — o mesmo critério do olho que desce).
	var st: int = int(_rei.get("estate"))
	if st == Enemy.EState.DEAD:
		return
	var mv = _rei_brain.get("mv") if _rei_brain != null and is_instance_valid(_rei_brain) else {}
	if not (mv is Dictionary):
		mv = {}
	if st != _rei_prev_state:
		if st == Enemy.EState.RECOVER and _rei_prev_state != -1:
			rei_duel("recovered", {"id": String(mv.get("id", ""))})
		_rei_prev_state = st
	var low: bool = st == Enemy.EState.RECOVER and bool(mv.get("expose", false))
	if low and not _rei_prev_low:
		rei_duel("knelt")
	_rei_prev_low = low


## Evento do duelo (do próprio polling, dos sinais ou de uma sonda).
func rei_duel(ev: String, data: Dictionary = {}) -> void:
	if not rei_duel_active():
		return
	match ev:
		"parried":
			_rei_parried = true
		"recovered":
			var id := String(data.get("id", ""))
			if id == "leque" and not _rei_parried:
				_rei_try("C1")
			elif not _rei_lead_api and id in ["raio", "raio_b"]:
				_rei_try("C2")
			elif not _rei_lead_api and id in ["mao", "mao2"]:
				_rei_try("C3")
		"will_start":
			var id := String(data.get("id", ""))
			if float(data.get("lead", 0.0)) < REI_LEAD_MIN:
				return
			if id in ["raio", "raio_b"]:
				_rei_try("C2")
			elif id in ["mao", "mao2"]:
				_rei_try("C3")
		"knelt":
			_rei_kneels += 1
			if not rei_exposed and _hints_on() and (_rei_kneels >= 2 or _rei_clock >= REI_HINT_AFTER):
				_rei_try("C6a")
		"lie_exposed":
			if rei_exposed:
				return
			rei_exposed = true
			if not seen.has("rei_C6a"):
				_rei_try("C6b")
		"phase":
			var n := int(data.get("n", 0))
			if n == 2:
				_rei_try("C4", true)
			elif n == 3:
				_rei_try("C5", true)


## Tenta dizer a fala `id` (1 vez por run). Fala comum respeita o intervalo
## (se não cabe, fica para a próxima ocasião); fala de FASE (`fixed`) espera o
## intervalo em tempo de jogo. Nenhuma passa do orçamento.
func _rei_try(id: String, fixed: bool = false) -> bool:
	var key := "rei_" + id
	if seen.has(key) or _rei_said >= REI_BUDGET:
		return false
	var wait := REI_GAP - (_rei_clock - _rei_last)
	if wait > 0.0 and not fixed:
		return false
	seen[key] = true
	_rei_said += 1
	_rei_last = _rei_clock + maxf(wait, 0.0)
	if wait > 0.0:
		get_tree().create_timer(wait, false).timeout.connect(_rei_emit.bind(id))
	else:
		_rei_emit(id)
	return true


func _rei_emit(id: String) -> void:
	if not rei_duel_active():
		return
	Gnosis.captions([_rei_line(id)])


## Degrau 2 das dicas (opt-in): desligável por uma opção "Dicas" (UI), se existir.
func _hints_on() -> bool:
	var v = GameManager.get("hints_enabled")
	return true if v == null else bool(v)


# --- ATO 2: OS SETE ÉONS -------------------------------------------------------

## Introdução de cada Éon (primeira tela do ato, caixa de diálogo). A Voz dá o
## lugar; a Sophia fecha com a fala-marco do degrau dela (o que sente ao chegar).
func eon_intro(eon: int) -> Array:
	match eon:
		# Torpor: LEGENDA (não caixa), depois de ≥ 10 s de jogo na tela 2 (Level) —
		# a queda do Rei já pausou o mundo logo antes (regra 3 do Guardião).
		0: return [
			_l(VOZ, "O Torpor. Aqui os mortos ainda não sabem que morreram."),
			_l(VOZ, "Não odeie quem dorme. Até agora há pouco, você dormia."),
			_l(SOPHIA, "Confesso: deitar parece ótimo. ...Não vou."),
			_l(SOPHIA, "(Dormir é esquecer de onde veio. Acordar dói porque é lembrar.)"),
		]
		1: return [
			_l(VOZ, "O Éon da Fome. Estes mercados devoram quem compra. Tudo aqui tem preço, até a saudade."),
			_l(VOZ, "O Arconte daqui vai oferecer-te o que perdeste. Lembra: cópia não é volta."),
			_l(SOPHIA, "Eu nem sei o que perdi. Como vou recusar o que ele me oferecer?"),
			_l(SOPHIA, "(Kenoma: um mundo cheio de coisas e vazio de sentido. Nada aqui mata a fome de verdade.)"),
		]
		2: return [
			_l(VOZ, "O Éon da Corrente. A lei deste lugar não protege: prende. Cada selo é um cadeado."),
			_l(SOPHIA, "Eu sigo uma voz que não vejo. Isso também é corrente?"),
			_l(VOZ, "É confiança. É diferente. Quebra os selos, e sobe."),
			_l(SOPHIA, "(Os Arcontes mandam pelo destino: selos, leis, correntes. Quem sabe que está presa já começou a sair.)"),
		]
		3: return [
			_l(VOZ, "O Éon do Silêncio. Uma biblioteca de livros em branco: aqui calaram a verdade página por página."),
			_l(VOZ, "Escuta o que não é dito. É assim que se lê este lugar."),
			_l(SOPHIA, "Tem uma voz por baixo da tua. Aqui, no silêncio, eu vou ouvi-la."),
			_l(SOPHIA, "(Antes de tudo havia o Silêncio. A verdade não grita: espera ser ouvida.)"),
		]
		4: return [
			_l(VOZ, "O Éon do Espelho. Cuidado, Portadora: aqui o inimigo és tu."),
			_l(VOZ, "O reflexo luta com a tua força e com a tua fúria. Vence quem se conhece."),
			_l(SOPHIA, "Eu quero ver o meu rosto. Mesmo que ele me ataque."),
			_l(SOPHIA, "(Conhecer-se é lembrar de onde veio a luz. O reflexo copia; não sabe quem é.)"),
		]
		5: return [
			_l(VOZ, "O Éon da Praga. As faíscas aqui se apagam devagar, como velas num pântano."),
			_l(VOZ, "O desespero é a última arma deles. Não é a tua."),
			_l(SOPHIA, "Estou cansada. Pela primeira vez eu digo em voz alta: cansada."),
			_l(SOPHIA, "(O corpo cansa e apodrece. A faísca, não: ela só pode ser esquecida.)"),
		]
		6: return [
			_l(VOZ, "O Éon da Coroa. O último degrau. O Arconte daqui quase tocou o trono do Cego."),
			_l(VOZ, "Ele vai oferecer-te poder: a mais velha das mentiras, e a mais doce."),
			_l(SOPHIA, "Último degrau. Depois eu descubro quem sou. Tu prometeste."),
			_l(SOPHIA, "(Todo poder que exige joelhos tem medo. A Luz de verdade não pede adoração.)"),
		]
	return []


## Tentação do Arconte (antes da luta). Cada Arconte é um filho do Cego com um
## pedaço da solidão do pai; a tentação é o jeito que achou de não senti-la.
## A Voz fecha sempre com "Escolhe." (botões Recusar / Ceder).
func temptation(boss_id: String) -> Array:
	match boss_id:
		"arconte_sono": return [
			_l("Athoth", "Portadora... tu também não dormes, não é? Conheço esse cansaço. Deita. Eu sonho o resto por ti."),
			_l(VOZ, "Se dormires agora, nunca mais acordas. Escolhe."),
		]
		"arconte_fome": return [
			_l("Harmas", "A tua casa. A janela para o rio. Os barcos que contavas. Guardei tudo, quentinho. Fica."),
			_m(_l(SOPHIA, "(Como ele sabe da janela?)"), M_MEDO),
			_l(VOZ, "Arcontes roubam lembranças. Essa é nossa. Não deixes. Escolhe."),
		]
		"arconte_corrente": return [
			_l("Galila", "Consta que estás fora do teu lugar. Sem lei, tudo cai: eu caí uma vez. Ajoelha-te, e ninguém te solta."),
			_l(VOZ, "Corrente polida ainda é corrente. Escolhe."),
		]
		"arconte_silencio": return [
			_l("Yabel", "(não fala; aponta a própria boca costurada, depois a tua, e oferece o descanso de nunca mais responder)"),
			_l(VOZ, "O silêncio dele é um túmulo confortável. Escolhe."),
		]
		"arconte_espelho": return [
			_l("Astaphaios", "Olha: somos nós, antes das cinzas, à janela, contando barcos. Fica deste lado do vidro. Eu fico com o resto."),
			_l(VOZ, "É o golpe mais cruel de todos. Eu sei. Escolhe."),
		]
		"arconte_praga": return [
			_l("Belias", "Tudo apodrece, Portadora. Vi morrer tudo o que plantei. Rende-te agora, e eu poupo-te do fim."),
			_l(VOZ, "Ele confunde cansaço com verdade. Escolhe."),
		]
		"arconte_coroa": return [
			_l("Armupiel", "O Cego nunca olhou para mim. Talvez olhe para ti. Toma a minha coroa. Sê o que eu quase fui."),
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


## Card do Campeão de cada Éon (#20): o nome do bot temático do Éon (o mesmo das
## legendas: "O Glutão que guarda o santuário...") e o santuário que ele guarda.
## Nome ≤ 18 caracteres e título ≤ 52 (ESTILO §5) — exceto o Portador de
## Esporos (21; cabe no letterbox de 600 px, conferido na captura). Sem a
## palavra "Campeão" no card: ela já é o nome de uma dificuldade.
const CHAMPION_CARDS := [
	{"name": "O SONÂMBULO", "title": "Guardião do santuário do Torpor"},
	{"name": "O GLUTÃO", "title": "Guardião do santuário da Fome"},
	{"name": "O CARCEREIRO", "title": "Guardião do santuário da Corrente"},
	{"name": "O BIBLIOTECÁRIO", "title": "Guardião do santuário do Silêncio"},
	{"name": "O REFLEXO", "title": "Guardião do santuário do Espelho"},
	{"name": "O PORTADOR DE ESPOROS", "title": "Guardião do santuário da Praga"},
	{"name": "O PRETORIANO", "title": "Guardião do santuário da Coroa"},
]


func champion_card(eon: int) -> Dictionary:
	if eon < 0 or eon >= CHAMPION_CARDS.size():
		return {}
	return CHAMPION_CARDS[eon]


## Fase 2 de um Arconte (a 50% da vida): legendas SEM pausar — a luta continua.
## Gancho (Onda 2): enemy._enter_phase2 → Gnosis.captions(Narrative.archon_phase2(type_id)).
func archon_phase2(boss_id: String) -> Array:
	match boss_id:
		"rei":
			# Duelo do Rei: a fala entra pelo orçamento do duelo (C4), não aqui.
			rei_duel("phase", {"n": 2})
			return []
		"arconte_sono": return [_u(_l("Athoth", "Por que acordar? Lá fora só tem a falta!"))]
		"arconte_fome": return [_u(_l("Harmas", "Dá-me uma! Uma lembrança que seja minha!"))]
		"arconte_corrente": return [_u(_l("Galila", "Se eu soltar, eu caio! Todos caem!"))]
		"arconte_silencio": return [_u(_l("Yabel", "(os pontos da boca dele esticam; alguma coisa quer sair)"))]
		"arconte_espelho": return [
			_u(_l(SOPHIA, "(O vidro racha: uma nuvem branca. Alguém pequeno chorando.)")),
			_u(_l("Astaphaios", "Esse não! Esse reflexo não é para ti!")),
		]
		"arconte_praga": return [_u(_l("Belias", "Por que insistes? Eu só quero que pare de doer!"))]
		"arconte_coroa": return [_u(_l("Armupiel", "Corte! Ao rei! ...Ninguém vem. Nunca ninguém vem."))]
	return []


## FASE 3 dos Arconte (Onda 6, pedido do chefes6: `enemy._enter_phase(3)` chama
## se existir). Uma linha, tom de filho ferido, urgente (é da luta).
func archon_phase3(boss_id: String) -> Array:
	match boss_id:
		"rei":
			rei_duel("phase", {"n": 3})
			return []
		"arconte_sono": return [_u(_l("Athoth", "Só mais um pouco... deixa eu dormir só mais um pouco."))]
		"arconte_fome": return [_u(_l("Harmas", "Ainda tenho fome. Sempre."))]
		"arconte_corrente": return [_u(_l("Galila", "Se eu soltar... quem me segura?"))]
		"arconte_silencio": return [_u(_l("Yabel", "(um fio arrebenta; um som, quase uma palavra)"))]
		"arconte_espelho": return [_u(_l("Astaphaios", "Qual de nós é o reflexo?"))]
		"arconte_praga": return [_u(_l("Belias", "Está bem. Está bem. Só mais uma vez, então."))]
		"arconte_coroa": return [_u(_l("Armupiel", "De pé, corte! ...De pé..."))]
	return []


## A queda de cada Arconte: a última fala dele (tragédia, não vilania).
func _archon_death(who: String) -> Dictionary:
	match who:
		"sono": return _l("Athoth", "Ah... então é isto, estar acordado. Dói. ...É bonito.")
		"fome": return _l("Harmas", "Nunca provei nada que fosse meu. Guarda as tuas lembranças. Guarda bem.")
		"corrente": return _l("Galila", "Leve... é assim, sem elo? Ninguém me disse... que era leve.")
		"silencio": return _l("Yabel", "(os pontos se rompem) Alguém respondeu a ele, uma vez, lá de cima. Eu ouvi. Ele costurou-me por isso.")
		"espelho": return _l("Astaphaios", "Fica com o teu rosto. Eu nunca tive um. ...Era bonito, o teu.")
		"praga": return _l("Belias", "(na poça dele, uma coisa verde, minúscula) ...Brotou? Não olhes para mim. Olha aquilo.")
		"coroa": return _l("Armupiel", "Diz a ele que eu... não. Ele não escuta. Nunca escutou.")
	return {}


## O Arconte cai e o Anel se condensa (caixa de diálogo): a última fala dele,
## a micro-pausa da Voz (um pai ouvindo um filho morrer, sem que se saiba) e a
## magia nova. Depois de Armupiel, só "Sete." — o roubo vem em seguida.
func ring_gained(boss_id: String, skill_name: String, count: int) -> Array:
	var who := boss_id.trim_prefix("arconte_")
	var lines := []
	var last := _archon_death(who)
	if not last.is_empty():
		lines.append(last)
	if who == "coroa":
		lines.append(_l(VOZ, "Sete."))
		return lines
	var ord: String = ORDINAIS[clampi(count - 1, 0, ORDINAIS.size() - 1)]
	lines.append(_l(VOZ, "(...) O %s Anel. A paixão dele agora te obedece: %s." % [ord, skill_name]))
	match who:
		"sono":
			lines.append(_l(SOPHIA, "(Ao tocar o Anel: uma nuvem branca, e um trono pequeno dentro dela.)"))
			lines.append(_l(VOZ, "Sonhos do Torpor. Passam. Experimenta-o: o Éter que juntas vira a magia dele."))
		"fome": lines.append(_l(VOZ, "Faltam cinco. E a tua janela continua tua. Sobe."))
		"corrente": lines.append(_l(VOZ, "Galila classificou-te e perdeu. Faltam quatro."))
		"silencio": lines.append(_l(VOZ, "Ouve: as tuas magias voltaram a falar. Faltam três."))
		"espelho":
			lines.append(_l(VOZ, "Este Anel pesa, não pesa? ...Eu também não sei bem o que sou."))
			lines.append(_l(VOZ, "Só sei que não quero ficar só de novo."))
		"praga": lines.append(_l(VOZ, "Só falta a Coroa. Agora, Portadora, não pares por nada."))
		_: lines.append(_l(VOZ, "Sobe."))
	return lines


## SANTUÁRIOS (tela do Desafio de cada Éon: 6, 15, 24, 33, 42, 51, 60): o
## "fogo de acampamento" da dupla, antes de abrir a loja. É aqui que a Voz
## planta o afeto que o roubo vai colher (a janela, o riso, "ficar contigo").
## Gancho (Onda 2): level._on_screen_cleared, ramo "trial", antes da loja.
func sanctuary(eon: int) -> Array:
	match eon:
		0: return [
			_l(VOZ, "Tu tinhas uma casa com uma janela para o rio. Contavas os barcos."),
			_l(SOPHIA, "...Não lembro."),
			_l(VOZ, "Eu lembro por ti. Por enquanto."),
		]
		1: return [
			_l(SOPHIA, "Fala comigo até passar?"),
			_l(VOZ, "Falo. Tenho todo o tempo do mundo. ...Literalmente."),
		]
		2: return [
			_l(SOPHIA, "Como tu és? De verdade."),
			_l(VOZ, "Nada bonito de se ver. Acredita: é melhor assim."),
			_l(SOPHIA, "(E, pela primeira vez desde as cinzas, eu rio.)"),
			_l(VOZ, "...Faz isso mais vezes. Combina contigo."),
		]
		3: return [
			_l(VOZ, "Aqui me calo. Fala tu, hoje. Eu escuto."),
			_l(SOPHIA, "Sonhei de novo com a nuvem branca. Tinha um trono pequeno no meio."),
			_c(VOZ, "(um silêncio longo demais) ...Sonhos. Descansa. Eu vigio.", "wait_2s"),
		]
		4: return [
			_l(SOPHIA, "Como eu era? Antes."),
			_l(VOZ, "Teimosa. Contavas os barcos errado de propósito, só para eu te corrigir."),
		]
		5: return [
			_l(SOPHIA, "Eu não aguento mais."),
			_l(VOZ, "Então encosta em mim. Não tenho ombro. Mas tenho paciência de eras."),
		]
		6: return [
			_l(VOZ, "Quando acabar... o que vais fazer?"),
			_l(SOPHIA, "Não sei. Ficar contigo? Se deixares."),
			_c(VOZ, "...Sim. Comigo. Sempre.", "music_stop"),
		]
	return []


## Encontros com Soter, o Ungido (telas 17, 35 e 53). Ele não luta — abençoa,
## e carrega os NOMES do povo das cinzas (Ina, Merou, Tasso): as pessoas eram
## reais, e a verdade é mais humilde que a mentira (um poço, não um rio).
## O Cego não o vê: durante o encontro a Voz não diz nada.
func soter_meeting(n: int) -> Array:
	match n:
		0: return [
			_l("Soter", "Paz, Portadora. Baixa o cajado: o Cego não me vê, e contigo não brigo."),
			_l(SOPHIA, "Quem és tu?"),
			_l("Soter", "Alguém que desce sem precisar. Conheci a gente das cinzas onde acordaste."),
			_l("Soter", "Carrego os nomes deles. Quando quiseres ouvir, pergunta. Hoje, deixa-me ungir o que já é teu. Escolhe."),
		]
		1: return [
			_l("Soter", "De novo tu. Mais fundo, mais forte, mais cansada. Senta-te. O mundo espera."),
			_c(NARRADOR, "(Tu te sentas. Por um instante, nada te persegue.)", "wait_2s"),
			_l(SOPHIA, "Os nomes. Me diz um."),
			_c("Soter", "Ina. Padeira. Cantava errado de propósito, para a filha rir. A filha ria sempre.", "chime"),
			_l("Soter", "Sabes por que não luto? Toda lâmina, até a justa, ensina a mão a fechar. A tua ainda abre. Escolhe."),
		]
		2: return [
			_m(_l("Soter", "É a última vez que nos vemos deste lado, Portadora. Lá em cima, nem eu alcanço."), M_TRISTE),
			_l("Soter", "Merou, que tirava água do poço para quem não podia. Tasso, que dormia no telhado para ver os astros."),
			_l(SOPHIA, "Eles eram a minha gente?"),
			_l("Soter", "Eram de todos. Por isso também são teus. Lembra-te disso quando te disserem outra coisa."),
			_m(_l("Soter", "E quando ficares sozinha, não temas o silêncio. Ele também é teu. Escolhe."), M_TRISTE),
		]
	return []


## SOTER CONCEDE A LEVEZA (Onda 6: o pulo duplo, 1º encontro, tela 17). Depois
## da bênção escolhida: as mãos dele nos ombros dela, luz, o chão pesa menos.
## Fala 0: as mãos (a luz sobe); fala 1 (rubrica, `chime`): ela fica leve e o
## pulo duplo é concedido. Gancho: npc_encounter._soter_lightness.
func soter_lightness() -> Array:
	return [
		_l("Soter", "Mais uma coisa. Fica quieta: isto não dói."),
		_c(NARRADOR, "(As mãos dele pousam nos teus ombros. Um calor sobe dos pés, e o chão, de repente, pesa menos.)", "chime"),
		_l("Soter", "Há passagens que só se alcançam com asas. Asas não dou. Dou leveza: no ar, pisa outra vez."),
		_l(SOPHIA, "(Leve. Como antes de cair.)"),
		_l("Soter", "Vê aquela luz no alto? Sobe até ela. Eu espero."),
	]


## Ela alcançou o degrau de luz (mini-desafio do pulo duplo): Soter parte.
func soter_lightness_done() -> Array:
	return [_l("Soter", "Assim. Quem dá asas não luta: só lembra que tu sabias voar.")]


## Prompt curto do pulo duplo (HUD), logo depois da leveza.
func hint_double_jump() -> String:
	return "no ar, pule outra vez"


## Prompt curto do CONTRA-ATAQUE (HUD), no 1º aparo do run.
func hint_riposte() -> String:
	return "contra-ataque: golpeie agora"


## Ao entrar num nó especial do mapa (Onda 6, mapa6: `RunManager.node_kind()`):
## uma fala curta (legenda, na calma) que diz o que o lugar é.
func node_arrival(kind: String) -> Array:
	match kind:
		"sanctuary": return [_l(SOPHIA, "(Um altar apagado. Aqui ninguém me persegue. Respiro.)")]
		"challenge": return [_l(VOZ, "Uma arena. Eles vêm em ondas, e pagam bem quem fica de pé.")]
		"secret": return [_l(SOPHIA, "(Lá no alto, uma câmara. Só se chega pisando no ar.)")]
		"hazard": return [_l(VOZ, "O chão daqui morde. Olha onde pisas.")]
		"platform": return [_l(SOPHIA, "(O caminho sobe. Degrau por degrau.)")]
	return []


func soter_blessings() -> Array:
	return ["Cura plena", "Arma desperta (+1 nível)", "Vigor (+25 de vida máx.)"]


## Legenda da Voz depois que Soter some (ela não o viu — a pista).
## Tocada por npc_encounter._do_soter, após o fade.
func after_soter(n: int) -> Array:
	match n:
		0: return [_l(VOZ, "Com quem falavas? ...Não vi ninguém. Sobe.")]
		1: return [_l(VOZ, "Paraste muito tempo. Não pares. ...Por favor.")]
		2: return [_l(VOZ, "Falta pouco. Não deixes ninguém te atrasar agora.")]
	return []


## Encontro único com Velkar, o Arrependido (tela 61, Éon da Coroa): a prova
## de que um filho do Cego pode acordar; ensina a misericórdia com o monstro.
## Termina numa escolha sem efeito mecânico (velkar_choices → velkar_farewell).
func velkar_meeting() -> Array:
	return [
		_l("Velkar", "Não ergas o cajado, Portadora. Já fui Arconte. Larguei a corrente... e ela levou o meu braço junto."),
		_l(SOPHIA, "Por que a largaste?"),
		_m(_l("Velkar", "Porque uma faísca me olhou como tu olhas os Adormecidos. Não aguentei ser olhado assim."), M_ARREPENDIDO),
		_m(_l("Velkar", "Lá em cima não há tirano. Há uma criança cega, num trono grande demais, chamando pela mãe."), M_ARREPENDIDO),
		_m(_l(SOPHIA, "...Tu choras por ele?"), M_TRISTE),
		_m(_l("Velkar", "Todo dia. Era meu pai."), M_ARREPENDIDO),
		_l("Velkar", "Quando chegares nele, acaba direito. Toma: faíscas que colhi quando era monstro. Pesam menos em ti."),
	]


func velkar_choices() -> Array:
	return ["Vem comigo", "Fica em paz"]


func velkar_farewell(choice: int) -> Array:
	if choice == 0:
		return [_m(_l("Velkar", "Não. Alguém tem de ficar com os que acordam tarde."), M_ARREPENDIDO)]
	return [_m(_l("Velkar", "Paz eu não tenho. Mas fico. Alguém tem de ficar com os que acordam tarde."), M_ARREPENDIDO)]


# --- ATO 3: O ROUBO + A MÁSCARA CAI (tela 64) ----------------------------------
## Após o 7º Arconte ("Sete."). O Rei reaparece e leva os sete Anéis; a voz-amiga
## sai da boca dele e se revela Yaldabaoth. Cada fala dele COLHE um plantio: o
## aplauso (Fome), a janela e o rio (santuários), "Portadora", "ficar contigo"
## (santuário da Coroa), "levanta" (as mortes), e a frase do Cego que a Estela
## da tela 12 ensinou. O rótulo "A Voz" saindo da boca do Rei vem ANTES do nome.
## Encenação: docs/ROTEIRO.md, cena B.
func theft() -> Array:
	return [
		_l(VOZ, "Chegaste. Todos os sete. Fizeste tudo tão bem, minha fiel."),
		_l(SOPHIA, "E agora? Tu prometeste me mostrar."),
		_c(NARRADOR, "(Passos na névoa. Um vulto que tu conheces. A máscara sem uma rachadura.)", "king_emerges"),
		_c(VOZ, "(a voz já não vem de dentro de ti: vem da boca do Rei) Mostrar. Sim.", "voice_merge"),
		_l(VOZ, "(ele aplaude, devagar) Eu disse que aplaudiria, se tivesse mãos. Tenho."),
		_m(_l(SOPHIA, "...Não."), M_CHOQUE),
		_c(NARRADOR, "(Os sete Anéis se arrancam dos teus dedos, um a um, e voam para ele como quem volta para casa.)", "rings_fly"),
		_m(_c(YAL, "(a máscara cai; atrás dela, só um olho cego) Eu sou o Cego de quem te falei. E não há outro além de mim.", "mask_falls"), M_REVELADO),
		_m(_l(YAL, "Chama-me pelo nome que nunca te disse: Yaldabaoth. Sabes o que portavas, Portadora? A mim."), M_REVELADO),
		_m(_l(YAL, "Nunca houve rio. Nunca houve janela. A tua gente? Cinzas de uma colheita qualquer."), M_REVELADO),
		_m(_l(YAL, "Dei-te um luto para te dar um caminho. O luto é a coleira mais macia."), M_REVELADO),
		_m(_l(SOPHIA, "Eu chorei por eles."), M_TRISTE),
		_m(_l(YAL, "Choraste por mim. Os sete eram meus filhos, e tu trouxeste-me o que restou deles."), M_REVELADO),
		_l("Uma voz nos Anéis", "...espera... eu... lembro..."),
		_m(_l(YAL, "(mais baixo, quase a Voz de antes) Tu disseste que ficavas comigo."), M_REVELADO),
		_m(_c(YAL, "(vira um motor de anéis e afunda no chão) Desta vez, não te levantes.", "sink"), M_REVELADO),
	]


# --- ATO 4: O CENTRO (telas 65–67) ----------------------------------------------

## O Centro (tela 65): sem os Anéis, sem a Voz. Encenação da descida: cena C.
func center_intro() -> Array:
	return [
		_c(NARRADOR, "(Silêncio. Nenhuma voz. Pela primeira vez, só o som da tua respiração.)", "wait_2s"),
		_m(_l(SOPHIA, "Voz?"), M_MEDO),
		_m(_l(SOPHIA, "..."), M_MEDO),
		_m(_l(SOPHIA, "Ninguém. ...Então eu."), M_DETERMINADA),
		_m(_l(SOPHIA, "Os ecos dele estão aqui embaixo. Cada um guarda um pedaço que ele me tirou. Vou buscá-los."), M_DETERMINADA),
	]


## Um eco quebrado devolve um caco de memória (toast do HUD, registro de sistema).
func echo_shard(_boss_id: String, skill_name: String) -> String:
	return "Caco de memória recuperado: %s" % skill_name


## A LEMBRANÇA VERDADEIRA que volta com cada eco (legendas, sem pausar — o
## Centro tem larvas). Contam o Apócrifo de João em 1ª pessoa: quem leu as
## Estelas reconhece o mito; agora é DELA. Depois do 2º caco, o poço de Soter.
## Gancho (Onda 2): level._restore_echo → Gnosis.captions(Narrative.echo_memory(boss_id)).
func echo_memory(boss_id: String) -> Array:
	match boss_id:
		"arconte_sono": return [
			_l(SOPHIA, "Antes de tudo, eu não dormia. Ninguém dormia. Éramos muitos, olhando juntos."),
		]
		"arconte_fome": return [
			_l(SOPHIA, "Eu quis ver a Fonte sozinha. Tive fome de um rosto que ninguém tinha visto."),
			_l(SOPHIA, "Não havia rio. Havia um poço. Merou tirava água dele. Eles existiram."),
		]
		"arconte_corrente": return [
			_l(SOPHIA, "Do meu querer sem par nasceu alguém. Pequeno. Torto. Meu."),
		]
		"arconte_silencio": return [
			_l(SOPHIA, "Tive vergonha. Fiz uma nuvem de luz, pus um trono pequeno no meio... e fechei."),
			_l(SOPHIA, "A nuvem branca. Era isso."),
		]
		"arconte_espelho": return [
			_l(SOPHIA, "Ele gritou que não havia outro além dele. Eu respondi lá de cima: “Erras, Samael.”"),
			_l(SOPHIA, "Foi a última vez que falei com ele."),
		]
		"arconte_praga": return [
			_l(SOPHIA, "Eu chorei. Das lágrimas veio a água; do medo, a matéria. Este mundo é o meu luto."),
		]
	return []


# --- ATO 5: A MENTE (tela 68) ---------------------------------------------------

## A batalha final: o choque, a mente dele.
func final_pre() -> Array:
	return [
		_m(_l(SOPHIA, "(Um clarão. O chão some. O mundo vira o interior de uma mente.) ...Estou dentro dele."), M_MEDO),
		_m(_l(YAL, "Duas faces: a que amaste e a que temes. As duas sou eu. Derruba uma, e a outra a refaz."), M_REVELADO),
		_m(_l(SOPHIA, "Então caem as duas. Juntas."), M_DETERMINADA),
	]


## O 7º Anel volta na PRIMEIRA queda de uma das formas (legendas, sem pausar —
## o relógio de 14 s corre). Gancho: final_battle, bloco da primeira queda.
func seventh_ring() -> Array:
	return [
		_u(_m(_l(SOPHIA, "A Coroa voltou. E com ela, o porquê: eu desci de propósito."), M_DETERMINADA)),
		_u(_m(_l(SOPHIA, "Para desfazer o que tu fazias. E para te buscar."), M_TERNURA)),
	]


## Toasts da batalha dupla (registro de sistema: imperativo de "você").
func final_form_fell(form_name: String) -> String:
	return "%s caiu. Derrube a outra antes que se refaça!" % form_name


func final_revive(form_name: String) -> String:
	return "%s se refez." % form_name


## A ANAGNÓRISE (após as DUAS formas caírem): os Anéis voltam à Sophia; ela
## olha para quem escondeu. A frase do carcereiro ("levanta") vira a da mãe; os
## nomes trocados (o dela, o dele) fecham a pergunta do jogo. Cena D.
func final_lines() -> Array:
	return [
		_c(NARRADOR, "(As duas formas caem juntas. Os sete Anéis param no ar... e voltam para ti, um por um.)", "rings_return"),
		_m(_c(SOPHIA, "Eles não são o teu corpo. São o meu: cacos meus, que tu forjaste em correntes.", "flash"), M_DETERMINADA),
		_m(_l(SOPHIA, "Vim te buscar. E os meus próprios cacos me fizeram esquecer até isso."), M_TRISTE),
		_c(NARRADOR, "(O Colosso se abre. Está oco. Lá no fundo, encolhido e cego, alguém pequeno.)", "colossus_shrinks"),
		_m(_l(CEGO, "...mãe? eu não queria ser cego. eu só queria que alguém olhasse para mim."), M_OLHANDO),
		_m(_l(SOPHIA, "Fui eu que fechei a nuvem. Fui eu que te deixei lá. Agora eu estou olhando."), M_TERNURA),
		_m(_c(SOPHIA, "Levanta. Eu te seguro.", "theme_alone"), M_TERNURA),
		_m(_c(SOPHIA, "(recolhe-o para dentro de si) Meu nome é Sophia. Fui eu que te dei o teu.", "reclaim"), M_TERNURA),
		_m(_l(SOPHIA, "Falta o mais difícil: um mundo inteiro de gente que dorme. Ninguém vai escolher por mim."), M_DETERMINADA),
	]


## Os três finais = três jeitos de nunca mais abandonar ninguém, cada um com um
## preço. O rótulo mostra o MOTIVO (curto: três botões numa linha de 520 px).
func final_choices(sleepers: int) -> Array:
	var semente_ok := sleepers >= 4
	return [
		"Ascensão — levar todos",
		"Ruptura — proteger",
		{"text": "Semente — despertar", "enabled": semente_ok,
			"hint": "Exige 4 Adormecidos despertos pelo caminho"},
	]


## A fala curta de cada final, entre a escolha e o epílogo (caixa de diálogo).
## Gancho (Onda 2): level._win, depois de apply_ending(idx).
func ending_lines(index: int) -> Array:
	match index:
		0: return [
			_m(_l(SOPHIA, "Vamos para casa. Todos."), M_SERENA),
			_l(NARRADOR, "(O Kenoma começa a se desfazer, como sonho ao amanhecer. Ela olha para trás uma vez.)"),
		]
		1: return [
			_m(_l(SOPHIA, "Ninguém mais vai ser abandonado. Eu fico. Eu olho por todos."), M_SERENA),
			_l(NARRADOR, "(O trono ainda está morno. Serve.)"),
		]
		2: return [
			_m(_l(SOPHIA, "Não vou subir. Não vou sentar. Vou descer e bater em cada porta."), M_SERENA),
			_l(NARRADOR, "(Lá embaixo, nas cinzas onde ela acordou, alguém começa a se mexer.)"),
		]
	return []


## Títulos e subtítulos do fim (cartão de abertura do epílogo e EndScreen).
func apply_ending(index: int) -> void:
	match index:
		0:
			ending = "ascensao"
			GameManager.end_title = "ASCENSÃO"
			GameManager.end_subtitle = "Toda faísca voltou à Fonte. O Kenoma se desfez como um sonho ao acordar.\nVerdade inteira. Mundo nenhum."
		1:
			ending = "ruptura"
			GameManager.end_title = "RUPTURA"
			GameManager.end_subtitle = "Sophia sentou-se no trono ainda morno. A coroa serviu.\nNinguém mais seria abandonado. Ninguém mais sairia."
		2:
			ending = "semente"
			GameManager.end_title = "SEMENTE"
			GameManager.end_subtitle = "Sophia recusou o trono e a porta. Desceu de volta, de faísca em faísca.\nSem apocalipse e sem prisão: liberdade lenta, a única que dura."
	if ending != "" and not RunManager.endings_seen.has(ending):
		RunManager.endings_seen.append(ending)


# --- ADORMECIDOS (o contrapeso moral do final Semente) --------------------------
## A fala de quem acorda (legenda, sem pausar). Gratidão, medo e recusa.
## Endereço fixo por tela (Adormecidos ficam nas telas `% 4 == 2` sem chefe);
## a lembrança da Ina só aparece depois que Soter disse o nome dela (tela 35).
## Gancho (Onda 2): sleeper, ao acordar → Gnosis.captions(Narrative.sleeper_line(screen)).
const SLEEPER_ORDER := [2, 6, 14, 18, 22, 26, 30, 34, 38, 42, 50, 54, 58, 62]

func sleeper_line(screen: int) -> Array:
	var pool := [
		[_l("Adormecida", "Eu estava sonhando com a minha mãe. Por que me acordaste?")],
		[_l("Adormecido", "Está frio aqui fora. Sempre esteve?")],
		[_l("Adormecida", "Quanto tempo eu dormi? ...Não. Não me digas.")],
		[_l("Adormecido", "Obrigado. Acho.")],
		[_l("Adormecida", "Tu também estavas dormindo? Tens a cara.")],
		[_l("Adormecido", "Se eu acordo, quem cuida do meu sonho?")],
		[_l("Adormecida", "Ele disse que dormir era bondade. Quem disse? Não lembro quem disse.")],
		[_l("Adormecido", "Deixa a luz acesa. Só um pouco.")],
		[_l("Adormecida", "Eu lembro de uma mulher que cantava errado. Ina? Tu conheceste a Ina?")],
		[_l("Adormecido", "Meu filho dorme duas ruas para lá. Vais lá também? Por favor?")],
		[_l("Adormecida", "Dói. Por que acordar dói?"), _l(SOPHIA, "Porque é teu.")],
		[_l("Adormecido", "Eu sonhava que voava. Aqui embaixo tudo pesa tanto.")],
		[_l("Adormecida", "Eu não pedi isto. ...Mas agora que vejo, não quero fechar os olhos.")],
		[_l("Adormecido", "Contam de uma que anda entre os que dormem. Eras tu?")],
	]
	var i: int = SLEEPER_ORDER.find(screen)
	if i < 0:
		i = (screen / 4) % pool.size()
	return pool[i % pool.size()]


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
		# O resto da intro (#6), andando: ela acorda à esquerda, a Estela fica
		# logo adiante e o duelo, à direita. A Cena A corta o que sobrar.
		# A Estela (D7/D8) é do Gnosis, por proximidade; a névoa (D9–D11) abre a Cena A.
		return [
			_l(SOPHIA, "Onde eu tô? ...Pior: quem sou eu?"),
			_l(VOZ, "Uma pergunta por vez. Primeiro, ande. Pra direita, de preferência."),
			_l(VOZ, "Essas cinzas eram gente. A sua gente."),
			_l(SOPHIA, "Não lembro de nenhum rosto. Isso devia doer mais, não?"),
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
			_l(SOPHIA, "Os cacos não voltam quentes. Voltam frios. E verdadeiros."),
			_l(SOPHIA, "Ele chamava os Anéis de chave. Chaves abrem, e ele esqueceu que abrem dos dois lados."),
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
			[_l(SOPHIA, "Pares de luz. Éons. Então quem era o meu par?"),
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
			[_l(SOPHIA, "Há alguém de branco mais adiante, parado numa luz que não vem de lugar nenhum."),
			 _l(VOZ, "Dizem que um tal Soter anda por estas bandas. Eu nunca o vi.")],
			[_l(VOZ, "A antessala de Harmas. Golpe primeiro; conversa, nunca.")],
			[_l(SOPHIA, "Um mercado inteiro na barriga dele. E ainda me olha com fome.")],
		]
		2: return [   # CORRENTE (telas 20–28) · Estelas 21 (Heimarmene) e 25 (barro e faísca)
			[_l(SOPHIA, "Selos por toda parte. Cada porta tem um cadeado; cada cadeado, um nome.")],
			[_l(VOZ, "Heimarmene, diziam os antigos: o Destino como corrente. Aqui, é corrente mesmo.")],
			[_l(SOPHIA, "Os astros são os elos. Sete elos, sete céus, sete Arcontes."),
			 _l(VOZ, "E tu já partiste dois. Continua.")],
			[_l(VOZ, "Galila não te odeia. Classifica-te. É pior.")],
			[_l(VOZ, "O Carcereiro do santuário prende primeiro e pergunta depois. Esquiva-te, e a corrente se parte.")],
			[_l(SOPHIA, "Se a lei daqui é medo com coroa, quem usa a coroa?"),
			 _l(VOZ, "O Cego, lá no alto. Ninguém mais. Sobe.")],
			[_l(SOPHIA, "A pedra diz que o sopro no barro veio de fora deste mundo. Então eu também vim?"),
			 _l(VOZ, "Vieste de mim. Achei-te. Não esqueças a ordem das coisas.")],
			[_l(VOZ, "Última porta antes do trono. As correntes dele cantam quando têm medo.")],
			[_l(SOPHIA, "Um trono feito de elos. Ele se acorrentou a si mesmo para não cair.")],
		]
		3: return [   # SILÊNCIO (telas 29–37) · Estelas 30 (gnose), 33 (Nag Hammadi), 35 (Apócrifo) · Soter 35
			[_l(SOPHIA, "Livros em branco. Milhares. Alguém apagou uma biblioteca inteira.")],
			[_l(VOZ, "Aqui a Palavra foi calada. Yabel costurou a própria boca para dar o exemplo.")],
			[_l(SOPHIA, "Ouviste? De novo. Fraca, por baixo de ti."),
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
			[_l(VOZ, "Astaphaios vai dar-te o que mais queres: tu, antes de tudo. É o golpe mais cruel.")],
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
			[_l(VOZ, "Cinco Anéis. Mais dois, e mostro-te o fim de tudo isto.")],
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
			[_l(VOZ, "Bonito golpe. Eu teria aplaudido, se tivesse mãos."),
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
			[_l(SOPHIA, "Se o Cego fez os sete à imagem dele... derrubar os sete derruba o quê?")],
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
			[_l(SOPHIA, "O que está dentro de mim me salva? E se o que está dentro for escuro?"),
			 _l(VOZ, "Então eu sou a tua luz. Basta.")],
			[],
			[_l(VOZ, "Não respires fundo aqui. Nem para suspirar."),
			 _l(SOPHIA, "Cinco Anéis, cada um mais quente que o anterior. Como se me reconhecessem.")],
			[_l(SOPHIA, "O manto do príncipe esperava por ele lá em cima. Será que algo me espera?"),
			 _l(SOPHIA, "Ina, Merou, Tasso. Digo os nomes baixinho, para não esquecer.")],
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
## Três finais, três formas de amor — nenhum é "o final mau". Voz do narrador
## (a mesma das Estelas). O título e o subtítulo já estão no GameManager
## (apply_ending). Cada item vira um card.
func epilogue_cards(which: String) -> Array:
	match which:
		"ascensao": return [
			"As sete esferas se apagaram como lamparinas ao amanhecer. Os Arcontes voltaram a ser o que sempre foram: nomes.",
			"Os que dormiam não acordaram. Só deixaram de sonhar. Ninguém perguntou se queriam.",
			"No colo da Fonte, uma criança aprendeu a ver. A mãe olhou para trás uma vez. Bastou para lembrar; não para ficar.",
		]
		"ruptura":
			var r := [
				"A coroa pesava menos do que ele dizia. Isso devia ter sido o aviso.",
				"Sete tronos, sete cascas novas. O Kenoma não notou a diferença. Ela cuidava de todos. De todos.",
			]
			if concessions >= 4:
				r.append("Tantas vezes provou os presentes deles. O trono só lhe pareceu familiar.")
			r.append("Um dia, numa cidade de cinzas, alguém acordou e ouviu uma voz gentil: “Ei. Acorda. Essas cinzas eram a sua gente.”")
			return r
		"semente": return [
			"Ela desceu de porta em porta, batendo à casa dos que dormem. Alguns abriram. Outros pediram mais um pouco de sonho. Ela esperou.",
			"Na cidade das cinzas aprendeu os nomes. Ina, que cantava errado. Merou, do poço. Tasso, do telhado. Disse cada um em voz alta.",
			"Não eram a gente dela. Agora são. E dentro dela, pequeno, alguém aprendia a ver.",
		]
	return ["A faísca lembrou. O resto é silêncio."]
