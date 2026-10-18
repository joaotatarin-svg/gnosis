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
6. **player.gd (combate)**: chamar `visual.play_action("parry")` dentro de `_parry()` (hoje o aparo é
   reconhecido pelo flash — se a Fase B mudar a cor do flash, para de funcionar) e, se houver
   contra-ataque após o aparo, `visual.play_action("riposte")` no início dele (quadros prontos no atlas).
7. **staging.gd (cena D, anagnórise — o "disco preto")**: o Cego pequeno é o `_Little` (círculos desenhados).
   Trocar SÓ duas linhas (a interface é a mesma: `glow`, `modulate`, `scale`, `global_position`):
   - linha 56: `var _little: _Little`  →  `var _little: CegoPequeno`
   - linha 615: `_little = _Little.new()`  →  `_little = CegoPequeno.new()`
   (a classe `_Little`, linha 1027, pode ser apagada depois). O `CegoPequeno` (`scripts/fx/cego_pequeno.gd`)
   escolhe a pose pelo `glow` que a cena já anima: encolhido com a máscara caída → olha pra cima → estende a
   mão → erguido → aninhado (quando já está na mão dela, escala < 0,8). Para travar uma pose:
   `_little.set_anim("curled"|"trembling"|"look_up"|"reach"|"lifted"|"nestled")`. Prova:
   `gifs/cego_pequeno_prancha.png` (AnimQA `-- cego_board`).
8. **ENCENAÇÃO (narrativa6, `staging.gd`, roubo/tela 64 — o "disco preto")**: o rosto revelado hoje é o `_blind`
   (oval preto + olho branco desenhados por cima, `_King._draw_over`, ~linha 1135). O atlas do Rei agora tem
   os estados pintados, mesma escala e lugar do Rei: `mask_crack` (mão no rosto, máscara rachando), `revealed`
   (vazio escuro com UM olho âmbar), `triumph` (orbe-olho ao alto), `dominion` (mão puxando os 7 anéis),
   `sinking` (afundando em rachaduras de luz). Uso, no `_King`:
   - `drop_mask(t)`: `art.set_anim("mask_crack")` e, ~0,3 s depois, `art.set_anim("revealed")`; **não desenhar
     mais o bloco `if _blind > 0.0:`** quando `art.has_boss_frames()` (é ele o disco preto); a máscara caindo
     (`_mask_off`) pode ficar.
   - durante o roubo dos anéis (gemas indo para `hand()`): `art.set_anim("dominion")`; triunfo: `"triumph"`
     (esconder o `orb` Sprite2D nesse estado — o orbe já está pintado no quadro).
   - `collapse(t)`: `art.set_anim("sinking")` no lugar do `scale:y` 0,2 (ou junto, mais curto).
   - Fala "…mãe?" (cena D, tela 68): retrato `res://assets/painted/derived/portraits/cego_pequeno_olhando.png`.
9. **UI (retratos do diálogo)**: novos bustos RGBA em `res://assets/painted/derived/portraits/`:
   `rei_revelado.png` (Rei sem máscara, olho âmbar — falas depois do roubo) e `cego_pequeno_assustado.png`,
   `cego_pequeno_olhando.png`, `cego_pequeno_sereno.png`, `cego_pequeno_aninhado.png` (o "pequeno" da cena D,
   por humor). Gerador: `tools/anim_bosses/portraits.py`.
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

## Sophia — corrida desenhada (S11) e morte com transição (S12)

- **Corrida** (atualizada com a S13 _b): estado `rund` = ciclo de **16 quadros todos desenhados** pela fase do pé de apoio — S2 run_0..7 + as 8 poses ENTRE da S13 (pé saindo do chão, joelho alto, pé estendido antes do contato, recebendo o peso, das duas pernas). A S11 saiu do ciclo (as poses dela caem nas mesmas fases da S2). Ordem: contato D, saída E, peso D, recuo, passagem, joelho E, impulso, alcance E | contato E, peso E, saída D, recuo, joelho D, passagem, alcance D (apoio ainda no pé de trás: `support: rear`), impulso. **Deriva do pé na troca 0,00 px**; deslizamento dentro do quadro **≤ 10,1 px** de mundo (antes 13,3 com 11 quadros; 16 no ciclo de 8). `build_frames.py`/`run_drift.py` ganharam `support` por quadro. `USE_RUN_INBETWEENS := false`; nenhum meio do RIFE na corrida. GIFs: `gifs/sophia_corrida_antes.gif` (run16 com RIFE) × `gifs/sophia_corrida_depois.gif` (16 desenhados); versão intermediária de 11 quadros em `gifs/sophia_corrida_v11_s2s11.gif`.
- **Morte**: `dead` = S12 _b inteira (atingida → cambaleia → um joelho → mão no chão → tombando →
  deitada de bruços), 0,6 s, âncora no pé de trás (cai pra frente sem escorregar). Substitui S9 die_0..3.
