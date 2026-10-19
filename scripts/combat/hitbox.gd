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
# Combate 6 (playtest 2: "o cajado atravessa"): o golpe da Sophia segue o cajado
# DESENHADO quadro a quadro (o Player chama set_box/set_live). `_active` = o
# golpe está na fase de acerto; `_live` = o quadro atual é de impacto. Cada alvo
# toma o golpe UMA vez por ativação (a caixa anda e não pode acertar 2x).
var _active: bool = false
var _live: bool = true
var _hit_ids: Dictionary = {}
var _own_shape: bool = false
# Polimento 7 (QA7 #1, R5): `deactivate()` é chamado DENTRO do sinal de acerto
# (aparo → stagger, morte) e o Godot bloqueia mudar `monitoring` ali ("Function
# blocked during in/out signal") — a caixa seguia ligada e o golpe aparado ainda
# feria. Agora: `_off` corta o dano NA HORA (checado em _on_area_entered) e o
# `monitoring` desliga adiado (_sync_monitoring, fora do sinal).
var _off: bool = false
var _sync_queued: bool = false


func _ready() -> void:
	monitoring = active_by_default
	_active = active_by_default
	area_entered.connect(_on_area_entered)


func activate(new_damage: int = -1) -> void:
	if new_damage >= 0:
		damage = new_damage
	_active = true
	_off = false
	_hit_ids.clear()
	monitoring = _active and _live


## Encerra o golpe: deixa de ferir no mesmo instante (mesmo dentro de um sinal
## de acerto) e desliga a área no fim do quadro.
func deactivate() -> void:
	_active = false
	_off = true
	if not _sync_queued:
		_sync_queued = true
		_sync_monitoring.call_deferred()


## Religa o golpe para mais um toque (multi-hit): desliga e liga a área no mesmo
## passo de física, para o Godot reportar de novo quem já está dentro. Só fora
## de sinal (o Player chama no _physics_process).
func rearm(new_damage: int = -1) -> void:
	monitoring = false
	activate(new_damage)


## Aplica o estado pedido (`_active` e `_live`, sem `_off`) fora do sinal.
func _sync_monitoring() -> void:
	_sync_queued = false
	var want: bool = _active and _live and not _off
	if monitoring != want:
		monitoring = want


## Liga/desliga a caixa sem encerrar o golpe (quadro de impacto ou não).
func set_live(on: bool) -> void:
	_live = on
	if monitoring != (_active and _live):
		monitoring = _active and _live


## Reposiciona/redimensiona a caixa (coords locais do dono). A forma vira única
## na 1ª chamada (o recurso da cena não é compartilhado com ninguém).
func set_box(center: Vector2, size: Vector2) -> void:
	position = center
	var cs := _shape_node()
	if cs == null:
		return
	if not _own_shape:
		_own_shape = true
		cs.shape = RectangleShape2D.new()
		cs.position = Vector2.ZERO
	(cs.shape as RectangleShape2D).size = size


func box_size() -> Vector2:
	var cs := _shape_node()
	if cs != null and cs.shape is RectangleShape2D:
		return (cs.shape as RectangleShape2D).size * cs.scale
	return Vector2.ZERO


func _shape_node() -> CollisionShape2D:
	for c in get_children():
		if c is CollisionShape2D:
			return c
	return null


## Dano de CONTATO (encostar no inimigo) não fere a Sophia — playtest 2 do João:
## "a dificuldade vinha de tomar dano ao ACERTAR os inimigos". Só fere se o dono
## pedir explicitamente (`contact_hurts = true`, ex.: espinhos, investida).
func _is_harmless_contact(victim: Node) -> bool:
	if team != "enemy" or not (victim is Player) or owner == null or not is_instance_valid(owner):
		return false
	if owner.get("contact_hitbox") != self:
		return false
	return owner.get("contact_hurts") != true


## O golpe atual do dono (só a Sophia tem `current_move`).
func _move() -> ComboData:
	if owner == null or not is_instance_valid(owner):
		return null
	var mv = owner.get("current_move")
	return mv as ComboData


func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox and area.team != team):
		return
	# golpe encerrado (aparado, morto, interrompido) ou fora do quadro de impacto
	if _off or not _live:
		return
	var victim: Node = area.owner if area.owner != null else area.get_parent()
	if _is_harmless_contact(victim):
		return
	if team == "player":
		var vid: int = area.get_instance_id()
		if _hit_ids.has(vid):
			return
		_hit_ids[vid] = true
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
