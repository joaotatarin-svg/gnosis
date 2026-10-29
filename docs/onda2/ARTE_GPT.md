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

## Morte de chefe com peso + máscara presa ao quadro (Onda 6, feedback do João)

- `CharacterArt.play_boss_death(cor)` (~1,9 s, só a PRÓPRIA pintura): cambaleio (quadro de dano, tremor, 2 lampejos)
  → queda (quadro de morte, impacto, `Juice.shake`) → pausa dramática (luz do Éon vazando pela borda, contorno sobe a
  2,2) → estilhaça em ~80 cacos TRIANGULARES do atlas com física, brilho que esquenta na cor do Éon, clarão radial e
  faíscas (`ShatterLayer`) → sinal `death_finished`. Sem escala/"murcha" (PuppetQA confere: escala do corpo > 0,9 e
  estilhaça + termina em todos os chefes). Ligação no `enemy.gd`: docs/pedidos/onda6_chefes6.md.
- GIFs: `gifs/morte_chefes_antes.gif` (desmembra na hora em 3×3) × `gifs/morte_chefes_depois.gif` (Harmas, Armupiel, Rei).
- Pedido à Produção: `C:\gnosis-wt\_gpt\out\PEDIDO_MORTE_CHEFES.md` (folha 2×2 por chefe: stagger_0, stagger_1, kneel,
  collapse) — hoje cada chefe tem só 2 quadros para morrer.
- **Máscara "solta"**: no jogo era o `_orb` (Sprite2D da pintura antiga flutuando ao lado do Rei, `enemy.gd`) →
  pedido em docs/pedidos/onda6_inimigos6.md; na encenação, o rosto/rachadura/máscara do `_King` desenhados em ponto
  FIXO sobre quadros que mudam → pedido em docs/pedidos/onda6_narrativa6.md (usar os estados pintados, ou
  `art.head_point()`). Cada quadro de todo atlas de chefe/criatura agora tem `head` medido (JSON) e
  `CharacterArt.head_point()` devolve a cabeça do quadro atual em coordenadas locais.

## Geometria por quadro (Onda 6, PLAYTEST 2)

`tools/anim/geometry.py` mede em cada quadro de TODO atlas: caixa e contorno do corpo e, na Sophia, o eixo visível do cajado (cabo→ponta; estimado quando cruza o corpo). `CharacterArt.frame_geometry(global)` devolve isso no transform do corpo. HeroQA confere que todo quadro tem corpo, todo quadro com ponta tem cajado e que, na estocada, a ponta cai no cristal e fora do corpo; PuppetQA confere a caixa do corpo de todos os chefes. Prova: `gifs/geometria_quadros.png`. Pedidos ao combate6/inimigos6/chefes6 em `docs/pedidos/onda6_*.md`.


## FILA 9 (Onda 6) — integrada
- **Sophia S17/S18** (b618400): ação desenhada `double_jump` (o player do combate6 já chama `play_action("double_jump")`
  e pula o giro do cartão quando `has_action`); `start_run`/`stop_run` automáticos no `set_anim` (parado→corre;
  corre >0,3 s→parado), desligáveis com `drawn_gait = false`. Nome de estado NÃO pode começar com "run" (índice
  pela distância). Virada (s18 q6-7) fora. Escala s18 = 1.03 com `frame_fix` na freada (igual ao run/idle).
  Prova: `_caps/arte-gpt/fila9/s17_s18_antes_depois.png`, `dj_detail.png` (AnimQA `film_gait x [old]`).
- **Inimigos com arte própria**: `PaintedLibrary.character(p, ctx)`; o `CharacterArt._host_ctx()` lê `type_id` e
  `is_champion` do Enemy (pai/avô). `OWN_ART`: espectro=mariposa, alado=sentinela-olho (voa e atira de cima),
  acolito=en_alado_a (andarilho com besta), cornudo, fantasma (fundo verde). Campeão → `creatures/champ_<bot>`.
  `has_own_art()`; o interino (tinta do tipo + graduação do Rim) é desfeito no 1º `_process` (`_clear_interim_tint`)
  até o inimigos6 pular por conta própria (pedido em `docs/pedidos/onda6_inimigos6.md`).
- **Pipeline**: `key_array` detecta fundo VERDE pela moldura (despill: g ≤ média(r,b) na borda e onde g > r);
  `slice_sheet(grid_only, erase)`: `grid_only` separa quadros que se tocam por inundação geodésica a partir do corpo
  de cada célula (champ_2, champ_7); `erase` apaga retângulos (pó do sono da mariposa; névoa do champ_6 via
  `mk_champ_recipes.haze_rects`). Estado com `puff: [r,g,b]` solta `VfxLibrary.cast` na frente do corpo ao entrar.
  Andar SEM meios do RIFE (a PuppetQA proíbe: lê como fantasma).
