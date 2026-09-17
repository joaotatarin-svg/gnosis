extends Node2D
class_name BossPuppet
## Bonecos ilustrados: armaduras em recortes rígidos; tecidos e fera com pele UV.
## Pivôs definidos por pintura. O esqueleto recebe o estado real do combate.

const COLS: int = 48
const ROWS: int = 64
var skeleton: Skeleton2D
var skin: Polygon2D
var bones: Dictionary = {}
var points: Dictionary = {}
var ends: Dictionary = {}
var kind: String = "biped"
var identity: int = 0
var aspect: float = 1.0
var clock: float = 0.0
var gait: float = 0.0
var debug_bones: bool = false
var debug_layer: Node2D
var blade_outline := PackedVector2Array()
var pieces: Array[Polygon2D] = []

func configure(paint: Dictionary) -> void:
	identity = int(paint.get("puppet",0))
	aspect = paint.rect.size.x / paint.rect.size.y
	kind = "spirit" if identity in [0,3] else "biped"
	if identity == 5: kind = "beast"
	if identity == 8: kind = "king"
	skeleton = Skeleton2D.new()
	skeleton.name = "Skeleton"
	add_child(skeleton)
	_layout()
	if identity == 2:
		blade_outline = PackedVector2Array([Vector2(.66,.49),Vector2(.73,.50),Vector2(.78,.57),Vector2(.68,.61),Vector2(.235,.997),Vector2(.20,.985),Vector2(.52,.62),Vector2(.59,.56)])
	elif identity == 6:
		blade_outline = PackedVector2Array([Vector2(.72,.535),Vector2(.80,.58),Vector2(.69,.645),Vector2(.065,.975),Vector2(.05,.95),Vector2(.22,.78),Vector2(.57,.615),Vector2(.62,.55)])
	_build_mesh(paint)
	debug_layer = Node2D.new()
	debug_layer.visible = false
	debug_layer.z_index = 2
	debug_layer.draw.connect(_draw_bones)
	add_child(debug_layer)

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

