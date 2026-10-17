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
	"blip_estela", "blip_npc", "ui_move", "ui_confirm", "ui_back", "ui_open",
	"fog_swell", "king_step", "mask_light", "voice_merge", "whisper"]

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
		var names: Array = sfx_names if sub == "sfx" else ((music_names + Audio.OPTIONAL_MUSIC) if sub == "music" else amb_names)
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
	var ceiling := 0.0
	for i in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, i) is AudioEffectHardLimiter:
			ceiling = (AudioServer.get_bus_effect(mi, i) as AudioEffectHardLimiter).ceiling_db
	check(buses_ok and lim and ceiling <= -1.0, "buses Music/Ambience/SFX/UI/Voice + limitador no Master (teto %.1f dB)" % ceiling)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("UI")) == "SFX" and AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "SFX", "UI e Voz seguem o slider de SFX")

	# (b5) vozes por falante.
	check(Audio.blip_for_speaker("Sophia") == "blip_sophia" and Audio.blip_for_speaker("O Rei") == "blip_rei"
		and Audio.blip_for_speaker("A Voz") == "blip_voz" and Audio.blip_for_speaker("Fulano") == "blip_npc",
		"blip_for_speaker mapeia Sophia/Rei/Voz/resto")
	for i in 30:
		Audio.play_blip(["Sophia", "O Rei", "A Voz", "Estela", "Velkar"][i % 5])
	check(true, "rajada de 30 blips não trava")

	# (b6) ducking manual e automático (DialogueBox/Cinematic).
	#     As esperas são por RELÓGIO REAL atravessando quadros (_wait_real): um
	#     create_timer criado no 1º quadro (o da carga) dispara no MESMO quadro,
	#     com o delta inteiro da carga — 0,4 s viravam 0 ms e o teste media nada.
	await get_tree().process_frame
	var music_bus := AudioServer.get_bus_index("Music")
	var base_db := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck(true)
	await _wait_real(0.4)
	var ducked_db := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck(false)
	await _wait_real(1.0)
	var back_db := AudioServer.get_bus_volume_db(music_bus)
	check(ducked_db < base_db - 6.0 and absf(back_db - base_db) < 0.5, "duck(): música %.1f → %.1f → %.1f dB" % [base_db, ducked_db, back_db])
	# duck(true)+duck(false) no MESMO quadro não pode deixar o estado preso.
	Audio.duck(true)
	Audio.duck(false)
	await _wait_real(0.3)
	check(absf(AudioServer.get_bus_volume_db(music_bus) - base_db) < 0.5 and not Audio.is_ducked(), "duck(true)+duck(false) no mesmo quadro não prende a música")
	var dbox := DialogueBox.play([{"speaker": "Sophia", "text": "teste"}])
	await get_tree().process_frame
	await get_tree().process_frame
	var auto_ducked := Audio.is_ducked()
	await _wait_real(0.4)
	var box_db := AudioServer.get_bus_volume_db(music_bus)
	dbox.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	check(auto_ducked and not Audio.is_ducked() and box_db < base_db - 6.0,
		"DialogueBox abaixa a música sozinho (%.1f → %.1f dB) e devolve ao sair" % [base_db, box_db])

	# (b7) API da Narrativa: duck_music temporário, camada por faixa, tom.
	await _wait_real(1.0)
	var b0 := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck_music(0.3, -12.0)
	await _wait_real(0.35)
	var b1 := AudioServer.get_bus_volume_db(music_bus)
	await _wait_real(1.2)
	var b2 := AudioServer.get_bus_volume_db(music_bus)
	check(b1 < b0 - 8.0 and absf(b2 - b0) < 0.5, "duck_music(0,3 s, -12): %.1f → %.1f → %.1f dB" % [b0, b1, b2])
	Audio.set_music_layer_volume(0.0, "centro")
	Audio.set_music_layer_volume(1.0, "centro")
	Audio.set_music_pitch(0.8, 0.0)
	Audio.set_music_pitch(1.0, 0.2)
	Audio.play_music("theme", true, 0.9)
	check(true, "set_music_layer_volume / set_music_pitch / play_music com tom não travam")

	# (b8) Provação (REVISAO #8): CodexSession.active é testado ANTES de
	#      run_active (start_demo liga os dois); faixa pelo Arconte escolhido.
	var keep_active: bool = CodexSession.active
	var keep_stage: int = CodexSession.stage
	var keep_boss: int = CodexSession.boss_index
	var keep_run: bool = RunManager.run_active
	var keep_screen: int = RunManager.current_screen
	CodexSession.active = true
	RunManager.run_active = true
	var wrong_trial: Array[String] = []
	for b in 7:
		CodexSession.boss_index = b
		for st in 3:
			CodexSession.stage = st
			Audio._on_state_changed(GameManager.State.PLAYING)
			var want: String = "boss" if st >= 2 else "eon_" + Audio.EON_TRACKS[b]
			if Audio.current_track != want:
				wrong_trial.append("arconte %d enc. %d → %s (queria %s)" % [b, st + 1, Audio.current_track, want])
	Audio._on_screen_changed(1)
	check(wrong_trial.is_empty() and Audio.current_track == "boss",
		"Provação: Éon certo nos encontros 1–2, boss no 3º, mesmo com run_active; screen_changed não atropela (%s)" % str(wrong_trial))
	CodexSession.active = keep_active
	CodexSession.stage = keep_stage
	CodexSession.boss_index = keep_boss

	# (b9) Centro (ROTEIRO cena C): sem música até o 1º caco; depois sobe por caco.
	var keep_restored: Array[String] = Progression.restored_rings.duplicate()
	RunManager.current_screen = RunManager.CENTER_FIRST
	Progression.restored_rings.clear()
	Audio._play_run_context(RunManager.CENTER_FIRST)
	var c0: String = Audio._playing_track
	Progression.restored_rings.assign(["a", "b"])
	Audio._update_center_music()
	var c2: String = Audio._playing_track
	var l2: float = float(Audio._layer_db.get("centro", 99.0))
	Progression.restored_rings.assign(["a", "b", "c", "d", "e", "f"])
	Audio._update_center_music()
	var l6: float = float(Audio._layer_db.get("centro", 99.0))
	check(c0 == "" and c2 == "centro" and absf(l2 - lerpf(-18.0, 0.0, 0.35 + 0.65 * 2.0 / 6.0)) < 0.01 and is_equal_approx(l6, 0.0),
		"Centro: mudo sem cacos ('%s'), 'centro' entra no 1º caco e sobe por caco (2 → %.1f dB, 6 → %.1f dB)" % [c0, l2, l6])
	Progression.restored_rings.assign(keep_restored)
	RunManager.run_active = keep_run
	RunManager.current_screen = keep_screen

	# (b10) Menu desfaz o que as cenas deixaram (tom, camadas).
	Audio.set_music_layer_volume(0.2, "theme")
	Audio.set_music_pitch(0.75, 0.0)
	Audio._on_state_changed(GameManager.State.MENU)
	check(Audio._layer_db.is_empty() and is_equal_approx(Audio._music_pitch, 1.0) and Audio.current_track == Audio.menu_track(),
		"menu zera tom e camadas e volta ao tema do menu ('%s')" % Audio.menu_track())
	check(Audio.menu_track() == ("menu" if Audio.has_music("menu") else "theme"),
		"tema do menu: 'menu' se o arquivo existir, senão 'theme' (hoje: %s)" % Audio.menu_track())

	# (b11) Corte seco: fade 0 para a anterior na hora e a nova entra cheia.
	Audio.play_music("rei", true, 1.0, 0.0)
	await get_tree().process_frame
	var n_playing := 0
	for m in Audio._music:
		if m.playing:
			n_playing += 1
	check(Audio._playing_track == "rei" and n_playing == 1 and absf(Audio._music[Audio._music_cur].volume_db) < 0.01,
		"play_music(faixa, loop, tom, fade=0) corta seco (%d player tocando, %.1f dB)" % [n_playing, Audio._music[Audio._music_cur].volume_db])

	# (b12) SFX: tom exato, anti-spam, arpejo da faísca, limite de vozes (R6/R11).
	var pitched := Audio.play_sfx_pitched("ring_steal", pow(2.0, 3.0 / 12.0), -2.0)
	var exact := false
	for i in Audio._players.size():
		if Audio._pl_name[i] == "ring_steal":
			exact = is_equal_approx(Audio._players[i].pitch_scale, pow(2.0, 3.0 / 12.0)) and is_equal_approx(Audio._players[i].volume_db, -2.0)
	check(pitched and exact, "play_sfx_pitched toca no tom e volume EXATOS")
	var h1 := Audio.play_sfx("hit")
	var h2 := Audio.play_sfx("hit")
	check(h1 and not h2, "anti-spam: o mesmo golpe 2× no mesmo instante toca 1×")
	var arp := 0
	for i in 6:
		if Audio.play_sfx("spark"):
			arp += 1
		await _wait_real(0.042)
	check(arp == 6 and Audio.spam_ms_for("spark") < 40, "faísca: 6 chegadas a ~42 ms soam todas (arpejo não é engolido)")
	for i in 6:
		Audio.play_sfx("hit_heavy")
		await _wait_real(0.045)
	var hv := Audio.voices_playing("hit_heavy")
	check(hv <= Audio.MAX_SAME, "no máximo %d vozes do mesmo som (hit_heavy: %d tocando)" % [Audio.MAX_SAME, hv])

	# (b13) Estéreo discreto pela posição na tela (R14).
	var vw := get_viewport().get_visible_rect().size.x
	var pl := Audio.pan_for(get_viewport().get_canvas_transform().affine_inverse() * Vector2(0, 0))
	var pc := Audio.pan_for(get_viewport().get_canvas_transform().affine_inverse() * Vector2(vw * 0.5, 0))
	var pr := Audio.pan_for(get_viewport().get_canvas_transform().affine_inverse() * Vector2(vw * 3.0, 0))
	var right_pos := get_viewport().get_canvas_transform().affine_inverse() * Vector2(vw, 0)
	Audio.play_sfx("enemy_hurt", -1.0, 0.0, right_pos)
	var right_bus := ""
	for i in Audio._players.size():
		if Audio._pl_name[i] == "enemy_hurt":
			right_bus = Audio._players[i].bus
	Audio.play_sfx("proj_hit")
	var mid_bus := ""
	for i in Audio._players.size():
		if Audio._pl_name[i] == "proj_hit":
			mid_bus = Audio._players[i].bus
	var r2 := AudioServer.get_bus_index("SFX_R2")
	var pan_fx = AudioServer.get_bus_effect(r2, 0) if r2 >= 0 and AudioServer.get_bus_effect_count(r2) > 0 else null
	check(is_equal_approx(pl, -0.5) and absf(pc) < 0.01 and is_equal_approx(pr, 0.5) and right_bus == "SFX_R2" and mid_bus == "SFX"
		and pan_fx is AudioEffectPanner and is_equal_approx(pan_fx.pan, 0.5) and AudioServer.get_bus_send(r2) == "SFX",
		"pan pela tela: esquerda %.2f, meio %.2f, fora à direita %.2f (teto 0,5); com posição → %s, sem → %s" % [pl, pc, pr, right_bus, mid_bus])

	# (b14) Slow-mo (R8): passa-baixas 20 kHz → 1,5 kHz em 60 ms, música −4 dB,
	#       volta em 250 ms; esquiva perfeita (0,3) abafa só até 2,5 kHz.
	if Juice.has_signal("slowmo_changed"):
		check(Juice.is_connected("slowmo_changed", Callable(Audio, "_on_slowmo_changed")), "Audio escuta Juice.slowmo_changed")
	await _wait_real(0.6)
	var sfx_i := AudioServer.get_bus_index("SFX")
	var lp_slot := -1
	for i in AudioServer.get_bus_effect_count(sfx_i):
		if AudioServer.get_bus_effect(sfx_i, i) is AudioEffectLowPassFilter:
			lp_slot = i
	var m0 := AudioServer.get_bus_volume_db(music_bus)
	var lp_off0 := lp_slot >= 0 and not AudioServer.is_bus_effect_enabled(sfx_i, lp_slot)
	Audio._on_slowmo_changed(true, 0.22)
	await _wait_real(0.12)
	var hz_cut := Audio.lowpass_cutoff_hz()
	var lp_on := lp_slot >= 0 and AudioServer.is_bus_effect_enabled(sfx_i, lp_slot)
	var m1 := AudioServer.get_bus_volume_db(music_bus)
	Audio._on_slowmo_changed(false, 1.0)
	await _wait_real(0.4)
	var lp_off1 := lp_slot >= 0 and not AudioServer.is_bus_effect_enabled(sfx_i, lp_slot)
	var m2 := AudioServer.get_bus_volume_db(music_bus)
	Audio._on_slowmo_changed(true, 0.3)
	await _wait_real(0.12)
	var hz_dodge := Audio.lowpass_cutoff_hz()
	Audio._on_slowmo_changed(false, 1.0)
	await _wait_real(0.4)
	check(lp_off0 and lp_on and lp_off1 and absf(hz_cut - 1500.0) < 30.0 and absf(hz_dodge - 2500.0) < 50.0
		and absf((m1 - m0) + 4.0) < 0.3 and absf(m2 - m0) < 0.3,
		"slow-mo: corte %.0f Hz (esquiva %.0f Hz), música %.1f → %.1f → %.1f dB, filtro desliga ao sair" % [hz_cut, hz_dodge, m0, m1, m2])

	# (b15) Tema da Voz (ROTEIRO §5 #8): santuário baixo → roubo distorcido 3 s
	#       e corte seco para `roubo` → anagnórise sozinho e lento. Fora de run.
	var keep_run2: bool = RunManager.run_active
	var keep_codex: bool = CodexSession.active
	RunManager.run_active = false
	CodexSession.active = false
	Audio._on_state_changed(GameManager.State.MENU)
	Audio.voice_theme("santuario")
	var sanct_ok: bool = Audio.current_track == "theme" and is_equal_approx(float(Audio._layer_db.get("theme", 99.0)), Audio.VOICE_SANCTUARY_DB) \
		and Audio.voice_theme_mode == "santuario" and is_equal_approx(Audio._duck_scale, 1.0)
	Audio.voice_theme("roubo")
	var stolen_ok: bool = Audio._playing_track == "theme" and is_equal_approx(Audio._music_pitch, Audio.VOICE_STOLEN_PITCH) \
		and not Audio._layer_db.has("theme") and Audio._duck_scale < 0.5
	var t_roubo := Time.get_ticks_msec()
	await _wait_real(Audio.VOICE_STOLEN_SECS - 0.4)
	var early: String = Audio._playing_track
	while Audio._playing_track != "roubo" and Time.get_ticks_msec() - t_roubo < int(Audio.VOICE_STOLEN_SECS * 1000.0) + 900:
		await get_tree().process_frame
	var cut_ms := Time.get_ticks_msec() - t_roubo
	var n_roubo := 0
	for m in Audio._music:
		if m.playing:
			n_roubo += 1
	check(sanct_ok and stolen_ok and early == "theme" and Audio._playing_track == "roubo" and n_roubo == 1
		and is_equal_approx(Audio._music_pitch, 1.0) and cut_ms >= int(Audio.VOICE_STOLEN_SECS * 1000.0) - 20
		and cut_ms <= int(Audio.VOICE_STOLEN_SECS * 1000.0) + 800,
		"tema da Voz: santuário (−3 dB) → roubo a 0,75 → corte seco para 'roubo' em %d ms (%d player)" % [cut_ms, n_roubo])
	# Uma troca de cena no meio cancela o corte agendado.
	Audio.voice_theme("roubo")
	Audio.voice_theme("sozinha")
	await _wait_real(Audio.VOICE_STOLEN_SECS + 0.3)
	check(Audio._playing_track == "theme" and is_equal_approx(Audio._music_pitch, Audio.VOICE_ALONE_PITCH),
		"anagnórise: tema sozinho e lento (%.2f) e o corte do roubo agendado antes foi cancelado (%s)" % [Audio._music_pitch, Audio._playing_track])
	var s0 := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck(true)
	await _wait_real(0.4)
	await get_tree().process_frame
	var s1 := AudioServer.get_bus_volume_db(music_bus)
	Audio.duck(false)
	await _wait_real(1.0)
	check(absf((s1 - s0) - Audio.DUCK_MUSIC_DB * Audio.SCENE_DUCK_SCALE) < 0.5,
		"na cena musical o diálogo abaixa a música só %.1f dB (normal: %.1f)" % [s1 - s0, Audio.DUCK_MUSIC_DB])
	Audio.voice_theme("")
	check(Audio.voice_theme_mode == "" and is_equal_approx(Audio._duck_scale, 1.0), "voice_theme('') encerra a cena e devolve o ducking normal")
	# Névoa (cena A): abaixada longa; a troca de tela solta.
	Audio.cue("fog_thickens")
	await _wait_real(0.4)
	await get_tree().process_frame     # o _process do Audio roda DEPOIS deste ponto do quadro
	var fog_db: float = Audio._temp_duck_db
	Audio._end_scene_music()
	await _wait_real(1.0)
	check(absf(fog_db - Audio.FOG_DUCK_DB) < 0.3 and absf(Audio._temp_duck_db) < 0.05,
		"cue fog_thickens abaixa a música %.1f dB e a troca de tela solta (%.1f)" % [fog_db, Audio._temp_duck_db])
	RunManager.run_active = keep_run2
	CodexSession.active = keep_codex

	# (b16) Todo `cue` usado nas falas (narrative.gd) é conhecido por Audio.cue();
	#       cue desconhecido devolve false; gemas do roubo sobem, as da volta descem.
	var nsrc := FileAccess.get_file_as_string("res://scripts/autoload/narrative.gd")
	var cre := RegEx.new()
	cre.compile("_c\\(.+\"([a-z0-9_]+)\"\\)")
	var used_cues: Dictionary = {}
	for m in cre.search_all(nsrc):
		used_cues[m.get_string(1)] = true
	var unknown_cues: Array[String] = []
	for c in used_cues:
		if not Audio.CUES.has(c):
			unknown_cues.append(c)
	var cue_fail: Array[String] = []
	for c in Audio.CUES:
		if not Audio.cue(c):
			cue_fail.append(c)
	Audio._on_state_changed(GameManager.State.MENU)
	check(used_cues.size() >= 15 and unknown_cues.is_empty() and cue_fail.is_empty() and not Audio.cue("__nao_existe__"),
		"%d cues nas falas, todos tratados por Audio.cue() (desconhecidos: %s; falharam: %s)" % [used_cues.size(), str(unknown_cues), str(cue_fail)])
	await _wait_real(0.1)
	var steal_p: Array[float] = []
	var ret_p: Array[float] = []
	for i in 2:
		Audio.ring_note(i, false)
		for k in Audio._players.size():
			if Audio._pl_name[k] == "ring_steal" and Audio._pl_start[k] == Audio._pl_start.max():
				steal_p.append(Audio._players[k].pitch_scale)
		Audio.ring_note(i, true)
		for k in Audio._players.size():
			if Audio._pl_name[k] == "ring_gain" and Audio._pl_start[k] == Audio._pl_start.max():
				ret_p.append(Audio._players[k].pitch_scale)
		await _wait_real(0.06)
	check(steal_p.size() == 2 and ret_p.size() == 2 and steal_p[1] > steal_p[0] and ret_p[1] < ret_p[0]
		and is_equal_approx(steal_p[1] / steal_p[0], pow(2.0, 1.0 / 12.0)),
		"ring_note: roubo sobe um semitom por gema %s, a volta desce %s" % [str(steal_p), str(ret_p)])

	# (b17) Depois de um ring_note, o sinal de Anel (Progression) não toca o som
	#       de novo (senão o roubo soaria 8 gemas, a volta dobraria). Sem a cena, toca.
	var keep_state = GameManager.state
	var keep_stolen: bool = Progression.rings_stolen
	GameManager.state = GameManager.State.PLAYING
	await _wait_real(0.1)
	for k in Audio._players.size():
		if Audio._pl_name[k] == "ring_steal":
			Audio._players[k].stop()
	var before := Audio.voices_playing("ring_steal")
	Audio.ring_note(6, false)
	var after_note := Audio.voices_playing("ring_steal")
	Audio._last_stolen = false
	Progression.rings_stolen = true
	Audio._on_rings()
	var after_signal := Audio.voices_playing("ring_steal")
	Audio._ring_note_ms = -100000
	Audio._last_stolen = false
	await _wait_real(0.06)
	Audio._on_rings()
	var plain_signal := Audio.voices_playing("ring_steal")
	Progression.rings_stolen = keep_stolen
	Audio._last_stolen = keep_stolen
	GameManager.state = keep_state
	check(before == 0 and after_note == 1 and after_signal == 1 and plain_signal == 2,
		"sinal de Anel não repete a gema que a cena tocou (%d → %d → %d); sem cena toca (%d)" % [before, after_note, after_signal, plain_signal])

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
	re.compile("play_(sfx_at|sfx_pitched|sfx|music)\\(\"([A-Za-z0-9_]+)\"")
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

	# (g) Encerramento (REVISAO #15): para e solta todos os players.
	Audio.play_music("boss")
	Audio.play_ambience("torpor")
	Audio.play_sfx("nova")
	await get_tree().process_frame
	Audio.shutdown()
	var still := 0
	for p in Audio.get_children():
		if p is AudioStreamPlayer and ((p as AudioStreamPlayer).playing or (p as AudioStreamPlayer).stream != null):
			still += 1
	check(still == 0 and not Audio.play_sfx("hit"), "shutdown() para e solta todos os players (%d sobrando) e não toca mais nada" % still)

	print("AUDIO QA: %d falhas" % fails)
	get_tree().quit(0 if fails == 0 else 1)


## Espera `sec` segundos de relógio REAL, atravessando quadros (não um timer
## que pode disparar no mesmo quadro em que nasceu).
func _wait_real(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame


func _collect_gd(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect_gd(path.path_join(d), out)
