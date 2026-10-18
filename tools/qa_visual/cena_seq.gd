extends "res://tools/encenacao/cena_shot.gd"
## SONDA QA-VISUAL (não faz parte do jogo): a CenaShot da Encenação SEM mudar
## nada nela + um GRAVADOR contínuo: salva um quadro (640×360) a cada `every`
## quadros do começo ao fim da cena — vira GIF/MP4 em tempo real com o ffmpeg.
## A cada 30 quadros imprime onde estão Sophia e chefes NA TELA (px de 640×360),
## visíveis ou não: "CSEQ|f=<n>|sophia=(x,y)|<chefe>=(x,y) vis=<bool> a=<alpha>"
## Uso: godot --fixed-fps 60 --audio-driver Dummy --path . --resolution 1280x720 --position 4000,4000 \
##   res://tools/qa_visual/CenaSeq.tscn -- <tela> <prefixo> [hold=..] [kill=..] [every=4] [maxq=1800]


func _ready() -> void:
	super()
	var r := Recorder.new()
	r.prefix = prefix
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = String(a).split("=", true, 1)
		if kv.size() == 2 and kv[0] == "every":
			r.every = maxi(1, int(kv[1]))
		if kv.size() == 2 and kv[0] == "maxq":
			r.max_saves = int(kv[1])
	get_tree().root.add_child.call_deferred(r)


class Recorder extends Node:
	var prefix: String = ""
	var every: int = 4
	var max_saves: int = 1800
	var _f: int = 0
	var _n: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_d: float) -> void:
		_f += 1
		if _f % 30 == 0:
			_log()
		if _f % every != 0 or _n >= max_saves:
			return
		var img := get_viewport().get_texture().get_image()
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s_seq_%05d.png" % [prefix, _n])
		_n += 1

	func _log() -> void:
		var cs := get_tree().current_scene
		if not (cs is Level):
			return
		var ct := get_viewport().get_canvas_transform()
		var parts: Array = ["CSEQ|f=%d" % _f]
		var lv: Level = cs
		if lv.player != null:
			parts.append("sophia=%s" % str((ct * lv.player.global_position).round()))
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Enemy and e.is_boss_enemy:
				parts.append("%s=%s vis=%s a=%.2f est=%s" % [e.display_name, str((ct * e.global_position).round()), str(e.is_visible_in_tree()), e.modulate.a, str(e.estate)])
		print("|".join(parts))
