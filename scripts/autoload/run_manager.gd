extends Node
## Estrutura do "run" — o ARCO DOS ANÉIS em 68 telas:
##   1        = O Rei (chefe-tutorial; a Voz o apresenta como amigo)
##   2..64    = os 7 Éons (9 telas cada); o Arconte fecha o Éon em 10,19,...,64
##              Dentro do Éon (offset 0..8): chegada · travessia · travessia ·
##              travessia · DESAFIO (Campeão + santuário) · travessia · travessia ·
##              antessala (2 waves pesadas) · ARCONTE.
##   64       = ao cair o 7º Arconte, o Rei rouba os 7 Anéis e a Voz se revela (cutscene)
##   65..67   = o Centro: ecos rápidos dos Arcontes devolvem os cacos de memória
##   68       = a Mente: batalha dupla (Rei + Colosso) — as duas formas caem juntas
## Cada tela é uma TRAVESSIA com 1–3 ZONAS de combate (ver Level): o jogador
## anda, a zona tranca, as waves nascem, limpou → segue. O HP do herói é
## carregado entre telas. Autoload acessível como `RunManager`.
##
## MAPA (Onda 6): cada Éon é um GRAFO por camadas (scripts/levels/map/eon_map.gd).
## A tela (2..64) continua sendo a CAMADA do Éon — todo caminho passa por um nó
## por camada —, mas a camada pode ter 2–3 nós à escolha (combate, perigo,
## escalada, santuário, Arena, segredo). `current_node` diz QUAL nó da camada é
## a tela atual; a escolha acontece na tela de mapa (scenes/ui/WorldMap.tscn),
## aberta pelo advance_and_reload quando há mais de uma saída.

signal screen_changed(screen: int)
## Entrou num nó do mapa (id do EonMap; "" fora dos Éons).
signal node_entered(node_id: String)

const KING_SCREEN := 1
const EON_LEN := 9            # telas por Éon
const FIRST_EON_SCREEN := 2
const LAST_ARCHON_SCREEN := FIRST_EON_SCREEN + 7 * EON_LEN - 1   # 64
const CENTER_FIRST := LAST_ARCHON_SCREEN + 1                      # 65
const CENTER_LAST := CENTER_FIRST + 2                             # 67
const MAX_SCREEN := CENTER_LAST + 1                               # 68

const EON_NAMES := ["Torpor", "Fome", "Corrente", "Silêncio", "Espelho", "Praga", "Coroa"]

var run_active: bool = false
var current_screen: int = 1
var carry_health: int = -1        # HP levado pra próxima tela (-1 = cheio)
var best_screen: int = 1
var pending_advance: bool = false # loja pós-chefe deve avançar ao fechar
var endings_seen: Array = []      # finais já alcançados ("ascensao"/"ruptura"/"semente")
var deaths_this_run: int = 0      # quedas (a Voz te recompõe — checkpoint)
var saved_run: Dictionary = {}    # run salvo em disco (menu "Continuar")

# --- mapa (Onda 6) ---
const WORLD_MAP_SCENE := "res://scenes/ui/WorldMap.tscn"
const MAP_VERSION := 1            # versão do bloco de mapa no save (migração)
var current_node: String = ""     # nó do mapa da tela atual ("" = padrão da camada)
var path: Array[String] = []      # nós visitados no run, em ordem
var choosing: bool = false        # a tela de mapa está esperando a escolha
var last_reward: Dictionary = {}  # recompensa do último nó vencido (o mapa mostra)
var last_node: String = ""        # o nó que acabou de ser vencido
## Rota automática (bot de balance / QAs): -1 = o jogador escolhe na tela de
## mapa · 0 = sempre o nó padrão (trilha do meio — compara com o histórico) ·
## N>0 = escolha sorteada, determinística pela semente N e pelo nó de origem.
var map_route_seed: int = -1


