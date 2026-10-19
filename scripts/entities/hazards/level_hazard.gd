extends Node2D
class_name LevelHazard
## BASE dos perigos de cenário do level6 (Onda 6): névoa, bocas, pêndulos,
## guilhotinas, esporos, cacos... Cada perigo é um nó filho do Level, em
## coordenadas de mundo, desenhado por código e DETERMINÍSTICO (fase pelo x e
## pela tela — mesma tela, mesmo ritmo).
##
## Regras de justiça (NEURO_SATISFACAO): todo golpe do cenário AVISA antes
## (brilho/sombra/tremor ≥ 0,5 s), tem ritmo legível e se resolve com o que a
## Sophia já sabe (esquiva com i-frames, pulo, andar no tempo certo). A esquiva
## no tempo vale ESQUIVA PERFEITA (o perigo se passa por "atacante").
## Muitos perigos também ferem os INIMIGOS: atrair o bicho para a lâmina é jogada.

## Rótulo do perigo (prancha de layout, relatório, bot).
var hazard_kind: String = "hazard"
## Fase do ritmo em segundos (deslocamento do relógio), sorteada pelo layout.
var phase: float = 0.0
## Multiplicador do dano (a tabela do layout ajusta por tipo de tela).
var dmg_mult: float = 1.0

var _t: float = 0.0
## Camada pintada ATRÁS dos lutadores (Onda 7; criada por HazardArt.back_layer).
var _back: Node2D = null


func _enter_tree() -> void:
	HazardArt.setup(self)      # filtro com mipmaps (perigos pintados, Onda 7)
	add_to_group("lv6_hazard")
	# CENARIO5: perigo precisa ser LIDO — coluna de primeiro plano não o cobre.
	add_to_group("fg_guard")
	if not has_meta("fg_half"):
		set_meta("fg_half", guard_half())


## Meia-largura protegida do primeiro plano (sobrescreva se o perigo for largo).
func guard_half() -> float:
	var w = get("width")
	return (float(w) * 0.5 + 30.0) if w != null else 80.0


## Dano base do cenário: leve no começo, cresce devagar com o run (a vida da
## Sophia é ~120–300). Nunca é o que mata sozinho — é o que cobra desatenção.
func hazard_damage(base: int = 4) -> int:
	return int(round(float(base + int(GameManager.current_screen / 10)) * dmg_mult))


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## O mundo está jogável? (diálogo/loja/cena pausam a árvore; morto não leva golpe)
func _live() -> bool:
	if GameManager.state != GameManager.State.PLAYING:
		return false
	var p := _player()
	return p != null and p.health != null and not p.health.is_dead()


## Fere a Sophia pelo HURTBOX dela: respeita i-frames, bloqueio (se não for
## imparável) e conta ESQUIVA PERFEITA (o perigo é o "atacante").
func hurt_player(dmg: int, from: Vector2, knockback: float = 140.0, unblockable: bool = true) -> bool:
	var p := _player()
	if p == null or p.hurtbox == null or p.health == null:
		return false
	var before: int = p.health.current_health
	p.hurtbox.receive_hit(dmg, from, knockback, unblockable, self)
	return p.health.current_health < before


## Fere todo inimigo cujo corpo esteja no retângulo (mundo). Devolve quantos.
func hurt_enemies_in(rect: Rect2, dmg: int, from: Vector2, knockback: float = 160.0) -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Enemy) or not is_instance_valid(e) or e.estate == Enemy.EState.DEAD:
			continue
		if e.is_boss_enemy:
			continue
		if rect.has_point((e as Node2D).global_position):
			e.apply_damage(dmg, from, knockback)
			n += 1
	return n


## O corpo da Sophia está no retângulo (mundo)?
func player_in(rect: Rect2) -> bool:
	var p := _player()
	return p != null and rect.has_point(p.global_position)


## Pés da Sophia no chão (não no ar/plataforma)?
func player_grounded_low() -> bool:
	var p := _player()
	return p != null and p.is_on_floor() and p.global_position.y > 280.0


## Relógio do ritmo (com a fase): `_cycle(periodo)` devolve 0..periodo.
func _cycle(period: float) -> float:
	return fposmod(_t + phase, period)


func _physics_process(delta: float) -> void:
	_t += delta
	_tick(delta)
	queue_redraw()
	if _back != null:
		_back.queue_redraw()


## Sobrescreva: a lógica do perigo (roda no passo de física).
func _tick(_delta: float) -> void:
	pass


## Cor de contorno escuro que lê em qualquer fundo (R18).
const INK := Color(0.04, 0.04, 0.06, 0.95)
const WARN_COL := Color(1.0, 0.32, 0.25)
## Luz de contorno clara (R18): a peça que FERE salta de qualquer fundo escuro.
const RIM_COL := Color(1.0, 0.92, 0.78, 0.35)
## Fio quente no meio da borda de aviso (claro: contraste em fundo médio).
const WARN_HOT := Color(1.0, 0.74, 0.68)


## Contorno de AVISO pulsante (2 Hz) sobre a pintura: intensidade `k` 0..1.
func warn_outline(piece: String, frame: int, at: Vector2, k: float, rot: float = 0.0, scl: Vector2 = Vector2.ONE) -> void:
	if k <= 0.0:
		return
	# é INFORMAÇÃO: não cai com "Reduzir flashes" (R10 mantém o aviso)
	var a := (0.35 + 0.65 * k) * (0.55 + 0.45 * HazardArt.pulse(_t))
	# borda ESCURA por fora + vermelha por dentro: lê em fundo claro (Coroa,
	# Pleroma) e escuro (Silêncio, Torpor) — R18 / QA7 #25
	# + um FIO QUENTE claro no meio: em fundo de luminância média (onde nem o
	# escuro nem o vermelho passam de 3:1) é o fio claro que lê (contrast.py)
	HazardArt.draw_outline(self, piece, frame, at, Color(INK, 0.75 * minf(1.0, a + 0.3)), 2.8, rot, scl)
	HazardArt.draw_outline(self, piece, frame, at, Color(WARN_COL, a), 1.6, rot, scl)
	HazardArt.draw_outline(self, piece, frame, at, Color(WARN_HOT, a), 0.8, rot, scl)


## Linha de aviso com sublinhado escuro (lê em qualquer fundo — R18).
func warn_line(a: Vector2, b: Vector2, col: Color, width: float = 2.0) -> void:
	draw_line(a, b, Color(INK, minf(0.85, col.a + 0.25)), width + 2.4, true)
	draw_line(a, b, col, width, true)
	draw_line(a, b, Color(col.lightened(0.55), col.a), maxf(0.8, width * 0.4), true)
