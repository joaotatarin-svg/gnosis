# Onda 7 — Áudio7 (branch `dir7/audio7`, base `origin/integracao/onda1`)

## BILHETE PARA O SUCESSOR (atualizado a cada bloco)

**Estado:** PAUSA pedida pelo chefe logo após a VARREDURA. Nenhum som novo gerado ainda; nenhum código alterado.
Import do worktree feito (0 SCRIPT ERROR).

**Varredura (play_sfx/play_sfx_at/sfx/_tell_sound em scripts/**):**
- Nomes chamados que NÃO existem: só `chain` (boss_galila.gd:105) e `glass` (boss_astaphaios.gd:79,105).
  Ambos passam pelo `BossBrain.sfx()`, que só toca se o nome estiver no CATALOG → hoje mudos. Basta criar.
- O resto do conteúdo novo usa sons GENÉRICOS: perigos do level6 (`hit_heavy`, `tell_unblock`, `swing_heavy`,
  `land`, `cast_fail`, `enemy_hurt`, `chest_hit`, `portal_open`, `sleeper_wake`, `fog_swell`, `shard`), inimigos
  (só `tell_*`, `enemy_hurt`, `*_die`), chefes (só `boss_appear`/`boss_phase2` em toda fase/`boss_die`), mapa
  (`ui_move`/`ui_confirm`), loja (`shop_buy`).

**Ganchos por SINAL que o Áudio pode ligar sozinho (sem pedir a ninguém):**
- `Enemy.boss_dying(step 0..4)` → morte em 5 passos (impacto, cambaleio, colapso, pausa, estilhaço).
- `Achievements.unlocked(id)` → conquista. `Progression.double_jump_granted` → dom do Soter.
- `Progression.relics_changed` (cuidado: pode disparar no load), `Progression.boss_beaten`, `RunManager.node_entered`.
- `Player.riposte_window_opened` (contra-ataque), `BossHazard.struck`, `SummonTotem.destroyed`.

**Plano de API (no audio_manager, pra o dono ligar com UMA linha):**
- `Audio.move_sfx(id, kind, stage("wind"|"strike"), pos)` → resolve por id de golpe de chefe e cai no som
  do `kind` (inimigos: swing combo rush leap slam nova shot burst lob pillar fissure grab dive glide blink
  summon explode). Ponto de chamada: `Enemy._start_move`/`_strike_move` e `BossBrain._start`/`strike`.
- Golpes de chefe (id:kind): athoth orbes bocejo toque deslize cancao chuva · harmas punhos succao investida
  boca sopro salto · galila corrente estocada corte puxao queda prisao giro · yabel sopro asas pergaminhos
  mergulho grito laminas pisca · astaphaios estocada corte cacos guarda reflexos troca · belias bote mordida
  esporos enterrar nuvem · armupiel espadao varredura decreto investida corte_real coroacao · rei leque gesto
  raio mao aneis larvas teleporte · colosso punhos pisotear investida salto desabamento.
- `boss_phase3` (pedir ao chefes6: enemy.gd:1009 escolher por fase).

**Próximo passo:** síntese em `tools/audio_synth/onda7.py` (numpy, padrão de `tells.py`/`story.py`), entrar no
`build_sfx.py` com categorias de loudness; CATALOG; API; AudioQA; pedidos em `docs/pedidos/audio7.md`.

**Arquivos-chave:** `scripts/autoload/audio_manager.gd` (CATALOG l.119, `_on_sfx_event` l.1065, `_on_node_added`
l.898), `tools/audio_synth/{common,build_sfx,tells,story}.py`, `tools/audio_qa.gd`, `docs/AUDIO.md`.
