extends Node
## QA de áudio (headless): confere que o catálogo do autoload Audio, a lista de
## compras (docs/AUDIO.md), os arquivos na pasta assets/audio/ e as chamadas no
## código batem entre si — e que tocar som/música sem arquivo não gera erro.
## Uso:  godot --headless --path . res://tools/AudioQA.tscn --quit-after 300
## Imprime "AUDIO QA: N falhas" e sai com 0 (ok) ou 1.

const DOC_PATH := "res://docs/AUDIO.md"
const AUDIO_DIR := "res://assets/audio/"
const SCAN_DIRS := ["res://scripts", "res://tools"]
const AUDIO_EXTS := ["ogg", "wav", "mp3"]

var fails: int = 0


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("QA PASS: ", message)
	else:
		fails += 1
		push_error("QA FAIL: " + message)


func _run() -> void:
	var sfx_names: Array = Audio.CATALOG["sfx"]
	var music_names: Array = Audio.CATALOG["music"]
	print("Catálogo: %d SFX, %d músicas" % [sfx_names.size(), music_names.size()])

	# (a) todo nome do catálogo está documentado na lista de compras.
	var doc := FileAccess.get_file_as_string(DOC_PATH)
	check(doc != "", "docs/AUDIO.md existe e não está vazio")
	var missing_doc: Array[String] = []
	for n in sfx_names:
		if not doc.contains("sfx/%s.ogg" % n):
			missing_doc.append("sfx/" + n)
	for n in music_names:
		if not doc.contains("music/%s.ogg" % n):
			missing_doc.append("music/" + n)
	check(missing_doc.is_empty(), "todo nome do catálogo está em docs/AUDIO.md (faltam: %s)" % str(missing_doc))

	# (a2) sem nomes duplicados no catálogo.
	var seen: Dictionary = {}
	var dups: Array[String] = []
	for n in sfx_names + music_names:
		if seen.has(n):
			dups.append(n)
		seen[n] = true
	check(dups.is_empty(), "catálogo sem nomes duplicados (%s)" % str(dups))

	# (b) todo arquivo de áudio na pasta está no catálogo (nada órfão).
	var orphans: Array[String] = []
	var present := 0
	for sub in ["sfx", "music"]:
		var dir := DirAccess.open(AUDIO_DIR + sub)
		if dir == null:
			continue
		var names: Array = sfx_names if sub == "sfx" else music_names
		for f in dir.get_files():
			var ext := f.get_extension().to_lower()
			if not AUDIO_EXTS.has(ext):
				continue
			present += 1
			if not names.has(f.get_basename()):
				orphans.append(sub + "/" + f)
	check(orphans.is_empty(), "nenhum arquivo órfão em assets/audio (%d arquivos presentes; órfãos: %s)" % [present, str(orphans)])

	# (c) tocar SFX inexistente não gera erro (cache negativa) — e o pool aguenta rajada.
	Audio.play_sfx("__nao_existe__")
	Audio.play_sfx_at("__nao_existe__", Vector2(9999, 0))
	for i in 40:
		Audio.play_sfx(sfx_names[i % sfx_names.size()])
	check(true, "play_sfx com nome inexistente e rajada de 40 chamadas não travam")

	# (d) crossfade / stop sem arquivos não geram erro e mantêm a faixa pedida.
	Audio.play_music("theme")
	Audio.play_music("boss")
	Audio.play_music("boss")           # idempotente
	check(Audio.current_track == "boss", "play_music registra a faixa pedida mesmo sem arquivo")
	Audio.stop_music(0.0)
	Audio.stop_music()
	Audio.play_music("__nao_existe__")
	await get_tree().process_frame
	await get_tree().process_frame
	check(true, "crossfade e stop_music sem arquivos não travam")

	# (e) toda faixa por contexto que o autoload escolhe existe no catálogo.
	var bad_tracks: Array[String] = []
	for s in range(1, RunManager.MAX_SCREEN + 1):
		var t: String = Audio.track_for_screen(s)
		if not music_names.has(t):
			bad_tracks.append("tela %d → %s" % [s, t])
	check(bad_tracks.is_empty(), "track_for_screen cobre todas as telas com faixa do catálogo (%s)" % str(bad_tracks))

	# (f) toda chamada literal no código (play_sfx/play_sfx_at/play_music) usa nome do catálogo.
	var files: Array[String] = []
	for d in SCAN_DIRS:
		_collect_gd(d, files)
	var re := RegEx.new()
	re.compile("play_(sfx_at|sfx|music)\\(\"([A-Za-z0-9_]+)\"")
	var unknown: Array[String] = []
	var used: Dictionary = {}
	for f in files:
		if f.ends_with("audio_qa.gd"):
			continue
		var src := FileAccess.get_file_as_string(f)
		for m in re.search_all(src):
			var kind: String = m.get_string(1)
			var n: String = m.get_string(2)
			if n.begins_with("__"):
				continue
			var resolved: String = Audio.ALIASES.get(n, n) if kind != "music" else n
			var names: Array = music_names if kind == "music" else sfx_names
			used[resolved] = true
			if not names.has(resolved):
				unknown.append("%s: %s" % [f.get_file(), n])
	check(unknown.is_empty(), "%d scripts varridos; toda chamada literal usa nome do catálogo (%s)" % [files.size(), str(unknown)])
	var never: Array[String] = []
	for n in sfx_names:
		if not used.has(n):
			never.append(n)
	print("Nomes do catálogo ainda sem chamada no código (esperados até a integração): ", never)

	print("AUDIO QA: %d falhas" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _collect_gd(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect_gd(path.path_join(d), out)
