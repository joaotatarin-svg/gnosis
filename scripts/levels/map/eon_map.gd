extends RefCounted
class_name EonMap
## MAPA DOS ÉONS (Onda 6, diretor de mapa) — cada Éon deixa de ser um corredor
## de 9 telas e vira um pequeno GRAFO por CAMADAS:
##
##   camada:  0        1    2    3        4          5    6        7          8
##            CHEGADA ─┬ A ─ A ─ A ─┐                ┌ A ─ A ─┐
##                     ├ B ─ B ─ B ─┼─ DESAFIO (cp) ─┼ B ─ B ─┼─ ANTESSALA ─ ARCONTE
##                     └ C ─ C ─ C ─┘                └ C ─ C ─┘
##   (A = trilha alta: perigo/escalada/segredo · B = trilha do meio: combate ·
##    C = trilha baixa: santuário/arena; arestas cruzadas entre trilhas vizinhas)
##
## REGRA DE OURO DO DESENHO: todo caminho passa por EXATAMENTE um nó por camada.
## Assim o número da tela (2..64) continua sendo a "camada" do Éon — os beats
## da história (Estelas, Soter, Velkar, legendas por tela), o balance por tela,
## o sorteio determinístico e os checkpoints (camadas 0, 4 e 7, que são nós
## únicos) seguem valendo em QUALQUER rota. A escolha muda o TIPO da tela
## (combate, perigo, escalada, santuário, arena, segredo) e a recompensa.
##
## Os dados ficam numa TABELA literal (LANES) para o João/o chefe ajustarem
## sem mexer em código. Recompensas por tipo em REWARDS (combinar com o diretor
## de progressão — ver docs/pedidos/onda6_mapa6.md).

const LAYERS := 9                  # camadas por Éon (= telas por Éon)
const CONVERGE := [0, 4, 7, 8]     # camadas de nó único (chegada, Desafio, antessala, Arconte)
const ROWS := 3                    # trilhas: 0 alta · 1 meio · 2 baixa
const ROW_LETTER := ["a", "b", "c"]

## Tipos de nó das camadas de escolha, por Éon e camada: [alta, meio, baixa]
## ("" = sem nó nessa trilha). Nós "secret" exigem o PULO DUPLO (Soter).
const LANES := {
	0: {   # TORPOR — ensina o mapa: três trilhas claras, segredo à vista (selado)
		1: ["hazard", "combat", "sanctuary"],
		2: ["platform", "combat", "combat"],
		3: ["hazard", "combat", "sanctuary"],
		5: ["platform", "combat", "sanctuary"],
		6: ["secret", "combat", "challenge"],
	},
	1: {   # FOME — a Arena aparece no meio; Soter (camada 6) vem em qualquer trilha
		1: ["platform", "combat", "sanctuary"],
		2: ["hazard", "challenge", "combat"],
		3: ["secret", "combat", "sanctuary"],
		5: ["hazard", "combat", "sanctuary"],
		6: ["platform", "combat", "challenge"],
	},
	2: {   # CORRENTE — o 1º segredo já ao alcance (pulo duplo depois do Soter #1)
		1: ["hazard", "combat", "sanctuary"],
		2: ["secret", "combat", "challenge"],
		3: ["platform", "combat", "sanctuary"],
		5: ["hazard", "challenge", "sanctuary"],
		6: ["secret", "combat", "combat"],
	},
	3: {   # SILÊNCIO — biblioteca: mais santuários, escalada nas estantes
		1: ["platform", "combat", "sanctuary"],
		2: ["platform", "combat", "sanctuary"],
		3: ["secret", "challenge", "combat"],
		5: ["hazard", "combat", "sanctuary"],
		6: ["platform", "combat", "challenge"],
	},
	4: {   # ESPELHO — trilhas se cruzam muito (reflexos)
		1: ["hazard", "combat", "challenge"],
		2: ["platform", "combat", "sanctuary"],
		3: ["secret", "combat", "sanctuary"],
		5: ["platform", "challenge", "sanctuary"],
		6: ["secret", "combat", "combat"],
	},
	5: {   # PRAGA — perigo em toda parte, santuário raro
		1: ["hazard", "combat", "sanctuary"],
		2: ["hazard", "challenge", "combat"],
		3: ["platform", "combat", "secret"],
		5: ["hazard", "combat", "sanctuary"],
		6: ["platform", "challenge", "combat"],
	},
	6: {   # COROA — a subida final: duas arenas, dois segredos
		1: ["platform", "combat", "challenge"],
		2: ["hazard", "combat", "sanctuary"],
		3: ["secret", "challenge", "combat"],
		5: ["platform", "combat", "sanctuary"],
		6: ["secret", "combat", "challenge"],
	},
}

