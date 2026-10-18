extends Node
## Bestiário + evolução do herói + balanceamento por tela.
## Autoload acessível como `Bestiary`.
##
## Balanceamento determinístico: os stats de um inimigo dependem SÓ do tipo e do
## número da tela. Inimigo da tela 1 sempre tem a mesma vida; na tela 64, o
## mesmo tipo tem o boost fixo daquela tela. Nada aleatório.

var wave_types: Array = []   # inimigos comuns (waves)
var bosses: Array = []       # os 7 Arcontes (ordem dos Éons)
var specials: Array = []     # O Rei (tutorial), o Rei enfraquecido e o Colosso (final)
var echoes: Array = []       # ecos dos Arcontes (Centro) — gerados a partir de `bosses`
var demiurge: Dictionary = {}
var items: Array = []        # itens = peças de gear que aparecem no herói

## Bot temático de cada Éon (entra nas waves daquele Éon, além do pool por tier).
const EON_BOTS := ["sonambulo", "glutao", "carcereiro", "mudo", "reflexo", "esporos", "pretoriano"]


## Criaturas já ENCONTRADAS (backlog #26/#35): id → true. Meta-progresso
## gravado no save (`bestiary_seen`); o Bestiário/Galeria só mostra as vistas.
signal seen_changed(id: String)
var _seen: Dictionary = {}


func _ready() -> void:
	_build()
	# "Ao encontrar": todo Enemy que entra na árvore DURANTE a campanha marca o
	# seu tipo como visto (Provação e cenas de teste fora de run não contam).
	get_tree().node_added.connect(_on_node_added)


# --- vistos (Bestiário) ---------------------------------------------------------

## A criatura `id` já foi encontrada na campanha?
func seen(id: String) -> bool:
	return _seen.has(id)


## Marca como vista. Devolve true se era inédita.
func mark_seen(id: String) -> bool:
	if id == "" or _seen.has(id):
		return false
	_seen[id] = true
	seen_changed.emit(id)
	# Vai ao disco no próximo save (fim da tela, morte, opções). NÃO grava aqui:
	# um save no meio da tela gravaria as faíscas ganhas nela com a retomada
	# no checkpoint (dava para repetir o trecho e acumular).
	return true


func seen_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _seen:
		out.append(String(k))
	return out


func set_seen_ids(ids: Array) -> void:
	_seen.clear()
	for id in ids:
		_seen[String(id)] = true


## Quantos tipos de wave (criaturas comuns + bots dos Éons) já foram vistos.
func seen_wave_count() -> int:
	var n := 0
	for t in wave_types:
		if _seen.has(t.id):
			n += 1
	return n


func _on_node_added(node: Node) -> void:
	if not (node is Enemy):
		return
	if not RunManager.run_active or CodexSession.active:
		return
	# O type_id costuma vir antes do add_child, mas o Level pode ajustá-lo no
	# _ready: lê depois de pronto.
	node.ready.connect(_mark_enemy_seen.bind(node), CONNECT_ONE_SHOT)


func _mark_enemy_seen(node: Node) -> void:
	if is_instance_valid(node) and RunManager.run_active and not CodexSession.active:
		mark_seen(String(node.get("type_id")))


## Progresso do run (0 na tela 1, 1 na tela do 7º Arconte, até 1.15 no fim).
## Normalizado pelo mapa: mudar o número de telas NÃO muda os valores finais.
func run_progress(screen: int) -> float:
	var span := float(maxi(1, RunManager.LAST_ARCHON_SCREEN - 1))
	return clampf(float(screen - 1) / span, 0.0, 1.15)


## Vida dos inimigos: cresce até ≈1.98x na tela do 7º Arconte (r2 2026-09-11:
## +3% em vida E dano virava pântano no fim — o combate arrastava).
func screen_multiplier(screen: int) -> float:
	return 1.0 + run_progress(screen) * 0.8   # r7: 0.98 → 0.8 (lutas mais curtas = menos dano tomado)


