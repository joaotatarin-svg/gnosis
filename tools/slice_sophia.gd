extends SceneTree
## Fatia a Sophia recortada em 4 partes de rig (cajado, cabeca, corpo, saia),
## dropando a sombra/pés (y >= CUT_Y). Salva PNGs + rig.json (offsets/pivôs) +
## um preview remontado sobre magenta pra conferência visual.

const SRC := "res://assets/characters/sophia.png"
const OUTDIR := "res://assets/characters/sophia/parts"
const MANIFEST := "res://assets/characters/sophia/rig.json"
const PREVIEW := "res://tools/_assembled.png"

const CUT_Y := 950        # abaixo disto = sombra/pés → descarta
const STAFF_X := 100      # x < isto = cajado
const HEAD_Y := 300       # y < isto (e x>=STAFF_X) = cabeca
const SKIRT_Y := 560      # y >= isto = saia; entre HEAD_Y e SKIRT_Y = corpo

# Pivôs (coords da fonte) e ordem de desenho (z: menor atrás).
const PIVOTS := {
	"corpo": Vector2(255, 430),
	"saia": Vector2(255, 560),
	"cabeca": Vector2(250, 300),
	"cajado": Vector2(72, 445),
}
const ZORDER := ["corpo", "saia", "cabeca", "cajado"]
const FOOT_CENTER := Vector2(260, 950)

func _part_of(x: int, y: int) -> String:
	if x < STAFF_X:
		return "cajado"
	if y < HEAD_Y:
		return "cabeca"
	if y >= SKIRT_Y:
		return "saia"
	return "corpo"

func _initialize() -> void:
	var img := Image.load_from_file(SRC)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()

	# bbox por parte
	var bb := {}
	for name in ZORDER:
		bb[name] = {"minx": w, "miny": h, "maxx": 0, "maxy": 0, "cnt": 0}
	for y in range(min(h, CUT_Y)):
		for x in range(w):
			if img.get_pixel(x, y).a <= 0.5:
				continue
			var pn := _part_of(x, y)
			var b = bb[pn]
			b["minx"] = mini(b["minx"], x)
			b["maxx"] = maxi(b["maxx"], x)
			b["miny"] = mini(b["miny"], y)
			b["maxy"] = maxi(b["maxy"], y)
			b["cnt"] += 1

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTDIR))

	var manifest := {
		"source": [w, h],
		"foot_center": [FOOT_CENTER.x, FOOT_CENTER.y],
		"parts": [],
	}
	# gera cada parte cortada ao seu bbox, só com os pixels da parte
	for zi in range(ZORDER.size()):
		var name: String = ZORDER[zi]
		var b = bb[name]
		if b["cnt"] == 0:
			print("AVISO: parte vazia: ", name)
			continue
		var pw: int = b["maxx"] - b["minx"] + 1
		var ph: int = b["maxy"] - b["miny"] + 1
		var part := Image.create_empty(pw, ph, false, Image.FORMAT_RGBA8)
		for y in range(b["miny"], b["maxy"] + 1):
			for x in range(b["minx"], b["maxx"] + 1):
				if img.get_pixel(x, y).a > 0.5 and _part_of(x, y) == name:
					part.set_pixel(x - b["minx"], y - b["miny"], img.get_pixel(x, y))
		var file := "%s/%s.png" % [OUTDIR, name]
		part.save_png(file)
		var piv: Vector2 = PIVOTS[name]
		manifest["parts"].append({
			"name": name, "file": file,
			"off": [b["minx"], b["miny"]],
			"pivot": [piv.x, piv.y], "z": zi,
		})
		print("parte %-7s px=%6d bbox=(%d,%d)-(%d,%d) -> %dx%d" % [name, b["cnt"], b["minx"], b["miny"], b["maxx"], b["maxy"], pw, ph])

	var f := FileAccess.open(MANIFEST, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	print("manifest: ", MANIFEST)

	# --- preview remontado sobre magenta ---
	var canvas := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(1, 0, 1, 1))
	for p in manifest["parts"]:
		var pimg := Image.load_from_file(p["file"])
		pimg.convert(Image.FORMAT_RGBA8)
		var ox: int = p["off"][0]
		var oy: int = p["off"][1]
		for yy in range(pimg.get_height()):
			for xx in range(pimg.get_width()):
				var c := pimg.get_pixel(xx, yy)
				if c.a > 0.01:
					var bgp := canvas.get_pixel(ox + xx, oy + yy)
					canvas.set_pixel(ox + xx, oy + yy, bgp.lerp(Color(c.r, c.g, c.b, 1.0), c.a))
	canvas.save_png(PREVIEW)
	print("preview: ", PREVIEW)
	quit(0)
