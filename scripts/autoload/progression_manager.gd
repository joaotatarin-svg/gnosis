extends Node
## O CORAÇÃO do loop estilo God of War: orbs (moeda), upgrade de arma
## (desbloqueia combos), níveis de magia, e bônus de HP/MP máximo.
## Autoload acessível como `Progression`.

signal orbs_changed(total: int)
signal weapon_level_changed(level: int)
signal skill_upgraded(skill_id: String, level: int)
signal stats_changed()

const MAX_WEAPON_LEVEL := 5

# --- ECONOMIA (Onda 6, docs/onda2/PROGRESSAO6.md) ---------------------------
# Queixa do playtest: "antes do 2º chefe já tinha upgrades no nível máximo". O
# run dava ~12,8 mil faíscas e a loja inteira custava ~5 mil, aberta a qualquer
# hora pela pausa. Agora: (1) custos crescentes; (2) cada TRILHA tem o nível
# máximo SELADO pelo progresso — o "grau" = Arcontes vencidos NESTE run (0..7);
# (3) a soma de tudo passa do que o run dá: não dá para comprar tudo.
## Grau máximo (os 7 Arcontes). Fora do run (Provação, testes) nada é selado.
const MAX_TIER := 7
## Custo para CHEGAR ao nível i da arma (índices 0 e 1 não se compram).
## Onda 7 (QA7 #13): a arma chegava ao Nv.5 na tela 46 e o resto do run
## não tinha meta — agora a subida se espalha até a reta final.
const WEAPON_COSTS := [0, 0, 200, 500, 1100, 1800]
## Arcontes vencidos exigidos para o nível i da arma: Nv.2 no Torpor, Nv.3
## após Athoth (aéreos), Nv.4 após Yabel (tela 37), Nv.5 após Belias (tela 55).
const WEAPON_TIER := [0, 0, 0, 1, 4, 6]
## Vida máx.: +20 por compra, preço 90 × (n+1), no máximo 10 compras e no
## máximo 3 + grau (a 10ª só depois do 7º Arconte).
const HP_STEP := 20
const HP_BASE_COST := 90
const HP_MAX_BUYS := 10
const HP_FREE_BUYS := 3
## Éter máx.: +15 por compra, preço 80 × (n+1), no máximo 6 e 1 + grau.
const MP_STEP := 15
const MP_BASE_COST := 80
const MP_MAX_BUYS := 6
const MP_FREE_BUYS := 1
## Progressão 7 (curva, iteração 2): a 6ª compra de Éter só depois de Belias
## (grau 6). Medido no ProgBot: quem compra sempre o mais barato enchia o Éter
## na tela 48 — a trilha mais cedo no topo; agora nenhuma trilha fecha antes da
## Praga (tela 55), igual à 10ª vida, que espera o 7º Arconte.
const MP_LAST_TIER := 6
## Magias: Nv.2 = 150 + 40·k, Nv.3 = 400 + 80·k (k = nº do Anel, 0 = Esfera
## Solar). O Nv.3 pede 2 Arcontes depois do Anel (a Esfera, 2 Arcontes).
const SKILL_COST_L2 := 150
const SKILL_COST_L2_RING := 40
const SKILL_COST_L3 := 400
const SKILL_COST_L3_RING := 80
const SKILL_L3_TIER_GAP := 2
## Restauração (cura cheia): 50 + 15 por grau.
const HEAL_BASE_COST := 50
const HEAL_TIER_COST := 15
## Dom de vida do Soter (npc_encounter.gd) — entra no bônus mas não é compra.
const SOTER_HP := 25
## Relíquias (game_content.gd): a Brasa cura e a Lâmpada devolve Éter a cada
## faísca que chega (spark_orb.gd); a Pérola rende +25% de faíscas.
const RELIC_HEAL_PER_SPARK := 2
const RELIC_ETHER_PER_SPARK := 3
const RELIC_SPARK_BONUS := 0.25
## Coro das Faíscas (Onda 7): quando a ÚLTIMA faísca de um inimigo te alcança,
## um anel de luz fere quem está perto (dano fixo, sem sorteio).
const RELIC_CHOIR_DAMAGE := 14
const RELIC_CHOIR_RADIUS := 80.0
## Segundo engaste (Onda 7): DUAS relíquias em uso. Preço fixo, selado até
## Astaphaios — o destino das faíscas do fim do run (QA7 #13), sem sorteio.
const RELIC_SLOT_COST := 1500
const RELIC_SLOT_TIER := 5