- HeroQA ganhou: corrida sem quadros do RIFE e ≥ 8 quadros; morte com ≥ 5 quadros e terminando deitada.
- GIFs: `gifs/sophia_corrida_antes.gif` × `gifs/sophia_corrida_depois.gif`, `gifs/sophia_morte_antes.gif` ×
  `gifs/sophia_morte_depois.gif`, prancha `gifs/sophia_corrida_morte_antes_depois.png` (AnimQA film_sophia).
- Shader da Sophia NÃO mudado (decisão do João).

## Sophia — guarda, aparo e contra-ataque (S14)

- `player.gd` só envia `block` (State.BLOCK); o aparo acontece DENTRO da guarda (`_parry`, sem estado
  próprio) e não existe estado de contra-ataque. Então:
  - `block` = guarda da S14 (guard ↔ volta à guarda, laço lento) — substitui a pose S1 antiga;
  - `parry` = aparo c/ faísca → desvio → abertura → guarda (0,3 s), tocado como AÇÃO AVULSA por cima
    da guarda. Sem tocar no player.gd, o CharacterArt reconhece o aparo pelo flash do `_parry`
    (`modulate.b > 3,5` enquanto em `block`; o bloqueio comum pisca 3,0 e não dispara);
  - `riposte` = estocada → giro (smear) → follow-through → volta à guarda (0,32 s), pronto no atlas,
    tocado por `visual.play_action("riposte")`.
- O `run16` (meios do RIFE) saiu do atlas para caber tudo em 2048×2048 (70 quadros). Para voltar:
  recolocar o estado na receita e `USE_RUN_INBETWEENS := true`.
- HeroQA: estados block/parry/riposte no atlas; flash do aparo na guarda toca `parry`; `riposte` toca e termina.
- Capturas: `gifs/sophia_aparo_quadros.png` (quadros alinhados), `gifs/sophia_guarda_antes.gif` (pose S1) ×
  `gifs/sophia_aparo_depois.gif` (guarda → aparo → contra-ataque, AnimQA film_sophia).

## O Cego pequeno (cena D)

Folha `artes/gpt/cego_pequeno_a.png` (2×3) → receita `tools/anim_bosses/recipes/cego_pequeno.json` (grupo `npcs`, linha de baixo × 0,92 para igualar a escala; sem pintura antiga, o `boss_frames.py` agora aceita isso) → `assets/painted/derived/npcs/cego_pequeno_frames.*`. Nó pronto: `scripts/fx/cego_pequeno.gd` (`class_name CegoPequeno`), origem no chão, ~22 px de mundo na escala 1 (33 px na escala 1,5 da cena), respiração, tremor em surtos, contorno pálido para ler no escuro e o halo quente do `glow`; sem atlas cai no desenho antigo. Ligação na cena: Pedido 7.

## #30 Leitura dos inimigos escuros — contorno de luz do Éon

`painted_boss.gdshader` ganhou um contorno interno (rim) aditivo: borda da silhueta (alfa do pixel −
menor alfa num raio de 4 texels) × cor × intensidade. No `CharacterArt`, todo inimigo por quadros
(chefes, família, criaturas; NPCs e Sophia não) usa a cor `glow` do Éon atual
(`SceneryLibrary.look(RunManager.eon_index(tela))`, só leitura) com intensidade **0,32** e **0,64 na
preparação** (soma ao contorno do telegrafo). `rim_enabled` desliga por personagem.
Prancha (AnimQA `-- rim_board`): `gifs/contorno_inimigos_antes_depois.png` (Torpor, Silêncio, Centro;
esquerda sem, direita com; parado e preparando) e o zoom `gifs/contorno_inimigos_zoom.png`.

## #46 Progressão da arma visível na Sophia (níveis 1–5, sem arte nova)

`CharacterArt._draw_weapon_glow`: no cristal do cajado (ponta medida por quadro no atlas) halo em camadas
que cresce e esquenta por nível (ciano → branco-dourado), pulso; nível 3+ cintilação em cruz; 4+ motes
orbitando; 5 anel dourado. Smear do cajado mais denso/quente por nível e com faíscas no 3+. Nível lido de
`Progression.weapon_level` (só leitura; `weapon_level_override` para QA). As marcas antigas em arco
(desenhadas fora do lugar com os quadros) ficam só na reserva das 6 poses.
Limitações: o **bracelete não brilha** — não há posição do braço medida por quadro (estimar dava brilho
flutuando fora do corpo); na **magia** a "ponta" medida é o orbe da mão livre (maior mancha ciano), então o
halo engrossa o feitiço, não o cristal. Prancha: `gifs/arma_niveis_1a5.png` (AnimQA `-- weapon_board`:
parada, golpe forte, magia × níveis 1→5).

