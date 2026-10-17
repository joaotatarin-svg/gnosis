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
## FOTO DO RUN (para medir UMA tela muitas vezes, com a progressão de verdade):
##   snap=<base>@<tela>[,<tela>...] = numa rodada longa, grava a progressão ao
##          ENTRAR em cada tela, em <base>_<tela>.json.
##   carrega=<arq.json>     = começa já com essa progressão (use ini=fim=tela).
##   Ex.: rodada 1–68 com snap=C:/x/foto@55,68; depois 68–68 carrega=C:/x/foto_68.json ruido=1..N.

const JIT_X := 14.0       # px (±) no eixo X
const JIT_Y := 8.0        # px (±) no eixo Y (profundidade)

var _ruido: int = 0
var _snap_path: String = ""
var _snap_screens: Array[int] = []
var _load_path: String = ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ruido="):
			_ruido = int(a.substr(6))
		elif a.begins_with("snap="):
			var parts := a.substr(5).split("@")
			_snap_path = parts[0]
			var lst: String = parts[1] if parts.size() > 1 else str(RunManager.MAX_SCREEN)
			for t in lst.split(","):
				_snap_screens.append(int(t))
		elif a.begins_with("carrega="):
			_load_path = a.substr(8)
	super._ready()
	# Este nó é a cena principal e morre na 1ª troca de cena: o ruído e a foto
	# vivem num nó próprio na raiz (como o BalanceWorker, que entra ANTES dele).
	var j := Jitter.new()
	j.ruido = _ruido
	j.snap_path = _snap_path
	j.snap_screens = _snap_screens
	j.load_path = _load_path
	get_tree().root.add_child.call_deferred(j)


class Jitter extends Node:
	var ruido: int = 0
	var snap_path: String = ""
	var snap_screens: Array[int] = []
	var load_path: String = ""
	var _last_pl: int = 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		# O BalanceWorker já zerou o run (reset_run) no _ready dele; a troca de
		# cena ainda está na fila: aqui dá para pôr a progressão gravada.
		if load_path != "":
			_load(load_path)
		if snap_path != "":
			RunManager.screen_changed.connect(_on_screen)

	func _on_screen(screen: int) -> void:
		if not snap_screens.has(screen):
			return
		var d := {
			"screen": screen, "orbs": Progression.orbs, "weapon_level": Progression.weapon_level,
			"skill_levels": Progression.skill_levels, "bonus_hp": Progression.bonus_max_health,
			"bonus_mp": Progression.bonus_max_mana, "items": Progression.items,
			"sleepers": Progression.sleepers_freed, "unlocked": Progression.unlocked_skills,
			"rings": Progression.rings, "rings_stolen": Progression.rings_stolen,
			"restored": Progression.restored_rings, "selected_ring": Progression.selected_ring,
			"seen": Narrative.seen.keys(),
		}
		var out := "%s_%d.json" % [snap_path, screen]
		var f := FileAccess.open(out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(d))
			print("RUIDO: foto da tela %d em %s" % [screen, out])

	func _load(path: String) -> void:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("RUIDO: não abriu %s" % path)
			return
		var d = JSON.parse_string(f.get_as_text())
		if not (d is Dictionary):
			push_error("RUIDO: foto inválida %s" % path)
			return
		Progression.orbs = int(d.get("orbs", 0))
		Progression.weapon_level = int(d.get("weapon_level", 1))
		Progression.bonus_max_health = int(d.get("bonus_hp", 0))
		Progression.bonus_max_mana = int(d.get("bonus_mp", 0))
		Progression.sleepers_freed = int(d.get("sleepers", 0))
		Progression.rings_stolen = bool(d.get("rings_stolen", false))
		Progression.selected_ring = int(d.get("selected_ring", 0))
		Progression.items.assign(d.get("items", []))
		Progression.unlocked_skills.assign(d.get("unlocked", ["m_s1"]))
		Progression.rings.assign(d.get("rings", []))
		Progression.restored_rings.assign(d.get("restored", []))
		Progression.skill_levels.clear()
		var sl: Dictionary = d.get("skill_levels", {})
		for k in sl:
			Progression.skill_levels[str(k)] = int(sl[k])
		for s in d.get("seen", []):
			Narrative.seen[str(s)] = true
		Progression.orbs_changed.emit(Progression.orbs)
		Progression.weapon_level_changed.emit(Progression.weapon_level)
		Progression.rings_changed.emit()
		Progression.stats_changed.emit()
		print("RUIDO: progressão carregada de %s (arma %d)" % [path, Progression.weapon_level])

	func _physics_process(_delta: float) -> void:
		if ruido <= 0:
			return
		var pl := get_tree().get_first_node_in_group("player") as Node2D
		if pl == null or pl.get_instance_id() == _last_pl:
			return
		_last_pl = pl.get_instance_id()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("gnosis-ruido-%d-%d" % [ruido, RunManager.current_screen])
		pl.global_position += Vector2(rng.randf_range(-JIT_X, JIT_X), rng.randf_range(-JIT_Y, JIT_Y))
