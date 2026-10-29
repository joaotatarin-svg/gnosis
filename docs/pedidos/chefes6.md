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
