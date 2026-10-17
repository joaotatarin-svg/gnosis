extends Node2D
class_name BossPuppet
## Bonecos ilustrados como UM corpo contínuo.
## - Corpo: malha única com pesos suaves (até 4 ossos por vértice, espalhados
##   entre ossos vizinhos), triângulos de alfa 0 descartados. A textura é a
##   camada "corpo" gerada offline (tools/anim_bosses/build_puppets.py): alfa
##   real, arma removida e o que ficava atrás reconstruído por inpaint.
## - Só arma e cristais são peças rígidas (camada "parts", mesmas coordenadas).
## - Movimento: mola por osso (leve sobressalto), atraso escalonado
##   peito → braço → pano, HOLD na preparação e ESTALO no golpe.
## Estado/progresso reais vêm de Enemy._sync_anim através do CharacterArt.

const NAMES := ["athoth","harmas","galila","yabel","astaphaios","belias","armupiel","colosso","rei"]
const DERIVED := "res://assets/painted/derived/puppets/"

# Peças rígidas em UV do recorte (mesmos polígonos de build_puppets.py).
const PARTS := {
	2: {"weapon": [[Vector2(.50,.465),Vector2(.535,.48),Vector2(.575,.505),Vector2(.60,.50),Vector2(.615,.525),Vector2(.67,.56),Vector2(.685,.585),Vector2(.655,.59),Vector2(.60,.575),Vector2(.475,.752),Vector2(.336,.912),Vector2(.247,.997),Vector2(.205,.997),Vector2(.198,.97),Vector2(.318,.828),Vector2(.438,.69),Vector2(.53,.57),Vector2(.55,.535),Vector2(.52,.50)]]},
	6: {"weapon": [[Vector2(.589,.50),Vector2(.64,.513),Vector2(.70,.515),Vector2(.745,.52),Vector2(.792,.56),Vector2(.802,.60),Vector2(.778,.636),Vector2(.70,.648),Vector2(.61,.692),Vector2(.465,.762),Vector2(.31,.85),Vector2(.20,.912),Vector2(.116,.958),Vector2(.066,.988),Vector2(.056,.975),Vector2(.066,.935),Vector2(.094,.873),Vector2(.148,.81),Vector2(.226,.748),Vector2(.308,.702),Vector2(.384,.636),Vector2(.492,.58),Vector2(.568,.534)]]},
	4: {"weapon": [[Vector2(.08,.165),Vector2(.085,.10),Vector2(.14,.045),Vector2(.175,-.01),Vector2(.205,-.01),Vector2(.235,.045),Vector2(.28,.075),Vector2(.34,.125),Vector2(.315,.18),Vector2(.27,.215),Vector2(.258,.245),Vector2(.248,.292),Vector2(.212,.292),Vector2(.195,.245),Vector2(.15,.215),Vector2(.10,.21)],
			[Vector2(.2326,.345),Vector2(.3205,.83),Vector2(.322,.86),Vector2(.326,.89),Vector2(.348,.975),Vector2(.356,.998),Vector2(.364,.998),Vector2(.368,.975),Vector2(.352,.89),Vector2(.352,.86),Vector2(.3405,.83),Vector2(.2506,.345)]],
		"crystal_0": [[Vector2(.128,.235),Vector2(.146,.235),Vector2(.19,.35),Vector2(.17,.46),Vector2(.15,.46),Vector2(.10,.35)]],
		"crystal_1": [[Vector2(.195,.43),Vector2(.215,.43),Vector2(.24,.52),Vector2(.22,.605),Vector2(.19,.605),Vector2(.175,.52)]],
		"crystal_2": [[Vector2(.32,.165),Vector2(.368,.16),Vector2(.368,.262),Vector2(.326,.262)]],
		"crystal_3": [[Vector2(.368,.015),Vector2(.435,-.005),Vector2(.435,.152),Vector2(.37,.152)]],
		"crystal_4": [[Vector2(.70,.055),Vector2(.765,.055),Vector2(.805,.17),Vector2(.785,.255),Vector2(.745,.255),Vector2(.705,.15)]],
		"crystal_5": [[Vector2(.715,.245),Vector2(.765,.245),Vector2(.78,.32),Vector2(.755,.395),Vector2(.725,.395),Vector2(.71,.32)]],
		"crystal_6": [[Vector2(.815,.185),Vector2(.885,.185),Vector2(.935,.33),Vector2(.895,.485),Vector2(.845,.485),Vector2(.805,.33)]]},
}
# Tecido/capa por boneco: [lado, x, y_topo, y_base, osso_pai].
const CLOTH := {
	1: [["c",.50,.56,.90,"hip"]],
	2: [["l",.33,.45,.95,"hip"],["r",.72,.50,.92,"hip"]],
	4: [["l",.26,.45,.92,"chest"],["r",.74,.40,.95,"chest"]],
	6: [["l",.07,.42,.92,"chest"],["r",.90,.40,.92,"chest"],["c",.44,.56,.90,"hip"]],
	7: [["c",.32,.48,.86,"hip"]],
}
# Zonas presas a um osso só (gaiolas penduradas de Galila balançam como pêndulo).
const ZONES := {
	2: [["cage_l",Rect2(.07,.23,.15,.64)],["cage_r",Rect2(.745,.19,.115,.70)]],
}

