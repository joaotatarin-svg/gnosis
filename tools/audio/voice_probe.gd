extends Node
## SONDA DA DUBLAGEM (Áudio7, Onda 7) — headless, sem tocar som no PC.
## Monta um manifesto de TESTE (user://voice_probe_manifest.json) que liga 4 falas
## reais do roteiro às amostras da Dublagem e confere, pelo estado do Audio:
##   (v1) id da fala = sha1(falante|texto)[:12] igual ao do pipeline;
##   (v2) DialogueBox: fala com voz toca, sem blips, texto e voz terminam juntos
##        (±0,3 s), espera o jogador (não avança sozinha), avanço livre desde o 1º
##        quadro: 1º aperto completa o texto e corta a voz (80 ms), 2º avança; fala
##        sem voz volta ao blip; wait_2s não trava fala dublada; dono apagado = voz some;
##   (v3) ducking: música −8 / ambiência −6 "vale o maior", e voltam sem voz;
##   (v4) legenda (CaptionBar): dura ≥ voz + 0,4 s, sem blips, sair corta a voz;
##        escondida (pausa) = voz congelada;
##   (v5) card do prólogo: segura o card enquanto a voz fala; avançar corta;
##   (v6) aviso tell_unblock: voz −8 dB + passa-altas; voz de luta nova espera
##        400 ms depois do aviso, golpe avisado no ar (+0,3 s) e o stinger do chefe
##        (+0,5 s); sem folga por 3 s = descartada; efeitos de luta NÃO baixam;
##   (v7) slider Vozes = 0 desliga a dublagem (volta o blip); bus Voice → Master.
## Uso (SEMPRE com o driver mudo):
##   godot --headless --audio-driver Dummy --path . res://tools/audio/VoiceProbe.tscn
##   GNOSIS_VOICE_SAMPLES=<pasta> troca a pasta das amostras (padrão abaixo).
## Imprime "VOICE PROBE: N falhas" e sai com 0 (ok) ou 1.

const SAMPLES := "C:/gnosis-wt/_caps/dublagem/amostras/"
const TEST_MANIFEST := "user://voice_probe_manifest.json"
const WATCHDOG_S := 150.0
## Falas curtas do roteiro (amostras ≤ 2,5 s) para a guarda de frequência da luta.
const SHORT_A := {"speaker": "Sophia", "text": "Eu também queria deitar. ...Não vou."}
const SHORT_B := {"speaker": "Velkar", "text": "Todo dia. Era meu pai."}
const SHORT_C := {"speaker": "Harmas", "text": "Dá-me uma! Uma lembrança que seja minha!"}

var fails: int = 0
var _dir: String = SAMPLES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# rede de segurança: um erro no meio de um await não deixa a sonda pendurada
	get_tree().create_timer(WATCHDOG_S, true, false, true).timeout.connect(func() -> void:
		push_error("VOICE FAIL: sonda passou de %d s (travou)" % int(WATCHDOG_S))
		print("VOICE PROBE: TEMPO ESGOTADO")
		get_tree().quit(1))
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if condition:
		print("VOICE PASS: ", message)
	else:
		fails += 1
		push_error("VOICE FAIL: " + message)


func _wait_real(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame


func _bus_db(n: String) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(n))


func _press(target: Node) -> void:
	var ev := InputEventAction.new()
	ev.action = "jump"
	ev.pressed = true
	target.call("_unhandled_input", ev)
	await get_tree().process_frame


## A fala do roteiro com este texto (prova que é fala REAL, não escrita aqui).
func _find(lines: Array, needle: String) -> Dictionary:
	for l in lines:
		if l is Dictionary and String(l.get("text", "")).contains(needle):
			return l
	return {}


