extends SceneTree
## Repro: forma da batalha final morta por golpe comum fica com vida 0 e estado != DEAD.
## Rodar: godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tools/balance/repro_revive.gd
## Esperado (com o bug): "depois do golpe: hp=0 estado=HURT" e o revive não faz nada.
var _f := 0
var e
func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		var sc = load("res://scenes/entities/Enemy.tscn")
		e = sc.instantiate()
		e.type_id = "colosso"
		e.revivable = true
		var host := Node2D.new()
		root.add_child(host)
		host.add_child(e)
		e.global_position = Vector2(400, 250)
	elif _f == 10:
		print("REPRO antes: hp=%d estado=%s" % [e.health.current_health, e.EState.keys()[e.estate]])
		e._on_hit_received(e.health.max_health + 50, Vector2(300, 250), 10.0, false, null)
		print("REPRO depois do golpe: hp=%d estado=%s" % [e.health.current_health, e.EState.keys()[e.estate]])
	elif _f == 40:
		e.revive(0.45)
		print("REPRO depois de revive(0.45): hp=%d estado=%s" % [e.health.current_health, e.EState.keys()[e.estate]])
		return true
	return false