static var _mesh_cache: Dictionary = {}

var skeleton: Skeleton2D
var skin: Polygon2D
var bones: Dictionary = {}
var points: Dictionary = {}
var ends: Dictionary = {}
var joint_uv: Dictionary = {}
var kind: String = "biped"
var identity: int = 0
var aspect: float = 1.0
var clock: float = 0.0
var gait: float = 0.0
var debug_bones: bool = false
var debug_layer: Node2D
var pieces: Array[Polygon2D] = []
var paint: Dictionary = {}
var vertex_count: int = 0
var triangle_count: int = 0
var grid := Vector2i.ZERO
## Textura por estado (futuro: quadros pintados por estado). Mesmo tamanho e
## coordenadas da camada corpo; a malha e os pesos continuam valendo.
var state_textures: Dictionary = {}
var base_texture: Texture2D

# Molas por osso: ângulo, velocidade e alvo.
var ang: Dictionary = {}
var vel: Dictionary = {}
var tgt: Dictionary = {}
var tune: Dictionary = {}          # grupo -> Vector2(freq Hz, amortecimento)
var hip_y: float = 0.0
var hip_v: float = 0.0
var hip_t: float = 0.0
var last_state: String = ""
var floaters: Array = []           # [{node, base, i}]
var hip_rest := Vector2.ZERO


func configure(p: Dictionary) -> void:
	paint = p
	identity = int(p.get("puppet",0))
	aspect = p.rect.size.x / p.rect.size.y
	kind = "spirit" if identity in [0,3] else "biped"
	if identity == 5: kind = "beast"
	if identity == 8: kind = "king"
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	_layout()
	hip_rest = bones.hip.rest.origin
	for id in bones:
		ang[id] = 0.0
		vel[id] = 0.0
		tgt[id] = 0.0
	debug_layer = Node2D.new()
	debug_layer.visible = false
	debug_layer.z_index = 4
	debug_layer.draw.connect(_draw_bones)
	add_child(debug_layer)


## Esvazia o cache de malhas (QA mede o custo da 1ª montagem).
static func clear_cache() -> void:
	_mesh_cache.clear()


## Monta a malha (na 1ª animação, quando a escala já é conhecida). Pode ser
## chamado direto (QA). `creature` força a grade leve.
func ensure_built(creature: int = -1) -> void:
	if skin != null: return
	var small: bool = absf(scale.y) < 0.9 if creature < 0 else creature == 1
	var rows: int = 32 if small else (52 if identity == 8 else 48)
	var cols: int = 24 if small else clampi(roundi(rows*aspect),16,64)
	grid = Vector2i(cols,rows)
	_build_body(cols,rows)
	_build_parts()


func _point(uv: Vector2) -> Vector2:
	return Vector2((uv.x-0.5)*100.0*aspect,(uv.y-1.0)*100.0)


func _bone(id: String, parent_id: String, at: Vector2, end: Vector2) -> void:
	var b := Bone2D.new()
	b.name = id
	b.set_autocalculate_length_and_angle(false)
	b.set_length(maxf(2.0,_point(at).distance_to(_point(end))))
	b.set_bone_angle((_point(end)-_point(at)).angle())
	var origin: Vector2 = points.get(parent_id,Vector2.ZERO)
	b.position = _point(at)-origin
	b.rest = b.transform
	var parent_node: Node = skeleton if parent_id == "" else bones[parent_id]
	parent_node.add_child(b)
	bones[id] = b
	points[id] = _point(at)
	ends[id] = _point(end)
	joint_uv[id] = [at,end]