func _run() -> void:
	var env_dir := OS.get_environment("GNOSIS_VOICE_SAMPLES")
	if env_dir != "":
		_dir = env_dir.replace("\\", "/").trim_suffix("/") + "/"
	_check_real_manifest()
	# (c) padrão 80 %: save sem `vol_voice` (ou sem save) carrega 0,8
	var saved = SaveManager.read_json_safe(SaveManager.SAVE_PATH).data if SaveManager.has_method("read_json_safe") else null
	var has_saved_voice: bool = saved is Dictionary and (saved as Dictionary).has("vol_voice")
	check(has_saved_voice or is_equal_approx(Audio.voice_vol, 0.8),
		"Vozes no boot = %d %% (save %s vol_voice; padrão 80 %%)" % [int(round(Audio.voice_vol * 100.0)), "COM" if has_saved_voice else "sem"])
	var voz: Dictionary = _find(Narrative.intro(), "Acorda. ...Isso.")
	var rei: Dictionary = _find(Narrative.king_intro(), "Faísca perdida")
	var cap: Dictionary = _find(Narrative.walk_arrival(1), "Uma pedra escrita")
	var card_text := String((Cinematic.prologue().cards[0] as Dictionary).get("text", ""))
	# o prologue() acima já entrou na árvore (deferred): some antes de começar
	await get_tree().process_frame
	for n in get_tree().root.get_children():
		if n is Cinematic:
			n.queue_free()
	await get_tree().process_frame
	check(not voz.is_empty() and not rei.is_empty() and not cap.is_empty() and card_text != "",
		"falas reais achadas no Narrative/Cinematic (intro, king_intro, walk_arrival(1), prólogo)")

	# (v1) ids iguais aos do pipeline (tools/voice/extract_lines.py → roteiro.json)
	check(Audio.voice_id("A Voz", "Acorda. ...Isso. Devagar. Eu estou aqui.") == "d6059a40ad2f",
		"id da fala = sha1(falante|texto)[:12] (A Voz/intro = d6059a40ad2f do roteiro)")
	check(Audio.voice_id("card", card_text) == "a4f2a4baab4a", "id do card do prólogo = a4f2a4baab4a do roteiro")

	# manifesto de TESTE (formato do contrato) apontando para as amostras
	var files := {"voz": _dir + "a_voz_pt_1.ogg", "rei": _dir + "o_rei_pt_1.ogg",
		"cap": _dir + "sophia_pt_3.ogg", "card": _dir + "narrador_pt_1.ogg",
		"sa": _dir + "sophia_pt_1.ogg", "sb": _dir + "velkar_pt_2.ogg", "sc": _dir + "velkar_pt_2.ogg"}   # sc: arquivo emprestado (só id distinto importa)
	check(Audio.voice_id("Sophia", String(SHORT_A["text"])) == "a250454c1893" and Audio.voice_id("Velkar", String(SHORT_B["text"])) == "baf76ea82434",
		"falas curtas de luta com os ids do roteiro (a250454c1893, baf76ea82434)")
	for k in files:
		if not FileAccess.file_exists(String(files[k])):
			# outra máquina / amostras apagadas: só o manifesto real e os ids valem
			print("VOICE INFO: sem a amostra %s — testes com voz PULADOS (só manifesto real e ids)" % files[k])
			_end()
			return
	var man := {"version": 1, "lufs": -18.0, "lines": {
		Audio.voice_id(String(voz["speaker"]), String(voz["text"])): {"speaker": voz["speaker"], "pt": {"file": files["voz"]}},
		Audio.voice_id(String(rei["speaker"]), String(rei["text"])): {"speaker": rei["speaker"], "pt": {"file": files["rei"]}},
		Audio.voice_id(String(cap["speaker"]), String(cap["text"])): {"speaker": cap["speaker"], "pt": {"file": files["cap"]}},
		Audio.voice_id("card", card_text): {"speaker": "card", "pt": {"file": files["card"]}},
		Audio.voice_id("Sophia", String(SHORT_A["text"])): {"speaker": "Sophia", "pt": {"file": files["sa"]}},
		Audio.voice_id("Velkar", String(SHORT_B["text"])): {"speaker": "Velkar", "pt": {"file": files["sb"]}},
		Audio.voice_id("Harmas", String(SHORT_C["text"])): {"speaker": "Harmas", "pt": {"file": files["sc"]}},
	}}
	var f := FileAccess.open(TEST_MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(man, "\t"))
	f.close()
	OS.set_environment("GNOSIS_VOICE_MANIFEST", ProjectSettings.globalize_path(TEST_MANIFEST))
	Audio.reload_voice_manifest()
	Audio.set("_log_path", ProjectSettings.globalize_path("user://voice_probe_log.json"))   # conta os blips
	check(Audio.voice_manifest().size() == 7, "manifesto de teste lido (7 falas → amostras)")
	check(not Audio.voice_entry(voz).is_empty() and Audio.voice_entry({"speaker": "A Voz", "text": "fala que não existe"}).is_empty(),
		"voice_entry acha a fala mapeada e devolve {} para fala sem arquivo")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "Master", "bus Voice direto no Master")

	await _check_dialogue(voz)
	await _check_caption(cap)
	await _check_card()
	await _check_tell(rei)
	await _check_combat_guard(rei)
	await _check_off(voz)
	_end()


