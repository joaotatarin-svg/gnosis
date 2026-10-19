extends RefCounted
class_name ScreenLayouts
## LAYOUT DE CADA TELA (level6, Onda 6) — "COMO a tela é".
##
## O mapa (mapa6 / RunManager) diz QUE telas existem, em que ordem/ramos e o
## que nasce em cada zona; aqui mora a FORMA da tela: tipo, comprimento das
## passagens, plataformas em 2–4 alturas, perigos do Éon, segredos (alguns só
## com PULO DUPLO), objetivo de cada zona e se a fenda de saída fica no ALTO.
## Tudo determinístico pelo NÓ (RunManager.node_rng: duas trilhas da mesma
## camada têm cara diferente).
##
## Layout por TIPO DE NÓ (RunManager.node_kind()):
##   arrival     → chegada   · arena baixa → passagem com 1 perigo do Éon + saliência
##                             de pulo duplo → arena alta
##   combat      → por camada: travessia (perigos + TOTEM) · fuga (a escuridão
##                             persegue) · segredo (começa antes; baú na torre)
##   hazard      → perigo    · passagem aberta e passagem longa com 3 perigos do Éon
##                             em ritmo; guarda do Éon nas duas arenas
##   platform    → escalada  · torre no começo, ESCALADA sobre chão perigoso (pedras
##                             vivas do Éon), arenas altas, voadores; saída no ALTO
##   sanctuary   → santuário · calmo, sem perigo; ALTAR de repouso; torre de luz;
##                             proteger a luz do Adormecido
##   challenge   → arena     · fechada e pesada, sem perigo gratuito; TOTEM na 2ª zona
##   secret      → sala secreta · a CÂMARA lá em cima só se alcança com PULO DUPLO
##                             (porta selada embaixo): dois baús secretos
##   trial → desafio (duelo limpo) · antechamber → antessala (corredor denso de
##   perigos + guarda) · center → centro (cacos caindo) · rei/arconte/mente: limpas.
## Sem mapa (node_kind ausente), o tipo vem do offset no Éon (tabela antiga).
##
## Coordenadas: plataformas de ZONA em dx a partir do centro da zona (±440);
## perigos/plataformas de PASSAGEM em px a partir do início da passagem (0..L).
## Alturas: Y1..Y4 (centro da plataforma). Pulo simples sobe ~77 px; cada
## degrau sobe 56 (folga de 20). Rota no CHÃO sempre existe (o bot não pula).

# Alturas (y do CENTRO da plataforma; o topo fica 6 px acima). Pés no chão = 310.
const Y1 := 252.0    # do chão, um pulo
const Y2 := 196.0    # de Y1
const Y3 := 140.0    # de Y2
const Y4 := 84.0     # de Y3
## Saliência de PULO DUPLO: 116 px acima do chão, longe de qualquer degrau
## (pulo simples sobe ~77; o duplo, ~150). Nunca obrigatória.
const YDJ := 200.0

const PASS_SHORT := 560.0    # passagem padrão (passo de zona antigo = 1500)
const PASS_LONG := 900.0     # travessia/perigo/fuga
const PASS_ZERO := 870.0     # passagem 0 aberta: a Sophia nasce em x = -600
const PASS_NPC := 1000.0     # passagem com encontro (Estela + NPC + Selos separados)

# --- arenas (plataformas da zona: [dx, y, largura]) ---------------------------
const ARENAS := {
	"baixa": [[-250, Y1, 140], [260, Y1, 140]],
	"tres_alturas": [[-330, Y1, 130], [-220, Y2, 120], [-110, Y3, 110], [300, Y1, 130], [395, Y2, 90]],
	"ponte": [[-330, Y1, 120], [-225, Y2, 110], [0, Y2, 210], [225, Y2, 110], [330, Y1, 120]],
	"torres": [[-300, Y1, 120], [-215, Y2, 100], [-300, Y3, 110], [300, Y1, 120], [215, Y2, 100], [300, Y3, 110]],
	"degraus": [[-170, Y1, 120], [-60, Y2, 110], [50, Y3, 120], [160, Y2, 110], [270, Y1, 120]],
	"bordas": [[-360, Y1, 120], [-270, Y2, 100], [360, Y1, 120], [270, Y2, 100]],
}

