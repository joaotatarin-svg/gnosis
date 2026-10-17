extends Node
## FERRAMENTA (não faz parte do jogo): compila TODOS os .gd do projeto.
## O `--editor --quit` só reclama de scripts usados por cenas/autoloads/class_name;
## um script solto com erro passava batido. Aqui cada .gd é carregado e checado.
## Uso: godot --headless --path . res://tools/ScriptCheck.tscn
## Imprime "SCRIPTCHECK: N scripts, M com erro" e sai com 0 (ok) ou 1.

const SKIP_DIRS := ["res://.godot", "res://addons", "res://builds", "res://.agents"]


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)   # ferramenta NUNCA toca som
	var files: Array[String] = []
	_scan("res://", files)
	var bad: Array[String] = []
	for f in files:
		var s = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REUSE)
		if s == null or not (s is Script) or not s.can_instantiate():
			bad.append(f)
	for f in bad:
		print("SCRIPTCHECK FAIL: ", f)
	print("SCRIPTCHECK: %d scripts, %d com erro" % [files.size(), bad.size()])
	get_tree().quit(0 if bad.is_empty() else 1)


func _scan(dir: String, out: Array[String]) -> void:
	if dir in SKIP_DIRS:
		return
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan(dir.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
