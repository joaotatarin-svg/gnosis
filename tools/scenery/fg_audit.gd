extends Node
## FERRAMENTA (cenário, Onda 5): AUDITORIA DO PRIMEIRO PLANO em todas as telas.
## Abre cada tela do run (headless, sem janela), espera o Level pôr NPC/Estela/
## Selos/baú, e varre a câmera de parede a parede (passo 8 px) medindo com
## `Scenery.Foreground.audit_at`:
##   cover   = fração do quadro 640×360 coberta por silhueta de primeiro plano
##   col     = só a parte das colunas
##   hits    = ponto protegido (NPC, Estela, Selos, baú, Adormecido, fenda) no
##             quadro com coluna em cima (fração da faixa do personagem coberta)
##   fight   = coluna visível com uma zona trancada (câmera em c ± 150)
## Uso: godot --headless --audio-driver Dummy --path . res://tools/scenery/FgAudit.tscn -- [telas=1-68] [legacy] [out=C:/x.csv]
##   legacy = mede o ANTES (colunona em cada descanso, entulho alto).
## Saída: uma linha "FGAUDIT ..." por tela e "FGAUDIT RESUMO ..." no fim.


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var w := Worker.new()
	for a in OS.get_cmdline_user_args():
		if a == "legacy":
			w.legacy = true
		elif a.begins_with("out="):
			w.out = a.substr(4)
		elif a.begins_with("telas="):
			w.screens = _parse(a.substr(6))
	if w.screens.is_empty():
		w.screens = _parse("1-68")
	get_tree().root.add_child.call_deferred(w)


static func _parse(s: String) -> Array:
	var r: Array = []
	for part in s.split(","):
		if part.contains("-"):
			var ab := part.split("-")
			for i in range(int(ab[0]), int(ab[1]) + 1):
				r.append(i)
		elif part != "":
			r.append(int(part))
	return r


class Worker extends Node:
	var screens: Array = []
	var legacy: bool = false
	var out: String = ""
	var _i: int = -1
	var _wait: int = 0
	var _lines: PackedStringArray = PackedStringArray(["tela,eon,colunas,cover_max,cx_max,col_max,hits,pior_hit,fight"])
	var _worst: float = 0.0
	var _worst_s: int = 0
	var _hits: int = 0
	var _fight: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		SaveManager.persist_enabled = false
		Scenery.Foreground.legacy = legacy
		_next()

	func _next() -> void:
		_i += 1
		if _i >= screens.size():
			print("FGAUDIT RESUMO legacy=%s telas=%d cover_max=%.3f (tela %d) hits=%d fight=%d" % [legacy, screens.size(), _worst, _worst_s, _hits, _fight])
			if out != "":
				var f := FileAccess.open(out, FileAccess.WRITE)
				if f != null:
					f.store_string("\n".join(_lines) + "\n")
			get_tree().quit(0)
			return
		var screen: int = screens[_i]
		GameManager.selected_character = GameContent.characters[0]
		Progression.reset_run()
		RunManager.begin()
		Narrative.once("prologue")
		Gnosis.persist_enabled = false
		RunManager.current_screen = screen
		GameManager.current_screen = screen
		_wait = 0
		get_tree().change_scene_to_file.call_deferred("res://scenes/levels/Level01.tscn")

	func _process(_delta: float) -> void:
		for c in get_tree().root.get_children():
			if c is DialogueBox:
				if c.choices.size() > 0:
					c._on_choice(0)
				else:
					c._finish()
		var lv := get_tree().current_scene
		if lv == null or not ("_ready_done" in lv) or not bool(lv.get("_ready_done")):
			_wait += 1
			if _wait > 3000:
				print("FGAUDIT tela=%d TEMPO (o Level não ficou pronto)" % screens[_i])
				_next()
			return
		_wait += 1
		if _wait < 12:
			return                  # deixa o fim de quadro pôr as colunas
		_audit(lv)
		_next()

	func _audit(lv: Node) -> void:
		var screen: int = screens[_i]
		var fg := lv.get_node_or_null("Foreground")
		if fg == null:
			print("FGAUDIT tela=%d sem Foreground (PNG único ou tela especial)" % screen)
			_lines.append("%d,%d,0,0,0,0,0,0,0" % [screen, RunManager.eon_index(screen)])
			return
		var prot: Array = []
		var names: Dictionary = {}
		for n in lv.get_children():
			var hw: float = Scenery.Foreground._guard_half(n)
			if hw > 0.0:
				var x: float = (n as Node2D).global_position.x
				prot.append(Vector2(x, hw))
				names[int(x)] = n.get_class() if n.get_script() == null else String(n.get_script().get_global_name())
		var cols := 0
		for ch in fg.get_children():
			if ch.has_meta("col"):
				cols += 1
		var cy := 224.0
		var pl = lv.get("player")
		if pl != null and pl.has_node("Camera2D"):
			var cam: Camera2D = pl.get_node("Camera2D")
			cy = cam.get_screen_center_position().y
		var left: float = Level.WALL_LEFT + 320.0
		var right: float = float(lv.get("_end_x")) - 320.0
		var cmax := 0.0
		var cxmax := 0.0
		var colmax := 0.0
		var hits := 0
		var worst_hit := ""
		var cx := left
		while cx <= right:
			var r: Dictionary = fg.audit_at(cx, cy, prot)
			if float(r.cover) > cmax:
				cmax = r.cover
				cxmax = cx
			colmax = maxf(colmax, r.col)
			for h in r.hits:
				hits += 1
				if worst_hit == "" or float(h[1]) > float(worst_hit.split(":")[2]):
					worst_hit = "%s@x%d:cx%d:%.2f" % [names.get(int(h[0]), "?"), int(h[0]), int(cx), float(h[1])]
			cx += 8.0
		# luta: coluna no quadro com zona trancada
		var fight := 0
		var nz: int = (lv.get("zones") as Array).size()
		for z in nz:
			var c: float = Level.ZONE_FIRST_X + float(z) * Level.ZONE_STEP
			var k := -159.0
			while k <= 159.0:
				var rr: Dictionary = fg.audit_at(c + k, cy, [])
				if float(rr.col) > 0.0:
					fight += 1
				k += 8.0
		if worst_hit != "":
			worst_hit = worst_hit.substr(0, worst_hit.rfind(":")) + "=" + worst_hit.substr(worst_hit.rfind(":") + 1)
		print("FGAUDIT tela=%d eon=%d colunas=%d cover_max=%.3f (cx %d) col_max=%.3f hits=%d %s fight=%d cy=%d" % [screen, RunManager.eon_index(screen), cols, cmax, int(cxmax), colmax, hits, worst_hit, fight, int(cy)])
		_lines.append("%d,%d,%d,%.4f,%d,%.4f,%d,%s,%d" % [screen, RunManager.eon_index(screen), cols, cmax, int(cxmax), colmax, hits, worst_hit, fight])
		if cmax > _worst:
			_worst = cmax
			_worst_s = screen
		_hits += hits
		_fight += fight