# --- perigo por Éon ------------------------------------------------------------
# 0 Torpor · 1 Fome · 2 Corrente · 3 Silêncio · 4 Espelho · 5 Praga · 6 Coroa · 7 Centro
## Perigo das PASSAGENS (travessia): névoa que lentifica · boca no chão · pêndulo
## · badalo mudo (pêndulo do Silêncio) · feixe do reflexo · casulo de esporos ·
## guilhotina da guarda · cacos caindo.
const EON_HAZARD := ["mist", "maw", "pendulum", "bell", "beam", "spores", "guillotine", "shards"]
## Perigo de CHÃO da escalada (por cima é seguro): nada que corte as plataformas.
const EON_FLOOR := ["mist", "maw", "shackles", "spears", "beam", "spores", "spears", "spears"]
## Guarda da ARENA (antessala/perigo/Centro). Silêncio = campo que anula magia;
## Espelho = as plataformas da arena alternam com o reflexo.
const EON_GUARD := ["mist", "maw", "pendulum", "silence", "mirror", "spores", "spears", "shards"]
## Plataforma "viva" do Éon (substitui degraus da escalada): afunda (Torpor) ou
## alterna com o reflexo (Espelho). "" = plataforma comum.
const EON_LIVE_PLATFORM := ["sinking", "", "", "", "mirror", "", "", ""]