## Tipos fixos das camadas de nó único.
const FIXED := {0: "arrival", 4: "trial", 7: "antechamber", 8: "archon"}

## Nome, descrição curta e papel legado (RunManager.screen_role) de cada tipo.
const KINDS := {
	"arrival": {"name": "Chegada", "desc": "A porta do Éon. Checkpoint.", "role": "arrival"},
	"combat": {"name": "Travessia", "desc": "Zonas de combate cheias. Mais faíscas.", "role": "travel"},
	"hazard": {"name": "Passagem perigosa", "desc": "Menos inimigos, chão traiçoeiro. Fortalece a vida.", "role": "travel"},
	"platform": {"name": "Escalada", "desc": "Plataformas e altura. Fortalece o Éter.", "role": "travel"},
	"sanctuary": {"name": "Santuário", "desc": "Luta leve e um lugar de repouso. Cura inteira.", "role": "travel"},
	"challenge": {"name": "Arena", "desc": "Opcional e dura: ondas pesadas. Grande recompensa.", "role": "travel"},
	"secret": {"name": "Sala secreta", "desc": "Só se alcança com o pulo duplo. Um tesouro escondido.", "role": "travel"},
	"trial": {"name": "O Desafio", "desc": "O Campeão guarda o santuário do Éon. Checkpoint.", "role": "trial"},
	"antechamber": {"name": "Antessala", "desc": "A última prova antes do trono. Checkpoint.", "role": "antechamber"},
	"archon": {"name": "O Arconte", "desc": "O senhor deste Éon.", "role": "archon"},
}

## Recompensa por tipo, aplicada quando o nó é VENCIDO (RunManager): faíscas
## (orbs = base + por_eon × Éon), +vida máx. (hp), +Éter máx. (mp), cura inteira
## na próxima tela (heal). Valores modestos de propósito: o playtest (#8) achou a
## economia generosa demais — quem calibra é o diretor de progressão.
## Calibrado pela Progressão (Onda 6, docs/onda2/PROGRESSAO6.md): vida/Éter do
## mapa vêm DE GRAÇA e fora dos tetos da loja — com os valores antigos uma rota
## "só perigo/Arena/segredo" somava até ~210 de vida (mais que a trilha inteira
## da loja, +200). Agora ~0,75 disso e só para quem troca santuário por risco.
const REWARDS := {
	"combat": {"orbs": 6, "per_eon": 3},
	"hazard": {"hp": 4},
	"platform": {"mp": 4},
	"sanctuary": {"heal": true},
	"challenge": {"orbs": 30, "per_eon": 10, "hp": 6},
	"secret": {"orbs": 20, "per_eon": 6, "hp": 8, "mp": 8},
}

## Requisito de cada tipo ("" = livre).
const REQUIRES := {"secret": "double_jump"}

static var _cache: Dictionary = {}


## Grafo de um Éon (0..6), em cache: {"eon", "nodes": {id: nó}, "layers": [[ids]]}.
## Nó = {id, eon, layer, row, kind, screen, next: [ids], requires, reward}.
static func graph(eon: int) -> Dictionary:
	eon = clampi(eon, 0, 6)
	if not _cache.has(eon):
		_cache[eon] = _build(eon)
	return _cache[eon]


static func node_id(eon: int, layer: int, row: int) -> String:
	return "e%d.%d%s" % [eon, layer, ROW_LETTER[clampi(row, 0, ROWS - 1)]]


## Tela (2..64) de uma camada de um Éon — a mesma conta do RunManager.
static func screen_of(eon: int, layer: int) -> int:
	return 2 + eon * LAYERS + layer


static func kind_name(kind: String) -> String:
	return String(KINDS.get(kind, {}).get("name", kind))


static func kind_desc(kind: String) -> String:
	return String(KINDS.get(kind, {}).get("desc", ""))


## Recompensa concreta (com o Éon aplicado) de um tipo: {orbs, hp, mp, heal}.
static func reward_for(kind: String, eon: int) -> Dictionary:
	var r: Dictionary = REWARDS.get(kind, {})
	var out := {}
	var orbs := int(r.get("orbs", 0)) + int(r.get("per_eon", 0)) * eon
	if orbs > 0:
		out["orbs"] = orbs
	if int(r.get("hp", 0)) > 0:
		out["hp"] = int(r.hp)
	if int(r.get("mp", 0)) > 0:
		out["mp"] = int(r.mp)
	if bool(r.get("heal", false)):
		out["heal"] = true
	return out


