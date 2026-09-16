extends SceneTree
## Mede a silhueta da Sophia recortada: por linha, o intervalo x opaco e se há
## um cluster separado à esquerda (o cajado). Ajuda a definir os cortes do rig.
func _initialize() -> void:
	var img := Image.load_from_file("res://assets/characters/sophia.png")
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	print("dim: ", w, "x", h)
	for frac in [0.03, 0.08, 0.14, 0.20, 0.26, 0.32, 0.40, 0.48, 0.56, 0.64, 0.72, 0.80, 0.88, 0.94, 0.99]:
		var y := int(frac * (h - 1))
		# acha os segmentos opacos nessa linha (para detectar cajado separado do corpo)
		var segs: Array = []
		var in_seg := false
		var seg_start := 0
		for x in range(w):
			var op := img.get_pixel(x, y).a > 0.5
			if op and not in_seg:
				in_seg = true
				seg_start = x
			elif not op and in_seg:
				in_seg = false
				segs.append([seg_start, x - 1])
		if in_seg:
			segs.append([seg_start, w - 1])
		var desc := ""
		for s in segs:
			desc += "[%d-%d] " % [s[0], s[1]]
		print("y=%4d (%.0f%%): %d seg  %s" % [y, frac * 100, segs.size(), desc])
	quit(0)
