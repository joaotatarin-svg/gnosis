extends Node
## QA de áudio (headless): confere que o catálogo do autoload Audio, a lista de
## compras (docs/AUDIO.md), os arquivos na pasta assets/audio/ e as chamadas no
## código batem entre si — e que tocar som/música sem arquivo não gera erro.
## Também cobre: variações (nome_2, nome_3...), ambiências por Éon, ducking,
## vozes "gromelô" e buses.
## Uso:  godot --headless --audio-driver Dummy --path . res://tools/AudioQA.tscn --quit-after 300
## Imprime "AUDIO QA: N falhas" e sai com 0 (ok) ou 1.

const DOC_PATH := "res://docs/AUDIO.md"
const AUDIO_DIR := "res://assets/audio/"
const SCAN_DIRS := ["res://scripts", "res://tools"]
const AUDIO_EXTS := ["ogg", "wav", "mp3"]
## Eventos frequentes: precisam de pelo menos 2 variações (contrato de áudio).
const NEED_VARIANTS := ["swing_light", "swing_heavy", "hit", "hit_heavy", "step", "step_heavy", "cloth",
	"boss_step", "enemy_hurt", "block", "blip_voz", "blip_rei", "blip_sophia", "blip_estela", "blip_npc", "spark"]
## Contrato com Animação/UI: estes nomes TÊM de existir com arquivo.
const CONTRACT := ["step", "step_heavy", "cloth", "boss_step", "blip_voz", "blip_rei", "blip_sophia",
	"blip_estela", "blip_npc", "ui_move", "ui_confirm", "ui_back", "ui_open"]

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
	var amb_names: Array = Audio.CATALOG["amb"]
	print("Catálogo: %d SFX, %d músicas, %d ambiências" % [sfx_names.size(), music_names.size(), amb_names.size()])

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
	for n in amb_names:
		if not doc.contains("amb/%s.ogg" % n):
			missing_doc.append("amb/" + n)
	check(missing_doc.is_empty(), "todo nome do catálogo está em docs/AUDIO.md (faltam: %s)" % str(missing_doc))

	# (a2) sem nomes duplicados no catálogo.
	var seen: Dictionary = {}
	var dups: Array[String] = []
	for n in sfx_names + music_names + amb_names:
		if seen.has(n):
			dups.append(n)
		seen[n] = true
	check(dups.is_empty(), "catálogo sem nomes duplicados (%s)" % str(dups))

	# (b) todo arquivo de áudio na pasta está no catálogo (nada órfão) —
	#     variação `nome_N` conta se `nome` está no catálogo.
	var orphans: Array[String] = []
	var present := 0
	var var_re := RegEx.new()
	var_re.compile("^(.+)_([2-9])$")
	for sub in ["sfx", "music", "amb"]:
		var dir := DirAccess.open(AUDIO_DIR + sub)
		if dir == null:
			continue
		var names: Array = sfx_names if sub == "sfx" else (music_names if sub == "music" else amb_names)
		for f in dir.get_files():
			var ext := f.get_extension().to_lower()
			if not AUDIO_EXTS.has(ext):
				continue
			present += 1
			var base := f.get_basename()
			if names.has(base):
				continue
			var m := var_re.search(base)
			if sub == "sfx" and m != null and names.has(m.get_string(1)):
				continue
			orphans.append(sub + "/" + f)
	check(orphans.is_empty(), "nenhum arquivo órfão em assets/audio (%d arquivos presentes; órfãos: %s)" % [present, str(orphans)])

	# (b2) todo nome do catálogo TEM arquivo (o jogo não fica mudo em nada).
	var missing: Array[String] = []
	for n in sfx_names:
		if not Audio.has_sfx(n):
			missing.append("sfx/" + n)
	for n in music_names:
		if not Audio.has_music(n):
			missing.append("music/" + n)
	for n in amb_names:
		if not Audio.has_ambience(n):
			missing.append("amb/" + n)
	check(missing.is_empty(), "todo nome do catálogo tem arquivo (faltam: %s)" % str(missing))
	var no_contract: Array[String] = []
	for n in CONTRACT:
		if not sfx_names.has(n) or not Audio.has_sfx(n):
			no_contract.append(n)
	check(no_contract.is_empty(), "sons do contrato (Animação/UI) existem (%s)" % str(no_contract))

	# (b3) variações: eventos frequentes têm 2+; o sorteio nunca repete seguido.
	var few: Array[String] = []
	var total_var := 0
	for n in NEED_VARIANTS:
		var k: int = Audio.variants_of(n).size()
		total_var += k
		if k < 2:
			few.append("%s=%d" % [n, k])
	check(few.is_empty(), "eventos frequentes com 2+ variações (%d arquivos; poucos: %s)" % [total_var, str(few)])
	var repeats := 0
	var prev = null
	for i in 60:
		var s = Audio._pick_variant("hit", false)
		if s == prev:
			repeats += 1
		prev = s
	check(repeats == 0, "sorteio de variação não repete a anterior (60 sorteios de hit, %d repetições)" % repeats)
	var seq: Array[int] = []
	Audio._last_variant.erase("spark")
	for i in 7:
		var s = Audio._pick_variant("spark", i > 0)
		seq.append(Audio.variants_of("spark").find(s))
	check(seq[0] == 0 and seq[1] == 1 and seq[2] == 2, "faísca sobe a escala em sequência (%s)" % str(seq))

	# (b4) buses e limitador.
	var buses_ok := true
	for b in ["Music", "Ambience", "SFX", "UI", "Voice"]:
		buses_ok = buses_ok and AudioServer.get_bus_index(b) >= 0
	var lim := false
	var mi := AudioServer.get_bus_index("Master")
	for i in AudioServer.get_bus_effect_count(mi):
		lim = lim or AudioServer.get_bus_effect(mi, i) is AudioEffectHardLimiter
	check(buses_ok and lim, "buses Music/Ambience/SFX/UI/Voice + limitador no Master")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")) == "SFX" and AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "SFX", "UI e Voz seguem o slider de SFX")

	# (b5) vozes por falante.
	check(Audio.blip_for_speaker("Sophia") == "blip_sophia" and Audio.blip_for_speaker("O Rei") == "blip_rei"
		and Audio.blip_for_speaker("A Voz") == "blip_voz" and Audio.blip_for_speaker("Fulano") == "blip_npc",
		"blip_for_speaker mapeia Sophia/Rei/Voz/resto")
	for i in 30:
		Audio.play_blip(["Sophia", "O Rei", "A Voz", "Estela", "Velkar"][i % 5])
	check(true, "rajada de 30 blips não trava")

	# (b6) ducking manual e automático (DialogueBox/Cinematic).
	var music_bus := AudioServer.get_bus_index("Music")
	var base_db := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck(true)
	await get_tree().create_timer(0.4, true, false, true).timeout
	var ducked_db := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck(false)
	await get_tree().create_timer(1.0, true, false, true).timeout
	var back_db := AudioServer.get_bus_volume_db(music_bus)
	check(ducked_db < base_db - 6.0 and absf(back_db - base_db) < 0.5, "duck(): música %.1f → %.1f → %.1f dB" % [base_db, ducked_db, back_db])
	var dbox := DialogueBox.play([{"speaker": "Sophia", "text": "teste"}])
	await get_tree().process_frame
	await get_tree().process_frame
	var auto_ducked := Audio.is_ducked()
	dbox.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	check(auto_ducked and not Audio.is_ducked(), "DialogueBox abaixa a música sozinho e devolve ao sair")

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
	var bad_amb: Array[String] = []
	for s in range(1, RunManager.MAX_SCREEN + 1):
		var a: String = Audio.ambience_for_screen(s)
		if a != "" and not amb_names.has(a):
			bad_amb.append("tela %d → %s" % [s, a])
	check(bad_amb.is_empty(), "ambience_for_screen só usa ambiências do catálogo (%s)" % str(bad_amb))
	Audio.play_ambience("torpor")
	Audio.play_ambience("amb_fome", -5.0)
	Audio.play_ambience("__nao_existe__")
	Audio.stop_ambience(0.0)
	check(true, "play_ambience/stop_ambience (inclusive sem arquivo) não travam")

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