- Prova: `_caps/arte-gpt/fila9/own_board.png`, `own_board_champ.png` (AnimQA `own_board x [champ]`).
- Ressalvas (revistas): champ_3 e champ_6 com `despill_full` (o rosado pintado nos panos virou ferrugem/vinho);
  o brilho amarelado no leque do champ_6 ficou (lê como esporos acesos); champ_5 morre estilhaçando EM PÉ de
  propósito (cavaleiro de vidro — R17 morte distinta), com o monte de cacos no chão (âncora `lying` = base no chão).

## Mortes de chefe em 4 etapas (FILA 10) e cor real
- Folhas `boss_<n>_<nome>_death_a.png` (2×2: tranco, cambaleio, joelhos, tombado) entram por
  `tools/anim_bosses/add_death.py` como `extra_sheets` (escala auto contra o `hurt`) e estado `dying`
  (dur 0,17/0,17/0,28; o tombado segura até o estilhaço em 1,08 s). `_death_seq` prefere `dying`; `_boss_index`
  indexa pelo relógio da morte. O fundo rosa do Rei (≈248,2,192) passou na chave magenta normal (K estimado da
  moldura; r e b ≫ g) — sem chave própria. Galila: usada a `_a`. Prova: `_caps/arte-gpt/fila9/death_board.png`
  (AnimQA `death_board`: 1ª linha = antes).
- Cor ao quadrado corrigida no `painted_flex` (60a8cf7): Sophia e criaturas sem quadros na cor real da pintura.

## CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)
- **R17 morte distinta**: chefe morre em 4 poses desenhadas (tranco → cambaleio → joelhos → tombado) + lampejos
  brancos no tranco, tremor e contorno crescendo antes do estilhaço — lê como "acabou" sem olhar a barra.
  Criaturas novas têm quadro de morte próprio (deitado/desfazendo); o contorno branco de 1 quadro no golpe que
  mata é do combate/juice.
- **R18 legibilidade (19/10, auditoria do Guardião)**: Sophia ganhou luz de recorte (por dentro, só onde a borda é
  escura) + halo de ~1 px (por fora) na cor do Éon no `painted_flex` (`HERO_RIM` 0,6, `HERO_HALO` 0,25 só junto das partes ESCURAS —
  sem piso: o cajado dourado ficou sem a faixa pálida que o Guardião apontou —, raio 1,6 texel).
  Medido em jogo (ContrastProbe + contrast_r18.py): tela 3 1,76→2,06:1 · tela 30 2,02→2,37:1 · tela 57 1,45→1,71:1.
  Mais forte lava a pintura; o resto até 3:1 é do fundo (pedido em `docs/pedidos/cenario7.md`). Prancha:
  `_caps/arte-gpt/r18/r18_antes_depois.png`. Chefes/criaturas por quadros já tinham o rim do `painted_boss`.
