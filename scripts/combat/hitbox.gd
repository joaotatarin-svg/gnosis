extends Area2D
class_name Hitbox
## Área que CAUSA dano. Só acerta Hurtboxes de time diferente.
## `unblockable` = golpe vermelho estilo GoW (não pode ser aparado, só desviado).
##
## R2/R3/R4 (NEURO_SATISFACAO): UM evento de impacto por golpe, não por alvo.
## Cada alvo ganha o seu VFX no ponto de contato (um só, leve ou pesado); o
## hitstop, o chute/tremor de câmera e o som do impacto saem UMA vez no fim do
## quadro (`_flush_impact`), pelo peso do golpe, com bônus se matou ou pegou 3+.

@export var damage: int = 10
@export var knockback: float = 140.0
@export var team: String = "player"      # "player" ou "enemy"
@export var unblockable: bool = false
@export var active_by_default: bool = false

var _frame_hits: int = 0          # alvos que tomaram dano neste quadro
var _frame_kill: bool = false
var _frame_contacts: int = 0      # alvos tocados (inclui aparado/esquivado)
var _flush_queued: bool = false


func _ready() -> void:
	monitoring = active_by_default
	area_entered.connect(_on_area_entered)


func activate(new_damage: int = -1) -> void:
	if new_damage >= 0:
		damage = new_damage
	monitoring = true


func deactivate() -> void:
	monitoring = false


## O golpe atual do dono (só a Sophia tem `current_move`).
func _move() -> ComboData:
	if owner == null or not is_instance_valid(owner):
		return null
	var mv = owner.get("current_move")
	return mv as ComboData


func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox and area.team != team):
		return
	var victim: Node = area.owner if area.owner != null else area.get_parent()
	var hc = victim.get("health") if victim != null else null
	var hp_before: int = hc.current_health if hc is HealthComponent else -1
	area.receive_hit(damage, global_position, knockback, unblockable, owner)
	var took := false
	if hc is HealthComponent and is_instance_valid(hc):
		took = hc.current_health < hp_before
		if hc.is_dead() and hp_before > 0:
			_frame_kill = true
	# Sophia que bloqueou: o bloqueio tem o próprio peso (não conta como dano).
	if took and victim is Player and victim.state == Player.State.BLOCK:
		took = false
	_frame_contacts += 1
	if took:
		_frame_hits += 1
	if team == "player" and owner != null and owner.has_method("register_hit"):
		owner.register_hit()
	if owner != null and owner.has_method("on_hit_landed"):
		owner.on_hit_landed(damage)
	# R4: um VFX por par atacante-alvo, no ponto de contato (entre a arma e o corpo).
	if owner != null and owner.get_parent() != null:
		var mv := _move()
		var heavy: bool = mv != null and mv.is_heavy()
		var col := Color(1.0, 0.92, 0.7) if team == "player" else Color(1.0, 0.45, 0.35)
		var contact := Vector2(lerpf(area.global_position.x, global_position.x, 0.3), lerpf(area.global_position.y, global_position.y, 0.5))
		ImpactBurst.spawn(owner.get_parent(), contact, col, heavy)
	if not _flush_queued:
		_flush_queued = true
		_flush_impact.call_deferred()


## Um impacto por golpe: hitstop pelo peso, chute/tremor e som UMA vez.
func _flush_impact() -> void:
	_flush_queued = false
	var hits := _frame_hits
	var contacts := _frame_contacts
	var kill := _frame_kill
	_frame_hits = 0
	_frame_contacts = 0
	_frame_kill = false
	if contacts <= 0:
		return
	if team == "player":
		var mv := _move()
		var heavy: bool = mv != null and mv.is_heavy()
		var finisher: bool = mv != null and (mv.launcher or mv.sequence.size() >= 3)
		var d: float = Juice.hitstop_for(heavy, finisher, kill, hits)
		# Multi-hit (Giro): os ticks do meio congelam pouco; o último vale como final.
		if mv != null and mv.hits > 1 and int(owner.get("hits_left")) > 0:
			d = Juice.HS_MULTI_TICK + (Juice.HS_KILL_BONUS if kill else 0.0)
		# Ajuste fino por golpe, se o ComboData ganhar o campo (pedido ao Técnico).
		if mv != null and "hitstop" in mv and float(mv.get("hitstop")) > 0.0:
			d = float(mv.get("hitstop")) + (Juice.HS_KILL_BONUS if kill else 0.0)
		Juice.hit_stop(d)
		var dir_x: float = float(owner.get("facing")) if owner != null and is_instance_valid(owner) and owner.get("facing") != null else 1.0
		Juice.kick(dir_x, heavy)
		if heavy:
			Juice.shake(Juice.TRAUMA_HEAVY)
		# R4: o pesado toca "hit_heavy" NO LUGAR do "hit" (não por cima).
		Audio.play_sfx("hit_heavy" if heavy else "hit")
	else:
		if hits > 0:
			Juice.hit_stop(Juice.HS_PLAYER_HURT)
			Juice.shake(Juice.TRAUMA_HURT)
			Audio.play_sfx("hit")
