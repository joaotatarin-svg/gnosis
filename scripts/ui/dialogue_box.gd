extends CanvasLayer
class_name DialogueBox
## Caixa de diálogo do jogo. Pausa o mundo (PauseStack), mostra falas com
## MÁQUINA DE ESCREVER (1º aperto mostra a fala inteira, 2º avança) e,
## opcionalmente, termina numa escolha com botões. Moldura do Códex, placa com
## o nome do falante e retrato pintado quando houver (assets/ui/portraits/).
##
## API (para Level, Encenação e ferramentas):
##   var d := DialogueBox.play([{speaker, text, cue?, mood?}, ...], ["Op A", {text, enabled, hint}])
## Campo `mood` (Onda 3): emoção do retrato — ver MOODS / portrait_for().
##   await d.finished                      (ou: var i = await d.choice_made)
##   d.line_shown(index, line)             sinal emitido NO INÍCIO de cada fala (antes da
##                                         1ª letra). A Encenação dispara o efeito pelo `cue`.
##   d.lock_advance(true/false)            trava/destrava o AVANÇO (o 1º aperto ainda completa
##                                         a fala). Ex.: enquanto as 7 gemas voam (cena B).
##   d.is_advance_locked() -> bool
##   d.reveal_all() · d.is_typing()
## Campo `cue` da fala: a caixa só entende `"wait_2s"` = durante 2 s
## nenhum aperto é aceito (nem completar, nem avançar); o resto é da Encenação.
## Tempos (wait_2s, guarda da escolha) contam pelo `delta` do _process.
## Escolha: caixa e botões sempre dentro de 640×360 (a caixa cresce para cima e
## os botões encolhem a fonte se precisar); opção bloqueada mostra o MOTIVO
## (campo `hint`) escrito na própria caixa, não só em dica de mouse. Foco no 1º
## botão habilitado, ←/→ circulam, ui_accept escolhe (0,25 s de guarda contra
## aperto acidental de quem vinha pulando falas).
## Voz: a cada 2 letras visíveis `Audio.play_blip(falante)` (se existir; senão o
## blip antigo por `play_sfx`). Sem arquivo de som, fica mudo.
## DUBLAGEM (Onda 7 — edição do Áudio por delegação do chefe): cada fala pede
## `Audio.play_voice(fala, self)`. Com voz: sem blips, e a máquina de escrever
## anda no ritmo da voz (texto e voz terminam juntos, ±0,3 s). Regras do Guardião
## (_caps/dublagem/REGRAS_GUARDIAO.md §2-3): avanço livre desde o 1º quadro;
## apertar com a voz soando completa o texto e corta a voz (fade 80 ms); o aperto
## seguinte avança. Fala dublada ignora o `wait_2s` (a voz já dá a pausa). Sem
## arquivo de voz ou Vozes em 0 %: tudo como antes.
## RUBRICA (backlog #22) — modo `narration`: fala SEM falante cujo texto é só uma
## rubrica entre parênteses (ou com `mode: "narration"`) não usa a caixa: o texto
## aparece centralizado, em itálico, sem os parênteses, sobre um véu.
##   · `dark` = tela escura (abre a cena no escuro). Padrão: só na 1ª fala da caixa
##     e só se o `cue` dela não for encenação visual (sem cue, ou "heartbeat"/"wait_2s");
##   · senão véu leve na base, para a Encenação seguir visível (anéis voltando etc.).
##   O campo `dark: true/false` da fala manda no padrão.
## Velocidade do texto: `GameManager.settings["text_speed"]` (multiplicador 0,5/1/2;
## 0, ≥10 ou "instant" = instantâneo) — ver text_speed(). A legenda usa o mesmo.
## Rodapé "continuar" mostra o botão de avançar no dispositivo em uso (InputGlyphs,
## quando existir; sem ele, só o texto).

signal finished
signal choice_made(index: int)
## No INÍCIO de cada fala exibida (o Level/Encenação usa o campo opcional `cue`).
signal line_shown(index: int, line: Dictionary)

