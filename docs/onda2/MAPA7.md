# MAPA7: o segredo antes do Soter (Onda 7, diretor de mapa)

Branch `dir7/mapa7` (base `origin/integracao/onda1` 0a77007). Base técnica: `docs/onda2/MAPA6.md`.

## 1. O pedido
Na QA7 ("Para decidir"), os nós secretos aparecem antes do Soter (e0.6a, e1.3a) e ficam
fechados na 1ª jogada. **Decisão do chefe:** manter, porque é o gancho do "volte depois"
(estilo Hollow Knight), mas com sinalização clara para não parecer bug: ícone de pulo duplo
bloqueado, um texto curto "precisa de asas" e, depois do Soter, o ícone passa a "aberto".

## 2. O que mudou (`scripts/ui/world_map.gd`)
- **O ícone da Sala secreta agora são ASAS** (três penas de cada lado), o símbolo do pulo duplo.
  Antes era um olho, que não dizia nada sobre o requisito.
- **Selo no canto do nó:**
  - antes do Soter: cadeado fechado;
  - depois: cadeado aberto, dourado.
- **Rótulo por extenso em todo nó secreto que ainda vem:** "precisa de asas" (lilás) ou
  "aberta" (lilás claro).
  - Na trilha alta o rótulo fica acima do nó, para não pisar no nó de baixo.
- **Painel do nó secreto fechado:**
  - "Precisa de asas: só o pulo duplo alcança esta sala. Mais adiante, alguém te dá asas."
  - "Recompensa: escondida". O prêmio não é anunciado enquanto não dá para pegar
    (sem aversão à perda; NEURO §3).
- **Painel do nó aberto:** "Aberta: com as asas, esta sala está ao alcance." e o prêmio real.
- **Aviso único:** na 1ª tela de mapa depois do pulo duplo com um segredo à frente
  (`Narrative.once("mapa_asas_abertas")`, vai no save do run):
  - o subtítulo vira "Com as asas, as salas secretas se abrem.";
  - os segredos abertos ganham um halo que pulsa por 4 s;
  - nas telas seguintes, nada disso se repete.
- **Legenda:** o cadeado ganhou a entrada "precisa de asas (pulo duplo)".
- **Prévia fora de run:** `GNOSIS_MAP_ASAS=1` mostra o estado aberto.
- `tools/map6/map_shot.gd`: a captura agora acontece num **SubViewport 640×360**, então a
  janela pode ser 320×180 fora da tela (o João joga ao mesmo tempo).
  - Opções novas: `asas` e `rota=a,b,..`.
- `tools/map6/map_qa.gd`: 4 checagens novas do selo (detalhes na seção 3).
- i18n: 7 textos novos no lote `12_mapa6.tsv`; os 2 textos removidos saíram do lote.

## 3. Validação
- MapQA: **26 PASS**, exit 0. As 4 checagens novas do selo:
  - fechado / "precisa de asas" / prêmio escondido;
  - nó comum sem selo;
  - aberto com prêmio e aviso único;
  - o aviso não se repete.
- i18n: `build.py --strict` 1424/1424, 0 alertas; LangQA 12 ok; EnFit 0 falhas (67 avisos
  de UI que já existiam).
  - Armadilha: com `core.autocrlf=true`, o `strings.csv` do checkout vem com CRLF dentro dos
    campos multilinha e o `extract.py` toma 18 textos por "pt mudou". Antes de extrair:
    `git show HEAD:assets/i18n/strings.csv > assets/i18n/strings.csv`.
