extends Node
## CONQUISTAS (backlog #49) — autoload leve `Achievements`. Grava LOCAL
## (user://achievements.json; demo: user://demo/achievements.json) e emite
## `unlocked(id)` (a UI pode mostrar um toast). A lista está em
## scripts/data/achievement_data.gd.
##
## Como libera (tudo observado daqui, sem mexer em arquivo de outro agente):
##  - chefes: `Progression.boss_beaten` (1ª vitória na campanha) e
##    `on_boss_cleared` (RunManager, a cada saída de tela de chefe);
##  - "Intocada": vigia a vida do Player de cada tela (node_added) — qualquer
##    queda de vida na tela do Arconte invalida;
##  - arma no máximo / cacos do Centro: sinais da Progression;
##  - Crônicas, finais, Adormecidos, Bestiário: `check_progress()` (o
##    SaveManager e o Gnosis chamam ao gravar);
##  - fim da campanha (dificuldade): `on_campaign_won` (RunManager).
## Provação (CodexSession) e cenas de teste fora de run NÃO liberam nada.
##
## STEAM (fica para depois — o que falta):
##  1. Plugin GodotSteam (GDExtension; é lib externa → decisão do João) e o
##     steam_appid.txt na pasta do executável em dev.
##  2. Cadastrar no Steamworks cada conquista com o API name
##     `AchievementData.steam_api_name(id)` ("ACH_REI"...), título/descrição
##     (pt + en), ícones 64×64 (liberada e cinza) e "hidden" conforme a lista.
##  3. Aqui, em `_on_unlocked`: `Steam.setAchievement(api)` +
##     `Steam.storeStats()`; no boot, sincronizar as já liberadas offline
##     (`_sync_platform()`), pois o jogo pode ter rodado sem a Steam.
##  4. Steam Cloud: só configuração no Steamworks (Auto-Cloud) com as raízes
##     `%APPDATA%/GNOSIS-Codex/` (Windows) — save.json, chronicles.json,
##     achievements.json (+ .bak); a demo usa a subpasta demo/.
##  5. Rich presence ("Torpor · Travessia II") = GameManager.screen_title().

signal unlocked(id: String)

## `var` só para as QAs gravarem em user://qa/ (REVISAO #9); o jogo não muda.
var SAVE_PATH: String = "user://achievements.json"

var _unlocked: Dictionary = {}          # id → true
var _hurt_on_screen: bool = false        # a Sophia perdeu vida na tela atual?
var _player_ref: WeakRef = null
var _last_hp: int = -1


func _ready() -> void:
	if GameManager.demo and SAVE_PATH == "user://achievements.json":
		SAVE_PATH = GameManager.DEMO_DIR + "achievements.json"
	load_state()
	Progression.boss_beaten.connect(_on_boss_beaten)
	Progression.weapon_level_changed.connect(_on_weapon_level)
	Progression.rings_changed.connect(_on_rings_changed)
	RunManager.screen_changed.connect(func(_s: int): _hurt_on_screen = false)
	get_tree().node_added.connect(_on_node_added)


# --- API pública -----------------------------------------------------------------

func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


func total() -> int:
	return AchievementData.LIST.size()


## Lista com o estado: [{id, title, desc, hidden, unlocked}], na ordem da lista.
func entries() -> Array:
	var out: Array = []
	for a in AchievementData.LIST:
		var e: Dictionary = (a as Dictionary).duplicate()
		e["unlocked"] = _unlocked.has(String(a.id))
		out.append(e)
	return out


## Libera (e grava). Devolve true se era inédita. Id fora da lista é ignorado.
func unlock(id: String) -> bool:
	if _unlocked.has(id) or AchievementData.find(id).is_empty():
		return false
	_unlocked[id] = true
	_save()
	unlocked.emit(id)
	return true


