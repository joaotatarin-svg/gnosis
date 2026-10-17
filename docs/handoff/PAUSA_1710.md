# PAUSA — 17/10/2026 (~19h BRT). Retomar na próxima semana NESTE MESMO CHAT.

> Motivo: limite semanal de uso. O João volta na semana que vem (e vai assinar o Max 20x no mês que vem).
> Ao retomar: `git fetch`, leia ESTE arquivo, `C:\gnosis-wt\_ONDA6.md` (cópia em docs/handoff/ONDA6.md),
> `C:\gnosis-wt\_REGRAS.md`, e retome cada agente pelo ID abaixo (SendMessage) — eles guardam o contexto.
> Todo trabalho não validado foi salvo como commit "WIP (pausa 17/10/2026)" no branch de cada agente e enviado ao GitHub.

## 1. Estado da integração
- `origin/integracao/onda1` = **ac04adc** — VALIDADO (validate.ps1 -Repeat 2: TUDO VERDE, 11 etapas).
  Contém: Ondas 1–4, Onda 5 (UI5, Cenário5, Estab5, Encenação5 até o push dela), i18n (PT/EN), arte desenhada
  (Sophia/9 chefes/criaturas/bots/NPCs + fluidez da Fila 7), loja v2, correção de FPS.
- **NÃO integrado ainda** (integrar na retomada, nesta ordem sugerida, validando com `-Repeat 2` a cada merge):
  1. `dir6/mapa6` (PRONTO, validado no branch — mapa não linear + WorldMap). Conflito esperado só em assets/i18n
     gerados → resolver com `python tools/i18n/extract.py && python tools/i18n/build.py --strict`.
  2. `dir4/loja2` commit 82db035 (loja v3 com keyart_capsule_b; prancha `assets/store/board3.png`) — só assets.
  3. Os branches da Onda 6 abaixo, quando cada agente fechar (hoje todos têm WIP não validado).
  4. `dir4/qa-visual2` (só docs/sondas) — opcional.
  5. `dir4/balance4` — OBSOLETO (o combate/economia mudaram); usar só como referência de dados.
- Prévias jogáveis no Desktop: "GNOSIS - prévia da noite" e "GNOSIS - prévia 2" (save separado GNOSIS-Previa).
  A prévia 3 (Onda 6) NÃO foi gerada ainda.

