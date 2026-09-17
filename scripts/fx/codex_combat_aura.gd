extends Node2D
## Rastro do cajado e faíscas: acompanha a janela ativa do golpe real.

var player: Player
var time: float = 0.0

func _ready() -> void:
	player = get_parent() as Player
	z_index = 4

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if player == null or player.state == Player.State.DEAD:
		return
	var light := Color("a3eee2")
	if player.state == Player.State.ATTACK and player.hit_started:
		var heavy: bool = player.current_move != null and player.current_move.is_heavy()
		var radius: float = 53.0 if heavy else 38.0
		var angle: float = -1.3 + fposmod(time * 14.0, 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(player.facing, 1))
		for i in 5:
			draw_arc(Vector2(6, -5), radius - i * 2, angle, angle + 1.5, 28, Color(light, 0.42 - i * 0.075), 1.2, true)
		for i in 4:
			var a: float = angle + i * 0.4
			draw_circle(Vector2(6, -5) + Vector2.from_angle(a) * radius, 1.2, Color("ffe4a3"))
	elif player.state == Player.State.BLOCK:
		draw_arc(Vector2(player.facing * 8, -3), 27, -1.3 if player.facing > 0 else 1.8, 1.3 if player.facing > 0 else 4.5, 32, Color(light, 0.6), 1.1, true)
