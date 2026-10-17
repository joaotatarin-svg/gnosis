# QA VISUAL (renderer real) — Onda 2

Diretor de QA visual, sessão LOCAL (PC do João: Ryzen 5 5600G, RX 7600, monitor 1920×1080 a **144 Hz** + 2º monitor 1366×768).
Branch `dir2/qa-visual`. Todo Godot com `--audio-driver Dummy` e janela em `--position 4000,4000` (fora do monitor).
Capturas completas (fora do git): `C:\gnosis-wt\_caps\qa-visual\` (rodada 0) e `C:\gnosis-wt\_caps\qa-visual\r1\` (rodada 1).
Capturas reduzidas versionadas: `docs/onda2/qa_visual_caps/r0/` e `docs/onda2/qa_visual_caps/r1/`.

| Rodada | Base testada | Quando |
|---|---|---|
| r0 | `integracao/onda1` @ `589a751` (Onda 1 + técnico/ui-menus da Onda 2) | 17/10 noite |
| **r1** | `integracao/onda1` @ `b04f413` (Onda 2 quase toda: ui-hud, encenação A–D, combate A+B, câmera zoom 1,2, prewarm, physics_interpolation…) | 17/10 noite, depois do pedido do chefe |

---

## 0. AS 4 PRIORIDADES DA NUVEM (r1, base b04f413)

### P1 — Cenas A–D em tempo real (telas 1, 64, 65, 68)
Ferramenta: `tools/qa_visual/CenaSeq.tscn` (= `CenaShot` da Encenação + gravador contínuo, 1 quadro a cada 4 a 60 qps fixos).
GIFs (256 px, ≤300 KB): `qa_visual_caps/r1/cenaA_t01_rei_sai_da_nevoa.gif`, `cenaB_t64_aneis_e_mascara.gif`,
`cenaC_t65_descida.gif`, `cenaD_t68_anagnorise.gif`. MP4 completos (locais): `C:\gnosis-wt\_caps\qa-visual\r1\cena_t{1,64,65,68}.mp4`.
Pranchas por fala: `C:\gnosis-wt\_caps\qa-visual\r1\cena_t{1,64,65,68}.png`.

**Funciona e lê bem:** A (preto + batimento → névoa → silhueta preta com orbe → o Rei "acende" → card → duelo → máscara racha → afunda);
B (Armupiel cai, o Rei sai da névoa, as 7 gemas saem do HUD uma a uma e o HUD vira ◇ cinza, a máscara cai e mostra o olho cego, afunda);
C (preto, câmera desce, Sophia ajoelha, sem música); D (Anéis voltam em espiral, clarão/aura, Colosso encolhe, "alguém pequeno", escolha, epílogo "Ascensão" e Crônicas).
0 `SCRIPT ERROR` nas 4.

**Problemas vistos nas cenas:**
| # | Sev. | O quê | Onde ver | Dono provável |
|---|---|---|---|---|
| C1 | **Média** | **Número de dano CONGELADO na tela a cena inteira.** O último golpe no chefe deixa o número (com brilho) parado durante todo o diálogo da cena (a árvore pausa e o número não some). Tela 64: "2331" do quadro 220 ao fim (≈ 1 min); tela 1: "18" na base do Rei enquanto ele afunda; tela 68: "2146" até a escolha. (O valor alto é da sonda, que mata com HP+999; o congelamento acontece com qualquer número.) | `qa_visual_caps/r1/B_t64_dano_congelado_e_dica_U.jpg` · `C:\gnosis-wt\_caps\qa-visual\r1\crop_t64_dano.png` | combate (`damage_number.gd`: limpar/terminar ao abrir cena) ou encenação (`staging.gd` limpar números ao começar) |
| C2 | Média | **Dica "U · usar o Anel equipado (gasta Éter)" fica no topo, sobre a cabeça do Rei, durante a cena inteira** (64 e 68). Em parte é artefato (a sonda dá os Anéis na hora e a dica de "1º Anel" dispara), mas a dica não deveria ficar visível durante cena/diálogo. | mesma imagem acima; `r1/t68_inicio_rei_na_borda.jpg` | ui-hud (`hud.gd`, esconder dicas com caixa/cena) |
| C3 | Baixa | Card de chefe aparece com o chefe FORA do quadro (Athoth na tela 10; Yaldabaoth na 68): o card fala de alguém que não se vê. | `C:\gnosis-wt\_caps\qa-visual\r1\combate\c10_follow_sheet.png` (quadros 000–040) | encenação (posição de nascimento) / combate (câmera) |
| C4 | Baixa | Cena D: o "pequeno" é um disco preto liso — lê como buraco/bomba, não como alguém. | `r1/cenaD_t68_falas.jpg` (falas l03–l07) | arte-gpt local (o ENCENACAO.md já admite) |

### P2 — Feel do combate novo (hitstop/câmera/flash)
Ferramenta: `tools/qa_visual/CombatSeq.tscn` (anda até a zona trancar e roda L-L-L → H → esquiva → APARAR quando um inimigo entra em WINDUP; grava quadro + meta com `Engine.time_scale`, zoom e origem da câmera).
Folhas: `qa_visual_caps/r1/combate_t03_combo_pesado_esquiva_aparar.jpg`, `combate_t68_rei_e_colosso.jpg`; locais `C:\gnosis-wt\_caps\qa-visual\r1\combate\c{03,10,68}_*.png/gif`.
- **Câmera: a Sophia NÃO sai mais do quadro.** Zoom 1,2 constante; x da Sophia na imagem 162–760 (tela 3), 98–799 (tela 10), 901–1203 (68) — 0 quadros fora (r0: fora em 15–27 de 30 amostras no início de toda zona). A5 = CORRIGIDO.
- **Hitstop existe e é curto:** `time_scale = 0,05` em 2–3 amostras (≈4–6 quadros) nos golpes que conectam; 11 eventos em 600 quadros (tela 3), 24 (tela 10), 30 (68).
- **Golpes distintos:** L, LL, LLL e H têm poses diferentes (S4 do GPT), anel laranja grande no pesado.
- **Problema F1 (Média): o "flash" de dano da SOPHIA é silhueta laranja-vermelha CHAPADA** (corpo inteiro sem textura) — quadros 063/098/154/287 da folha da tela 3. É o mesmo defeito que o telegrafo tinha. Dono: combate (`player.gd`, R1: tingir 40–50%, não 100%).
- **Telegrafo do chefe (WINDUP) melhorou:** agora tinge ~50% (a textura aparece) — `C:\gnosis-wt\_caps\qa-visual\r1\crop_windup68.png`. Em r0 era amarelo chapado (`r0/04_telegrafo_amarelo_chapado.jpg`).
- **Aparar NÃO confirmado:** a sonda apertou "block" em 2–4 WINDUPs por luta; o estado BLOCK aparece, mas não vi o VFX de aparo e a Sophia toma o golpe logo depois (HURT). Pode ser só o meu tempo (janela de 0,18 s). **Não testável com segurança por automação — precisa da mão do João.**
- **Tela 68 (F2, Média): Rei e Colosso ficam EMPILHADOS no mesmo lugar** (o Colosso desenhado por cima do Rei), e a Sophia, pequena, some atrás deles na borda direita. Lê como um borrão dourado. Dono: encenação/combate (`final_battle.gd`: separar as duas formas; z-order).

### P3 — FPS real com physics_interpolation (monitor 144 Hz)
Ferramentas: `tools/qa_visual/PerfTimeline.tscn` (= `tools/PerfProbe` do Técnico + espião de engasgos que mede TODOS os quadros, com o momento) e `tools/qa_visual/JitterProbe.tscn` + `jitter_csv.py` (tremor).
Números na seção 5. Resumo honesto:
- **vsync DESLIGADO:** 100–190 qps médios com 12–24 criaturas; 1% low 35–90; nenhum quadro >100 ms; 0–5 quadros >33 ms por 12 s.
- **vsync LIGADO: NÃO deu pra medir.** Com a janela fora do monitor (regra do silêncio/sem janela) o Windows (DWM) estrangula a apresentação: 21–30 qps constantes (≈ 40 ms por quadro), inclusive com a janela 5 px dentro do canto. Isso é artefato da janela invisível, não o jogo — mas **precisa ser confirmado com a janela VISÍVEL** (o padrão das Opções é VSync "Ligada"; se fosse real, o jogo inteiro rodaria a 25 qps). Pedido ao chefe: autorizar 1 medição com janela visível no 2º monitor, ou o João olhar o contador de FPS (FpsOverlay) jogando.
- **Tremor de 1 px:** PARADA, a câmera e a Sophia ficam imóveis (0 quadros com movimento ≥0,25 px depois de 0,6 s). ANDANDO a ~370 qps a câmera anda todo quadro (contínua). Há **saltos de ~2 px (espaço 640×360 = ~4 px na tela) concentrados nos 50 ms em que a Sophia ARRANCA** (look-ahead acelerando) — 58 quadros "rápidos demais" em 3 s, todos entre 0,40 e 0,45 s. Não é tremor contínuo; pode ser sentido como um "tranco" ao começar a andar. Limite: o Godot não expõe a posição 2D interpolada, então a da Sophia é reconstruída (lerp físico); a da câmera é a real (`canvas_transform`).

### P4 — Tela 68: o REI aparece?
**Sim, mas mal enquadrado.** Ao chegar: as DUAS barras aparecem (Rei e Colosso — A3 corrigido), o Rei está metade fora do quadro (x de tela 726 de 640) e o **Colosso totalmente fora** (x 1255 de 640). Durante o card "Yaldabaoth" nenhum dos dois aparece. Eles entram no quadro quando a Sophia anda ~100 px para a direita; aí ficam empilhados (F2).
Prova: `qa_visual_caps/r1/t68_inicio_rei_na_borda.jpg`; posições por quadro em `C:\gnosis-wt\_caps\qa-visual\r1\cenas\t68.log` (linhas `CSEQ|`).
Sugestão: nascer as duas formas dentro do quadro (x ≤ ~560 do espaço 640), separadas ~200 px, ou a câmera da arena final enquadrar as duas. Dono: encenação (`final_battle.gd`/`level.gd`).

---

## 1. Validação (`tools/validate.ps1`)
| Etapa | r0 (589a751) | r1 (b04f413) |
|---|---|---|
| Scripts (editor headless) | VERDE | VERDE |
| ScriptCheck (109 .gd) | VERDE | VERDE |
| CodexQA | VERDE 53 PASS | VERDE 53 PASS |
| AudioQA | VERDE 45 PASS | VERDE 46 PASS |
| GnoseQA | VERDE 18 PASS | VERDE 18 PASS |
| SaveQA | VERDE 41 PASS | VERDE 41 PASS |
| PuppetQA / HeroQA / WaveQA | VERDE | VERDE |
Obs.: a 1ª importação headless de um worktree novo deu **segfault** ao importar `Alegreya-VF.ttf` (r0); a 2ª passou. Não se repetiu em r1.

## 2. Passada visual (r0, base 589a751)
- **68/68 telas avançam** na RunProbe (modo fight), 0 `BUG?`, 0 `SCRIPT ERROR` (1 aviso de cache de shader por processos em paralelo). Pranchas: `C:\gnosis-wt\_caps\qa-visual\pranchas\prancha_*.png`.
- Menus (Shot de cada cena): `C:\gnosis-wt\_caps\qa-visual\prancha_menus.png` · `r0/07_menus.jpg`. Créditos rolam (lentos: ~15 s até o 2º bloco).
- HUD/chefe fase 2/68/diálogos: `C:\gnosis-wt\_caps\qa-visual\prancha_hud.png`, `prancha_boss_f2.png`, `prancha_dialogos.png`.
- GIFs Sophia (andar/combo/pesado/esquiva/magia/pulo) e chefes 10/37/64: `C:\gnosis-wt\_caps\qa-visual\extra\*_follow.gif`, tiras `anim_sophia.png`/`anim_chefes.png` (`r0/08_sophia_quadros.jpg`, `r0/10_sophia_combo.gif`, `r0/11_athoth_windup.gif`).
- Varredura automática: **0 pixels magenta** em 967 capturas (`tools/qa_visual/magenta.py`); emendas verticais no chão **7/68 → 0/68** (`tools/qa_visual/seams.py`; antes/depois `C:\gnosis-wt\_caps\qa-visual\crop_emenda_antes_depois.png`).

## 3. Re-teste dos 24 itens de `docs/QA_UX_BUGS.md`
Coluna r0 = base 589a751 (capturas). Coluna r1 = base b04f413 (o que já reverifiquei; "—" = ainda não reverificado nesta base).

| ID | r0 (589a751) | r1 (b04f413) | Evidência |
|---|---|---|---|
| B1 controle A/B | **CORRIGIDO** (ui_accept = A, ui_cancel = B; A entra em Nova campanha, B volta, A escolhe na tentação) | — | `C:\gnosis-wt\_caps\qa-visual\padprobe\log.txt` |
| A1 loja sem foco/Esc | **CORRIGIDO** (foco no 1º item, ↓ navega, Esc/B fecha; também no santuário) | — | `uiprobe\ui09_loja_pela_pausa.png`, `vis\log.txt` |
| A2 legenda sobre menus | **CORRIGIDO** na pausa/loja/opções/golpes. Resíduo baixo: durante o *fade-in* da loja do santuário a legenda ainda aparece por cima | — | `uiprobe\ui08..ui11`, `run\s24_end.png` |
| A3 tela 68 uma barra | AINDA OCORRIA | **CORRIGIDO** (duas barras: "O Rei — a Mentira" e "O Colosso Oco — a Verdade") | `r1/t68_inicio_rei_na_borda.jpg` |
| A4 morte congela no ar / de pé sem queda | AINDA OCORRIA (no ar y=219 fixo; de pé anim=idle) | — | `r0/03_A4_morte_sem_queda.jpg` |
| A5 câmera tira a Sophia do quadro | AINDA OCORRIA, generalizado (8/8 telas, fora em 15–27 de 30 amostras ao trancar a zona) | **CORRIGIDO** (0 quadros fora em 3 lutas filmadas) | `r0/01_A5_sophia_fora_do_quadro.jpg`; `r1/combate_*.jpg` |
| A6 escolha final estoura | PARCIAL (cabia; motivo do "Semente" só em tooltip) | **CORRIGIDO** (cabe e mostra "Semente: exige 4 Adormecidos…" abaixo dos botões) | `r0/06_A6_escolha_final.jpg`, `r1/cenaD_t68_falas.jpg` (escolha) |
| A7 sem dica de controles | AINDA OCORRIA | **CORRIGIDO (parcial)**: faixa de teclas no topo na tela 1 (A·D mover, Espaço…) e dicas contextuais ("U usar o Anel"); só vi teclas de teclado | `r1/cena_t1.png` (quadros 020+) |
| M1 legenda cobre pés/telegrafos | AINDA OCORRIA | **AINDA OCORRE, pior com o zoom 1,2**: com barra de chefe a faixa sobe e fica na altura das canelas/pés da Sophia (pés em y≈259/360; faixa começa ≈257) e cobre a névoa-telegrafo | `r1/M1_legenda_nos_pes_t10.jpg` |
| M2 toast colado no Anel | **CORRIGIDO** (toast centralizado; "roubados" separado) | — | `prancha_hud.png` (hud_68) |
| M3 itens indisponíveis parecem selecionados | **CORRIGIDO** (apagados + "Faíscas insuficientes · faltam 50") | — | `uiprobe\ui09_loja_pela_pausa.png` |
| M4 card × HUD | NÃO REPRODUZIDO em 1280×720 (HUD inteiro; legenda acima do card sem sobrepor). Não testei 1366×768 | — | `miscprobe\misc_esc_no_card.png` |
| M5 emendas 1 px | **CORRIGIDO** (7/68 → 0/68) | — | `crop_emenda_antes_depois.png` |
| M6 cura no meio do chefe | **CORRIGIDO** (Melhorias desabilitada com chefe vivo, com o porquê) | — | `vis\vis_pausa_chefe.png`, `VIS|pausa_chefe|…desabilitada=true` |
| M7 golpe abre a Estela | **CORRIGIDO** (não abre com inimigo perto/zona trancada) | — | `miscprobe\misc_estela_painel.png` |
| L1 B não volta no Ateliê/Bestiário | **CORRIGIDO** | — | `uiprobe\log.txt` (`B_volta`) |
| L2 nomes cortados no Bestiário | **CORRIGIDO** | — | `uiprobe\ui24_Gallery.png` |
| L3 Crônicas rolam 3 linhas | **CORRIGIDO** (0,25 s = 1 linha) | — | `miscprobe\log.txt` |
| L4 Sophia "fala" morta | AINDA OCORRIA | — | `uiprobe\ui15_morte.png` |
| P1 ornamentos sobre textos | Parece CORRIGIDO (pré-jogo/opções limpos) | — | `uiprobe\ui02_pregame.png` |
| P2 parede invisível / chão liso | PARCIAL (chão ganhou reflexo; câmera ainda mostra 90 px além da parede em r0) | — | `miscprobe\misc_camera_parede_esq.png` |
| P3 Provação só mostra teclado | AINDA OCORRIA | — | `uiprobe\ui26_provacao.png` |
| P4 "Esc / B fecham" mentia | **CORRIGIDO** (B agora é ui_cancel) | — | `padprobe\log.txt` |
| D1 user:// compartilhado | NÃO TESTÁVEL aqui (override.cfg isola os worktrees) | — | — |
| D2 vazamentos ao sair | AINDA OCORRE (inofensivo) | AINDA OCORRE | qualquer `.log` |

## 4. Regressões / achados novos
| ID | Sev. | Base | O quê / como reproduzir | Captura | Arquivo provável → dono |
|---|---|---|---|---|---|
| C1 | Média | r1 | Número de dano congelado durante cenas (ver P1) | `r1/B_t64_dano_congelado_e_dica_U.jpg` | `damage_number.gd` → **combate** / `staging.gd` → encenacao |
| C2 | Média | r1 | Dica de controle ("U · usar o Anel") fica visível durante cenas | idem | `hud.gd` → **ui-hud** |
| F1 | Média | r1 | Dano na Sophia = silhueta laranja-vermelha chapada | `r1/combate_t03_combo_pesado_esquiva_aparar.jpg` | `player.gd` → **combate** |
| F2 | Média | r1 | Tela 68: Rei e Colosso empilhados; Colosso e Rei fora do quadro na chegada | `r1/combate_t68_rei_e_colosso.jpg`, `r1/t68_inicio_rei_na_borda.jpg` | `final_battle.gd` → **encenacao** |
| M1+ | Média | r1 | Legenda na altura dos pés com o zoom 1,2 | `r1/M1_legenda_nos_pes_t10.jpg` | `caption_bar.gd` (`BOTTOM_Y`/acima da barra do chefe) → **ui-hud** |
| H1 | Baixa | r0 | `hud.gd:371` `_bar`: com vida quase 0 o "fantasma" da barra vira polígono degenerado → `ERROR: Invalid polygon data, triangulation failed` (13–23 por morte, spam no console) | log `C:\gnosis-wt\_caps\qa-visual\extra\hud_die.log` | `hud.gd` (`_wedge` com largura < 2×chanfro) → **ui-hud** (reverificar em r1) |
| H2 | Baixa | r0 | Contador de faíscas do HUD congela com a árvore pausada: atrás da loja mostra o valor velho (HUD 0 × loja 147, tela 19) | `run\s19_shop.png` | `hud.gd` `_process` → **ui-hud** |
| H3 | Baixa | r0 | Card do Campeão desenhado POR CIMA da loja do santuário quando o Campeão morre durante o card (só com morte muito rápida) | `r0/09_loja_card_e_rei_amarelo.jpg` | `cinematic.gd` → **encenacao** |
| T1 | Baixa (ferramenta) | r0 | `MiscProbe` (qa) quebra no caso da batalha final: `hud._boss_name` não existe mais (HUD nova) → SCRIPT ERROR e o processo não fecha | `miscprobe\log.txt` linha 55 | `tools/qa_ux/misc_probe.gd` → **qa** |
| V1 | ? (a confirmar) | r0/r1 | vsync ligado = 21–30 qps com janela fora do monitor (provável artefato do DWM) | seção 5 | **perf/tecnico** confirmar com janela visível |

## 5. FPS real (PerfTimeline = PerfProbe + espião de engasgos; 12 s medindo, Sophia atacando sem parar, arena cheia)
GPU AMD RX 7600, renderer `gl_compatibility`, janela 1280×720 fora do monitor, **vsync desligado** (com vsync ligado ver V1).

| Tela | criaturas | r0 qps médio / 1% low / mín | r0 ms médio / p99 / máx | r1 qps médio / 1% low / mín | r1 ms médio / p99 / máx |
|---|---|---|---|---|---|
| 3 | 12 | 189 / 97 / 70 | 5,3 / 9,2 / 14,3 | 150 / 63 / 20 | 6,7 / 12,7 / 48,8 |
| 3 | 24 | 135 / 65 / 23 | 7,4 / 12,5 / 43,8 | 116 / 59 / 51 | 8,6 / 15,4 / 19,7 |
| 22 | 12 | 181 / 89 / 71 | 5,5 / 9,9 / 14,0 | 182 / 90 / 76 | 5,5 / 10,2 / 13,2 |
| 22 | 24 | 111 / 56 / 21 | 9,0 / 14,4 / 47,2 | 116 / 52 / 21 | 8,7 / 15,0 / 47,9 |
| 50 | 12 | 169 / 73 / 22 | 5,9 / 11,0 / 46,0 | 159 / 69 / 21 | 6,3 / 11,6 / 46,8 |
| 50 | 24 | 132 / 59 / 21 | 7,6 / 13,5 / 47,7 | 117 / 57 / 21 | 8,6 / 14,1 / 47,5 |
| 64 | 12 | 191 / 83 / 22 | 5,2 / 9,6 / 45,7 | 166 / 67 / 21 | 6,0 / 10,0 / 46,7 |
| 64 | 24 | 141 / 65 / 23 | 7,1 / 11,8 / 43,7 | 123 / 54 / 18 | 8,1 / 13,4 / 55,8 |
| 68 | 12 | 176 / 86 / 74 | 5,7 / 10,7 / 13,5 | 146 / 78 / 40 | 6,9 / 11,3 / 24,7 |
| 68 | 24 | 115 / 48 / 21 | 8,7 / 17,5 / 48,5 | 104 / 48 / 19 | 9,6 / 16,7 / 52,5 |
A tela 3 da r1 foi refeita sozinha (a 1ª medição rodou junto com um script Python). **r1 ficou 10–20% mais lenta que r0** nas telas 3/64/68 (zoom 1,2 + VFX/juice novos) — ainda folgado: média ≥100 qps e 1% low ≥48 qps em tudo, pior quadro 60 ms.

**Engasgos (quando):** nenhum >100 ms em nenhuma medição (o engasgo antigo de 193 ms no 1º golpe NÃO apareceu). Padrões:
(a) **34–37 ms no quadro ~243** = quando a sonda despeja 4 criaturas por quadro (instanciar) — artefato da sonda;
(b) **1–2 quadros de 43–60 ms a cada 12 s** no meio da luta, sem relação com o início — provável desmembramento/gib ou VFX novo;
(c) **tela 68: 54–57 ms no 4º quadro** (carga da arena final).
Logs com cada engasgo: `C:\gnosis-wt\_caps\qa-visual\perf\*.log` e `...\r1\perf\*.log` (linhas `SPIKE|t=…|ms=…|fase=…`).

## 6. Ferramentas novas (só em `tools/qa_visual/`, nenhuma muda código do jogo)
`VisualProbe.tscn` (A3 final/A1-A2 loja do santuário/A4 morte de pé/A5 Sophia no quadro/A6 escolha/M6 pausa no chefe) ·
`CenaSeq.tscn` (filma cena encenada contínua) · `CombatSeq.tscn` (feel: combo/pesado/esquiva/aparar + meta com hitstop/zoom/câmera) ·
`PerfTimeline.tscn` (PerfProbe + engasgos com tempo) · `JitterProbe.tscn` + `jitter_csv.py` (tremor) · `shots.sh` (menus/HUD/diálogos/GIFs) ·
`perf.sh` · `anim_strip.py` · `seams.py` · `magenta.py`.

## 7. Limites honestos
- Sem controle físico e sem jogar de verdade: aparo, timing e "peso" precisam do João.
- vsync ligado não medível com a janela invisível (V1).
- Tremor: posição da Sophia reconstruída (o Godot não expõe a interpolada em 2D).
- As cenas foram filmadas com a CenaShot avançando as falas a cada 2 s (120 quadros) — o ritmo de leitura real é do jogador.
