# Onda 7 — POLIMENTO DE COMBATE (branch `dir7/polimento7`, base `origin/integracao/onda1` 4cfd64c)

Tarefas: (1) hurtbox dos inimigos ≈ 80 % do corpo DESENHADO por quadro (`visual.frame_geometry().body`);
(2) caixa do cajado da Sophia via `frame_geometry().staff/tip` (API oficial da arte) no lugar do StaffReach próprio;
(3) 2º golpe leve que bate atrás do pé; (4) recalibrar `Player.FLASH_ADD` (~0,45) quando o `painted_flex` for corrigido
no `dir2/arte-gpt`; (5) FeelProbe e HitboxProbe no `validate.ps1`.

## Medição ANTES (HitboxProbe, 18/10, base 4cfd64c, nível de arma 3)
Log: `C:\gnosis-wt\_caps\polimento7\antes\hitbox_probe.log`
- caixa NOVA (StaffReach): esperados 122, reais 132, certos 121, **atravessa 1** (m_LLL × larva a 48 px), **apelão 11**.
- contra o CORPO DESENHADO: o cajado encostou no desenho 136 vezes, **sem dano em 7 (5 %)**.
- hurtbox × desenho (largura): larva 21 × 39 px, servo 28 × 56, canino 25 × 52, bruto 37 × 64.
- contato: Sophia colada num bruto 1,5 s → 120 → 120 (ok). `QA PASS (atravessa 1 %, apelão 8 %)`.

## Coordenação
- chefes6 já corrigiu o `set_deferred` do `stagger()` (commit 50a89eb em `dir6/chefes6`): NÃO refeito aqui.
- Shader `painted_flex` ainda com `COLOR = c * COLOR` no `origin/dir2/arte-gpt` (7163c12): tarefa (4) aguardando.

## BILHETE PARA O SUCESSOR (18/10, pausa pedida pelo chefe)
- Estado: só importação + medição de base. Nenhum código alterado ainda.
- Próximo passo: (1) em `enemy._fit_hurtbox()` trocar a leitura de `_boss_db.meta/_shown_key` por
  `visual.frame_geometry().body` (local do Visual → `visual.transform * rect`), largura ≈ 80 % do corpo; ver se as
  criaturas comuns têm quadros (`has_boss_frames()`); (2) `StaffReach.current()` passar a usar
  `frame_geometry().staff/tip` mantendo `rect/impact/hand/prev` que o player e a sonda leem.
- Arquivos-chave: `scripts/entities/enemy.gd` (`_fit_hurtbox`, ~l. 2282), `scripts/combat/staff_reach.gd`,
  `scripts/entities/player.gd` (`_update_staff_hitbox`, `FLASH_ADD` l. 33), `tools/combate/hitbox_probe.gd`,
  `scripts/fx/character_art.gd` (`frame_geometry`, só leitura).
- Armadilha: `frame_geometry()` é preenchida no `_draw` (1 quadro de atraso); coordenadas locais do nó Visual.
