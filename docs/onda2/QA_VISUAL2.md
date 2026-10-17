# QA VISUAL — passada 2 (renderer real, PC do João)

Diretor de QA visual 2. Branch `dir4/qa-visual2`, base `origin/integracao/onda1` @ `eb46164`
(Ondas 1, 2, 2b, 3 e arte integradas). 17/10/2026.
Todo Godot com `--audio-driver Dummy`, janela 1280×720 no canto (`--position 1200,600`).
Máquina: Ryzen 5 5600G, RX 7600, monitor 144 Hz (+ 2º monitor). **Durante as medições havia ~12 outros
processos Godot de outros diretores rodando** (não são meus; não mexi).

Capturas completas (fora do git): `C:\gnosis-wt\_caps\qa-visual2\` — `run\` (68 telas), `pranchas\`,
`ux\` (menus/HUD), `r2\` (arma, NPCs, Estela), `cine\` (prólogo e epílogos), `cena\t{1,64,65,68}\`,
`combate\c{3,10,68}\`, `fp\` (FlashParryProbe), `vis\` (VisualProbe), `abertura\`, `fps\`.
Reduzidas (≤ 300 KB cada) versionadas: `docs/onda2/qa_visual2_caps/` (30 imagens, numeradas abaixo como `[NN]`).

---

## TOP PROBLEMAS POR DONO (o que ver primeiro)

| # | Sev. | Dono | O quê | Prova |
|---|---|---|---|---|
| 1 | **Alta** | encenação | **A caixa de diálogo esconde a Sophia (e às vezes o interlocutor) nas cenas que não "sobem o quadro".** Cena A (tela 1: "Olha: alguém vem da névoa"/"Faísca perdida…" — só se vê o Rei, a Sophia está atrás da caixa), chegada da Mente (68, d1: ninguém no quadro, só o fundo), roubo (64: Sophia atrás da caixa, só a ponta do cajado), diálogos comuns (Sophia/Yaldabaoth na tela 11). O D_LIFT da Encenação 3 só vale p/ tentação, Soter e Velkar. | [16] [17] [22] [20] |
| 2 | **Alta** | arte | **Tela 64: depois de "a máscara cai", a cabeça do Rei é um DISCO PRETO liso com um círculo branco** (desenho procedural) sobre o corpo pintado — destoa muito da arte e fica cortada no topo do quadro; o retrato da caixa mostra outra coisa (máscara rachada com olho). Dura ~7 falas. | [17] [21] (c_027–c_033) |
| 3 | Média | cenário / encenação | **Tela 17: no encontro com o Soter, ele fica ATRÁS de um pilar escuro de primeiro plano** (só a borda branca aparece) durante todas as falas. A Encenação 3 já sabia ("é do cenário"). Mesmo pilar corta o quadro da 61 (Velkar visível, mas uma faixa preta de ~25 % da tela no meio). Na 17 ainda se empilham Estela + Selos ("OS TRÊS SELOS / golpeie na ordem…") + Soter no mesmo descanso. | [02] [03] |
| 4 | Média | ui-hud | **Legenda no topo colide com o card de chefe**: na tela 68 "As duas formas precisam cair juntas." fica por cima de "YALDABAOTH" e do subtítulo, tudo sobre a cabeça do Rei. Efeito colateral do M1 (legenda foi pro topo). Só acontece quando há legenda viva quando o card nasce. | [14] |
| 5 | Média | ui-hud | **Toast de conquista aparece NO MEIO da cena** (68: "Conquista · Memória inteira" sobre o Rei, durante "As duas formas caem juntas…"; 64: "Conquista · …" na fala do Armupiel). Também as **barras dos 2 chefes continuam visíveis** (esmaecidas) sob a rubrica da cena D. O C2 esconde dicas/combo/faíscas, mas não o toast nem as barras. | [19] [21] c_010 |
| 6 | Média | encenação / ui | **Cena D: o retrato da fala "…mãe? eu não queria ser cego" é o Rei de máscara rachada**, mas quem fala é o Cego pequeno (que agora aparece bem — pintado, ao lado da Sophia). O retrato contradiz a imagem. | [18] |
| 7 | Média | combate | **Contorno de telegrafo (amarelo) está forte demais**: contorno duplo branco+amarelo de ~2 px (base 640) com brilho, serrilhado, em todo inimigo em WINDUP — lê como "objeto selecionado no editor"/neon. Nos Éons Praga/Coroa (47–57) quase todo quadro tem um inimigo assim. Funciona como aviso; esteticamente pesa. Sugestão: 1 px, menos saturado, pulsar em vez de fixo. | [10] [11] [23] |
| 8 | Média | combate | **Flash de golpe/aparo nos INIMIGOS ainda é branco quase chapado** (o mesmo defeito do F1, agora do outro lado): no aparo o cavaleiro vira silhueta branca; o Rei na 68 apanhando fica branco-estourado. O F1 da Sophia ficou bom (camada aditiva curta). | [12] (aparo), [26] (s68_fight0) |
| 9 | Baixa | encenação | NPCs: durante as falas do Soter/Velkar **a Sophia fica congelada no meio da passada de corrida** (o mundo pausa no quadro em que ela encostou). Deveria ir para idle/parada antes da 1ª fala. | [02] [03] |
| 10 | Baixa | ui-hud | **Topo da tela carregado nas travessias**: HUD + faixa de dicas ("U · usar o Anel equipado (gasta Éter)") + legenda de 2 linhas em fonte grande ocupam ~¼ da altura. Não cobre jogo, mas pesa. (A dica do Anel aparece em quase toda tela na sonda porque cada tela é um processo novo — artefato; num run real aparece 1×.) | [23] [24] [25] |
| 11 | Baixa | encenação | Tela 68/64: depois que os chefes caem, **dois "borrões" brancos com ponto preto** (restos luminosos) ficam parados no chão a cena inteira — lêem como bug/objeto solto, não como "o Colosso se abriu". | [18] [20] |
| 12 | Baixa | narrativa | Tela 17: depois de falar com o Soter, a Voz diz "Dizem que um tal Soter anda por estas bandas. Eu nunca o vi." (legenda de chegada atrasada na fila). Pode ser intencional (a Voz mente), mas o tempo faz parecer erro. | [02] (depois) |
| 13 | Baixa | ui | Textos de tecla fixos ainda no teclado: painel da Estela "Esc fechar", cards do prólogo/epílogo "qualquer tecla avança · Esc pula". (A Provação já troca para o controle — P3 ok.) | [04] [05] |
| 14 | Baixa | arte | Retratos por emoção: coerentes entre si; os da Sophia (cel/anime) são um pouco mais "desenho" que o retrato do HUD (pintado). Não incomoda. | `C:\gnosis-wt\_caps\qa-visual2\portraits.png` |

**Técnico:** nenhum problema novo. FPS com o padrão das Opções está bom (ver §5). 0 `SCRIPT ERROR`, 0 `Invalid polygon`, 0 magenta, 0 emendas.

---

## 1. Validação — `tools/validate.ps1 -Full`
```
  VERDE     Scripts          8,4s    0 PASS
  VERDE     ScriptCheck      8,4s    0 PASS
  VERDE     CodexQA         16,6s   53 PASS
  VERDE     AudioQA         29,2s   54 PASS
  VERDE     GnoseQA         19,2s   18 PASS
  VERDE     SaveQA           6,5s   49 PASS
  VERDE     PuppetQA         5,7s    0 PASS
  VERDE     HeroQA           3,3s    0 PASS
  VERDE     WaveQA           3,7s    0 PASS
  VERDE     TecnicoQA        8,4s   43 PASS
  VERDE     CodexPlaytest   42,5s    1 PASS