## Pulo duplo concedido (o Soter dá numa cena; o Combate lê a flag).
signal double_jump_granted()
## Relíquia comprada ou trocada.
signal relics_changed()

## Estado extra do run guardado DENTRO de `items` como "#chave=valor" — o
## `items` já vai no save do run (run_manager.run_snapshot/continue_run) e o
## conversor tolerante devolve [] se vier quebrado. Save antigo = sem as
## entradas = padrão (sem pulo duplo, compras deduzidas do bônus).
## `item_features()` filtra essas entradas (a arte só vê roupa).
const FLAG_PREFIX := "#"

var orbs: int = 0
var weapon_level: int = 1
var skill_levels: Dictionary = {}      # skill_id -> int
var bonus_max_health: int = 0
var bonus_max_mana: int = 0
var items: Array[String] = []          # peças de gear adquiridas (aparência)
var sleepers_freed: int = 0            # Adormecidos despertados (final "Semente")
var unlocked_skills: Array[String] = [] # magias adquiridas ao longo do jogo
# --- Os 7 Anéis ---
signal rings_changed()
var rings: Array[String] = []          # ids dos Arcontes vencidos (Anéis reunidos)
var rings_stolen: bool = false         # o Rei roubou os Anéis (tela 50)
var restored_rings: Array[String] = [] # cacos de memória devolvidos no Centro
var selected_ring: int = 0             # índice (0..6) do Anel equipado

# --- Desbloqueios (backlog #26) — META-progresso: NÃO zera no reset_run ---
## Um chefe caiu na CAMPANHA pela 1ª vez (Provação não conta).
signal boss_beaten(boss_id: String)
## Ids dos chefes já vencidos na campanha ("rei", ids dos Arcontes,
## "demiurgo"). Gravado no save; a Provação só lista os vencidos.
var bosses_beaten: Array[String] = []


## Marca um chefe como vencido na campanha. Ignora a Provação e cenas de teste
## fora de run. Devolve true se era inédito.
func record_boss_beaten(boss_id: String) -> bool:
	if boss_id == "" or CodexSession.active or not RunManager.run_active:
		return false
	if bosses_beaten.has(boss_id):
		return false
	bosses_beaten.append(boss_id)
	boss_beaten.emit(boss_id)
	return true


func is_boss_beaten(boss_id: String) -> bool:
	return bosses_beaten.has(boss_id)


func unlock_skill(id: String) -> void:
	if not unlocked_skills.has(id):
		unlocked_skills.append(id)


func is_skill_unlocked(id: String) -> bool:
	return unlocked_skills.has(id)


## Ganha o Anel de um Arconte (e a magia dele).
func add_ring(boss_id: String, skill_id: String) -> void:
	if not rings.has(boss_id):
		rings.append(boss_id)
	unlock_skill(skill_id)
	record_boss_beaten(boss_id)      # o Anel só vem de um Arconte vencido
	rings_changed.emit()


## O roubo: todos os Anéis vão pro Rei. As magias de Anel somem.
func steal_rings() -> void:
	rings_stolen = true
	restored_rings.clear()
	rings_changed.emit()


## Um caco de memória devolve o PODER de um Anel (não o Anel).
func restore_ring(boss_id: String) -> void:
	if not restored_rings.has(boss_id):
		restored_rings.append(boss_id)
	rings_changed.emit()


## O Anel de `boss_id` está utilizável agora?
func ring_usable(boss_id: String) -> bool:
	if not rings.has(boss_id):
		return false
	if rings_stolen:
		return restored_rings.has(boss_id)
	return true


