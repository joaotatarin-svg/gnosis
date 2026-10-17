# ANIMAÇÃO — Sophia e criaturas comuns (diretor anim-sophia, 17/10/2026)

Objetivo: acabar com a leitura de "foto recortada movida em peças". A Sophia
agora toca **quadros pintados** (folhas do ChatGPT S1–S10 + as 6 poses
antigas) com troca seca, escala única e pé travado; as criaturas sem boneco
se mexem como corpo inteiro **sem girar o cartão** e morrem **dissolvendo**.

## O que mudou

| Área | Antes | Agora |
|---|---|---|
| Recorte das folhas | chave magenta no shader, depois do bilinear (franja), sem mipmap | `assets/painted/derived/*.png` com alfa real (desmistura + despill + erosão 1 px), **mesmas coordenadas**; mipmaps; `painted_clean.gdshader` só tinta |
| Sophia | 6 poses, cada uma normalizada pela própria altura (cabeça "inchava" 1,33×), âncoras manuais, corrida de 2 quadros por tempo | atlas `sophia_frames.png` (61 quadros, 28 estados), escala ÚNICA, âncora do pé por quadro medida na máscara, corrida 8+8 (RIFE) com fase pela **distância** |
| Movimento extra | cartão girando até 1,4 rad, squash até 1,4×0,7 | rotação ≤ 0,12 rad, squash ±7%; inclinação vira **curvatura no vertex shader** (`painted_flex.gdshader`, pés pregados) |
| Secundário | — | vento no cabelo e nas barras do manto por máscara (`sophia_frames_flex.png`), ondulação da barra dos espectros |
| Golpes | — | smear do cajado (arco da ponta anterior à atual), afterimages aditivos (esquiva e golpe forte, 80–90 ms) |
| Criaturas | balanço com rotação, morte tombando o cartão | passo com quique/squash pela distância, curvatura no shader, **morte por dissolução** com borda luminosa (gibs pintados continuam no golpe pesado) |
| Áudio | passo por timer no player | `step` no quadro de apoio da corrida; `step`/`step_heavy` no passo das criaturas; `cloth` na esquiva |

Arquivos: `scripts/fx/character_art.gd` (seção PINTURA ANIMADA, classe interna
`AfterimageLayer`), `scripts/fx/painted_library.gd`, `assets/shaders/painted_{clean,flex,ghost}.gdshader`,
`scripts/entities/player.gd` (`_sync_anim`: windup do leve, `combo_step`, `dodge_back`;
`_squash` limitado; timer de passo removido), `scripts/entities/enemy.gd` (morte por
dissolução; forma revivível dissolve só até 55%).

## Como regerar

```
python tools/anim/clean_sheets.py            # folhas derivadas (alfa real) — todas
python tools/anim/rife_inbetween.py          # meios da corrida (GPU, ~30 s) — só se mudar a corrida
python tools/anim/build_frames.py            # atlas + JSON + pranchas em _caps/anim-sophia/frames_contact_*.png
python tools/anim/run_drift.py run16         # deriva do pé de apoio
godot --headless --path . --editor --quit    # reimporta (mipmaps já no .import)
```
Folha nova do GPT: copie para `assets/painted/src/sophia_<id>.png` (pasta com
`.gdignore`), declare a fonte (grade + nomes das células) e os estados em
`tools/anim/sophia_recipe.json`, rode `build_frames.py` e confira as pranchas.
Âncoras: `front` (golpes/parada: bota da frente travada), `rear`, `pelvis`
(corrida/esquiva/magia), `air` (pulo/aéreos), `lying` (deitada); por quadro: `"s9.die_0@rear"`.
Escala por folha: número ou `"auto:<célula em pé>"`.

Filmar: `godot --audio-driver Dummy --path . --resolution 1280x720 --fixed-fps 30 --write-movie <pasta>/f.png res://tools/AnimQA.tscn -- film_sophia|film_criaturas`
e `python tools/anim/film_tools.py gif|sheet ...`. Prancha parada: `-- board <png>`.