## (v0) o manifesto DE VERDADE (lotes da Dublagem): lê, e cada arquivo listado
## existe e carrega como áudio com duração > 0. Lote quebrado = falha aqui.
func _check_real_manifest() -> void:
	Audio.reload_voice_manifest()
	var man: Dictionary = Audio.voice_manifest()
	var n := 0
	var bad: Array = []
	for id in man:
		var e = man[id]
		if not (e is Dictionary):
			bad.append(str(id))
			continue
		for lang in ["pt", "en"]:
			var le = (e as Dictionary).get(lang)
			if not (le is Dictionary):
				continue
			n += 1
			var s: AudioStream = Audio.call("_voice_stream", String((le as Dictionary).get("file", "")))
			if s == null or s.get_length() <= 0.0:
				bad.append("%s/%s" % [id, lang])
	print("VOICE INFO: manifesto real (%s): %d falas, %d arquivos" % [Audio.VOICE_MANIFEST, man.size(), n])
	check(bad.is_empty(), "manifesto real: todo arquivo listado existe e carrega (ruins: %s)" % str(bad.slice(0, 8)))


## (v2)(v3) caixa de diálogo
func _check_dialogue(voz: Dictionary) -> void:
	await _wait_real(1.0)   # nenhum ducking sobrando
	var music0 := _bus_db("Music")
	var amb0 := _bus_db("Ambience")
	var blips0 := int(Audio.played_counts.get("blip_voz", 0))
	var nov := {"speaker": "A Voz", "text": "Fala de teste sem arquivo de voz, com blips."}
	var box: DialogueBox = DialogueBox.play([voz, nov])
	await get_tree().process_frame
	await get_tree().process_frame
	var dur: float = float(box.get("_voice_dur"))
	check(box.has_voice() and dur > 0.5 and Audio.is_voice_playing(box), "caixa: fala com voz TOCA (%.2f s)" % dur)
	await _wait_real(0.6)
	var music1 := _bus_db("Music")
	var amb1 := _bus_db("Ambience")
	# Guardião §19 "vale o maior": o diálogo já tira 9 dB da música (> 8 da voz) → a voz não soma;
	# ambiência: diálogo −5, voz −6 → fica em −6.
	check(Audio.voice_duck_amount() > 0.95 and absf((music1 - music0) + 9.0) < 0.3 and absf((amb1 - amb0) + 6.0) < 0.3,
		"caixa + voz: música %.1f → %.1f dB (−9, sem empilhar), ambiência %.1f → %.1f (−6)" % [music0, music1, amb0, amb1])
	check(int(Audio.played_counts.get("blip_voz", 0)) == blips0, "caixa: fala dublada NÃO toca blips")
	check(box.is_typing(), "caixa: texto ainda digitando aos 0,6 s (anda no ritmo da voz)")
	# texto e voz terminam juntos (±0,3 s — Guardião §3); a caixa NÃO avança sozinha
	var t_type := -1.0
	var t_voice := -1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int((dur + 1.0) * 1000.0) and (t_type < 0.0 or t_voice < 0.0):
		await get_tree().process_frame
		var tt := float(Time.get_ticks_msec() - t0) / 1000.0 + 0.6
		if t_type < 0.0 and not box.is_typing():
			t_type = tt
		if t_voice < 0.0 and not Audio.is_voice_playing(box):
			t_voice = tt
	check(t_type > 0.0 and t_voice > 0.0 and absf(t_type - t_voice) <= 0.3,
		"caixa: texto termina %.2f s, voz %.2f s (diferença %.2f ≤ 0,3)" % [t_type, t_voice, absf(t_type - t_voice)])
	await _wait_real(0.5)
	check(not Audio.is_voice_playing(box) and is_instance_valid(box) and box.idx == 0,
		"caixa: voz acabou e a caixa ESPERA o jogador (fala 0 ainda na tela)")
	await _wait_real(0.8)
	check(Audio.voice_duck_amount() < 0.05, "caixa: ducking da voz solta quando a voz acaba (%.2f)" % Audio.voice_duck_amount())
	box.queue_free()
	await _wait_real(1.2)

	# de novo, AVANÇANDO no meio da voz: 1º aperto completa o texto E corta a voz (80 ms), 2º avança
	box = DialogueBox.play([voz, nov])
	await get_tree().process_frame
	await get_tree().process_frame
	await _press(box)           # avanço livre desde o 1º quadro (Guardião §2)
	var db_mid: float = Audio.voice_player_db()
	await _wait_real(0.12)
	check(not box.is_typing() and not Audio.is_voice_playing(box) and box.idx == 0,
		"1º aperto (no 2º quadro): fala inteira na tela e a voz sai (fade %.2f s; no meio %.1f dB)" % [box.VOICE_CUT, db_mid])
	await _press(box)
	await get_tree().process_frame
	check(box.idx == 1 and not box.has_voice(), "2º aperto: avança para a fala seguinte (sem arquivo → sem voz)")
	box.queue_free()
	await _wait_real(0.6)
	# (b) DECISÃO DO CHEFE: texto já completo e a voz ainda soando → UM aperto corta a voz E avança
	box = DialogueBox.play([voz, nov])
	await _wait_real(0.3)
	box.reveal_all()            # texto completo (instantâneo), voz no meio
	var still: bool = Audio.is_voice_playing(box)
	await _press(box)
	await _wait_real(0.12)
	check(still and box.idx == 1 and not Audio.is_voice_playing(box),
		"texto completo + voz soando: UM aperto corta a voz (80 ms) E avança (idx %d)" % box.idx)
	await _wait_real(1.0)
	check(int(Audio.played_counts.get("blip_voz", 0)) > blips0, "fala sem voz: blips de sempre (%d)" % (int(Audio.played_counts.get("blip_voz", 0)) - blips0))
	for i in 3:                # completa (se ainda digitava) e fecha
		if is_instance_valid(box) and not box.is_queued_for_deletion():
			await _press(box)
	await _wait_real(0.3)
	check(not is_instance_valid(box) or box.is_queued_for_deletion(), "caixa fecha normalmente depois da fala sem voz")
	# fala dublada com cue wait_2s: o avanço NÃO fica travado
	var w := voz.duplicate()
	w["cue"] = "wait_2s"
	box = DialogueBox.play([w])
	await _wait_real(0.2)
	check(not bool(box.call("_waiting")), "fala dublada ignora o wait_2s (avanço livre)")
	box.queue_free()
	# dono apagado sem cortar: a voz não vaza
	var tmp := Node.new()
	add_child(tmp)
	await _wait_real(0.8)
	Audio.play_voice(voz, tmp)
	await _wait_real(0.2)
	tmp.free()
	await _wait_real(0.3)
	check(not Audio.is_voice_playing(), "dono apagado (troca de cena): a voz some com fade")
	await _wait_real(1.0)


