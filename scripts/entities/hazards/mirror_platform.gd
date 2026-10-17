extends LevelHazard
class_name MirrorPlatform
## ESPELHO — plataforma que só existe de um lado do reflexo. As plataformas do
## grupo A e do grupo B se alternam a cada 2,4 s; 0,6 s antes de sumir, a que
## está firme pisca (aviso). Quando é "reflexo", não tem chão: só o contorno.
## O relógio é GLOBAL (todas da tela em sincronia) — o ritmo se aprende uma vez.

const HALF := 2.4             # s de cada lado
const WARN := 0.6

var width: float = 120.0
var group_b: bool = false     # grupo B = firme quando o A é reflexo
var _body: StaticBody2D
var _col: CollisionShape2D
var _spr: Sprite2D
var _solid: bool = true


func _ready() -> void:
	hazard_kind = "reflexo"
	phase = 0.0                   # sincronia: todas usam o mesmo relógio
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_col = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 12)
	_col.shape = rect
	_col.one_way_collision = true
	_body.add_child(_col)
	_spr = Sprite2D.new()
	_spr.texture = PaintedLibrary.prop(5)
	_spr.material = PaintedLibrary.material()
	_spr.scale = Vector2(width / _spr.texture.get_width(), 22.0 / _spr.texture.get_height())
	_spr.position.y = 5.0
	_spr.modulate = Color(0.8, 0.95, 1.05)
	_body.add_child(_spr)
	add_child(_body)
	_apply(_want_solid(), true)


## Relógio da tela inteira (não do nó): Time de jogo acumulado pelo Level.
func _clock() -> float:
	return _t


func _want_solid() -> bool:
	var a_solid := fposmod(_clock(), HALF * 2.0) < HALF
	return a_solid != group_b


## 0..1: aviso de que vai sumir.
func _warning() -> float:
	var c := fposmod(_clock(), HALF)
	return clampf((c - (HALF - WARN)) / WARN, 0.0, 1.0) if _solid else 0.0


func _apply(solid: bool, force: bool = false) -> void:
	if solid == _solid and not force:
		return
	_solid = solid
	_col.set_deferred("disabled", not solid)
	_spr.modulate.a = 1.0 if solid else 0.0


func _tick(_delta: float) -> void:
	_apply(_want_solid())
	if _solid:
		var w := _warning()
		_spr.modulate.a = 1.0 - 0.6 * w * (0.5 + 0.5 * sin(_t * 30.0))


func _draw() -> void:
	var glass := Color(0.75, 0.95, 1.0)
	if not _solid:
		# o reflexo: contorno e brilho de vidro onde a pedra vai aparecer
		var a := 0.22 + 0.1 * sin(_t * 3.0)
		draw_rect(Rect2(-width * 0.5, -6.0, width, 12.0), Color(glass, a), false, 1.0)
		draw_line(Vector2(-width * 0.4, 0), Vector2(width * 0.4, 0), Color(glass, a * 0.6), 1.0)
	else:
		draw_line(Vector2(-width * 0.46, -7.0), Vector2(width * 0.46, -7.0), Color(glass, 0.3 + 0.5 * _warning()), 2.0, true)
