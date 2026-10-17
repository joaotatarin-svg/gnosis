extends Node
## Lança UMA QA de regressão pelo id (não faz parte do jogo).
## Uso: godot --headless --audio-driver Dummy --fixed-fps 60 --path . \
##        res://tools/regressao/Reg.tscn -- <ID> [autoteste]   (ex.: B1, A3, R1)
## Carrega res://tools/regressao/reg_<id minúsculo>.gd (extends reg_base.gd).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("REG|?|BROKEN|sem id (uso: Reg.tscn -- <ID>)")
		get_tree().quit(3)
		return
	var tid: String = args[0].to_upper()
	var path := "res://tools/regressao/reg_%s.gd" % tid.to_lower()
	if not ResourceLoader.exists(path):
		print("REG|%s|BROKEN|script não existe: %s" % [tid, path])
		get_tree().quit(3)
		return
	var scr = load(path)
	if scr == null or not (scr is GDScript) or not scr.can_instantiate():
		print("REG|%s|BROKEN|script não compila: %s" % [tid, path])
		get_tree().quit(3)
		return
	var t: Node = scr.new()
	t.set("id", tid)
	if args.size() >= 2 and args[1] == "autoteste":
		t.set("autoteste", true)
	t.name = "Reg_" + tid
	get_tree().root.add_child.call_deferred(t)
