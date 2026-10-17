extends CanvasLayer
class_name DialogueBox
## Caixa de diálogo do jogo. Pausa o mundo (PauseStack), mostra falas com
## MÁQUINA DE ESCREVER (1º aperto mostra a fala inteira, 2º avança) e,
## opcionalmente, termina numa escolha com botões. Moldura do Códex, placa com
## o nome do falante e retrato pintado quando houver (assets/ui/portraits/).
##
## API (para Level, Encenação e ferramentas):
##   var d := DialogueBox.play([{speaker, text, cue?}, ...], ["Op A", {text, enabled, hint}])
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


static func play(p_lines: Array, p_choices: Array = []) -> DialogueBox:
	var d: DialogueBox = DialogueBox.new()
	d.lines = p_lines
	d.choices = p_choices
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.call_deferred("add_child", d)
	return d


## Retrato pintado do falante (null = sem retrato: A Voz, Estelas, desconhecidos).
static func portrait_for(speaker: String) -> Texture2D:
	var s := speaker.to_lower()
	var id := ""
	for k in ["sophia", "athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel", "soter", "velkar"]:
		if s.contains(k):
			id = k
			break
	if id == "" and (s.contains("rei") or s.contains("yaldabaoth")):
		id = "rei"
	if id == "":
		return null
	var path := "res://assets/ui/portraits/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


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

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = CodexStyle.theme()
	add_child(_root)

	# Véu leve na base (o texto assenta sobre o cenário).
	var veil := _Veil.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(veil)

	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", CodexStyle.panel_frame(0.95))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	_deco = _Deco.new()
	_deco.box = self
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_deco)

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
	_root.add_child(_plate)
	_speaker = Label.new()
	_speaker.add_theme_font_override("font", CodexStyle.display())
	_speaker.add_theme_font_size_override("font_size", 10)
	_speaker.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	_speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_root.add_child(_text)

	_choice_box = HBoxContainer.new()
	_choice_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_box.add_theme_constant_override("separation", int(CHOICE_SEP))
	_choice_box.visible = false
	_root.add_child(_choice_box)

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
	_root.add_child(_reason)

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
	_portrait = portrait_for(who)
	_blip = blip_for(who)
	_speaker.text = who
	_plate.visible = who != ""
	_text.text = String(l.get("text", ""))
	_text.visible_characters = 0
	_shown = 0.0
	_pause = 0.0
	_blip_count = 0
	_typing = true
	# A última fala antes das escolhas já usa a caixa alta (sem pulo depois).
	_set_tall(not choices.is_empty() and idx >= lines.size() - 1)
	_place()
	_deco.queue_redraw()
	if String(l.get("cue", "")) == WAIT_CUE:
		_wait_until = _clock + WAIT_SECONDS
	# No INÍCIO da fala (antes da 1ª letra): a Encenação reage ao `cue` já aqui.
	line_shown.emit(idx, l)


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


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	# Relógio da caixa: delta (sem câmera lenta), não o relógio de parede.
	_clock += delta / maxf(0.01, Engine.time_scale)
	_t += delta
	_deco.queue_redraw()
	if not _typing:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var total := _text.get_total_character_count()
	var before := int(_shown)
	_shown += delta * CPS
	var now := mini(int(_shown), total)
	var txt := _text.text
	for i in range(before, now):
		var ch := txt[i] if i < txt.length() else ""
		if ch != " " and ch != "\n":
			_blip_count += 1
			if _blip_count % 2 == 1:
				_play_blip()
		# respiro na pontuação
		if ch in [".", "!", "?", "…"]:
			_pause = 0.2
			_shown = float(i + 1)
			now = i + 1
			break
		elif ch in [",", ";", ":", "—"]:
			_pause = 0.08
			_shown = float(i + 1)
			now = i + 1
			break
	_text.visible_characters = now
	if now >= total:
		_typing = false
		_text.visible_characters = -1


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
				reasons.append(_reason_text(btn.text, String(c.hint)))
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
	_release_pause()
	finished.emit()
	queue_free()


func _release_pause() -> void:
	if _paused_world:
		_paused_world = false
		PauseStack.pop(self)


## Caixa apagada sem passar por _finish (troca de cena): não segura a pausa.
func _exit_tree() -> void:
	_release_pause()


func _input(event: InputEvent) -> void:
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
		if _typing:
			reveal_all()           # 1º aperto: a fala inteira
			return
		if _locked:
			return                 # a Encenação segura o avanço
		Audio.play_sfx("ui_advance")
		idx += 1
		_show_line()


## Véu escuro em degradê na base da tela.
class _Veil extends Control:
	func _draw() -> void:
		var top := 200.0
		var pts := PackedVector2Array([Vector2(0, top), Vector2(size.x, top), Vector2(size.x, size.y), Vector2(0, size.y)])
		draw_polygon(pts, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.0, 0.02, 0.03, 0.55), Color(0.0, 0.02, 0.03, 0.55)]))


## Retrato em medalhão + indicador de "continuar" (losango que respira).
class _Deco extends Control:
	var box
	func _draw() -> void:
		var c: Vector2 = box.portrait_center()
		var r: float = PORTRAIT_R
		var rect: Rect2 = box._rect
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
		# "continuar": losango respirando no canto, só com a fala completa
		# (some enquanto a Encenação trava o avanço ou o cue wait_2s segura)
		if not box._typing and not box._in_choices and not box._locked and not box._waiting():
			var p := Vector2(rect.end.x - 18.0, rect.end.y - 12.0 + sin(box._t * 5.0) * 1.5)
			CodexStyle.draw_diamond(self, p, 3.4, CodexStyle.GOLD_HI, Color(0, 0, 0, 0.6))
			draw_string(CodexStyle.display(), Vector2(rect.end.x - 140.0, rect.end.y - 9.0), "continuar", HORIZONTAL_ALIGNMENT_RIGHT, 112.0, 7, Color(CodexStyle.MUTED, 0.8))