## Dano dos inimigos: cresce mais devagar que a vida (≈1.59x no 7º Arconte).
func damage_multiplier(screen: int) -> float:
	return 1.0 + run_progress(screen) * 0.4   # r7: 0.588 → 0.5 → 0.45 → 0.4 (travessias mais longas)


func is_boss_id(id: String) -> bool:
	for b in bosses:
		if b.id == id:
			return true
	for s in specials:
		if s.id == id:
			return true
	return demiurge.get("id", "") == id


func get_type(id: String) -> Dictionary:
	for t in wave_types:
		if t.id == id:
			return t
	for b in bosses:
		if b.id == id:
			return b
	for s in specials:
		if s.id == id:
			return s
	for e in echoes:
		if e.id == id:
			return e
	if demiurge.get("id", "") == id:
		return demiurge
	return wave_types[0] if wave_types.size() > 0 else {}


## Quais tipos de wave aparecem numa dada tela: pool por tier de dificuldade +
## o bot temático do Éon (com peso dobrado, pra dar cara ao ato).
## Em run, o tier vem do ÉON (0 → 1 · 1–2 → 2 · 3–4 → 3 · 5+ → 4); fora de run
## (cenas de teste) vale a regra antiga por número de tela.
func types_for_screen(screen: int) -> Array:
	var max_tier := 1
	if RunManager.run_active:
		var e := RunManager.eon_index(screen)
		if e >= 1: max_tier = 2
		if e >= 3: max_tier = 3
		if e >= 5: max_tier = 4
	else:
		if screen >= 13: max_tier = 2
		if screen >= 26: max_tier = 3
		if screen >= 41: max_tier = 4
	var ids: Array = []
	for t in wave_types:
		if t.tier <= max_tier:
			ids.append(t.id)
	if RunManager.run_active:
		var eon := RunManager.eon_index(screen)
		if eon >= 0 and eon < EON_BOTS.size():
			ids.append(EON_BOTS[eon])
			ids.append(EON_BOTS[eon])
	return ids


## Soter, o Ungido: branco e ouro, manto, aura — o único que o Cego não vê.
func soter_profile() -> ArtProfile:
	return _profile(ArtProfile.Body.HUMANOID, 50.0,
		Color(0.93, 0.9, 0.82), Color(0.85, 0.72, 0.38), Color(1.0, 0.96, 0.75),
		["cape", "aura", "face", "hair", "soter"])


## Velkar, o Arrependido: Arconte caído — chifre quebrado, sem coroa, olho fraco.
func velkar_profile() -> ArtProfile:
	return _profile(ArtProfile.Body.BRUTE, 56.0,
		Color(0.4, 0.32, 0.44), Color(0.24, 0.18, 0.26), Color(0.75, 0.6, 0.5),
		["horns", "pauldrons", "velkar"])


## Aparência do herói — muda conforme o nível da arma e os itens adquiridos.
## (Com o rig PNG ligado, só a COR do orbe/aura vem daqui.)
func player_profile(character: CharacterData, weapon_level: int, owned_items: Array = []) -> ArtProfile:
	var body := ArtProfile.Body.HUMANOID
	var feats: Array = []
	var primary: Color = Color("e2dac2")
	var secondary := Color(0.85, 0.72, 0.38)      # ouro do gear
	var eye := Color(1.0, 0.92, 0.55)

	# Sophia (única): humanoide (anima bem, ganha o núcleo no peito e o gear), cajado,
	# rosto e cabelo comprido (a faísca em forma de gente).
	feats = ["staff", "hair"]
	eye = Color("a3eee2")

	# Evolução por nível de arma (fica mais "foda" a cada tier).
	if weapon_level >= 2: feats.append("pauldrons")
	if weapon_level >= 3: feats.append("helmet")
	if weapon_level >= 4: feats.append("bracers")
	if weapon_level >= 5:
		feats.append("crown")
		feats.append("aura")

	for it in owned_items:
		if not feats.has(it):
			feats.append(it)

	feats.append("hero")   # detalhe extra (núcleo de luz no peito) só no herói
	var p := _profile(body, 46.0, primary, secondary, eye, feats)
	p.skin = Color(0.96, 0.90, 0.86)
	p.hair = Color("e8eee5")     # lilás-prata: cabelo de luz
	return p