- validate.ps1 -Repeat 2: **TUDO VERDE (11 etapas, 2/2 cada)**: CodexQA 53, AudioQA 54, GnoseQA 20, SaveQA 49, TecnicoQA 43, LangQA.
- **Capturas** (`C:\gnosis-wt\_caps\mapa7\`), todas no estado real do run (SubViewport):
  - `antes_e0_L6_sem_asas.png`: o olho com um cadeadinho, sem explicar nada.
  - `depois_e0_L6_sem_asas_sel.png`: asas + cadeado, "precisa de asas" e o painel
    explicando, com o prêmio escondido.
  - `depois_e0_L6_sem_asas_en.png`: o mesmo em inglês.
  - `antes_e2_L2_com_asas.png`: depois do Soter, sem diferença visual de um nó comum.
  - `depois_e2_L2_com_asas.png`: "aberta" + cadeado dourado, prêmio à vista e o aviso
    "Com as asas, as salas secretas se abrem."

## 4. CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)

| Decisão | R / princípio atendido | Risco / violação e o que fiz |
|---|---|---|
| Segredo antes do Soter continua visível e fechado | Princípio 5 (SDT, autonomia: o mapa mostra o mundo inteiro, sem esconder o que existe); §3 ético: a "surpresa" vem da história (o Soter), não de sorte | Pode virar aversão à perda. **Correção:** o prêmio fica ESCONDIDO enquanto está fechado, e o texto diz por quê e quando ("mais adiante, alguém te dá asas"). Não há contador, timer nem FOMO |
| Ícone de asas + cadeado + texto ("forma + texto", não só cor) | §4 item 11 (cor não é o único aviso) e R5 (legibilidade por forma): dá para ler o estado mesmo sem distinguir o lilás | — |
| Aviso único "as salas secretas se abrem" | Princípio 4 (erro de predição positivo, raro): uma vez por run, ligado a uma conquista da história; R22 por analogia (nada que fique martelando) | Halo de 4 s a ~0,6 Hz, numa área pequena, sem clarão: R10 e §4 item 4 respeitados |
| Recompensas fixas e determinísticas por tipo de nó | §3 ético ("quantidade fixa e determinística — manter"); §4 item 12 (nada de recompensa variável manipulativa) | — |
| Tentar entrar num segredo fechado | Feedback informativo: som "voltar" + o texto do requisito acende | Sem punição, sem tremor (§4 item 1) |
| Mudança pequena e isolada (só a UI do mapa) | §4 item 13 (mexer em tudo de uma vez) | — |

**§4 conferido:** 1 (sem tremor) · 4 (sem clarão de tela) · 11 (forma e texto, além da cor) ·
12 (sem sorteio) · 13 (bloco pequeno). Não se aplicam (são de combate e som): 2, 3, 5, 6, 7, 8, 9, 10.

**Ponto honesto para o chefe:** como o pulo duplo é por run e o Soter só aparece em e1.L6
(tela 17), **e0.6a e e1.3a nunca abrem em nenhum run**. Elas funcionam como prenúncio, não como
"volte depois" de verdade. O texto não promete abrir AQUELA sala ("mais adiante, alguém te dá
asas"), e as salas de e2 em diante abrem de fato no mesmo run.
- Se o chefe quiser o "volte depois" literal, as opções são:
  - (a) trocar e0.6a/e1.3a por outro tipo em `EonMap.LANES`;
  - (b) pulo duplo persistente entre runs (decisão da progressao).

## 5. BILHETE PARA O SUCESSOR
- **Estado:** pronto. Último commit = o do relatório (ver `git log dir7/mapa7`).
- **Arquivos-chave:**
  - `scripts/ui/world_map.gd`: `secret_badge`, `_draw_seal`, `_draw_wings`, `_wings_news`;
  - `scripts/levels/map/eon_map.gd`: a tabela LANES/REWARDS;
  - `tools/map6/map_qa.gd`: `_seal_checks`;
  - `tools/map6/map_shot.gd`.
- **Rodar:**
  - `godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/map6/MapQA.tscn`;
  - captura: `--resolution 320x180 --position 4000,4000 res://tools/map6/MapShot.tscn -- <eon> <camada> <png> [rota=..] [asas] [mover=N]`.
- **Armadilhas:**
  - o CRLF do `strings.csv` (seção 3);
  - a MapQA ainda não está no `validate.ps1`; rode à parte.
