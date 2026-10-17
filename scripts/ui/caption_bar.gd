extends CanvasLayer
class_name CaptionBar
## Legendas de caminhada: falas curtas (1–2 linhas, 3–5 s) que aparecem na base
## da tela SEM pausar o jogo — a Voz comenta, a Sophia responde a si mesma.
## Fila: uma fala por vez, com fade; `clear()` ao trocar de tela. Vive como
## filho do autoload `Gnosis` (persiste entre cenas). Durante um DialogueBox
## ou a pausa (árvore pausada) a legenda SOME e o relógio dela congela.
## Visual: faixa que se dissolve nas pontas, filetes dourados, nome do falante
## em versalete, retrato pequeno quando houver; o texto entra em máquina de
## escrever com o "blip" de voz do falante (mesmos sons do DialogueBox).
## O tamanho do texto segue as Opções (Legendas P/M/G).
## Lugar (QA-UX M1, Onda 3): no TOPO, logo abaixo da faixa de dicas do HUD
## (y 66 na base 640×360), centrada e mais estreita que antes (420 px) — com o
## zoom 1,2 da câmera a base da tela é chão de luta (pés, telegrafos de chão,
## barra do chefe) e a legenda ficava nas canelas da Sophia. O topo central é
## céu/arquitetura em todas as telas; a faixa é mais discreta (véu α 0,5) e cresce
## para baixo só o que o texto pedir. O HUD sabe onde ela está
## (hud.set_caption_band) para o toast nascer logo abaixo.
## Some (QA-UX A2/L4/M4): árvore pausada ou PauseStack segurando (pausa, loja,
## opções, golpes, diálogo, card de chefe), Sophia morta (a fila é descartada) e
## fora de uma tela do run.
## Luta de chefe (backlog #21): legenda de CHEGADA não fala por cima do chefe.
## Na 1ª vez que uma barra de chefe/Campeão aparece na tela, a fala no ar sai e
## a fila enfileirada ANTES (chegada da tela) é descartada; o que nasce DURANTE a
## luta (fase 2 dos Arcontes, 7º Anel, lembranças dos ecos) passa normalmente.
## Velocidade do texto segue as Opções (DialogueBox.text_speed()).

const SPEAKER_COLOR := Color("ecd498")
const MIN_TIME := 3.0
const MAX_TIME := 5.2
const CPS := 55.0
const TOP_Y := 66.0               # topo da faixa (abaixo das dicas do HUD, y 37–55)
const STRIP_W := 420.0            # largura da faixa (centrada; livre dos Anéis e do combo)
const STRIP_A := 0.5              # véu da faixa (era 0,72 na base: no topo, mais discreta)

var _queue: Array = []            # [{speaker, text}]
var _time_left: float = 0.0       # tempo da fala atual
var _gap: float = 0.0             # respiro entre falas
var _showing: bool = false
var _root: Control
var _strip: _Strip
var _speaker: Label
var _text: Label
var _tween: Tween
var _shown: float = 0.0
var _typing: bool = false
var _blip: String = "blip_npc"
var _blips: int = 0
var _height: float = 48.0
var _fight_armed: bool = true     # a próxima luta de chefe da tela ainda corta a chegada
var _in_fight: bool = false
var _lines_shown: int = 0
const MIN_FS := 11                # menor corpo aceito ao apertar para 1 linha


func _ready() -> void:
	layer = 60                     # acima do HUD (1), abaixo do DialogueBox (90)
	process_mode = Node.PROCESS_MODE_ALWAYS   # só pra se ESCONDER na pausa
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa no topo central (ver _layout).
	_root.position = Vector2(320.0 - STRIP_W * 0.5, TOP_Y)
	_root.size = Vector2(STRIP_W, _height)
	_root.modulate.a = 0.0
	add_child(_root)

	_strip = _Strip.new()
	_strip.bar = self
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_strip)

	_speaker = Label.new()
	_speaker.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_speaker.offset_top = 4.0
	_speaker.offset_bottom = 16.0
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker.add_theme_font_size_override("font_size", 8)
	_speaker.add_theme_color_override("font_color", SPEAKER_COLOR)
	_speaker.add_theme_font_override("font", CodexStyle.display())
	_speaker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_speaker.add_theme_constant_override("outline_size", 3)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # i18n: I18n.t em _show
	_root.add_child(_speaker)

	_text = Label.new()
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 24.0
	_text.offset_right = -24.0
	_text.offset_top = 17.0
	_text.offset_bottom = -3.0
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", CodexStyle.body())
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_constant_override("line_spacing", -1)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED      # i18n: I18n.t em _show
	_root.add_child(_text)