func next_stolen_ring() -> String:
	for r in rings:
		if not restored_rings.has(r):
			return r
	return ""


## Features de gear que o herói veste (usado pela arte procedural).
func item_features() -> Array:
	return items.filter(func(it: String) -> bool: return not it.begins_with(FLAG_PREFIX))


# --- Estado extra do run (dentro de `items`) ----------------------------

func _flag_get(key: String, fallback: String = "") -> String:
	var head := FLAG_PREFIX + key + "="
	for it in items:
		if it.begins_with(head):
			return it.substr(head.length())
	return fallback


func _flag_has(key: String) -> bool:
	var head := FLAG_PREFIX + key + "="
	for it in items:
		if it.begins_with(head):
			return true
	return false


func _flag_set(key: String, value: String) -> void:
	var head := FLAG_PREFIX + key + "="
	for i in items.size():
		if items[i].begins_with(head):
			items[i] = head + value
			return
	items.append(head + value)


# --- Recompensa única por run (Guardião §3) ------------------------------

## Paga cada achado UMA vez por run: baú, Selos, Adormecido e recompensa de nó
## do mapa. Morrer e refazer o trecho não paga de novo (sem lucro por morrer).
## Devolve true na 1ª vez (quem chama paga) e false depois. Fica no save do run.
## Chaves usadas: "bau:<tela>", "selo:<tela>", "adormecido:<tela>",
## "no:<éon>.<camada>". Fora do run (Provação/testes) sempre paga.
func claim_once(key: String) -> bool:
	if not RunManager.run_active or CodexSession.active:
		return true
	var paid := _flag_get("pagos", "").split(",", false)
	if paid.has(key):
		return false
	paid.append(key)
	_flag_set("pagos", ",".join(paid))
	return true


## Já foi pago neste run? (consulta, não marca)
func was_claimed(key: String) -> bool:
	return _flag_get("pagos", "").split(",", false).has(key)


# --- Pulo duplo (dom do Soter) -------------------------------------------

## A Sophia já pode pular de novo no ar? Por run (o Soter concede numa cena);
## save antigo/sem a entrada = não.
func has_double_jump() -> bool:
	return _flag_get("pulo_duplo") == "1"


## O Soter concede o pulo duplo (idempotente). Vai no save do run.
func grant_double_jump() -> void:
	if has_double_jump():
		return
	_flag_set("pulo_duplo", "1")
	double_jump_granted.emit()
	stats_changed.emit()


# --- Grau de progresso (trava dos níveis máximos) -------------------------

## Arcontes vencidos NESTE run (0..7). O roubo não tira o grau (os Anéis
## continuam contados em `rings`). Fora do run (Provação/testes) = 7.
func progress_tier() -> int:
	if not RunManager.run_active or CodexSession.active:
		return MAX_TIER
	return clampi(rings.size(), 0, MAX_TIER)


## Nome curto do Arconte que abre o grau `tier` (1..7): "Athoth", "Harmas"...
## (nome próprio: igual em todo idioma).
func tier_gate_name(tier: int) -> String:
	if tier <= 0 or Bestiary.bosses.is_empty():
		return ""
	var b: Dictionary = Bestiary.bosses[clampi(tier - 1, 0, Bestiary.bosses.size() - 1)]
	return str(b.get("name", "")).get_slice(",", 0).strip_edges()


## Zera a progressão para uma nova run (chamado ao entrar no menu / começar).
func reset_run() -> void:
	orbs = 0
	weapon_level = 1
	skill_levels.clear()
	bonus_max_health = 0
	bonus_max_mana = 0
	items.clear()
	# Contadores da loja explícitos desde o início do run: o bônus de vida/Éter
	# também recebe presentes (Soter, recompensas do mapa), então só save
	# ANTIGO (sem as entradas) deduz as compras do bônus.
	_flag_set("vida", "0")
	_flag_set("eter", "0")
	sleepers_freed = 0
	unlocked_skills.clear()
	unlocked_skills.append("m_s1")   # a Esfera Solar é inata; os Anéis vêm dos Arcontes
	rings.clear()
	rings_stolen = false
	restored_rings.clear()
	selected_ring = 0
	rings_changed.emit()
	orbs_changed.emit(orbs)
	weapon_level_changed.emit(weapon_level)
	stats_changed.emit()


