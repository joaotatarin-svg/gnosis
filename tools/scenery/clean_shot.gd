extends Node
## FERRAMENTA (cenário): igual ao tools/Shot.tscn, mas esconde as legendas
## (CaptionBar) e, com "nohud", também o HUD — pra julgar o CENÁRIO sem caixa
## de texto por cima. Uso: ... res://tools/scenery/CleanShot.tscn -- <tela> <saida.png> [frames] [nohud]

var _nohud: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_nohud = args.has("nohud")
	var w = load("res://tools/shot.gd").ShotWorker.new()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.out = args[1]
	if args.size() >= 3:
		w.frames = int(args[2])
	get_tree().root.add_child.call_deferred(w)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)


func _process(_delta: float) -> void:
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c is CaptionBar or (_nohud and c.is_in_group("hud")):
			c.visible = false
