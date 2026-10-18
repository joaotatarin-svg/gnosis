extends RefCounted
class_name BossTuning
## Números das LUTAS DE CHEFE (Onda 6, chefes6). A vida do chefe não é mais um
## número solto do Bestiário: é "quantos golpes um jogador médio precisa dar"
## × "quanto vale um golpe médio da Sophia naquela tela". Assim, quando o
## combate6 mexe no dano da Sophia (tabela de golpes em GameContent), a vida
## dos chefes acompanha sozinha — e a meta de 25–40 golpes continua valendo.
## Determinístico por tela (mesma tela = mesma vida), como o resto do balance.

## Golpes-alvo por chefe (jogador médio, sem magia). Sobe ao longo do run.
const TARGET_HITS := {
	"rei": 36,                 # tutorial: ~1:15 de luta
	"arconte_sono": 28,
	"arconte_fome": 40,
	"arconte_corrente": 38,
	"arconte_silencio": 34,
	"arconte_espelho": 42,
	"arconte_praga": 38,
	"arconte_coroa": 48,
	"rei_final": 34,           # batalha dupla: cada forma (e elas se refazem)
	"colosso": 42,
}

## Nível de arma ESPERADO ao chegar em cada chefe (economia da Onda 6 — o
## progressao6 pode publicar `Progression.expected_weapon_level(tela)`; se
## existir, ele manda).
const EXPECTED_WL := {1: 1, 10: 2, 19: 2, 28: 3, 37: 3, 46: 4, 55: 4, 64: 5, 68: 5}

## Bônus de dano por nível de arma (player.gd: `(weapon_level - 1) * 6`). Se o
## combate6 expuser `Player.WEAPON_DMG_STEP`, vale o dele.
const WEAPON_STEP_FALLBACK := 6.0

## Limiares de fase (fração da vida): fase 2 a 66 %, fase 3 a 33 %.
const PHASE_MARKS := [0.66, 0.33]


static func expected_weapon_level(screen: int) -> int:
	if Progression.has_method("expected_weapon_level"):
		return int(Progression.call("expected_weapon_level", screen))
	var best := 1
	for s in EXPECTED_WL.keys():
		if screen >= int(s):
			best = maxi(best, int(EXPECTED_WL[s]))
	return best


## Dano médio de UM golpe da Sophia no chão com a arma `wl` (média simples dos
## golpes liberados; golpe de vários acertos conta por acerto).
static func expected_hit(wl: int) -> float:
	var ch: CharacterData = GameContent.characters[0] if not GameContent.characters.is_empty() else null
	var step: float = WEAPON_STEP_FALLBACK
	var pscript = load("res://scripts/entities/player.gd")
	if pscript is Script:
		var consts: Dictionary = (pscript as Script).get_script_constant_map()
		if consts.has("WEAPON_DMG_STEP"):
			step = float(consts["WEAPON_DMG_STEP"])
	if ch == null:
		return 16.0 + step * float(wl - 1)
	var tot := 0.0
	var n := 0
	for mv in ch.combos:
		var c: ComboData = mv
		if c.air or c.required_weapon_level > wl:
			continue
		tot += float(c.damage)
		n += 1
	var base: float = tot / float(maxi(1, n))
	return base + step * float(wl - 1)


## Vida do chefe nesta tela (já com a dificuldade).
static func boss_health(type_id: String, screen: int) -> int:
	var hits: int = int(TARGET_HITS.get(type_id, 30))
	var wl := expected_weapon_level(screen)
	var hp := float(hits) * expected_hit(wl) * GameManager.difficulty_multiplier()
	return maxi(60, int(round(hp)))


## Dano dos golpes do chefe: o mesmo multiplicador por tela dos inimigos.
static func damage_mult(screen: int) -> float:
	return Bestiary.damage_multiplier(screen) * GameManager.difficulty_multiplier()
