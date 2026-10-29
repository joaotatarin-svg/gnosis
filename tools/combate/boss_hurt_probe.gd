extends Node
## FERRAMENTA (Polimento 7, não vai no jogo): a HURTBOX dos chefes bate com o
## desenho? (João, 19/10: "a Sophia atravessa o manto do Rei; só o centro acerta".)
## Desenha cada chefe sozinho num SubViewport transparente, em várias poses, e
## compara a silhueta opaca (alfa > 0,5) com a Hurtbox real do Enemy:
##   cobre   = % da silhueta dentro da hurtbox
##   vazio   = % da hurtbox fora da silhueta ("apelão": acerta o ar)
##   faixa   = só as linhas na ALTURA DO CAJADO da Sophia (pés até ~1 Sophia):
##             borda esquerda/direita da silhueta × da hurtbox, em px de mundo;
##             gap > 0 = pano desenhado que o cajado atravessa sem dano.
## Também mede a caixa ANTIGA (prévia 3: ½ do recorte, conta pelo JSON) para o
## "antes", e o BONECO (boss_puppet, reserva sem atlas) com `puppet`.
## Precisa de janela (renderer), não roda headless:
##   godot --audio-driver Dummy --path . --resolution 320x180 --position 4000,4000 \
##     res://tools/combate/BossHurtProbe.tscn -- png=C:/dir [puppet] [ids=rei,colosso]
## Saída: "HURTPROBE|<id>|<pose>|cobre=..|vazio=..|gapE=..|gapD=..|fora=.." e PNGs
## com a silhueta e as caixas (vermelho = hurtbox atual, ciano = caixa antiga).

const IDS := ["rei", "arconte_sono", "arconte_fome", "arconte_corrente", "arconte_silencio",
	"arconte_espelho", "arconte_praga", "arconte_coroa", "colosso", "rei_final"]
const POSES := [["idle", -1.0], ["walk", -1.0], ["windup", 0.6], ["attack", 0.5], ["hurt", -1.0]]
const VP := Vector2i(900, 900)
const FOOT := Vector2(450, 760)   # onde ficam os pés no SubViewport
const ALPHA := 0.5
const SOPHIA_H := 62.0            # altura desenhada da Sophia (BossSizeProbe) = faixa do cajado

var _png_dir: String = ""
var _puppet: bool = false
var _ids: Array = IDS.duplicate()
var _rows: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("png="):
			_png_dir = a.substr(4)
		elif a == "puppet":
			_puppet = true
		elif a.begins_with("ids="):
			_ids = Array(a.substr(4).split(","))
	_run.call_deferred()


func _make_vp() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = VP
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


## Caixa da Hurtbox em coordenadas do viewport (= mundo do holder).
func _hurt_rect(e) -> Rect2:
	var shp: CollisionShape2D = e.get_node("Hurtbox/HurtShape")
	var xf: Transform2D = shp.get_global_transform()
	if shp.shape is RectangleShape2D:
		var hs: Vector2 = (shp.shape as RectangleShape2D).size * 0.5
		var r := Rect2(xf * -hs, Vector2.ZERO)
		for c in [Vector2(hs.x, -hs.y), Vector2(-hs.x, hs.y), hs]:
			r = r.expand(xf * c)
		return r
	if shp.shape is ConvexPolygonShape2D:
		var pts: PackedVector2Array = (shp.shape as ConvexPolygonShape2D).points
		var r2 := Rect2(xf * pts[0], Vector2.ZERO)
		for p in pts:
			r2 = r2.expand(xf * p)
		return r2
	return Rect2()


## Polígono da hurtbox (se for convexa) em coordenadas do viewport, senão vazio.
func _hurt_poly(e) -> PackedVector2Array:
	var shp: CollisionShape2D = e.get_node("Hurtbox/HurtShape")
	var out := PackedVector2Array()
	if shp.shape is ConvexPolygonShape2D:
		var xf: Transform2D = shp.get_global_transform()
		for p in (shp.shape as ConvexPolygonShape2D).points:
			out.append(xf * p)
	return out


