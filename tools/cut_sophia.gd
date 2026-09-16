extends SceneTree
## Remove o fundo cinza sólido da Sophia (flood-fill das bordas) e salva
## transparente, recortado ao conteúdo: assets/characters/sophia.png
## Tolerância ajustável (TOL) — subir se sobrar fundo, baixar se comer a roupa.

const SRC := "res://artes/sophia_raw.png"
const OUT := "res://assets/characters/sophia.png"
const SEED_TOL := 0.12   # borda vs cor-de-fundo média (semeadura)
const LOCAL_TOL := 0.05  # pixel vs vizinho já-fundo (segue gradiente suave)
const GLOBAL_TOL := 0.20 # teto: pixel vs fundo médio (evita invadir a figura)

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

	# Cor de fundo = média dos 4 cantos.
	var bg := (img.get_pixel(0, 0) + img.get_pixel(w - 1, 0)
		+ img.get_pixel(0, h - 1) + img.get_pixel(w - 1, h - 1)) / 4.0
	print("bg medio: ", bg)

	var isbg := PackedByteArray()
	isbg.resize(n)
	var stack: Array = []

	# Semeia todas as bordas que casam com o fundo.
	for x in range(w):
		_seed(img, isbg, stack, x, 0, w, bg)
		_seed(img, isbg, stack, x, h - 1, w, bg)
	for y in range(h):
		_seed(img, isbg, stack, 0, y, w, bg)
		_seed(img, isbg, stack, w - 1, y, w, bg)

	# Flood fill 4-conn seguindo o gradiente (compara com o vizinho de origem).
	while stack.size() > 0:
		var p: int = stack.pop_back()
		var px := p % w
		var py := p / w
		var from := img.get_pixel(px, py)
		if px > 0: _try(img, isbg, stack, p - 1, w, from, bg)
		if px < w - 1: _try(img, isbg, stack, p + 1, w, from, bg)
		if py > 0: _try(img, isbg, stack, p - w, w, from, bg)
		if py < h - 1: _try(img, isbg, stack, p + w, w, from, bg)

	# Aplica alpha 0 no fundo + acha bbox do conteúdo.
	var removed := 0
	var minx := w
	var miny := h
	var maxx := 0
	var maxy := 0
	for y in range(h):
		for x in range(w):
			var i := y * w + x
			if isbg[i] == 1:
				var c := img.get_pixel(x, y)
				c.a = 0.0
				img.set_pixel(x, y, c)
				removed += 1
			else:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	print("removidos: ", removed, " (", 100.0 * removed / n, "%)")
	print("bbox conteudo: (", minx, ",", miny, ")-(", maxx, ",", maxy, ")")

	var cw := maxx - minx + 1
	var ch := maxy - miny + 1
	var out := img.get_region(Rect2i(minx, miny, cw, ch))
	out.save_png(OUT)
	print("salvo: ", OUT, "  ", cw, "x", ch)
	quit(0)


func _seed(img: Image, isbg: PackedByteArray, stack: Array, x: int, y: int, w: int, bg: Color) -> void:
	var i := y * w + x
	if isbg[i] == 1:
		return
	if _dist(img.get_pixel(x, y), bg) <= SEED_TOL:
		isbg[i] = 1
		stack.push_back(i)


func _try(img: Image, isbg: PackedByteArray, stack: Array, i: int, w: int, from: Color, bg: Color) -> void:
	if isbg[i] == 1:
		return
	var x := i % w
	var y := i / w
	var c := img.get_pixel(x, y)
	# Segue o gradiente (perto do vizinho-fundo) mas sem passar do teto global.
	if _dist(c, from) <= LOCAL_TOL and _dist(c, bg) <= GLOBAL_TOL:
		isbg[i] = 1
		stack.push_back(i)


func _dist(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)