## (v4) legenda
func _check_caption(cap: Dictionary) -> void:
	var bar := CaptionBar.new()
	add_child(bar)
	await get_tree().process_frame
	bar.set_process(false)        # fora de uma Level a fila se esvazia; aqui a sonda dirige
	var w0 := Time.get_ticks_msec()
	while (Audio.is_ducked() or Audio.get("_duck") > 0.001) and Time.get_ticks_msec() - w0 < 3000:
		await get_tree().process_frame   # o ducking da caixa anterior solta antes da medida
	var blips0 := int(Audio.played_counts.get("blip_sophia", 0))
	var sfx0 := _bus_db("SFX")
	var tell0 := _bus_db("Tell")
	var music0 := _bus_db("Music")
	bar.call("_show", cap)
	var vd: float = float(bar.get("_voice_dur"))
	var tl: float = float(bar.get("_time_left"))
	check(vd > 0.5 and Audio.is_voice_playing(bar), "legenda: voz toca (%.2f s)" % vd)
	check(tl >= vd + 0.4 - 0.001, "legenda: fica no ar ≥ voz + 0,4 s (%.2f ≥ %.2f)" % [tl, vd + 0.4])
	for i in 20:
		bar.call("_type", 0.05)
	check(int(Audio.played_counts.get("blip_sophia", 0)) == blips0, "legenda dublada: sem blips")
	await _wait_real(0.6)
	check(absf(_bus_db("Music") - music0 + 8.0) < 0.3 and absf(_bus_db("SFX") - sfx0) < 0.1 and absf(_bus_db("Tell") - tell0) < 0.1,
		"legenda + voz: música %.1f→%.1f (−8), efeitos %.1f→%.1f e Tell %.1f INTOCADOS (Guardião §19)" % [music0, _bus_db("Music"), sfx0, _bus_db("SFX"), _bus_db("Tell")])
	Audio.pause_voice(bar, true)
	await _wait_real(0.1)
	check(not Audio.is_voice_playing(bar), "legenda escondida (pausa): voz congelada")
	Audio.pause_voice(bar, false)
	await _wait_real(0.1)
	check(Audio.is_voice_playing(bar), "legenda volta: voz continua")
	bar.call("_hide")
	await _wait_real(0.25)
	check(not Audio.is_voice_playing(), "legenda saiu: voz cortada")
	bar.queue_free()
	await _wait_real(1.0)


