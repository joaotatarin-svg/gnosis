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