- **R18 fechamento com os fundos HD (29/10, Cenário7 1b1c69f na base)**: o contraste borda×fundo da Sophia estava em
  2,64–2,93:1 (Cenário7). A luz de recorte interna (`HERO_RIM` 0,6) era fina demais na tela: o raio de 1,6 texel da folha
  (2048×4096) vale ~0,25 px de tela, então quase não tocava os 2 px de borda que o olho (e o `contrast_r18.py`) usam.
  Agora `HERO_RIM` 0,9 com raio próprio `HERO_RIM_PX` 6,0 (~1 px de tela); o halo de FORA ficou como era (`HERO_HALO` 0,25
  e novo uniform `halo_px` 1,6 no `painted_flex.gdshader`, para o raio maior não alargar o halo/faixa pálida do cajado).
  Medido (ProbeBg, quadro 150, rim desligado → ligado): 3 Torpor 2,77→3,72 · 13 Fome 2,87→3,65 · 22 Corrente 2,86→3,71 ·
  31 Silêncio 2,77→3,67 · 40 Espelho 2,74→3,54 · 49 Praga 2,75→3,65 · 57 Coroa 2,75→3,19 · 58 Coroa 2,66→3,05 ·
  66 Centro 2,85→3,77 · 68 Mente 2,04→2,55 (NÃO chega: a Sophia fica no canto esquerdo escuro com a borda em 0,13 de
  luminância; a pose varia entre rodadas — a de 150 quadros é o agachado de chegada; parte do ganho é limitado pelo fundo
  roxo; deixado assim para não lavar a pintura). A tela 68 agora é medida de verdade: o `contrast_probe.gd` pula diálogo.
  Varredura: raio 1,6 → rim até 2,0 só chega a 3,0–3,15 e nas Coroa/Mente nada; raio 4–6 com 0,6–1,0 resolve. Escolhido o
  par mais suave que passa 3:1 também na Coroa. Cajado/saia/botas: no 1280×720 o recorte vira um fio dourado claro nas
  botas e no cajado, sem lavar o manto (a luz só entra onde a borda é escura); saia branca contra o céu claro do Espelho
  não precisa de luz (já salta; o contraste vem do LaneHalo do Cenário). Capturas: `C:\gnosis-wt\_capsrte18\`
  (`antes_*`/`depois_*` 3, 40, 58_x180, 58_x450 — Sophia diante dos pedestais/estátuas dourados da Coroa —, `cmp_1x1.png`,
  `r18_antes_depois.png`, probes `final_*`).
  CHECAGEM: R18 atendida (>=3:1 em 9 de 10 telas; 68 em 2,55 — pendente, sinalizado); R16 (clareza) ok: recorte discreto,
  sem pulso/flash; §4 conferido: nenhum truque, nenhuma recompensa/aviso por cor; a Sophia continua com a cor real da
  pintura (R18 antiga). Risco aceito: botas/cajado levemente mais claros que a pintura.
- **R17 tremor**: o `Juice.shake` da queda de joelhos na morte desenhada caiu de 0,7 para 0,15 (micro) — o tremor
  grande é UM, no golpe final (combate/chefes6).
- **QA7 #18 pés**: `tools/FeetProbe.tscn` mede pé desenhado × base da colisão nas 7 telas de Arconte: todos ≤ 3 px,
  exceto Belias 6,7 px (foot_gap do boneco antigo → zerado). Os 40–55 px da captura do QA7 não se reproduzem no
  idle/andar — devem ser de pose/encenação (entrada do chefe), não da âncora do PNG.
- **R18 (antes)**: cor REAL da pintura (sem o quadrado, a Sophia ficou mais clara e salta do fundo escuro);
  inimigos com arte própria mantêm o contorno do Rim (cor do Éon); o interino tingido/dessaturado sai quando
  há arte própria. Fantasma: fumaça despill p/ cinza-violeta (não some no fundo azul). Pendente: teste em
  escala de cinza ≥ 3:1 por tela (dono: cenário/QA).
- **R19 smear/segurar pose**: nada mudou no golpe da Sophia; as ações novas (pulo duplo, freada) são quadros
  desenhados — sem "foto cortada" girando (o giro do cartão do pulo duplo saiu quando há quadros).
- **R20 squash**: pulo duplo/arrancada/freada desenhados não usam squash extra do CharacterArt (o `_hero_motion`
  segue moderado: jump 0,95/1,06). O squash do player.gd é do combate6.

## BILHETE PARA O SUCESSOR (19/10/2026, 2º integrador de arte, branch `dir2/arte-gpt`)

**Estado:** TUDO da lista do chefe feito, validado (validate -Repeat 2 verde) e com push; último commit e114a52.
- Fila 9: bloco 1 Sophia S17/S18 (b618400) · blocos 2+3 inimigos/campeões (7163c12) · bloco 4 Soter (62f3ed0).
- Cor ao quadrado do `painted_flex` corrigida (60a8cf7) — polimento7 recalibra o FLASH_ADD.
- Mortes de chefe em 4 etapas (4038d12, `add_death.py`, estado `dying`). Ressalvas dos campeões (e114a52).
**Pedidos abertos (de outros):** inimigos6 pular a tinta/graduação do interino com `visual.has_own_art()`
(hoje o CharacterArt desfaz sozinho); narrativa6 usar Soter `lift/offer/rest`, Sophia `soter_look/land/bow`
e `visual.bless_light()` na cena da leveza (`docs/pedidos/onda6_narrativa6.md`).
**Possíveis próximos:** virada da Sophia (s18 q6-7 fraca — pedir refação ao GPT se o João quiser); `fx_floor_crack_a`
já está em `assets/cinematic/` (integrado por outro); acólito usa a arte do alado de besta (en_alado_a) — se o
João quiser o monge da lanterna, pedir folha nova; quadros de morte das criaturas comuns são 1 só (hurt→death).
**Ferramentas novas:** `slice_sheet(grid_only, erase, strip_glow, min_part, despill_full)`; chave VERDE automática no
`key_array`; AnimQA `film_gait x [old]`, `own_board x [champ]`, `soter_board`, `death_board`.
**Armadilhas:** estado da Sophia não pode começar com "run"; andar de criatura SEM meios do RIFE (PuppetQA);
depois de atlas novo, `--editor --quit` e conferir `mipmaps/generate=true`; AnimQA com erro de script trava
(Start-Process + WaitForExit e matar pelo PID); escreva caminhos Windows em Python com r'' (barra-b vira backspace).
Pranchas: `C:\gnosis-wt\_caps\arte-gpt\fila9\`.

### Bilhete anterior (1º integrador)
**Estado:** tudo abaixo está commitado e com push; `tools/validate.ps1 -Repeat 2` VERDE (11 etapas) no último commit.
Feito na Onda 6: Rei revelado + retratos (Pedidos 8/9), morte de chefe com peso (`play_boss_death`, pedido ao chefes6),
cabeça por quadro (`head_point`, pedidos ao inimigos6/narrativa6 sobre o orbe solto e a máscara do `_King`),
geometria por quadro (`frame_geometry`, pedidos ao combate6/inimigos6/chefes6). Pedido à Produção de morte em etapas:
`C:\gnosis-wt\_gpt\out\PEDIDO_MORTE_CHEFES.md` (quando chegarem `boss_<n>_<nome>_death_a.png` 2×2 stagger_0, stagger_1,
kneel, collapse: `extra_sheets` na receita do chefe e trocar `_death_seq`/`_boss_index` para tocar as 4 etapas — hoje
usa hurt → death).

**FILA 9 — falta integrar TUDO** (folhas em `C:\gnosis-wt\_gpt\out\`, notas na seção FILA 9 do MANIFESTO; copie as usadas
para `artes/gpt/`):
- `s17_doublejump_a` (Sophia, pulo duplo) e `s18_runstart_stop_a` (arrancada/freada; a VIRADA não lê como giro — pode
  ficar de fora): fontes novas em `tools/anim/sophia_recipe.json` (copiar para `assets/painted/src/sophia_s17.png`/`s18`),
  estados novos (ex.: `jump2`, `run_start`, `run_stop`), seleção em `CharacterArt._hero_seq` e contrato com o combate6
  (qual estado o player.gd manda: pedir em `docs/pedidos/onda6_combate6.md`). Atlas da Sophia já está 2048×4096.
- Voadores `fly_mariposa_a` (pó do sono rosado translúcido → apagar no recorte, refazer por FX) e `fly_sentinela_a`;
  campeões `champ_1..7_*_a` (champ_2 e champ_7: recortar pela GRADE FIXA 384×512 — hoje `slice_sheet` agrupa por
  componente; dá para forçar com uma opção nova "grid_only"); `en_alado_a`, `en_cornudo_a`, `en_fantasma_b` (FUNDO VERDE
  ≈2,250,1 — o `key_array` estima a cor pela moldura e usa o canal verde? CONFERIR: a fórmula atual assume r,b > g
  (magenta); para fundo verde precisa de uma chave própria); `npc_soter_blessing_a` (coluna de luz → apagar no recorte).
  Receita = grupo `creatures` como os bots (`tools/anim_bosses/mk_bot_recipes.py` é o modelo; sem `old_body`: use
  `size_fix`/escala pela altura em tela desejada). IDs dos inimigos novos: combinar com o inimigos6 em
  `docs/pedidos/onda6_inimigos6.md` e ligar em `PaintedLibrary.character()` (hoje: alado/fantasma/cornudo caem na família
  do Arconte com dessaturação — trocar por `creatures/en_<id>` quando houver atlas, como os bots).
- `fx_floor_crack_a`: perguntar ao chefe se a encenação já usa antes de integrar.

**Ferramentas:** `tools/anim_bosses/boss_frames.py <receita>` (atlas+JSON+geometria; `--no-rife`), `add_motion.py`,
`portraits.py`, `tools/anim/build_frames.py` (Sophia), `tools/anim/sophia_motion.py`, AnimQA (`boss_board`, `film_boss`,
`film_walk`, `film_death[_old]`, `geo_board`, `npc_board`, `cego_board`, `rim_board`, `weapon_board`, `bot_board`).
Depois de gerar atlas novo: `godot --headless --editor --quit` e conferir `mipmaps/generate=true` no `.import` novo
(trocar e reimportar). PuppetQA trava fantasma/RIFE no andar e confere geometria; HeroQA confere Sophia.
**Regras atuais:** nenhuma janela visível (capturas `--position 4000,4000`), `--audio-driver Dummy`, validate `-Repeat 2`.
