extends Node
## QA de áudio (headless): confere que o catálogo do autoload Audio, a lista de
## compras (docs/AUDIO.md), os arquivos na pasta assets/audio/ e as chamadas no
## código batem entre si — e que tocar som/música sem arquivo não gera erro.
## Também cobre: variações (nome_2, nome_3...), ambiências por Éon, ducking,
## vozes "gromelô" e buses.
## Uso:  godot --headless --audio-driver Dummy --path . res://tools/AudioQA.tscn --quit-after 300
## Imprime "AUDIO QA: N falhas" e sai com 0 (ok) ou 1.

const DOC_PATH := "res://docs/AUDIO.md"
## Onda 7: o catálogo dos sons novos fica no relatório do Áudio7 (lido junto).
const DOC7_PATH := "res://docs/onda2/AUDIO7.md"
const AUDIO_DIR := "res://assets/audio/"
const SCAN_DIRS := ["res://scripts", "res://tools"]
const AUDIO_EXTS := ["ogg", "wav", "mp3"]
## Eventos frequentes: precisam de pelo menos 2 variações (contrato de áudio).
const NEED_VARIANTS := ["swing_light", "swing_heavy", "hit", "hit_heavy", "step", "step_heavy", "cloth",
	"boss_step", "enemy_hurt", "block", "blip_voz", "blip_rei", "blip_sophia", "blip_estela", "blip_npc", "spark",
	# Onda 7: frequentes do conteúdo novo
	"atk_swing", "atk_combo", "atk_shot", "atk_rush", "atk_dive", "fly_fall", "chain", "glass",
	"hz_shard_impact", "hz_spears", "hz_chain_swing", "hz_totem_hit", "double_jump", "eye_hit", "bs_melee"]
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
	doc += "\n" + FileAccess.get_file_as_string(DOC7_PATH)
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
	# ESTABILIDADE (Onda 5): antes era UMA amostra aos 0,35 s — sob carga um
	# quadro longo jogava a amostra para depois da janela (0,55 s + saída) e
	# a música já voltava. Agora amostra TODO quadro até o fim do "hold" e
	# guarda a mais funda: a abaixada tem de aparecer em algum quadro.
	var dm_t0 := Time.get_ticks_msec()
	var b1 := AudioServer.get_bus_volume_db(music_bus)
	while Time.get_ticks_msec() - dm_t0 < int((Audio.DUCK_IN + 0.3) * 1000.0):
		await get_tree().process_frame
		b1 = minf(b1, AudioServer.get_bus_volume_db(music_bus))
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
	# Voltar da pausa (estado PLAYING de novo) no Centro sem cacos NÃO religa
	# a música (pedido da Encenação): nem pelo contexto nem por track_for_screen.
	Audio.play_music("centro", true, 1.0, 0.0)       # como se alguém tivesse religado
	Audio._on_state_changed(GameManager.State.PLAYING)
	await _wait_real(Audio.MUSIC_FADE * 2.0 + 0.3)
	var paused_back: String = Audio._playing_track
	var center_players := 0
	for m in Audio._music:
		if m.playing:
			center_players += 1
	var tfs0: String = Audio.track_for_screen(RunManager.CENTER_FIRST)
	check(paused_back == "" and center_players == 0 and tfs0 == "",
		"Centro sem cacos: voltar da pausa não religa ('%s', %d player; track_for_screen '%s')" % [paused_back, center_players, tfs0])
	Progression.restored_rings.assign(["a", "b"])
	Audio._update_center_music()
	var c2: String = Audio._playing_track
	var tfs2: String = Audio.track_for_screen(RunManager.CENTER_FIRST)
	var l2: float = float(Audio._layer_db.get("centro", 99.0))
	Progression.restored_rings.assign(["a", "b", "c", "d", "e", "f"])
	Audio._update_center_music()
	var l6: float = float(Audio._layer_db.get("centro", 99.0))
	check(c0 == "" and c2 == "centro" and tfs2 == "centro" and absf(l2 - lerpf(-18.0, 0.0, 0.35 + 0.65 * 2.0 / 6.0)) < 0.01 and is_equal_approx(l6, 0.0),
		"Centro: mudo sem cacos ('%s'), 'centro' entra no 1º caco e sobe por caco (2 → %.1f dB, 6 → %.1f dB)" % [c0, l2, l6])
	Progression.restored_rings.assign(keep_restored)
	RunManager.run_active = keep_run
	RunManager.current_screen = keep_screen

	# (b9b) Silêncio antes do chefe (R9): na tela do Arconte a faixa de chefe
	#       espera o stinger; entra ~0,3 s depois dele; voltar da pausa no meio
	#       da luta não refaz o silêncio; a morte do chefe tira a música ~2 s.
	var keep_run3: bool = RunManager.run_active
	var keep_screen3: int = RunManager.current_screen
	var keep_codex3: bool = CodexSession.active
	CodexSession.active = false
	RunManager.run_active = true
	var archon := -1
	for sc in range(2, RunManager.MAX_SCREEN + 1):
		if RunManager.is_archon_screen(sc):
			archon = sc
			break
	var eon_before := -1
	for sc in range(archon - 1, 0, -1):
		if not RunManager.is_boss_screen(sc) and not RunManager.is_center(sc):
			eon_before = sc
			break
	RunManager.current_screen = eon_before
	Audio._on_screen_changed(eon_before)
	await _wait_real(0.1)
	var before_track: String = Audio._playing_track
	RunManager.current_screen = archon
	Audio._on_screen_changed(archon)
	await _wait_real(Audio.PRE_BOSS_FADE + 0.3)
	var hushed_players := 0
	for m in Audio._music:
		if m.playing:
			hushed_players += 1
	var pend: String = Audio.boss_pending
	await _wait_real(0.1)
	Audio.play_sfx("boss_appear")
	var appear_ms := Time.get_ticks_msec()
	var still_pending_early: String = Audio.boss_pending
	# O Audio dispara no 1º quadro depois do prazo (relógio real) e a QA vê no
	# quadro seguinte: o teto ganha 2× o maior intervalo entre quadros medido
	# na espera (carga só atrasa; o PISO continua exato — nunca entra cedo).
	var boss_want := Audio.boss_track(RunManager.eon_index(archon))
	var entry_gap: int = await _poll_until(func() -> bool: return Audio._playing_track == boss_want, 4000)
	var entry_ms := Time.get_ticks_msec() - appear_ms
	check(before_track.begins_with("eon_") and hushed_players == 0 and pend == "boss" and still_pending_early == "boss"
		and Audio._playing_track == "boss" and entry_ms >= int(Audio.BOSS_ENTRY_DELAY * 1000.0) - 20 and entry_ms < 900 + 2 * entry_gap,
		"R9: tela do Arconte (%d) — '%s' sai, %d player tocando antes do stinger, faixa '%s' entra %d ms depois do boss_appear" % [archon, before_track, hushed_players, pend, entry_ms])
	Audio._on_state_changed(GameManager.State.PLAYING)          # voltar da pausa no meio da luta
	await _wait_real(0.1)
	check(Audio.boss_pending == "" and Audio._playing_track == "boss", "R9: voltar da pausa depois do stinger mantém a faixa de chefe (pendente '%s')" % Audio.boss_pending)
	await _wait_real(0.1)
	var k0 := Audio._temp_duck_db
	Audio.play_sfx("boss_die")
	await _wait_real(0.25)
	await get_tree().process_frame
	var k1 := Audio._temp_duck_db
	await _wait_real(Audio.BOSS_KILL_HOLD + Audio.BOSS_KILL_OUT + 0.3)
	var k2 := Audio._temp_duck_db
	check(absf(k0) < 0.05 and k1 < Audio.BOSS_KILL_DB + 1.0 and absf(k2) < 0.05,
		"R9: morte do chefe — música %.1f → %.1f → %.1f dB (some em 150 ms, volta ~2,6 s)" % [k0, k1, k2])
	# Rede de segurança e troca de tela: o recomeço da tela refaz o silêncio.
	Audio._on_screen_changed(archon)
	var re_pending: String = Audio.boss_pending
	check(re_pending == "boss" and Audio.boss_track(0) == ("boss_torpor" if Audio.has_music("boss_torpor") else "boss"),
		"R9: recomeçar a tela do Arconte volta a esperar o stinger; boss_track sem variação instalada = 'boss'")
	Audio._on_state_changed(GameManager.State.MENU)
	RunManager.run_active = keep_run3
	RunManager.current_screen = keep_screen3
	CodexSession.active = keep_codex3

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
	# Onda 7 (R9): sons de recompensa tocados antes abaixam a música por ~1–2 s;
	# espera a abaixada acabar para medir só o slow-mo.
	var sm_t0 := Time.get_ticks_msec()
	while Audio._td_active and Time.get_ticks_msec() - sm_t0 < 4000:
		await get_tree().process_frame
	await _wait_real(0.05)
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
	# Sob carga a amostra "cedo" pode cair DEPOIS do prazo (quadro longo): aí
	# ela não prova nada — quem garante "não cortou cedo" é o piso de cut_ms.
	var early_ms := Time.get_ticks_msec() - t_roubo
	var early_ok: bool = early == "theme" or early_ms >= int(Audio.VOICE_STOLEN_SECS * 1000.0) - 20
	var cut_gap: int = await _poll_until(func() -> bool: return Audio._playing_track == "roubo", int(Audio.VOICE_STOLEN_SECS * 1000.0) + 3000, t_roubo)
	var cut_ms := Time.get_ticks_msec() - t_roubo
	var n_roubo := 0
	for m in Audio._music:
		if m.playing:
			n_roubo += 1
	check(sanct_ok and stolen_ok and early_ok and Audio._playing_track == "roubo" and n_roubo == 1
		and is_equal_approx(Audio._music_pitch, 1.0) and cut_ms >= int(Audio.VOICE_STOLEN_SECS * 1000.0) - 20
		and cut_ms <= int(Audio.VOICE_STOLEN_SECS * 1000.0) + 800 + 2 * cut_gap,
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

	# (b18) Avisos do combate (R5): tom FIXO, bus Tell fora do passa-baixas da
	#       câmera lenta, com pan pela tela; os dois são sons diferentes.
	var tell_ok: bool = Audio.has_sfx("tell_parry") and Audio.has_sfx("tell_unblock") \
		and Audio.variants_of("tell_parry")[0] != Audio.variants_of("tell_unblock")[0]
	var tb := AudioServer.get_bus_index(Audio.TELL_BUS)
	var tell_lp := false
	if tb >= 0:
		for i in AudioServer.get_bus_effect_count(tb):
			tell_lp = tell_lp or AudioServer.get_bus_effect(tb, i) is AudioEffectLowPassFilter
	var tell_pitch := 0.0
	var tell_bus := ""
	Audio.play_sfx("tell_parry", -1.0, 0.0, right_pos)
	for i in Audio._players.size():
		if Audio._pl_name[i] == "tell_parry":
			tell_pitch = Audio._players[i].pitch_scale
			tell_bus = Audio._players[i].bus
	Audio.play_sfx("tell_unblock")
	var unb_bus := ""
	for i in Audio._players.size():
		if Audio._pl_name[i] == "tell_unblock":
			unb_bus = Audio._players[i].bus
	check(tell_ok and tb >= 0 and AudioServer.get_bus_send(tb) == "Master" and not tell_lp
		and is_equal_approx(tell_pitch, 1.0) and tell_bus == "Tell_R2" and unb_bus == Audio.TELL_BUS
		and AudioServer.get_bus_send(AudioServer.get_bus_index("Tell_R2")) == Audio.TELL_BUS,
		"tell_parry/tell_unblock: tom fixo (%.3f), bus próprio sem passa-baixas, pan pela tela (%s / %s)" % [tell_pitch, tell_bus, unb_bus])
	# Vida baixa (R22): UMA batida por pulso, volume do Áudio, sem metralhar.
	#   (espera esvaziar a fila: o cue `heartbeat` do (b16) agendou uma 2ª batida)
	var q_t0 := Time.get_ticks_msec()
	while not Audio._later.is_empty() and Time.get_ticks_msec() - q_t0 < 3000:
		await get_tree().process_frame
	await _wait_real(0.7)
	# Onda 7 (R9): espera a abaixada de momento (recompensa/aparo) terminar.
	var hbw_t0 := Time.get_ticks_msec()
	while Audio._td_active and Time.get_ticks_msec() - hbw_t0 < 4000:
		await get_tree().process_frame
	var td_was: bool = Audio._td_active
	var p1 := Audio.low_health_pulse()
	var p2 := Audio.low_health_pulse()
	var dip_ok: bool = not td_was and Audio._td_active and is_equal_approx(Audio._td_db, Audio.HEART_DIP_DB)
	var hb_db := 99.0
	var hb_newest := -1
	for i in Audio._players.size():
		if Audio._pl_name[i] == "heartbeat" and (hb_newest < 0 or Audio._pl_start[i] > Audio._pl_start[hb_newest]):
			hb_newest = i
	if hb_newest >= 0:
		hb_db = Audio._players[hb_newest].volume_db
	var hb_len: float = Audio.variants_of("heartbeat")[0].get_length()
	check(p1 and not p2 and dip_ok and is_equal_approx(hb_db, Audio.HEART_PULSE_DB) and hb_len < 1.0,
		"low_health_pulse: 1 batida (%.2f s) a %.0f dB, música abre %.0f dB; 2ª chamada no mesmo instante barrada" % [hb_len, hb_db, Audio.HEART_DIP_DB])
	# Intro: o cue `heartbeat` toca 2 batidas, a 2ª agendada por relógio real
	# (mede o INÍCIO de cada disparo: a batida dura 0,75 s, menos que o intervalo).
	await _wait_real(0.1)              # sai da janela do anti-spam do pulso acima
	# A 1ª batida sai NA chamada (síncrona): o registro muda dentro do cue e
	# com carimbo ≥ o relógio de antes da chamada (antes: |Δ| < 50 ms, que uma
	# preempção da thread sob carga estourava). A 2ª: piso exato, teto +2×
	# o maior intervalo entre quadros medido na espera.
	var hb_prev: int = int(Audio._last_play_ms.get("heartbeat", -1))
	var hb_t0 := Time.get_ticks_msec()
	Audio.cue("heartbeat")
	var hb_first_ms: int = int(Audio._last_play_ms.get("heartbeat", -1))
	var hb_sync: bool = hb_first_ms != hb_prev and hb_first_ms >= hb_t0
	var hb_wait: int = await _poll_until(func() -> bool: return int(Audio._last_play_ms.get("heartbeat", -1)) != hb_first_ms, 4000)
	var hb_gap: int = int(Audio._last_play_ms.get("heartbeat", -1)) - hb_first_ms
	check(hb_sync and hb_gap > int(Audio.HEART_GAP * 1000.0) - 300 and hb_gap < int(Audio.HEART_GAP * 1000.0) + 300 + 2 * hb_wait and Audio._later.is_empty(),
		"cue heartbeat: 2 batidas, a 2ª %d ms depois da 1ª (alvo %d ms)" % [hb_gap, int(Audio.HEART_GAP * 1000.0)])

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
	# Só o Centro pode devolver "" (silêncio antes do 1º caco); com caco, `centro`.
	var bad_tracks: Array[String] = []
	var keep_rr: Array[String] = Progression.restored_rings.duplicate()
	for with_shard in [false, true]:
		Progression.restored_rings.assign(["a"] if with_shard else [])
		for s in range(1, RunManager.MAX_SCREEN + 1):
			var t: String = Audio.track_for_screen(s)
			var silent_ok: bool = t == "" and RunManager.is_center(s) and not with_shard
			var optional_ok: bool = Audio.OPTIONAL_MUSIC.has(t) and Audio.has_music(t)
			if not music_names.has(t) and not silent_ok and not optional_ok:
				bad_tracks.append("tela %d (caco=%s) → '%s'" % [s, str(with_shard), t])
	Progression.restored_rings.assign(keep_rr)
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
	# Onda 7: também `sfx("x"` (BossBrain.sfx — só toca nome do catálogo) e
	# `_tell_sound("x"` / `play_sfx_later("x"`.
	re.compile("(?:play_(sfx_at|sfx_pitched|sfx_later|sfx|music)|\\b(?:sfx|_tell_sound))\\(\"([A-Za-z0-9_]+)\"")
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

	# (h) ONDA 7 — golpes, chefes, ganchos por sinal, cena do roubo.
	await _check_onda7(sfx_names)

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


## ONDA 7 (Áudio7): o conteúdo novo das Ondas 5–6 tem som próprio e as rotas
## automáticas (move_sfx, morte em 5 passos, contra-ataque, conquista, roubo)
## funcionam. Os golpes são lidos do CÓDIGO (ids/tipos nos scripts), não de uma
## lista daqui: golpe novo sem som aparece como falha.
func _check_onda7(sfx_names: Array) -> void:
	# (h1) todo TIPO de golpe dos inimigos comuns e dos chefes tem som no strike
	#      (menos os que não ferem/têm som próprio: recuo, explosão = nova).
	var kind_re := RegEx.new()
	kind_re.compile("\"kind\":\\s*\"([a-z_]+)\"")
	var call_re := RegEx.new()
	call_re.compile("\\b_m\\(\"[a-z_0-9]+\",\\s*\"([a-z_]+)\"")
	var kinds: Dictionary = {}
	var moves_src := FileAccess.get_file_as_string("res://scripts/entities/enemies/enemy_moves.gd")
	for m in kind_re.search_all(moves_src) + call_re.search_all(moves_src):
		kinds[m.get_string(1)] = true
	var doc_re := RegEx.new()
	doc_re.compile("##\\s+kind\\s+([a-z ·]+)")
	var dm := doc_re.search(moves_src)
	if dm != null:
		for k in dm.get_string(1).split("·"):
			if k.strip_edges() != "":
				kinds[k.strip_edges()] = true
	var silent_kinds := ["retreat", "explode"]
	var no_kind: Array[String] = []
	for k in kinds:
		if silent_kinds.has(k):
			continue
		var n: String = Audio.move_sound_for({"id": "x", "kind": k}, "wind" if k == "blink" else "strike")
		if n == "" or not Audio.has_sfx(n):
			no_kind.append(k)
	check(kinds.size() >= 15 and no_kind.is_empty(), "todo tipo de golpe de inimigo tem som (%d tipos; sem som: %s)" % [kinds.size(), str(no_kind)])
	# (h2) todo golpe de chefe (id + tipo nos scripts dos chefes) tem som em ALGUMA
	#      etapa (o telegrafo tell_* já existe à parte) — e todo nome resolvido existe.
	var id_re := RegEx.new()
	id_re.compile("\"id\":\\s*\"([a-z_0-9]+)\"[^}]*?\"kind\":\\s*\"([a-z]+)\"")
	var boss_dir := DirAccess.open("res://scripts/entities/bosses")
	var n_moves := 0
	var mute: Array[String] = []
	var bad_name: Array[String] = []
	var kit_sound := ["guarda"]      # a guarda do Astaphaios soa `glass` pelo kit
	if boss_dir != null:
		for f in boss_dir.get_files():
			if not f.ends_with(".gd"):
				continue
			var src := FileAccess.get_file_as_string("res://scripts/entities/bosses/" + f)
			for m in id_re.search_all(src):
				n_moves += 1
				var mv := {"id": m.get_string(1), "kind": m.get_string(2)}
				var any := false
				for stg in ["wind", "strike", "land"]:
					var sn: String = Audio.move_sound_for(mv, stg, true)
					if sn == "":
						continue
					if not Audio.has_sfx(sn):
						bad_name.append("%s/%s→%s" % [mv.id, stg, sn])
					any = true
				if not any and not kit_sound.has(Audio.move_base_id(mv.id)):
					mute.append("%s:%s" % [f.get_basename(), mv.id])
	check(n_moves >= 40 and mute.is_empty() and bad_name.is_empty(),
		"todo golpe de chefe tem som (%d golpes; mudos: %s; nomes sem arquivo: %s)" % [n_moves, str(mute), str(bad_name)])
	check(Audio.move_base_id("guarda3") == "guarda" and Audio.move_base_id("corte_b") == "corte"
		and Audio.move_base_id("corte_real") == "corte_real", "id de golpe normalizado (guarda3→guarda, corte_b→corte, corte_real fica)")
	check(Audio.move_sound_for({"id": "x", "kind": "shot", "homing": 2.0}, "strike") == "atk_homing"
		and Audio.move_sound_for({"id": "x", "kind": "shot", "air": true}, "strike") == "atk_shot_air"
		and Audio.move_sound_for({"id": "x", "kind": "shot", "count": 3}, "strike") == "atk_fan"
		and Audio.move_sound_for({"id": "mordida", "kind": "melee"}, "strike") == "bs_melee"
		and Audio.move_sound_for({"id": "mordida", "kind": "melee"}, "strike", true) == "bs_bite",
		"tiro teleguiado/de cima/leque têm som próprio; id de chefe só vale para chefe")
	# (h3) move_sfx toca de verdade (com posição: pan) e não toca golpe mudo.
	Audio._last_play_ms.erase("atk_rush")
	var played: bool = Audio.move_sfx({"id": "investida", "kind": "rush"}, "strike", Vector2(100, 200))
	var mute_ok: bool = not Audio.move_sfx({"id": "bocejo", "kind": "cast"}, "strike", Vector2.INF, true)
	check(played and Audio.voices_playing("atk_rush") >= 1 and mute_ok, "move_sfx toca o golpe e respeita etapa muda")
	# (h4) morte do chefe em 5 passos: o sinal boss_dying(passo) toca o passo certo.
	var steps_ok := true
	for i in 5:
		var sn: String = Audio.death_step_sfx(i)
		if sn == "" or not Audio.has_sfx(sn):
			steps_ok = false
	var fake := Node2D.new()
	fake.add_user_signal("boss_dying", [{"name": "step", "type": TYPE_INT}])
	add_child(fake)
	await get_tree().process_frame
	fake.emit_signal("boss_dying", 0)
	var impact_ok: bool = Audio.voices_playing("boss_death_impact") >= 1
	fake.emit_signal("boss_dying", 4)
	var shatter_ok: bool = Audio.voices_playing("boss_death_shatter") >= 1
	fake.queue_free()
	check(steps_ok and impact_ok and shatter_ok and Audio.death_step_sfx(5) == "",
		"morte do chefe em 5 passos ligada ao sinal boss_dying (impacto e estilhaço tocaram)")
	# (h5) contra-ataque: sinal da Sophia → riposte_ready no bus Tell, tom fixo.
	var pl := Node.new()
	pl.add_user_signal("riposte_window_opened")
	add_child(pl)
	await get_tree().process_frame
	pl.emit_signal("riposte_window_opened")
	var rip_ok: bool = Audio.voices_playing("riposte_ready") >= 1
	pl.queue_free()
	check(rip_ok and Audio._bus_for("riposte_ready") == Audio.TELL_BUS and Audio._pitch_for("riposte_ready") == 0.0,
		"janela do contra-ataque soa riposte_ready (bus Tell, tom fixo)")
	# (h6) conquista em rajada toca UMA vez; sons de interface no bus UI.
	Audio._last_play_ms.erase("achievement")
	Audio._on_achievement("a")
	Audio._on_achievement("b")
	Audio._on_achievement("c")
	check(Audio.voices_playing("achievement") == 1 and Audio._bus_for("achievement") == "UI"
		and Audio._bus_for("map_select") == "UI" and Audio._bus_for("shop_seal") == "UI",
		"conquista em rajada toca 1 vez; mapa/loja/conquista no bus UI")
	# (h7) roubo: o cue `sink` é o Rei afundando + a rachadura logo depois.
	Audio._last_play_ms.erase("king_sink")
	Audio.cue("sink")
	var sink_ok: bool = Audio.voices_playing("king_sink") >= 1
	await _wait_real(Audio.CRACK_DELAY + 0.25)
	check(sink_ok and Audio.voices_playing("crack_open") >= 1, "cue `sink` do roubo: king_sink e crack_open %.1f s depois" % Audio.CRACK_DELAY)
	# (h8) cargas (VFX7) e sons de informação tocam com tom EXATO.
	var exact_bad: Array[String] = []
	for n in ["charge_light", "charge_dark", "charge_king", "riposte_ready", "achievement", "map_select", "soter_gift"]:
		if Audio._pitch_for(n) != 0.0:
			exact_bad.append(n)
	check(exact_bad.is_empty(), "cargas e sons de informação com tom fixo (%s)" % str(exact_bad))
	# (h9) OBSERVADOR (_Watch): eventos sem sinal tocam na BORDA. Bonecos com as
	#      mesmas propriedades públicas do Enemy/Player (o observador só lê estado).
	var gs := GDScript.new()
	gs.source_code = "extends Node2D\nvar estate: int = 0\nvar _mv: Dictionary = {}\nvar brain = null\nvar _downed: float = 0.0\nvar fly_height: float = 30.0\nvar _champ_fury: bool = false\n"
	gs.reload()
	var foe: Node2D = gs.new()
	add_child(foe)
	await get_tree().physics_frame
	await get_tree().physics_frame
	foe.set("_mv", {"id": "garras", "kind": "combo"})
	foe.set("estate", Enemy.EState.STRIKE)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var w_strike: bool = Audio.voices_playing("atk_combo") >= 1
	foe.set("_downed", 1.4)
	foe.set("_champ_fury", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var w_fall: bool = Audio.voices_playing("fly_fall") >= 1
	var w_fury: bool = Audio.voices_playing("champion_fury") >= 1
	foe.queue_free()
	var gp := GDScript.new()
	gp.source_code = "extends CharacterBody2D\nvar state: int = 0\nvar _air_jumps_left: int = 1\nvar current_move = null\nvar windup_timer: float = 0.0\nvar dive_landed: bool = false\nvar _riposte_t: float = 0.0\n"
	gp.reload()
	var hero: CharacterBody2D = gp.new()
	hero.add_user_signal("riposte_window_opened")
	add_child(hero)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hero.set("_air_jumps_left", 0)            # 2º pulo no ar: o player.gd toca (dono troca na fonte)
	hero.set("_riposte_t", 0.3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hero.set("state", Player.State.ATTACK)
	hero.set("_riposte_t", 0.0)               # contra-ataque saiu: idem, é do player.gd
	await get_tree().physics_frame
	await get_tree().physics_frame
	var w_quiet: bool = Audio.voices_playing("double_jump") == 0 and Audio.voices_playing("riposte") == 0 		and Audio.voices_playing("star_charge") == 0
	hero.queue_free()
	check(w_strike and w_fall and w_fury and w_quiet,
		"observador: golpe (%s), voador cai (%s), fúria (%s); 2º pulo/contra-ataque/carga NÃO dobram (%s)" % [w_strike, w_fall, w_fury, w_quiet])
	# (h10) golpes de inimigo: anti-spam 130 ms e 2 vozes no máximo (R11).
	check(Audio.spam_ms_for("atk_swing") >= 120 and Audio.spam_ms_for("atk_swing") <= 150
		and Audio.max_same_for("atk_shot") == 2 and Audio.max_same_for("hit") == Audio.MAX_SAME,
		"golpes de inimigo atk_*: anti-spam %d ms, %d vozes" % [Audio.spam_ms_for("atk_swing"), Audio.max_same_for("atk_shot")])
	# (h11) R7 — adoçante do combo: sinal combo_changed → tique a partir do 3º
	#       acerto, subindo a pentatônica (teto +16), tom EXATO.
	var curve_ok: bool = Audio.combo_tick_pitch(2) == 0.0 and is_equal_approx(Audio.combo_tick_pitch(3), 1.0) \
		and is_equal_approx(Audio.combo_tick_pitch(5), pow(2.0, 4.0 / 12.0)) \
		and is_equal_approx(Audio.combo_tick_pitch(99), pow(2.0, 16.0 / 12.0))
	var cb := Node.new()
	cb.add_user_signal("combo_changed", [{"name": "count", "type": TYPE_INT}])
	add_child(cb)
	await get_tree().process_frame
	Audio._last_play_ms.erase("combo_tick")
	cb.emit_signal("combo_changed", 2)
	var none_at_2: bool = Audio.voices_playing("combo_tick") == 0
	cb.emit_signal("combo_changed", 5)
	var tick_pitch := 0.0
	for i in Audio._players.size():
		if Audio._pl_name[i] == "combo_tick" and Audio._players[i].playing:
			tick_pitch = Audio._players[i].pitch_scale
	cb.queue_free()
	check(curve_ok and none_at_2 and is_equal_approx(tick_pitch, pow(2.0, 4.0 / 12.0)),
		"R7: tique do combo só a partir do 3º acerto, pentatônica com teto +16, tom exato (5º acerto = %.3f)" % tick_pitch)
	# (h12) R9 — abaixada curta da música nos momentos (−7 dB) e no aparo (−3 dB);
	#       não atropela uma abaixada maior ativa.
	await _wait_real(1.5)
	Audio._last_play_ms.erase("level_clear")
	Audio.play_sfx("level_clear")
	await _wait_real(0.15)
	var lc_db: float = Audio._temp_duck_db
	await _wait_real(2.0)
	Audio._last_play_ms.erase("parry")
	Audio.play_sfx("parry")
	await _wait_real(0.06)
	var pa_db: float = Audio._temp_duck_db
	await _wait_real(0.6)
	Audio.duck_music(5.0, -14.0)
	await _wait_real(0.3)
	Audio._last_play_ms.erase("ring_gain")
	Audio.play_sfx("ring_gain")
	await _wait_real(0.1)
	var keep_db: float = Audio._temp_duck_db
	Audio.duck_music(0.0, 0.0)
	await _wait_real(1.0)
	check(lc_db <= -6.5 and lc_db >= -7.5 and pa_db <= -2.5 and pa_db >= -3.5 and keep_db <= -13.0,
		"R9: level_clear abaixa a música %.1f dB, aparo %.1f dB; uma abaixada maior não é atropelada (%.1f)" % [lc_db, pa_db, keep_db])


## Espera `sec` segundos de relógio REAL, atravessando quadros (não um timer
## que pode disparar no mesmo quadro em que nasceu).
## ESTABILIDADE (Onda 5): + 1 quadro no fim. O `process_frame` acorda a QA
## ANTES do `_process` do Audio daquele quadro; sem o quadro extra a QA lia o
## envelope do quadro ANTERIOR — sob carga (quadros de 100+ ms) esse quadro
## era antes do prazo e o slow-mo aparecia pela metade (1890 Hz em vez de 1500).
func _wait_real(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
	await get_tree().process_frame


## ESTABILIDADE (Onda 5): espera `cond` quadro a quadro (teto `max_ms` de
## relógio contado de `t0`, ou de agora) e devolve o MAIOR intervalo entre
## quadros visto na espera (ms) — a folga honesta de medição: o Audio só
## dispara no 1º quadro depois do prazo e a QA só vê no seguinte.
func _poll_until(cond: Callable, max_ms: int, t0: int = -1) -> int:
	var start := Time.get_ticks_msec() if t0 < 0 else t0
	var last := Time.get_ticks_msec()
	var gap := 0
	while not cond.call() and Time.get_ticks_msec() - start < max_ms:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		gap = maxi(gap, now - last)
		last = now
	return gap


func _collect_gd(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(path.path_join(f))
	for d in dir.get_directories():
		_collect_gd(path.path_join(d), out)
