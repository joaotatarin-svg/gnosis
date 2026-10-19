# MAPA7: o segredo antes do Soter (Onda 7, diretor de mapa)

Branch `dir7/mapa7` (base `origin/integracao/onda1` 0a77007). Base técnica: `docs/onda2/MAPA6.md`.

## 1. O pedido
Na QA7 ("Para decidir"), os nós secretos aparecem antes do Soter (e0.6a, e1.3a) e ficam
fechados na 1ª jogada. **Decisão do chefe:** manter, porque é o gancho do "volte depois"
(estilo Hollow Knight), mas com sinalização clara para não parecer bug: ícone de pulo duplo
bloqueado, um texto curto "precisa de asas" e, depois do Soter, o ícone passa a "aberto".

## 1b. DECISÃO FINAL (chefe, 19/10): nenhum cadeado que não abre
Na 1ª entrega descobri que **e0.6a e e1.3a nunca abriam em nenhum run**: o pulo duplo é por
run e o Soter só aparece na tela 17 (e1.L6). Pelo §4 da satisfação, isca impossível frustra.
Por isso:

- **Novo tipo `hidden` — Câmara oculta:**
  - ícone de chave, sem requisito;
  - **mesmo prêmio** da sala secreta (`EonMap.REWARDS["hidden"]` = `["secret"]`);
  - substitui o segredo em **e0.6a** (Torpor, camada 6) e **e1.3a** (Fome, camada 3).
- **A sala de asas (`secret`, asas + cadeado)** agora só existe depois da tela 17, onde abre
  no mesmo run.
  - A MapQA garante: nenhum nó que exige pulo duplo em tela ≤ 17.
- O pulo duplo continua por run; a progressão não foi tocada.
- **Layout `oculta`:**
  - torres de um pulo por degrau com baú secreto no topo, mais um perigo opcional no chão
    entre as zonas;
  - **sem saliência de pulo duplo**;
  - a LayoutQA confere que os baús alcançam com pulo simples: e0.6a e e1.3a com 2 baús cada.
- **Mudanças pequenas em arquivos de outros donos**, comentadas com "mapa7":
  - `scripts/levels/layouts/screen_layouts.gd` (level6): o caso `"oculta"` e o mapeamento
    `"hidden" → "oculta"`;
  - `scripts/ui/run_labels.gd` (ui): `"hidden"` em `NODE_KINDS`, para o HUD dizer
    "Torpor · Câmara oculta".
  - Sem isso, o tipo novo cairia num corredor genérico, sem o segredo prometido.
- **Legenda do mapa:** entra "Câmara oculta"; sai a entrada do cadeado (o selo fechado virou
  caso de borda; continua desenhado se faltar o pulo duplo depois da 17).
- **Validação (commit 26d28b3):**
  - MapQA 28 PASS (novas: "nenhum cadeado antes do Soter", "câmara oculta escolhível sem
    pulo duplo", "nó comum e câmara oculta não têm selo"; o selo é testado na sala do Éon 2);
  - LayoutQA: 1251 verificações em 129 telas, PASS;
  - i18n `--strict` 1425/1425;
  - validate.ps1 -Repeat 2: **TUDO VERDE (11 etapas, 2/2)**.
- **Capturas** (`C:\gnosis-wt\_caps\mapa7\`):
  - `final_e0_L6_camara_oculta.png` e `final_e0_L6_camara_oculta_en.png`: chave, sem cadeado,
    prêmio à vista;
  - `final_e1_L3_camara_oculta.png`;
  - `final_e2_L2_sala_asas_aberta.png`: asas + cadeado aberto + o aviso único.

### 1c. Saliências de pulo duplo dentro das fases (fechado por mim, autorizado pelo chefe)
- **O problema:** o level6 punha uma saliência de pulo duplo com baú e setas apagadas no
  chão (`dj_cache`) nos layouts `chegada` e `segredo` também nas telas 2–16, antes do Soter.
  Era um baú à vista que não se alcançava.
- **A correção** (`scripts/levels/layouts/screen_layouts.gd`, `_high_cache(screen)`):
  - antes da tela 17 o baú alto vira uma **torre de pulo simples** (`tower_cache`);
  - da 17 em diante a saliência de pulo duplo volta, porque aí ela se alcança.
- A sala secreta (`vault`) já era só do tipo `secret`, que agora só existe depois da 17.
  `level.gd` não tinha estrutura de pulo duplo.
- **Validação:**
  - MapQA confere no plano de layout de todo nó das telas 2–16 que não há `dj_cache` nem
    `vault` (28 PASS);
  - LayoutQA: 1246 verificações em 129 telas, PASS (baú de torre alcançável com pulo simples);
  - validate -Repeat 2: ver o relatório.

### Pedido restante
- **narrativa:**
  - Uma fala de chegada para `"hidden"` em `Narrative.node_arrival` (hoje fica muda).
  - Sugestão: "(Uma torre esquecida. Lá no alto, alguém guardou alguma coisa.)".

## 2. O que mudou na 1ª entrega (`scripts/ui/world_map.gd`)
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
| ~~Segredo antes do Soter visível e fechado~~ → **Câmara oculta** (e0.6a, e1.3a), livre e com o mesmo prêmio | §4 / §3: nenhuma isca impossível. Antes do Soter, todo nó que aparece no mapa pode ser tomado. Princípio 5 (autonomia: escolha real); competência (o baú alto se alcança com pulo simples e atenção) | A 1ª versão violava: cadeado em sala que nunca abria no run. **Corrigido** (decisão do chefe). O selo fechado ficou só como caso de borda depois da 17 |
| Ícone de asas + cadeado + texto ("forma + texto", não só cor) | §4 item 11 (cor não é o único aviso) e R5 (legibilidade por forma): dá para ler o estado mesmo sem distinguir o lilás | — |
| Baú alto antes do Soter = torre de pulo simples (o `dj_cache` só da tela 17 em diante) | §4/§3: nada prometido fora de alcance; competência (achar e subir a torre) | Antes, setas apagadas e baú inalcançável nas telas 2–16. **Corrigido** |
| Aviso único "as salas secretas se abrem" | Princípio 4 (erro de predição positivo, raro): uma vez por run, ligado a uma conquista da história; R22 por analogia (nada que fique martelando) | Halo de 4 s a ~0,6 Hz, numa área pequena, sem clarão: R10 e §4 item 4 respeitados |
| Recompensas fixas e determinísticas por tipo de nó | §3 ético ("quantidade fixa e determinística — manter"); §4 item 12 (nada de recompensa variável manipulativa) | — |
| Tentar entrar num segredo fechado | Feedback informativo: som "voltar" + o texto do requisito acende | Sem punição, sem tremor (§4 item 1) |
| Mudança pequena e isolada (só a UI do mapa) | §4 item 13 (mexer em tudo de uma vez) | — |

**§4 conferido:** 1 (sem tremor) · 4 (sem clarão de tela) · 11 (forma e texto, além da cor) ·
12 (sem sorteio) · 13 (bloco pequeno). Não se aplicam (são de combate e som): 2, 3, 5, 6, 7, 8, 9, 10.

**Ponto honesto (resolvido):** e0.6a e e1.3a nunca abriam em nenhum run. Agora são Câmaras
ocultas, sem pulo duplo (ver §1b). As saliências de pulo duplo dentro das telas 2–16
também foram trocadas por torres de pulo simples (§1c).

## 5. BILHETE PARA O SUCESSOR
- **Estado:** FINAL. Câmara oculta antes do Soter; sala de asas só depois da 17 (ver `git log dir7/mapa7`).
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
