extends Node
## SONDA DA DUBLAGEM (Áudio7, Onda 7) — headless, sem tocar som no PC.
## Monta um manifesto de TESTE (user://voice_probe_manifest.json) que liga 4 falas
## reais do roteiro às amostras da Dublagem e confere, pelo estado do Audio:
##   (v1) id da fala = sha1(falante|texto)[:12] igual ao do pipeline;
##   (v2) DialogueBox: fala com voz toca, sem blips, texto no ritmo da voz,
##        espera o jogador (não avança sozinha), 1º aperto mostra tudo, 2º corta
##        a voz com fade e avança; fala sem voz volta ao blip sem erro;
##   (v3) ducking: música/ambiência descem com voz e voltam sem ela;
##   (v4) legenda (CaptionBar): dura ≥ voz + 0,4 s, sem blips, sair corta a voz;
##        escondida (pausa) = voz congelada;
##   (v5) card do prólogo: segura o card enquanto a voz fala; avançar corta;
##   (v6) aviso tell_unblock: voz −8 dB + passa-altas; voz de luta nova espera
##        400 ms depois do aviso; efeitos (SFX) descem 3 dB na legenda, o Tell não;
##   (v7) slider Vozes = 0 desliga a dublagem (volta o blip); bus Voice → Master.
## Uso (SEMPRE com o driver mudo):
##   godot --headless --audio-driver Dummy --path . res://tools/audio/VoiceProbe.tscn
##   GNOSIS_VOICE_SAMPLES=<pasta> troca a pasta das amostras (padrão abaixo).
## Imprime "VOICE PROBE: N falhas" e sai com 0 (ok) ou 1.

const SAMPLES := "C:/gnosis-wt/_caps/dublagem/amostras/"
const TEST_MANIFEST := "user://voice_probe_manifest.json"

var fails: int = 0
var _dir: String = SAMPLES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		"cap": _dir + "sophia_pt_3.ogg", "card": _dir + "narrador_pt_1.ogg"}
	for k in files:
		if not FileAccess.file_exists(String(files[k])):
			check(false, "amostra existe: %s" % files[k])
			_end()
			return
	var man := {"version": 1, "lufs": -18.0, "lines": {
		Audio.voice_id(String(voz["speaker"]), String(voz["text"])): {"speaker": voz["speaker"], "pt": {"file": files["voz"]}},
		Audio.voice_id(String(rei["speaker"]), String(rei["text"])): {"speaker": rei["speaker"], "pt": {"file": files["rei"]}},
		Audio.voice_id(String(cap["speaker"]), String(cap["text"])): {"speaker": cap["speaker"], "pt": {"file": files["cap"]}},
		Audio.voice_id("card", card_text): {"speaker": "card", "pt": {"file": files["card"]}},
	}}
	var f := FileAccess.open(TEST_MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(man, "\t"))
	f.close()
	OS.set_environment("GNOSIS_VOICE_MANIFEST", ProjectSettings.globalize_path(TEST_MANIFEST))
	Audio.reload_voice_manifest()
	Audio.set("_log_path", ProjectSettings.globalize_path("user://voice_probe_log.json"))   # conta os blips
	check(Audio.voice_manifest().size() == 4, "manifesto de teste lido (4 falas → amostras)")
	check(not Audio.voice_entry(voz).is_empty() and Audio.voice_entry({"speaker": "A Voz", "text": "fala que não existe"}).is_empty(),
		"voice_entry acha a fala mapeada e devolve {} para fala sem arquivo")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")) == "Master", "bus Voice direto no Master")

	await _check_dialogue(voz)
	await _check_caption(cap)
	await _check_card()
	await _check_tell(rei)
	await _check_off(voz)
	_end()


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
	check(Audio.voice_duck_amount() > 0.95 and music1 < music0 - 11.0 and _bus_db("Ambience") < amb0 - 6.0,
		"caixa + voz: música %.1f → %.1f dB (−9 do diálogo −3 da voz), ambiência %.1f → %.1f" % [music0, music1, amb0, _bus_db("Ambience")])
	check(int(Audio.played_counts.get("blip_voz", 0)) == blips0, "caixa: fala dublada NÃO toca blips")
	check(box.is_typing(), "caixa: texto ainda digitando aos 0,6 s (anda no ritmo da voz)")
	# espera a voz quase acabar: o texto terminou junto, a caixa NÃO avança sozinha
	await _wait_real(maxf(0.1, dur - 0.6))
	check(not box.is_typing(), "caixa: texto completo antes do fim da voz")
	await _wait_real(0.8)
	check(not Audio.is_voice_playing(box) and is_instance_valid(box) and box.idx == 0,
		"caixa: voz acabou e a caixa ESPERA o jogador (fala 0 ainda na tela)")
	await _wait_real(0.7)
	check(Audio.voice_duck_amount() < 0.05, "caixa: ducking da voz solta quando a voz acaba (%.2f)" % Audio.voice_duck_amount())
	box.queue_free()
	await _wait_real(1.2)

	# de novo, agora AVANÇANDO no meio da voz: 1º aperto mostra tudo, 2º corta e avança
	box = DialogueBox.play([voz, nov])
	await _wait_real(0.4)
	await _press(box)
	check(not box.is_typing() and Audio.is_voice_playing(box), "1º aperto: fala inteira na tela, voz CONTINUA")
	await _press(box)
	await get_tree().process_frame
	var db_mid: float = Audio.voice_player_db()
	check(box.idx == 1 and not box.has_voice(), "2º aperto: avança para a fala seguinte (sem arquivo → sem voz)")
	await _wait_real(0.25)
	check(not Audio.is_voice_playing(), "avançar corta a voz (fade de %.2f s; volume no meio do fade %.1f dB)" % [Audio.VOICE_FADE, db_mid])
	await _wait_real(1.0)
	check(int(Audio.played_counts.get("blip_voz", 0)) > blips0, "fala sem voz: blips de sempre (%d)" % (int(Audio.played_counts.get("blip_voz", 0)) - blips0))
	for i in 3:                # completa (se ainda digitava) e fecha
		if is_instance_valid(box) and not box.is_queued_for_deletion():
			await _press(box)
	await _wait_real(0.3)
	check(not is_instance_valid(box) or box.is_queued_for_deletion(), "caixa fecha normalmente depois da fala sem voz")
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
	check(_bus_db("Music") < music0 - 8.0 and _bus_db("SFX") < sfx0 - 2.5 and absf(_bus_db("Tell") - tell0) < 0.1,
		"legenda + voz: música %.1f→%.1f, SFX %.1f→%.1f (luta continua), Tell intocado %.1f" % [music0, _bus_db("Music"), sfx0, _bus_db("SFX"), _bus_db("Tell")])
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
	bar.queue_free()
	print("VOICE INFO: voz do Rei %.2f s" % d)
	await _wait_real(0.8)


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


func _end() -> void:
	OS.set_environment("GNOSIS_VOICE_MANIFEST", "")
	Audio.set("_log_path", "")
	print("VOICE PROBE: %d falhas" % fails)
	get_tree().quit(0 if fails == 0 else 1)
