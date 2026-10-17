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
| Athoth | `artes/gpt/boss_1_athoth_c.png` (perfil; a versão a, 3/4 com névoa roxa, ficou guardada) | **integrado** (14 quadros, 6 meios RIFE) — `gifs/athoth_c_jogo.png`, `gifs/prancha_arconte_sono.png` | `gifs/athoth_antes_jogo_leve.gif`, `gifs/athoth_depois_jogo_leve.gif`, `gifs/athoth_prancha_antes_depois.png`, `athoth_contact.png` |
| Harmas | `boss_2_harmas_a.png` (RGBA, alfa já vem pronto) | **integrado** (11 quadros, 3 meios) | `gifs/prancha_arconte_fome.png`, `gifs/harmas_depois_jogo_leve.gif` |
| Galila | `boss_3_galila_b.png` (_a rejeitada pelo produtor) | **integrado** (11/3) | `gifs/prancha_arconte_corrente.png`, `gifs/galila_depois_jogo_leve.gif` |
| Yabel | `boss_4_yabel_a.png` | **integrado** (14/6, espectro: andar em vaivém) | `gifs/prancha_arconte_silencio.png`, `gifs/yabel_depois_jogo_leve.gif` |
| Astaphaios | `boss_5_astaphaios_a.png` | **integrado** (11/3; véus pela desmistura do key_array, 0 px magenta/rosado) | `gifs/prancha_arconte_espelho.png`, `gifs/astaphaios_depois_jogo_leve.gif` |
| Belias | `boss_6_belias_a.png` (quadrúpede) | **integrado** (14/6, galope em vaivém; fatiado por componentes) | `gifs/prancha_arconte_praga.png`, `gifs/belias_depois_jogo_leve.gif` |
| Armupiel | `boss_7_armupiel_a.png` | **integrado** (11/3) | `gifs/prancha_arconte_coroa.png`, `gifs/armupiel_depois_jogo_leve.gif` |
| Colosso | `boss_8_colosso_b.png` (_a rejeitada) | **integrado** (11/3) | `gifs/prancha_colosso.png`, `gifs/final_depois_jogo_leve.gif` |
| Rei / Rei final / Yaldabaoth | `boss_9_rei_a.png` (fundo rosa 248,3,185 — a chave estima a cor pela moldura) | **integrado** (14/6) | `gifs/prancha_rei_final.png`, `gifs/rei_depois_jogo_leve.gif`, `t68b/last_small.png` |

Bípedes andam com 8 quadros pela DISTÂNCIA (walk_0 → idle_0 → walk_1 → idle_1 com um meio do RIFE entre cada par, ciclo = 0,9 altura do corpo; Armupiel só walk_0 ↔ walk_1 + meio, porque no idle a espada fica fincada e o meio dobrava a lâmina — gifs/andar_8_quadros_bipedes.png); espectros, fera e Rei em vaivém com meios do RIFE. Tamanho: altura do corpo
igual ao boneco em todos (PuppetQA); a largura muda onde a vista mudou (Colosso e Rei em perfil
ficaram mais estreitos que a pintura frontal antiga; Belias com espinhos mais baixos).

**Tela 68 (Rei "não aparece")**: conferido no renderer real — os dois chefes existem; o Rei
final aparece com os quadros novos (`_caps/arte-gpt/t68/both.png`, `t68b/last_small.png`). O
Colosso nasce FORA da tela (x≈1774 px de imagem com a Sophia em 460) e entra andando; a barra
mostra o nome do Colosso desde o início. Não é arte → Pedido 4.

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
3. **level.gd / final_battle.gd (tela 68)**: o Colosso nasce fora da tela (≈ +1300 px da Sophia) e a
   barra única mostra o nome dele enquanto só o Rei está visível — já listado como A3 no QA-UX.
4. **enemy.gd (morte do chefe)**: opcional — tocar o estado `dead` (quadro `death` + dissolução)
   ~0,4 s antes do desmembramento, para o quadro de morte desenhado aparecer.

5. **npc_encounter.gd** (encontros): os atlas já têm os estados; basta `_art.set_anim("talk")` ao abrir o
   diálogo, `"bless"` na escolha do Soter (antes do AoeNova), `"fade"` no tween de saída do Soter;
   Velkar: `"kneel"` durante a fala, `"farewell"` na despedida, `"walk"` ao mancar pro canto. Sem isso
   eles ficam no `idle` (vaivém), que já anima.
## Criaturas (bloco extra, mesmo pipeline)

Folhas `cri_<n>_<nome>` do produtor (2×4: idle_0, walk_0, walk_1, walk_2, windup, strike, hurt,
death), grupo `creatures` (`assets/painted/derived/creatures/`, receitas com `"group": "creatures"`
e `old_sheet`/`old_rect` = Rect2 da pintura única em `inhabitants`). Integradas: larva (índice 0,
todos os WRAITH comuns), espadachim (1, humanoide padrão), bruto (2, BRUTE/COLOSSUS — folha _b),
cão (3, BEAST), escudeiro (4, escudo), conjurador (5, cajado). Andar = 3 quadros + 3 meios do
RIFE pela distância (larva em laço por tempo); parado = 1 quadro + respiração da mola. A tinta
leve por tipo (`profile.primary`) continua. Soter/Velkar/Adormecido (6–8) seguem na pintura única
até virem folhas.

As **criaturas da família de cada Arconte** (sonâmbulo, glutão, carcereiro, pretoriano...) agora
usam os quadros do seu Arconte em escala de criatura — antes eram o boneco da pintura antiga, e
ficariam com cara do chefe antigo ao lado do chefe novo. `gifs/familia_athoth_tela4.png`.

WaveQA atualizado para o método novo: cada estado da criatura toca a sua sequência própria e a
mola mexe o corpo inteiro sem girar o cartão (squash ≤ 7%, preparar recua, golpe avança).
Capturas: `gifs/criaturas_prancha_antes_depois.png` (pintura única × quadros), `gifs/criaturas_quadros.png`.
Obs.: com o shader corrigido as criaturas ficam no brilho real da pintura (antes saíam escurecidas
pela cor ao quadrado do `painted_flex`).

## NPCs (Soter, Velkar, Adormecido)

Mesmo pipeline (grupo `creatures`, índices 6–8 do `inhabitants`). Soter veio RGBA (alfa real);
o quadro `fade` veio rosado (o GPT pintou o fantasma já misturado ao magenta) → receita com
`recolor` (mantém a luminância, cor creme). Estados no atlas:
- Soter: `idle` (vaivém + RIFE), `talk`, `bless`, `fade`.
- Velkar: `idle`, `talk`, `kneel`, `rise`, `farewell`, `walk`.
- Adormecido: `asleep` (vaivém, deitado), `wake` (acordar → de pé → reverência → parado), `idle`, `talk`.
  Funciona SEM tocar no `sleeper.gd`: o CharacterArt dorme enquanto o olho do perfil está apagado
  e, quando o `sleeper.gd` troca o perfil (olho aceso), toca o `wake` no relógio próprio.
Prova: `gifs/npcs_estados.png` (AnimQA `-- npc_board`).
