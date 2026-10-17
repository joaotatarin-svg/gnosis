# Onda 3 — COMBATE (branch `dir3/combate3`, base `integracao/onda1` ab250ea) — relatório

Sessão local (PC do João, RX 7600). Todo Godot com `--audio-driver Dummy`; janelas em `--position 4000,4000`.
Capturas (fora do git): `C:\gnosis-wt\_caps\combate3\`.

## 1. Commits
| Commit | O quê |
|---|---|
| `5392a33` | Merge de `origin/dir2/combate2` (1119ad7) **sem** `arconte_praga` no `BOSS_PRESENCE` |
| `1cd7ae8` | Perf: corpo do `VfxLibrary.prewarm` do Desempenho (`vfx_prewarm.patch`) + contorno do combate2 no prewarm |
| `7a78d51` | Perf: o palco do prewarm some também no headless; `PrewarmProbe` atualizada |
| `0fd82c8` | F1: flash de dano da Sophia = camada ADITIVA ≤ 100 ms (sem silhueta chapada) |
| `ec14120` | Pedidos da Arte: aparo com quadros, contra-ataque novo, telegrafo por contorno, pose de morte do chefe |
| `c1f714b` | C1: números de dano somem quando o mundo pausa; `tools/combate/FlashParryProbe` |
| (este) | `docs/onda2/COMBATE3.md`, `docs/pedidos/combate3.md` |

## 2. O que mudou
- **Integração do combate2** (gibs com teto, Belias P3 = poças 3,0 s / raio 40, opção "Números de dano",
  contorno de leitura por Éon, regras de travessia Torpor/Corrente, tiro de corrente que prende de fato,
  pose inicial do chefe no card). `enemy.gd`: `BOSS_PRESENCE = {"arconte_sono": 1.08}` (Belias saiu).
- **Prewarm** (`vfx_library.gd`): palco alfa 0,01 sobre a Sophia com o visual real das criaturas da tela,
  gibs, afterimage, esqueleto, efeitos, contorno (CanvasGroup) e o flash novo; folhas seguradas até a próxima
  fase. No headless não existe `frame_post_draw` → o palco ficava para sempre; agora some em 0,5 s.
- **F1** (`player.gd`): flash claro não mexe mais no `modulate` (×2,2 no vermelho sobre a pintura = silhueta
  laranja). `Player.FlashLayer` redesenha a malha do corpo por cima com `VfxLibrary.flash_add_shader()`
  (blend_add, repete a curvatura do `painted_flex`): cheio 35 ms, apaga até 100 ms REAIS; força pelo Juice
  (≤ 3 cheios/s, "Reduzir flashes" × 0,5). Dano = branco quente; flash escuro (Silêncio) continua no modulate.
  A camada entra 1 quadro depois do golpe (no quadro do golpe a malha guardada ainda é a pose anterior —
  aparecia um "fantasma" deslocado).
- **Aparo / contra-ataque** (`player.gd`): `_parry()` → `visual.play_action("parry")`. Contra-ataque novo:
  aparo perfeito abre janela de **0,4 s**; ataque (J ou K) nela = pesado simples **×1,5** (24 → 36 no nível 1),
  wind-up 0,06 s, virado para quem foi aparado, avanço até alcançá-lo (≤ 560 px/s; o aparo empurra o inimigo
  atordoado), `visual.play_action("riposte")`, chute de câmera pesado. O combo segue a partir do pesado.
- **Telegrafo** (`enemy.gd`): chefe por quadros → `visual.telegraph_color` (contorno pulsante, pintura intacta)
  no wind-up, alfa zerado no golpe. Os demais seguem com 45 % de tingimento.
- **Morte do chefe** (`enemy.gd`): segura a pose `dead` **0,4 s reais** (tween que ignora câmera lenta e pausa)
  e só então desmembra (gibs do quadro de morte). Se o mundo estiver pausado nessa hora, só some.
- **C1** (`damage_number.gd`): o número roda com `PROCESS_MODE_ALWAYS` só para perceber `get_tree().paused`
  (a caixa de diálogo pausa pela PauseStack) e sumir na hora. `DamageNumber.clear_all()` disponível. O do
  prewarm (`force`) desenha mesmo pausado.

## 3. Provas
- **F1 antes/depois** (tela 22, Sophia parada levando golpe, 1 quadro a cada 1/60 s):
  `f1\F1_antes_depois.png` (em cima: silhueta laranja chapada por ~6 quadros; embaixo: pintura com textura e
  clarão curto), GIFs `f1\antes_follow.gif` × `f1\depois_follow.gif`, zoom do pico/apagando/depois
  `f1\zoom_f1.png`.
- **Aparo + contra-ataque**: `f1\prancha_f1_aparo.png` (4 primeiros = flash; 5º aparo com o escudo de luz;
  6º contra-ataque acertando, número 36).
- **Telegrafo e morte do chefe** (Athoth): `f1\chefe_antes_depois.png` — em cima (antes): tingimento amarelo
  quase invisível; gibs no mesmo quadro da morte. Embaixo (depois): contorno amarelo; quadro de morte desenhado.
- **FlashParryProbe** (`res://tools/combate/FlashParryProbe.tscn`, janela real): **0 falhas** —
  ```
  FPPROBE|f1|modulate=(1.0, 1.0, 1.0, 1.0) camada=true visivel=true pico=0.36 malha=77
  FPPROBE|f1_freq|pico1=0.36 pico2(<333ms)=0.17
  FPPROBE|aparo|estado=6 acao=parry janela=0.40 vida=120/120
  FPPROBE|contra|estado=4 acao=riposte riposting=true dano=36
  FPPROBE|contra_dano|vida 30 -> 0
  FPPROBE|telegrafo|quadros=true contorno=(1.0, 0.85, 0.2, 0.9) modulate=(1.0, 1.0, 1.0, 1.0)
  FPPROBE|morte|0,2s vivo=true anim=dead gibs=0
  FPPROBE|morte|0,65s vivo=false gibs=9
  FPPROBE|c1|numeros antes=1 pausado=0
  FPPROBE|c1_caixa|pausado=true numeros=0
  ```