# --- Orbs ---------------------------------------------------------------

func add_orbs(amount: int) -> void:
	# Pérola do Hino: +25% de toda faísca GANHA (perdas e gastos não mudam).
	if amount > 0 and relic_active("perola"):
		amount = int(round(float(amount) * (1.0 + RELIC_SPARK_BONUS)))
	orbs += amount
	orbs_changed.emit(orbs)


func spend_orbs(amount: int) -> bool:
	if orbs < amount:
		return false
	orbs -= amount
	orbs_changed.emit(orbs)
	return true


# --- Arma (desbloqueia combos) -----------------------------------------

## Preço do PRÓXIMO nível da arma (0 se já está no máximo).
func weapon_upgrade_cost() -> int:
	if weapon_level >= MAX_WEAPON_LEVEL:
		return 0
	return int(WEAPON_COSTS[weapon_level + 1])


## Arcontes exigidos para o próximo nível da arma.
func weapon_next_tier() -> int:
	if weapon_level >= MAX_WEAPON_LEVEL:
		return 0
	return int(WEAPON_TIER[weapon_level + 1])


## O próximo nível da arma está selado pelo progresso?
func weapon_sealed() -> bool:
	return weapon_level < MAX_WEAPON_LEVEL and progress_tier() < weapon_next_tier()


func can_upgrade_weapon() -> bool:
	return weapon_level < MAX_WEAPON_LEVEL and not weapon_sealed() and orbs >= weapon_upgrade_cost()


## Presente de arma (o Soter): sobe 1 nível DE GRAÇA, respeitando o selo.
## Devolve false se a arma está no máximo ou selada (quem chama dá outra coisa).
func gift_weapon_level() -> bool:
	if weapon_level >= MAX_WEAPON_LEVEL or weapon_sealed():
		return false
	weapon_level += 1
	weapon_level_changed.emit(weapon_level)
	return true


func upgrade_weapon() -> bool:
	if not can_upgrade_weapon():
		return false
	if spend_orbs(weapon_upgrade_cost()):
		weapon_level += 1
		weapon_level_changed.emit(weapon_level)
		return true
	return false


## Combos liberados dependem do nível da arma (o gancho principal).
func unlocked_combos(character: CharacterData) -> Array:
	var result: Array = []
	if character == null:
		return result
	for combo in character.combos:
		if combo.required_weapon_level <= weapon_level:
			result.append(combo)
	return result


# --- Magias ------------------------------------------------------------

func skill_level(skill_id: String) -> int:
	return skill_levels.get(skill_id, 1)


## Nº do Anel da magia (1..7, na ordem dos Arcontes); 0 = a Esfera Solar inata.
func skill_ring_index(skill_id: String) -> int:
	var ch: CharacterData = GameManager.selected_character
	if ch == null and GameContent.characters.size() > 0:
		ch = GameContent.characters[0]
	if ch == null:
		return 0
	var ring := ""
	for s in ch.skills:
		if s.id == skill_id:
			ring = s.ring
	if ring == "":
		return 0
	for i in Bestiary.bosses.size():
		if str(Bestiary.bosses[i].get("id", "")) == ring:
			return i + 1
	return 0


## Preço do PRÓXIMO nível da magia (Nv.2 ou Nv.3).
func skill_upgrade_cost(skill_id: String) -> int:
	var k := skill_ring_index(skill_id)
	if skill_level(skill_id) <= 1:
		return SKILL_COST_L2 + SKILL_COST_L2_RING * k
	return SKILL_COST_L3 + SKILL_COST_L3_RING * k