func begin() -> void:
	run_active = true
	current_screen = 1
	carry_health = -1
	pending_advance = false
	deaths_this_run = 0
	saved_run = {}                 # run novo substitui o "Continuar" antigo
	current_node = ""
	path.clear()
	choosing = false
	last_reward = {}
	last_node = ""
	GameManager.current_screen = 1
	Narrative.reset()
	screen_changed.emit(current_screen)


func end_run() -> void:
	run_active = false


# --- checkpoints / continuar -------------------------------------------------

## Telas de CHECKPOINT dentro do Éon (offsets): chegada, o Desafio (santuário)
## e a antessala do Arconte. Backlog #3: morrer no Arconte devolvia 8 telas.
const CHECKPOINT_OFFSETS := [0, 4, 7]

## Onde a morte te devolve: o último checkpoint ALCANÇADO no trecho atual.
## Limiar → 1 · Éon → chegada (offset 0), Desafio/santuário (4) ou antessala (7)
## — o maior que não passa da tela atual (ex.: morrer no Arconte 19 → 18;
## na travessia 14 → 11; no Desafio 15 ou depois dele → 15) · Centro → 65 ·
## Mente → 68. Como o run é linear, "a última tela de checkpoint alcançada" é
## função só da tela atual: o "Continuar" (run_snapshot) usa a mesma conta.
## O custo da morte continua no Level (−20% de faíscas).
func checkpoint_for(screen: int) -> int:
	if screen <= KING_SCREEN:
		return KING_SCREEN
	if screen >= MAX_SCREEN:
		return MAX_SCREEN
	if screen >= CENTER_FIRST:
		return CENTER_FIRST
	var first := FIRST_EON_SCREEN + eon_index(screen) * EON_LEN
	var off := screen - first
	var best := 0
	for o in CHECKPOINT_OFFSETS:
		if o <= off:
			best = maxi(best, o)
	return first + best


## A tela é um checkpoint (a morte adiante volta para ela)?
func is_checkpoint(screen: int) -> bool:
	return checkpoint_for(screen) == screen


## Morte com run ativo: volta pro checkpoint com a progressão intacta.
func respawn_at_checkpoint() -> void:
	current_screen = checkpoint_for(current_screen)
	_settle_on_checkpoint()
	GameManager.current_screen = current_screen
	carry_health = -1              # recomposta inteira
	pending_advance = false
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


## Foto do run pro save (a retomada é sempre do checkpoint, nunca do meio da tela).
func run_snapshot() -> Dictionary:
	if not run_active:
		return saved_run           # preserva o que estava no disco
	return {
		"screen": checkpoint_for(current_screen),
		"deaths": deaths_this_run,
		"difficulty": GameManager.difficulty,
		"orbs": Progression.orbs,
		"weapon_level": Progression.weapon_level,
		"skill_levels": Progression.skill_levels,
		"bonus_hp": Progression.bonus_max_health,
		"bonus_mp": Progression.bonus_max_mana,
		"items": Progression.items,
		"sleepers": Progression.sleepers_freed,
		"unlocked": Progression.unlocked_skills,
		"rings": Progression.rings,
		"rings_stolen": Progression.rings_stolen,
		"restored": Progression.restored_rings,
		"selected_ring": Progression.selected_ring,
		"seen": Narrative.seen.keys(),
		# Mapa (Onda 6): a rota até o checkpoint. Saves antigos não têm estas
		# chaves — o continue_run migra (nó padrão da camada, rota vazia).
		"map_v": MAP_VERSION,
		"node": _node_at_checkpoint(checkpoint_for(current_screen)),
		"path": _path_until(checkpoint_for(current_screen)),
	}


func has_saved_run() -> bool:
	return SaveCoerce.as_int(saved_run.get("screen", 0), 0) >= 1


