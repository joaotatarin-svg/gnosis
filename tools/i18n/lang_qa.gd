extends Node
## LangQA (Onda 4 — i18n): confere a tradução inglesa LIGADA no jogo.
##   godot --headless --audio-driver Dummy --path . res://tools/i18n/LangQA.tscn
## Sai com 0 (verde) ou 1. Checa: pt continua pt (a trava do idioma de reserva),
## en traduz chave exata / formato / caixa alta / compostos, Label traduz
## sozinho, e varre as fontes de texto do jogo (Narrative, Estelas, cards,
## Bestiário, golpes) procurando texto que ficaria em português.

var _fails := 0
var _passes := 0


func check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails += 1
		print("  FALHA: ", what)


func eq(got: String, want: String, what: String) -> void:
	check(got == want, "%s → %s (esperado %s)" % [what, got, want])


func _set_lang(code: String) -> void:
	GameManager.settings["locale"] = code
	GameManager.apply_settings()


func _ready() -> void:
	# o SaveManager reaplica as opções no 1º quadro (call_deferred): espera passar
	await get_tree().process_frame
	await get_tree().process_frame
	var old := String(GameManager.settings.get("locale", ""))
	# --- português: nada muda (o Godot cairia no "en" de reserva sem a trava) ---
	_set_lang("pt_BR")
	eq(tr("A Voz"), "A Voz", "pt: A Voz")
	eq(I18n.t("Continuar"), "Continuar", "pt: Continuar")
	# --- inglês ---
	_set_lang("en")
	check(I18n.is_en(), "I18n.is_en() depois de apply(en)")
	eq(tr("A Voz"), "The Voice", "en: falante")
	eq(I18n.t("Fome"), "Hunger", "en: nome de Éon")
	eq(I18n.t("Fome · Chegada"), "Hunger · Arrival", "en: formato %s · Chegada")
	eq(I18n.t("ESTELA  ·  FOME"), "STELE  ·  HUNGER", "en: caixa alta + formato")
	eq(I18n.t("Campeão da Corrente"), "Champion of the Chain", "en: composto (gênero)")
	eq(I18n.t("Crônica 3/18"), "Chronicle 3/18", "en: %d/%d")
	eq(I18n.t("  Continuar"), "  Continue", "en: espaços nas pontas")
	var lab := Label.new()
	add_child(lab)
	lab.text = "Continuar"
	await get_tree().process_frame
	check(lab.get_total_character_count() == "Continue".length(), "Label traduz sozinho (Continue)")
	lab.queue_free()
	# --- varredura: o que o jogador lê ---
	var missing: Array[String] = []
	_scan_narrative(missing)
	for s in Gnosis.STELAS:
		for k in ["title", "source", "hint", "eon"]:
			_need(String(s.get(k, "")), "Estela." + k, missing)
		for ln in s.get("lines", []):
			_need(String(ln), "Estela.linha", missing)
	for m in missing.slice(0, 40):
		print("  sem tradução: ", m)
	check(missing.is_empty(), "%d texto(s) do jogo sem tradução" % missing.size())
	_set_lang(old)
	print("LangQA: %d ok, %d falha(s)" % [_passes, _fails])
	print("QA PASS" if _fails == 0 else "QA FAIL")
	get_tree().quit(0 if _fails == 0 else 1)


## Texto com letras que o inglês devolve igual = sem tradução (nomes próprios à parte).
func _need(pt: String, where: String, missing: Array[String]) -> void:
	if pt.strip_edges() == "" or not _has_letters(pt):
		return
	if I18n.t(pt) == pt and not _same_in_en(pt):
		var m := "%s: %s" % [where, pt.left(80)]
		if not m in missing:
			missing.append(m)


func _has_letters(s: String) -> bool:
	for c in s:
		if c.to_lower() != c.to_upper():
			return true
	return false


## Nomes próprios e termos iguais nos dois idiomas.
func _same_in_en(pt: String) -> bool:
	var names := ["sophia", "athoth", "harmas", "galila", "yabel", "astaphaios", "belias", "armupiel",
		"yaldabaoth", "soter", "velkar", "torpor", "kenoma", "ina", "merou", "tasso", "gnosis", "pleroma",
		"nag hammadi, 1945"]
	return pt.to_lower() in names


## Chama cada fonte de falas do Narrative com argumentos do run real.
func _scan_narrative(missing: Array[String]) -> void:
	var ids := ["arconte_sono", "arconte_fome", "arconte_corrente", "arconte_silencio", "arconte_espelho", "arconte_praga", "arconte_coroa"]
	var fixed := ["intro", "king_intro", "king_fall", "refusal_response", "concession_response", "soter_blessings",
		"velkar_meeting", "velkar_choices", "theft", "center_intro", "final_pre", "seventh_ring", "final_lines"]
	for n in fixed:
		_walk(Narrative.call(n), "Narrative." + n, missing)
	for e in 7:
		_walk(Narrative.eon_intro(e), "eon_intro", missing)
		_walk(Narrative.champion_card(e), "champion_card", missing)
		_walk(Narrative.sanctuary(e), "sanctuary", missing)
		_need(RunManager.EON_NAMES[e], "EON_NAMES", missing)
	for i in ids.size():
		_walk(Narrative.temptation(ids[i]), "temptation", missing)
		_walk(Narrative.archon_phase2(ids[i]), "archon_phase2", missing)
		_walk(Narrative.ring_gained(ids[i], "Esfera Solar", i + 1), "ring_gained", missing)
		_walk(Narrative.echo_memory(ids[i]), "echo_memory", missing)
		_need(Narrative.echo_shard(ids[i], "Esfera Solar"), "echo_shard", missing)
	for n in 3:
		_walk(Narrative.soter_meeting(n), "soter_meeting", missing)
		_walk(Narrative.after_soter(n), "after_soter", missing)
		_walk(Narrative.ending_lines(n), "ending_lines", missing)
	for c in 2:
		_walk(Narrative.velkar_farewell(c), "velkar_farewell", missing)
	for sl in 8:
		_walk(Narrative.final_choices(sl), "final_choices", missing)
	_need(Narrative.final_form_fell("O Colosso Oco"), "final_form_fell", missing)
	_need(Narrative.final_revive("O Colosso Oco"), "final_revive", missing)
	for w in ["ascensao", "ruptura", "semente"]:
		_walk(Narrative.epilogue_cards(w), "epilogue_cards", missing)
	for screen in range(1, RunManager.MAX_SCREEN + 1):
		_walk(Narrative.sleeper_line(screen), "sleeper_line", missing)
		_walk(Narrative.walk_arrival(screen), "walk_arrival", missing)
		for z in 4:
			_walk(Narrative.walk_cleared(screen, z), "walk_cleared", missing)
		for d in [1, 2, 4, 8, 14]:
			_walk(Narrative.death_revive(screen, d, 1 if d == 1 else 37), "death_revive", missing)
	Narrative.reset()
	for id in Gnosis.BOSS_TITLES:
		_walk(Gnosis.BOSS_TITLES[id], "BOSS_TITLES", missing)
	for t in Bestiary.wave_types + Bestiary.bosses + Bestiary.specials + Bestiary.echoes:
		_need(String(t.get("name", "")), "Bestiary.name", missing)


func _walk(v, where: String, missing: Array[String]) -> void:
	if v is String:
		_need(v, where, missing)
	elif v is Array:
		for x in v:
			_walk(x, where, missing)
	elif v is Dictionary:
		for k in ["text", "speaker", "title", "body", "name", "hint"]:
			if v.has(k) and v[k] is String:
				_need(String(v[k]), where + "." + k, missing)