func _layout() -> void:
	# Pivôs conferidos sobre cada pintura (tools/anim_bosses/overlay_bones.py).
	var hip := Vector2(0.53,0.61)
	var chest := Vector2(0.51,0.32)
	var head := Vector2(0.51,0.19)
	var al := Vector2(0.30,0.28)
	var el := Vector2(0.23,0.44)
	var hl := Vector2(0.22,0.62)
	var ar := Vector2(0.72,0.29)
	var er := Vector2(0.78,0.46)
	var hr := Vector2(0.80,0.63)
	var tl := Vector2(0.41,0.61)
	var kl := Vector2(0.37,0.80)
	var fl := Vector2(0.31,0.96)
	var tr := Vector2(0.64,0.61)
	var kr := Vector2(0.67,0.80)
	var fr := Vector2(0.70,0.96)
	var hand_l := Vector2(-0.06,0.02)
	var hand_r := Vector2(-0.06,0.02)
	match identity:
		0:
			head=Vector2(0.56,0.20); al=Vector2(0.41,0.30); el=Vector2(0.34,0.41); hl=Vector2(0.32,0.49)
			ar=Vector2(0.65,0.31); er=Vector2(0.77,0.41); hr=Vector2(0.86,0.47)
		1:
			hip=Vector2(.50,.58); chest=Vector2(.50,.36); head=Vector2(.38,.20)
			al=Vector2(.26,.27); el=Vector2(.17,.46); hl=Vector2(.13,.64); hand_l=Vector2(-.01,.07)
			ar=Vector2(.72,.26); er=Vector2(.82,.45); hr=Vector2(.83,.64); hand_r=Vector2(0,.07)
			tl=Vector2(.40,.60); kl=Vector2(.24,.73); fl=Vector2(.17,.89)
			tr=Vector2(.60,.60); kr=Vector2(.61,.69); fr=Vector2(.68,.93)
		2:
			hip=Vector2(.47,.56); chest=Vector2(.47,.33); head=Vector2(.40,.17)
			al=Vector2(.30,.27); el=Vector2(.25,.42); hl=Vector2(.25,.56); hand_l=Vector2(0,.05)
			ar=Vector2(.63,.26); er=Vector2(.68,.40); hr=Vector2(.62,.50); hand_r=Vector2(-.04,.03)
			tl=Vector2(.40,.58); kl=Vector2(.40,.76); fl=Vector2(.36,.92)
			tr=Vector2(.58,.58); kr=Vector2(.62,.76); fr=Vector2(.67,.94)
		3:
			head=Vector2(0.44,0.23); chest=Vector2(0.52,0.36)
			al=Vector2(0.38,0.35); el=Vector2(0.33,0.44); hl=Vector2(0.33,0.59)
			ar=Vector2(0.66,0.32); er=Vector2(0.69,0.43); hr=Vector2(0.52,0.46)
		4:
			hip=Vector2(.50,.50); chest=Vector2(.50,.33); head=Vector2(.50,.21)
			al=Vector2(.38,.28); el=Vector2(.34,.37); hl=Vector2(.24,.32); hand_l=Vector2(-.03,-.01)
			ar=Vector2(.60,.28); er=Vector2(.645,.39); hr=Vector2(.62,.50); hand_r=Vector2(0,.04)
			tl=Vector2(.45,.52); kl=Vector2(.46,.70); fl=Vector2(.50,.90)
			tr=Vector2(.56,.52); kr=Vector2(.55,.70); fr=Vector2(.54,.90)
		6:
			hip=Vector2(.47,.56); chest=Vector2(.47,.32); head=Vector2(.42,.14)
			al=Vector2(.24,.28); el=Vector2(.16,.42); hl=Vector2(.12,.50); hand_l=Vector2(0,.04)
			ar=Vector2(.66,.28); er=Vector2(.75,.42); hr=Vector2(.69,.51); hand_r=Vector2(-.04,.02)
			tl=Vector2(.38,.58); kl=Vector2(.36,.76); fl=Vector2(.30,.90)
			tr=Vector2(.58,.58); kr=Vector2(.62,.76); fr=Vector2(.66,.92)
		7:
			hip=Vector2(.50,.50); chest=Vector2(.47,.30); head=Vector2(.45,.12)
			al=Vector2(.18,.28); el=Vector2(.11,.46); hl=Vector2(.11,.64); hand_l=Vector2(0,.05)
			ar=Vector2(.77,.30); er=Vector2(.83,.47); hr=Vector2(.81,.64); hand_r=Vector2(-.01,.06)
			tl=Vector2(.48,.52); kl=Vector2(.50,.70); fl=Vector2(.50,.95)
			tr=Vector2(.62,.52); kr=Vector2(.68,.72); fr=Vector2(.70,.85)
		8:
			head=Vector2(0.51,0.16); hip=Vector2(0.51,0.52); chest=Vector2(0.51,0.27)
			al=Vector2(0.33,0.23); el=Vector2(0.29,0.37); hl=Vector2(0.18,0.44)
			ar=Vector2(0.68,0.21); er=Vector2(0.75,0.33); hr=Vector2(0.81,0.28)
	if kind == "beast":
		_layout_beast()
		return
	if kind != "biped":
		tl = Vector2(0.41,hip.y); tr = Vector2(0.64,hip.y)
	_bone("hip","",hip,chest)
	_bone("chest","hip",chest,head)
	_bone("head","chest",head,head+Vector2(0,-0.10))
	_bone("arm_l","chest",al,el)
	_bone("fore_l","arm_l",el,hl)
	_bone("hand_l","fore_l",hl,hl+hand_l)
	_bone("arm_r","chest",ar,er)
	_bone("fore_r","arm_r",er,hr)
	_bone("hand_r","fore_r",hr,hr+hand_r)
	_bone("thigh_l","hip",tl,kl)
	_bone("shin_l","thigh_l",kl,fl)
	_bone("thigh_r","hip",tr,kr)
	_bone("shin_r","thigh_r",kr,fr)
	if kind == "biped":
		for c in CLOTH.get(identity,[]):
			var mid: float = lerpf(c[2],c[3],0.5)
			_bone("cloth_"+c[0],c[4],Vector2(c[1],c[2]),Vector2(c[1],mid))
			_bone("hem_"+c[0],"cloth_"+c[0],Vector2(c[1],mid),Vector2(c[1],c[3]))
	else:
		for side in ["l","c","r"]:
			var xx: float = {"l":0.26,"c":0.51,"r":0.76}[side]
			_bone("cloth_"+side,"hip",Vector2(xx,0.58),Vector2(xx,0.78))
			_bone("hem_"+side,"cloth_"+side,Vector2(xx,0.78),Vector2(xx,0.98))
	if identity == 3:
		_bone("wing_l","chest",Vector2(0.35,0.30),Vector2(0.11,0.44))
		_bone("wing_r","chest",Vector2(0.70,0.30),Vector2(0.92,0.46))
	if identity == 2:
		_bone("cage_l","chest",Vector2(.16,.26),Vector2(.15,.86))
		_bone("cage_r","chest",Vector2(.80,.21),Vector2(.80,.88))
	if identity in [2,6]:
		_bone("weapon","hand_r",hr,Vector2(0.20,0.97))
	if identity == 4:
		_bone("weapon","hand_l",hl,Vector2(0.19,0.13))