## Plano de layout da tela. `n_zones` = zonas do plano de waves (RunManager).
## Devolve um Dictionary:
##   kind: String · spawn_x: float (NAN = padrão da cena) · exit_top: bool
##   gaps: Array[float] (comprimento da passagem ANTES da zona i; i ≥ 1)
##   zones: Array[{arena: String, plats: Array, guard: Array, objective: String}]
##   passages: Array[{items: Array}] (passagem i = antes da zona i; a 0 vai de
##     WALL_LEFT até a zona 0). Item = {t: tipo, x: px na passagem, ...}
static func plan(screen: int, n_zones: int) -> Dictionary:
	var out := {
		"kind": "arena", "spawn_x": NAN, "exit_top": false,
		"gaps": [], "zones": [], "passages": [],
	}
	var n := maxi(1, n_zones)
	if not RunManager.run_active:
		_fill_default(out, n)
		return out
	if layout_kind(screen) == "chefe":
		out.kind = "chefe"
		_fill_default(out, n)
		return out
	var eon := RunManager.eon_index(screen)        # 0..6 Éons · 7 Centro
	var off := RunManager.eon_offset(screen)       # camada no Éon; -1 fora
	var kind := layout_kind(screen)
	var hz: String = EON_HAZARD[clampi(eon, 0, EON_HAZARD.size() - 1)]
	var floor_hz: String = EON_FLOOR[clampi(eon, 0, EON_FLOOR.size() - 1)]
	var guard: String = EON_GUARD[clampi(eon, 0, EON_GUARD.size() - 1)]
	var live: String = EON_LIVE_PLATFORM[clampi(eon, 0, EON_LIVE_PLATFORM.size() - 1)]
	var r := _rng(screen, 61)
	var pick := r.randi()                          # variação por nó
	for i in n:
		out.passages.append({"items": []})
		out.zones.append({"arena": "baixa", "plats": [], "guard": [], "objective": "ondas"})
		if i >= 1:
			out.gaps.append(PASS_SHORT)
	var arenas := ARENAS.keys()
	out.kind = kind
	match kind:
		"chegada":
			_set_arena(out, 0, "baixa")
			for i in range(1, n):
				_set_arena(out, i, ["tres_alturas", "ponte"][pick % 2])
				out.gaps[i - 1] = 700.0
				_add(out, i, {"t": hz, "x": 230.0})
				# Saliência de pulo duplo com baú (sem degrau por perto).
				_add(out, i, {"t": "dj_cache", "x": 480.0})
		"travessia":
			for i in n:
				_set_arena(out, i, arenas[(pick + i * 2) % arenas.size()])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": hz, "x": 150.0})
					_add(out, i, {"t": hz, "x": 720.0})
			if n >= 2:
				out.zones[1].objective = "totem"
		"perigo":
			# A passagem perigosa: o CHÃO é o inimigo (o plano já vem mais leve).
			out.spawn_x = -600.0
			_add(out, 0, {"t": hz, "x": 400.0})
			for i in n:
				_set_arena(out, i, ["baixa", "degraus", "bordas"][(pick + i) % 3])
				if i == n - 1:
					_guard(out, i, guard)      # guarda só na arena final (bot r1: +60 de dano com as duas)
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": hz, "x": 130.0})
					_add(out, i, {"t": floor_hz, "x": 450.0})
					_add(out, i, {"t": hz, "x": 770.0})
		"escalada":
			# Altura de verdade: torre logo no começo, escalada sobre chão perigoso,
			# arenas de 3 alturas (voadores no alto) e a fenda no TOPO.
			out.spawn_x = -600.0
			out.exit_top = true
			var npc := npc_on_screen(screen)
			if npc:
				# Tela de encontro (Soter/Velkar): a escalada vai para a passagem 0 e a
				# passagem do encontro fica CALMA (a conversa não divide espaço com perigo).
				_add(out, 0, {"t": "climb", "x": 60.0, "hz": floor_hz, "live": live})
			else:
				_add(out, 0, {"t": "tower_cache", "x": 330.0})
			for i in n:
				_set_arena(out, i, ["torres", "tres_alturas", "degraus"][(pick + i) % 3])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					if not npc:
						_add(out, i, {"t": "climb", "x": 90.0, "hz": floor_hz, "live": live})
		"segredo":
			out.spawn_x = -600.0
			# Passagem 0 aberta: um baú no alto de uma torre logo no começo
			# (quem olha pra cima acha) e o pulo duplo pra uma 2ª saliência.
			_add(out, 0, {"t": "tower_cache", "x": 330.0})
			_add(out, 0, {"t": hz, "x": 640.0})
			for i in n:
				_set_arena(out, i, ["ponte", "torres", "tres_alturas"][(pick + i) % 3])
				if i >= 1:
					out.gaps[i - 1] = 760.0
					_add(out, i, {"t": "dj_cache", "x": 500.0})
			out.zones[n - 1].objective = "totem" if n >= 2 else "ondas"
		"oculta":
			# mapa7 (decisão do chefe, 19/10): a CÂMARA OCULTA, o segredo de antes
			# do Soter. Nada de pulo duplo aqui (nenhum cadeado que não abre): o
			# tesouro fica no alto de torres de um pulo por degrau, depois de um
			# perigo opcional no chão. Mesmo prêmio da sala secreta (EonMap.REWARDS).
			out.spawn_x = -600.0
			_add(out, 0, {"t": "tower_cache", "x": 330.0})
			for i in n:
				_set_arena(out, i, ["torres", "tres_alturas", "ponte"][(pick + i) % 3])
				if i >= 1:
					out.gaps[i - 1] = 760.0
					_add(out, i, {"t": hz, "x": 200.0})
					_add(out, i, {"t": "tower_cache", "x": 480.0})
		"secreta":
			# A SALA SECRETA: a câmara fica lá em cima; só se entra com PULO DUPLO
			# (saliência a 116 px do chão → câmara em Y3). Embaixo, a porta selada.
			for i in n:
				_set_arena(out, i, ["ponte", "torres"][(pick + i) % 2])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": "vault", "x": 480.0})
		"desafio":
			_set_arena(out, 0, "bordas")
		"fuga":
			for i in n:
				_set_arena(out, i, arenas[(pick * 3 + i) % arenas.size()])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": "tide", "x": 0.0})
					_add(out, i, {"t": hz, "x": 700.0})
		"santuario":
			# Calmo: nada fere. Um ALTAR de repouso, uma torre de luz e a luz a proteger.
			for i in n:
				_set_arena(out, i, ["baixa", "ponte", "degraus"][(pick + i) % 3])
				if i >= 1:
					out.gaps[i - 1] = 760.0
					_add(out, i, {"t": "altar", "x": 160.0})
					_add(out, i, {"t": "tower_cache", "x": 520.0})
			if n >= 2:
				out.zones[1].objective = "proteger"
		"arena":
			# Arena pesada (opcional): fechada, sem perigo de cenário; totem na 2ª zona.
			for i in n:
				_set_arena(out, i, ["ponte", "bordas", "tres_alturas"][(pick + i) % 3])
			if n >= 2:
				out.zones[1].objective = "totem"
		"antessala":
			out.spawn_x = -600.0
			# O corredor: três perigos do Éon em ritmo, um degrau alto pra respirar.
			_add(out, 0, {"t": hz, "x": 230.0})
			_add(out, 0, {"t": "perch", "x": 420.0})
			_add(out, 0, {"t": hz, "x": 610.0})
			_set_arena(out, 0, "tres_alturas")
			_guard(out, 0, guard)
		"centro":
			_set_arena(out, 0, ["ponte", "degraus", "torres"][screen % 3])
			_guard(out, 0, "shards")
		_:
			_fill_default(out, n)
	# ENCONTRO (Soter/Velkar) na passagem 1: Estela (descanso − 200), o NPC (no
	# descanso) e os Selos (descanso + 300) precisam de espaço — a passagem
	# cresce para ≥ 1000 px (a tela 17 tinha os três empilhados).
	if npc_on_screen(screen) and out.gaps.size() >= 1:
		out.gaps[0] = maxf(float(out.gaps[0]), PASS_NPC)
	# Silêncio: toda arena tem um campo que anula magia (num lado ou no meio) —
	# menos no santuário e na Arena (sem regra de cenário gratuita).
	if eon == 3 and off != 8 and not (kind in ["santuario", "arena"]):
		for i in out.zones.size():
			var has_field := false
			for g in out.zones[i].guard:
				has_field = has_field or String(g.t) == "silence"
			if not has_field:
				out.zones[i].guard.append({"t": "silence", "dx": [-200.0, 0.0, 200.0][(screen + i) % 3], "w": 150.0})
	# Variação fina determinística: espelha a arena em metade das telas.
	if r.randf() < 0.5:
		for z in out.zones:
			var mir: Array = []
			for p in z.plats:
				mir.append([-float(p[0]), p[1], p[2]])
			z.plats = mir
	return out


