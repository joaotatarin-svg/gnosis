# Briefs — demais cargos da Onda 2 (nuvem)

## AUDIO (dir2/audio)
Leia AUDIO.md (ESTADO), pedidos/combate.md (Áudio), pedidos/roteiro.md, REVISAO #8 e #15, NEURO R6–R14, ROTEIRO §2/§5 #8. Não pode ouvir: mede offline.
Seus: scripts/autoload/audio_manager.gd, assets/audio/*, assets/LICENSES.md, tools/audio_synth/*, tools/audio_qa.gd(+cena), tools/audio/, docs/AUDIO.md, docs/onda2/AUDIO.md.
1. Bug do ducking do AudioQA (24/24 sem afrouxar). 2. CodexSession.active antes de run_active; parar players no quit. 3. play_sfx_pitched; spark na chegada do orbe (tirar do crédito; anti-spam não engole arpejo); escutar Juice.slowmo_changed se existir (passa-baixas, música −4 dB). 4. Tema da Voz `theme` e API das cenas; tema do menu: opções por síntese para o João ouvir. 5. R11–R14 seguros. Relatório com LISTA DE AMOSTRAS para o João ouvir.

## CENARIO (dir2/cenario)
Leia VFX.md (ESTADO), QA_UX_BUGS M5/P2, NEURO R18, pedidos/cenario.md.
Seus: scripts/levels/scenery.gd, scripts/fx/scenery_library.gd, assets/shaders/scenery_*, assets/backgrounds/*, tools/scenery/*, docs/VFX.md, docs/onda2/CENARIO.md.
1. M5 emendas de 1 px (causa + correção). 2. P2 limite da arena legível + faixa inferior com vida sem competir com personagens. 3. VFX.md falta 2, 3, 4, 6. 4. Não piorar desempenho. Capturas antes/depois por Éon.

## LOJA (dir2/loja)
Seus: assets/store/* (com .gdignore), tools/store/*, docs/onda2/LOJA.md. Compor com PIL a partir de assets/painted, assets/backgrounds e capturas reais: cápsulas 460×215, 231×87, 616×353, 374×448, hero 3840×1240 sem texto, logo transparente ≥1280, ícone 512 + .ico; 5 capturas 1920×1080; script que regera tudo; prancha para o João escolher. Sem promessas falsas.

## QA (dir2/qa)
Seus: tools/qa_ux/*, tools/qa/, tools/regressao/, docs/QA_UX*.md, docs/onda2/QA.md. Não corrige o jogo.
1. Portar as sondas para Linux e rodar a passada completa em integracao/onda1 (baseline). 2. QAs de regressão headless (PASS/FAIL) para B1, A1, A2, A3, A4, A5, A6, REVISAO #1, #3, #10 — hoje devem FALHAR; tools/regressao/run_all.sh. 3. Tabela bug→teste→estado.

## BALANCE (dir2/balance)
Seus: tools/balance_bot.gd(+cena), tools/balance/, docs/BALANCE.md, docs/onda2/BALANCE.md. Não edita números do jogo.
1. r8 baseline nas 68 telas (consertar só o BOT se quebrar). 2. Determinismo (2 rodadas iguais?). 3. Propostas numéricas com dados (arquivo:linha, hoje→proposto), sem truques de recompensa. 4. tools/balance/run.sh para comparar r8×r9 após o Combate.

## PERF (dir2/perf)
Seus: tools/perf_probe.gd(+cena), tools/perf/, docs/onda2/PERF.md. Não edita o jogo: entrega correção pronta ao dono.
1. Perfil por tela (1,3,10,22,36,50,63,64,65,68). 2. Engasgos do 1º golpe/VFX/shader (lista exata para VfxLibrary.prewarm). 3. Alocação por quadro (REVISAO #16), peso do .pck por pasta. 4. Tabela de achados + tools/perf/run.sh.

## I18N (dir2/i18n)
Seus: assets/i18n/* (com .gdignore), tools/i18n/*, docs/onda2/I18N.md. Não liga no jogo ainda.
1. tools/i18n/extract.py → assets/i18n/strings.csv (todas as strings visíveis, chave estável, contexto, limite). 2. Glossário inglês + tradução literária. 3. Plano técnico (TranslationServer/CSV, tr(), fontes, opção de idioma).

## Só leitura
- REVISOR: revisa commits novos de dir2/* (bugs, quebra de contrato entre agentes, arquivo de outro dono, teste afrouxado, .import/override commitados); relatório priorizado.
- CRÍTICO: captura amostra ampla do jogo e entrega backlog priorizado de melhorias para produto vendável (/home/user/caps/critico/BACKLOG.md).
