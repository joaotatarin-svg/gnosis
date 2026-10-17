# Pedidos do BALANCE (Onda 2, 17/10/2026)

Dados e método em `docs/onda2/BALANCE.md`. Rodadas em `/home/user/caps/balance/runs/`.
O Balance não edita o jogo: cada item diz arquivo, linha (base `integracao/onda1`) e o que mudar.

## 1. COMBATE — BLOQUEANTE: a batalha final pode travar (soft-lock)
`scripts/entities/enemy.gd`, `_on_hit_received`, linhas 777–799. O golpe que mata chama
`health.take_damage()` → `_on_died()` põe `estate = DEAD` → mas a função segue e, na linha 798,
faz `estate = EState.HURT` (só escapa se o chefe estiver no WINDUP). O inimigo fica com **vida 0 e
estado HURT**. Para inimigo comum é quase invisível (o corpo some pelo tween), mas nas **duas formas
da tela 68** (`revivable`): `FinalBattle` registra a queda; aos 14 s chama `revive()`, que exige
`estate == DEAD` e não faz nada; a forma fica de pé com vida 0, **volta a atacar** e nunca mais
morre (`take_damage` sai cedo com vida <= 0). Se a outra forma não cair dentro de 14 s, a luta
**não tem como ser vencida**.
- Prova mínima: `godot --headless --audio-driver Dummy --fixed-fps 60 --path . -s tools/balance/repro_revive.gd`
  → `depois do golpe: hp=0 estado=HURT` e `depois de revive(0.45): hp=0 estado=HURT`.
- Visto no bot: rodada `r8_teto` ficou presa na tela 68 (rei_final hp=0 RECOVER, colosso hp=0 CHASE).
- Conserto sugerido: logo depois de `health.take_damage(damage)` (e dos efeitos), `if estate == EState.DEAD: return`
  antes de mexer em `estate`. Vale também para o `_enter_phase2()` (não deve rodar com vida 0).

## 2. ENCENAÇÃO — tela 68 não é determinística
`scripts/levels/final_battle.gd:100` usa `randi() % 7` (sorteio GLOBAL). O mesmo sorteio global é
consumido pelo `Audio` (variação de pitch) em quantidades que dependem do relógio real
(`gib.gd:105`, `audio_manager.gd:227` usam `Time.get_ticks_msec`). Resultado: duas rodadas
idênticas do bot dão 971 × 1255 de dano na tela 68 (as outras 67 telas saem idênticas).
Conserto: `var _rng := RandomNumberGenerator.new()` com `_rng.seed = hash("final_%d" % RunManager.MAX_SCREEN)`
em `start()` e `_rng.randi() % 7` na linha 100 (como `scenery.gd:108` já faz).
Observação: numa rodada isolada da tela 68 as formas apareceram em x = -43 e x = -206 (fora da
arena); vale conferir as paredes da tela 68.

## 3. TÉCNICO + UI-MENUS — economia de faíscas (proposta P1 e P2 do BALANCE)
Ver `docs/onda2/BALANCE.md` §Propostas. Resumo: `+20 de vida máx.` custa 60 sem limite
(`scripts/ui/upgrade_menu.gd:102`, `Progression.buy_max_health`) e a `Restauração` (cura cheia, 50)
pode ser comprada pela pausa no meio da luta (`upgrade_menu.gd:106`, `pause_menu.gd:74`). O run dá
~12 800 faíscas e a arma/magias custam ~1 300: sobram ~11 500 (≈ 230 curas cheias ou +3 800 de vida).

## 4. COMBATE — Belias (proposta P3)
`scripts/entities/enemy.gd:597-599` (poças da investida da Praga). Ver `docs/onda2/BALANCE.md`.

## 5. TÉCNICO / ENCENAÇÃO — antessala da Coroa (proposta P4)
`scripts/levels/level.gd:369-372` (quem vira Elite). Ver `docs/onda2/BALANCE.md`.