const CPS := 46.0                 # letras por segundo
const PANEL := Rect2(36, 250, 568, 98)
## Com escolhas a caixa cresce PARA CIMA (a base fica no lugar): a fala em cima,
## os botões numa linha de largura cheia e o motivo da opção bloqueada embaixo.
const PANEL_TALL := Rect2(36, 214, 568, 134)
const PORTRAIT_DY := 49.0         # centro do retrato abaixo do topo do painel
const PORTRAIT_X := 80.0
const PORTRAIT_R := 30.0
const WAIT_CUE := "wait_2s"
const WAIT_SECONDS := 2.0
const CHOICE_GUARD := 0.25        # s em que ui_accept não escolhe (aperto acidental)
const CHOICE_SEP := 10.0
const NARR_WIDTH := 460.0         # largura do texto da rubrica (centralizado)
const NARR_DARK_A := 0.97         # véu da rubrica escura
const NARR_FADE := 0.45           # s da troca caixa ↔ rubrica
const ADVANCE_ACTION := "jump"    # botão mostrado no rodapé (pular/A também avança)
const GLYPHS_PATH := "res://scripts/ui/input_glyphs.gd"
## Cues que NÃO pedem a cena visível (som/tempo): a rubrica de abertura pode ser escura.
const DARK_OK_CUES := ["", "heartbeat", "wait_2s"]
## RETRATOS POR EMOÇÃO (Onda 3) — campo opcional `mood` da fala:
##   {"speaker": "Sophia", "text": "...Não.", "mood": "choque"}
## Falantes com emoções (o resto ignora o campo e usa o retrato único):
const MOODS := {
	"sophia": ["neutra", "determinada", "triste", "raiva", "medo", "ternura", "choque", "serena"],
	"rei": ["regio", "ironico", "revelado", "quebrado"],
	"soter": ["sereno", "triste"],
	"velkar": ["elmo", "arrependido"],
	# "O Cego" pequeno (cena D, tela 68 — Onda 6): bustos derivados da arte
	# (assets/ui/build_derived_portraits.py → assets/ui/portraits/cego_<humor>.png).
	"cego": ["olhando", "assustado", "sereno", "aninhado"],
}
## Sem `mood` (ou desconhecido): o neutro de cada um.
const MOOD_DEFAULT := {"sophia": "neutra", "rei": "regio", "soter": "sereno", "velkar": "elmo", "cego": "olhando"}
## Sinônimos aceitos (inglês do manifesto do GPT e variações comuns).
const MOOD_ALIAS := {
	"neutral": "neutra", "determined": "determinada", "decidida": "determinada", "sad": "triste",
	"tristeza": "triste", "anger": "raiva", "angry": "raiva", "brava": "raiva", "raivosa": "raiva",
	"fear": "medo", "afraid": "medo", "assustada": "medo", "tender": "ternura", "terna": "ternura",
	"shock": "choque", "shocked": "choque", "chocada": "choque", "serene": "serena", "paz": "serena",
	"regal": "regio", "ironic": "ironico", "ironia": "ironico", "revealed": "revelado",
	"broken": "quebrado", "helm": "elmo", "repentant": "arrependido",
	"looking": "olhando", "scared": "assustado", "curled": "aninhado", "nestled": "aninhado",
}

var lines: Array = []
var choices: Array = []      # String ou {text: String, enabled: bool}
var idx: int = 0

var _root: Control
var _panel: Panel
var _deco: _Deco
var _plate: Panel
var _speaker: Label
var _text: Label
var _choice_box: HBoxContainer
var _reason: Label
var _in_choices: bool = false
var _rect: Rect2 = PANEL          # painel atual (anima entre PANEL e PANEL_TALL)
var _tall: bool = false
var _rect_tween: Tween
var _clock: float = 0.0           # s acumulados no _process (delta; respeita --fixed-fps)
var _wait_until: float = 0.0      # _clock até aceitar input de novo (cue wait_2s)
var _locked: bool = false         # lock_advance(true)
var _choices_at: float = -100.0   # _clock em que os botões apareceram
var _speaker_name: String = ""
var _paused_world: bool = false
var _typing: bool = false
var _shown: float = 0.0           # letras visíveis (fracionário)
var _pause: float = 0.0           # respiro de pontuação
var _blip_count: int = 0
var _blip: String = "blip_npc"
var _t: float = 0.0
var _portrait: Texture2D
var _box: Control                 # véu de base + caixa + placa + texto + escolhas
var _narr: Control                # camada da rubrica (véu + texto centralizado)
var _narr_veil: _NarrVeil
var _narr_text: Label
var _narr_on: bool = false        # fala atual é rubrica?
var _narr_dark: bool = false
var _mode_tween: Tween
var _mode_set: bool = false       # já houve a 1ª fala (sem fade cruzado nela)
var _cont: _Cont                  # rodapé "continuar" (fica fora de _box)
var _speed: float = 1.0           # text_speed() lido ao abrir
var _voice_dur: float = 0.0       # dublagem: duração da voz da fala atual (0 = blips)
const VOICE_CUT := 0.08           # apertar com a voz soando: fade de corte (Guardião §2)
var _cps: float = CPS             # letras/s da fala atual (com voz: o ritmo da voz)
var _pause_k: float = 1.0         # escala dos respiros de pontuação da fala atual
var _scene: Node                  # cena dona da fala (QA7 #14: troca de cena fecha a caixa)


static func play(p_lines: Array, p_choices: Array = []) -> DialogueBox:
	var d: DialogueBox = DialogueBox.new()
	d.lines = p_lines
	d.choices = p_choices
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.call_deferred("add_child", d)
	return d


