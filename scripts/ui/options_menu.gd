extends Control
## Opções (tela cheia ou overlay da pausa). Duas colunas:
##   VÍDEO & JOGO — tela cheia · VSync · tremor de câmera (0–100%) · vibração ·
##                  reduzir flashes · tamanho da legenda (P/M/G)
##   ÁUDIO        — volumes Geral / Efeitos / Música
## Tudo vai para `GameManager.settings` (ou Audio) e é salvo na hora pelo
## SaveManager; `GameManager.apply_settings()` reaplica vídeo no boot.
## Tremor, vibração e "Reduzir flashes" (padrão desligada) também são gravados
## direto em `Juice.shake_mult` / `rumble_enabled` / `reduce_flashes` quando
## esses campos existirem. Dentro da Provação (save desligado) as OPÇÕES ainda
## são gravadas — só elas (REVISAO #13).
## Navegável por teclado/controle: botões alternam com Enter/A, sliders com ←/→.
## Cada linha mostra o NOME à esquerda e o VALOR em ouro à direita.

signal closed

## true = aberto por cima do jogo (pausa): "Voltar" só fecha este overlay.
var overlay: bool = false

const CAPTION_NAMES := ["Pequena", "Média", "Grande"]
const COL_W := 236.0

var _left: VBoxContainer
var _right: VBoxContainer
var _fullscreen: Button
var _vsync: Button
var _rumble: Button
var _caption: Button
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
	title.add_theme_font_size_override("font_size", 22)
	var rule := CodexStyle.Rule.new()
	rule.custom_minimum_size = Vector2(0, 7)
	rule.color = Color(CodexStyle.GOLD, 0.85)
	$Center/VBox.add_child(rule)
	$Center/VBox.move_child(rule, 1)
	_section(_left, "Vídeo & jogo")
	_fullscreen = _toggle(_left, "Tela cheia", "fullscreen")
	_first = _fullscreen
	_vsync = _toggle(_left, "VSync", "vsync")
	_slider(_left, "Tremor de câmera", 0.0, 1.0, float(GameManager.settings.get("shake", 1.0)), func(v: float):
		GameManager.settings["shake"] = v
		_push_juice(), func(v: float): return "%d%%" % int(round(v * 100.0)))
	_rumble = _toggle(_left, "Vibração do controle", "rumble")
	_toggle(_left, "Reduzir flashes", "reduce_flashes")
	_caption = _row_button(_left, "Legendas")
	_caption.pressed.connect(_cycle_caption)
	_refresh_caption()
	_section(_right, "Áudio")
	_slider(_right, "Volume geral", 0.0, 1.0, Audio.master_vol, func(v: float): Audio.set_volume("Master", v))
	_slider(_right, "Efeitos", 0.0, 1.0, Audio.sfx_vol, func(v: float): Audio.set_volume("SFX", v))
	_slider(_right, "Música", 0.0, 1.0, Audio.music_vol, func(v: float): Audio.set_volume("Music", v))
	# Amostra viva do tamanho da legenda (muda junto com a opção).
	_sample = Label.new()
	_sample.text = "“Lembre-se do que arde.”"
	_sample.add_theme_font_override("font", CodexStyle.italic())
	_sample.add_theme_color_override("font_color", Color(CodexStyle.PAPER, 0.85))
	_sample.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sample.custom_minimum_size = Vector2(COL_W, 34)
	_sample.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_right.add_child(_sample)
	_refresh_caption()
	var back: Button = $Center/VBox/Back
	back.pressed.connect(_back)
	back.custom_minimum_size.y = CodexStyle.BTN_H
	_first.grab_focus()
	CodexStyle.stagger_in([$Center/VBox], 0.0, 0.0)
	if overlay:
		Audio.play_sfx("ui_open")


func _section(parent: Node, text: String) -> void:
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
	b.custom_minimum_size = Vector2(COL_W, CodexStyle.BTN_H)
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


## Botão que alterna um bool de GameManager.settings ("Tela cheia ...... Ligada").
func _toggle(parent: Node, text: String, key: String) -> Button:
	var b := _row_button(parent, text)
	b.set_meta("key", key)
	b.pressed.connect(func():
		GameManager.settings[key] = not bool(GameManager.settings.get(key, false))
		_refresh_toggle(b)
		_push_juice()
		_apply_and_save())
	_refresh_toggle(b)
	return b


func _refresh_toggle(b: Button) -> void:
	var on := bool(GameManager.settings.get(b.get_meta("key"), false))
	var v: Label = b.get_node("Value")
	v.text = "Ligada" if on else "Desligada"
	v.add_theme_color_override("font_color", CodexStyle.GOLD_HI if on else CodexStyle.MUTED)


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
	if SaveManager.persist_enabled:
		SaveManager.save_game()
	elif SaveManager.has_method("save_settings"):
		SaveManager.call("save_settings")
	elif CodexSession.active and CodexSession.previous_persist:
		_save_settings_only()


## Provação: o save do run está desligado (não grava progresso), mas as opções
## do jogador têm de sobreviver. Regrava SÓ volumes e opções no save existente.
## (Ferramentas de QA que já tinham o save desligado não gravam nada.)
func _save_settings_only() -> void:
	var path: String = SaveManager.SAVE_PATH
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf == null:
			return
		var parsed = JSON.parse_string(rf.get_as_text())
		rf.close()
		if typeof(parsed) != TYPE_DICTIONARY:
			return                         # ilegível: não piora o que está lá
		data = parsed
	data["vol_master"] = Audio.master_vol
	data["vol_sfx"] = Audio.sfx_vol
	data["vol_music"] = Audio.music_vol
	data["settings"] = GameManager.settings
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(data))
		wf.close()


func _back() -> void:
	if overlay:
		closed.emit()
		queue_free()
	else:
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Audio.play_sfx("ui_back")
		_back()