## Texto curto da recompensa ("+12 faíscas · +5 vida máx.").
static func reward_text(rw: Dictionary) -> String:
	var parts: Array[String] = []
	if int(rw.get("orbs", 0)) > 0:
		parts.append(I18n.t("+%d faíscas") % int(rw.orbs))
	if int(rw.get("hp", 0)) > 0:
		parts.append(I18n.t("+%d vida máx.") % int(rw.hp))
	if int(rw.get("mp", 0)) > 0:
		parts.append(I18n.t("+%d Éter máx.") % int(rw.mp))
	if bool(rw.get("heal", false)):
		parts.append(I18n.t("cura inteira"))
	return "  ·  ".join(parts)


static func _build(eon: int) -> Dictionary:
	var nodes := {}
	var layers: Array = []
	var table: Dictionary = LANES.get(eon, LANES[0])
	for layer in LAYERS:
		var ids: Array = []
		if FIXED.has(layer):
			var id := node_id(eon, layer, 1)
			nodes[id] = _make(eon, layer, 1, String(FIXED[layer]))
			ids.append(id)
		else:
			var row_kinds: Array = table.get(layer, ["", "combat", ""])
			for row in ROWS:
				var k: String = String(row_kinds[row]) if row < row_kinds.size() else ""
				if k == "":
					continue
				var id := node_id(eon, layer, row)
				nodes[id] = _make(eon, layer, row, k)
				ids.append(id)
		layers.append(ids)
	# Arestas: nó único → todos da próxima camada; trilha → mesma trilha e,
	# alternando por (Éon + camada), a trilha vizinha (cruzamento); → nó único.
	for layer in LAYERS - 1:
		var here: Array = layers[layer]
		var nxt: Array = layers[layer + 1]
		for id in here:
			var n: Dictionary = nodes[id]
			var out: Array = []
			if nxt.size() == 1 or here.size() == 1:
				out = nxt.duplicate()
			else:
				var r: int = int(n.row)
				var cross := r + (1 if (eon + layer) % 2 == 0 else -1)
				if cross < 0 or cross >= ROWS:
					cross = r + (-1 if (eon + layer) % 2 == 0 else 1)
				for cand in [r, cross]:
					var cid := node_id(eon, layer + 1, cand)
					if nodes.has(cid) and not out.has(cid):
						out.append(cid)
				# Nunca um beco que só um segredo resolve: garante uma saída livre.
				var free := false
				for cid in out:
					if String(nodes[cid].requires) == "":
						free = true
				if not free:
					var mid := node_id(eon, layer + 1, 1)
					if nodes.has(mid) and not out.has(mid):
						out.append(mid)
				if out.is_empty():
					out = nxt.duplicate()
			n.next = out
	return {"eon": eon, "nodes": nodes, "layers": layers}


static func _make(eon: int, layer: int, row: int, kind: String) -> Dictionary:
	return {
		"id": node_id(eon, layer, row),
		"eon": eon,
		"layer": layer,
		"row": row,
		"kind": kind,
		"screen": screen_of(eon, layer),
		"next": [],
		"requires": String(REQUIRES.get(kind, "")),
		"reward": reward_for(kind, eon),
	}


## Procura um nó por id em qualquer Éon ({} se não existir).
static func find(id: String) -> Dictionary:
	if not id.begins_with("e") or id.length() < 4:
		return {}
	var dot := id.find(".")
	if dot < 2:
		return {}
	var eon := id.substr(1, dot - 1).to_int()
	if eon < 0 or eon > 6:
		return {}
	return graph(eon).nodes.get(id, {})


## Ids dos nós de uma camada.
static func layer_ids(eon: int, layer: int) -> Array:
	var g := graph(eon)
	if layer < 0 or layer >= (g.layers as Array).size():
		return []
	return g.layers[layer]


## Nó PADRÃO de uma camada (sem escolha registrada): o do meio (combate) ou o
## único. É o que a tela "era" antes do mapa — o plano legado da tela.
static func default_id(eon: int, layer: int) -> String:
	var ids := layer_ids(eon, layer)
	if ids.is_empty():
		return ""
	var mid := node_id(eon, layer, 1)
	return mid if ids.has(mid) else String(ids[0])


## Slot de compatibilidade dos beats: "e<Éon>.L<camada>" — equivale à tela
## legada (ex.: "e1.L6" = tela 17, o 1º Soter). Ver docs/onda2/MAPA6.md.
static func slot(eon: int, layer: int) -> String:
	return "e%d.L%d" % [eon, layer]