## Arcontes exigidos para o PRÓXIMO nível da magia: o Nv.2 sai junto com o
## Anel; o Nv.3 pede 2 Arcontes a mais (a Esfera, 2; o Anel k, k+2; teto 7).
func skill_next_tier(skill_id: String) -> int:
	var k := skill_ring_index(skill_id)
	if skill_level(skill_id) <= 1:
		return k
	return mini(MAX_TIER, k + SKILL_L3_TIER_GAP)


func skill_sealed(skill_id: String) -> bool:
	return progress_tier() < skill_next_tier(skill_id)


func upgrade_skill(skill: SkillData) -> bool:
	var cur := skill_level(skill.id)
	if cur >= skill.max_level or skill_sealed(skill.id):
		return false
	if spend_orbs(skill_upgrade_cost(skill.id)):
		skill_levels[skill.id] = cur + 1
		skill_upgraded.emit(skill.id, cur + 1)
		return true
	return false


# --- HP / MP máximo (Gorgon Eyes / Phoenix Feathers) -------------------

## Quantas vezes a vida máx. foi comprada NESTE run. Save antigo (sem a
## entrada "#vida") = deduzida do bônus: bônus = 20·n + 25·k, k (0–3) dons de
## vida do Soter — 25·k mod 20 é diferente para cada k, então a conta é exata.
func hp_buys() -> int:
	if _flag_has("vida"):
		return maxi(0, _flag_get("vida", "0").to_int())
	return hp_buys_from_bonus(bonus_max_health)


static func hp_buys_from_bonus(bonus: int) -> int:
	for k in 4:
		var rest := bonus - SOTER_HP * k
		if rest >= 0 and rest % HP_STEP == 0:
			return rest / HP_STEP
	return maxi(0, bonus / HP_STEP)


## Preço da (n+1)-ésima compra de vida: 90, 180, 270...
static func hp_cost_for(n: int) -> int:
	return HP_BASE_COST * (n + 1)


## Compras de vida liberadas pelo grau atual (3 + grau, teto 10).
func hp_buy_cap() -> int:
	return mini(HP_MAX_BUYS, HP_FREE_BUYS + progress_tier())


## Grau que abre a (n+1)-ésima compra de vida (a loja mostra "vença <Arconte>").
static func hp_buy_tier(n: int) -> int:
	return maxi(0, n - HP_FREE_BUYS + 1)


## Compras de Éter feitas (save antigo: deduzidas do bônus, 15 cada).
func mp_buys() -> int:
	if _flag_has("eter"):
		return maxi(0, _flag_get("eter", "0").to_int())
	return maxi(0, bonus_max_mana / MP_STEP)


static func mp_cost_for(n: int) -> int:
	return MP_BASE_COST * (n + 1)


## Grau que abre a (n+1)-ésima compra de Éter: 1 + grau, e a última (a 6ª)
## só no grau MP_LAST_TIER.
static func mp_buy_tier(n: int) -> int:
	var t := maxi(0, n - MP_FREE_BUYS + 1)
	if n >= MP_MAX_BUYS - 1:
		t = maxi(t, MP_LAST_TIER)
	return t


## Compras de Éter liberadas pelo grau atual (1 + grau, teto 6; a 6ª pede o
## grau 6).
func mp_buy_cap() -> int:
	var tier := progress_tier()
	var cap := 0
	while cap < MP_MAX_BUYS and mp_buy_tier(cap) <= tier:
		cap += 1
	return cap


## Compra da loja: +20 de vida máx. com preço crescente e teto pelo grau.
func buy_health_upgrade() -> bool:
	var n := hp_buys()
	if n >= hp_buy_cap():
		return false
	if buy_max_health(HP_STEP, hp_cost_for(n)):
		_flag_set("vida", str(n + 1))
		return true
	return false


## Compra da loja: +15 de Éter máx. com preço crescente e teto pelo grau.
func buy_mana_upgrade() -> bool:
	var n := mp_buys()
	if n >= mp_buy_cap():
		return false
	if buy_max_mana(MP_STEP, mp_cost_for(n)):
		_flag_set("eter", str(n + 1))
		return true
	return false


