extends "res://tools/shot.gd"
## FERRAMENTA QA7 (não faz parte do jogo): o Shot normal, mas FORÇA o nó do mapa
## da tela (variável de ambiente QA7_NODE=e1.2b) e, com QA7_DJ=1, concede o
## pulo duplo. Mesmos argumentos do tools/shot.gd.


func _ready() -> void:
	super._ready()
	_force.call_deferred()


func _force() -> void:
	var id := OS.get_environment("QA7_NODE")
	if id != "":
		RunManager.set("current_node", id)
		print("QA7 nó forçado: ", id, " tela ", RunManager.current_screen)
	if OS.get_environment("QA7_DJ") == "1" and Progression.has_method("grant_double_jump"):
		Progression.grant_double_jump()
