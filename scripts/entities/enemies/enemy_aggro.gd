extends RefCounted
class_name EnemyAggro
## FILA DE AGRESSÃO (Onda 6, inimigos6): no máximo MAX_ATTACKERS inimigos
## comuns preparam/desferem golpe ao mesmo tempo, e entre dois inícios de golpe
## passa pelo menos MIN_GAP s de jogo. Quem não tem a vez cerca a Sophia a uma
## distância de "roda" (flanqueia, finta) em vez de bater junto — a luta vira
## leitura de um golpe por vez, não um empilhamento de dano (NEURO: justo).
##
## Chefes e o Campeão furam a fila (são a ameaça principal), mas CONTAM nela:
## enquanto o chefe prepara, só mais um comum pode atacar.

const MAX_ATTACKERS := 2
const MIN_GAP := 0.35           # s de jogo entre dois inícios de golpe

static var _holders: Array = []
static var _last_grant_ms: int = -100000


## Pode começar um golpe agora? Se sim, já reserva a vez.
static func request(e: Node, priority: bool = false) -> bool:
	_prune()
	if _holders.has(e):
		return true
	var now := Time.get_ticks_msec()
	var gap_ok: bool = float(now - _last_grant_ms) / 1000.0 * Engine.time_scale >= MIN_GAP
	if priority or (_holders.size() < MAX_ATTACKERS and gap_ok):
		_holders.append(e)
		_last_grant_ms = now
		return true
	return false


## Devolve a vez (fim da recuperação, tomou dano, morreu).
static func release(e: Node) -> void:
	_holders.erase(e)


static func holds(e: Node) -> bool:
	return _holders.has(e)


static func count() -> int:
	_prune()
	return _holders.size()


## Limpa quem sumiu/morreu (troca de cena não chama release).
static func _prune() -> void:
	var keep: Array = []
	for h in _holders:
		if is_instance_valid(h) and h.is_inside_tree() and not (h is Enemy and h.estate == Enemy.EState.DEAD):
			keep.append(h)
	_holders = keep


# --- QA7 #10 (R21): COLEIRA dos inimigos de longe ---------------------------
## Atirador/voador não foge para a borda: o x que ele quer fica a no máximo
## LEASH px da Sophia e dentro da arena (bordas − MARGIN); quem já está fora
## (fugiu antes de a zona trancar) é puxado de volta. O enemy.gd chama em
## `_desired_x` (pedido ao polimento7 em docs/pedidos/vfx7.md).
const LEASH := 230.0
const MARGIN := 48.0


static func leash_x(e: Node2D, want_x: float) -> float:
	if e == null or not e.is_inside_tree():
		return want_x
	var x := want_x
	var pl := e.get_tree().get_first_node_in_group("player")
	if pl is Node2D:
		var px: float = (pl as Node2D).global_position.x
		x = clampf(x, px - LEASH, px + LEASH)
	var b := arena_of(e)
	if b != Vector2.ZERO:
		x = clampf(x, b.x + MARGIN, b.y - MARGIN)
	return x


## Lado do salto de RECUO: se o lado de "fuga" bate na borda (ou na coleira),
## recua para o outro lado — nunca para fora da arena.
static func retreat_dir(e: Node2D, away: float) -> float:
	if e == null or not e.is_inside_tree():
		return away
	var probe := e.global_position.x + away * 90.0
	return away if is_equal_approx(leash_x(e, probe), probe) else -away


## (x mín, x máx) da arena atual (Level.arena_bounds), ou ZERO se não houver.
static func arena_of(e: Node) -> Vector2:
	var n: Node = e.get_parent()
	while n != null:
		if n.has_method("arena_bounds"):
			var b = n.call("arena_bounds")
			return b if b is Vector2 else Vector2.ZERO
		n = n.get_parent()
	return Vector2.ZERO