func _layout() -> void:
	# Ombros/cotovelos/quadris específicos evitam dobrar a roupa como um cartão.
	var hip := Vector2(0.53,0.61)
	var chest := Vector2(0.51,0.32)
	var head := Vector2(0.51,0.19)
	var al := Vector2(0.30,0.28)
	var el := Vector2(0.23,0.44)
	var hl := Vector2(0.22,0.62)
	var ar := Vector2(0.72,0.29)
	var er := Vector2(0.78,0.46)
	var hr := Vector2(0.80,0.63)
	var kl := Vector2(0.37,0.80)
	var kr := Vector2(0.67,0.80)
	var fl := Vector2(0.31,0.96)
	var fr := Vector2(0.70,0.96)
	match identity:
		0:
			head=Vector2(0.56,0.20); al=Vector2(0.41,0.30); el=Vector2(0.34,0.41); hl=Vector2(0.32,0.49)
			ar=Vector2(0.65,0.31); er=Vector2(0.77,0.41); hr=Vector2(0.86,0.47)
		1:
			head=Vector2(0.45,0.18); chest=Vector2(0.5,0.35)
			al=Vector2(0.25,0.27); el=Vector2(0.17,0.45); hl=Vector2(0.15,0.66)
			ar=Vector2(0.72,0.28); er=Vector2(0.82,0.47); hr=Vector2(0.82,0.68)
			kl=Vector2(0.31,0.79); fl=Vector2(0.23,0.91)
		2:
			head=Vector2(0.42,0.20); al=Vector2(0.30,0.29); el=Vector2(0.26,0.43); hl=Vector2(0.26,0.57)
			ar=Vector2(0.68,0.28); er=Vector2(0.70,0.45); hr=Vector2(0.63,0.59)
		3:
			head=Vector2(0.44,0.23); chest=Vector2(0.52,0.36)
			al=Vector2(0.38,0.35); el=Vector2(0.33,0.44); hl=Vector2(0.33,0.59)
			ar=Vector2(0.66,0.32); er=Vector2(0.69,0.43); hr=Vector2(0.52,0.46)
		4:
			head=Vector2(0.49,0.23); chest=Vector2(0.51,0.38)
			al=Vector2(0.32,0.31); el=Vector2(0.29,0.43); hl=Vector2(0.23,0.49)
			ar=Vector2(0.65,0.34); er=Vector2(0.73,0.47); hr=Vector2(0.70,0.63)
			kl=Vector2(.52,.75); fl=Vector2(.52,.97); kr=Vector2(.60,.76); fr=Vector2(.60,.97)
		6:
			head=Vector2(0.41,0.22); al=Vector2(0.27,0.32); el=Vector2(0.17,0.46); hl=Vector2(0.20,0.60)
			ar=Vector2(0.71,0.31); er=Vector2(0.81,0.46); hr=Vector2(0.74,0.61)
		7:
			head=Vector2(0.46,0.15); chest=Vector2(0.5,0.32)
			al=Vector2(0.18,0.30); el=Vector2(0.12,0.48); hl=Vector2(0.15,0.65)
			ar=Vector2(0.77,0.31); er=Vector2(0.83,0.49); hr=Vector2(0.83,0.66)
			kl=Vector2(.48,.78); fl=Vector2(.50,.98); kr=Vector2(.69,.78); fr=Vector2(.68,.90)
		8:
			head=Vector2(0.51,0.16); hip=Vector2(0.51,0.52); chest=Vector2(0.51,0.27)
			al=Vector2(0.33,0.23); el=Vector2(0.29,0.37); hl=Vector2(0.18,0.44)
			ar=Vector2(0.68,0.21); er=Vector2(0.75,0.33); hr=Vector2(0.81,0.28)
	if kind == "beast":
		_layout_beast()
		return
	_bone("hip","",hip,chest)
	_bone("chest","hip",chest,head)
	_bone("head","chest",head,head+Vector2(0,-0.10))
	_bone("arm_l","chest",al,el)
	_bone("fore_l","arm_l",el,hl)
	_bone("hand_l","fore_l",hl,hl+Vector2(-0.06,0.02))
	_bone("arm_r","chest",ar,er)
	_bone("fore_r","arm_r",er,hr)
	_bone("hand_r","fore_r",hr,hr+Vector2(-0.06,0.02))
	_bone("thigh_l","hip",Vector2(0.41,hip.y),kl)
	_bone("shin_l","thigh_l",kl,fl)
	_bone("thigh_r","hip",Vector2(0.64,hip.y),kr)
	_bone("shin_r","thigh_r",kr,fr)
	for side in ["l","c","r"]:
		var xx: float = {"l":0.26,"c":0.51,"r":0.76}[side]
		_bone("cloth_"+side,"hip",Vector2(xx,0.58),Vector2(xx,0.78))
		_bone("hem_"+side,"cloth_"+side,Vector2(xx,0.78),Vector2(xx,0.98))
	if identity == 3:
		_bone("wing_l","chest",Vector2(0.35,0.30),Vector2(0.11,0.44))
		_bone("wing_r","chest",Vector2(0.70,0.30),Vector2(0.92,0.46))
	if identity in [2,6]:
		_bone("weapon","hand_r",hr,Vector2(0.18,0.98))
	if identity == 4:
		_bone("weapon","hand_l",hl,Vector2(0.22,0.08))

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

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var v: Vector2 = b-a
	return p.distance_to(a+v*clampf((p-a).dot(v)/maxf(v.length_squared(),0.01),0,1))