- **Engasgo de 1ª vez** (`HitchProbe` do `origin/dir2/perf`, copiada sem versionar; janela real 1280×720,
  `--disable-vsync`, cache de shader do Godot apagado; mínimo de 2 rodadas; "excesso" = pico da 1ª vez − 2ª vez):

  | Evento | antes | depois | shaders | textura |
  |---|---|---|---|---|
  | 1º inimigo nasce | 51,6 ms | 0,0 ms | 2 → 0 | 14,7 MB → 0 |
  | 1ª variante do Éon nasce | 55,5 ms | 0,3 ms | 0 | 29,3 MB → 0 |
  | 1º desmembramento | 11,5 ms | 1,2 ms | 1 → 0 | — |
  | 1º inimigo leva golpe | 4,5 ms | 2,2 ms | 0 | — |
  | 1ª esquiva | 3,1 ms | 0,0 ms | 1 → 0 | — |
  | 1º golpe leve da Sophia | 0,0 | 0,0 | 0 | — |

  Limite: nesta máquina o quadro-base ficou em ~26 ms mesmo com `--disable-vsync` (o mesmo teto de vsync/driver
  do QA visual, V1), então engasgos < ~26 ms ficam escondidos. O prewarm custa ~250 ms no load da fase.
- **Validação** `tools/validate.ps1 -Path C:\gnosis-wt\combate3 -Full`: **TUDO VERDE (11 etapas)** após o merge e
  de novo após F1/pedidos/C1 (CodexQA 53, AudioQA 54, GnoseQA 18, SaveQA 41, TecnicoQA 36, Puppet/Hero/Wave OK,
  CodexPlaytest 1). Sondas do combate: DeathProbe 0 falhas, GibProbe 0, RuleProbe 0, PrewarmProbe PASS
  (com e sem janela). BossSizeProbe precisa de janela (não rodei de novo; ela mede o Belias que eu tirei do 1,15×).

## 4. Balance r9 (bot, `--fixed-fps 60`, vel 1, seed 1, loja clássica)
Faixa do merge (telas 50–58, antes de tudo): base **2537** de dano → com combate2 sem Belias 1,15× **2327**
(−8 %); tela 55 (Belias) **1008 → 833**.