# --- construção do conteúdo -------------------------------------------

## Graduação de cor do corpo (giro de matiz em rad, saturação, tinta) — vai no
## shader do contorno (scripts/entities/enemies/enemy_grade.gdshader).
func _grade(id: String, hue: float, sat: float, tint: Color) -> void:
	var t: Dictionary = get_type(id)
	if String(t.get("id", "")) != id:
		return
	t["grade"] = [hue, sat, tint]


## Troca a pintura usada por um tipo (id do PaintedLibrary) e dá a tinta própria
## (`tint` vai no self_modulate do desenho — Enemy._ready).
func _art_as(id: String, painted: String, tint: Color) -> void:
	var t: Dictionary = get_type(id)
	if String(t.get("id", "")) != id:
		return
	(t.profile as ArtProfile).painted_id = painted
	t["tint"] = tint


func _profile(body: int, height: float, primary: Color, secondary: Color, eye: Color, features: Array) -> ArtProfile:
	var p := ArtProfile.new()
	p.body = body
	p.height = height
	p.primary = primary
	p.secondary = secondary
	p.eye = eye
	p.features = PackedStringArray(features)
	return p


## style: "melee" (corpo-a-corpo), "ranged" (atira), "charge" (investida),
## "slam" (pancada no chão com onda de choque).
## kit: assinatura de chefe (torpor/fome/corrente/silencio/espelho/praga/coroa/rei/colosso).
## behavior: comportamento de wave (shield/teleport/exploder/summoner/slowshot/
##   leech/chainshot/silencer/dodger/spores/guard).
func _wt(id: String, name: String, tier: int, hp: int, dmg: int, spd: float, spark: int, profile: ArtProfile, style: String = "melee", kit: String = "", behavior: String = "") -> Dictionary:
	profile.painted_id = id
	return {
		"id": id, "name": name, "tier": tier, "base_health": hp,
		"base_damage": dmg, "move_speed": spd, "spark": spark, "profile": profile,
		"style": style, "kit": kit, "behavior": behavior, "art": id,
	}


