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
# Pedidos do Inimigos6 (Onda 6)

## → Arte (GPT + integrador) — arte NOVA (o maior limite desta onda)
Folhas no padrão das criaturas (1536×1024, fundo magenta, olhando para a DIREITA, grade 2×3 ou 2×4;
estados idle · walk(4) · windup · attack · recover · hurt · dead). Uma criatura por folha:
1. **Espectro Mergulhador** (voador): verme-espírito alado, pálido azul-gelo, cauda de trapos.
   Poses: pairar (2 quadros de batida de asa), preparar mergulho (encolhido, olhando pra baixo),
   mergulho (corpo em diagonal, asas fechadas), pousado/atordoado no chão, rasante (horizontal, asas
   abertas), dor, morte.
2. **Vigia Alado** (voador): sentinela de manto dourado com 4 asas de penas e lança-olho; poses:
   pairar (2), mirar de cima (braço apontando 45° p/ baixo), lançar coluna (braços erguidos),
   rasante, dor, morte. HOJE usa a pintura do Sonâmbulo (= família de Athoth) graduada para âmbar.
3. **Fantasma do Vazio**: espectro violeta translúcido sem pés; aparecer (forma se juntando),
   garra, abraço (braços abertos), dor, morte. HOJE usa a pintura do Bibliotecário Mudo (≈ Yabel).
4. **Ceifador Cornudo**: humanoide de chifres com foice longa; ceifa larga, combo de 3, agarrão.
   HOJE usa o espadachim tingido.
5. **Acólito do Fogo-Fátuo** (só à distância): monge magro com lanterna de chama verde-água;
   rajada (lanterna para a frente), invocar fogo-fátuo, salto de recuo, dor, morte.
6. **Bots dos Éons** — TODOS são da família visual do Arconte do Éon (prova:
   `C:\gnosis-wt\_caps\inimigos6\arcontes_vs_bots.png`). Para o João, isso é "mini-chefe com a cara
   do chefe". Pedido: redesenhar os 7 com silhueta e paleta PRÓPRIAS (servos, menores, sem a
   assinatura do Arconte: sem boca no torso para o Glutão, sem capuz-pálpebra para o Sonâmbulo etc.).
   Até lá o código os deixa cinzentos e o Campeão com cor oposta (`enemy_grade.gdshader`).
7. **API**: `CharacterArt.body_rect() -> Rect2` (corpo do quadro na tela, sem arma/pano, em
   coordenadas locais do Visual). Hoje o `Enemy._fit_hurtbox()` lê `_boss_db.meta`,
   `_shown_key` e `_body_xform` (internos). E, se possível, `weapon_rect()` por quadro para a caixa
   do golpe seguir a arma desenhada.

## → Combate6
1. **Dano da Sophia** (contrato da vida nova dos comuns ≈ ×1,7): golpe leve ≈ 12 + **3** por nível
   da arma (hoje +6). Com +6 os comuns caem em 4–6 golpes; com +3, 4–8 (tanques 8–10).
2. **Voadores**: antes da arma nv. 3 não há golpe aéreo. Os voadores descem (mergulho com pouso de
   1 s, rasante na altura dela), mas um aéreo básico desde o nv. 1 (ou com o pulo duplo) deixaria
   a luta mais rica. Acerto no ar (golpe `air`/lançador) DERRUBA o voador.
3. Uso campos da Sophia (leitura/escrita mínima): `state` (ATTACK/HURT), `facing`, `root_timer`
   (o agarrão prende 0,8 s e zera ao ser interrompido), `_on_hit_received(dmg, pos, kb, unb, attacker)`.
   Se mudar essas assinaturas, me avise.

## → Chefes6
1. **Dano de contato DESLIGADO para todo Enemy** (inclusive chefes) — `_ready`/`revive`. Se algum
   kit precisar de contato, use a `AttackHitbox` com telegrafo.
2. **Hurtbox segue o quadro desenhado** também nos chefes por quadros (`_fit_hurtbox`, só quando
   `visual.has_boss_frames()`).
3. `_flash()` agora é ADITIVO (camada `EnemyFlashLayer`) para cor clara; o `_flash` da fase 2 continua igual.
4. Nada no caminho dos chefes foi alterado: com `moves` vazio o `Enemy` segue o `style`/`kit` antigos.
   O enum `EState` ganhou `GUARD` no FIM (números antigos iguais).

## → Level6
1. `Enemy.is_flyer()` existe (true para Espectro e Vigia Alado — pairam >40 px). Também
   `Bestiary.is_flyer(id)`. Voador pairando usa como referência o chão DA SOPHIA.
2. Os perigos chamam `apply_damage`/`apply_root`/`apply_slow` — mantidos (magia/perigo ignora a guarda).

## → VFX7
1. `Projectile.look` ∈ {"" (orbe antigo), "bolt", "wisp", "seed", "spike", "page"}; `homing` > 0 =
   teleguiado; `arc_gravity` > 0 = arco. O `_ready` chama `VfxLibrary.projectile_look(self, look, color)`
   SE o método existir; retorne algo verdadeiro para assumir o desenho (o `_draw` por código cala).
2. `HazardZone.pillar()` (anel de aviso → coluna) e as ondas `spike` também podem ganhar o seu brilho.

## → Narrativa / UI (bestiário)
1. Lore e entrada no Bestiário para **Espectro Mergulhador** (tier 2) e **Acólito do Fogo-Fátuo** (tier 1).
2. O card do Campeão (`Narrative.champion_card`) segue nomeando o bot — o corpo continua sendo o bot.

## → Estab5 (QA)
1. Incluir `res://tools/inimigos6/EnemyProbe.tscn` no `validate.ps1` (headless, `--fixed-fps 60`, ~90 s, sai 0/1).
2. BalanceBot: rodar r9 com a vida nova; o bot não pula — contra voadores depende do mergulho/rasante.