TUDO VERDE (11 etapas)
```
Depois de adicionar as sondas novas: ScriptCheck `155 scripts, 0 com erro`; editor headless 0 `SCRIPT ERROR`.
Outras conferências rodadas com janela real: **UxShots** `UX NAV: 9 ok, 0 falha(s)` · `UX CHECK: 13 ok, 0 falha(s)`;
**FlashParryProbe** (combate) 19 `QA PASS`, 0 FAIL.

## 2. Re-teste dos itens abertos da passada 1

| ID | Estado | Evidência |
|---|---|---|
| **M1** legenda nos pés | **CORRIGIDO** — legenda no topo (faixa y 66, 420 px de largura na base 640), longe dos pés e dos telegrafos em todas as 68 telas. **Efeito colateral novo:** colide com o card de chefe (problema #4) e carrega o topo (#10). | [23] [09] (`hud_arconte_legenda`), UX CHECK M1 OK |
| **C1** número de dano congelado na cena | **CORRIGIDO** — nenhum número parado nas cenas 1/64/65/68; FlashParryProbe: "número some com o mundo pausado" e "some quando a caixa abre" PASS. | [20] [21], `fp\log.txt` |
| **C2** dica de controle durante cena | **CORRIGIDO** (dicas/combo/faíscas somem; UX CHECK alpha 0,00). **Mas** toast de conquista e barras de chefe ainda aparecem na cena (#5). | [19] |
| **F1** flash de dano da Sophia chapado | **CORRIGIDO** — em luta real (tela 3, 4 golpes recebidos) a Sophia mantém a textura, só aquece; FPPROBE pico 0,36, ≤100 ms, "Reduzir flashes" corta à metade. | [13] [12] |
| **F2** Rei e Colosso empilhados/fora do quadro (68) | **CORRIGIDO** — Rei x=258 e Colosso x=504 (de 640) na chegada, os dois no card, separados durante toda a luta, 2 barras. | [15] (final_inicio), [29] |
| **C3** card de chefe com o chefe fora do quadro | **CORRIGIDO** — Athoth (10) no quadro durante o card; Rei (1) no quadro com caminhada real; Yaldabaoth (68) os dois no quadro. | [30] [16] (a_012) [14] |
| **P3** Provação só com ícones de teclado | **CORRIGIDO** — faixa com glifos do controle (Analógico, A, X/Y, B, LB, RB, RT). | [27] |
| **H2** faíscas congeladas atrás da loja | **CORRIGIDO** — UX CHECK "faíscas do HUD atrás da loja = 282 (HUD 282)". | `ux\log.txt` |
| **H3** card do Campeão por cima da loja | **NÃO REPRODUZIDO** (corrigido por leitura na Encenação 3). Na tela 6 a loja abre com a barra do Campeão ainda sumindo, sem card por cima. | `run\s06_shop.png` |
| **Cena D** "pequeno" = disco preto | **CORRIGIDO** — Cego pequeno pintado, ao lado da Sophia, lê como alguém. Novo: retrato errado na fala dele (#6). | [18] |
| **Aparo** sem VFX/confirmação | **PARCIAL / funciona na sonda** — FlashParryProbe: aparo toca os quadros `parry` (estrela + arco), abre janela de 0,40 s, contra-ataque `riposte` acerta (dano 36). Na luta automática (CombatSeq) o "block" entra, mas o tempo do aparo continua dependendo da mão do João. | [12] (aparo, contra_ataque) |
| **Flash** (telegrafo do chefe) | **CORRIGIDO na forma** (contorno, corpo não é pintado — FPPROBE `modulate=(1,1,1,1)`), **mas exagerado na intensidade** (#7). | [10] |
| **V1** vsync ~21 qps | **CORRIGIDO** — padrão VSync desligado + teto = taxa do monitor: 144/140 qps (§5). | `fps\t22.log`, `fps\t68.log` |
| A3/A4/A5/A6/M6/B1 (passada 1 já corrigidos) | **Seguem corrigidos** — VisualProbe: 2 barras na final; morte de pé faz `anim=dead`; Sophia no quadro 0/30 fora em 8 telas; 3 botões da escolha cabem (Semente com motivo); Melhorias trancada com chefe; A do controle escolhe na tentação. | `vis\log.txt`, [15] |

## 3. Passada nas 68 telas + menus + cenas + epílogos + prólogo

- **RunProbe com janela real, modo fight (68 telas, 2 em paralelo): `TOTAL: 68/68 telas avançaram · telas com BUG?: 0 · telas com ERROR: 0`**; 68 termina no EndScreen; chão y 285,9–286,0 em todas. Resumo: `C:\gnosis-wt\_caps\qa-visual2\run_all.txt`. Pranchas (9): `C:\gnosis-wt\_caps\qa-visual2\pranchas\prancha_*.png`.
- **Varreduras:** 0 pixels magenta em 369 + 36 + 98 + 43 capturas; 0 emendas verticais no chão em 68/68; 0 `Invalid polygon` (H1) em todos os logs.
- **Menus** (UxShots): menu novo com a ilustração lê muito bem [08]; pré-jogo, Golpes, Opções, Ateliê, Bestiário, Crônicas (afresco + texto longo cabe), Créditos, fim (vitória/derrota), pausa, loja — sem corte nem sobreposição [07]. Observações: a captura "menu sem save" pega os botões ainda no fade-in (só uma placa cinza) — o fade do menu é longo (> ~0,5 s); o aviso "Um progresso de versão anterior foi descartado…" fica em texto amarelo direto sobre a pintura, sem placa (legível).
- **Prólogo:** 3 cards × 2 ilustrações (01→06), fusão no meio, legenda no terço inferior — bonito e legível, 21 s [05].
- **Epílogos (Ascensão/Ruptura/Semente):** ilustração 10/11/12 sob título e cards, sem piscar; Crônicas, créditos e "...mãe?" no preto [06]. (O título "ASCENSAO" sem til na captura é da sonda, que preenche `end_title` com o id.)
- **Cenas:** A (1) com caminhada real (AberturaShot): Rei sai da névoa como silhueta, acende, card, duelo com câmera lenta no 1º telegrafo [16]. B (64): Armupiel, gemas saem uma a uma, ilustração 07 no clarão da máscara [21]. C (65): ilustração 08 da queda, preto + "Silêncio", Centro [`cena\cena_t65.png`]. D (68): Anéis voltam, Colosso encolhe, Cego pequeno, ilustração 09 no abraço, escolha, epílogo [20].
- **Arcontes (chegada/luta):** todos no quadro com barra; Harmas textura cheia (sem fantasma); Astaphaios branco por ser o Espelho [26].
- **Inimigos dos Éons novos** (sonâmbulo, glutão, carcereiro, mudo, reflexo, esporos, pretoriano): arte própria em todos, escala coerente, sem transparência indevida; os "ecos" do Centro são translúcidos de propósito [24] [25].
- **Arma da Sophia nível 5:** cristal com halo branco-dourado + anel de luz, visível parada, no pesado e no leve; nível 1 só o cristal azul. Lê bem, sem exagero [01].
- **Estela:** painel com afresco + texto + fonte, "nova Crônica 1/18" [04].
- **NPCs:** Soter (17) escondido atrás do pilar (#3); Velkar (61) ajoelhado e visível, retratos `arrependido`/`triste` trocam por fala [02] [03].

## 4. Regressões novas desta integração (lista checada)
| Pedido | Resultado |
|---|---|
| Retratos por mood na caixa | Funcionam (Sophia choque/triste, Rei revelado, Velkar arrependido, Soter triste). Problema: retrato do Rei na fala do Cego pequeno (#6). |
| Legenda no topo cobrindo HUD/chefe? | Não cobre HUD nem barra de chefe. **Cobre o card de chefe** (#4). Topo carregado (#10). |
| Estelas | OK (painel e Crônicas com afresco). "Esc fechar" só teclado (#13). |
| Menu novo | OK. |
| Contorno de luz nos inimigos exagerado? | **Sim, o de telegrafo** (#7). O contorno discreto do Éon (verde/rosa escuro) está bom. |
| Arma da Sophia nível 5 | OK [01]. |
| Inimigos dos Éons novos | OK [24] [25]. |
| Fantasma/transparência | Nenhum fantasma indevido (Harmas ok). |
| Cego pequeno | OK (#6 à parte). |
| NPCs | #3 e #9. |
| Cards de chefe | Chefe no quadro em 1/10/68; colisão com legenda (#4). |

## 5. FPS real com janela visível (padrão das Opções, user dir do worktree — save real NÃO tocado)
Ferramenta do Técnico `tools/perf/FpsReal.tscn` (não mexe em VSync/max_fps; vale o que o boot aplicou), janela 1280×720 em 1200,600, 25 s medindo, Sophia batendo.
Boot aplicou: `settings_vsync=false`, `vsync_mode=0`, `max_fps=144`, `refresh_hz=144`, `gl_compatibility`, RX 7600.

| Tela | qps médio | 1% low | ms médio / p99 / máx |
|---|---|---|---|
| 22 | **143,9** | 97,8 | 6,95 / 8,15 / 18,95 |
| 68 | **140,2** | 84,1 | 7,13 / 10,50 / 19,86 |
| 22 com `vsync=1` forçado (comparação) | 130,6 | 64,8 | — |

Conclusão: **V1 resolvido** — o jogo roda colado no teto de 144 qps com o padrão, pior quadro < 20 ms, com ~12 outros Godot dos colegas rodando ao mesmo tempo. Curioso: hoje o vsync forçado também deu 130 qps (na passada 1 dava ~21–25); não investiguei a causa (driver/posição da janela/carga).

## 6. Limites honestos
- Sem controle físico: aparo, timing e "peso" continuam precisando do João.
- As sondas de cena (CenaSeq/CenaShot) **teleportam a Sophia**: na tela 1 isso faz o Rei-figurante e o Rei de verdade aparecerem lado a lado no card [28] — **artefato da sonda** (com caminhada real, AberturaShot, há um Rei só [16]). Também por isso, na CenaSeq da tela 1 o Rei não aparece nas falas — com caminhada real ele aparece.
- A legenda/dica "U · usar o Anel" em toda tela é da RunProbe (processo novo por tela).
- FPS medido com outros processos Godot ativos (de outros diretores) — os números reais devem ser iguais ou melhores.
- Não joguei o run inteiro sem cortes; a RunProbe limpa a zona após 5 s de briga.

## 7. Ferramentas (só `tools/qa_visual/`, nenhuma muda o jogo)
Importadas da passada 1 (`origin/dir2/qa-visual`) + novas:
- `Regress2Probe.tscn` / `regress2_probe.gd` — casos `arma=N`, `npc=T` (chega andando, mata quem nasce, foto por fala com speaker/mood), `estela`, `epi=<final>`, `prologo`.
- `run_window.sh` — RunProbe nas 68 telas com janela real no canto (`POS`, padrão 1200,600).
- `grid.py` (grade rotulada de PNGs), `to_jpg.py` (JPEG ≤ N KB p/ o relatório).
- `shots.sh`/`perf.sh` agora usam `POS` (padrão 1200,600) em vez de 4000,4000.

## 8. Pedidos aos donos (resumo)
- **encenação:** #1 (subir o quadro/centralizar falante+Sophia acima da caixa em TODAS as cenas: rei, final_pre, roubo, anagnórise), #6 (retrato do Cego pequeno), #9 (Sophia idle no NPC), #11 (restos luminosos), #3 junto com cenário.
- **arte:** #2 (cabeça do Rei sem máscara: pintar ou usar o retrato `rei_revelado` recortado), #14.
- **cenário:** #3 (tirar/mover o pilar de primeiro plano das telas 17 e 61, ou mover o ponto do NPC; separar Estela/Selos/Soter na 17).
- **ui-hud:** #4 (legenda sai/abaixa enquanto há card de chefe), #5 (segurar toasts e esconder barras durante cena), #10, #13.
- **combate:** #7 (telegrafo mais fino/menos saturado), #8 (flash dos inimigos aditivo/parcial como o F1).
- **técnico:** nada.