## A tela tem ENCONTRO da história (Soter nos Éons 1/3/5 camada 6; Velkar no
## Éon 6 camada 5)? Mesma regra do Level._spawn_extras. O NPC fica no descanso
## do meio (passagem 1).
static func npc_on_screen(screen: int) -> bool:
	if not RunManager.run_active:
		return false
	var eon := RunManager.eon_index(screen)
	var off := RunManager.eon_offset(screen)
	return (off == 6 and eon in [1, 3, 5]) or (off == 5 and eon == 6)


## Tipo de LAYOUT da tela (nome do level6) a partir do tipo do nó do mapa.
static func layout_kind(screen: int) -> String:
	if not RunManager.run_active:
		return "arena"
	var nk := ""
	if RunManager.has_method("node_kind"):
		nk = String(RunManager.call("node_kind", screen))
	else:
		nk = RunManager.screen_role(screen)
	var layer := RunManager.eon_offset(screen)
	match nk:
		"king", "archon", "final":
			return "chefe"
		"center":
			return "centro"
		"arrival":
			return "chegada"
		"trial":
			return "desafio"
		"antechamber":
			return "antessala"
		"hazard":
			return "perigo"
		"platform":
			return "escalada"
		"sanctuary":
			return "santuario"
		"challenge":
			return "arena"
		"secret":
			return "secreta"
		"hidden":
			return "oculta"            # mapa7: segredo sem pulo duplo (antes do Soter)
		"combat", "travel":
			# Travessia comum: a forma muda com a camada (o mapa do meio = o
			# caminho do bot; antes era sempre o mesmo corredor).
			match layer:
				2, 5: return "fuga"
				3: return "segredo"
			return "travessia"
	return "travessia"


## RNG do layout: por NÓ quando o mapa existe (trilhas diferentes, caras
## diferentes); senão por tela.
static func _rng(screen: int, salt: int) -> RandomNumberGenerator:
	if RunManager.has_method("node_rng"):
		return RunManager.call("node_rng", salt, screen)
	return RunManager.screen_rng(screen, salt)


static func _fill_default(out: Dictionary, n: int) -> void:
	out.passages.clear()
	out.zones.clear()
	out.gaps.clear()
	for i in n:
		out.passages.append({"items": []})
		out.zones.append({"arena": "", "plats": [], "guard": [], "objective": "ondas"})
		if i >= 1:
			out.gaps.append(PASS_SHORT)


static func _set_arena(out: Dictionary, i: int, arena: String) -> void:
	if i < 0 or i >= out.zones.size():
		return
	out.zones[i].arena = arena
	var plats: Array = []
	for p in ARENAS.get(arena, []):
		plats.append([float(p[0]), float(p[1]), float(p[2])])
	out.zones[i].plats = plats


static func _add(out: Dictionary, passage: int, item: Dictionary) -> void:
	if passage >= 0 and passage < out.passages.size():
		out.passages[passage].items.append(item)


## Guarda da arena: dois perigos do Éon nas laterais da zona (longe dos spawns
## do meio), que ferem os inimigos também — dá para atraí-los.
static func _guard(out: Dictionary, i: int, kind: String) -> void:
	if i < 0 or i >= out.zones.size():
		return
	match kind:
		"shards":
			out.zones[i].guard.append({"t": "shards", "dx": 0.0, "w": 760.0})
		"silence":
			out.zones[i].guard.append({"t": "silence", "dx": 0.0, "w": 160.0})
		"mirror":
			out.zones[i].guard.append({"t": "mirror_set", "dx": 0.0})
		_:
			out.zones[i].guard.append({"t": kind, "dx": -250.0})
			out.zones[i].guard.append({"t": kind, "dx": 250.0})
