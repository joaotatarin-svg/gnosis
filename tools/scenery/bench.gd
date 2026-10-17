extends Node
## FERRAMENTA (não faz parte do jogo): mede o custo do CENÁRIO numa tela do run.
## Abre a tela com vsync desligado e FPS livre, pula diálogos e mede a média
## de tempo de quadro entre os quadros 120 e 720 (inimigos rodando normalmente).
## Uso: godot --path . res://tools/scenery/Bench.tscn -- <tela>

var screen: int = 3
var _n: int = 0
var _acc: float = 0.0
var _worst: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		screen = int(args[0])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	SaveManager.persist_enabled = false
	GameManager.selected_character = GameContent.characters[0]
	Progression.reset_run()
	RunManager.begin()
	Narrative.once("prologue")
	Gnosis.persist_enabled = false
	RunManager.current_screen = screen
	GameManager.current_screen = screen
	var root := get_tree().root
	get_parent().remove_child.call_deferred(self)
	root.add_child.call_deferred(self)
	get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")


func _process(delta: float) -> void:
	for c in get_tree().root.get_children():
		if c is DialogueBox:
			if c.choices.size() > 0:
				c._on_choice(0)
			else:
				c._finish()
			return
	_n += 1
	if _n > 120 and _n <= 720:
		_acc += delta
		_worst = maxf(_worst, delta)
	if _n == 721:
		print("BENCH tela=%d quadro_medio=%.3f ms fps_medio=%.0f pior=%.2f ms nos=%d" % [screen, _acc / 600.0 * 1000.0, 600.0 / _acc, _worst * 1000.0, get_tree().get_node_count()])
		get_tree().quit()