## Preço da Restauração (cura cheia) no grau atual (fora do run, o base).
func heal_cost() -> int:
	if not RunManager.run_active:
		return HEAL_BASE_COST
	return HEAL_BASE_COST + HEAL_TIER_COST * progress_tier()


# --- Relíquias (uma em uso por vez: a escolha é a graça) -----------------

## Dados da relíquia (game_content.gd); {} se não existe.
func relic_data(id: String) -> Dictionary:
	for r in GameContent.relics:
		if r.get("id", "") == id:
			return r
	return {}


func owned_relics() -> PackedStringArray:
	var raw := _flag_get("reliquias", "")
	if raw == "":
		return PackedStringArray()
	return raw.split(",", false)


func has_relic(id: String) -> bool:
	return owned_relics().has(id)


## Relíquias em uso (a mais antiga primeiro). Save da Onda 6 guardava UMA
## ("#reliquia_ativa=perola") — o formato em lista lê igual.
func equipped_relics() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _flag_get("reliquia_ativa", "").split(",", false):
		if has_relic(id) and not out.has(id):
			out.append(id)
	while out.size() > relic_slots():
		out.remove_at(0)
	return out


## A relíquia em uso mais recente ("" = nenhuma) — compatível com a Onda 6.
func equipped_relic() -> String:
	var worn := equipped_relics()
	return worn[worn.size() - 1] if not worn.is_empty() else ""


## Esta relíquia está em uso agora?
func relic_active(id: String) -> bool:
	return equipped_relics().has(id)


## Quantas relíquias cabem em uso (1; 2 com o segundo engaste).
func relic_slots() -> int:
	return 2 if _flag_get("engaste", "") == "1" else 1


## O segundo engaste ainda está selado pelo progresso?
func relic_slot_sealed() -> bool:
	return progress_tier() < RELIC_SLOT_TIER


## Compra o segundo engaste (preço fixo, uma vez por run).
func buy_relic_slot() -> bool:
	if relic_slots() >= 2 or relic_slot_sealed():
		return false
	if not spend_orbs(RELIC_SLOT_COST):
		return false
	_flag_set("engaste", "1")
	relics_changed.emit()
	return true


## A relíquia ainda está selada pelo progresso?
func relic_sealed(id: String) -> bool:
	return progress_tier() < int(relic_data(id).get("tier", 0))


## Compra e já põe em uso (troca a anterior — a comprada continua sua).
func buy_relic(id: String) -> bool:
	var r := relic_data(id)
	if r.is_empty() or has_relic(id) or relic_sealed(id):
		return false
	if not spend_orbs(int(r.get("cost", 0))):
		return false
	var owned := owned_relics()
	owned.append(id)
	_flag_set("reliquias", ",".join(owned))
	equip_relic(id)
	return true


## Põe em uso uma relíquia já comprada (de graça, em qualquer loja). Com os
## engastes cheios, sai a que está em uso há mais tempo.
func equip_relic(id: String) -> bool:
	if not has_relic(id):
		return false
	var worn := equipped_relics()
	if worn.has(id):
		return true
	worn.append(id)
	while worn.size() > relic_slots():
		worn.remove_at(0)
	_flag_set("reliquia_ativa", ",".join(worn))
	relics_changed.emit()
	return true


## Tira uma relíquia de uso (libera o engaste).
func unequip_relic(id: String) -> bool:
	var worn := equipped_relics()
	if not worn.has(id):
		return false
	worn.remove_at(worn.find(id))
	_flag_set("reliquia_ativa", ",".join(worn))
	relics_changed.emit()
	return true


func buy_max_health(amount: int, cost: int) -> bool:
	if spend_orbs(cost):
		bonus_max_health += amount
		stats_changed.emit()
		return true
	return false


func buy_max_mana(amount: int, cost: int) -> bool:
	if spend_orbs(cost):
		bonus_max_mana += amount
		stats_changed.emit()
		return true
	return false
