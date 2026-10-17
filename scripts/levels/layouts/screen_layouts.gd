extends RefCounted
class_name ScreenLayouts
## LAYOUT DE CADA TELA (level6, Onda 6) — "COMO a tela é".
##
## O mapa (mapa6 / RunManager) diz QUE telas existem e o que nasce em cada zona;
## aqui mora a FORMA da tela: tipo, comprimento das passagens, plataformas em
## 2–4 alturas, perigos do Éon, segredos (alguns só com PULO DUPLO), objetivo
## de cada zona e se a fenda de saída fica no ALTO. Tudo determinístico pela tela.
##
## Até o mapa6 entregar o tipo de tela, o tipo vem da posição no Éon (offset):
##   0 chegada   · arena baixa → passagem com 1 perigo (apresenta o Éon) → arena alta
##   1 travessia · passagens LONGAS com perigos; a 2ª zona tem um TOTEM que invoca
##   2 perigo    · escalada sobre chão perigoso (por cima é seguro, por baixo dói);
##                 proteger a luz do Adormecido; saída no ALTO
##   3 segredo   · começa ANTES (passagem 0 aberta): baú alto, pulo duplo, voadores
##   4 desafio   · arena do Campeão: duas alturas nas bordas, centro limpo (duelo justo)
##   5 fuga      · a escuridão persegue nas passagens (+ a regra do Éon, se houver)
##   6 santuário · calmo, sem perigo; torre de luz com segredo de pulo duplo
##   7 antessala · CORREDOR de perigos denso antes da arena (que tem guarda do Éon)
##   8 Arconte   · arena limpa (é dos chefes)
## Centro (65–67): cacos caindo; Rei (1) e Mente (68): limpas.
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
	var role := RunManager.screen_role(screen)
	if role in ["king", "archon", "final"]:
		out.kind = "chefe"
		_fill_default(out, n)
		return out
	var eon := RunManager.eon_index(screen)        # 0..6 Éons · 7 Centro
	var off := RunManager.eon_offset(screen)       # -1 fora dos Éons
	if role == "center":
		off = 9
	var hz: String = EON_HAZARD[clampi(eon, 0, EON_HAZARD.size() - 1)]
	var floor_hz: String = EON_FLOOR[clampi(eon, 0, EON_FLOOR.size() - 1)]
	var guard: String = EON_GUARD[clampi(eon, 0, EON_GUARD.size() - 1)]
	var live: String = EON_LIVE_PLATFORM[clampi(eon, 0, EON_LIVE_PLATFORM.size() - 1)]
	var r := RunManager.screen_rng(screen, 61)
	for i in n:
		out.passages.append({"items": []})
		out.zones.append({"arena": "baixa", "plats": [], "guard": [], "objective": "ondas"})
		if i >= 1:
			out.gaps.append(PASS_SHORT)
	var arenas := ARENAS.keys()
	match off:
		0:
			out.kind = "chegada"
			_set_arena(out, 0, "baixa")
			for i in range(1, n):
				_set_arena(out, i, ["tres_alturas", "ponte"][screen % 2])
				out.gaps[i - 1] = 700.0
				_add(out, i, {"t": hz, "x": 230.0})
				# Saliência de pulo duplo com baú (sem degrau por perto).
				_add(out, i, {"t": "dj_cache", "x": 560.0})
		1:
			out.kind = "travessia"
			for i in n:
				_set_arena(out, i, arenas[(screen + i * 2) % arenas.size()])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": hz, "x": 170.0})
					_add(out, i, {"t": hz, "x": 690.0})
			if n >= 2:
				out.zones[1].objective = "totem"
		2:
			out.kind = "perigo"
			out.exit_top = true
			for i in n:
				_set_arena(out, i, ["degraus", "torres"][(screen + i) % 2])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": "climb", "x": 90.0, "hz": floor_hz, "live": live})
			out.zones[n - 1].objective = "proteger"
			_guard(out, n - 1, guard)
		3:
			out.kind = "segredo"
			out.spawn_x = -600.0
			# Passagem 0 aberta: um baú no alto de uma torre logo no começo
			# (quem olha pra cima acha) e o pulo duplo pra uma 2ª saliência.
			_add(out, 0, {"t": "tower_cache", "x": 140.0})
			_add(out, 0, {"t": hz, "x": 470.0})
			for i in n:
				_set_arena(out, i, ["ponte", "torres", "tres_alturas"][(screen + i) % 3])
				if i >= 1:
					out.gaps[i - 1] = 760.0
					_add(out, i, {"t": "dj_cache", "x": 190.0})
			out.zones[n - 1].objective = "totem" if n >= 2 else "ondas"
		4:
			out.kind = "desafio"
			_set_arena(out, 0, "bordas")
		5:
			out.kind = "fuga"
			for i in n:
				_set_arena(out, i, arenas[(screen * 3 + i) % arenas.size()])
				if i >= 1:
					out.gaps[i - 1] = PASS_LONG
					_add(out, i, {"t": "tide", "x": 0.0})
					_add(out, i, {"t": hz, "x": 520.0})
		6:
			out.kind = "santuario"
			for i in n:
				_set_arena(out, i, ["baixa", "ponte", "degraus"][(screen + i) % 3])
				if i >= 1:
					out.gaps[i - 1] = 700.0
					# Torre de luz calma (um pulo por degrau) + saliência de pulo duplo.
					_add(out, i, {"t": "tower_cache", "x": 120.0, "calm": true})
					_add(out, i, {"t": "dj_cache", "x": 560.0})
			if n >= 2:
				out.zones[1].objective = "proteger"
		7:
			out.kind = "antessala"
			out.spawn_x = -600.0
			# O corredor: três perigos do Éon em ritmo, um degrau alto pra respirar.
			_add(out, 0, {"t": hz, "x": 230.0})
			_add(out, 0, {"t": "perch", "x": 420.0})
			_add(out, 0, {"t": hz, "x": 610.0})
			_set_arena(out, 0, "tres_alturas")
			_guard(out, 0, guard)
		9:
			out.kind = "centro"
			_set_arena(out, 0, ["ponte", "degraus", "torres"][screen % 3])
			_guard(out, 0, "shards")
		_:
			_fill_default(out, n)
	# Silêncio: toda arena tem um campo que anula magia (num lado ou no meio).
	if eon == 3 and off != 8:
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
