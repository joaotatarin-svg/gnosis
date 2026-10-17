# ARTE GPT — chefes por quadros desenhados (Onda 2, sessão local)

Branch `dir2/arte-gpt` (base `integracao/onda1`). Diretor de animação de chefes por quadros.

## Método (decisão técnica)

Trocar a textura da malha do boneco (`BossPuppet.set_state_texture`) por uma pose
diferente deforma errado: os pesos foram feitos para a pose de repouso. Por isso os
chefes passam a **tocar os quadros pintados como a Sophia**, e o boneco fica de reserva:

- `tools/anim_bosses/boss_frames.py <nome>` + receita `tools/anim_bosses/recipes/<nome>.json`
  → `assets/painted/derived/bosses/<nome>_frames.png` (atlas, mipmaps), `_frames_flex.png`
  (máscara do pano), `_frames_sil.png` (silhueta do telegrafo) e `_frames.json`.
- Escala e lugar herdados da pintura antiga: o script mede a altura do corpo, a folga do pé
  e o centro do corpo em `derived/puppets/<nome>_body.png` (`fit` no JSON). O chefe novo tem a
  MESMA altura de corpo em tela que o boneco (PuppetQA confere ±3%) → colisões e `_fit_body()`
  continuam valendo sem tocar no `enemy.gd`.
- Meios do RIFE (GPU) entre idle_0↔idle_1 e walk_0↔walk_1 (profundidade 2, vaivém de 8
  quadros), montados com as âncoras alinhadas. Entre poses muito diferentes (golpe→parado)
  o RIFE borra: não é usado.
- `CharacterArt`: se `PaintedLibrary.character()` traz `frames` e o atlas existe, toca os
  quadros (troca seca); senão, o boneco (fallback, API intacta — Ateliê e `set_state_texture`
  seguem funcionando). Só o chefe em pessoa e o seu eco usam os quadros; as criaturas da
  família (glutão, sonâmbulo...) seguem no boneco.
- Movimento por cima dos quadros = **mola amortecida** em (avanço, curvatura do shader):
  HOLD na preparação (chega à pose em 35% do tempo, tensão + tremor fino), ESTALO no golpe
  (velocidade injetada → sobressalto + afterimage na cor do olho), recuo no dano, flutuação
  dos espectros, pano/trapos por máscara, onda da barra. Sem girar o cartão.
- **Telegrafo**: nos chefes por quadros, o tom chapado amarelo/vermelho que o `Enemy` põe na
  preparação vira **contorno pulsante** na mesma cor (o quadro de preparação continua legível).
- Gibs da morte saem do último quadro desenhado (3×3), não da pintura antiga.

### Achado importante (afeta a Sophia e as criaturas — NÃO corrigido por mim)
`assets/shaders/painted_flex.gdshader` faz `COLOR = texture(TEXTURE, uv) * COLOR`, mas no
Godot 4 o `COLOR` de entrada do fragment **já vem multiplicado pela textura** → a pintura sai
com a cor ao quadrado (bem mais escura e saturada). Os chefes por quadros usam
`assets/painted/shaders/painted_boss.gdshader` (igual, mas guarda a cor do vértice num
`varying` e multiplica uma vez só). Prova: `_caps/arte-gpt/board_arconte_sono.png` (quadros
com o shader antigo, escuros) × `board2_arconte_sono.png` (corrigido, mesmo brilho do boneco).
Ver Pedidos.

## Estado por chefe

| Chefe | Folha | Estado | Capturas (C:\gnosis-wt\_caps\arte-gpt\) |
|---|---|---|---|
| Athoth | `artes/gpt/boss_1_athoth_a.png` | **integrado** (14 quadros, 6 meios RIFE) | `gifs/athoth_antes_jogo_leve.gif`, `gifs/athoth_depois_jogo_leve.gif`, `gifs/athoth_prancha_antes_depois.png`, `athoth_contact.png` |

## QAs
- `PuppetQA` (check) ganhou `_check_frames()`: estados obrigatórios, retângulos no atlas,
  altura do corpo = boneco (±3%), pés no chão, boneco invisível e sem montar malha, telegrafo
  → contorno, estalo da mola no golpe, gibs vindos do atlas; criatura da família NÃO usa quadros.
- `AnimQA -- boss_board <png> [id]` (prancha boneco × quadros) e `-- film_boss x <id>` (filme).
- `tools/validate.ps1` TUDO VERDE após o bloco Athoth.

## Pendências
- Telegrafo: o contorno é feito no CharacterArt convertendo o tom que o `Enemy` aplica; o ideal
  é o `Enemy` setar `visual.telegraph_color` direto (ver Pedidos).
- Recuperação usa golpe → parado (sem meio): troca seca, lê bem em jogo; dá para pedir ao GPT um
  quadro "recover" se o João achar brusco.
- Bosses morrem por desmembramento (gibs) no `enemy.gd`; o quadro `death` só aparece nas formas
  revivíveis (batalha final). Ver Pedidos.

## Pedidos (para donos de outros arquivos)
1. **Shader (dono de `assets/shaders/painted_flex.gdshader`)**: trocar o fim do fragment por
   `COLOR = c * vert_col;` com `varying vec4 vert_col; ... vert_col = COLOR;` no vertex (igual a
   `assets/painted/shaders/painted_boss.gdshader`). Hoje a Sophia e as criaturas aparecem com a
   cor ao quadrado. Mudança visual visível (fica como a pintura de verdade) — mostrar ao João antes.
2. **enemy.gd**: na preparação, em vez de `visual.modulate = TELEGRAPH_*`, usar
   `visual.telegraph_color = TELEGRAPH_*` (e zerar `telegraph_color.a` no golpe) quando
   `visual.has_boss_frames()`; os demais inimigos podem continuar no tom chapado ou ganhar o mesmo
   contorno depois.
3. **enemy.gd (morte do chefe)**: opcional — tocar o estado `dead` (quadro `death` + dissolução)
   ~0,4 s antes do desmembramento, para o quadro de morte desenhado aparecer.