## #7 Bots de Éon (deixam de ser miniaturas dos Arcontes)

- **Arte própria** (folhas `bot_<n>_<id>` do produtor → receitas `tools/anim_bosses/recipes/bot_<id>.json`, grupo
  `creatures`, tamanho = o da família antiga): **os 7** — sonâmbulo, glutão, carcereiro, mudo, reflexo, esporos (corcunda bípede: `size_fix` 1,35 e `fit_override` pé no chão), pretoriano. `PaintedLibrary` passa a
  usar `creatures/bot_<id>`; os 7 ids **saíram do mapa `families`** (sem atlas, caem na pintura única das criaturas pelo tipo de corpo). Glutão usa a folha **_b** (criatura-saco de quatro, `size_fix` 0,8). O PuppetQA continua testando o boneco do Harmas/Armupiel em escala de criatura montado à parte (`puppet_idx`).
- **Interino** só para os parentes sem folha (alado, fantasma, cornudo):
  quadros do Arconte com saturação × 0,45 + tinta da cor da criatura. Honesto: a silhueta continua a do
  Arconte (auréola/coroa) — só a arte própria resolve; ficam pequenos (escala da criatura).
- Prancha `gifs/bots_antes_depois.png` (AnimQA `-- bot_board`: Arconte a 55% · antes · depois parado · depois preparando).
- Gerador das receitas: `tools/anim_bosses/mk_bot_recipes.py` (lê `C:\gnosis-wt\_gpt\out\bot_<n>_<id>_*.png`).

## Bug "Harmas fantasma" (João, jogando) — corrigido

- **Causa principal:** os meios do RIFE no andar (commit b1afc8b e os das criaturas/bots) fundiam duas
  poses distantes — duas pernas/barrigas meio-sobrepostas que liam como corpo transparente. **Removidos de
  todo andar** (chefes, criaturas, bots): só quadros desenhados, pela distância (bípedes de 2 passos:
  walk_0 → idle_0 → walk_1 → idle_1; espectros/fera/Rei/Armupiel: walk_0 ↔ walk_1; criaturas e bots:
  walk_0..2). Os meios do PARADO (poses quase iguais) ficaram.
- **Causa secundária:** folhas que já vêm com alfa (Harmas, Soter) tinham o corpo a 0,94–0,996 de
  opacidade (nenhum pixel 255). `build_frames.slice_sheet` agora deixa o miolo opaco (a borda
  antisserrilhada e o que for translúcido de propósito ficam; `raw_alpha_cells` = ["fade"] do Soter, marcado
  `translucent` no JSON).
- **Trava automática (PuppetQA `_check_opacity`):** em todos os atlas (sophia, bosses, creatures, npcs)
  falha se o miolo do corpo de algum quadro tiver opacidade média < 0,95 ou > 15% abaixo de 0,85, ou se
  qualquer andar/corrida usar um meio do RIFE. Hoje: 311 quadros em 27 atlas, pior 0,982
  (Astaphaios, véus translúcidos da arte). Sophia conferida (corrida `rund` sem RIFE).
- Capturas: `gifs/harmas_andando_antes.gif` × `gifs/harmas_andando_depois.gif` e
  `gifs/harmas_andando_antes_depois.png` (no trecho capturado o Harmas anda pouco: o "antes" não chega a
  mostrar o quadro fundido; o "depois" não tem nenhum quadro fundido por construção).

## FLUIDEZ (FILA 7) — intermediários desenhados

`boss_frames.py` ganhou `extra_sheets` (folhas `<id>_motion_a` do mesmo chat, mesma pipeline; escala
normalizada pela pose quase parada `recover_1` × `idle_0` da folha principal → mesma escala e linha de
pés). `tools/anim_bosses/add_motion.py <receita>=<folha>` liga a folha (padrão A das criaturas/bots):
- `walk` = 6 quadros desenhados (contato A, desce A, passagem A, sobe A, contato B, passagem B) pela distância;
- `recover` = golpe → recover_0 → recover_1 → parado, pelo progresso real do inimigo.

**Bloco 1 (bots 1–4: sonâmbulo, glutão, carcereiro, mudo):** escalas medidas 0,995 / 1,032 / 1,008 / 1,013
(nenhuma destoou → nada no REFAZER). Opacidade/sem-RIFE do PuppetQA verde. GIFs do andar:
`gifs/andar_bots_antes.gif` × `gifs/andar_bots_depois.gif` (AnimQA `-- film_walk x sonambulo glutao carcereiro`),
faixa `gifs/andar_bots_antes_depois.png`. Honesto: no glutão o rastejar de 6 quadros tem diferenças sutis
(o produtor avisou) — fica mais "vivo", não muito mais legível.