func _weights(uv: Vector2) -> Dictionary:
	# Campo contínuo de influência: ombro/cotovelo dobram sem abrir a pele.
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
		if id == "weapon" and identity in [2,6]: continue
		var d: float = _distance_to_segment(_point(uv),points[id],ends[id])
		var w: float = 1.0/pow(1.0+d*0.28,5)
		if kind != "beast":
			if id in ["arm_l","fore_l","hand_l"]:
				w *= (1.0-smoothstep(.29,.45,uv.x))*(1.0-smoothstep((points.hand_l.y/100+1)+.015,(points.hand_l.y/100+1)+.08,uv.y))
			elif id in ["arm_r","fore_r","hand_r"]:
				w *= smoothstep(.56,.72,uv.x)*(1.0-smoothstep((points.hand_r.y/100+1)+.015,(points.hand_r.y/100+1)+.08,uv.y))
			elif id in ["thigh_l","thigh_r","shin_l","shin_r"]:
				w *= smoothstep(.55,.70,uv.y)
			elif id == "head": w *= 1.0-smoothstep(.22,.34,uv.y)
			elif id == "chest": w *= 1.0-smoothstep(.48,.65,uv.y)
		if id == "hip": w *= 0.45
		if id == "weapon": w *= 2.0
		weighted.append([id,w])
	weighted.sort_custom(func(x: Array,y: Array) -> bool: return x[1]>y[1])
	var sum: float = 0
	for i in mini(4,weighted.size()):
		result[weighted[i][0]] = weighted[i][1]
		sum += weighted[i][1]
	for id in result: result[id] /= sum
	return result

func _build_mesh(paint: Dictionary) -> void:
	skin = Polygon2D.new()
	skin.name = "PaintedSkin"
	skin.texture = PaintedLibrary.sheet(paint.sheet)
	skin.material = PaintedLibrary.material()
	skin.skeleton = NodePath("../Skeleton")
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []
	var weights: Dictionary = {}
	for id in bones: weights[id] = PackedFloat32Array()
	if kind == "biped":
		_build_cutouts(paint)
		return
	for row in ROWS+1:
		for column in COLS+1:
			var uv := Vector2(float(column)/COLS,float(row)/ROWS)
			vertices.append(_point(uv))
			uvs.append(paint.rect.position+uv*paint.rect.size)
			var influence: Dictionary = _weights(uv)
			for id in bones: weights[id].append(influence.get(id,0.0))
	for row in ROWS:
		for column in COLS:
			var i: int = row*(COLS+1)+column
			triangles.append(PackedInt32Array([i,i+1,i+COLS+1]))
			triangles.append(PackedInt32Array([i+1,i+COLS+2,i+COLS+1]))
	skin.polygon = vertices
	skin.uv = uvs
	skin.polygons = triangles
	add_child(skin)
	for id in bones: skin.add_bone(skeleton.get_path_to(bones[id]),weights[id])
	skin.queue_redraw()

func _segment(id: String, width: float, end_width: float) -> PackedVector2Array:
	var a: Vector2 = points[id]
	var b: Vector2 = ends[id]
	var axis: Vector2 = (b-a).normalized()
	var side := Vector2(-axis.y,axis.x)
	var cap: float = 1.4 if id.begins_with("arm_") else .85
	return PackedVector2Array([a-axis*width*cap-side*width,a-axis*width*cap+side*width,b+axis*3+side*end_width,b+axis*3-side*end_width])

func _patch(paint: Dictionary, id: String, outline: PackedVector2Array, depth: int) -> void:
	var polygons: Array[PackedVector2Array] = [outline]
	if not blade_outline.is_empty() and id != "weapon":
		var blade_points := PackedVector2Array()
		for uv in blade_outline: blade_points.append(_point(uv))
		polygons = Geometry2D.clip_polygons(outline,blade_points)
	for polygon in polygons:
		if polygon.size() < 3: continue
		var part := Polygon2D.new()
		part.texture = skin.texture
		part.material = skin.material
		part.z_index = depth
		var local_points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for point in polygon:
			local_points.append(point-points[id])
			var uv := Vector2(point.x/(100*aspect)+.5,point.y/100+1)
			uvs.append(paint.rect.position+uv*paint.rect.size)
		part.polygon = local_points
		part.uv = uvs
		bones[id].add_child(part)
		pieces.append(part)

func _uv_patch(paint: Dictionary, id: String, uvs: Array, depth: int) -> void:
	var polygon := PackedVector2Array()
	for uv in uvs: polygon.append(_point(uv))
	_patch(paint,id,polygon,depth)

