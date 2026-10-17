extends Node
## FERRAMENTA (Combate2): mede a ALTURA DESENHADA dos chefes em relação à Sophia
## (backlog #42: Arconte ≥ ~1,8× a Sophia, o Espelho é exceção de propósito).
## Desenha cada personagem sozinho num SubViewport transparente e mede a caixa
## dos pixels opacos (alfa > 0,25). Precisa de janela (xvfb), não roda headless:
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . res://tools/combate/BossSizeProbe.tscn
## Saída: "SIZEPROBE|<id>|alt=<px>|razao=<x>|alvo=<x>" + "QA PASS/FAIL" por Arconte.
## Opção `-- png=/caminho/dir` salva o recorte de cada um (para olhar).

const IDS := ["rei", "arconte_sono", "arconte_fome", "arconte_corrente", "arconte_silencio",
	"arconte_espelho", "arconte_praga", "arconte_coroa", "rei_final", "colosso"]
const MIN_RATIO := 1.8            # alvo do crítico (#42)
const MIRROR := "arconte_espelho" # exceção de propósito
const VP := Vector2i(900, 900)
const FOOT := Vector2(450, 760)   # onde ficam os pés no SubViewport

var _png_dir: String = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("png="):
			_png_dir = a.substr(4)
	_run.call_deferred()


func _make_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = VP
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


## Altura (px) dos pixels opacos e o retângulo deles.
func _measure(vp: SubViewport, tag: String) -> float:
	var img := vp.get_texture().get_image()
	var used := img.get_used_rect()          # usa alfa > 0
	# get_used_rect conta alfa mínimo; refaz com limiar para ignorar halo/aura.
	var top := -1
	var bottom := -1
	for y in img.get_height():
		var row_ok := false
		for x in range(0, img.get_width(), 2):
			if img.get_pixel(x, y).a > 0.25:
				row_ok = true
				break
		if row_ok:
			if top < 0:
				top = y
			bottom = y
	if _png_dir != "" and used.size.x > 0:
		img.get_region(used).save_png("%s/%s.png" % [_png_dir, tag])
	if top < 0:
		return 0.0
	return float(bottom - top + 1)


func _run() -> void:
	await get_tree().process_frame
	SaveManager.persist_enabled = false
	# --- Sophia (o mesmo perfil que o player.gd usa no _refresh_look) ---
	var vp := _make_vp()
	var sophia := CharacterArt.new()
	vp.add_child(sophia)
	sophia.position = FOOT
	sophia.set_profile(Bestiary.player_profile(GameContent.characters[0], 1, []))
	sophia.set_anim("idle")
	for i in 30:
		await get_tree().process_frame
	var h_sophia := _measure(vp, "sophia")
	vp.queue_free()
	print("SIZEPROBE|sophia|alt=%.0f" % h_sophia)
	if h_sophia <= 0.0:
		push_error("QA FAIL: não consegui medir a Sophia (rodou headless?)")
		get_tree().quit(1)
		return
	var fails := 0
	var scn = load("res://scenes/entities/Enemy.tscn")
	for id in IDS:
		var v := _make_vp()
		var holder := Node2D.new()
		v.add_child(holder)
		var e = scn.instantiate()
		e.type_id = id
		holder.add_child(e)
		e.position = FOOT + Vector2(0, -24)        # pés do Enemy ficam em y+24
		e.set_physics_process(false)
		for i in 30:
			await get_tree().process_frame
		# Só o desenho do corpo: some com sombra, orbe-olho, VFX de entrada etc.
		for c in holder.get_children():
			if c != e:
				c.visible = false
		for c in e.get_children():
			if c is CanvasItem and c != e.visual and c.name != "Rim":
				c.visible = false
		await get_tree().process_frame
		await get_tree().process_frame
		var h := _measure(v, id)
		var ratio := h / h_sophia
		var target := 0.0 if id == MIRROR else MIN_RATIO
		print("SIZEPROBE|%s|alt=%.0f|razao=%.2f|alvo=%.2f|escala_enemy=%.2f" % [id, h, ratio, target, e.scale.y])
		var arconte: bool = id.begins_with("arconte_")
		if arconte and id != MIRROR:
			if ratio + 0.03 >= MIN_RATIO:
				print("QA PASS: %s mede %.2f× a Sophia (≥ %.1f)" % [id, ratio, MIN_RATIO])
			else:
				fails += 1
				push_error("QA FAIL: %s mede %.2f× a Sophia (< %.1f)" % [id, ratio, MIN_RATIO])
		v.queue_free()
		await get_tree().process_frame
	# Chefe nascendo com o mundo PAUSADO (card de chefe): precisa aparecer.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pv := _make_vp()
	pv.process_mode = Node.PROCESS_MODE_ALWAYS
	var ph := Node2D.new()
	ph.process_mode = Node.PROCESS_MODE_PAUSABLE
	pv.add_child(ph)
	PauseStack.push(self)            # como o card de chefe
	var pe = scn.instantiate()
	pe.type_id = "arconte_fome"
	ph.add_child(pe)
	pe.position = FOOT + Vector2(0, -24)
	for i in 6:
		await get_tree().process_frame
	for c in ph.get_children():
		if c != pe:
			c.visible = false
	for c in pe.get_children():
		if c is CanvasItem and c != pe.visual and c.name != "Rim":
			c.visible = false
	await get_tree().process_frame
	var hp := _measure(pv, "pausado")
	PauseStack.pop(self)
	print("SIZEPROBE|pausado|alt=%.0f" % hp)
	if hp > 0.5 * 121.0:
		print("QA PASS: chefe nascido com o mundo pausado já aparece (alt %.0f)" % hp)
	else:
		fails += 1
		push_error("QA FAIL: chefe nascido com o mundo pausado não aparece (alt %.0f)" % hp)
	print("SIZEPROBE|fim|falhas=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
