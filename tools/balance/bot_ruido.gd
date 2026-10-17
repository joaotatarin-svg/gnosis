extends "res://tools/balance_bot.gd"
## FERRAMENTA (não faz parte do jogo): o BOT DE BALANCE com RUÍDO controlado.
## Com `--fixed-fps 60` o bot é determinístico e a semente quase não muda nada
## (o jogo mal usa o sorteio global): três rodadas com seed 1/2/3 saem IGUAIS.
## Isso esconde o ruído real — qualquer mudança mínima muda a vida carregada
## entre telas e as lutas divergem em cascata. Para medir esse ruído, este bot
## desloca a Sophia alguns pixels ao nascer em cada tela (como um humano, que
## nunca começa exatamente no mesmo ponto). Deslocamento determinístico por
## (ruido, tela): mesma opção = mesma rodada.
## Uso: igual ao BalanceBot, mais `ruido=N` (N>0 liga; N=0 = bot normal).
##   godot --headless --audio-driver Dummy --fixed-fps 60 --path . \
##     res://tools/balance/BalanceBotRuido.tscn -- 1 68 1 seed=1 ruido=2 out=...

const JIT_X := 14.0       # px (±) no eixo X
const JIT_Y := 8.0        # px (±) no eixo Y (profundidade)

var _ruido: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ruido="):
			_ruido = int(a.substr(6))
	super._ready()
	if _ruido > 0:
		# Este nó é a cena principal e morre na 1ª troca de cena: o ruído
		# vive num nó próprio na raiz (como o BalanceWorker).
		var j := Jitter.new()
		j.ruido = _ruido
		get_tree().root.add_child.call_deferred(j)


class Jitter extends Node:
	var ruido: int = 1
	var _last_pl: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _physics_process(_delta: float) -> void:
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl == null or pl.get_instance_id() == _last_pl:
			return
		_last_pl = pl.get_instance_id()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("gnosis-ruido-%d-%d" % [ruido, RunManager.current_screen])
		pl.global_position += Vector2(rng.randf_range(-JIT_X, JIT_X), rng.randf_range(-JIT_Y, JIT_Y))
