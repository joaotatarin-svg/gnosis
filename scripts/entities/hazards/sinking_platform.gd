extends LevelHazard
class_name SinkingPlatform
## TORPOR — pedra que DORME: aguenta um passo, mas se a Sophia ficar parada em
## cima ela afunda no sono (meio segundo de aviso: treme e solta bolhas), some e
## volta depois. Quem anda segue; quem para, cai. Não fere (cair já é o custo).

const GRACE := 0.45        # s parada em cima até começar a afundar
const SINK_SPEED := 30.0   # px/s
const SINK_DEPTH := 30.0   # afundou isso → some
const SUNK_TIME := 1.8     # s sumida

var width: float = 120.0
var _body: StaticBody2D
var _col: CollisionShape2D
var _spr: Sprite2D
var _state: String = "rest"
var _stand: float = 0.0
var _timer: float = 0.0


func _ready() -> void:
	hazard_kind = "sinking"
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
	_spr.modulate = Color(0.78, 0.74, 1.0)
	_body.add_child(_spr)
	add_child(_body)


func _standing() -> bool:
	var p := _player()
	if p == null or not p.is_on_floor():
		return false
	var top: float = _body.global_position.y - 6.0
	return absf(p.global_position.x - _body.global_position.x) < width * 0.5 + 6.0 \
		and absf(p.global_position.y + 12.0 - top) < 7.0


func _tick(delta: float) -> void:
	match _state:
		"rest":
			if _standing():
				_stand += delta
				if _stand >= GRACE:
					_state = "sinking"
			else:
				_stand = maxf(0.0, _stand - delta * 2.0)
		"sinking":
			_body.position.y += SINK_SPEED * delta
			if _body.position.y >= SINK_DEPTH:
				_state = "sunk"
				_timer = SUNK_TIME
				_col.set_deferred("disabled", true)
				_spr.visible = false
				Audio.play_sfx_at("land", global_position, 0.1)
		"sunk":
			_timer -= delta
			if _timer <= 0.0:
				_state = "rest"
				_stand = 0.0
				_body.position.y = 0.0
				_col.set_deferred("disabled", false)
				_spr.visible = true
				_spr.modulate.a = 0.0
	if _spr.visible and _spr.modulate.a < 1.0:
		_spr.modulate.a = minf(1.0, _spr.modulate.a + delta * 2.5)
	# tremor de aviso enquanto ela está parada em cima
	_spr.position.x = sin(_t * 60.0) * 1.2 if (_stand > 0.1 or _state == "sinking") else 0.0


func _draw() -> void:
	var y := _body.position.y if _body != null else 0.0
	var col := Color(0.7, 0.65, 1.0)
	if _state == "sunk":
		# só o contorno sonhado de onde a pedra volta
		draw_rect(Rect2(-width * 0.5, -6.0, width, 12.0), Color(col, 0.18 + 0.1 * sin(_t * 4.0)), false, 1.0)
		return
	# brilho do sono na borda de cima (acende com o aviso)
	var warn := clampf(_stand / GRACE, 0.0, 1.0)
	if _state == "sinking":
		warn = 1.0
	draw_line(Vector2(-width * 0.45, y - 7.0), Vector2(width * 0.45, y - 7.0), Color(col, 0.25 + 0.5 * warn), 2.0, true)
	# bolhas de sono subindo
	for i in 4:
		var ph := fposmod(_t * 0.6 + float(i) * 0.27, 1.0)
		var bx := (float(i) - 1.5) * width * 0.22
		draw_circle(Vector2(bx, y - 10.0 - ph * 26.0), 1.5 + ph * 1.5, Color(col, (1.0 - ph) * (0.2 + 0.5 * warn)))