## Enfileira uma fala. `lines` = Array de {speaker, text} (formato do Narrative).
func say_lines(lines: Array) -> void:
	for l in lines:
		if l is Dictionary and String(l.get("text", "")) != "":
			_queue.append(l)


func say(speaker: String, text: String) -> void:
	_queue.append({"speaker": speaker, "text": text})


## Esvazia tudo (troca de tela, morte).
func clear() -> void:
	_fight_armed = true
	_in_fight = false
	_queue.clear()
	_time_left = 0.0
	_gap = 0.0
	if _showing:
		_hide()


func _process(delta: float) -> void:
	# Pausa / diálogo / loja / card: some e congela (a fala não "queima" escondida).
	# Também com CENA no ar sem pausa (Cinemática, rubrica/ilustração da Encenação —
	# HUD.scene_active): a legenda espera e aparece depois (QA2 #4).
	var paused := get_tree().paused or PauseStack.is_held() or _scene_on()
	_root.visible = not paused
	_report_band()
	if paused:
		return
	# Fora de uma tela do run (menu, Crônicas, fim), nada fica pendurado.
	if not (get_tree().current_scene is Level):
		if _showing or not _queue.is_empty():
			clear()
		return
	# Sophia caída: ninguém "fala" com ela morta (L4); a fila não volta depois.
	if _player_dead():
		if _showing or not _queue.is_empty():
			clear()
			_kill_tween()
			_root.modulate.a = 0.0     # sem fade: a morte vem com câmera lenta
		return
	_check_fight()
	_layout(delta)
	if _showing:
		_type(delta)
		_time_left -= delta
		if _time_left <= 0.0:
			_hide()
		return
	if _gap > 0.0:
		_gap -= delta
		return
	if _queue.is_empty():
		return
	_show(_queue.pop_front())


func _type(delta: float) -> void:
	if not _typing:
		return
	var total := _text.get_total_character_count()
	var before := int(_shown)
	var sp := DialogueBox.text_speed()
	_shown = INF if is_inf(sp) else _shown + delta * CPS * sp
	var now := total if is_inf(_shown) else mini(int(_shown), total)
	var txt := _text.text
	for i in range(before, now):
		if is_inf(_shown):
			break                  # instantâneo: sem rajada de blips
		if i < txt.length() and txt[i] != " ":
			_blips += 1
			if _blips % 2 == 1:
				Audio.play_sfx(_blip, -1.0, -6.0)
	_text.visible_characters = now
	if now >= total:
		_typing = false
		_text.visible_characters = -1


func _show(l: Dictionary) -> void:
	_showing = true
	# i18n (Onda 4): exibe traduzido; o falante pt segue como chave de retrato/blip.
	var text := I18n.t(String(l.get("text", "")))
	var who := String(l.get("speaker", ""))
	_speaker.text = I18n.t(who)
	_strip.portrait = DialogueBox.portrait_for(who, String(l.get("mood", "")))
	# Com retrato, o texto abre espaço à esquerda (o medalhão fica dentro da faixa).
	_text.offset_left = 62.0 if _strip.portrait != null else 24.0
	_blip = DialogueBox.blip_for(who)
	# Hierarquia do topo (QA2 #10): a legenda usa o tamanho das Opções SEM o +1 de
	# antes (13 px no M — o mesmo corpo da caixa de diálogo, legível em 640×360) e,
	# se o texto passa de 1 linha por pouco, desce 1 px para caber numa linha só.
	var fs := GameManager.caption_font_size()
	var lw := STRIP_W - (62.0 if _strip.portrait != null else 24.0) - 24.0
	var font: Font = CodexStyle.body()
	var nlines := _lines_for(font, text, lw, fs)
	if nlines == 2 and fs - 1 >= MIN_FS and _lines_for(font, text, lw, fs - 1) == 1:
		fs -= 1
		nlines = 1
	_text.add_theme_font_size_override("font_size", fs)
	# Altura pelo texto de verdade (1–3 linhas): a faixa não reserva espaço à toa.
	var line_h := ceilf(float(fs) * 1.15)
	_height = 21.0 + line_h * float(nlines)
	_lines_shown = nlines
	_layout(-1.0)
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_blips = 0
	_typing = true
	_time_left = clampf(MIN_TIME + float(text.length()) * 0.03, MIN_TIME, MAX_TIME) + float(text.length()) / CPS
	Audio.play_sfx("caption")
	_strip.queue_redraw()
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.25)