## Menu "Continuar": restaura a progressão salva e retoma do checkpoint.
## Tudo lido pelos conversores TOLERANTES (REVISAO #5): um campo com tipo
## errado (ex.: `skill_levels: [1,2]`, `rings_stolen: "sim"`, `orbs: [5]`)
## volta ao padrão SÓ ele — o resto do run continua e a cena troca.
func continue_run() -> void:
	var d := saved_run
	GameManager.selected_character = GameContent.characters[0]
	GameManager.difficulty = clampi(SaveCoerce.as_int(d.get("difficulty", 0), 0), 0, 3) as GameManager.Difficulty
	Progression.reset_run()
	Progression.orbs = maxi(0, SaveCoerce.as_int(d.get("orbs", 0), 0))
	Progression.weapon_level = clampi(SaveCoerce.as_int(d.get("weapon_level", 1), 1), 1, Progression.MAX_WEAPON_LEVEL)
	Progression.bonus_max_health = maxi(0, SaveCoerce.as_int(d.get("bonus_hp", 0), 0))
	Progression.bonus_max_mana = maxi(0, SaveCoerce.as_int(d.get("bonus_mp", 0), 0))
	Progression.sleepers_freed = maxi(0, SaveCoerce.as_int(d.get("sleepers", 0), 0))
	Progression.rings_stolen = SaveCoerce.as_bool(d.get("rings_stolen", false), false)
	Progression.selected_ring = clampi(SaveCoerce.as_int(d.get("selected_ring", 0), 0), 0, 6)
	Progression.items.assign(SaveCoerce.as_str_array(d.get("items", [])))
	Progression.unlocked_skills.assign(SaveCoerce.as_str_array(d.get("unlocked", ["m_s1"]), ["m_s1"]))
	Progression.rings.assign(SaveCoerce.as_str_array(d.get("rings", [])))
	Progression.restored_rings.assign(SaveCoerce.as_str_array(d.get("restored", [])))
	Progression.skill_levels.clear()
	var sl := SaveCoerce.as_dict(d.get("skill_levels", {}))
	for k in sl:
		Progression.skill_levels[str(k)] = maxi(0, SaveCoerce.as_int(sl[k], 0))
	Narrative.reset()
	for s in SaveCoerce.as_str_array(d.get("seen", [])):
		Narrative.seen[s] = true
	run_active = true
	deaths_this_run = maxi(0, SaveCoerce.as_int(d.get("deaths", 0), 0))
	current_screen = clampi(SaveCoerce.as_int(d.get("screen", 1), 1), 1, MAX_SCREEN)
	carry_health = -1
	pending_advance = false
	_restore_map(d)
	GameManager.current_screen = current_screen
	Progression.rings_changed.emit()
	Progression.orbs_changed.emit(Progression.orbs)
	Progression.weapon_level_changed.emit(Progression.weapon_level)
	Progression.stats_changed.emit()
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


## Vitória: o run acabou de verdade — o "Continuar" some.
func clear_saved_run() -> void:
	if run_active and is_final(current_screen):
		Progression.record_boss_beaten("demiurgo")
		var ach := get_node_or_null("/root/Achievements")
		if ach != null and ach.has_method("on_campaign_won"):
			ach.call("on_campaign_won", int(GameManager.difficulty), deaths_this_run)
	run_active = false
	saved_run = {}
	SaveManager.save_game()


# --- sorteio determinístico ---------------------------------------------------

