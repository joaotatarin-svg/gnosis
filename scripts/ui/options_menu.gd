extends Control
## Opções: volumes (Geral/SFX/Música). Sliders montados por código. Salva ao mexer.

func _ready() -> void:
	CodexStyle.apply_existing(self, true)
	var center := $Center
	var vbox := $Center/VBox
	_slider(vbox, "Volume geral", "Master", Audio.master_vol)
	_slider(vbox, "Efeitos (SFX)", "SFX", Audio.sfx_vol)
	_slider(vbox, "Música", "Music", Audio.music_vol)
	$Center/VBox/Back.pressed.connect(func(): SceneManager.change_scene("res://scenes/ui/MainMenu.tscn"))


func _slider(parent: Node, label_text: String, bus: String, value: float) -> void:
	var row := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(240, 0)
	s.value_changed.connect(func(v):
		Audio.set_volume(bus, v)
		Audio.play_sfx("ui")
		SaveManager.save_game())
	row.add_child(s)
	parent.add_child(row)
	parent.move_child(row, parent.get_child_count() - 2)   # antes do botão Voltar