## Medidas

- Magenta residual nas folhas derivadas: **0 px** (métrica: min(r,b)−g>90, r>170, b>120, alfa>0,25); antes, cru: 0,8–1,26 M px por folha.
- Cabeça entre poses da folha antiga (olho→queixo): 25,5–27,5 px (±4%, limite de medição ±1 px); a folha é quase uniforme — só a preparação recebe +6%. As folhas GPT saíram na mesma escala (auto 1,004).
- Corrida: `run` (8 quadros) deriva do pé na troca **0,00 px** por construção (cada quadro dura o recuo do pé apoiado); `run16` (com meios RIFE, a usada) **≤1,58 px de mundo** medidos na imagem (ruído dos pés borrados nos meios). Deslizamento DENTRO de cada quadro: ≤16 px (run) / ≤8 px (run16). Tabela: `_caps/anim-sophia/run_drift.txt`.

## Limitações honestas

- Os meios do RIFE borram as pernas nos quadros de cruzamento (visível em zoom; em jogo ~110 px de altura quase não aparece). Para voltar ao ciclo de 8: `USE_RUN_INBETWEENS := false` em `character_art.gd`.
- Estados aéreos usam âncora pela pélvis (pose de chão no ar fica plausível, não perfeita). `attack_dive` não sabe a hora do pouso (o CharacterArt não vê o chão).
- Morte: die_0 troca o cajado de lado em relação ao dano anterior (curto, passa).
- Criaturas comuns continuam peça única (sem quadros próprios): a vida vem de quique/curvatura/dissolução, não de membros.
- Franja: medida só pela métrica estrita de magenta; não há medição de "halo escuro" no jogo.
- O `posterize`/outros shaders de cenário não foram tocados; props/baús/gibs usam o material limpo mas ficam sem mipmap (filtro do nó, não é meu — ver pedidos).

## ESTADO PARA A PRÓXIMA SESSÃO

**Feito (branch `dir/anim-sophia`, commits 835e80f → 3c23c8e):** pipeline de folhas
limpas; atlas genérico por receita com S1–S10 integradas (L/LL/LLL = light1/2/3,
forte 6, magia s6_b, aéreo s7_b, esquiva/dano s8, morte s9_a, pulo s10, parada+prontidão s3,
corrida s2 + RIFE); CharacterArt toca sequências (fps/dur por estado, hold na antecipação,
corrida pela distância, pouso, levantar, prontidão após combate) com fallback nas 6 poses;
vertex shader de curvatura + vento + dissolução; smear; afterimages; criaturas sem girar e
com dissolução; AnimQA (prancha/filmes/deriva); HeroQA e WaveQA reescritas para o método novo.

**QAs:** HeroQA VERDE (0 falhas, 14 células) · WaveQA VERDE · CodexQA VERDE sem o
`override.cfg` do chefe (com ele falha só "diretório de save independente", pois o user dir
vira GNOSIS-WT-anim-sophia — não é do código) · AudioQA VERMELHO só por `cloth`/`step_heavy`
fora do catálogo — o branch `dir/audio` já os adiciona (fica verde na integração).

**Falta / próximos passos exatos:**
1. Jogar (humano) e ajustar `dur`/`fps` por estado em `sophia_recipe.json` (só dados) — especialmente combo leve vs duração real dos golpes e magia (0,3 s).
2. Decidir run16 (RIFE) × run (8): olhar `_caps/anim-sophia/sophia_v2.gif`.
3. Flash ciano do impacto do golpe forte (heavy_3) por FX — S5 não trouxe o brilho.
4. Usar `rise` quando houver renascer sem recarregar a cena; `land` após o mergulho.
5. Criaturas: se vierem folhas por criatura, a mesma receita/`build_frames.py` serve (trocar `character`, `ref_frame` e `body_px`); hoje `frame_db()` só é consultado pra Sophia.
