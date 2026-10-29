# Pedidos do diretor de PROGRESSÃO — Onda 7 (dir6/progressao6)

Medição e motivo em `docs/onda2/PROGRESSAO6.md` §9. Os números abaixo foram TESTADOS com o
QA7Bot (3 sementes, run inteiro) num worktree de protótipo — não estão no meu branch, porque os
arquivos são de outros donos. Diff exato do protótipo: §9.3 do PROGRESSAO6.md.

## → inimigos (vfx7 / inimigos6) — `scripts/autoload/bestiary.gd` + `scripts/entities/enemy.gd`
1. **Pressão por Éon só nas criaturas** (Praga e Coroa estavam abaixo do Espelho):
   ```gdscript
   # bestiary.gd, antes de damage_multiplier
   const EON_PRESSURE := {5: 1.1, 6: 1.3}      # Praga +10%, Coroa +30% de dano
   func eon_pressure(screen: int) -> float:
   	return float(EON_PRESSURE.get(RunManager.eon_index(screen), 1.0))
   # enemy.gd _ready, logo depois de `var dmg_mult := ...`
   if not is_boss_enemy:
   	dmg_mult *= Bestiary.eon_pressure(GameManager.current_screen)
   ```
   Arcontes ficam de fora: já passam de 100 s (QA7 bug 2).
2. **Campeão (Desafio) mais curto**: em `enemy.gd` (bloco `if is_champion:`) vida `× 1.7 → × 1.35`
   e dano `× 1.15 → × 1.0`. O moveset de elite e o letreiro continuam: a dificuldade vem do
   repertório, não da barra de vida (§4).
3. **Ecos do Centro**: `bestiary.gd` (`echoes`) vida `0.3 → 0.55` e dano `0.6 → 0.85` do Arconte.
4. **Renda igual em todas as dificuldades** (Guardião §3, decisão da Progressão): em
   `enemy.gd` `_reward_mult = hp_mult` → `_reward_mult = Bestiary.screen_multiplier(GameManager.current_screen)`
   (sem `× difficulty_multiplier()`). Hoje o Difícil rende 1,5× e o Muito Difícil 2,2× com os
   mesmos preços: a loja inteira cabe e o Normal parece "pobre". Os preços e selos já seguram o
   ritmo; a dificuldade fica no combate.

## → mapa6 (run_manager.gd)
1. **Centro como clímax**: `zone_plan` do papel `"center"` ganha uma 3ª onda com os dois ecos
   JUNTOS e larvas ardentes na 2ª:
   `[[["larva", a, "larva"], ["larva_ardente", b, "larva_ardente"], [a, b]]]`.
2. (Já feito por mim, mudança mínima com aviso) `_grant_reward`: a recompensa de cada CAMADA paga
   uma vez por run (`Progression.claim_once("no:<éon>.<camada>")`); a cura do santuário continua.

## → level6 (inativo — mexi com autorização do chefe)
1. `level.gd`: `const WAVE_BREATH := 2.0` (era 0,8 s fixo entre ondas). Só a constante/uso.
2. `chest.gd`, `seal_puzzle.gd`, `sleeper.gd`: pagamento guardado por
   `Progression.claim_once("bau:<tela>" / "selo:<tela>" / "adormecido:<tela>")`. O Adormecido
   não conta mais 2× ao morrer e voltar.

## → ui (HUD)
1. R21: o HUD recua após `CALM_AFTER` = 4 s sem combate; com o respiro de 2 s entre ondas ele não
   chega a recuar. Sugestão: recuar as faíscas/arma já no fim de cada onda (sinal do Level) e
   voltar em 150 ms quando a onda nascer.
2. Mostrar as relíquias em uso (agora podem ser duas: `Progression.equipped_relics()`).

## → QA7 / balance
1. `QA7Bot._auto_shop` só compra arma e magias: as "faíscas sobrando" do fim do run são em parte
   artefato do bot. Para medir a loja inteira, usar `buy_health_upgrade`, `buy_mana_upgrade`,
   `buy_relic`, `buy_relic_slot`.