func _build_cutouts(paint: Dictionary) -> void:
	# Peças rígidas sobrepostas, como um boneco: armadura e lâmina não esticam.
	if identity in [2,6]:
		# A túnica de baixo ocupa a área originalmente encoberta pela lâmina.
		var lining := Polygon2D.new()
		lining.z_index = -1
		var pp := PackedVector2Array()
		for uv in [Vector2(.33,.55),Vector2(.64,.55),Vector2(.70,.84),Vector2(.55,.97),Vector2(.46,.87),Vector2(.34,.94),Vector2(.27,.85)]: pp.append(_point(uv)-points.hip)
		lining.polygon = pp
		var cloth_color := Color("393737") if identity == 2 else Color("23272b")
		lining.vertex_colors = PackedColorArray([cloth_color,cloth_color.lightened(.08),cloth_color.darkened(.3),cloth_color,cloth_color.darkened(.4),cloth_color.lightened(.04),cloth_color.darkened(.2)])
		bones.hip.add_child(lining)
		pieces.append(lining)
	for side in ["l","r"]:
		_patch(paint,"thigh_"+side,_segment("thigh_"+side,9,8),0)
		_patch(paint,"shin_"+side,_segment("shin_"+side,8,9),1)
		_patch(paint,"arm_"+side,_segment("arm_"+side,12 if identity in [6,7] else 9,7),2)
		_patch(paint,"fore_"+side,_segment("fore_"+side,7,6),3)
		_patch(paint,"hand_"+side,_segment("hand_"+side,5,5),4)
	_uv_patch(paint,"hip",[Vector2(.34,.52),Vector2(.68,.52),Vector2(.65,.76),Vector2(.48,.98),Vector2(.35,.77)],1)
	_uv_patch(paint,"chest",[Vector2(.29,.25),Vector2(.72,.25),Vector2(.68,.45),Vector2(.65,.61),Vector2(.38,.61),Vector2(.32,.45)],5)
	_uv_patch(paint,"head",[Vector2(.29,0),Vector2(.72,0),Vector2(.70,.26),Vector2(.31,.27)],6)
	if not blade_outline.is_empty():
		var outline := PackedVector2Array()
		for uv in blade_outline: outline.append(_point(uv))
		_patch(paint,"weapon",outline,7)
	elif identity == 4:
		_uv_patch(paint,"weapon",[Vector2(.06,0),Vector2(.29,0),Vector2(.38,.99),Vector2(.29,.99)],7)
		for rect in [Rect2(.35,.01,.10,.19),Rect2(.68,.06,.14,.21),Rect2(.80,.28,.14,.27),Rect2(.08,.27,.10,.20)]:
			_uv_patch(paint,"chest",[rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)],0)
	skin.free()
	skin = null

func _rotate(id: String, angle: float, delta: float, speed: float = 18.0) -> void:
	if bones.has(id): bones[id].rotation = lerp_angle(bones[id].rotation,angle,1.0-exp(-delta*speed))

