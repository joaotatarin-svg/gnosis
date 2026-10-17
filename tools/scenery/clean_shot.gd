extends Node
## FERRAMENTA (cenário): igual ao tools/Shot.tscn, mas esconde as legendas
## (CaptionBar) e, com "nohud", também o HUD — para julgar o CENÁRIO sem caixa
## de texto por cima. Uso: ... res://tools/scenery/CleanShot.tscn -- <tela> <saida.png> [frames] [nohud] [x=<x>] [zone=<i>]
##   x=<x>     prende a Sophia nesse x de mundo (ex.: x=-690 = colada na parede esquerda)
##   zone=<i>  tranca a zona i logo no começo (mostra as paredes da arena)
##   legacyfg  primeiro plano antigo (colunona em cada descanso) — capturas ANTES
##   face=<-1|1> vira a Sophia (a antecipação da câmera olha 90 px para esse lado)

## (O nó raiz desta cena é liberado quando o Shot troca de cena; quem esconde
## legendas e prende a Sophia é o `Cleaner`, filho do ROOT, que sobrevive.)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cl := Cleaner.new()
	cl.nohud = args.has("nohud")
	# legacyfg = primeiro plano como era até a Onda 4 (colunona no descanso), p/ o ANTES
	Scenery.Foreground.legacy = args.has("legacyfg")
	for a in args:
		if a.begins_with("x="):
			cl.x = float(a.substr(2))
		elif a.begins_with("zone="):
			cl.zone = int(a.substr(5))
		elif a.begins_with("face="):
			cl.face = int(a.substr(5))
	var w = load("res://tools/shot.gd").ShotWorker.new()
	if args.size() >= 1:
		w.screen = int(args[0])
	if args.size() >= 2:
		w.out = args[1]
	if args.size() >= 3:
		w.frames = int(args[2])
	get_tree().root.add_child.call_deferred(w)
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	cl.process_priority = 100        # depois do ShotWorker (que teleporta a Sophia)
	get_tree().root.add_child.call_deferred(cl)


class Cleaner extends Node:
	var nohud: bool = false
	var x: float = INF
	var zone: int = -1
	var face: int = 0
	var _zone_done: bool = false

	func _process(_delta: float) -> void:
		for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
			if c is CaptionBar or (nohud and c.is_in_group("hud")):
				c.visible = false
		var lv := get_tree().current_scene
		if lv == null or not ("player" in lv) or lv.get("player") == null:
			return
		if zone >= 0 and not _zone_done and lv.has_method("_start_zone"):
			_zone_done = true
			lv.call("_start_zone", zone)
		if x != INF:
			var pl: Node2D = lv.get("player")
			pl.global_position.x = x
		if face != 0 and "facing" in lv.get("player"):
			lv.get("player").set("facing", face)
			# sem zone=: o "anda até a zona" do Shot pode ter trancado uma zona;
			# solta a câmera para ela poder ir até a Sophia
			if zone < 0 and lv.get("zone_active") and lv.has_method("_unlock_zone"):
				lv.call("_unlock_zone")
		if OS.has_environment("CLEAN_DEBUG") and Engine.get_process_frames() % 20 == 0:
			var cam := get_viewport().get_camera_2d()
			print("CLEAN f=%d player=%s cam=%s lim=%d..%d" % [Engine.get_process_frames(), lv.get("player").global_position, cam.get_screen_center_position() if cam else Vector2.ZERO, cam.limit_left if cam else 0, cam.limit_right if cam else 0])
