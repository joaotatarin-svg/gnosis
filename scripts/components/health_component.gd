extends Node
class_name HealthComponent
## Componente reutilizável de vida. Player e Arcontes usam o mesmo.
##
## MISERICÓRDIA OCULTA (aprovada pelo dono — docs/COMBATE.md §4): a Sophia, com
## mais de 10 % da vida, recebe um golpe que a mataria → fica com 1, UMA vez por
## luta (o componente nasce de novo a cada tela; a fase chama `reset_mercy()` ao
## trancar zona nova; a fase 2 do chefe NÃO reseta). Invisível: só um hitstop um
## pouco maior. Não vale contra insta-kill (roteiro/ferramentas, dano >= 9999).

signal health_changed(current: int, maximum: int)
signal died()
signal mercy_spared()               ## a misericórdia acabou de segurar um golpe fatal

const MERCY_MIN_RATIO := 0.10       # só se tinha mais de 10 % da vida antes do golpe
const INSTA_KILL := 9999            # dano >= isto ignora a misericórdia (roteiro/ferramentas)
const MERCY_HITSTOP := 0.12         # um pouco maior que o dano comum (75 ms)

@export var max_health: int = 100
var current_health: int = 100

## Liga sozinho quando o dono é a Sophia (Player); inimigos nunca.
var mercy_enabled: bool = false
var _mercy_used: bool = false


func _ready() -> void:
	current_health = max_health
	if get_parent() is Player:
		mercy_enabled = true


func setup(new_max: int) -> void:
	max_health = new_max
	current_health = new_max
	health_changed.emit(current_health, max_health)


## Nova luta (zona trancada / encontro novo). A fase 2 do chefe NÃO chama isto.
func reset_mercy() -> void:
	_mercy_used = false


func mercy_available() -> bool:
	return mercy_enabled and not _mercy_used


func take_damage(amount: int) -> void:
	amount = maxi(0, amount)            # dano negativo não cura (REVISAO #11)
	if current_health <= 0 or amount <= 0:
		return
	if mercy_enabled and not _mercy_used and amount < INSTA_KILL \
			and amount >= current_health \
			and current_health > maxi(1, int(ceil(max_health * MERCY_MIN_RATIO))):
		_mercy_used = true
		current_health = 1
		health_changed.emit(current_health, max_health)
		Juice.hit_stop(MERCY_HITSTOP)
		mercy_spared.emit()
		return
	current_health = maxi(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()


## Cura. Não revive morto nem aceita valor negativo (REVISAO #11).
func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	current_health = mini(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0