## A caixa da prévia 3 (antes do Polimento 7): ½ da largura do recorte do quadro,
## topo→pé pelo JSON, centrada na pélvis. Mesma conta do `_fit_hurtbox` antigo,
## sem a suavização (é o alvo para onde ela convergia).
func _old_rect(e) -> Rect2:
	var visual = e.visual
	if not visual.has_boss_frames():
		return Rect2()
	var key: String = visual._shown_key
	var cut := key.rfind(":")
	if cut <= 0:
		return Rect2()
	var meta: Dictionary = visual._boss_db.meta
	var seq: Dictionary = meta.states.get(key.substr(0, cut), {})
	var i := int(key.substr(cut + 1))
	if seq.is_empty() or i < 0 or i >= seq.frames.size():
		return Rect2()
	var fe: Dictionary = seq.frames[i]
	var fr: Dictionary = meta.frames.get(fe.f, {})
	if fr.is_empty() or not fr.has("top"):
		return Rect2()
	var rr: Array = fr.rect
	var anchor := Vector2(fe.anchor[0], fe.anchor[1])
	var h: float = float(fr.foot_y) - float(fr.top)
	var w: float = clampf(float(rr[2]) * 0.5, h * 0.3, h * 1.0)
	var cx: float = float(fr.get("pelvis_x", float(rr[2]) * 0.5))
	var a: Vector2 = Vector2(cx - w * 0.5, float(fr.top)) - anchor
	var b: Vector2 = Vector2(cx + w * 0.5, float(fr.foot_y)) - anchor
	var xf: Transform2D = visual.get_global_transform() * visual._body_xform
	return Rect2(xf * a, Vector2.ZERO).expand(xf * b)


func _inside(p: Vector2, r: Rect2, poly: PackedVector2Array) -> bool:
	if poly.size() >= 3:
		return Geometry2D.is_point_in_polygon(p, poly)
	return r.has_point(p)


## Mede silhueta × caixa. Devolve o dicionário de números.
func _measure(img: Image, r: Rect2, poly: PackedVector2Array) -> Dictionary:
	var used := img.get_used_rect()
	var sil := 0
	var sil_in := 0
	var foot_y := -1
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > ALPHA:
				sil += 1
				foot_y = maxi(foot_y, y)
				if _inside(Vector2(x + 0.5, y + 0.5), r, poly):
					sil_in += 1
	# vazio: amostra a caixa em grade de 1 px
	var box := 0
	var box_empty := 0
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			if not _inside(Vector2(x + 0.5, y + 0.5), r, poly):
				continue
			box += 1
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or img.get_pixel(x, y).a <= ALPHA:
				box_empty += 1
	# faixa do cajado: dos pés até 1 Sophia de altura
	var gap_l := 0.0
	var gap_r := 0.0
	var out_l := 0.0
	var out_r := 0.0
	var n := 0
	for y in range(maxi(0, foot_y - int(SOPHIA_H)), foot_y - 2):
		var xl := -1
		var xr := -1
		for x in range(used.position.x, used.end.x):
			if img.get_pixel(x, y).a > ALPHA:
				if xl < 0:
					xl = x
				xr = x
		if xl < 0:
			continue
		# bordas da hurtbox nesta linha
		var hl := INF
		var hr := -INF
		for x in range(used.position.x - 40, used.end.x + 40):
			if _inside(Vector2(x + 0.5, y + 0.5), r, poly):
				hl = minf(hl, x)
				hr = maxf(hr, x)
		if hl == INF:
			gap_l += float(xr - xl) * 0.5
			gap_r += float(xr - xl) * 0.5
		else:
			gap_l += maxf(0.0, hl - xl)
			gap_r += maxf(0.0, xr - hr)
			out_l += maxf(0.0, xl - hl)
			out_r += maxf(0.0, hr - xr)
		n += 1
	var k := 1.0 / maxf(1.0, n)
	return {"cobre": 100.0 * sil_in / maxf(1.0, sil), "vazio": 100.0 * box_empty / maxf(1.0, box),
		"gapE": gap_l * k, "gapD": gap_r * k, "fora": (out_l + out_r) * k, "sil_w": used.size.x}


## Pinta o contorno de um retângulo/polígono na imagem (prancha de prova).
func _stroke(img: Image, r: Rect2, poly: PackedVector2Array, col: Color) -> void:
	if r.size.x <= 0.0:
		return
	var pts: PackedVector2Array = poly
	if pts.size() < 3:
		pts = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var steps := int(maxf(2.0, a.distance_to(b)))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var q: Vector2i = Vector2i(int(p.x), int(p.y)) + d
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, col)