## Retrato pintado do falante (null = sem retrato: A Voz, Estelas, desconhecidos).
## `mood` (campo opcional da fala) escolhe a EMOÇÃO quando o falante tem
## retratos por emoção (assets/ui/portraits/<id>_<emoção>.png — ver MOODS);
## vazio/desconhecido = o neutro dele. Sem os arquivos, o retrato antigo <id>.png.
static func portrait_for(speaker: String, mood: String = "") -> Texture2D:
	var id := speaker_id(speaker)
	if id == "":
		return null
	if MOODS.has(id):
		var m := mood_for(id, mood)
		var mp := "res://assets/ui/portraits/%s_%s.png" % [id, m]
		if ResourceLoader.exists(mp):
			return load(mp)
	var path := "res://assets/ui/portraits/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


## Id do retrato pelo nome do falante ("" = sem retrato).
static func speaker_id(speaker: String) -> String:
	var s := speaker.to_lower()
	# O Cego (a criança que o Rei foi) antes do teste do Rei/Yaldabaoth.
	if s.contains("cego") or s.contains("blind"):
		return "cego"
	for k in ["sophia", "athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "soter", "velkar"]:
		if s.contains(k):
			return k
	if s.contains("rei") or s.contains("yaldabaoth"):
		return "rei"
	return ""


## Emoção normalizada para o falante `id`: aceita sem acento, o outro gênero
## ("sereno"/"serena") e os nomes em inglês do manifesto ("shock", "regal"...).
## Desconhecida ou vazia = MOOD_DEFAULT[id].
static func mood_for(id: String, mood: String) -> String:
	var list: Array = MOODS.get(id, [])
	var def := String(MOOD_DEFAULT.get(id, ""))
	var m := _plain(mood.strip_edges().to_lower())
	if m == "":
		return def
	if list.has(m):
		return m              # nome exato do falante vence o sinônimo ("assustado" do Cego ≠ "medo")
	m = String(MOOD_ALIAS.get(m, m))
	if list.has(m):
		return m
	# o outro gênero (sereno ↔ serena, neutro ↔ neutra, determinado ↔ determinada)
	if m.ends_with("a") and list.has(m.left(m.length() - 1) + "o"):
		return m.left(m.length() - 1) + "o"
	if m.ends_with("o") and list.has(m.left(m.length() - 1) + "a"):
		return m.left(m.length() - 1) + "a"
	return def


static func _plain(t: String) -> String:
	var from := "áàâãéêíóôõúüç"
	var to := "aaaaeeiooouuc"
	for i in from.length():
		t = t.replace(from[i], to[i])
	return t


## Som de "voz" (blip) por falante.
static func blip_for(speaker: String) -> String:
	var s := speaker.to_lower()
	if s.contains("voz"):
		return "blip_voz"
	if s.contains("sophia"):
		return "blip_sophia"
	if s.contains("estela"):
		return "blip_estela"
	if s.contains("rei") or s.contains("yaldabaoth") or s.contains("???"):
		return "blip_rei"
	for k in ["athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "arconte"]:
		if s.contains(k):
			return "blip_rei"
	return "blip_npc"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseStack.push(self)
	_paused_world = true
	layer = 90
	_scene = get_tree().current_scene

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CodexStyle.theme()
	add_child(_root)
	_speed = text_speed()

	# Rubrica: véu + texto centralizado (embaixo da caixa na ordem; só um aparece).
	_narr = Control.new()
	_narr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_narr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr.modulate.a = 0.0
	_root.add_child(_narr)
	_narr_veil = _NarrVeil.new()
	_narr_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_narr_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_narr.add_child(_narr_veil)
	_narr_text = Label.new()
	_narr_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narr_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narr_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narr_text.add_theme_font_override("font", CodexStyle.italic())
	_narr_text.add_theme_font_size_override("font_size", GameManager.caption_font_size() + 3)
	_narr_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_narr_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_narr_text.add_theme_constant_override("outline_size", 4)
	_narr_text.add_theme_constant_override("line_spacing", 2)
	_narr_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# i18n (Onda 4): o texto chega já traduzido por I18n.t (a digitação conta as
	# letras do texto EXIBIDO; com a tradução automática os índices desalinhariam).
	_narr_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_narr.add_child(_narr_text)

	_box = Control.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_box)

	# Véu leve na base (o texto assenta sobre o cenário).
	var veil := _Veil.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(veil)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.95))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_panel)

	_deco = _Deco.new()
	_deco.box = self
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_deco)

	# Placa do nome: aba sobre a borda de cima do painel.
	_plate = Panel.new()
	var pf := CodexStyle.button_frame("normal")
	pf.fill_top = Color(0.09, 0.17, 0.2, 0.98)
	pf.fill_bottom = Color(0.04, 0.08, 0.1, 0.98)
	pf.border = Color(CodexStyle.GOLD, 0.9)
	pf.inner = Color(CodexStyle.GOLD, 0.25)
	pf.chamfer = 4.0
	_plate.add_theme_stylebox_override("panel", pf)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_plate)
	_speaker = Label.new()
	_speaker.add_theme_font_override("font", CodexStyle.display())
	_speaker.add_theme_font_size_override("font_size", 10)
	_speaker.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_plate.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Tamanho da legenda vem das Opções (P/M/G); a Alegreya pede +1 pra
	# render o mesmo "olho" da fonte antiga.
	_text.add_theme_font_size_override("font_size", GameManager.caption_font_size() + 1)
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_constant_override("line_spacing", 1)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_box.add_child(_text)

	_choice_box = HBoxContainer.new()
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", int(CHOICE_SEP))
	_choice_box.visible = false
	_box.add_child(_choice_box)

	# Motivo da opção bloqueada (visível, não só tooltip de mouse).
	_reason = Label.new()
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reason.add_theme_font_override("font", CodexStyle.italic())
	_reason.add_theme_font_size_override("font_size", 10)
	_reason.add_theme_color_override("font_color", CodexStyle.MUTED)
	_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reason.clip_text = true
	_reason.visible = false
	_box.add_child(_reason)

	# Rodapé "continuar" (desenha na caixa OU sob a rubrica).
	_cont = _Cont.new()
	_cont.box = self
	_cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cont)

	# Com escolhas, a caixa já nasce alta se não houver fala antes delas.
	_tall = not choices.is_empty() and lines.size() <= 1
	_rect = PANEL_TALL if _tall else PANEL
	_place()

	# Entrada: sobe 10 px e acende.
	_root.modulate.a = 0.0
	_root.position.y = 10
	var t := create_tween().set_parallel(true)
	t.tween_property(_root, "modulate:a", 1.0, 0.18)
	t.tween_property(_root, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_line()


func _show_line() -> void:
	if idx >= lines.size():
		if choices.is_empty():
			_finish()
		else:
			_show_choices()
		return
	var l: Dictionary = lines[idx]
	var who := String(l.get("speaker", ""))
	_speaker_name = who
	_portrait = portrait_for(who, String(l.get("mood", "")))
	_blip = blip_for(who)
	_speaker.text = I18n.t(who)        # o nome pt continua a chave de retrato/blip
	_plate.visible = who != ""
	var narr := is_narration(l)
	_set_narration(narr, narration_dark(l, idx) if narr else false)
	if narr:
		_narr_text.text = narration_text(I18n.t(String(l.get("text", ""))))
		_text.text = ""
	else:
		_text.text = I18n.t(String(l.get("text", "")))
		_narr_text.text = ""
	_label().visible_characters = 0
	_shown = 0.0
	_pause = 0.0
	_blip_count = 0
	_typing = true
	# A última fala antes das escolhas já usa a caixa alta (sem pulo depois).
	_set_tall(not choices.is_empty() and idx >= lines.size() - 1)
	_place()
	_deco.queue_redraw()
	_start_voice(l)
	# Fala dublada ignora o wait_2s (Guardião §2: avanço livre; a voz já dá a pausa).
	if String(l.get("cue", "")) == WAIT_CUE and _voice_dur <= 0.0:
		_wait_until = _clock + WAIT_SECONDS
	# Texto instantâneo (Opções): a fala já nasce inteira.
	if is_inf(_speed):
		reveal_all()
	# No INÍCIO da fala (antes da 1ª letra): a Encenação reage ao `cue` já aqui.
	line_shown.emit(idx, l)


## Dublagem: toca a voz da fala (se houver) e acerta o ritmo da digitação.
func _start_voice(l: Dictionary) -> void:
	_cps = CPS * _speed
	_pause_k = 1.0 / _speed
	_voice_dur = 0.0
	if not Audio.has_method("play_voice"):
		return
	_voice_dur = float(Audio.call("play_voice", l, self))
	if _voice_dur <= 0.0:
		return
	_cps = voice_cps(_label().text, _voice_dur, _label().get_total_character_count())
	_pause_k = voice_pause_k(_label().text, _voice_dur)


## Letras/s para o texto terminar JUNTO com a voz (VOICE_END_LEAD antes do fim,
## respiros incluídos — Guardião §3: ±0,3 s). O texto "instantâneo" das Opções
## continua instantâneo (reveal_all em _show_line).
const VOICE_END_LEAD := 0.0       # o arquivo já tem ~0,1-0,25 s de cauda depois da última palavra
## `total` = letras que a digitação conta (Label.get_total_character_count: sem
## espaços nem quebras); < 0 = conta aqui do mesmo jeito.
static func voice_cps(txt: String, dur: float, total: int = -1) -> float:
	if total < 0:
		total = 0
		for ch in txt:
			if ch != "\n" and ch != " ":
				total += 1
	var pauses := _pause_total(txt) * voice_pause_k(txt, dur)
	var needed := maxf(0.3, dur - VOICE_END_LEAD - pauses)
	return float(total) / needed


## Respiros de pontuação encolhem se somariam mais que metade da voz.
static func voice_pause_k(txt: String, dur: float) -> float:
	var p := _pause_total(txt)
	return 1.0 if p <= dur * 0.5 or p <= 0.0 else dur * 0.5 / p


static func _pause_total(txt: String) -> float:
	var p := 0.0
	# a pontuação do FIM não pausa (a digitação acaba na última letra)
	var end := txt.length()
	while end > 0 and txt[end - 1] in [".", "!", "?", "…", ",", ";", ":", "—", " ", "\n", ")", "\"", "”"]:
		end -= 1
	for ch in txt.substr(0, end):
		if ch in [".", "!", "?", "…"]:
			p += 0.2
		elif ch in [",", ";", ":", "—"]:
			p += 0.08
	return p


## Fala atual tem voz gravada? (QA/sonda)
func has_voice() -> bool:
	return _voice_dur > 0.0


## A fala é uma RUBRICA (modo narration)? Sem falante e o texto todo entre
## parênteses — ou `mode: "narration"` explícito.
static func is_narration(l: Dictionary) -> bool:
	var mode := String(l.get("mode", ""))
	if mode != "":
		return mode == "narration"
	if String(l.get("speaker", "")).strip_edges() != "":
		return false
	var t := String(l.get("text", "")).strip_edges()
	return t.length() > 2 and t.begins_with("(") and t.ends_with(")") and t.count("(") == 1


## Rubrica escura? `dark` da fala; senão só a 1ª da caixa sem cue visual.
static func narration_dark(l: Dictionary, index: int) -> bool:
	if l.has("dark"):
		return bool(l["dark"])
	return index == 0 and String(l.get("cue", "")) in DARK_OK_CUES


## Texto da rubrica sem os parênteses de fora (o itálico já marca a rubrica).
static func narration_text(t: String) -> String:
	var s := t.strip_edges()
	if s.begins_with("(") and s.ends_with(")"):
		s = s.substr(1, s.length() - 2).strip_edges()
	return s


## Velocidade do texto das Opções: multiplicador sobre as letras por segundo.
## `settings["text_speed"]` = 0,5 / 1 / 2 (número ou "2x"); 0, ≥ 10 ou "instant…"
## = instantâneo (devolve INF). Sem a chave, 1.
static func text_speed() -> float:
	var v = GameManager.settings.get("text_speed", 1.0)
	if v is String:
		var s := (v as String).strip_edges().to_lower()
		if s.begins_with("inst"):
			return INF
		v = s.trim_suffix("x").trim_suffix("×").replace(",", ".").to_float()
	if not (v is float or v is int):
		return 1.0
	var f := float(v)
	if f <= 0.0 or f >= 10.0:
		return INF
	return clampf(f, 0.25, 4.0)


## Script do InputGlyphs (do ui-menus) se existir; null = sem glifos.
static func glyphs():
	return load(GLYPHS_PATH) if ResourceLoader.exists(GLYPHS_PATH) else null


## Rótulo que está sendo digitado (caixa ou rubrica).
func _label() -> Label:
	return _narr_text if _narr_on else _text


## Liga/desliga o modo rubrica com fade cruzado (caixa ↔ véu + texto central).
func _set_narration(on: bool, dark: bool) -> void:
	var first := not _mode_set
	_mode_set = true
	_narr_dark = dark
	_narr_veil.dark = dark
	_narr_veil.queue_redraw()
	_narr_text.size = Vector2(NARR_WIDTH, 120.0 if dark else 64.0)
	_narr_text.position = Vector2((640.0 - NARR_WIDTH) * 0.5, 120.0 if dark else 262.0)
	if on == _narr_on and not first:
		return
	_narr_on = on
	if _mode_tween != null and _mode_tween.is_valid():
		_mode_tween.kill()
	if first:
		# 1ª fala: nada de fade cruzado (a entrada geral já acende o _root).
		_narr.modulate.a = 1.0 if on else 0.0
		_box.modulate.a = 0.0 if on else 1.0
		return
	_mode_tween = create_tween().set_parallel(true)
	_mode_tween.tween_property(_narr, "modulate:a", 1.0 if on else 0.0, NARR_FADE)
	_mode_tween.tween_property(_box, "modulate:a", 0.0 if on else 1.0, NARR_FADE * 0.7)


## Posiciona painel, placa, texto, retrato, botões e motivo a partir de `_rect`.
func _place() -> void:
	if _panel == null:
		return
	_panel.position = _rect.position
	_panel.size = _rect.size
	var x0 := _rect.position.x + (88.0 if _portrait != null else 22.0)
	var font: Font = CodexStyle.display()
	var w := font.get_string_size(_speaker.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 30.0
	_plate.position = Vector2(x0 - 6.0, _rect.position.y - 10.0)
	_plate.size = Vector2(maxf(70.0, w), 19)
	_speaker.position = Vector2.ZERO
	_speaker.size = _plate.size
	_text.position = Vector2(x0, _rect.position.y + 16.0)
	_text.size = Vector2(_rect.end.x - 22.0 - x0, PANEL.size.y - 30.0)
	# Botões: linha de largura cheia abaixo do retrato; motivo logo embaixo.
	var inner := _rect.size.x - 28.0
	var bw := minf(inner, _choice_box.get_combined_minimum_size().x)
	_choice_box.size = Vector2(bw, CodexStyle.BTN_H)
	_choice_box.position = Vector2(_rect.position.x + 14.0 + (inner - bw) * 0.5, _rect.end.y - 46.0)
	_reason.position = Vector2(_rect.position.x + 14.0, _rect.end.y - 18.0)
	_reason.size = Vector2(inner, 13.0)


func portrait_center() -> Vector2:
	return Vector2(PORTRAIT_X, _rect.position.y + PORTRAIT_DY)


func _set_tall(on: bool) -> void:
	if on == _tall:
		return
	_tall = on
	if _rect_tween != null and _rect_tween.is_valid():
		_rect_tween.kill()
	var from := _rect
	var to := PANEL_TALL if on else PANEL
	_rect_tween = create_tween()
	_rect_tween.tween_method(func(k: float):
		_rect = Rect2(from.position.lerp(to.position, k), from.size.lerp(to.size, k))
		_place(), 0.0, 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Trava/destrava o AVANÇO de fala (a Encenação segura a caixa enquanto algo
## acontece — ex.: as 7 gemas voando). O 1º aperto ainda completa o texto.
func lock_advance(on: bool) -> void:
	_locked = on
	_deco.queue_redraw()


func is_advance_locked() -> bool:
	return _locked


## `cue == "wait_2s"` ainda segurando?
func _waiting() -> bool:
	return _clock < _wait_until


## Mostra a fala inteira (1º aperto durante a digitação).
func reveal_all() -> void:
	_typing = false
	_text.visible_characters = -1
	_narr_text.visible_characters = -1


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	# A cena que abriu a fala saiu (troca de cena direta, Abandonar, Crônicas…):
	# a caixa vai junto — antes ela ficava por cima da tela nova tapando botões (QA7 #14).
	if _scene_gone():
		_abort()
		return
	# Relógio da caixa: delta (sem câmera lenta), não o relógio de parede.
	_clock += delta / maxf(0.01, Engine.time_scale)
	_t += delta
	_deco.queue_redraw()
	_cont.queue_redraw()
	if not _typing:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var lab := _label()
	var total := lab.get_total_character_count()
	var before := int(_shown)
	_shown += delta * _cps
	var now := mini(int(_shown), total)
	var txt := lab.text
	for i in range(before, now):
		var ch := txt[i] if i < txt.length() else ""
		if ch != " " and ch != "\n" and not _narr_on and _voice_dur <= 0.0:
			_blip_count += 1
			if _blip_count % 2 == 1:
				_play_blip()
		# respiro na pontuação
		if ch in [".", "!", "?", "…"]:
			_pause = 0.2 * _pause_k
			_shown = float(i + 1)
			now = i + 1
			break
		elif ch in [",", ";", ":", "—"]:
			_pause = 0.08 * _pause_k
			_shown = float(i + 1)
			now = i + 1
			break
	lab.visible_characters = now
	if now >= total:
		_typing = false
		lab.visible_characters = -1


## Blip de voz: API nova do Áudio por falante; sem ela, o som antigo por nome.
func _play_blip() -> void:
	if Audio.has_method("play_blip"):
		Audio.call("play_blip", _speaker_name)
	else:
		Audio.play_sfx(_blip)


func _show_choices() -> void:
	_in_choices = true
	_typing = false
	_text.visible_characters = -1
	_set_narration(false, false)       # escolha sempre na caixa
	_set_tall(true)
	_choice_box.visible = true
	_choices_at = _clock
	var first_btn: Button = null
	var btns: Array = []
	var reasons: Array = []
	for i in choices.size():
		var c = choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(120, CodexStyle.BTN_H)
		if c is String:
			btn.text = c
		else:
			btn.text = c.get("text", "?")
			btn.disabled = not c.get("enabled", true)
			if btn.disabled and c.has("hint"):
				btn.tooltip_text = c.hint
				reasons.append(_reason_text(I18n.t(btn.text), I18n.t(String(c.hint))))
		CodexStyle.style_button(btn)
		CodexStyle._wire(btn, "")
		btn.pressed.connect(_on_choice.bind(i))
		btn.focus_entered.connect(_on_choice_focus.bind(btn))
		_choice_box.add_child(btn)
		btns.append(btn)
		if first_btn == null and not btn.disabled:
			first_btn = btn
	_fit_choices(btns)
	# Esquerda/direita circulam; cima/baixo ficam (não fogem para o nada).
	for k in btns.size():
		var bb: Button = btns[k]
		var prev: Button = btns[(k - 1 + btns.size()) % btns.size()]
		var next: Button = btns[(k + 1) % btns.size()]
		bb.focus_neighbor_top = bb.get_path_to(bb)
		bb.focus_neighbor_bottom = bb.get_path_to(bb)
		bb.focus_neighbor_left = bb.get_path_to(prev)
		bb.focus_neighbor_right = bb.get_path_to(next)
	_reason.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # já traduzido acima
	_reason.text = "  ·  ".join(reasons)
	_reason.visible = not reasons.is_empty()
	_place()
	CodexStyle.stagger_in(btns, 0.0, 0.06)
	if not reasons.is_empty():
		CodexStyle.stagger_in([_reason], 0.0, 0.0, 0.18)
	if first_btn:
		first_btn.grab_focus()
	_deco.queue_redraw()


## "Semente — despertar" + "Exige 4 Adormecidos…" → "Semente: exige 4 Adormecidos…"
static func _reason_text(label: String, hint: String) -> String:
	var short := label.split(" — ", false, 1)[0].strip_edges() if label.contains(" — ") else label
	var h := hint.strip_edges()
	if h.length() > 1:
		h = h.left(1).to_lower() + h.substr(1)
	return "%s: %s" % [short, h]


## Os botões cabem na largura da caixa: encolhe a fonte; em último caso corta o texto.
func _fit_choices(btns: Array) -> void:
	var inner := PANEL_TALL.size.x - 28.0
	for fs in [10, 9, 8]:
		for b in btns:
			(b as Button).add_theme_font_size_override("font_size", fs)
		if _choice_box.get_combined_minimum_size().x <= inner:
			return
	var each := floorf((inner - CHOICE_SEP * float(btns.size() - 1)) / float(maxi(1, btns.size())))
	for b in btns:
		var bb: Button = b
		bb.clip_text = true
		bb.custom_minimum_size.x = each


## Foco numa opção bloqueada acende o motivo (quem joga de controle "lê" o cadeado).
func _on_choice_focus(btn: Button) -> void:
	_reason.add_theme_color_override("font_color", CodexStyle.GOLD_HI if btn.disabled else CodexStyle.MUTED)


func _on_choice(i: int) -> void:
	Audio.play_sfx("ui_choice")
	choice_made.emit(i)
	_finish()


func _finish() -> void:
	_stop_voice()
	_release_pause()
	finished.emit()
	queue_free()


## A cena dona foi trocada? (aberta sem cena — ferramenta/boot — adota a 1ª que aparecer)
func _scene_gone() -> bool:
	var cur := get_tree().current_scene
	if _scene == null:
		_scene = cur
		return false
	return not is_instance_valid(_scene) or cur != _scene


## Fecha sem escolher: solta a pausa, avisa quem espera `finished` e some.
func _abort() -> void:
	set_process(false)
	_stop_voice()
	_release_pause()
	finished.emit()
	queue_free()


func _release_pause() -> void:
	if _paused_world:
		_paused_world = false
		PauseStack.pop(self)


## Dublagem: corta a voz DESTA caixa (fade curto; < 0 = o padrão do Audio).
## A fala continua "dublada" (sem blips): só a voz sai.
func _stop_voice(fade: float = -1.0) -> void:
	if _voice_dur > 0.0 and Audio.has_method("stop_voice"):
		if fade < 0.0:
			Audio.call("stop_voice", self)
		else:
			Audio.call("stop_voice", self, fade)


## Caixa apagada sem passar por _finish (troca de cena): não segura a pausa.
func _exit_tree() -> void:
	_stop_voice()
	_release_pause()


func _input(event: InputEvent) -> void:
	# Dispositivo em uso para o rodapé (o ouvinte do InputGlyphs também faz; idempotente).
	var g = glyphs()
	if g != null:
		g.note_event(event)
	# Guarda: quem vinha apertando para pular falas não escolhe sem querer.
	if _in_choices and event.is_action_pressed("ui_accept") and _clock - _choices_at < CHOICE_GUARD:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _in_choices:
		# Botão A do controle escolhe mesmo se o InputMap ainda não ligou A em
		# ui_accept (quando ligar, o botão já recebeu o aperto e isto nem chega aqui).
		if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A:
			if _clock - _choices_at < CHOICE_GUARD:
				return
			var f := get_viewport().gui_get_focus_owner()
			if f is Button and _choice_box.is_ancestor_of(f) and not (f as Button).disabled:
				get_viewport().set_input_as_handled()
				(f as Button).pressed.emit()
		return
	if event.is_action_pressed("attack_light") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _waiting():
			return                 # cue wait_2s: 2 s de silêncio, nenhum aperto vale
		var voiced: bool = _voice_dur > 0.0 and Audio.has_method("is_voice_playing") \
			and bool(Audio.call("is_voice_playing", self))
		if _typing or voiced:
			reveal_all()           # 1º aperto: a fala inteira…
			if voiced:
				_stop_voice(VOICE_CUT)   # …e a voz sai (Guardião §2: fade de 80 ms)
			return
		if _locked:
			return                 # a Encenação segura o avanço
		Audio.play_sfx("ui_advance")
		_stop_voice()
		idx += 1
		_show_line()


## Véu escuro em degradê na base da tela.
class _Veil extends Control:
	func _draw() -> void:
		var top := 200.0
		var pts := PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, size.y), Vector2(0, size.y)])
		draw_polygon(pts, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.0, 0.02, 0.03, 0.55), Color(0.0, 0.02, 0.03, 0.55)]))