func drive(state: String, time: float, delta: float, progress: float = -1.0, stride: float = 1.0, fury: float = 1.0) -> void:
	clock += delta
	var walking: bool = state in ["walk","charge"]
	var target_gait: float = clampf(stride,0.0,1.5) if walking else 0.0
	gait = lerpf(gait,target_gait,1.0-exp(-delta*12))
	var cycle: float = clock*(7.5 if kind == "biped" else 5.5)*fury
	var step: float = sin(cycle)*gait
	var breathing: float = sin(clock*2.0)*0.025
	var attack: bool = state in ["attack","attack_heavy","cast","charge","attack_up"]
	var preparing: bool = state.begins_with("windup")
	var ph: float = progress if progress >= 0 else clampf(time/(0.55 if preparing else 0.25),0,1)
	var anticipation: float = smoothstep(0.0,0.8,ph) if preparing else 0
	var release: float = (1.0-ph*0.6) if attack else 0
	var arm_l: float = -step*0.18+breathing
	var arm_r: float = step*0.16-breathing
	var elbow_l: float = 0.0
	var elbow_r: float = 0.0
	var torso: float = breathing*0.35+step*0.025
	var nod: float = -breathing
	var hip_y: float = -absf(step)*1.3
	if preparing:
		arm_l -= 0.32*anticipation
		arm_r -= 0.25*anticipation
		elbow_l = -0.20*anticipation
		elbow_r = -0.15*anticipation
		torso = -0.08*anticipation
		nod = 0.07*anticipation
		hip_y += 1.7*anticipation
	if attack:
		arm_l += 0.34*release
		arm_r += (0.30 if state == "attack_heavy" else 0.22)*release
		elbow_l = 0.24*release
		elbow_r = 0.20*release
		torso = 0.10*release
		nod = -0.05*release
		hip_y += 1.0*release
	if state == "recover":
		arm_l = 0.40*(1.0-ph); arm_r=0.25*(1.0-ph)
		torso = 0.08*(1.0-ph)
	if state == "block": arm_l=0.65; elbow_l=0.60; arm_r=0.35; torso=-0.07
	if state in ["hurt","stagger"]:
		torso=-0.15*(1.0-clampf(time/0.6,0,1)); nod=0.16
		arm_l=-0.25; arm_r=0.35
	if state == "dodge": torso=0.2; hip_y=5.0; arm_l=0.45
	if state == "dead": torso=-0.65*clampf(time/0.5,0,1); hip_y=12*clampf(time/0.5,0,1)
	if kind in ["spirit","king"]:
		arm_l *= .48; arm_r *= .48; elbow_l *= .48; elbow_r *= .48
	_rotate("chest",torso,delta)
	_rotate("head",nod,delta)
	var hip: Bone2D = bones.hip
	hip.position = hip.rest.origin + Vector2(0,hip_y)
	if kind == "beast":
		_drive_beast(state,step,cycle,anticipation,release,delta)
	else:
		_rotate("arm_l",arm_l,delta,25 if attack else 18)
		_rotate("arm_r",arm_r,delta,25 if attack else 18)
		_rotate("fore_l",elbow_l,delta)
		_rotate("fore_r",elbow_r,delta)
		_rotate("hand_l",-elbow_l*0.25,delta)
		_rotate("hand_r",-elbow_r*0.25,delta)
		_rotate("thigh_l",step*0.24,delta)
		_rotate("thigh_r",-step*0.24,delta)
		_rotate("shin_l",maxf(0,-step)*0.30,delta)
		_rotate("shin_r",maxf(0,step)*0.30,delta)
		for i in 3:
			var side: String = ["l","c","r"][i]
			var flutter: float = sin(clock*3.0+i*1.8)*(0.06+gait*0.04)
			_rotate("cloth_"+side,flutter*(1.0 if kind in ["spirit","king"] else 0.4),delta)
			_rotate("hem_"+side,-flutter*1.5,delta)
		if kind == "spirit":
			hip.position.y += sin(clock*2.1)*1.4
			_rotate("wing_l",sin(clock*2.8)*0.12-anticipation*0.14+release*0.15,delta)
			_rotate("wing_r",-sin(clock*2.8)*0.12+anticipation*0.14-release*0.15,delta)
	debug_layer.visible = debug_bones
	if debug_bones: debug_layer.queue_redraw()

func _drive_beast(state: String, step: float, cycle: float, anticipation: float, release: float, delta: float) -> void:
	_rotate("head",sin(clock*2.6)*0.035-anticipation*0.20+release*0.20,delta)
	_rotate("jaw",0.03+anticipation*0.18+release*0.13,delta)
	_rotate("tail",sin(clock*3.2)*0.16-gait*0.06,delta)
	var run: float = 1.5 if state == "charge" else 1.0
	for i in 4:
		var id: String = ["front_far","front","back_far","back"][i]
		var stride: float = sin(cycle+[PI,0.0,0.3,PI+0.3][i])*gait*run
		_rotate(id,stride*0.28-anticipation*0.16,delta)
		_rotate(id+"_shin",maxf(0,-stride)*0.43+anticipation*0.25,delta)
	var hip: Bone2D = bones.hip
	hip.position.y += anticipation*3.0-absf(step)*1.4

func _draw_bones() -> void:
	for id in bones:
		var b: Bone2D = bones[id]
		var origin: Vector2 = to_local(b.global_position)
		var target: Vector2 = to_local(b.to_global(ends[id]-points[id]))
		debug_layer.draw_line(origin,target,Color(0.4,1.0,0.85,0.8),0.5,true)
		debug_layer.draw_circle(origin,1.0,Color("fff0b4"))
