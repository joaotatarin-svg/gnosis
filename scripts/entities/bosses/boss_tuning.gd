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
	"rei": 32,                 # tutorial: ~1:15 de luta
	"arconte_sono": 26,
	"arconte_fome": 32,
	"arconte_corrente": 38,
	"arconte_silencio": 28,
	"arconte_espelho": 34,
	"arconte_praga": 26,
	"arconte_coroa": 48,
	"rei_final": 22,           # batalha dupla: cada forma (e elas se refazem)
	"colosso": 26,
}

## Nível de arma ESPERADO ao chegar em cada chefe (economia da Onda 6 — o
## progressao6 pode publicar `Progression.expected_weapon_level(tela)`; se
## existir, ele manda).
const EXPECTED_WL := {1: 1, 10: 2, 19: 2, 28: 3, 37: 3, 46: 4, 55: 4, 64: 5, 68: 5}


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
	if ch == null:
		return float(SophiaTuning.move_damage(18, wl))
	var tot := 0.0
	var n := 0
	for mv in ch.combos:
		var c: ComboData = mv
		if c.air or c.required_weapon_level > wl:
			continue
		# o dano REAL que o golpe dá (combate6: SophiaTuning, base × 0,65 × +17 %/nível)
		tot += float(SophiaTuning.move_damage(c.damage, wl))
		n += 1
	return tot / float(maxi(1, n))


## Vida do chefe nesta tela (já com a dificuldade).
static func boss_health(type_id: String, screen: int) -> int:
	var hits: int = int(TARGET_HITS.get(type_id, 30))
	var wl := expected_weapon_level(screen)
	var hp := float(hits) * expected_hit(wl) * GameManager.difficulty_multiplier()
	return maxi(60, int(round(hp)))


## Dano dos golpes do chefe: o mesmo multiplicador por tela dos inimigos.
static func damage_mult(screen: int) -> float:
	return Bestiary.damage_multiplier(screen) * GameManager.difficulty_multiplier()
