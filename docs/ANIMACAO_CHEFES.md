# Animação dos chefes — malha contínua (17/10/2026)

Substitui o método de 17/09/2026 (recortes retos presos aos ossos). Vale para
os 7 Arcontes, o Colosso, o Rei/Yaldabaoth e as criaturas que herdam a família
visual deles (`PaintedLibrary.character()`: glutão, carcereiro, cornudo,
reflexo, pretoriano, sonâmbulo, fantasma, mudo, alado, esporos).

## O problema antigo

Harmas, Galila, Astaphaios, Armupiel e Colosso eram montados com quadriláteros
retos recortados da MESMA pintura. O peito carregava os pixels do braço e o
quad do braço carregava pedaços do tronco: braço duplicado, borda reta e
buraco ao girar. A lâmina aparecia duas vezes (pintada no corpo + peça). Todas
as peças giravam com o mesmo lerp exponencial, sem pausa nem estalo.

## Método novo

### 1. Camadas derivadas (offline, `tools/anim_bosses/`)

`build_puppets.py` recorta cada pintura NAS MESMAS coordenadas do
`PaintedLibrary` (sem mudar Rect2) e grava em `assets/painted/derived/puppets/`:

- `<nome>_body.png` — corpo RGBA com alfa real (mesma chave do
  `painted_key.gdshader`, sem franja magenta). Onde havia arma, cristais ou
  antebraço em camada, o que ficava por trás é reconstruído com
  `cv2.xphoto.inpaint` (SHIFTMAP, copia textura do próprio corpo). Só ganha
  alfa onde há corpo dos dois lados da peça (ou colado a ela, no caso dos
  membros) — a ponta da espada sobre o fundo continua vazia.
- `<nome>_parts.png` — só as peças rígidas: lâmina de Galila e Armupiel,
  cajado e 7 cristais de Astaphaios.
- `<nome>_arm_l/_arm_r.png` — antebraço+punho em camada própria (Harmas os
  dois, Colosso o esquerdo da pintura), para o punho passar por cima do
  joelho/manto sem esticar a pintura.
- `mesh_cache.res` — malhas e pesos pré-calculados (`bake_meshes.gd`).

Se a folha RGBA do diretor da Sophia (`assets/painted/derived/<folha>.png`)
existir, o script usa o alfa dela. Rodar de novo:

```
python tools/anim_bosses/build_puppets.py           # ~45 s, todas as camadas
godot --headless --audio-driver Dummy --path . --script res://tools/anim_bosses/bake_meshes.gd
```

Ferramentas de conferência: `overlay_bones.py` (pivôs sobre a pintura),
`compare_boards.py` (antes × depois), `make_gifs.py` (GIF por boneco).

### 2. Malha contínua com pesos suaves (`scripts/fx/boss_puppet.gd`)

- TODOS os bonecos usam uma malha única (Polygon2D + Skeleton2D). Grade de
  48 linhas nos chefes (52 no Rei) e 24×32 em escala de criatura
  (`scale < 0.9`). Células sem nenhum pixel visível são descartadas.
- Bípedes: peso por distância ao osso com portões por região (braço não puxa
  o tronco, perna não puxa a cintura nem o punho), membros quase rígidos
  (queda forte de peso) e 2 passadas de suavização pela malha — espalha o
  peso entre ossos vizinhos só por onde há corpo conectado. Até 4 ossos por
  vértice, normalizados.
- Espectros (Athoth, Yabel), Rei e Belias mantêm o campo de pesos que já era
  aprovado; ganharam o corte de alfa 0, a textura com alfa real e as molas.
- Pivôs dos bípedes conferidos sobre cada pintura (Astaphaios estava com o
  braço do cajado no lugar errado; Galila sem as gaiolas).
- Rígidos só a arma (osso `weapon`, filho da mão) e os cristais (flutuam).
- Galila: as gaiolas viraram pêndulos presos ao peito.
- Capa/pano por boneco (`CLOTH`): ossos `cloth_*`/`hem_*`.

### 3. Movimento (mola, hold, estalo)

- Cada osso é uma mola amortecida (frequência e amortecimento por grupo e por
  estado). Peito mais rápido que braço, braço mais rápido que pano → atraso
  escalonado peito → braço → pano sem código extra.
- Preparação: chega à pose em 35% do tempo e SEGURA (tensão +10% e tremor
  fino no fim). Golpe: o peito dispara em ~2 quadros, o braço logo depois,
  com velocidade injetada na entrada do estado → sobressalto e assentamento.
  Recuperação volta devagar. Dano: tranco no peito e na cabeça, quadril cai.
- Amplitudes ~55% das antigas (braço 0,32→0,17 rad; perna 0,24→0,13).
- Respiração no idle (peito enche 1%), pano arrastado pela inércia do corpo,
  limitado para não rasgar a pintura.
- Espadachins (Galila, Armupiel): o punho arma a lâmina na preparação e corta
  no golpe.
- Usa só o que `Enemy._sync_anim` já entrega: estado, progresso real do
  temporizador, velocidade (passada) e fase (fúria). `enemy.gd` intocado.

### 4. Textura por estado (para os quadros pintados que virão)

