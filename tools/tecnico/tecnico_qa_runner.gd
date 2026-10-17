extends Node
## Lança a QA do Técnico2 FORA da cena atual (ela troca de cena várias vezes;
## se fosse a cena principal, sumiria na 1ª troca). Mesmo esquema do
## tools/regressao/reg_runner.gd.

func _ready() -> void:
	var t: Node = load("res://tools/tecnico/tecnico_qa.gd").new()
	t.set("id", "TECNICO")
	t.name = "TecnicoQA_Run"
	get_tree().root.add_child.call_deferred(t)