## Quantas linhas o texto ocupa (1–3) na largura `lw` com a fonte `fs`.
func _lines_for(font: Font, text: String, lw: float, fs: int) -> int:
	var tsz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, lw, fs, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	return clampi(int(ceilf(tsz.y / maxf(1.0, font.get_height(fs)) - 0.01)), 1, 3)


## Cena no ar (Cinemática na raiz, caixa, Encenação dirigindo)? Pergunta ao HUD.
func _scene_on() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.has_method("scene_active") and bool(hud.call("scene_active"))


## Linhas da fala atual (QA/sonda).
func shown_lines() -> int:
	return _lines_shown


## Posição da faixa: topo central, fixa (o chefe não a empurra mais).
## `delta` fica por compatibilidade (antes animava a subida acima da barra).
func _layout(_delta: float) -> void:
	_root.position = Vector2(320.0 - STRIP_W * 0.5, TOP_Y)
	_root.size = Vector2(STRIP_W, _height)


## Avisa o HUD onde a faixa está agora (base em y, ou -1 = sem legenda na tela),
## para o toast não nascer embaixo dela.
func _report_band() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("set_caption_band"):
		return
	var on := _root.visible and _root.modulate.a > 0.05
	hud.call("set_caption_band", (TOP_Y + _height) if on else -1.0)


## Retângulo da faixa (base 640×360) — QA/sonda.
func band_rect() -> Rect2:
	return Rect2(_root.position, _root.size)


## Começou a luta de chefe (1ª barra viva na tela)? Corta a chegada (#21).
func _check_fight() -> void:
	var fight := false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("boss_bars"):
		fight = not (hud.call("boss_bars") as Array).is_empty()
	if fight and not _in_fight and _fight_armed:
		_fight_armed = false
		_queue.clear()
		if _showing:
			_hide()
	_in_fight = fight


## Há luta de chefe com barra viva agora? (QA/sonda)
func in_boss_fight() -> bool:
	return _in_fight


func _player_dead() -> bool:
	var pl := get_tree().get_first_node_in_group("player")
	if pl == null or not ("health" in pl) or pl.get("health") == null:
		return false
	return int(pl.health.current_health) <= 0


func _hide() -> void:
	_showing = false
	_gap = 0.9
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.35)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Faixa: azul-noite que se dissolve nas pontas + filetes dourados + retrato.
class _Strip extends Control:
	var bar
	var portrait: Texture2D
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var steps := 16
		var va: float = STRIP_A
		for i in steps:
			var a := float(i) / steps
			var b := float(i + 1) / steps
			var ka := sin(a * PI)
			var kb := sin(b * PI)
			var x0 := w * a
			var x1 := w * b
			draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]),
				PackedColorArray([Color(0.02, 0.045, 0.06, va * ka), Color(0.02, 0.045, 0.06, va * kb), Color(0.02, 0.045, 0.06, va * kb), Color(0.02, 0.045, 0.06, va * ka)]))
			var g := Color(CodexStyle.GOLD, 0.45)
			draw_line(Vector2(x0, 0), Vector2(x1, 0), Color(g, g.a * ka * ka), 0.6, true)
		CodexStyle.draw_diamond(self, Vector2(w * 0.5, 0), 2.2, CodexStyle.GOLD_HI)
		if portrait != null:
			var c := Vector2(44.0, h * 0.5 + 1.0)
			var r := 12.0
			draw_circle(c, r + 2.0, CodexStyle.INK_DEEP)
			draw_texture_rect(portrait, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false)
			draw_arc(c, r + 0.6, 0.0, TAU, 32, CodexStyle.GOLD, 1.0, true)
