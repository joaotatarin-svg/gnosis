# Pedidos do Chefes6 (28/10)

## Para o Polimento7 (hurtbox genérica por frame_geometry)
- O Rei (e o Rei-Mentira da final) agora têm uma caixa PRÓPRIA do corpo desenhado: `BossBodyBox`
  (`scripts/entities/bosses/boss_body_box.gd`, nó filho `BodyBox` do Enemy, 6 faixas por quadro). Quando ela liga,
  ela DESLIGA a `Hurtbox/HurtShape` genérica (`disabled = true`) para não contar 2 acertos por golpe (R4).
- Pedido: no `_fit_hurtbox`/frame_geometry genérico, **pule inimigos com filho `BodyBox`** (ou, se a sua versão
  cobrir o manto por faixas/polígono com o mesmo resultado, me avise que eu removo a BodyBox e volto para a genérica).
  Não religue a HurtShape desses inimigos.
- A tabela de faixas sai de `tools/chefes6/body_slabs.py <char> <saida.gd>` e pode servir a qualquer chefe por quadros.
- Medida/prova: `tools/chefes6/body_cover.py` (todos os quadros, sem Godot) e `tools/chefes6/ReiProbe.tscn`.

## Para a Progressão (curva de melhorias) — 28/10
- A vida dos chefes sai de `BossTuning.boss_health` = golpes-alvo × dano médio da arma ESPERADA na tela
  (`EXPECTED_WL`: 1@1, 2@10, 3@28, 4@46, 5@64). No re-teste 3.1 (QA7) o run chegou com arma 3 na 10–15, 4 na 28 e
  5 na 46 — um nível ACIMA — e com 5–7 mil faíscas sobrando. Se a sua curva nova mudar quando cada nível chega,
  publique `Progression.expected_weapon_level(tela)` (o BossTuning já usa se existir) — aí a vida acompanha sozinha.
- O que fiz do meu lado (pelo padrão, não pela vida): "guarda alta" nos chefes do fim (golpe no neutro/no golpe dele
  vale menos; as janelas de punição seguem iguais). Não mexi na economia.

## Para o dono do tools/shot.gd (Estab/Técnico) — 28/10
- `hurt` (tira 55 % dos chefes na metade dos quadros) acerta o Arconte ENCENADO antes do gatilho (zona inativa).
  Agora o chefe encenado é intocável (Chefes6), então nesses casos o `hurt` não força a fase 2. Pedido: aplicar o
  `hurt` só quando `ativa=true` (zona trancada), ou andar a Sophia até o gatilho antes.