**Bloco 2 (parcial): reflexo** (folha motion_a aprovada; escala 1,032) — `gifs/reflexo_andar_quadros.png`. Faltam esporos, pretoriano, 6 criaturas, S15/S16 da Sophia e os 9 chefes (ainda não chegaram).


**Bloco 2: esporos e pretoriano** (escalas 0,979 / 0,972) — `gifs/esporos_pretoriano_andar_quadros.png`, `gifs/andar_bots2_depois.gif` (reflexo, esporos, pretoriano). Os 7 bots têm andar de 6 quadros desenhados + recuperação.


**Bloco 3: criaturas larva, espadachim, bruto** (escalas 0,932 / 1,015 / 0,992; larva = padrão A' flutuando em laço) — `gifs/criaturas_andar_quadros_1.png`, `gifs/andar_criaturas1_depois.gif`. Preparado também: `tools/anim/sophia_motion.py` (S15/S16) e o padrão B dos chefes em `add_motion.py`; o CharacterArt já toca `rec_*` ao voltar pro parado.


**Bloco 4: criaturas cão, escudeiro, conjurador** (cão = trote A'', escala fixa 1,0 — a medida automática de quadrúpede dava 1,085 pela pose; escudeiro 0,984; conjurador 1,0) — `gifs/criaturas_andar_quadros_2.png`, `gifs/andar_criaturas2_depois.gif`. As 6 criaturas e os 7 bots têm intermediários desenhados.


**Bloco 5: Sophia S16 (respiração) + S15 (recuperações).**
- Parado = 8 quadros de respiração desenhados (S16, escala auto 1,000), laço a 5 qps.
- Recuperações ao voltar pro parado (ação avulsa, corta se ela andar/atacar): **usadas** rec_light3, rec_cast,
  rec_air (no lugar do pouso), rec_dodge, rec_hurt. **Descartadas** rec_light1, rec_light2 e rec_heavy: o
  cajado troca de lado/altura em relação ao fim do golpe e à prontidão (conferido em
  `gifs/sophia_s15_continuidade.png`: golpe → recuperação → prontidão). Menos quadros certos.
- HeroQA: parado com 8 quadros; rec_light3 toca e termina; rec_light1 não volta.
- O atlas da Sophia passou a 2048×4096 (80 quadros). GIFs: `gifs/sophia_parado_antes.gif` × `gifs/sophia_parado_depois.gif`,
  quadros em `gifs/sophia_s15_s16_quadros.png`.

**Bloco 6: chefes Athoth, Harmas, Galila (padrão C).** Escalas 1,025 / 0,932 / 1,030. Andar = 4 quadros novos
(contato, passagem, contato, passagem) pela distância; preparação = antecipação leve → máxima (hold na máxima);
golpe = impacto → seguimento; recuperação = seguimento → parado. Os quadros antigos `windup`/`strike` saíram
dessas sequências (duas poses "máximas" diferentes dariam pulo). Harmas: folha motion veio magenta (a original
era RGBA) — mesma escala/cor no recorte. GIFs: `gifs/harmas_andar_golpe_antes.gif` × `_depois.gif`,
`gifs/galila_andar_golpe_antes.gif` × `_depois.gif`; quadros `gifs/chefes_motion_1.png`.

**Bloco 7: chefes Yabel, Astaphaios, Belias (padrão C).** Escalas 0,988 / 1,009 / 1,023. Yabel: a preparação nova é de perfil (a antiga era frontal) — melhor. Quadros `gifs/chefes_motion_2.png`; GIF `gifs/belias_andar_golpe_depois.gif`.


**Bloco 8: chefes Armupiel, Colosso, Rei (padrão C; Rei com fundo rosa).** Escalas 1,000 / 0,998 / 1,002. Quadros `gifs/chefes_motion_3.png`; GIFs `gifs/arconte_coroa_andar_golpe_depois.gif`, `gifs/rei_final_andar_golpe_depois.gif`. **FILA 7 completa:** 9 chefes, 6 criaturas, 7 bots e a Sophia (S15/S16) com intermediários desenhados; nenhuma folha foi para o REFAZER.


## Onda 6 — Rei revelado e retratos

Folha `rei_revelado_a` (fundo rosa 252,2,186; chave pela moldura) entrou como `extra_sheets` do Rei (escala auto 0,953 pela pose `revealed` × `idle_0`): estados `mask_crack`, `revealed`, `triumph`, `dominion`, `sinking` (`gifs/rei_revelado_estados.png`). Busto → `portraits/rei_revelado.png`. `retrato_cego_pequeno_a` (aprovada; a `_x` foi descartada pelo produtor) → 4 bustos `portraits/cego_pequeno_<humor>.png` (`gifs/retratos_rei_cego.png`). Ressalvas: fios finos de cabelo do Cego e o brilho do orbe/anéis do Rei guardam um tom rosado leve (despill forte já aplicado). Ligação: Pedidos 8 e 9.