func _build() -> void:
	var H := ArtProfile.Body.HUMANOID
	var B := ArtProfile.Body.BRUTE
	var W := ArtProfile.Body.WRAITH
	var A := ArtProfile.Body.BEAST
	var C := ArtProfile.Body.COLOSSUS

	wave_types = [
		# Tier 1 (Éon 0 / telas 1–12 fora de run)
		_wt("larva", "Larva do Kenoma", 1, 40, 6, 55.0, 4,
			_profile(W, 38, Color(0.55, 0.75, 0.55), Color(0.2, 0.3, 0.22), Color(0.7, 1, 0.7), [])),
		_wt("sombra", "Sombra Errante", 1, 44, 7, 95.0, 5,
			_profile(W, 46, Color(0.28, 0.24, 0.36), Color(0.15, 0.12, 0.2), Color(0.72, 0.5, 1), [])),
		_wt("servo", "Servo do Demiurgo", 1, 58, 9, 105.0, 6,
			_profile(H, 48, Color(0.5, 0.5, 0.55), Color(0.3, 0.3, 0.34), Color(1, 0.8, 0.4), ["blade"])),
		# SÓ À DISTÂNCIA (Onda 6): rajada de setas, fogo-fátuo teleguiado e foge
		# quando você chega perto — ensina a fechar distância com esquiva.
		_wt("acolito", "Acólito do Fogo-Fátuo", 1, 34, 7, 80.0, 6,
			_profile(H, 48, Color(0.4, 0.62, 0.6), Color(0.2, 0.34, 0.33), Color(0.6, 1.0, 0.9), ["staff"]), "ranged"),
		# Larva Ardente: corre até você e EXPLODE (imparável — ensina a esquivar).
		_wt("larva_ardente", "Larva Ardente", 1, 26, 15, 82.0, 5,
			_profile(W, 36, Color(0.85, 0.45, 0.25), Color(0.4, 0.15, 0.08), Color(1, 0.75, 0.4), []), "melee", "", "exploder"),
		# Tier 2 (Éons 1–2)
		_wt("espinho", "Guardião Espinhoso", 2, 95, 11, 60.0, 10,
			_profile(B, 56, Color(0.7, 0.28, 0.26), Color(0.35, 0.14, 0.13), Color(1, 0.7, 0.3), ["spikes"]), "slam"),
		_wt("canino", "Besta Canina", 2, 78, 10, 110.0, 9,
			_profile(A, 40, Color(0.55, 0.4, 0.28), Color(0.3, 0.2, 0.14), Color(1, 0.85, 0.4), ["claws", "tail"]), "charge"),
		_wt("cornudo", "Ceifador Cornudo", 2, 85, 11, 85.0, 10,
			_profile(H, 50, Color(0.72, 0.3, 0.4), Color(0.3, 0.12, 0.16), Color(1, 0.6, 0.5), ["horns", "blade"])),
		# Escudeiro: golpe leve bate no escudo; só pesado ou magia ferem.
		_wt("escudeiro", "Escudeiro do Selo", 2, 95, 11, 70.0, 11,
			_profile(H, 50, Color(0.42, 0.45, 0.58), Color(0.7, 0.62, 0.4), Color(1, 0.85, 0.5), ["shield", "helmet"]), "melee", "", "shield"),
		# VOADOR (Onda 6): paira alto, avisa com uma linha e MERGULHA na diagonal;
		# pousa e fica 1 s no chão (castigo por terra) — ou derrube no ar.
		_wt("espectro", "Espectro Mergulhador", 2, 50, 10, 95.0, 11,
			_profile(W, 44, Color(0.55, 0.7, 0.85), Color(0.3, 0.4, 0.55), Color(0.7, 0.95, 1.0), ["wings"])),
		# Tier 3 (Éons 3–4)
		# VOADOR (Onda 6): orbita por cima, atira em leque na diagonal, chama
		# colunas de luz e dá rasantes. Só aéreos/magia o alcançam lá em cima.
		_wt("alado", "Vigia Alado", 3, 62, 11, 95.0, 12,
			_profile(W, 50, Color(0.32, 0.3, 0.5), Color(0.2, 0.18, 0.32), Color(0.6, 0.7, 1), ["wings"]), "ranged"),
		_wt("bruto", "Bruto de Ferro", 3, 120, 14, 55.0, 16,
			_profile(B, 64, Color(0.5, 0.34, 0.6), Color(0.28, 0.18, 0.34), Color(1, 0.8, 0.5), ["pauldrons"]), "slam"),
		_wt("arauto", "Arauto do Silêncio", 3, 100, 12, 75.0, 15,
			_profile(H, 52, Color(0.6, 0.55, 0.32), Color(0.4, 0.34, 0.16), Color(1, 0.9, 0.5), ["crown", "staff"]), "ranged"),
		# Fantasma (Onda 6): flutua baixo, aparece ATRÁS de você e agarra.
		_wt("fantasma", "Fantasma do Vazio", 3, 80, 12, 90.0, 13,
			_profile(W, 50, Color(0.5, 0.42, 0.66), Color(0.3, 0.24, 0.4), Color(0.85, 0.7, 1), ["aura"]), "melee", "", "teleport"),
		# Invocador: mantém distância, atira e chama larvas.
		_wt("invocador", "Invocador de Larvas", 3, 95, 10, 60.0, 16,
			_profile(H, 52, Color(0.36, 0.5, 0.4), Color(0.2, 0.3, 0.22), Color(0.7, 1, 0.6), ["staff", "horns"]), "ranged", "", "summoner"),
		# Tier 4 (Éons 5–6)
		_wt("aberracao", "Aberração do Vazio", 4, 125, 14, 100.0, 18,
			_profile(A, 48, Color(0.4, 0.5, 0.4), Color(0.2, 0.28, 0.2), Color(0.7, 1, 0.6), ["spikes", "tail", "claws"]), "charge"),

		# --- OS BOTS DE CADA ÉON (tier 9 = só entram pelo Éon, ver types_for_screen) ---
		# Torpor: Sonâmbulo — atira bocejos que deixam a Sophia LENTA.
		_wt("sonambulo", "Sonâmbulo", 9, 60, 8, 45.0, 8,
			_profile(H, 48, Color(0.5, 0.52, 0.62), Color(0.3, 0.3, 0.4), Color(0.75, 0.8, 1.0), ["eyelid"]), "ranged", "", "slowshot"),
		# Fome: Glutão — cada mordida que acerta CURA ele.
		_wt("glutao", "Glutão", 9, 110, 12, 60.0, 12,
			_profile(B, 58, Color(0.65, 0.3, 0.25), Color(0.35, 0.14, 0.1), Color(1, 0.6, 0.3), ["maw"]), "melee", "", "leech"),
		# Corrente: Carcereiro — corrente curta que PRENDE no lugar.
		_wt("carcereiro", "Carcereiro", 9, 100, 12, 70.0, 12,
			_profile(H, 52, Color(0.42, 0.4, 0.5), Color(0.26, 0.24, 0.32), Color(1, 0.8, 0.5), ["chains", "helmet", "blade"]), "ranged", "", "chainshot"),
		# Silêncio: Bibliotecário Mudo — aura curta que CALA as magias.
		_wt("mudo", "Bibliotecário Mudo", 9, 95, 12, 80.0, 13,
			_profile(W, 50, Color(0.32, 0.3, 0.44), Color(0.18, 0.18, 0.28), Color(0.7, 0.8, 1), ["sewn"]), "melee", "", "silencer"),
		# Espelho: Reflexo — recua no instante em que você golpeia.
		_wt("reflexo", "Reflexo", 9, 90, 13, 120.0, 14,
			_profile(H, 48, Color(0.8, 0.82, 0.9), Color(0.55, 0.5, 0.8), Color(1, 0.4, 0.4), ["mirror", "blade"]), "melee", "", "dodger"),
		# Praga: Portador de Esporos — ao morrer deixa uma poça de veneno.
		_wt("esporos", "Portador de Esporos", 9, 100, 12, 85.0, 13,
			_profile(A, 44, Color(0.42, 0.5, 0.32), Color(0.24, 0.3, 0.16), Color(0.75, 1, 0.55), ["rot", "claws"]), "charge", "", "spores"),
		# Coroa: Pretoriano — só toma dano cheio por trás ou de golpe pesado.
		_wt("pretoriano", "Pretoriano da Coroa", 9, 130, 15, 65.0, 18,
			_profile(H, 54, Color(0.6, 0.48, 0.24), Color(0.36, 0.28, 0.12), Color(1, 0.88, 0.45), ["crown", "pauldrons", "shield", "blade"]), "melee", "", "guard"),

		# Só invocada por Astaphaios (tier 9 = nunca entra nas waves).
		_wt("sombra_sophia", "Sombra da Sophia", 9, 120, 14, 170.0, 30,
			_profile(H, 46, Color(0.28, 0.22, 0.4), Color(0.4, 0.34, 0.2), Color(1, 0.3, 0.3), ["staff", "hero", "hair"]), "melee"),
	]
	# A Sombra é a Sophia invertida: pele cinza, cabelo negro.
	var sombra: ArtProfile = wave_types[wave_types.size() - 1].profile
	sombra.skin = Color(0.55, 0.5, 0.58)
	sombra.hair = Color(0.12, 0.08, 0.16)

	# Onda 6 — alado, fantasma e cornudo NÃO são mais miniaturas de Arconte
	# (o PaintedLibrary os mapeava para Yabel, Athoth e Galila: "mini-chefe com a
	# cara do chefe"). Enquanto a arte própria não chega (docs/pedidos/
	# onda6_inimigos6.md), usam uma pintura de criatura de OUTRO Éon + tinta.
	_art_as("alado", "sonambulo", Color(1.12, 1.0, 0.72, 1.0))      # sentinela dourada
	_art_as("fantasma", "mudo", Color(0.82, 0.72, 1.15, 0.8))       # translúcido violeta
	_art_as("cornudo", "ceifador", Color(1.12, 0.82, 0.82, 1.0))     # espadachim rubro
	_art_as("espectro", "espectro", Color(0.72, 0.92, 1.15, 0.86))   # verme-espírito pálido
	_art_as("acolito", "acolito", Color(0.74, 1.0, 0.94, 1.0))      # conjurador verde-água
	# GRADUAÇÃO de cor (Onda 6 — "mini-chefe com a cara do chefe"): a pintura dos
	# bots é da FAMÍLIA do Arconte do Éon (sonâmbulo ≈ Athoth, glutão ≈ Harmas…).
	# Sem arte nova, a cor separa: o Arconte guarda a cor-assinatura e os servos
	# ficam cinzentos (escala de servo). O Campeão ganha a sua (Enemy.CHAMPION_GRADE).
	for bot in EON_BOTS:
		_grade(bot, 0.0, 0.38, Color(0.94, 0.92, 0.98))
	_grade("alado", 2.6, 0.85, Color(1.05, 1.0, 0.92))      # pintura do sonâmbulo → âmbar (não o anil de Athoth)
	_grade("fantasma", -1.4, 0.7, Color(0.9, 1.05, 1.05))    # pintura do mudo → verde-espectro (não o anil de Yabel)

	# Os 7 Arcontes dos 7 Éons (ordem = ordem dos atos; ver docs/LORE.md).
	# Cada um tem uma ASSINATURA visual (feature própria) e um KIT de mecânica.
	bosses = [
		# Torpor: pálpebra pesada; atira + solta névoa do sono (lentidão).
		_wt("arconte_sono", "Athoth, Arconte do Torpor", 5, 260, 15, 50.0, 110,
			_profile(W, 84, Color(0.34, 0.36, 0.46), Color(0.2, 0.2, 0.3), Color(0.72, 0.78, 1), ["aura", "eyelid"]), "ranged", "torpor"),
		# Fome: boca sem fim no torso; suga a Sophia antes da pancada.
		_wt("arconte_fome", "Harmas, Arconte da Fome", 5, 340, 17, 46.0, 120,
			_profile(C, 96, Color(0.6, 0.22, 0.2), Color(0.32, 0.12, 0.1), Color(1, 0.6, 0.25), ["horns", "spikes", "pauldrons", "maw"]), "slam", "fome"),
		# Corrente: elos pendurados; investe e lança corrente que prende no lugar.
		_wt("arconte_corrente", "Galila, Arconte da Corrente", 5, 420, 18, 50.0, 130,
			_profile(B, 92, Color(0.44, 0.4, 0.5), Color(0.26, 0.22, 0.3), Color(1, 0.75, 0.5), ["pauldrons", "blade", "horns", "chains"]), "charge", "corrente"),
		# Silêncio: boca costurada; aura cala as magias; fase 2 pisca pra trás.
		_wt("arconte_silencio", "Yabel, Arconte do Silêncio", 5, 500, 19, 66.0, 140,
			_profile(W, 88, Color(0.3, 0.3, 0.42), Color(0.16, 0.16, 0.26), Color(0.7, 0.8, 1), ["wings", "aura", "crown", "sewn"]), "ranged", "silencio"),
		# Espelho: cacos orbitando, cajado como o dela; fase 2 invoca a Sombra da Sophia.
		_wt("arconte_espelho", "Astaphaios, Arconte do Espelho", 5, 560, 20, 74.0, 150,
			_profile(H, 76, Color(0.82, 0.84, 0.92), Color(0.6, 0.5, 0.85), Color(1, 0.35, 0.35), ["staff", "pauldrons", "mirror"]), "melee", "espelho"),
		# Praga: gavinhas podres; a investida deixa poças de veneno.
		_wt("arconte_praga", "Belias, Arconte da Praga", 5, 640, 21, 80.0, 160,
			_profile(A, 90, Color(0.4, 0.5, 0.34), Color(0.22, 0.3, 0.18), Color(0.75, 1, 0.55), ["claws", "tail", "spikes", "rot"]), "charge", "praga"),
		# Coroa: coroa alta e halo; fase 2 chama servos e fica blindado até caírem.
		_wt("arconte_coroa", "Armupiel, Arconte da Coroa", 5, 740, 23, 52.0, 180,
			_profile(C, 100, Color(0.62, 0.5, 0.24), Color(0.36, 0.28, 0.12), Color(1, 0.88, 0.45), ["bigcrown", "pauldrons", "aura", "blade"]), "slam", "coroa"),
	]

	# --- O Demiurgo em suas formas ---
	# O REI (Ato 1, tela 1): o sacerdote branco mascarado que sai da névoa. Usa o
	# PNG do Demiurgo (art = "demiurgo"). Tutorial: vida curta, golpes lentos.
	var rei := _wt("rei", "O Rei", 5, 320, 12, 40.0, 60,   # 18/09: João achou o duelo fácil (era 200/8)
		_profile(C, 92, Color(0.85, 0.82, 0.75), Color(0.5, 0.45, 0.3), Color(1, 0.9, 0.6), ["crown", "cape", "aura"]), "ranged", "rei")
	rei.art = "demiurgo"
	# O REI enfraquecido (batalha final): a mentira, mais frágil e mais rápida.
	var rei_final := _wt("rei_final", "O Rei — a Mentira", 5, 620, 20, 60.0, 400,
		_profile(C, 92, Color(0.85, 0.82, 0.75), Color(0.5, 0.45, 0.3), Color(1, 0.9, 0.6), ["crown", "cape", "aura"]), "ranged", "rei")
	rei_final.art = "demiurgo"
	# O COLOSSO OCO (batalha final): a verdade — gigante com cacos da máscara na cara.
	var colosso := _wt("colosso", "O Colosso Oco — a Verdade", 5, 820, 24, 42.0, 500,
		_profile(C, 130, Color(0.22, 0.16, 0.2), Color(0.45, 0.36, 0.2), Color(1, 0.75, 0.4), ["horns", "spikes", "pauldrons", "aura", "cracked", "bigcrown"]), "slam", "colosso")
	specials = [rei, rei_final, colosso]

	demiurge = _wt("demiurgo", "Yaldabaoth", 9, 1600, 26, 40.0, 1000,
		_profile(C, 92, Color(0.55, 0.45, 0.2), Color(0.3, 0.24, 0.1), Color(1, 0.9, 0.4), ["crown", "cape", "aura", "horns", "pauldrons"]), "slam")

	# --- ECOS dos Arcontes (o Centro): 30% da vida, sem o kit, morrem em segundos.
	echoes = []
	for b in bosses:
		var p: ArtProfile = b.profile.duplicate()
		p.height = b.profile.height * 0.75
		var e := _wt("eco_" + b.id, "Eco de " + b.name.split(",")[0], 9, int(b.base_health * 0.3), int(b.base_damage * 0.6), b.move_speed * 1.2, 40, p, b.style, "", "")
		echoes.append(e)

	# Itens = as próprias peças de gear que surgem no herói ao evoluir.
	items = [
		{"id": "pauldrons", "name": "Ombreiras do Éon", "feature": "pauldrons"},
		{"id": "helmet", "name": "Elmo do Guardião", "feature": "helmet"},
		{"id": "bracers", "name": "Braceletes do Éon", "feature": "bracers"},
		{"id": "crown", "name": "Diadema da Fonte", "feature": "crown"},
	]
