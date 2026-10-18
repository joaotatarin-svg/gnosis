# Pedidos para inimigos6 (de: arte / dir2/arte-gpt)

## Rei: orbe solto ("a máscara não parece colada")
`enemy.gd` `_apply_illustrated_art()` cria `_orb` (Sprite2D do orbe-olho da pintura ANTIGA) que flutua por
conta própria (`_process`: seno em x/y e giro) ao lado do Rei. Com os quadros desenhados o Rei já traz o
orbe PINTADO nos quadros de preparação/golpe/triunfo — o sprite solto sobra e não acompanha o corpo.
Pedido: não criar o `_orb` (ou escondê-lo) quando `visual.has_boss_frames()`; o brilho do telegrafo do orbe
fica por conta do contorno do CharacterArt.
## Geometria por quadro para hitbox/hurtbox (PLAYTEST 2: "o cajado atravessa") — de: arte
API pública no `CharacterArt` (branch dir2/arte-gpt): `visual.frame_geometry(global := false) -> Dictionary`,
medida offline na SILHUETA de cada quadro desenhado (tools/anim/geometry.py) e levada pelo mesmo transform do
corpo (âncora, escala, tranco, flip). Vale para a Sophia, chefes, criaturas, bots e NPCs com quadros.
- `body: Rect2` — caixa do corpo (sem cajado/arma fina, fios e trapos soltos; desce até os pés) → HURTBOX.
- `body_poly: PackedVector2Array` — contorno convexo do corpo (≤ 10 pontos), se quiserem `ConvexPolygonShape2D`.
- `staff: PackedVector2Array [cabo, ponta]` e `tip: Vector2` — eixo VISÍVEL do cajado da Sophia por quadro →
  HITBOX do golpe (ex.: `SegmentShape2D`/cápsula ao longo do eixo, raio ~4 px de mundo); `staff_estimated: bool`
  quando o cajado cruza o corpo (eixo estimado da ponta).
- Coordenadas LOCAIS do nó do visual (ou de mundo com `global=true`); vazio `{}` se o personagem não tem quadros.
- O quadro é escolhido no `_draw`: leia no `_physics_process` do mesmo quadro de jogo (no máx. 1 quadro de atraso).
Prova visual: `C:\gnosis-wt\_caps\arte-gpt\gifs\geometria_quadros.png` (AnimQA `-- geo_board`).