## (v5) card do prólogo
func _check_card() -> void:
	var c := Cinematic.prologue()
	await _wait_real(0.3)
	var t0 := Time.get_ticks_msec()
	check(Audio.is_voice_playing(c), "card do prólogo: voz do narrador toca")
	var card_time := float((c.cards[0] as Dictionary).get("time", 5.0)) + float((c.cards[0] as Dictionary).get("fade_in", 0.45))
	var vlen: float = (Audio._dub[Audio._dub_cur].stream as AudioStream).get_length()
	if vlen > card_time + 0.3:
		await _wait_real(card_time + 0.2 - 0.3)
		check(int(c.get("_idx")) == 0 and Audio.is_voice_playing(c), "card segura enquanto a voz fala (%.1f s > tempo do card %.1f s)" % [vlen, card_time])
	else:
		print("VOICE INFO: voz do card (%.1f s) cabe no tempo do card (%.1f s)" % [vlen, card_time])
	c.set("_advance", true)
	await _wait_real(0.3)
	check(not Audio.is_voice_playing(c), "avançar o card corta a voz")
	c.set("_skip_all", true)
	c.set("_advance", true)
	await _wait_real(1.5)
	check(not is_instance_valid(c) and not Audio.is_voice_playing(), "pular o prólogo: nenhuma voz de card fica no ar")
	print("VOICE INFO: card levou %d ms" % (Time.get_ticks_msec() - t0))
	await _wait_real(0.8)


