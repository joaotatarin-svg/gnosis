extends Control
## Opções (tela cheia ou overlay da pausa). Duas colunas (#34):
##   VÍDEO     — modo de janela (janela · tela cheia · sem bordas) · VSync ·
##               tremor de câmera (0–100%) · reduzir flashes
##   ÁUDIO     — volumes Geral / Efeitos / Música / Vozes (dublagem; 0 = desligadas)
##   JOGO      — velocidade do texto (0,5× · 1× · 2× · instantâneo) · legendas
##               (P/M/G, com amostra) · números de dano · vibração do controle
##   CONTROLES — "Teclas e botões" abre a tela de remapeamento (ControlsMenu)
##   IDIOMA    — (i18n, Onda 4) linha "Idioma · Language" no topo de JOGO:
##               Português ↔ English → `settings["locale"]` (ver scripts/i18n/i18n.gd)
## Tudo vai para `GameManager.settings` (ou Audio) e é salvo na hora pelo
## SaveManager; `GameManager.apply_settings()` reaplica vídeo no boot.
## Tremor, vibração e "Reduzir flashes" (padrão desligada) também são gravados
## direto em `Juice.shake_mult` / `rumble_enabled` / `reduce_flashes` quando
## esses campos existirem. Gravar é sempre `SaveManager.save_game()` (REVISAO
## #13: o SaveManager grava as opções inclusive na Provação).
## Navegável por teclado/controle: botões alternam com Enter/A, sliders com ←/→.
## Cada linha mostra o NOME à esquerda e o VALOR em ouro à direita.

signal closed

## true = aberto por cima do jogo (pausa): "Voltar" só fecha este overlay.
var overlay: bool = false

const CAPTION_NAMES := ["Pequena", "Média", "Grande"]
const COL_W := 236.0
const ROW_H := 22.0
## Modo de janela (`settings["window_mode"]`, contrato do Técnico):
## 0 janela · 1 tela cheia exclusiva · 2 tela cheia sem borda.
const WINDOW_NAMES := ["Janela", "Tela cheia", "Sem bordas"]
## Velocidade do texto (`settings["text_speed"]`): 0.0 = instantâneo.
const TEXT_SPEEDS := [0.5, 1.0, 2.0, 0.0]
const TEXT_SPEED_NAMES := ["0,5×", "1×", "2×", "Instantâneo"]

var _left: VBoxContainer
var _right: VBoxContainer
var _window: Button
var _text_speed: Button
var _controls: Button
var _controls_open: bool = false
var _vsync: Button
var _rumble: Button
var _caption: Button
var _lang: Button
var _first: Control
var _sample: Label


