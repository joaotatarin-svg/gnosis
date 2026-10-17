extends Node
## SONDA DE REVISÃO: recompila todos os .gd do jogo (cache ignorado). Com o
## override.cfg temporário elevando os avisos do GDScript a ERRO, cada aviso
## aparece no log como "Compile Error"/"SCRIPT ERROR" com arquivo:linha.
## Uso: godot --headless --audio-driver Dummy --path . res://tools/revisao/SondaAvisos.tscn

func _ready() -> void:
	var files: Array[String] = []
	_walk("res://scripts", files)
	var falhas := 0
	for p in files:
		var s = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not (s as GDScript).can_instantiate():
			falhas += 1
			print("AVISOS-ARQ ", p)
	print("AVISOS FIM: %d arquivos, %d com aviso/erro" % [files.size(), falhas])
	get_tree().quit()


func _walk(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)