## (v6) proteção do aviso
func _check_tell(rei: Dictionary) -> void:
	var bar := Node.new()     # dono qualquer (voz de "luta": árvore rodando)
	add_child(bar)
	var d := Audio.play_voice(rei, bar)
	await _wait_real(0.2)
	var v0 := _bus_db("Voice")
	check(Audio.play_sfx("tell_unblock"), "tell_unblock tocou")
	await _wait_real(0.05)
	var v1 := _bus_db("Voice")
	var hpf_on := false
	var vi := AudioServer.get_bus_index("Voice")
	for i in AudioServer.get_bus_effect_count(vi):
		if AudioServer.get_bus_effect(vi, i) is AudioEffectHighPassFilter:
			hpf_on = AudioServer.is_bus_effect_enabled(vi, i) and (AudioServer.get_bus_effect(vi, i) as AudioEffectHighPassFilter).cutoff_hz > 200.0
	check(Audio.voice_tell_guard() > 0.95 and v1 < v0 - 7.5 and hpf_on,
		"tell_unblock: voz %.1f → %.1f dB + passa-altas 250 Hz ligado (%s)" % [v0, v1, str(hpf_on)])
	Audio.stop_voice(bar, 0.0)
	# voz de luta pedida logo depois do aviso: espera a folga de 400 ms
	var d2 := Audio.play_voice(rei, bar)
	var raw: float = (Audio._dub[Audio._dub_cur].stream as AudioStream).get_length()
	check(d2 >= raw + 0.3 and not Audio._dub[Audio._dub_cur].playing,
		"voz nova logo após o aviso espera a folga (%.2f s de espera)" % (d2 - raw))
	var t0 := Time.get_ticks_msec()
	while not Audio._dub[Audio._dub_cur].playing and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().process_frame
	check(Audio._dub[Audio._dub_cur].playing, "…e começa depois dela (%d ms)" % (Time.get_ticks_msec() - t0))
	await _wait_real(0.8)
	check(Audio.voice_tell_guard() < 0.05, "fim do aviso: a voz volta ao volume")
	Audio.stop_voice(bar, 0.0)
	await _wait_real(0.6)
	# golpe avisado no ar (windup→strike): a voz de luta espera; acaba o golpe → +0,3 s e começa
	var t1 := Time.get_ticks_msec()
	Audio._mark_danger(Vector2.ZERO)
	Audio.play_voice(rei, bar)
	while Time.get_ticks_msec() - t1 < 1000:
		Audio._mark_danger(Vector2.ZERO)
		await get_tree().process_frame
	var held: bool = Audio.is_voice_pending(bar) and not Audio._dub[Audio._dub_cur].playing
	var t2 := Time.get_ticks_msec()
	while Audio.is_voice_pending(bar) and Time.get_ticks_msec() - t2 < 2000:
		await get_tree().process_frame
	var lag := Time.get_ticks_msec() - t2
	check(held and Audio._dub[Audio._dub_cur].playing and lag >= 250 and lag <= 450,
		"golpe avisado no ar: a voz espera (1 s) e começa %d ms depois do golpe (Guardião §10)" % lag)
	Audio.stop_voice(bar, 0.0)
	await _wait_real(0.5)
	# luta sem folga por > 3 s: desiste da voz (a legenda fica só com texto)
	Audio._mark_danger(Vector2.ZERO)
	Audio.play_voice(rei, bar)
	var t3 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t3 < 4500:
		Audio._mark_danger(Vector2.ZERO)
		await get_tree().process_frame
	check(not Audio.is_voice_pending(bar) and not Audio.is_voice_playing(bar), "luta sem folga por 4 s: a voz é descartada (nunca empilha)")
	await _wait_real(0.5)
	# stinger do chefe: nenhuma voz por cima nem 0,5 s depois
	Audio._last_play_ms.erase("boss_appear")
	var stung: bool = Audio.play_sfx("boss_appear")
	Audio.play_voice(rei, bar)
	var t4 := Time.get_ticks_msec()
	while Audio.is_voice_pending(bar) and Time.get_ticks_msec() - t4 < 6000:
		await get_tree().process_frame
	var sting_len := 99.0
	for v in Audio.variants_of("boss_appear"):
		sting_len = minf(sting_len, (v as AudioStream).get_length())   # a variação tocada pode ser a menor
	var waited := float(Time.get_ticks_msec() - t4) / 1000.0
	check(not stung or (waited >= sting_len + 0.45 and Audio.is_voice_playing(bar)), "stinger do chefe (%.2f s): a voz espera %.2f s (≥ stinger + 0,5)" % [sting_len, waited])
	Audio.stop_voice(bar, 0.0)
	bar.queue_free()
	print("VOICE INFO: voz do Rei %.2f s" % d)
	await _wait_real(0.8)


