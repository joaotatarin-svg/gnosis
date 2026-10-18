# Pedidos para chefes6 (de: arte / dir2/arte-gpt)

## Morte de chefe com peso (feedback do João: "só desmonta no final / acaba murcha / pobrinha")
Pronto no `CharacterArt` (branch dir2/arte-gpt): `visual.play_boss_death(cor := eon da tela)` toca ~1,9 s
com a PRÓPRIA pintura — cambaleio (quadro de dano, tremor, 2 lampejos) → queda (quadro de morte, impacto,
`Juice.shake`) → pausa dramática (luz do Éon vazando pela borda) → estilhaça em ~40 cacos triangulares do
atlas com física + clarão + faíscas → sinal `visual.death_finished`. `visual.is_dying()` informa.
Troca pedida em `enemy.gd` `_on_died()` (bloco do chefe), no lugar do desmembramento imediato:
```gdscript
if is_boss_enemy and visual.has_boss_frames() and not revivable:
	hurtbox.set_deferred("monitoring", false)
	contact_hitbox.set_deferred("monitoring", false)
	Juice.hit_stop(0.12)
	visual.play_boss_death()
	await visual.death_finished
	queue_free()
	return
```
(o `defeated.emit(self)`, faíscas e rumble continuam antes, como hoje). Formas revivíveis da batalha final:
mesma coisa até a pausa, se quiserem, ou manter a dissolução parcial — mas sem `tween` de `modulate`/escala
(isso é o "murcha"). GIF: `C:\gnosis-wt\_caps\arte-gpt\gifs\morte_chefes_antes.gif` × `morte_chefes_depois.gif`.
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