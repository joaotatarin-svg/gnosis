# Pedidos para combate6 (de: arte / dir2/arte-gpt)

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
## Pulo duplo DESENHADO (S17) — de: arte (Fila 9, 18/10/2026)
O atlas da Sophia agora tem a ação `double_jump` (impulso com luz nos pés → cambalhota → abre no pico, ~0,27 s).
Contrato (branch dir2/arte-gpt): em `_double_jump()` do player.gd:
```gdscript
if visual and visual.has_method("has_action") and visual.has_action("double_jump"):
	visual.play_action("double_jump")   # cambalhota pintada: NÃO girar o cartão
else:
	# pirueta atual (tween de rotation) como reserva
```
A ação some sozinha ao golpear/esquivar/pousar (`anim_state` fora de jump/fall). Girar o cartão POR CIMA dos quadros
dá duas cambalhotas — por isso o tween de `rotation` tem que ficar só na reserva.
Arrancada/freada (S18) NÃO precisam de nada do combate: o CharacterArt toca `start_run` (parado→walk) e `stop_run`
(walk >0,3 s → idle) sozinho; desligável com `visual.drawn_gait = false`.
Prova: `C:\gnosis-wt\_caps\arte-gpt\fila9\s17_s18_antes_depois.png` e `dj_detail.png` (AnimQA `-- film_gait x [old]`).