Run inteiro (r9_base = `integracao/onda1` ab250ea × r9_c3 = este branch):
```
                     min (A→B)        dano (A→B)      q-mortes  timeouts
TOTAL            29.5→28.9       6117→5795      -5%   59→55     0→0
Limiar(Rei)       0.3→0.3          42→42        +0%    0→0      0→0
1.Torpor          2.6→2.5         262→262       +0%    0→0      0→0
2.Fome            3.0→3.0         242→259       +7%    0→1      0→0
3.Corrente        3.3→3.4         387→466      +20%    3→4      0→0
4.Silencio        3.8→3.8         588→588       +0%    5→5      0→0
5.Espelho         4.3→4.3         844→844       +0%    8→8      0→0
6.Praga           5.2→5.0        1471→1307     -11%   17→15     0→0
7.Coroa           5.3→4.8        1565→1313     -16%   18→14     0→0
Centro            0.8→1.0         151→166      +10%    1→1      0→0
Mente             0.8→0.7         565→548       -3%    7→7      0→0
```
- **Atribuição:** o run no commit do merge (5392a33) dá **exatamente o mesmo dano** que o branch final
  (5795; só o tempo de 8 telas muda, pela pose de morte de 0,4 s). Ou seja: as tarefas 2–5 não mexem no
  balance (o bot não apara, não bloqueia); toda a diferença vem do combate2.
- **Praga/Coroa melhoraram** (poças de Belias −37 % no run; tela 55 586 → 422; Armupiel 440 → 293).
- **Corrente piorou (+20 %)**: telas 22–26, fonte principal `carcereiro(tiro)` (130 → 221 no run). Causa: duas
  mecânicas do combate2 que agora FUNCIONAM — o tiro de corrente prende de verdade (antes os i-frames
  anulavam a raiz) e as correntes-pêndulo da tela 25. O bot não esquiva nem bloqueia esses avisos.
- **Tentei ajustar e não apliquei.** Fatia 19–28 (determinística; semente não muda nada): base 717 →
  branch 1020. Variações: raiz do tiro do Carcereiro 0,6 s → 1054; 0,5 s → 1041; 0 s → 840; sem a regra
  de travessia → 983; período das correntes 6,0 s (tela 25 sozinha) → 105 × 80 com 4,6 s (e a base dá 119
  nessa mesma tela sozinha). Os números não respondem de forma monotônica: o efeito real é menor que o
  ruído em cascata do bot (vida carregada entre telas). Mexer agora seria ajustar ao ruído.
- **Leitura:** a curva por Éon ficou monotônica (Torpor 262 ≈ Fome 259 < Corrente 466 < Silêncio 588 <
  Espelho 844 < Praga 1307 ≈ Coroa 1313); na base Coroa e Praga eram os picos e a Corrente ficava colada
  na Fome. Recomendo validar a Corrente no playtest do João (esquivar/aparar a corrente) antes de mexer.
  Se ele achar pesado: a alavanca mais limpa é `enemy.gd` `p.root_time = 0.8` (Carcereiro) → 0,6.
- CSV/TXT/LOG: `C:\gnosis-wt\_caps\combate3\balance\` (`r9_base`, `r9_merge`, `r9_c3`, `base_50_58`,
  `merge_50_58`, `cor_*`, `t25_*`). Comparar: `python tools/balance/compare.py A.csv B.csv --papeis`
  (no Windows, `PYTHONIOENCODING=utf-8`).

## 5. O que não ficou bom / não testei
- **Feel** do flash, do contra-ataque (janela 0,4 s, ×1,5, avanço) e da pose de morte: só sonda e captura —
  falta a mão do João. O flash ficou discreto (pico 0,36 de soma); `FLASH_ADD` é a alavanca.
- O flash usa a malha do corpo, não o vento do cabelo/manto do shader: nos 100 ms a camada pode descolar
  1–2 px nas pontas do cabelo. Não se nota nas capturas.
- O flash lê `_body_mesh/_body_xform/_body_tex` do CharacterArt (nomes privados) — pedido de getter.
- O contra-ataque não aparece na tela de Golpes nem nas dicas (UI).
- Os inimigos comuns continuam com o flash de `modulate` (3,3,3) — F1 era só a Sophia.
- C1: não filmei a cena 64/68 de novo; a prova é funcional (sonda: pausa e caixa de diálogo real).
- Engasgos medidos com o teto de ~26 ms por quadro desta máquina; o tempo de 1ª vez abaixo disso não aparece.
- A tela 68 continua variando sozinha (RNG global da Encenação, já pedido na Onda 2).

## 6. Pedidos
`docs/pedidos/combate3.md` (Arte: getter do corpo, código morto do aparo/telegrafo; Encenação: conferir a pose
de morte nas telas 1/64; Shader: rever `FLASH_ADD` quando a cor ao quadrado for corrigida; UI: contra-ataque
na tela de Golpes).