`BossPuppet.set_state_texture(estado, textura)` troca a pintura da malha
quando o estado bate (null remove). Requisito: a imagem nova tem o MESMO
tamanho e enquadramento de `<nome>_body.png` (arma fora, mesmos pivôs). A
malha, os pesos e as molas continuam valendo por cima — servem de movimento
secundário sobre os quadros. Quadro com silhueta muito diferente pede malha
própria (rodar o bake com a nova textura).

## Custo (PuppetQA, `check` e `perf`)

| boneco | grade | vértices | triângulos | camadas/peças |
|---|---|---|---|---|
| Athoth | 36×48 | 1116 | 1780 | – |
| Harmas | 39×48 | 1554 | 2700 | 2 braços |
| Galila | 35×48 | 1047 | 1838 | lâmina |
| Yabel | 35×48 | 1157 | 1910 | – |
| Astaphaios | 35×48 | 772 | 1250 | cajado + 7 cristais |
| Belias | 43×48 | 1236 | 2066 | – |
| Armupiel | 34×48 | 1251 | 2290 | lâmina |
| Colosso | 34×48 | 1314 | 2290 | 1 braço |
| Rei | 53×52 | 1610 | 2942 | – |
| glutão (criatura) | 24×32 | 724 | 1204 | 2 braços |
| pretoriano (criatura) | 24×32 | 626 | 1116 | lâmina |

Montagem com bake: 15–45 ms por boneco (sem bake: 100–340 ms). Animação:
0,8 ms/quadro de GDScript para 1 chefe + 8 criaturas; quadro total 7 ms
nesta máquina (RX 7600).

## Validação

```
godot --headless --audio-driver Dummy --path . res://tools/PuppetQA.tscn            # check
godot --audio-driver Dummy --path . --resolution 1800x500 res://tools/PuppetQA.tscn -- boards <pasta>
godot --audio-driver Dummy --path . --resolution 1600x900 res://tools/PuppetQA.tscn -- seq <pasta>
python tools/anim_bosses/make_gifs.py <pasta_quadros> <pasta_gifs>
```

O `check` falha se: pesos não somam 1, vínculo de osso faltando, peça solta,
junta parada, ou malha fora do bake (layout mudou sem rodar o bake). A
prancha mostra parado, preparação (hold), pico do golpe, dano e os pesos
pintados por osso.

## Limitações (honestas)

- Continua sendo UMA pintura deformada. Golpes grandes ainda esticam a
  pintura nas juntas (ombro, cotovelo); por isso as amplitudes ficaram
  menores. Mudança de silhueta de verdade (braço erguido acima da cabeça,
  virar de costas) só com quadros pintados novos.
- O fundo reconstruído por inpaint é plausível, não é arte: aparece quando a
  lâmina/antebraço sai do lugar, e de perto se nota a textura repetida.
- Os polígonos de arma/camada foram traçados à mão sobre a pintura; restos
  de 1–2 px de borda podem aparecer em zoom. Ajuste em `build_puppets.py`
  (PARTS/LAYERS) e no GDScript (PARTS/LAYERS), depois rode o pipeline + bake.
- Braços de Galila e Armupiel não ganharam camada própria (o braço da espada
  quase não cruza o tronco); Yabel e Athoth seguem com o campo antigo.
- Sensação/tempo do golpe ainda precisa de playtest humano.

## 5. Quadros desenhados (Onda 2, 17/10/2026) — o método principal

Os chefes passaram a tocar **quadros pintados pelo GPT** (folha 2×4: idle_0, idle_1,
walk_0, walk_1, windup, strike, hurt, death), como a Sophia. O boneco desta página
continua como **reserva** (chefe sem atlas) e a API (`set_state_texture`, Ateliê) não mudou.
Trocar a textura da malha por outra pose foi descartado: os pesos valem só para a pose
de repouso e a pintura deformava errado.

```
python tools/anim_bosses/boss_frames.py athoth          # atlas + JSON + meios do RIFE (GPU)
python tools/anim_bosses/boss_frames.py athoth --no-rife # reaproveita os meios (src/bosses)
godot --headless --path . --editor --quit               # importa (mipmaps já no .import)
godot --headless --audio-driver Dummy --path . res://tools/PuppetQA.tscn         # check (inclui quadros)
godot --audio-driver Dummy --path . --resolution 1400x520 res://tools/AnimQA.tscn -- boss_board <prefixo> [id]
```

Receita (`tools/anim_bosses/recipes/<nome>.json`): folha, grade, `old_body` (camada do
boneco, de onde sai o ajuste de escala/lugar), âncoras por célula (`pelvis` | `top` |
`lying`, `anchor_fix`), meios do RIFE, máscara do pano e estados (`pingpong`, `loop`+`fps`,
`at` = limiares do progresso real do inimigo, `dur`, `cycle_bodies`). Detalhes e estado por
chefe em `docs/onda2/ARTE_GPT.md`.

No jogo (`CharacterArt`, seção "CHEFES POR QUADROS"): troca seca, mola amortecida em
(avanço, curvatura) para o hold da preparação e o estalo do golpe, afterimage na entrada do
golpe, contorno pulsante no telegrafo, gibs do último quadro, shader
`assets/painted/shaders/painted_boss.gdshader`.