## 2. Agente por agente — onde parou e o próximo passo EXATO
| Agente (ID p/ SendMessage) | Branch / worktree | Feito | ÚLTIMA AÇÃO em curso quando caiu | Falta |
|---|---|---|---|---|
| Combate da Sophia (`ac91e006dd14a1679`) | dir6/combate6 · C:\gnosis-wt\combate6 | aéreo forte com preparo, 1 uso por pulo e recarga; dano reduzido (nv5 leve 36→13); ritmo; curvas de movimento; buffers; pulo duplo travado pela flag | "Final validation run, then commit" | validate.ps1 + CombatTest, bot curto, GIFs, docs/onda2/COMBATE6.md, pedidos, push |
| Inimigos (`a1cad7526b957d379`) | dir6/inimigos6 · C:\gnosis-wt\inimigos6 | 2–3 golpes por tipo, 2 voadores (espectro, alado) + fantasma flutuante, fila de agressão, guarda/esquiva, elites, Campeão com moveset próprio, flash aditivo, alado/fantasma/cornudo sem cara de Arconte | "Renomear `gravity` → `arc_gravity` (Area2D já tem) e aplicar o barrier fix" | 3 golpes que não saem, GIFs, i18n do nome novo, validate, docs/onda2/INIMIGOS6.md, pedidos, push |
| Chefes (`ae20f222985757121`) | dir6/chefes6 · C:\gnosis-wt\chefes6 | base: cérebro de 3 fases, postura, repulsão, perigos telegrafados, morte-momento `boss_dying`, sonda; Athoth (137 s / 38 golpes) e Harmas em ajuste | "Escrever o arquivo de pedidos (contrato para os outros diretores)" | Galila, Yabel, Astaphaios, Belias, Armupiel, Rei, batalha final, GIFs, validate, relatório (estimativa 5–7 h) |
| Progressão (`a12e4826193c6e855`) | dir6/progressao6 · C:\gnosis-wt\progressao6 | economia, selos de nível, relíquias, `has_double_jump()`/`grant_double_jump()`, ProgQA, i18n | "validate.ps1 completo" | merge de dir6/mapa6 + recalibrar `EonMap.REWARDS`, validate verde, docs/pedidos, push |
| Mapa (`a52e979d4b27b3d1f`) | dir6/mapa6 | **PRONTO** (grafo por Éon, WorldMap, MapQA 22/22, bot percorre o mapa) | — | só integrar (item 1.1) |
| Level design (`a26501ca366c147cb`) | dir6/level6 · C:\gnosis-wt\level6 | tabela de layouts, 12 perigos/objetivos (névoa, pedra do sono, boca, pêndulo, badalo, silêncio, feixe/reflexo, esporos, guilhotina, lanças/correntes, cacos, maré escura, totem, luz a proteger, baú secreto c/ pulo duplo) | "Reescrever o cabeçalho e o plano para despachar por `node_kind()`" | merge mapa6 + layout por node_kind (inclui sala trancada por pulo duplo), contrato `fg_guard`/`fg_forbidden` do cenário, bot antes/depois, pranchas, i18n, validate, docs |
| Encenação + Narrativa (`abd5ee8054a96213f`) | dir5/encenacao5 · C:\gnosis-wt\encenacao5 | Onda 5 fechada (quadro de diálogo, Sophia idle, "O Cego", Rei revelado pintado, fendas de luz, Rei afunda recortado) | "Corrigir `has_pose` para ler `meta.states`" | (a) usar `fx_floor_crack_a` como efeito PRINCIPAL e GRANDE no roubo; Estela na frente da Sophia em 64/68; (b) NARRATIVA da Onda 6 (0%): legendas fora do combate, ensino por Éon/mecânica, Soter concede o pulo duplo (+ mini-desafio), `card_hint()` nos cards |
| Arte — integrador (`a2302ccd2e94889bc`) | dir2/arte-gpt · C:\gnosis-wt\arte-gpt | Rei revelado (5 estados) + retratos (Rei e 4 humores do Cego) | "Adicionar o código da sequência de morte" | morte de chefe com peso (cambaleio → joelhos → pausa → estilhaça em cacos da pintura), máscara presa por âncora por quadro, integrar a Fila 9 (s17 pulo duplo, s18 arrancada/freada/virada, mariposa, sentinela, campeões 1–3+, rachadura, Soter) |
| Produção GPT (`a01b86e2baa91eb90`) | C:\gnosis-wt\_gpt\out (+MANIFESTO.md) | s17, s18, fly_mariposa, fly_sentinela, fx_floor_crack_a, champ_1–3 (4–6 geradas/gerando) | "Chat do Pretoriano carregado; enviando o Campeão 7" | Campeões 4–7 (conferir quais baixaram), alado/fantasma/cornudo, Soter abençoando |

## 3. NOVO PLAYTEST DO JOÃO (17/10, noite) — prioridade da próxima onda
O equilíbrio melhorou ("bem mais equilibrado"; no difícil ele se bateu para vencer o Rei — ok, é iniciante). Mas:
1. **O Rei/Demiurgo tem UM ataque só** (bola de luz). Na fase 1 a bola sai do OLHO DE CIMA, numa altura que a
   Sophia nem alcança → inútil. Na fase 2 só solta mais uma bola. **Esse padrão pobre se repete em TODOS os chefes e mobs.**
2. **A dificuldade vem do jeito errado**: ele tomava dano AO ACERTAR os inimigos (contato/hitbox), não pelos ataques deles.
3. **CORRIGIR A HITBOX DE TODOS OS PERSONAGENS** — "o cajado atravessa", dá aflição. (Cuidado para não ficar apelão
   pelo alcance.) → revisar hurtbox/hitbox de Sophia, mobs e chefes; dano de contato só onde fizer sentido.
4. **Mais variedade de golpes nos adversários**: corpo a corpo, à distância, alguns só à distância, e variações.
5. **Projéteis/ataques "preguiçosos"** (tanto os da Sophia quanto os dos mobs): querem BRILHO, cara de jogo PREMIUM
   (trilhas, núcleo, glow, impacto, partículas, telegrafo, som).
6. Ele quer MAIS AGENTES explorando isso (ataques, padrões, VFX).
→ Donos naturais: chefes6 (padrões do Rei — o orbe precisa nascer na altura alcançável e ter 4–6 ataques por fase),
inimigos6 (repertório), combate6 (hitbox da Sophia/cajado), arte/VFX (projéteis premium — novo diretor de VFX de
ataques), QA (sonda de hitbox: cajado × hurtbox, dano de contato).

## 4. Pendências de decisão do João
Cor da Sophia (painted_flex ao quadrado: corrigir?), título ouro × marfim e ícone da loja (board3), tema do menu,
"regra do nome" (#16), AppPublisher/AppId, GodotSteam, declarar arte por IA na Steam, revisão nativa do inglês.