func _ready() -> void:
	CodexStyle.apply_existing(self, not overlay)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if overlay:
		$Bg.color = Color(CodexStyle.INK, 0.92)
	_left = $Center/VBox/Cols/Left
	_right = $Center/VBox/Cols/Right
	_left.custom_minimum_size.x = COL_W
	_right.custom_minimum_size.x = COL_W
	$Center/VBox/Cols.add_theme_constant_override("separation", 30)
	var title: Label = $Center/VBox/Title
	title.add_theme_font_size_override("font_size", 20)
	$Center/VBox.add_theme_constant_override("separation", 7)
	_left.add_theme_constant_override("separation", 4)
	_right.add_theme_constant_override("separation", 4)
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.85)
	$Center/VBox.add_child(rule)
	$Center/VBox.move_child(rule, 1)
	# --- coluna esquerda: vídeo + áudio ---
	_section(_left, "Vídeo")
	_window = _row_button(_left, "Modo de janela")
	_window.pressed.connect(_cycle_window)
	_refresh_window()
	_first = _window
	_vsync = _toggle(_left, "VSync", "vsync")
	_slider(_left, "Tremor de câmera", 0.0, 1.0, float(GameManager.settings.get("shake", 1.0)), func(v: float):
		GameManager.settings["shake"] = v
		_push_juice(), func(v: float): return "%d%%" % int(round(v * 100.0)))
	_toggle(_left, "Reduzir flashes", "reduce_flashes")
	_section(_left, "Áudio", true)
	_slider(_left, "Volume geral", 0.0, 1.0, Audio.master_vol, func(v: float): Audio.set_volume("Master", v))
	_slider(_left, "Efeitos", 0.0, 1.0, Audio.sfx_vol, func(v: float): Audio.set_volume("SFX", v))
	_slider(_left, "Música", 0.0, 1.0, Audio.music_vol, func(v: float): Audio.set_volume("Music", v))
	# Dublagem (Onda 7 — linha do Áudio por delegação do chefe): 0 = sem vozes
	# gravadas (as falas voltam ao "gromelô" de blips).
	_slider(_left, "Vozes", 0.0, 1.0, Audio.voice_vol, func(v: float): Audio.set_volume("Voice", v),
		func(v: float): return "Desligadas" if v <= 0.001 else "%d%%" % int(round(v * 100.0)))
	# --- coluna direita: jogo + controles ---
	_section(_right, "Jogo")
	# Idioma: rótulo nos DOIS idiomas (quem caiu no idioma errado acha a opção).
	_lang = _row_button(_right, "Idioma · Language")
	_lang.pressed.connect(_cycle_language)
	_refresh_language()
	_text_speed = _row_button(_right, "Velocidade do texto")
	_text_speed.pressed.connect(_cycle_text_speed)
	_refresh_text_speed()
	_caption = _row_button(_right, "Legendas")
	_caption.pressed.connect(_cycle_caption)
	# Amostra viva do tamanho da legenda (muda junto com a opção).
	_sample = Label.new()
	_sample.text = "“Lembre-se do que arde.”"
	_sample.add_theme_font_override("font", CodexStyle.italic())
	_sample.add_theme_color_override("font_color", Color(CodexStyle.PAPER, 0.85))
	_sample.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sample.custom_minimum_size = Vector2(COL_W, 26)
	_sample.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_right.add_child(_sample)
	_refresh_caption()
	_toggle(_right, "Números de dano", "damage_numbers", true)
	_rumble = _toggle(_right, "Vibração do controle", "rumble")
	_section(_right, "Controles", true)
	_controls = _row_button(_right, "Teclas e botões")
	(_controls.get_node("Value") as Label).text = "›"
	_controls.pressed.connect(_open_controls)
	var back: Button = $Center/VBox/Back
	back.pressed.connect(_back)
	back.custom_minimum_size.y = CodexStyle.BTN_H
	_first.grab_focus()
	CodexStyle.stagger_in([$Center/VBox], 0.0, 0.0)
	if overlay:
		Audio.play_sfx("ui_open")


func _section(parent: Node, text: String, gap: bool = false) -> void:
	if gap:
		var sp := Control.new()
		sp.custom_minimum_size.y = 4
		parent.add_child(sp)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", CodexStyle.display())
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", CodexStyle.GOLD)
	parent.add_child(l)


## Botão-linha: nome à esquerda + valor (Label) alinhado à direita.
func _row_button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.set_meta("label", text)
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(COL_W, ROW_H)
	b.add_theme_font_size_override("font_size", 10)
	var v := Label.new()
	v.name = "Value"
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_right = -12
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", CodexStyle.body_bold())
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	CodexStyle._wire(b, "")
	parent.add_child(b)
	return b


## Botão que alterna um bool de GameManager.settings ("VSync ...... Ligada").
## `default` = valor quando a chave ainda não existe nas opções.
func _toggle(parent: Node, text: String, key: String, default: bool = false) -> Button:
	var b := _row_button(parent, text)
	b.set_meta("key", key)
	b.set_meta("default", default)
	b.pressed.connect(func():
		GameManager.settings[key] = not bool(GameManager.settings.get(key, default))
		_refresh_toggle(b)
		_push_juice()
		_apply_and_save())
	_refresh_toggle(b)
	return b


func _refresh_toggle(b: Button) -> void:
	var on := bool(GameManager.settings.get(b.get_meta("key"), b.get_meta("default", false)))
	var v: Label = b.get_node("Value")
	v.text = "Ligada" if on else "Desligada"
	v.add_theme_color_override("font_color", CodexStyle.GOLD_HI if on else CodexStyle.MUTED)


## Modo de janela: janela → tela cheia → sem bordas. Pelo `set_window_mode` do
## Técnico quando existir (mantém `fullscreen` coerente); senão, o bool antigo.
func _cycle_window() -> void:
	var m := (_window_mode() + 1) % 3
	if GameManager.has_method("set_window_mode"):
		GameManager.call("set_window_mode", m)
	else:
		GameManager.settings["window_mode"] = m
		GameManager.settings["fullscreen"] = m != 0
	_refresh_window()
	_apply_and_save()


