extends Control
## Opções (tela cheia ou overlay da pausa). Duas colunas:
##   VÍDEO & JOGO — tela cheia · VSync · tremor de câmera (0–100%) · vibração ·
##                  tamanho da legenda (P/M/G)
##   ÁUDIO        — volumes Geral / Efeitos / Música
## Tudo vai pra `GameManager.settings` (ou Audio) e é salvo na hora pelo
## SaveManager; `GameManager.apply_settings()` reaplica vídeo no boot.
## Tremor e vibração também são gravados direto em `Juice.shake_mult` /
## `Juice.rumble_enabled` quando esses campos existirem (branch principal).
## Navegável por teclado/controle: botões alternam com Enter/A, sliders com ←/→.

signal closed

## true = aberto por cima do jogo (pausa): "Voltar" só fecha este overlay.
var overlay: bool = false

const CAPTION_NAMES := ["Pequena", "Média", "Grande"]

var _left: VBoxContainer
var _right: VBoxContainer
var _fullscreen: Button
var _vsync: Button
var _rumble: Button
var _caption: Button
var _first: Control


func _ready() -> void:
	CodexStyle.apply_existing(self, not overlay)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if overlay:
		$Bg.color = Color(CodexStyle.INK, 0.9)
	_left = $Center/VBox/Cols/Left
	_right = $Center/VBox/Cols/Right
	_left.custom_minimum_size.x = 250
	_right.custom_minimum_size.x = 230
	_section(_left, "VÍDEO & JOGO")
	_fullscreen = _toggle(_left, "Tela cheia", "fullscreen")
	_first = _fullscreen
	_vsync = _toggle(_left, "VSync", "vsync")
	_slider(_left, "Tremor de câmera", 0.0, 1.0, float(GameManager.settings.get("shake", 1.0)), func(v: float):
		GameManager.settings["shake"] = v
		_push_juice(), func(v: float): return "%d%%" % int(round(v * 100.0)))
	_rumble = _toggle(_left, "Vibração do controle", "rumble")
	_caption = Button.new()
	_caption.pressed.connect(_cycle_caption)
	_left.add_child(_caption)
	_refresh_caption()
	_section(_right, "ÁUDIO")
	_slider(_right, "Volume geral", 0.0, 1.0, Audio.master_vol, func(v: float): Audio.set_volume("Master", v))
	_slider(_right, "Efeitos (SFX)", 0.0, 1.0, Audio.sfx_vol, func(v: float): Audio.set_volume("SFX", v))
	_slider(_right, "Música", 0.0, 1.0, Audio.music_vol, func(v: float): Audio.set_volume("Music", v))
	var back: Button = $Center/VBox/Back
	back.pressed.connect(_back)
	_first.grab_focus()


func _section(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", CodexStyle.GOLD)
	parent.add_child(l)


## Botão que alterna um bool de GameManager.settings ("Tela cheia: Ligada").
func _toggle(parent: Node, text: String, key: String) -> Button:
	var b := Button.new()
	b.set_meta("label", text)
	b.set_meta("key", key)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		GameManager.settings[key] = not bool(GameManager.settings.get(key, false))
		_refresh_toggle(b)
		_push_juice()
		_apply_and_save())
	parent.add_child(b)
	_refresh_toggle(b)
	return b


func _refresh_toggle(b: Button) -> void:
	var on := bool(GameManager.settings.get(b.get_meta("key"), false))
	b.text = "%s:   %s" % [b.get_meta("label"), "Ligada" if on else "Desligada"]


func _cycle_caption() -> void:
	GameManager.settings["caption_size"] = (int(GameManager.settings.get("caption_size", 1)) + 1) % 3
	_refresh_caption()
	_apply_and_save()


func _refresh_caption() -> void:
	_caption.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_caption.text = "Legendas:   %s" % CAPTION_NAMES[clampi(int(GameManager.settings.get("caption_size", 1)), 0, 2)]


## Slider com rótulo que mostra o valor e fica dourado quando tem o foco.
func _slider(parent: Node, label_text: String, lo: float, hi: float, value: float, on_change: Callable, fmt: Callable = Callable()) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(220, 14)
	var show := func(v: float):
		var txt: String = str(fmt.call(v)) if fmt.is_valid() else "%d%%" % int(round(v * 100.0))
		lbl.text = "%s   %s" % [label_text, txt]
	show.call(value)
	s.value_changed.connect(func(v: float):
		on_change.call(v)
		show.call(v)
		_apply_and_save())
	s.focus_entered.connect(func(): lbl.add_theme_color_override("font_color", CodexStyle.GOLD))
	s.focus_exited.connect(func(): lbl.add_theme_color_override("font_color", CodexStyle.PAPER))
	row.add_child(s)
	parent.add_child(row)


## Espelha tremor/vibração no Juice quando ele tiver os campos (branch principal).
func _push_juice() -> void:
	if "shake_mult" in Juice:
		Juice.set("shake_mult", GameManager.shake_multiplier())
	if "rumble_enabled" in Juice:
		Juice.set("rumble_enabled", GameManager.rumble_enabled())


func _apply_and_save() -> void:
	Audio.play_sfx("ui")
	GameManager.apply_settings()
	SaveManager.save_game()


func _back() -> void:
	Audio.play_sfx("ui_back")
	if overlay:
		closed.emit()
		queue_free()
	else:
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_back()