## (a) guarda de frequência das vozes de LUTA (Guardião §9)
func _check_combat_guard(rei: Dictionary) -> void:
	var bar := Node.new()
	add_child(bar)
	Audio.reset_combat_voices()
	await _wait_real(0.6)        # sem aviso/golpe/stinger no ar
	Audio.set("_danger_until_us", 0)
	Audio.set("_tell_until_us", 0)
	var lens: Array = []
	for l in [SHORT_A, SHORT_B, SHORT_C]:
		var st: AudioStream = Audio.call("_voice_stream", String(Audio.voice_entry(l).get("file", "")))
		lens.append(st.get_length() if st != null else 99.0)
	check(float(lens.max()) <= 2.5, "amostras curtas ≤ 2,5 s (%s)" % str(lens))
	# fala de luta longa (> 2,5 s): só legenda
	check(Audio.play_voice(rei, bar, true) == 0.0 and not Audio.is_voice_playing(),
		"voz de LUTA de 7,7 s (> 2,5 s): não toca, só legenda")
	check(Audio.play_voice(rei, bar, false) > 2.5, "a mesma fala FORA da luta (cena) toca normalmente")
	Audio.stop_voice(bar, 0.0)
	Audio.reset_combat_voices()
	check(Audio.play_voice(SHORT_A, bar, true) > 0.0, "voz de luta curta toca")
	Audio.stop_voice(bar, 0.0)
	check(Audio.play_voice(SHORT_B, bar, true) == 0.0, "outra voz de luta logo depois: barrada (≥ 8 s de silêncio)")
	var now := Time.get_ticks_usec()
	Audio.set("_combat_voice_end_us", now - 7900000)
	check(Audio.play_voice(SHORT_B, bar, true) == 0.0, "7,9 s depois: ainda barrada")
	Audio.set("_combat_voice_end_us", now - 8100000)
	check(Audio.play_voice(SHORT_B, bar, true) > 0.0, "8,1 s depois: toca")
	Audio.stop_voice(bar, 0.0)
	Audio.set("_combat_voice_end_us", now - 9000000)
	check(Audio.play_voice(SHORT_A, bar, true) == 0.0, "a mesma fala 2x na mesma luta: barrada")
	Audio.set("_combat_voices", 6)
	check(Audio.combat_voices_left() == 0 and Audio.play_voice(SHORT_C, bar, true) == 0.0,
		"7ª voz de luta na tela: barrada (máx. 6 por luta)")
	var keep_screen: int = RunManager.current_screen
	RunManager.current_screen = RunManager.MAX_SCREEN
	var left_final: int = Audio.combat_voices_left()
	RunManager.current_screen = keep_screen
	check(RunManager.screen_role(RunManager.MAX_SCREEN) == "final" and left_final == 2,
		"batalha final: até 8 vozes de luta (sobram %d de 8 depois de 6)" % left_final)
	Audio.reset_combat_voices()
	check(Audio.play_voice(SHORT_C, bar, true) > 0.0, "tela nova (reset): a contagem zera")
	Audio.stop_voice(bar, 0.0)
	# legenda de luta cuja voz foi barrada: só legenda (sem voz e sem blips)
	var cb := CaptionBar.new()
	add_child(cb)
	await get_tree().process_frame
	cb.set_process(false)
	cb.set("_hot", true)
	var b0 := int(Audio.played_counts.get("blip_sophia", 0))
	cb.call("_show", SHORT_A)   # logo depois de outra voz de luta → barrada
	for i in 20:
		cb.call("_type", 0.05)
	check(float(cb.get("_voice_dur")) == 0.0 and bool(cb.get("_voice_refused")) and int(Audio.played_counts.get("blip_sophia", 0)) == b0,
		"legenda de luta com voz barrada: só o texto (sem voz, sem blips)")
	cb.queue_free()
	bar.queue_free()
	Audio.reset_combat_voices()
	await _wait_real(0.5)


## (v7) vozes desligadas
func _check_off(voz: Dictionary) -> void:
	var keep: float = Audio.voice_vol
	Audio.set_volume("Voice", 0.0)
	check(Audio.play_voice(voz, self) == 0.0 and not Audio.is_voice_playing(), "Vozes = 0: sem dublagem (a caixa volta aos blips)")
	var box: DialogueBox = DialogueBox.play([voz])
	await _wait_real(0.6)
	check(not box.has_voice() and int(Audio.played_counts.get("blip_voz", 0)) > 0, "Vozes = 0: caixa com blips")
	box.queue_free()
	Audio.set_volume("Voice", keep)
	await _wait_real(0.3)
	check(absf(_bus_db("Voice") - linear_to_db(keep)) < 0.2, "slider Vozes volta (%.1f dB)" % _bus_db("Voice"))
	check(is_equal_approx(float(SaveManager.DEFAULT_VOLUMES.get("Voice", -1.0)), 0.8) and is_equal_approx(Audio.VOICE_DEFAULT_VOL, 0.8),
		"slider Vozes: padrão 80 %% (Guardião §18), salvo como vol_voice")


func _end() -> void:
	OS.set_environment("GNOSIS_VOICE_MANIFEST", "")
	Audio.set("_log_path", "")
	print("VOICE PROBE: %d falhas" % fails)
	get_tree().quit(0 if fails == 0 else 1)