func _window_mode() -> int:
	if GameManager.settings.has("window_mode"):
		return clampi(int(GameManager.settings["window_mode"]), 0, 2)
	return 2 if bool(GameManager.settings.get("fullscreen", false)) else 0


func _refresh_window() -> void:
	(_window.get_node("Value") as Label).text = WINDOW_NAMES[_window_mode()]


func _cycle_text_speed() -> void:
	GameManager.settings["text_speed"] = TEXT_SPEEDS[(_text_speed_index() + 1) % TEXT_SPEEDS.size()]
	_refresh_text_speed()
	_apply_and_save()


func _text_speed_index() -> int:
	var v := float(GameManager.settings.get("text_speed", 1.0))
	var best := 1
	for i in TEXT_SPEEDS.size():
		if absf(float(TEXT_SPEEDS[i]) - v) < absf(float(TEXT_SPEEDS[best]) - v):
			best = i
	return best


func _refresh_text_speed() -> void:
	(_text_speed.get_node("Value") as Label).text = TEXT_SPEED_NAMES[_text_speed_index()]


func _open_controls() -> void:
	_controls_open = true
	var m := ControlsMenu.open(self)
	m.closed.connect(func():
		_controls_open = false
		_controls.grab_focus())


## Português ↔ English. Grava o código escolhido (deixa de seguir o sistema).
## Os rótulos com texto literal trocam na hora (o Godot avisa a árvore toda).
func _cycle_language() -> void:
	var nxt := I18n.EN if I18n.current() == I18n.PT else I18n.PT
	GameManager.settings["locale"] = nxt
	_apply_and_save()
	_refresh_language()


func _refresh_language() -> void:
	(_lang.get_node("Value") as Label).text = I18n.name_of(I18n.current())


func _cycle_caption() -> void:
	GameManager.settings["caption_size"] = (int(GameManager.settings.get("caption_size", 1)) + 1) % 3
	_refresh_caption()
	_apply_and_save()


func _refresh_caption() -> void:
	var v: Label = _caption.get_node("Value")
	v.text = CAPTION_NAMES[clampi(int(GameManager.settings.get("caption_size", 1)), 0, 2)]
	if _sample != null:
		_sample.add_theme_font_size_override("font_size", GameManager.caption_font_size() + 1)


## Slider com rótulo (nome · valor) que acende em ouro quando tem o foco.
func _slider(parent: Node, label_text: String, lo: float, hi: float, value: float, on_change: Callable, fmt: Callable = Callable()) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var head := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", CodexStyle.display())
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)
	var val := Label.new()
	val.add_theme_font_override("font", CodexStyle.body_bold())
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", CodexStyle.GOLD_HI)
	head.add_child(val)
	row.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(COL_W, 14)
	var show := func(v: float):
		val.text = str(fmt.call(v)) if fmt.is_valid() else "%d%%" % int(round(v * 100.0))
	show.call(value)
	s.value_changed.connect(func(v: float):
		on_change.call(v)
		show.call(v)
		_apply_and_save())
	s.focus_entered.connect(func(): lbl.add_theme_color_override("font_color", CodexStyle.GOLD_HI))
	s.focus_exited.connect(func(): lbl.add_theme_color_override("font_color", CodexStyle.PAPER))
	row.add_child(s)
	parent.add_child(row)


## Espelha tremor/vibração/flashes no Juice quando ele tiver os campos.
func _push_juice() -> void:
	if "shake_mult" in Juice:
		Juice.set("shake_mult", GameManager.shake_multiplier())
	if "rumble_enabled" in Juice:
		Juice.set("rumble_enabled", GameManager.rumble_enabled())
	if "reduce_flashes" in Juice:
		Juice.set("reduce_flashes", bool(GameManager.settings.get("reduce_flashes", false)))


func _apply_and_save() -> void:
	Audio.play_sfx("ui_confirm")
	GameManager.apply_settings()
	_push_juice()                      # apply_settings pode não conhecer as chaves novas
	# O SaveManager decide o que grava (o Técnico garante que as opções sempre
	# gravam, inclusive na Provação — REVISAO #13; gravação atômica com .bak).
	SaveManager.save_game()


func _back() -> void:
	if overlay:
		closed.emit()
		queue_free()
	else:
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if _controls_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_back()