## Retrato em medalhão (o "continuar" está em _Cont).
class _Deco extends Control:
	var box
	func _draw() -> void:
		var c: Vector2 = box.portrait_center()
		var r: float = PORTRAIT_R
		if box._portrait != null:
			draw_circle(c + Vector2(0, 1.5), r + 4.0, Color(0, 0, 0, 0.45))
			draw_circle(c, r + 2.5, CodexStyle.INK_DEEP)
			draw_texture_rect(box._portrait, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			draw_arc(c, r + 0.8, 0.0, TAU, 56, CodexStyle.GOLD, 1.6, true)
			draw_arc(c, r + 2.8, 0.0, TAU, 56, Color(CodexStyle.GOLD_LO, 0.9), 0.6, true)
			draw_arc(c, r - 1.0, 0.0, TAU, 56, Color(CodexStyle.GOLD_HI, 0.3), 0.5, true)
			for k in 4:
				var a := k * PI * 0.5
				CodexStyle.draw_diamond(self, c + Vector2(cos(a), sin(a)) * (r + 2.8), 2.0, CodexStyle.GOLD_HI)


## Rodapé "continuar": losango respirando + botão de avançar no dispositivo em
## uso. Só com a fala completa (some enquanto a Encenação trava o avanço ou o
## cue wait_2s segura). Na caixa: canto de baixo à direita; na rubrica: centrado
## abaixo do texto.
class _Cont extends Control:
	var box
	func _draw() -> void:
		if box._typing or box._in_choices or box._locked or box._waiting():
			return
		var g = DialogueBox.glyphs()
		var font: Font = CodexStyle.display()
		var word := I18n.t("continuar")
		var ww := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		var ih := 10.0
		var iw: float = g.icon_width(ADVANCE_ACTION, ih) if g != null else 0.0
		var bob := sin(box._t * 5.0) * 1.5
		var a: float = 0.8
		if box._narr_on:
			# centrado sob o texto da rubrica
			var cy: float = box._narr_text.position.y + box._narr_text.size.y + 14.0
			var total := ww + (iw + 5.0 if g != null else 0.0) + 12.0
			var x := 320.0 - total * 0.5
			if g != null:
				g.draw_icon(self, Vector2(x + iw * 0.5, cy), ADVANCE_ACTION, ih, null, -1, a)
				x += iw + 5.0
			draw_string(font, Vector2(x, cy + 2.5), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(CodexStyle.MUTED, a))
			CodexStyle.draw_diamond(self, Vector2(x + ww + 8.0, cy + bob), 2.6, CodexStyle.GOLD_HI, Color(0, 0, 0, 0.6))
			return
		var rect: Rect2 = box._rect
		var p := Vector2(rect.end.x - 18.0, rect.end.y - 12.0 + bob)
		CodexStyle.draw_diamond(self, p, 3.4, CodexStyle.GOLD_HI, Color(0, 0, 0, 0.6))
		var wx := rect.end.x - 28.0 - ww
		draw_string(font, Vector2(wx, rect.end.y - 9.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(CodexStyle.MUTED, a))
		if g != null:
			g.draw_icon(self, Vector2(wx - 4.0 - iw * 0.5, rect.end.y - 11.5), ADVANCE_ACTION, ih, null, -1, a)


## Véu da rubrica: escuro (tela quase preta, abre a cena) ou leve na base
## (a Encenação segue visível por cima do texto).
class _NarrVeil extends Control:
	var dark: bool = false
	func _draw() -> void:
		if dark:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.006, 0.01, NARR_DARK_A))
			return
		var top := 210.0
		var mid := 268.0
		var c0 := Color(0.0, 0.01, 0.015, 0.0)
		var c1 := Color(0.0, 0.01, 0.015, 0.62)
		draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, mid), Vector2(0, mid)]),
			PackedColorArray([c0, c0, c1, c1]))
		draw_rect(Rect2(0, mid, size.x, size.y - mid), c1)