## Confere as conquistas de ESTADO (Crônicas, finais, Adormecidos, Bestiário,
## cacos). Barato; pode ser chamado a qualquer momento.
func check_progress() -> void:
	var g := get_node_or_null("/root/Gnosis")
	if g != null:
		var n: int = int(g.call("chronicles_count"))
		if n >= 1:
			unlock("primeira_estela")
		if n >= int(g.call("chronicles_total")):
			unlock("cronicas")
	var seen_all := 0
	for e in AchievementData.ENDINGS:
		if RunManager.endings_seen.has(e):
			unlock(e)
			seen_all += 1
	if seen_all >= AchievementData.ENDINGS.size():
		unlock("tres_portas")
	if _campaign() and Progression.sleepers_freed >= AchievementData.SLEEPERS_GOAL:
		unlock("adormecidos")
	var need := campaign_creature_ids()
	if not need.is_empty():
		var all_seen := true
		for id in need:
			if not Bestiary.seen(id):
				all_seen = false
				break
		if all_seen:
			unlock("bestiario")


## Criaturas COMUNS que a campanha põe em campo (o pool de waves até o tier 4
## + os bots dos Éons). É a meta da conquista "Todos os nomes".
func campaign_creature_ids() -> Array[String]:
	var out: Array[String] = []
	for t in Bestiary.wave_types:
		var id := String(t.id)
		if int(t.tier) <= 4 or Bestiary.EON_BOTS.has(id):
			if not out.has(id):
				out.append(id)
	return out


## RunManager: saiu de uma tela de chefe (o chefe caiu). Vale a cada vitória
## (a "Intocada" pode vir num run posterior).
func on_boss_cleared(boss_id: String, screen: int) -> void:
	if not _campaign():
		return
	if RunManager.is_archon_screen(screen) and not _hurt_on_screen:
		unlock("intocada")
	if boss_id == "arconte_sono" and RunManager.deaths_this_run == 0:
		unlock("passo_firme")


## RunManager.clear_saved_run na vitória final.
func on_campaign_won(difficulty: int, _deaths: int) -> void:
	if CodexSession.active:
		return
	if difficulty >= int(GameManager.Difficulty.HARD):
		unlock("caminho_estreito")
	check_progress()


# --- ganchos ---------------------------------------------------------------------

func _campaign() -> bool:
	return RunManager.run_active and not CodexSession.active


func _on_boss_beaten(boss_id: String) -> void:
	var ach: String = String(AchievementData.BOSS_TO_ACH.get(boss_id, ""))
	if ach != "":
		unlock(ach)


func _on_weapon_level(level: int) -> void:
	if _campaign() and level >= Progression.MAX_WEAPON_LEVEL:
		unlock("arma_maxima")


func _on_rings_changed() -> void:
	if _campaign() and Progression.restored_rings.size() >= 7:
		unlock("memoria")


## Vigia a vida da Sophia de cada tela (o Player nasce de novo a cada tela).
func _on_node_added(node: Node) -> void:
	if not (node is Player):
		return
	node.ready.connect(_watch_player.bind(node), CONNECT_ONE_SHOT)


func _watch_player(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var hc = node.get("health")
	if hc == null or not (hc is HealthComponent):
		return
	_player_ref = weakref(node)
	_hurt_on_screen = false           # Sophia nova = tentativa nova da tela
	_last_hp = (hc as HealthComponent).current_health
	(hc as HealthComponent).health_changed.connect(_on_player_health.bind(node))


func _on_player_health(current: int, _maximum: int, node: Node) -> void:
	if _player_ref == null or _player_ref.get_ref() != node:
		return                        # Player de uma tela velha
	if current < _last_hp:
		_hurt_on_screen = true
	_last_hp = current


# --- disco -----------------------------------------------------------------------

func load_state() -> void:
	_unlocked.clear()
	var got: Dictionary = SaveManager.read_json_safe(SAVE_PATH)
	if typeof(got.data) != TYPE_DICTIONARY:
		return
	for id in SaveCoerce.as_str_array((got.data as Dictionary).get("unlocked", [])):
		if not AchievementData.find(id).is_empty():
			_unlocked[id] = true


func _save() -> void:
	if not SaveManager.persist_enabled:
		return
	var ids: Array[String] = []
	for a in AchievementData.LIST:
		if _unlocked.has(String(a.id)):
			ids.append(String(a.id))
	SaveManager.write_json_atomic(SAVE_PATH, {"version": 1, "unlocked": ids})


## Só para QA: zera em memória (não grava).
func reset_for_qa() -> void:
	_unlocked.clear()
	_hurt_on_screen = false
