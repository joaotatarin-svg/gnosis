extends CanvasLayer
class_name Cinematic
## Cinemática leve, toda por código: cards de texto sobre a pintura do Éon
## (prólogo, epílogo) e o CARD DE CHEFE com letterbox. Pausa o mundo enquanto
## toca (process ALWAYS) pela pilha de pausa (PauseStack): ao terminar, larga só
## a SUA pausa — se um diálogo ou a loja ainda seguram o mundo, ele continua parado.
## Uso:  await Cinematic.prologue().finished
##       Cinematic.boss_card("ATHOTH", "Arconte do Torpor")
##       await Cinematic.epilogue("semente", 7, 18).finished
## Qualquer tecla/botão avança o card; Esc (pause) pula tudo.

signal finished

const TEXT_W := 470.0

var cards: Array = []              # [{title, text, bg, time}]
var boss: Dictionary = {}          # {name, title} → modo card de chefe
var _idx: int = -1
var _done: bool = false
var _advance: bool = false
var _skip_all: bool = false
var _black: ColorRect
var _bg: TextureRect
var _title: Label
var _text: Label
var _hint: Label
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _boss_name: Label
var _boss_title: Label


## Fonte de TÍTULO: `CodexStyle.display()` (Cinzel) quando a UI nova estiver
## presente; senão, a serifada de corpo. Procurada pelo nome para este arquivo
## compilar com e sem a UI nova (o corpo continua em `CodexStyle.serif()`).
static func title_font() -> Font:
	var s: Script = load("res://scripts/ui/codex_style.gd")
	if s != null:
		for m in s.get_script_method_list():
			if String(m.get("name", "")) == "display":
				return s.call("display")
	return CodexStyle.serif()


static func _spawn() -> Cinematic:
	var c := Cinematic.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.call_deferred("add_child", c)
	return c


## O mito em 6 cards (Mônada → Éons → Sophia → o Cego → Kenoma → faíscas). O último
## card NÃO diz "acorda": quem diz é a Voz, na primeira fala do jogo (Narrative.intro).
static func prologue() -> Cinematic:
	var c := _spawn()
	c.cards = [
		{"title": "", "text": "No princípio não havia princípio.\nHavia o Um — sem nome, sem medida, pleno.\nOs antigos o chamaram Mônada, Abismo, Silêncio.", "bg": 8, "time": 5.0},
		{"title": "", "text": "Dele emanaram os Éons, aos pares, como luz que transborda.\nNo Pleroma nada dormia. Nada esquecia.", "bg": 3, "time": 4.6},
		{"title": "", "text": "A mais jovem, Sophia — a Sabedoria —, quis alcançar a Fonte sozinha.\nDo desejo sem par nasceu um filho sem forma,\ne ela o escondeu numa nuvem.", "bg": 4, "time": 5.2},
		{"title": "", "text": "Cego para a Luz de onde veio, ele se acreditou o único deus.\nE fez um mundo copiando o que nunca viu: o Kenoma, o vazio.", "bg": 6, "time": 5.0},
		{"title": "", "text": "Sete Arcontes. Sete esferas. Sete correntes.\nE dentro do barro, escondida, a faísca que ele levou da mãe.", "bg": 2, "time": 5.0},
		{"title": "", "text": "As faíscas dormem.\n\nUma delas acaba de sentir dor.", "bg": 0, "time": 4.4},
	]
	return c


## Letterbox + nome grande + título; congela ~1,8 s.
static func boss_card(p_name: String, p_title: String) -> Cinematic:
	var c := _spawn()
	c.boss = {"name": p_name, "title": p_title}
	return c


## Cards do final escolhido + "Crônicas: N/18" + créditos curtos.
static func epilogue(ending: String, chron_n: int, chron_total: int) -> Cinematic:
	var c := _spawn()
	var bg := 8
	match ending:
		"ascensao": bg = 3
		"ruptura": bg = 6
		"semente": bg = 0
	c.cards.append({"title": GameManager.end_title, "text": GameManager.end_subtitle, "bg": bg, "time": 6.0})
	for t in Narrative.epilogue_cards(ending):
		c.cards.append({"title": "", "text": String(t), "bg": bg, "time": 5.4})
	var chron_line := "Todas as pedras foram lidas. A faísca lembra por inteiro." if chron_n >= chron_total \
		else "Ficaram %d Estelas por ler no Kenoma. As Crônicas guardam as que foram lidas." % (chron_total - chron_n)
	c.cards.append({"title": "CRÔNICAS  %d / %d" % [chron_n, chron_total], "text": chron_line, "bg": 7, "time": 5.0})
	c.cards.append({"title": "GNOSIS", "text": "João Tatarin — direção, produção e escolhas\nArte ilustrada gerada por IA sob direção do autor\nCódigo escrito com Claude (Anthropic) e Codex (OpenAI)\nSons e efeitos CC0/CC-BY — ver assets/LICENSES.md\n\nInspirado nos textos de Nag Hammadi, na Pistis Sophia\ne nos relatos de Irineu, Hipólito e Clemente.", "bg": 8, "time": 7.0})
	# Depois dos créditos, em qualquer final: tela preta e só isto (bg -1 = sem
	# pintura). Não contradiz nenhum final e abre a porta do Jogo 2.
	c.cards.append({"title": "", "text": "...mãe?", "bg": -1, "time": 2.6})
	return c


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	PauseStack.push(self)
	if not boss.is_empty():
		_build_boss()
		_run_boss()
	else:
		_build_cards()
		_run_cards()


# --- cards ------------------------------------------------------------------