func _layout_beast() -> void:
	_bone("hip","",Vector2(0.70,0.52),Vector2(0.44,0.43))
	_bone("chest","hip",Vector2(0.44,0.43),Vector2(0.27,0.42))
	_bone("head","chest",Vector2(0.27,0.42),Vector2(0.10,0.58))
	_bone("jaw","head",Vector2(0.16,0.59),Vector2(0.07,0.65))
	var legs := [["front_far",Vector2(0.40,0.59),Vector2(0.20,0.72),Vector2(0.07,0.86)],
		["front",Vector2(0.47,0.58),Vector2(0.35,0.78),Vector2(0.31,0.94)],
		["back_far",Vector2(0.69,0.60),Vector2(0.78,0.75),Vector2(0.74,0.88)],
		["back",Vector2(0.80,0.59),Vector2(0.87,0.76),Vector2(0.89,0.91)]]
	for leg in legs:
		_bone(leg[0],"chest" if String(leg[0]).begins_with("front") else "hip",leg[1],leg[2])
		_bone(leg[0]+"_shin",leg[0],leg[2],leg[3])
	_bone("tail","hip",Vector2(0.81,0.43),Vector2(0.96,0.58))


# ------------------------------------------------------------------ PESOS

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var v: Vector2 = b-a
	return p.distance_to(a+v*clampf((p-a).dot(v)/maxf(v.length_squared(),0.01),0,1))


func _weights(uv: Vector2) -> Dictionary:
	if kind == "biped": return _weights_biped(uv)
	# Espectros, Rei e fera: campo contínuo original (já aprovado), sem mudança.
	var result: Dictionary = {}
	var active: Array = []
	for id in bones:
		if kind == "beast" or not (String(id).begins_with("cloth_") or String(id).begins_with("hem_")):
			active.append(id)
		elif kind in ["spirit","king"]: active.append(id)
	if kind in ["spirit","king"]:
		for id in ["thigh_l","thigh_r","shin_l","shin_r"]: active.erase(id)
	var weighted: Array = []
	for id in active:
		var d: float = _distance_to_segment(_point(uv),points[id],ends[id])
		var w: float = 1.0/pow(1.0+d*0.28,5)
		if kind != "beast":
			if id in ["arm_l","fore_l","hand_l"]:
				w *= (1.0-smoothstep(.29,.45,uv.x))*(1.0-smoothstep((points.hand_l.y/100+1)+.015,(points.hand_l.y/100+1)+.08,uv.y))
			elif id in ["arm_r","fore_r","hand_r"]:
				w *= smoothstep(.56,.72,uv.x)*(1.0-smoothstep((points.hand_r.y/100+1)+.015,(points.hand_r.y/100+1)+.08,uv.y))
			elif id == "head": w *= 1.0-smoothstep(.22,.34,uv.y)
			elif id == "chest": w *= 1.0-smoothstep(.48,.65,uv.y)
		if id == "hip": w *= 0.45
		weighted.append([id,w])
	return _top4(weighted)


func _top4(weighted: Array) -> Dictionary:
	weighted.sort_custom(func(x: Array,y: Array) -> bool: return x[1]>y[1])
	var result: Dictionary = {}
	var sum: float = 0
	for i in mini(4,weighted.size()):
		if weighted[i][1] <= 0.0: break
		result[weighted[i][0]] = weighted[i][1]
		sum += weighted[i][1]
	if sum <= 0.0: return {"hip":1.0}
	for id in result: result[id] /= sum
	return result


