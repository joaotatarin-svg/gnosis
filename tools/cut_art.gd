extends SceneTree
## Ferramenta única: separa o orbe-olho do corpo no PNG (já transparente) do
## Demiurgo e salva dois arquivos recortados ao conteúdo:
##   assets/characters/demiurgo.png      (corpo, orbe apagado)
##   assets/characters/demiurgo_orb.png  (só o orbe + pingentes)
## Método: componentes conectados sobre o alpha. Corpo = maior componente;
## orbe = demais componentes na metade de cima.

const SRC := "res://artes/arconte final.png"
const OUT_BODY := "res://assets/characters/demiurgo.png"
const OUT_ORB := "res://assets/characters/demiurgo_orb.png"

func _initialize() -> void:
	var img := Image.load_from_file(SRC)
	if img == null:
		push_error("FALHOU ao carregar: " + SRC)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var n := w * h

	# Máscara opaca (a > 0.5) pra velocidade.
	var op := PackedByteArray()
	op.resize(n)
	for y in range(h):
		for x in range(w):
			op[y * w + x] = 1 if img.get_pixel(x, y).a > 0.5 else 0

	# Componentes conectados (4-conn).
	var label := PackedInt32Array()
	label.resize(n)
	label.fill(-1)
	var comps: Array = []   # cada: {id, count, minx, miny, maxx, maxy, cy}
	var cur := 0
	for start in range(n):
		if op[start] == 0 or label[start] != -1:
			continue
		var st: Array = [start]
		label[start] = cur
		var cnt := 0
		var minx := w
		var miny := h
		var maxx := 0
		var maxy := 0
		while st.size() > 0:
			var p: int = st.pop_back()
			var px := p % w
			var py := p / w
			cnt += 1
			minx = mini(minx, px)
			maxx = maxi(maxx, px)
			miny = mini(miny, py)
			maxy = maxi(maxy, py)
			# vizinhos 4-conn
			if px > 0:
				var q := p - 1
				if op[q] == 1 and label[q] == -1:
					label[q] = cur
					st.push_back(q)
			if px < w - 1:
				var q2 := p + 1
				if op[q2] == 1 and label[q2] == -1:
					label[q2] = cur
					st.push_back(q2)
			if py > 0:
				var q3 := p - w
				if op[q3] == 1 and label[q3] == -1:
					label[q3] = cur
					st.push_back(q3)
			if py < h - 1:
				var q4 := p + w
				if op[q4] == 1 and label[q4] == -1:
					label[q4] = cur
					st.push_back(q4)
		comps.append({
			"id": cur, "count": cnt,
			"minx": minx, "miny": miny, "maxx": maxx, "maxy": maxy,
			"cy": float(miny + maxy) * 0.5,
		})
		cur += 1

	if comps.is_empty():
		push_error("nenhum componente opaco")
		quit(1)
		return

	# Corpo = maior componente.
	comps.sort_custom(func(a, b): return a["count"] > b["count"])
	var body: Dictionary = comps[0]
	var body_id: int = body["id"]

	print("componentes: ", comps.size())
	for c in comps:
		print("  id=", c["id"], " px=", c["count"],
			" bbox=(", c["minx"], ",", c["miny"], ")-(", c["maxx"], ",", c["maxy"], ")")

	# Orbe = união dos componentes NÃO-corpo com centro na metade de cima
	# e tamanho relevante (ignora poeira).
	var orb_ids: Dictionary = {}
	var ominx := w
	var ominy := h
	var omaxx := 0
	var omaxy := 0
	for c in comps:
		if c["id"] == body_id:
			continue
		if c["cy"] > h * 0.5:
			continue
		if c["count"] < 12:
			continue
		orb_ids[c["id"]] = true
		ominx = mini(ominx, c["minx"])
		ominy = mini(ominy, c["miny"])
		omaxx = maxi(omaxx, c["maxx"])
		omaxy = maxi(omaxy, c["maxy"])

	# --- Salva o CORPO recortado ao bbox do corpo (orbe apagado) ---
	var bx := body["minx"] as int
	var by := body["miny"] as int
	var bw := (body["maxx"] as int) - bx + 1
	var bh := (body["maxy"] as int) - by + 1
	var body_img := Image.create_empty(bw, bh, false, Image.FORMAT_RGBA8)
	for y in range(by, by + bh):
		for x in range(bx, bx + bw):
			if label[y * w + x] == body_id:
				body_img.set_pixel(x - bx, y - by, img.get_pixel(x, y))
	body_img.save_png(OUT_BODY)
	print("corpo salvo: ", OUT_BODY, "  ", bw, "x", bh)

	# --- Salva o ORBE recortado ao seu bbox ---
	if orb_ids.is_empty():
		print("AVISO: orbe não identificado; só o corpo foi salvo.")
	else:
		var ow := omaxx - ominx + 1
		var oh := omaxy - ominy + 1
		var orb_img := Image.create_empty(ow, oh, false, Image.FORMAT_RGBA8)
		for y in range(ominy, ominy + oh):
			for x in range(ominx, ominx + ow):
				if orb_ids.has(label[y * w + x]):
					orb_img.set_pixel(x - ominx, y - ominy, img.get_pixel(x, y))
		orb_img.save_png(OUT_ORB)
		print("orbe salvo:  ", OUT_ORB, "  ", ow, "x", oh)

	quit(0)
