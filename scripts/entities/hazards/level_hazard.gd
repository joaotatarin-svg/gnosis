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
var hazard_kind: String = "perigo"
## Fase do ritmo em segundos (deslocamento do relógio), sorteada pelo layout.
var phase: float = 0.0
## Multiplicador do dano (a tabela do layout ajusta por tipo de tela).
var dmg_mult: float = 1.0

var _t: float = 0.0


func _enter_tree() -> void:
	add_to_group("lv6_hazard")


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


## Sobrescreva: a lógica do perigo (roda no passo de física).
func _tick(_delta: float) -> void:
	pass


## Cor de contorno escuro que lê em qualquer fundo (R18).
const INK := Color(0.04, 0.04, 0.06, 0.95)
const WARN_COL := Color(1.0, 0.32, 0.25)