func _weights_biped(uv: Vector2) -> Dictionary:
	# Distância ao osso + portões por região (braço não puxa o tronco, perna
	# não puxa a cintura). A suavização na malha espalha depois entre vizinhos.
	var j: Dictionary = joint_uv
	var waist: float = j.hip[0].y
	var lx_in: float = maxf(j.arm_l[0].x,maxf(j.fore_l[0].x,j.hand_l[0].x))
	var rx_in: float = minf(j.arm_r[0].x,minf(j.fore_r[0].x,j.hand_r[0].x))
	var l_bottom: float = maxf(j.hand_l[0].y,j.hand_l[1].y)
	var r_bottom: float = maxf(j.hand_r[0].y,j.hand_r[1].y)
	var p: Vector2 = _point(uv)
	var weighted: Array = []
	for zone in ZONES.get(identity,[]):
		var r: Rect2 = zone[1]
		if r.has_point(uv): return {zone[0]:1.0}
	for id in bones:
		if id == "weapon" or String(id).begins_with("cage_"): continue
		var d: float = _distance_to_segment(p,points[id],ends[id])
		var w: float = 1.0/pow(1.0+d*0.22,4)
		if id in ["arm_l","fore_l","hand_l"]:
			w *= 1.0-smoothstep(lx_in+0.0,lx_in+0.06,uv.x)
			w *= 1.0-smoothstep(l_bottom+0.01,l_bottom+0.07,uv.y)
			w *= smoothstep(j.arm_l[0].y-0.10,j.arm_l[0].y-0.03,uv.y)
		elif id in ["arm_r","fore_r","hand_r"]:
			w *= smoothstep(rx_in-0.06,rx_in-0.0,uv.x)
			w *= 1.0-smoothstep(r_bottom+0.01,r_bottom+0.07,uv.y)
			w *= smoothstep(j.arm_r[0].y-0.10,j.arm_r[0].y-0.03,uv.y)
		elif id in ["thigh_l","shin_l"]:
			w *= smoothstep(waist-0.01,waist+0.08,uv.y)*(1.0-smoothstep(j.hip[0].x-0.01,j.hip[0].x+0.05,uv.x))
		elif id in ["thigh_r","shin_r"]:
			w *= smoothstep(waist-0.01,waist+0.08,uv.y)*smoothstep(j.hip[0].x-0.05,j.hip[0].x+0.01,uv.x)
		elif id == "head":
			w *= 1.0-smoothstep(j.head[0].y-0.01,j.head[0].y+0.06,uv.y)
		elif id == "chest":
			w *= 1.0-smoothstep(waist-0.10,waist+0.02,uv.y)
		elif id == "hip":
			w *= 0.7
		elif String(id).begins_with("cloth_") or String(id).begins_with("hem_"):
			w *= 0.75*smoothstep(j[id][0].y-0.02,j[id][0].y+0.05,uv.y)
		weighted.append([id,w])
	return _top4(weighted)


# ------------------------------------------------------------------ MALHA

func _layer_texture(layer: String) -> Texture2D:
	var path: String = DERIVED+NAMES[identity]+"_"+layer+".png"
	if ResourceLoader.exists(path): return load(path)
	return null


func _alpha(img: Image, px: Vector2i, keyed: bool) -> float:
	var c: Color = img.get_pixelv(px)
	if not keyed: return c.a
	# Folha original RGB: mesma chave do painted_key.gdshader.
	var key: float = minf(c.r,c.b)-c.g
	return 1.0-smoothstep(0.20,0.48,key)


func _build_body(cols: int, rows: int) -> void:
	var tex: Texture2D = _layer_texture("body")
	var uv_rect := Rect2(Vector2.ZERO,Vector2.ONE)
	var keyed: bool = false
	if tex == null:
		tex = PaintedLibrary.sheet(paint.sheet)
		uv_rect = paint.rect
		keyed = true
	else:
		uv_rect = Rect2(Vector2.ZERO,tex.get_size())
	base_texture = tex
	skin = Polygon2D.new()
	skin.name = "PaintedSkin"
	skin.texture = tex
	skin.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if keyed: skin.material = PaintedLibrary.material()
	skin.skeleton = NodePath("../Skeleton")
	var key: String = "%d:%d:%d:%s" % [identity,cols,rows,tex.resource_path]
	if not _mesh_cache.has(key): _mesh_cache[key] = _make_mesh(tex,uv_rect,keyed,cols,rows)
	var mesh: Dictionary = _mesh_cache[key]
	skin.polygon = mesh.polygon
	skin.uv = mesh.uv
	skin.polygons = mesh.polygons
	vertex_count = mesh.polygon.size()
	triangle_count = mesh.polygons.size()
	add_child(skin)
	move_child(skin,skeleton.get_index()+1)
	for id in bones: skin.add_bone(skeleton.get_path_to(bones[id]),mesh.weights[id])


