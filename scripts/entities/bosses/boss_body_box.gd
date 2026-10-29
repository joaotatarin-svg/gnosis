extends Hurtbox
class_name BossBodyBox
## CAIXA DE DANO DO CORPO DESENHADO de um chefe por quadros (chefes6, 28/10).
## Playtest do João: "a Sophia atravessa o MANTO do Rei; só o centro do corpo é
## atingível". A caixa genérica do Enemy é UM retângulo com metade da largura do
## recorte em volta da pélvis — o manto largo do Rei (e o pano caído do joelho
## pra baixo) ficava fora. Aqui o corpo vira N FAIXAS horizontais (do topo ao
## pé), cada uma com a largura da silhueta PINTADA naquela altura no quadro que
## está na tela (tabela gerada por tools/chefes6/body_slabs.py: franjas finas,
## pontas de pano e a mão estendida não contam — sem apelão).
## As faixas seguem o quadro, a mola do corpo (`_body_xform`), o vira-lado e o
## teleporte. Uma Área só (várias formas) = o Hitbox da Sophia acerta UMA vez
## por golpe (R4). Enquanto esta caixa vale, a HurtShape genérica fica
## desligada (não soma 2 acertos). Sem quadros/sem tabela: nada muda.

var e: Enemy = null
var slabs: Dictionary = {}               # quadro -> [[y0, y1, x0, x1], ...] (px do recorte)
var rects: Array[Rect2] = []             # faixas atuais (local do inimigo) — sonda/depuração
var _shapes: Array[CollisionShape2D] = []
var _main_off: bool = false
var _key: String = ""


## Cria e pendura no chefe. `table` = Script gerado (const SLABS).
static func attach(enemy: Enemy, table: Script) -> BossBodyBox:
	if enemy == null or table == null:
		return null
	var b := BossBodyBox.new()
	b.name = "BodyBox"
	b.e = enemy
	b.team = "enemy"
	b.slabs = table.get_script_constant_map().get("SLABS", {})
	b.collision_layer = enemy.hurtbox.collision_layer
	b.collision_mask = enemy.hurtbox.collision_mask
	b.monitoring = false                 # só é ACHADA (o Hitbox da Sophia monitora)
	enemy.add_child(b)
	b.owner = enemy                      # o Hitbox acha a vítima por area.owner
	b.hit_received.connect(enemy._on_hit_received)
	return b


func _physics_process(_d: float) -> void:
	if e == null or not is_instance_valid(e):
		return
	var on := _fit()
	if not on:
		_set_count(0)


## Ajusta as faixas ao quadro mostrado. false = caixa desligada neste quadro.
func _fit() -> bool:
	var v = e.visual
	if v == null or not v.has_boss_frames() or slabs.is_empty():
		return false
	if e.estate == Enemy.EState.DEAD or not v.is_visible_in_tree() or v.modulate.a < 0.3:
		return false
	var br = e.brain
	if br != null and (int(br._dying) >= 0 or bool(br._airborne)):
		return false
	var key: String = v._shown_key
	var cut := key.rfind(":")
	if cut <= 0:
		return false
	var seq: Dictionary = v._boss_db.meta.states.get(key.substr(0, cut), {})
	var i := int(key.substr(cut + 1))
	if seq.is_empty() or i < 0 or i >= seq.frames.size():
		return false
	var ent: Dictionary = seq.frames[i]
	var rows: Array = slabs.get(String(ent.f), [])
	if rows.is_empty():
		return false
	var anchor := Vector2(float(ent.anchor[0]), float(ent.anchor[1]))
	# recorte → Visual (mola/escala do quadro) → global → local do inimigo
	var xf: Transform2D = e.global_transform.affine_inverse() * v.get_global_transform() * v._body_xform
	_set_count(rows.size())
	rects.clear()
	for j in rows.size():
		var r: Array = rows[j]
		var a: Vector2 = xf * (Vector2(float(r[2]), float(r[0])) - anchor)
		var b: Vector2 = xf * (Vector2(float(r[3]), float(r[1])) - anchor)
		var rc := Rect2(a, Vector2.ZERO).expand(b)
		rects.append(rc)
		var cs := _shapes[j]
		cs.position = rc.get_center()
		(cs.shape as RectangleShape2D).size = Vector2(maxf(rc.size.x, 2.0), maxf(rc.size.y, 2.0))
	_key = key
	if not _main_off:
		# a caixa genérica sai de cena só depois da 1ª faixa válida
		_main_off = true
		var hs: CollisionShape2D = e.get_node_or_null("Hurtbox/HurtShape")
		if hs != null:
			hs.set_deferred("disabled", true)
	return true


## Garante n formas ligadas (as demais desligadas).
func _set_count(n: int) -> void:
	while _shapes.size() < n:
		var cs := CollisionShape2D.new()
		cs.shape = RectangleShape2D.new()
		add_child(cs)
		_shapes.append(cs)
	for j in _shapes.size():
		var off: bool = j >= n
		if _shapes[j].disabled != off:
			_shapes[j].set_deferred("disabled", off)
	if n == 0:
		rects.clear()
