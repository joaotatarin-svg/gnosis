extends "res://tools/qa7/visual/node_shot.gd"
## FERRAMENTA QA7: o NodeShot + a cada 60 quadros imprime os inimigos vivos
## (posição no mundo e na tela, visível, voador, alpha) — acha "inimigo sumido".
## O trabalho fica num nó filho do ROOT (a cena da ferramenta morre na troca).


func _ready() -> void:
	super._ready()
	get_tree().root.add_child.call_deferred(Dumper.new())


class Dumper extends Node:
	var _f: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_d: float) -> void:
		_f += 1
		if _f % 60 != 0:
			return
		var xf := get_viewport().get_canvas_transform()
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		var line := "QA7DUMP f=%d pl=%s |" % [_f, str(xf * pl.global_position) if pl else "-"]
		for e in get_tree().get_nodes_in_group("enemy"):
			var n := e as Node2D
			if n == null:
				continue
			var sp: Vector2 = xf * n.global_position
			line += " [%s|%s scr=(%.0f,%.0f) vis=%s a=%.2f fly=%s]" % [str(e.get("display_name")), str(e.get("_art_id")), sp.x, sp.y, str(n.is_visible_in_tree()), n.modulate.a, str(e.get("fly_height"))]
		print(line)
