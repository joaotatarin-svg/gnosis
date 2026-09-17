extends Area2D
class_name ExitPortal
## Fenda de luz que abre à direita quando a tela é limpa. O jogador ANDA até ela
## pra avançar (em vez de pular de tela sozinho). Desenhada por código.

signal entered

var _t: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2            # detecta o corpo do player (layer 2)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 96)
	shape.shape = rect
	shape.position = Vector2(0, -44)
	add_child(shape)
	body_entered.connect(func(b):
		if b.is_in_group("player"):
			entered.emit())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var light := Color("dcc68a")
	var cyan := Color("9de0d1")
	var arch := PackedVector2Array([Vector2(-20,0),Vector2(-20,-63)])
	for i in 33:
		var a: float = PI + PI * i / 32.0
		arch.append(Vector2(cos(a)*20,-63+sin(a)*29))
	arch.append(Vector2(20,0))
	draw_polyline(arch,Color("122e37"),8,true)
	draw_polyline(arch,Color(light,0.75),1.0,true)
	for i in 5:
		var p: float = float(i)/5.0
		draw_line(Vector2(lerpf(-14,14,p),-76),Vector2(lerpf(-14,14,p),-5),Color(cyan,0.05+sin(_t*2+i)*0.025),5.0,true)
	for i in 12:
		var ph: float = fposmod(_t*0.18+i*0.137,1.0)
		var at := Vector2(sin(i*4.7)*13,-ph*83)
		draw_circle(at,0.7,Color(light,sin(ph*PI)*0.8))
	var glyph := Vector2(0,-43)
	draw_arc(glyph,10,0,TAU,40,Color(cyan,0.7),0.8,true)
	draw_polyline(PackedVector2Array([glyph+Vector2(-3,-5),glyph+Vector2(3,0),glyph+Vector2(-3,5)]),light,1.5,true)
	draw_line(Vector2(-25,1),Vector2(25,1),Color(light,0.4),1.0,true)