func _run() -> void:
	await get_tree().process_frame
	SaveManager.persist_enabled = false
	var scn = load("res://scenes/entities/Enemy.tscn")
	var tot := {"cobre": 0.0, "vazio": 0.0, "gap": 0.0, "fora": 0.0, "n": 0}
	var tot_old := {"cobre": 0.0, "vazio": 0.0, "gap": 0.0, "fora": 0.0, "n": 0}
	for id in _ids:
		var v := _make_vp()
		var holder := Node2D.new()
		v.add_child(holder)
		var e = scn.instantiate()
		e.type_id = id
		holder.add_child(e)
		e.position = FOOT + Vector2(0, -24)        # pés do Enemy ficam em y+24
		e.set_physics_process(false)
		for i in 10:
			await get_tree().process_frame
		if _puppet and e.visual.has_boss_frames():
			# reserva: sem atlas, o CharacterArt cai no boneco articulado
			e.visual._boss_db = {}
			e.visual._geo_fr = {}
			e.visual.queue_redraw()
		for c in holder.get_children():
			if c != e:
				c.visible = false
		for c in e.get_children():
			if c is CanvasItem and c != e.visual and c.name != "Rim":
				c.visible = false
		var sheet: Image = null
		for pose in POSES:
			e.visual.set_anim(String(pose[0]))
			for i in 24:
				e.visual.pose_progress = float(pose[1])
				await get_tree().process_frame
				e._fit_hurtbox()
			var img := v.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var r := _hurt_rect(e)
			var poly := _hurt_poly(e)
			var m := _measure(img, r, poly)
			var tag: String = "%s|%s" % [id, pose[0]]
			print("HURTPROBE|%s|cobre=%.0f|vazio=%.0f|gapE=%.1f|gapD=%.1f|fora=%.1f|caixa=%.0fx%.0f|sil_w=%d" % [tag,
				m.cobre, m.vazio, m.gapE, m.gapD, m.fora, r.size.x, r.size.y, m.sil_w])
			tot.cobre += m.cobre; tot.vazio += m.vazio; tot.gap += m.gapE + m.gapD; tot.fora += m.fora; tot.n += 1
			var ro := _old_rect(e)
			if ro.size.x > 0.0:
				var mo := _measure(img, ro, PackedVector2Array())
				print("HURTPROBE_ANTIGA|%s|cobre=%.0f|vazio=%.0f|gapE=%.1f|gapD=%.1f|fora=%.1f|caixa=%.0fx%.0f" % [tag,
					mo.cobre, mo.vazio, mo.gapE, mo.gapD, mo.fora, ro.size.x, ro.size.y])
				tot_old.cobre += mo.cobre; tot_old.vazio += mo.vazio; tot_old.gap += mo.gapE + mo.gapD; tot_old.fora += mo.fora; tot_old.n += 1
			if _png_dir != "":
				var pic := img.duplicate() as Image
				# fundo escuro para enxergar a silhueta
				var bg := Image.create(pic.get_width(), pic.get_height(), false, Image.FORMAT_RGBA8)
				bg.fill(Color(0.12, 0.13, 0.16, 1.0))
				bg.blend_rect(pic, Rect2i(Vector2i.ZERO, pic.get_size()), Vector2i.ZERO)
				_stroke(bg, ro, PackedVector2Array(), Color(0.2, 0.9, 1.0))
				_stroke(bg, r, poly, Color(1.0, 0.15, 0.15))
				# linha da faixa do cajado (1 Sophia acima dos pés)
				var fy := int(FOOT.y - SOPHIA_H)
				for x in range(0, bg.get_width(), 6):
					bg.set_pixel(x, fy, Color(1, 1, 0.3))
				var crop := Rect2i(200, 330, 500, 450)
				var tile := bg.get_region(crop)
				if sheet == null:
					sheet = Image.create(crop.size.x * POSES.size(), crop.size.y, false, Image.FORMAT_RGBA8)
				sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, crop.size), Vector2i(crop.size.x * POSES.find(pose), 0))
		if sheet != null:
			pass
			sheet.save_png("%s/%s%s.png" % [_png_dir, id, "_boneco" if _puppet else ""])
		v.queue_free()
		await get_tree().process_frame
	var k: float = 1.0 / maxf(1.0, float(tot.n))
	print("HURTPROBE_MEDIA|atual|cobre=%.0f|vazio=%.0f|gap_faixa=%.1f|fora_faixa=%.1f" % [tot.cobre * k, tot.vazio * k, tot.gap * k, tot.fora * k])
	if tot_old.n > 0:
		var ko: float = 1.0 / float(tot_old.n)
		print("HURTPROBE_MEDIA|antiga|cobre=%.0f|vazio=%.0f|gap_faixa=%.1f|fora_faixa=%.1f" % [tot_old.cobre * ko, tot_old.vazio * ko, tot_old.gap * ko, tot_old.fora * ko])
	get_tree().quit(0)
