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

signal screen_changed(screen: int)

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


func begin() -> void:
	run_active = true
	current_screen = 1
	carry_health = -1
	pending_advance = false
	deaths_this_run = 0
	saved_run = {}                 # run novo substitui o "Continuar" antigo
	GameManager.current_screen = 1
	Narrative.reset()
	screen_changed.emit(current_screen)


func end_run() -> void:
	run_active = false


# --- checkpoints / continuar -------------------------------------------------

## Onde a morte te devolve: início do trecho atual. Limiar → 1 · Éon → primeira
## tela do Éon (2, 11, ..., 56) · Centro → 65 · Mente → 68.
func checkpoint_for(screen: int) -> int:
	if screen <= KING_SCREEN:
		return KING_SCREEN
	if screen >= MAX_SCREEN:
		return MAX_SCREEN
	if screen >= CENTER_FIRST:
		return CENTER_FIRST
	return FIRST_EON_SCREEN + eon_index(screen) * EON_LEN


## Morte com run ativo: volta pro checkpoint com a progressão intacta.
func respawn_at_checkpoint() -> void:
	current_screen = checkpoint_for(current_screen)
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
	GameManager.current_screen = current_screen
	Progression.rings_changed.emit()
	Progression.orbs_changed.emit(Progression.orbs)
	Progression.weapon_level_changed.emit(Progression.weapon_level)
	Progression.stats_changed.emit()
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")


## Vitória: o run acabou de verdade — o "Continuar" some.
func clear_saved_run() -> void:
	run_active = false
	saved_run = {}
	SaveManager.save_game()


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


## Guarda o HP com uma cura entre telas (+25% do máximo — r5: as travessias
## são mais longas que as arenas antigas, a recomposição acompanha).
func store_health(hp: int, max_hp: int) -> void:
	carry_health = mini(max_hp, hp + int(max_hp * 0.25))


func advance_and_reload() -> void:
	best_screen = maxi(best_screen, current_screen)
	current_screen += 1
	GameManager.current_screen = current_screen
	SaveManager.save_game()        # o "Continuar" acompanha o checkpoint
	screen_changed.emit(current_screen)
	SceneManager.change_scene("res://scenes/levels/Level01.tscn")