func _make_mesh(tex: Texture2D, uv_rect: Rect2, keyed: bool, cols: int, rows: int) -> Dictionary:
	var img: Image = tex.get_image()
	if img.is_compressed(): img.decompress()
	var size := Vector2(img.get_width()-1,img.get_height()-1)
	var src_scale := Vector2(float(img.get_width()),float(img.get_height()))/tex.get_size()
	# 1) Células com algum pixel visível (amostra 4×4 por célula).
	var keep := PackedByteArray()
	keep.resize(cols*rows)
	for row in rows:
		for column in cols:
			var hit: bool = false
			for sy in 4:
				for sx in 4:
					var uv := Vector2((column+(sx+0.5)/4.0)/cols,(row+(sy+0.5)/4.0)/rows)
					var px: Vector2 = (uv_rect.position+uv*uv_rect.size)*src_scale
					if _alpha(img,Vector2i(clampi(int(px.x),0,int(size.x)),clampi(int(px.y),0,int(size.y))),keyed) > 0.04:
						hit = true
						break
				if hit: break
			keep[row*cols+column] = 1 if hit else 0
	# 2) Só os vértices usados por células mantidas.
	var index := PackedInt32Array()
	index.resize((cols+1)*(rows+1))
	index.fill(-1)
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var grid_uv := PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []
	var neighbors: Array = []
	for row in rows:
		for column in cols:
			if keep[row*cols+column] == 0: continue
			var corner := [row*(cols+1)+column,row*(cols+1)+column+1,(row+1)*(cols+1)+column,(row+1)*(cols+1)+column+1]
			for c in corner:
				if index[c] < 0:
					index[c] = vertices.size()
					var uv := Vector2(float(c%(cols+1))/cols,float(floori(float(c)/(cols+1)))/rows)
					vertices.append(_point(uv))
					uvs.append(uv_rect.position+uv*uv_rect.size)
					grid_uv.append(uv)
					neighbors.append([])
			var a: int = index[corner[0]]
			var b: int = index[corner[1]]
			var c2: int = index[corner[2]]
			var d: int = index[corner[3]]
			triangles.append(PackedInt32Array([a,b,c2]))
			triangles.append(PackedInt32Array([b,d,c2]))
			for pair in [[a,b],[a,c2],[b,d],[c2,d]]:
				if not neighbors[pair[0]].has(pair[1]):
					neighbors[pair[0]].append(pair[1])
					neighbors[pair[1]].append(pair[0])
	# 3) Pesos: campo por osso + suavização pela malha (espalha entre vizinhos
	#    conectados; fundo vazio não conduz peso de um membro ao outro).
	var ids: Array = bones.keys()
	var count: int = vertices.size()
	var per_vertex: Array = []
	for v in count: per_vertex.append(_weights(grid_uv[v]))
	var field: Array = []
	for id in ids:
		var f := PackedFloat32Array()
		f.resize(count)
		for v in count: f[v] = per_vertex[v].get(id,0.0)
		field.append(f)
	if kind == "biped":
		for it in 3:
			for k in ids.size():
				var src: PackedFloat32Array = field[k]
				var dst := src.duplicate()
				for v in count:
					var n: Array = neighbors[v]
					if n.is_empty(): continue
					var acc: float = 0.0
					for o in n: acc += src[o]
					dst[v] = src[v]*0.5+acc/n.size()*0.5
				field[k] = dst
		# Recorta para 4 influências e normaliza.
		for v in count:
			var weighted: Array = []
			for k in ids.size():
				var fk: PackedFloat32Array = field[k]
				if fk[v] > 0.0005: weighted.append([ids[k],fk[v]])
			per_vertex[v] = _top4(weighted)
		field.clear()
		for id in ids:
			var f := PackedFloat32Array()
			f.resize(count)
			for v in count: f[v] = per_vertex[v].get(id,0.0)
			field.append(f)
	var weights: Dictionary = {}
	for k in ids.size(): weights[ids[k]] = field[k]
	return {"polygon":vertices,"uv":uvs,"polygons":triangles,"weights":weights}


func _build_parts() -> void:
	var tex: Texture2D = _layer_texture("parts")
	if tex == null or not PARTS.has(identity): return
	var defs: Dictionary = PARTS[identity]
	var i: int = 0
	for pid in defs:
		var holder: Node2D = bones.weapon if pid == "weapon" else Node2D.new()
		var origin: Vector2 = points.weapon if pid == "weapon" else Vector2.ZERO
		if pid != "weapon":
			var centre := Vector2.ZERO
			for uv in defs[pid][0]: centre += _point(uv)
			centre /= defs[pid][0].size()
			origin = centre
			holder.name = pid
			holder.position = centre-points.hip
			bones.hip.add_child(holder)
			floaters.append({"node":holder,"base":holder.position,"i":i})
			i += 1
		for outline in defs[pid]:
			var part := Polygon2D.new()
			part.texture = tex
			part.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			part.z_index = 1
			var local_points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for uv in outline:
				var u: Vector2 = Vector2(clampf(uv.x,0,1),clampf(uv.y,0,1))
				local_points.append(_point(u)-origin)
				uvs.append(u*tex.get_size())
			part.polygon = local_points
			part.uv = uvs
			holder.add_child(part)
			pieces.append(part)


## Troca a pintura do corpo por estado (quadros futuros). Passe null para remover.
func set_state_texture(state: String, tex: Texture2D) -> void:
	if tex == null: state_textures.erase(state)
	else: state_textures[state] = tex


# ------------------------------------------------------------------ MOLAS

func _group(id: String) -> String:
	if id in ["hip","chest","head"]: return "core"
	if id.begins_with("arm_") or id.begins_with("fore_") or id.begins_with("hand_") or id == "weapon": return "arm"
	if id.begins_with("cloth_") or id.begins_with("hem_") or id.begins_with("wing_") or id == "tail": return "cloth"
	if id.begins_with("cage_"): return "cage"
	return "leg"


func _aim(id: String, angle: float) -> void:
	if bones.has(id): tgt[id] = angle


## Mantida por compatibilidade: agora só define o alvo da mola.
func _rotate(id: String, angle: float, _delta: float = 0.0, _speed: float = 18.0) -> void:
	_aim(id,angle)