## RNG PRÓPRIO de uma tela (BALANCE §3): semeado só pelo número da tela, então
## a mesma tela sorteia a mesma sequência em todo run — independente do `randi()`
## global que o Áudio/VFX também consomem. Cada chamada devolve um gerador
## NOVO no começo da sequência: guarde-o enquanto a tela durar (ex.:
## `final_battle` pega `RunManager.screen_rng(68)` no _ready).
static func screen_rng(screen: int, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gnosis/screen/%d/%d" % [screen, salt])
	return rng


# --- mapa do run ------------------------------------------------------------

func is_king_screen(screen: int) -> bool:
	return screen == KING_SCREEN


## Tela do Arconte de um Éon (10, 19, ..., 64) — o último offset do Éon.
func is_archon_screen(screen: int) -> bool:
	return eon_offset(screen) == EON_LEN - 1


func is_theft_screen(screen: int) -> bool:
	return screen == LAST_ARCHON_SCREEN


func is_center(screen: int) -> bool:
	return screen >= CENTER_FIRST and screen <= CENTER_LAST


func is_final(screen: int) -> bool:
	return screen >= MAX_SCREEN


## Qualquer tela com chefe (Rei, Arcontes, batalha final).
func is_boss_screen(screen: int) -> bool:
	return is_king_screen(screen) or is_archon_screen(screen) or is_final(screen)


## Índice do Éon: 0..6 nos Éons; a tela 1 usa 0 (prólogo); 7 = Centro; 8 = Mente.
func eon_index(screen: int) -> int:
	if screen >= MAX_SCREEN:
		return 8
	if screen >= CENTER_FIRST:
		return 7
	if screen < FIRST_EON_SCREEN:
		return 0
	return clampi((screen - FIRST_EON_SCREEN) / EON_LEN, 0, 6)


## Número do Arconte (1..7) de uma tela de Arconte; 0 se não for.
func archon_number(screen: int) -> int:
	if not is_archon_screen(screen):
		return 0
	return eon_index(screen) + 1


## Posição da tela dentro do Éon (0..EON_LEN-1); -1 fora dos Éons.
func eon_offset(screen: int) -> int:
	if screen < FIRST_EON_SCREEN or screen > LAST_ARCHON_SCREEN:
		return -1
	return (screen - FIRST_EON_SCREEN) % EON_LEN


## Papel da tela no arco: "king" (1) · "arrival" (chegada ao Éon) · "travel"
## (travessia) · "trial" (o DESAFIO do Éon: Campeão + santuário) ·
## "antechamber" (antessala do Arconte) · "archon" · "center" · "final".
func screen_role(screen: int) -> String:
	if screen <= KING_SCREEN:
		return "king"
	if screen >= MAX_SCREEN:
		return "final"
	if is_center(screen):
		return "center"
	match eon_offset(screen):
		0: return "arrival"
		4: return "trial"
		7: return "antechamber"
		8: return "archon"
	return "travel"


## Quantas ZONAS de combate a tela tem (cada zona = um bolsão de waves).
## Travessia alterna 3 e 2 pela paridade da tela (par = 3).
func zone_count(screen: int) -> int:
	# Nós de mapa com tipo próprio têm sempre 2 zonas: as legendas de zona
	# (Z0/Z1 do ROTEIRO) tocam em qualquer rota.
	if node_kind(screen) in ["hazard", "platform", "sanctuary", "challenge", "secret", "hidden"]:
		return 2
	match screen_role(screen):
		"arrival": return 2
		"travel": return 3 if screen % 2 == 0 else 2
	return 1


func eon_name(screen: int) -> String:
	if screen >= MAX_SCREEN:
		return "A Mente"
	if is_center(screen):
		return "O Centro"
	if is_king_screen(screen):
		return "O Limiar"
	return EON_NAMES[eon_index(screen)]


## Primeira tela de um Éon (pra tocar a introdução narrada).
func is_eon_start(screen: int) -> bool:
	return eon_offset(screen) == 0


func boss_id_for(screen: int) -> String:
	if is_king_screen(screen):
		return "rei"
	if is_final(screen):
		return "demiurgo"
	var n := archon_number(screen)
	if n <= 0 or Bestiary.bosses.is_empty():
		return "servo"
	return Bestiary.bosses[clampi(n - 1, 0, Bestiary.bosses.size() - 1)].id


## Plano da tela: lista de ZONAS; cada zona = lista de WAVES; cada wave =
## lista de type_ids. Determinístico: mesma tela = mesmo plano.
##  - arrival/travel: 1–2 waves por zona (1 nos Éons 0–1, 2 a partir do Éon 2;
##    a última zona da tela sempre com 2), 3 inimigos por wave.
##  - trial: 1 zona, 2 waves: [bot, aliado, aliado] e [aliado, bot=CAMPEÃO].
##  - antechamber: 1 zona, 2 waves pesadas (4 inimigos, com o bot do Éon).
##  - king/archon: [[[chefe]]] · center: ecos · final: [] (controlador próprio).
func zone_plan(screen: int) -> Array:
	var role := screen_role(screen)
	if role == "final":
		return []
	if role == "king" or role == "archon":
		return [[[boss_id_for(screen)]]]
	if role == "center":
		# Ecos rápidos dos Arcontes (2 por tela) + larvas de interferência.
		var k := (screen - CENTER_FIRST) * 2
		var a: String = "eco_" + Bestiary.bosses[mini(k, Bestiary.bosses.size() - 1)].id
		var b: String = "eco_" + Bestiary.bosses[mini(k + 1, Bestiary.bosses.size() - 1)].id
		return [[["larva", a, "larva"], ["larva_ardente", b, "larva"]]]
	var eon := eon_index(screen)
	var bot: String = Bestiary.EON_BOTS[clampi(eon, 0, Bestiary.EON_BOTS.size() - 1)]
	var ids: Array = Bestiary.types_for_screen(screen)
	if ids.is_empty():
		ids = ["servo"]
	# Aliados = o pool sem o bot (o bot entra explicitamente onde a regra pede).
	var allies: Array = ids.filter(func(id): return id != bot)
	if allies.is_empty():
		allies = ["servo"]
	if role == "trial":
		var a1: String = allies[screen % allies.size()]
		var a2: String = allies[(screen + 1) % allies.size()]
		var a3: String = allies[(screen + 2) % allies.size()]
		return [[[bot, a1, a2], [a3, bot]]]
	if role == "antechamber":
		var zone: Array = []
		for w in 2:
			var wave: Array = [bot]
			for i in 3:
				wave.append(allies[(w * 3 + i + screen) % allies.size()])
			zone.append(wave)
		return [zone]
	# MAPA (Onda 6): telas de escolha com tipo próprio. "combat" (o nó padrão)
	# segue o plano legado abaixo — a rota do meio é o jogo de antes.
	var kind := node_kind(screen)
	if kind in ["hazard", "platform", "sanctuary", "challenge", "secret", "hidden"]:
		return _kind_plan(kind, screen, eon, bot, ids, allies)
	# arrival / travel — r5 (18/09): o bot media 300–800 de dano por tela com
	# 2 waves × 3 inimigos em cada zona. Agora a densidade sobe com o Éon:
	# Éons 0–1 = waves de 2 · Éons 2+ = waves de 3; zonas de 1 wave até o
	# Éon 2, 2 waves a partir do Éon 3; a última zona ganha a 2ª wave do Éon 1.
	var zones: Array = []
	var n := zone_count(screen)
	var per_wave := 2 if eon <= 1 else 3
	for z in n:
		# r6: 1 wave por zona; a última zona ganha a 2ª a partir do Éon 1 e,
		# nos Éons 5–6, todas as zonas menos a primeira têm 2 (o bot media
		# 400–1000 de dano/tela do Éon 3 em diante com 2 waves em toda zona).
		var waves_here := 1
		if z == n - 1 and eon >= 1:
			waves_here = 2
		if eon >= 5 and z >= 1:
			waves_here = 2
		var zone: Array = []
		for w in waves_here:
			var wave: Array = []
			for i in per_wave:
				wave.append(ids[(z * 7 + w * 3 + i + screen) % ids.size()])
			zone.append(wave)
		zones.append(zone)
	return zones


## Plano das telas de MAPA com tipo próprio (sempre 2 zonas). Determinístico
## pela tela e pelo tipo. O LAYOUT (perigos, plataformas, altura, sala do
## segredo) é do level6 via RunManager.node_kind(); aqui só a densidade:
##  - hazard:    o chão é o inimigo — 1 wave por zona, uma criatura a menos.
##  - platform:  1 wave por zona, densidade normal (espaço p/ voadores).
##  - sanctuary: luta leve (2 por zona) — o prêmio é a cura inteira.
##  - challenge: a ARENA — 2 waves na 1ª zona e 3 na 2ª, com o bot do Éon e
##               uma criatura a mais por wave (o último vira Elite, como sempre).
##  - secret:    guardiões poucos (2 por zona) — o desafio é chegar.
func _kind_plan(kind: String, screen: int, eon: int, bot: String, ids: Array, _allies: Array) -> Array:
	var per_wave := 2 if eon <= 1 else 3
	var waves_by_zone: Array = [1, 1]
	var size := per_wave
	match kind:
		"hazard":
			size = maxi(2, per_wave - 1)
		"sanctuary", "secret", "hidden":
			size = 2
		"challenge":
			waves_by_zone = [2, 3]
			size = per_wave + 1
	var zones: Array = []
	for z in 2:
		var zone: Array = []
		for w in int(waves_by_zone[z]):
			var wave: Array = []
			for i in size:
				wave.append(ids[(z * 5 + w * 3 + i + screen + kind.length()) % ids.size()])
			# A Arena traz o bot do Éon na última wave de cada zona.
			if kind == "challenge" and w == int(waves_by_zone[z]) - 1 and not wave.has(bot):
				wave[0] = bot
			zone.append(wave)
		zones.append(zone)
	return zones


## Guarda o HP com uma cura entre telas (+25% do máximo — r5: as travessias
## são mais longas que as arenas antigas, a recomposição acompanha).
func store_health(hp: int, max_hp: int) -> void:
	carry_health = mini(max_hp, hp + int(max_hp * 0.25))


func advance_and_reload() -> void:
	best_screen = maxi(best_screen, current_screen)
	# Sair de uma tela de chefe = o chefe caiu (o Rei não dá Anel; os Arcontes
	# já marcam no add_ring — aqui é idempotente).
	if run_active and (is_king_screen(current_screen) or is_archon_screen(current_screen)):
		var bid := boss_id_for(current_screen)
		Progression.record_boss_beaten(bid)
		var ach := get_node_or_null("/root/Achievements")
		if ach != null and ach.has_method("on_boss_cleared"):
			ach.call("on_boss_cleared", bid, current_screen)
	# DEMO (#27): passar do Athoth encerra a demo (sem carregar a tela 11).
	if run_active and GameManager.is_demo_end(current_screen):
		clear_saved_run()
		GameManager.finish_demo()
		return
	# Mapa: o nó que acabou de ser vencido paga a recompensa dele.
	var prev := node_id_at(current_screen)
	last_node = prev
	last_reward = _grant_reward(prev) if run_active else {}
	current_screen += 1
	GameManager.current_screen = current_screen
	var opts := options_after(prev, current_screen)
	if opts.size() > 1 and run_active:
		var auto := _auto_choice(prev, opts)
		if auto == "":
			# Há escolha: a tela de mapa decide (ela chama choose_node).
			current_node = ""
			choosing = true
			SaveManager.save_game()
			SceneManager.change_scene(WORLD_MAP_SCENE)
			return
		_enter_node(auto)
	else:
		_enter_node(String(opts[0]) if opts.size() == 1 else "")
		_toast_reward_later()
	SaveManager.save_game()        # o "Continuar" acompanha o checkpoint
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


# --- mapa: nós, escolha, recompensas (Onda 6) ---------------------------------

## A tela de mapa escolheu: entra no nó e carrega a tela. Ignora id inválido
## (devolve false) — só vale um nó entre as saídas atuais.
func choose_node(id: String) -> bool:
	var opts := options_after(last_node, current_screen)
	if not opts.has(id) or not node_available(id):
		return false
	choosing = false
	_enter_node(id)
	SaveManager.save_game()
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")
	return true


## Saídas possíveis ao chegar na tela `screen` vindo do nó `from_id` (ids do
## EonMap; inclui nós TRANCADOS — a tela de mapa os mostra selados). Fora dos
## Éons: [] (tela linear).
func options_after(from_id: String, screen: int) -> Array:
	if screen < FIRST_EON_SCREEN or screen > LAST_ARCHON_SCREEN:
		return []
	var eon := eon_index(screen)
	var layer := eon_offset(screen)
	var from := EonMap.find(from_id)
	if not from.is_empty() and int(from.eon) == eon and int(from.layer) == layer - 1:
		return (from.next as Array).duplicate()
	return EonMap.layer_ids(eon, layer).duplicate()


## Saídas que o jogador PODE tomar agora (sem as trancadas).
func available_options(from_id: String, screen: int) -> Array:
	return options_after(from_id, screen).filter(func(id): return node_available(String(id)))


## O nó pode ser escolhido? (segredo = exige o pulo duplo, dado por Soter).
func node_available(id: String) -> bool:
	var n := EonMap.find(id)
	if n.is_empty():
		return false
	match String(n.requires):
		"double_jump":
			return has_double_jump()
	return true


## Contrato com a Progressão/Combate (Onda 6): Progression.has_double_jump().
## Sem o método (branch sem a mecânica ainda), ninguém tem o pulo duplo.
func has_double_jump() -> bool:
	if Progression.has_method("has_double_jump"):
		return bool(Progression.call("has_double_jump"))
	return false


## Id do nó da tela `screen` (a escolha registrada se for a tela atual; senão o
## nó padrão da camada). "" fora dos Éons.
func node_id_at(screen: int) -> String:
	if screen < FIRST_EON_SCREEN or screen > LAST_ARCHON_SCREEN:
		return ""
	if screen == current_screen and current_node != "":
		var n := EonMap.find(current_node)
		if not n.is_empty() and int(n.screen) == screen:
			return current_node
	return EonMap.default_id(eon_index(screen), eon_offset(screen))


## Dados do nó da tela (ver EonMap._make); {} fora dos Éons.
func node_at(screen: int) -> Dictionary:
	return EonMap.find(node_id_at(screen))


## TIPO da tela para o layout (level6) e a narrativa: "king" · "arrival" ·
## "combat" · "hazard" · "platform" · "sanctuary" · "challenge" · "secret" · "hidden" ·
## "trial" · "antechamber" · "archon" · "center" · "final". Sem argumento = tela atual.
func node_kind(screen: int = -1) -> String:
	if screen < 0:
		screen = current_screen
	var n := node_at(screen)
	if not n.is_empty():
		return String(n.kind)
	return screen_role(screen)


## Nome legível do tipo da tela ("Passagem perigosa", "Arena"...).
func node_title(screen: int = -1) -> String:
	return EonMap.kind_name(node_kind(screen))


## A tela é um nó OPCIONAL (Arena ou segredo)? Útil pra HUD/narrativa.
func is_optional_node(screen: int = -1) -> bool:
	return node_kind(screen) in ["challenge", "secret", "hidden"]


## Slot de compatibilidade dos beats ("e1.L6" = tela 17). Fora dos Éons: "s<tela>".
func beat_slot(screen: int) -> String:
	if screen < FIRST_EON_SCREEN or screen > LAST_ARCHON_SCREEN:
		return "s%d" % screen
	return EonMap.slot(eon_index(screen), eon_offset(screen))


## Tela legada de um slot de beat (inverso de beat_slot); -1 se inválido.
func screen_for_slot(slot_id: String) -> int:
	if slot_id.begins_with("s"):
		return slot_id.substr(1).to_int()
	var m := slot_id.split(".L")
	if m.size() != 2 or not m[0].begins_with("e"):
		return -1
	return EonMap.screen_of(m[0].substr(1).to_int(), m[1].to_int())


## RNG próprio do NÓ (duas trilhas da mesma camada sorteiam diferente).
func node_rng(salt: int = 0, screen: int = -1) -> RandomNumberGenerator:
	if screen < 0:
		screen = current_screen
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gnosis/node/%s/%d/%d" % [node_id_at(screen), screen, salt])
	return rng


func _enter_node(id: String) -> void:
	current_node = id
	choosing = false
	if id != "":
		path.append(id)
	node_entered.emit(id)


## Paga a recompensa do nó vencido; devolve o que foi dado (vazio se nada).
func _grant_reward(id: String) -> Dictionary:
	var n := EonMap.find(id)
	if n.is_empty() or CodexSession.active:
		return {}
	var rw: Dictionary = n.reward
	if int(rw.get("orbs", 0)) > 0:
		Progression.add_orbs(int(rw.orbs))
	if int(rw.get("hp", 0)) > 0:
		Progression.buy_max_health(int(rw.hp), 0)
	if int(rw.get("mp", 0)) > 0:
		Progression.buy_max_mana(int(rw.mp), 0)
	if bool(rw.get("heal", false)):
		carry_health = -1          # a próxima tela começa com a vida cheia
	return rw.duplicate()


## Sem tela de mapa no meio (saída única): a recompensa vira um aviso no HUD
## da próxima tela (autoload sobrevive à troca de cena).
func _toast_reward_later() -> void:
	if last_reward.is_empty() or not is_inside_tree():
		return
	var kind := String(EonMap.find(last_node).get("kind", ""))
	var text := I18n.t(EonMap.kind_name(kind)) + " — " + EonMap.reward_text(last_reward)
	get_tree().create_timer(1.8, false).timeout.connect(func():
		get_tree().call_group("hud", "toast", text))


## Rota automática (map_route_seed >= 0): escolhe sem a tela de mapa.
func _auto_choice(from_id: String, opts: Array) -> String:
	if map_route_seed < 0:
		return ""
	var free: Array = opts.filter(func(id): return node_available(String(id)))
	if free.is_empty():
		return String(opts[0])
	if map_route_seed == 0:
		for id in free:
			if int(EonMap.find(String(id)).row) == 1:
				return String(id)
		return String(free[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gnosis/rota/%d/%s/%d" % [map_route_seed, from_id, current_screen])
	return String(free[rng.randi() % free.size()])


## Morte/continuar: o checkpoint é sempre um nó ÚNICO da camada (chegada,
## Desafio, antessala) — a rota é cortada até ele.
func _settle_on_checkpoint() -> void:
	choosing = false
	var id := _node_at_checkpoint(current_screen)
	path.assign(_path_until(current_screen))
	if id != "" and (path.is_empty() or path[path.size() - 1] != id):
		path.append(id)
	current_node = id


func _node_at_checkpoint(screen: int) -> String:
	if screen < FIRST_EON_SCREEN or screen > LAST_ARCHON_SCREEN:
		return ""
	return EonMap.default_id(eon_index(screen), eon_offset(screen))


## A rota até a tela `screen` (inclusive), sem os nós depois dela.
func _path_until(screen: int) -> Array[String]:
	var out: Array[String] = []
	for id in path:
		var n := EonMap.find(id)
		if not n.is_empty() and int(n.screen) <= screen:
			out.append(id)
	return out


## Continuar: lê o bloco de mapa do save com tolerância. Save antigo (sem
## "map_v"/"path") ou rota inválida → rota vazia e o nó padrão do checkpoint.
func _restore_map(d: Dictionary) -> void:
	path.clear()
	var last_screen := 0
	for id in SaveCoerce.as_str_array(d.get("path", [])):
		var n := EonMap.find(id)
		# Só ids válidos, em ordem crescente de tela e até o checkpoint.
		if n.is_empty() or int(n.screen) <= last_screen or int(n.screen) > current_screen:
			continue
		path.append(id)
		last_screen = int(n.screen)
	last_reward = {}
	last_node = ""
	_settle_on_checkpoint()


## Rota do Éon (para a tela de mapa): ids visitados naquele Éon, em ordem.
func path_in_eon(eon: int) -> Array:
	return path.filter(func(id): return int(EonMap.find(String(id)).get("eon", -1)) == eon)
