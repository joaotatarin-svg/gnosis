extends LevelHazard
class_name Maw
## FOME — o CHÃO QUE DEVORA: uma boca escondida no piso. Ritmo de 3,4 s:
## fechada (só a rachadura) → AVISO 0,8 s (a rachadura acende, dentes surgem,
## poeira treme) → MORDE (0,25 s) → fecha. Quem está em cima no chão leva a
## mordida (imparável: pule ou esquive no tempo). Morde INIMIGOS também, mais
## forte — atraia o bicho para a boca.

const PERIOD := 3.4
const WARN_AT := 2.2
const BITE_AT := 3.0
const BITE_END := 3.25

var width: float = 76.0
var _bit: bool = false       # já mordeu neste ciclo
var _warned: bool = false


func _ready() -> void:
	hazard_kind = "maw"
	z_index = -1             # é chão: atrás dos lutadores


func _tick(_delta: float) -> void:
	var c := _cycle(PERIOD)
	if c < WARN_AT:
		_bit = false
		_warned = false
		return
	if c < BITE_AT:
		if not _warned:
			_warned = true
			if _near_player(320.0):
				Audio.play_sfx_at("tell_unblock", global_position, 0.05)
				Audio.play_sfx_at("hz_maw_warn", global_position, 0.05)
		return
	if c < BITE_END and not _bit:
		_bit = true
		var area := Rect2(global_position.x - width * 0.5, global_position.y - 60.0, width, 64.0)
		hurt_enemies_in(area, hazard_damage(4) * 3, global_position + Vector2(0, 20), 220.0)
		if _live() and player_in(area) and player_grounded_low():
			hurt_player(int(hazard_damage(4) * 1.5), global_position + Vector2(0, 30), 200.0, true)
		if _near_player(320.0):
			Audio.play_sfx_at("hz_maw_bite", global_position, 0.1)
			Juice.shake(0.12)


func _near_player(d: float) -> bool:
	var p := _player()
	return p != null and absf(p.global_position.x - global_position.x) < d


func _draw() -> void:
	if HazardArt.has("maw"):
		_draw_art()
	else:
		_draw_code()


## PINTURA (Onda 7): fechada (só a carne na fenda) → no AVISO treme, a
## rachadura acende e ganha contorno vermelho; na 2ª metade do aviso ela
## ABRE (os dentes aparecem: a forma avisa, não só a cor) → MORDE (as
## mandíbulas sobem) → fecha.
func _draw_art() -> void:
	var c := _cycle(PERIOD)
	var hw := width * 0.5
	var warn := 0.0
	var f := 0
	if c >= WARN_AT and c < BITE_AT:
		warn = (c - WARN_AT) / (BITE_AT - WARN_AT)
		f = 1 if warn >= 0.45 else 0
	elif c >= BITE_AT and c < BITE_END:
		f = 2
	elif c >= BITE_END:
		f = 1 if (c - BITE_END) / (PERIOD - BITE_END) < 0.5 else 0
	var sc := Vector2.ONE * (width / maxf(1.0, HazardArt.size("maw").x))
	var shake := Vector2(sin(_t * 50.0) * 1.0 * warn, 0.0)
	warn_outline("maw", f, shake, warn, 0.0, sc)
	HazardArt.draw(self, "maw", f, shake, 0.0, sc)
	if warn > 0.0:
		# a fenda acende e a poeira treme (por cima da pintura)
		warn_line(Vector2(-hw * 0.8, -1), Vector2(hw * 0.8, -1), Color(WARN_COL, 0.35 + 0.65 * warn), 1.6)
		for i in 5:
			var px := (float(i) - 2.0) * hw * 0.4 + sin(_t * 50.0 + i) * 2.0
			draw_circle(Vector2(px, -4.0 - warn * 7.0 * float(i % 2)), 1.6, Color(0.8, 0.7, 0.55, 0.6 * warn))


## Desenho por CÓDIGO (fallback sem a pintura; também a prancha "antes").
func _draw_code() -> void:
	var c := _cycle(PERIOD)
	var hw := width * 0.5
	var open := 0.0                     # 0 = fechada · 1 = escancarada
	var warn := 0.0
	if c >= WARN_AT and c < BITE_AT:
		warn = (c - WARN_AT) / (BITE_AT - WARN_AT)
		open = 0.25 * warn
	elif c >= BITE_AT and c < BITE_END:
		open = 1.0
	elif c >= BITE_END:
		open = 1.0 - (c - BITE_END) / (PERIOD - BITE_END)
	# a rachadura (sempre visível: o jogador aprende onde fica)
	var crack := PackedVector2Array()
	for i in 9:
		var k := float(i) / 8.0
		crack.append(Vector2(lerpf(-hw, hw, k), 1.0 + (2.0 if i % 2 == 0 else -1.0)))
	draw_polyline(crack, INK, 3.0, true)
	draw_polyline(crack, Color(WARN_COL, 0.25 + 0.75 * warn), 1.2, true)
	# a boca: elipse escura que abre e dentes de cima e de baixo
	if open > 0.01:
		var h := 4.0 + 18.0 * open
		draw_set_transform(Vector2(0, 2), 0, Vector2(1.0, h / hw))
		draw_circle(Vector2.ZERO, hw, Color(0.08, 0.02, 0.03, 0.95))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		var teeth := 7
		for i in teeth:
			var tx := lerpf(-hw * 0.8, hw * 0.8, float(i) / float(teeth - 1))
			var tl := (6.0 + 6.0 * open) * (1.0 - absf(tx) / hw * 0.6)
			draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, 2 - h), Vector2(tx + 3, 2 - h), Vector2(tx, 2 - h + tl)]), Color(0.92, 0.86, 0.72))
			draw_colored_polygon(PackedVector2Array([Vector2(tx - 3, 2 + h), Vector2(tx + 3, 2 + h), Vector2(tx, 2 + h - tl)]), Color(0.85, 0.78, 0.65))
	# poeira tremendo no aviso
	if warn > 0.0:
		for i in 5:
			var px := (float(i) - 2.0) * hw * 0.4 + sin(_t * 50.0 + i) * 2.0
			draw_circle(Vector2(px, -3.0 - warn * 6.0 * float(i % 2)), 1.6, Color(0.8, 0.7, 0.55, 0.6 * warn))
