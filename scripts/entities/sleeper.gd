extends Node2D
class_name Sleeper
## Um Adormecido: habitante do Kenoma preso na ilusão. Chegue perto pra
## despertá-lo — ele acorda, a faísca acende, e você ganha faíscas.
## Conta pro final "Semente" (Progression.sleepers_freed).

var screen: int = 1
var awake: bool = false
var _art: CharacterArt


func _ready() -> void:
	_art = CharacterArt.new()
	var p := ArtProfile.new()
	p.body = ArtProfile.Body.HUMANOID
	p.height = 42.0
	p.painted_id = "sleeper"
	p.primary = Color("435962")          # cinza: sem cor própria
	p.secondary = Color("253b43")
	p.eye = Color(0.5, 0.5, 0.55)                # olho APAGADO (dormindo)
	_art.set_profile(p)
	_art.set_anim("idle")
	add_child(_art)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2                       # detecta o corpo do player
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 46.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if awake or not body.is_in_group("player"):
		return
	awake = true
	Audio.play_sfx("sleeper_wake")
	queue_redraw()
	# Guardião §3: cada Adormecido conta e paga UMA vez por run (morrer e
	# despertá-lo de novo contava 2× para o final "Semente").
	if Progression.claim_once("adormecido:%d" % screen):
		Progression.sleepers_freed += 1
		Progression.add_orbs(10 + screen)

	# A faísca acende: olho ganha luz, brilho de despertar.
	var p: ArtProfile = _art.profile.duplicate()
	p.eye = Color(1.0, 0.92, 0.55)
	p.primary = Color(0.55, 0.5, 0.55)
	_art.set_profile(p)
	AoeNova.spawn(get_parent(), global_position + Vector2(0, -8), 0, 52.0, Color(1.0, 0.92, 0.55))
	ImpactBurst.spawn(get_parent(), global_position + Vector2(0, -20), Color(1.0, 0.92, 0.55))
	# A fala de quem acorda (legenda, sem pausar): gratidão, medo, recusa —
	# o contrapeso moral do final Semente (ROTEIRO §5, gancho 5).
	Gnosis.captions(Narrative.sleeper_line(screen))


func _draw() -> void:
	draw_set_transform(Vector2(0,24),0,Vector2(1,0.22))
	draw_circle(Vector2.ZERO,17,Color(0,0,0,0.28))
	draw_arc(Vector2.ZERO,22,0,TAU,40,Color("dcc68a") if awake else Color("688084"),0.9,true)
	draw_set_transform(Vector2.ZERO)
	if not awake:
		draw_arc(Vector2(0,-34),5,0,PI,16,Color("899fa1"),0.7,true)