func _integrate(delta: float) -> void:
	var steps: int = clampi(ceili(delta*120.0),1,8)
	var h: float = minf(delta,0.1)/steps
	for id in tgt:
		var t: Vector2 = tune.get(_group(id),Vector2(4,0.7))
		var w: float = TAU*t.x
		var a: float = ang[id]
		var v: float = vel[id]
		for s in steps:
			v += (-2.0*t.y*w*v-w*w*(a-tgt[id]))*h
			a += v*h
		ang[id] = a
		vel[id] = v
		bones[id].rotation = a
	var hw: float = TAU*(tune.get("core",Vector2(4,0.7)).x)
	for s in steps:
		hip_v += (-2.0*0.55*hw*hip_v-hw*hw*(hip_y-hip_t))*h
		hip_y += hip_v*h


func _tune(core: Vector2, arm: Vector2) -> void:
	tune["core"] = core
	tune["arm"] = arm


func _ease_out(t: float) -> float:
	t = clampf(t,0,1)
	return 1.0-pow(1.0-t,3)


func drive(state: String, time: float, delta: float, progress: float = -1.0, stride: float = 1.0, fury: float = 1.0) -> void:
	if skin == null: ensure_built()
	clock += delta
	var entered: bool = state != last_state
	last_state = state
	# Textura por estado (quadros pintados no futuro).
	if not state_textures.is_empty():
		var want: Texture2D = state_textures.get(state,base_texture)
		if skin.texture != want: skin.texture = want
	var walking: bool = state in ["walk","charge"]
	var target_gait: float = clampf(stride,0.0,1.5) if walking else 0.0
	gait = lerpf(gait,target_gait,1.0-exp(-delta*10))
	var cycle: float = clock*(7.0 if kind == "biped" else 5.5)*fury
	var step: float = sin(cycle)*gait
	var breathing: float = sin(clock*2.1)
	var attack: bool = state in ["attack","attack_heavy","cast","charge","attack_up"]
	var preparing: bool = state.begins_with("windup")
	var ph: float = progress if progress >= 0 else clampf(time/(0.55 if preparing else 0.25),0,1)
	# Preparação: chega à pose em 35% e SEGURA (tensão crescente, tremor fino).
	var anticipation: float = 0.0
	if preparing:
		anticipation = _ease_out(ph/0.35)*(1.0+0.10*smoothstep(0.35,1.0,ph))
		anticipation += sin(clock*47.0)*0.012*smoothstep(0.5,1.0,ph)
	# Golpe: dispara em 2–3 quadros (peito antes, braço logo depois) e assenta.
	var hit_core: float = 0.0
	var hit_arm: float = 0.0
	if attack:
		hit_core = _ease_out(ph/0.08)*(1.0-0.30*smoothstep(0.45,1.0,ph))
		hit_arm = _ease_out((ph-0.03)/0.10)*(1.0-0.35*smoothstep(0.45,1.0,ph))
	var heavy: float = 1.25 if state == "attack_heavy" or state == "windup_heavy" else 1.0
	# Molas por estado: idle solto; preparação firme; golpe com sobressalto.
	tune = {"core":Vector2(3.2,0.75),"arm":Vector2(2.6,0.55),"leg":Vector2(4.0,0.8),"cloth":Vector2(1.6,0.28),"cage":Vector2(1.1,0.12)}
	if preparing: _tune(Vector2(4.0,0.85),Vector2(3.4,0.8))
	if attack: _tune(Vector2(7.5,0.42),Vector2(9.0,0.36))
	if state == "recover": _tune(Vector2(2.6,0.7),Vector2(2.2,0.6))
	if state in ["hurt","stagger"]: _tune(Vector2(5.0,0.35),Vector2(4.0,0.3))
	if state == "dead": _tune(Vector2(2.0,0.9),Vector2(1.5,0.5))
	# Pose-alvo (amplitudes ~55% das antigas: as junções não se abrem).
	var arm_l: float = -step*0.10+breathing*0.012
	var arm_r: float = step*0.09-breathing*0.012
	var elbow_l: float = -0.04*gait
	var elbow_r: float = -0.04*gait
	var torso: float = breathing*0.008+step*0.015
	var nod: float = -breathing*0.010
	hip_t = -absf(step)*1.1
	if preparing:
		arm_l -= 0.17*anticipation*heavy
		arm_r -= 0.14*anticipation*heavy
		elbow_l = -0.11*anticipation
		elbow_r = -0.08*anticipation
		torso = -0.05*anticipation*heavy
		nod = 0.04*anticipation
		hip_t += 1.6*anticipation*heavy
	if attack:
		arm_l += 0.19*hit_arm*heavy
		arm_r += 0.17*hit_arm*heavy
		elbow_l = 0.13*hit_arm
		elbow_r = 0.11*hit_arm
		torso = 0.06*hit_core*heavy
		nod = -0.03*hit_core
		hip_t += 0.8*hit_core
	if state == "recover":
		var back: float = 1.0-smoothstep(0.0,1.0,ph)
		arm_l = 0.12*back; arm_r = 0.09*back
		torso = 0.04*back
		hip_t += 0.5*back
	if state == "block": arm_l=0.36; elbow_l=0.33; arm_r=0.19; torso=-0.04
	if state in ["hurt","stagger"]:
		var fade: float = 1.0-clampf(time/0.6,0,1)
		torso=-0.08*fade; nod=0.09*fade
		arm_l=-0.14*fade; arm_r=0.19*fade
	if state == "dodge": torso=0.11; hip_t=4.0; arm_l=0.25
	if state == "dead":
		var fall: float = clampf(time/0.5,0,1)
		torso=-0.65*fall; hip_t=12*fall
	# Estalo/impacto na entrada do estado (velocidade injetada na mola).
	if entered:
		if attack:
			vel["chest"] += 1.6*heavy
			for id in ["arm_l","arm_r"]:
				if vel.has(id): vel[id] += 3.0*heavy
		if state in ["hurt","stagger"]:
			vel["chest"] -= 4.5
			vel["head"] += 6.0
			for id in ["arm_l","arm_r"]:
				if vel.has(id): vel[id] += (-3.5 if id == "arm_l" else 3.5)
			hip_v += 25.0
	if kind in ["spirit","king"]:
		arm_l *= .8; arm_r *= .8; elbow_l *= .8; elbow_r *= .8
	_aim("chest",torso)
	_aim("head",nod-ang.get("chest",0.0)*0.35)
	if kind == "beast":
		_drive_beast(state,step,cycle,anticipation,hit_core,delta)
	else:
		_aim("arm_l",arm_l)
		_aim("arm_r",arm_r)
		_aim("fore_l",elbow_l)
		_aim("fore_r",elbow_r)
		_aim("hand_l",-elbow_l*0.25)
		_aim("hand_r",-elbow_r*0.25)
		_aim("thigh_l",step*0.13)
		_aim("thigh_r",-step*0.13)
		_aim("shin_l",maxf(0,-step)*0.17)
		_aim("shin_r",maxf(0,step)*0.17)
		# Pano: atrasado e arrastado pelo corpo (inércia do peito e do quadril).
		var drag: float = -vel.get("chest",0.0)*0.05-hip_v*0.004
		var i: int = 0
		for id in tgt.keys():
			if String(id).begins_with("cloth_"):
				var flutter: float = sin(clock*2.6+i*1.8)*(0.035+gait*0.03)
				var spirit_k: float = 1.0 if kind in ["spirit","king"] else 0.6
				_aim(id,(flutter+drag)*spirit_k+gait*0.03)
				_aim("hem_"+String(id).trim_prefix("cloth_"),-flutter*1.3-drag*0.6)
				i += 1
		for side in ["l","r"]:
			_aim("cage_"+side,-ang.get("chest",0.0)*0.9+sin(cycle*0.5+(0.0 if side == "l" else 1.3))*0.05*gait-hip_v*0.002)
		if kind == "spirit":
			hip_t += sin(clock*2.1)*1.4
			_aim("wing_l",sin(clock*2.8)*0.10-anticipation*0.12+hit_core*0.13)
			_aim("wing_r",-sin(clock*2.8)*0.10+anticipation*0.12-hit_core*0.13)
	_integrate(delta)
	var hip: Bone2D = bones.hip
	hip.position = hip_rest+Vector2(0,hip_y)
	# Respiração: o peito enche de leve (escala no osso, a malha acompanha).
	bones.chest.scale = Vector2(1.0,1.0+breathing*0.010*(1.0-gait))
	# Cristais flutuam soltos; juntam na preparação e se abrem no golpe.
	for f in floaters:
		var k: int = f.i
		var bob := Vector2(sin(clock*1.3+k*1.7)*1.0,sin(clock*1.7+k*2.3)*1.8)
		var dir: Vector2 = (f.base as Vector2).normalized()
		f.node.position = f.base+bob-dir*anticipation*2.0+dir*hit_core*3.0
	debug_layer.visible = debug_bones
	if debug_bones: debug_layer.queue_redraw()


func _drive_beast(state: String, step: float, cycle: float, anticipation: float, release: float, _delta: float) -> void:
	_aim("head",sin(clock*2.6)*0.025-anticipation*0.14+release*0.14)
	_aim("jaw",0.02+anticipation*0.13+release*0.10)
	_aim("tail",sin(clock*3.2)*0.12-gait*0.05-vel.get("hip",0.0)*0.05)
	var run: float = 1.5 if state == "charge" else 1.0
	for i in 4:
		var id: String = ["front_far","front","back_far","back"][i]
		var stride: float = sin(cycle+[PI,0.0,0.3,PI+0.3][i])*gait*run
		_aim(id,stride*0.22-anticipation*0.12)
		_aim(id+"_shin",maxf(0,-stride)*0.33+anticipation*0.18)
	hip_t += anticipation*2.5-absf(step)*1.2


func _draw_bones() -> void:
	for id in bones:
		var b: Bone2D = bones[id]
		var origin: Vector2 = to_local(b.global_position)
		var target: Vector2 = to_local(b.to_global(ends[id]-points[id]))
		debug_layer.draw_line(origin,target,Color(0.4,1.0,0.85,0.8),0.5,true)
		debug_layer.draw_circle(origin,1.0,Color("fff0b4"))