func _build_cards() -> void:
	_black = ColorRect.new()
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	_bg = TextureRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.material = PaintedLibrary.material()
	_bg.modulate = Color(0.42, 0.44, 0.48, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# vinheta: escurece as bordas para o texto assentar
	var vig := ColorRect.new()
	vig.color = Color(0.0, 0.01, 0.02, 0.38)
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	_title = Label.new()
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.anchor_top = 0.5
	_title.anchor_bottom = 0.5
	_title.offset_left = -TEXT_W * 0.5
	_title.offset_right = TEXT_W * 0.5
	_title.offset_top = -92.0
	_title.offset_bottom = -58.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", CodexStyle.GOLD)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 5)
	_title.add_theme_font_override("font", Cinematic.title_font())
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_text = Label.new()
	_text.anchor_left = 0.5
	_text.anchor_right = 0.5
	_text.anchor_top = 0.5
	_text.anchor_bottom = 0.5
	_text.offset_left = -TEXT_W * 0.5
	_text.offset_right = TEXT_W * 0.5
	_text.offset_top = -52.0
	_text.offset_bottom = 70.0
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", CodexStyle.PAPER)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_constant_override("line_spacing", 3)
	_text.add_theme_font_override("font", CodexStyle.serif())
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)

	_hint = Label.new()
	_hint.text = "qualquer tecla avança  ·  Esc pula"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -240.0
	_hint.offset_top = -22.0
	_hint.offset_right = -14.0
	_hint.offset_bottom = -8.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 9)
	_hint.add_theme_color_override("font_color", CodexStyle.MUTED)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_set_alpha(0.0)


func _set_alpha(a: float) -> void:
	_bg.modulate.a = a
	_title.modulate.a = a
	_text.modulate.a = a


func _run_cards() -> void:
	for i in cards.size():
		if _skip_all:
			break
		_idx = i
		var card: Dictionary = cards[i]
		_title.text = String(card.get("title", ""))
		_text.text = String(card.get("text", ""))
		var bg_i: int = int(card.get("bg", -1))
		_bg.texture = PaintedLibrary.background(bg_i) if bg_i >= 0 else null
		_advance = false
		await _fade(1.0, 0.55)
		await _hold(float(card.get("time", 5.0)))
		await _fade(0.0, 0.35)
	_finish()


## Espera `t` segundos reais ou até o jogador avançar.
func _hold(t: float) -> void:
	var left := t
	while left > 0.0 and not _advance and not _skip_all:
		var dt: float = get_process_delta_time()
		left -= dt
		await get_tree().process_frame


func _fade(to: float, dur: float) -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_alpha, _bg.modulate.a, to, dur)
	await tw.finished


# --- card de chefe ----------------------------------------------------------

func _build_boss() -> void:
	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 0.0
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.offset_top = 0.0
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_bottom)

	_boss_name = Label.new()
	_boss_name.text = String(boss.get("name", ""))
	_boss_name.anchor_left = 0.5
	_boss_name.anchor_right = 0.5
	_boss_name.anchor_top = 0.5
	_boss_name.anchor_bottom = 0.5
	_boss_name.offset_left = -300.0
	_boss_name.offset_right = 300.0
	_boss_name.offset_top = -74.0
	_boss_name.offset_bottom = -34.0
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_boss_name.add_theme_font_size_override("font_size", 30)
	_boss_name.add_theme_color_override("font_color", CodexStyle.GOLD)
	_boss_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_boss_name.add_theme_constant_override("outline_size", 7)
	_boss_name.add_theme_font_override("font", Cinematic.title_font())
	_boss_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_name.modulate.a = 0.0
	add_child(_boss_name)

	_boss_title = Label.new()
	_boss_title.text = String(boss.get("title", ""))
	_boss_title.anchor_left = 0.5
	_boss_title.anchor_right = 0.5
	_boss_title.anchor_top = 0.5
	_boss_title.anchor_bottom = 0.5
	_boss_title.offset_left = -300.0
	_boss_title.offset_right = 300.0
	_boss_title.offset_top = -32.0
	_boss_title.offset_bottom = -12.0
	_boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_title.add_theme_font_size_override("font_size", 12)
	_boss_title.add_theme_color_override("font_color", CodexStyle.PAPER)
	_boss_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_boss_title.add_theme_constant_override("outline_size", 4)
	_boss_title.add_theme_font_override("font", Cinematic.title_font())
	_boss_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_title.modulate.a = 0.0
	add_child(_boss_title)


func _run_boss() -> void:
	Audio.play_sfx("boss_appear")
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(_bar_top, "offset_bottom", 44.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_bar_bottom, "offset_top", -44.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_boss_name, "modulate:a", 1.0, 0.35)
	tw.tween_property(_boss_title, "modulate:a", 1.0, 0.5).set_delay(0.15)
	_boss_name.scale = Vector2(1.18, 1.18)
	_boss_name.pivot_offset = Vector2(300.0, 40.0)
	tw.tween_property(_boss_name, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.8, true, false, true).timeout
	var out := create_tween()
	out.set_ignore_time_scale(true)
	out.set_parallel(true)
	out.tween_property(_bar_top, "offset_bottom", 0.0, 0.25)
	out.tween_property(_bar_bottom, "offset_top", 0.0, 0.25)
	out.tween_property(_boss_name, "modulate:a", 0.0, 0.22)
	out.tween_property(_boss_title, "modulate:a", 0.0, 0.22)
	await out.finished
	_finish()


# --- comum ------------------------------------------------------------------

func _finish() -> void:
	if _done:
		return
	_done = true
	PauseStack.pop(self)
	finished.emit()
	queue_free()


## Apagado sem passar por _finish (troca de cena): não segura a pausa.
func _exit_tree() -> void:
	if not _done:
		PauseStack.pop(self)


func _unhandled_input(event: InputEvent) -> void:
	if _done or not boss.is_empty():
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("pause"):
		_skip_all = true
	_advance = true
