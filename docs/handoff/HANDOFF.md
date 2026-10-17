# HANDOFF — você agora é o CHEFE (orquestrador) do GNOSIS

> Escrito em 17/10/2026 pela sessão anterior (Claude, orquestrador da "Onda 1").
> Leia este arquivo inteiro, depois `BIBLIA.md` (§0–§7), `CLAUDE.md` e os anexos desta pasta.

## 1. Quem é o dono e como ele quer trabalhar
- **João** (fala português, NÃO é programador). Orquestra e decide gosto; quer a IA **opinativa e honesta, sem hype**.
- Ele pediu: "Aja como o chefe, o orquestrador; libere quantos agentes julgar necessário, cada um com sua
  função, se reportando a você, refazendo trabalho se necessário. **Só você fala comigo.**"
- Autorizou: decidir sozinho tudo que é técnico/criativo ("adote tudo o que achar necessário pro jogo mais
  perfeito do mundo"), usar CPU/GPU dele pesado (economiza token: scripts locais em lote, ler só resumos e
  imagens reduzidas), instalar ferramentas grátis.
- Volte a ele só para: gosto pessoal, coisas que só ele faz (jogar/sentir, logar em conta, dinheiro).
- **NÃO compra créditos de IA** (Kairogen = 0). Arte nova vem do **ChatGPT Plus dele** (conta
  `social.labmkt@gmail.com`) dirigido pelo Chrome com a extensão Claude in Chrome — **só funciona na máquina
  local dele** (ver §5).
- **Ética de design (decisão firme):** só o que torna o jogo mais gostoso; **nada de truques manipulativos
  de cassino** (sem recompensa variável compulsiva, loot box, grind, dark patterns).
- **SILÊNCIO:** todo Godot que roda cena/janela usa `--audio-driver Dummy` (e janela em `--position 4000,4000`).
  O som alto incomodou o João.

## 2. Decisões tomadas nesta sessão
- HUD **vermelho/carmim** com medalhão (UI nova) — **aprovado** pelo João; pode refinar sem trocar a identidade.
- **"Misericórdia oculta"** aprovada: 1× por luta, golpe letal deixa a Sophia com 1 HP, invisível.
- 7ª magia "Coroa da Mônada" → **"Coroa Partida"**; item → **"Diadema da Fonte"** (Roteiro; chefe concordou;
  João não objetou).
- Animação: a causa do "foto recortada" era recorte rígido em ossos. Caminho adotado:
  **Sophia = quadros desenhados pelo GPT** (9 folhas prontas em `artes/gpt/`), **chefes = malha contínua com
  pesos + molas** (feito) e, depois, quadros desenhados dos chefes via GPT.
- Geração local (SDXL na RX 7600) testada e **descartada** (nota 1/10 de consistência).
- MusicGen proibido (pesos não-comerciais). Áudio = packs CC0/CC-BY + síntese própria em Python.

## 3. Repositório e branches (GitHub privado `joaotatarin-svg/gnosis`)
- `codex/despertar` — base estável anterior (1.1.0).
- **`integracao/onda1`** — integração da Onda 1 (é o ponto de partida). Já contém:
  Técnico (ferramentas: `tools/validate.ps1`, `tools/shot.gd` modo sequência, `tools/seq_to_media.py`,
  `tools/perf_probe`), UI nova (fontes OFL Cinzel/Alegreya, HUD carmim, diálogo máquina de escrever, Créditos),
  Roteiro (texto 100% revisado + Narrativa Emocional em texto, 208 falas/222 legendas, GnoseQA verde),
  Animação-Chefes (malha com pesos, molas, bake), Revisão (sondas), versões PARCIAIS de Anim-Sophia e Cenário,
  e este handoff + `artes/gpt/` (folhas do GPT; tem `.gdignore`).
- Branches de diretor `dir/<cargo>` (cada um dono de arquivos DISJUNTOS — ver `REGRAS_DIRETORES.md`):
  - `dir/anim-sophia` — quadros desenhados da Sophia (build_frames.py, atlas+JSON, CharacterArt toca
    sequências), alfa real, smear/afterimage/vento/dissolução. (fechado — ver 3b). QAs HeroQA/WaveQA e
    o CodexQA "troca de perfil libera o boneco anterior" estavam VERMELHOS na integração (provável: o teste
    conta filhos do CharacterArt e o novo código adiciona outro nó — ajustar o teste para contar só o
    BossPuppet, sem afrouxar o vazamento). Ver `docs/ANIMACAO.md` (seção "ESTADO PARA A PRÓXIMA SESSÃO").
  - `dir/cenario` — fundos upscale + paralaxe, chão/primeiro plano (faixa inferior morta), plataformas
    integradas, partículas por Éon, arena de chefe, store art. **Em andamento.** Ver `docs/VFX.md`.
  - `dir/audio` — mixagem/loudness, emenda de loops, ambiências sintetizadas, variações, sons do contrato
    (`step`, `step_heavy`, `cloth`, `boss_step`, `blip_voz|rei|sophia|estela|npc`, `ui_open`…), refazer magias
    e orbe (João achou "paia"), 5 SFX da cena do Rei, API de música (pitch, duck_music, camada do Centro),
    volume padrão moderado. (fechado — ver 3b). Ver `docs/AUDIO.md`.
  - `dir/combate` — Fase A (juice/câmera/hitbox/orbes/misericórdia, a partir do `NEURO_SATISFACAO.md`).
    **Em andamento.** A **Fase B** (player.gd/enemy.gd) está descrita em `docs/COMBATE.md`.
  - `dir/qa-ux` — caçador de bugs; relatório em `docs/QA_UX_BUGS.md`.
  - Concluídos e integrados: `dir/tecnico`, `dir/ui`, `dir/roteiro`, `dir/anim-chefes`, `dir/revisao`.
- Ao retomar: `git fetch`, veja `git log integracao/onda1..dir/<x>` para cada branch e integre o que faltar.
  Os `.import` reescritos só por fim de linha pelo editor headless **não** devem ser commitados.

## 3b. ATUALIZAÇÃO FINAL (todos os diretores da Onda 1 encerraram e estão MERGEADOS em integracao/onda1)
- Anim-Sophia FECHOU: 61 quadros/28 estados do GPT, corrida pela distância (16 quadros c/ RIFE; `USE_RUN_INBETWEENS := false` volta ao ciclo de 8 se borrar), smear/afterimage/vento/dissolução; HeroQA/WaveQA verdes. CodexQA só falha "diretório de save independente" por causa do `override.cfg` local (não é bug).
- Cenário FECHOU: fundos upscale (Real-ESRGAN) em camadas, chão 2.5D com reflexo, raios, névoa, plataformas integradas, arena de chefe. Faltou o pacote de loja (assets/store).
- Áudio FECHOU: loudness, loops, 9 ambiências, magias/faísca refeitas, 14 sons novos, buses+limitador, API de música. AudioQA 23/24: o ducking automático de diálogo NÃO abaixa a música (bug aberto, ver docs/AUDIO.md). Ninguém OUVIU os sons ainda — o João deve ouvir antes do fechamento.
- Combate: só PLANO (nenhum código de jogo aplicado). docs/COMBATE.md tem o código pronto da Fase A (câmera — causa: Camera2D.offset somado APÓS os limites —, juice R2/R3/R8/R10, hitbox, misericórdia, orbes R6, physics_interpolation) e a Fase B. Execute-o.
- **A integração completa ainda NÃO foi validada** depois desses últimos merges: primeiro passo = rodar a validação e corrigir.

## 3c. FECHAMENTO DA NUVEM (17/10/2026 ~08:30 UTC) — o bastão fica com a sessão LOCAL
`integracao/onda1` = Onda 1 + Onda 2 + Onda 2b + `dir2/arte-gpt` (local) integrados. Validação Linux:
`tools/validate.sh` TUDO VERDE (CodexQA 53, AudioQA 54, GnoseQA 18, SaveQA 41, TecnicoQA 36, Puppet/Hero/Wave OK) e
`tools/regressao/run_all.sh` 10/10 PASS. Relatórios de cada agente em `docs/onda2/*.md`; pedidos em `docs/pedidos/onda2_*.md`;
backlog do crítico em `docs/onda2/BACKLOG_CRITICO.md`; briefs em `docs/handoff/briefs/`.

**NÃO integrado (decidir):**
- `dir2/combate2` (gibs, P3 Belias, números de dano por opção, contorno do Éon, card com chefe visível, névoa na tela 7,
  correntes na tela 25, conserto do tiro de corrente). Ressalva do próprio agente: o bot PIOROU a tela 55 (1062→1319) por
  causa do Belias 1,15× maior → tirar `arconte_praga` do `BOSS_PRESENCE` em enemy.gd antes de mergear, e rodar validate --full.

**Fila imediata (por dono de arquivo):**
1. Técnico (game_manager.gd): portar `fac9814` do `preview/noite` (vsync=false padrão + `Engine.max_fps` = taxa do monitor) e
   MIGRAR saves antigos com `vsync: true` (senão o João fica a ~21 qps). Medido pela sessão local: causa é o vsync do OpenGL na RX 7600.
2. Desempenho: `git apply tools/perf/patches/vfx_prewarm.patch` (o prewarm atual não elimina engasgo; medido) e excluir do export
   as 5 folhas originais + `assets/characters/` (~9 MB). `character_art_alloc.patch` (baixa prioridade).
3. Encenação: F2 tela 68 (Rei metade fora / Colosso fora na chegada, empilhados na luta); C3 card de chefe com o chefe fora do quadro;
   pedido 7 da arte (staging.gd: `_Little` → `CegoPequeno`); ligar as 12 ilustrações `artes/gpt/cinematic/` no cinematic.gd/staging
   (copiar para assets/cinematic/); Soter/Velkar com `set_anim(...)`; esconder números de dano e dicas durante cinemáticas (C1/C2).
4. UI-menus: Estelas com `artes/gpt/stelae/` (painel + Crônicas), `menu_bg_a` no menu; P3 dicas da Provação (pad).
5. UI-HUD: M1 (legenda na altura das canelas com zoom 1,2); toast de conquista; `Audio.low_health_pulse()` na vinheta.
6. Combate: F1 flash de dano da Sophia (silhueta laranja chapada → flash branco curto); `visual.telegraph_color`;
   `visual.play_action("parry"/"riposte")` no `_parry()`; `dead` ~0,4 s antes do desmembramento.
7. Balance: medir de novo (checkpoints novos, P1 da loja, combate2) com `tools/balance/run.sh`.
8. Inglês: rodada própria no fim (plano em `assets/i18n/PLANO.md`).
9. `painted_flex.gdshader` da Sophia (cor ao quadrado): correção de 1 linha espera o OK visual do João.

**Decisões do João pendentes:** paleta da loja A/B e ícone Olho/Faísca (`assets/store/board.png`); tema do menu A/B/C e variações
de chefe (`/home/user/caps/...` não existe no PC — regerar com `tools/audio_synth/menu_theme.py` e `boss_variants.py`);
"regra do nome" (#16, recomendado: ironia dramática); AppPublisher/AppId; GodotSteam; `gnosis/store_url`; declarar arte por IA na Steam;
Athoth sempre liberado na Provação (hoje sim).

## 4. Fila de trabalho (em ordem)
1. **Fechar a Onda 1:** integrar `dir/anim-sophia`, `dir/cenario`, `dir/audio`, `dir/combate`, `dir/qa-ux`
   em `integracao/onda1`; rodar `tools/validate.ps1 -Path <wt>` até TUDO VERDE; capturas antes/depois.
2. **Onda 2** — lista viva em `docs/handoff/ONDA2.md`. Resumo:
   - Combate Fase B (`player.gd`/`enemy.gd`): flash em tempo real + vibração (R1), telegrafo com brilho
     180 ms + forma + som e bug `enemy.gd:778` (R5), um VFX por acerto + som em camadas (R4), flash ≤3/s (R10),
     câmera/presença da Sophia, interpolação de física, misericórdia ligada no player.
   - Correções da revisão (`docs/handoff/REVISAO.md`): **ALTA** morte×queda do Arconte (`level.gd:417-447`,
     `518-542`), licenças/atribuições CC-BY fora da build (include_filter + texto nos Créditos), **save
     não-atômico** (`.tmp`→rename + `.bak`), `gamecontrollerdb.txt` fora do .pck, saves com tipos errados,
     tools/ e artes/ dentro do .pck (exclude), patches inseguros, música errada na Provação, pausa global sem dono.
   - Encenação (Roteiro→level.gd/final_battle/sleeper/enemy): ganchos em `docs/ROTEIRO.md` §5 (santuário,
     fase 2, eco do Centro, 7º Anel, Adormecido, finais) + as 4 cenas (Rei sai da névoa, roubo, descida ao
     Centro, anagnórise) usando a API do HUD `ring_dot_global_pos(i)`/`detach_ring(i, alvo)`.
   - Arte: folhas dos 9 chefes e das criaturas via GPT (LOCAL), depois ligar com
     `BossPuppet.set_state_texture(estado, textura)` (mesmo enquadramento de `*_body.png`).
   - Polimento UI: barra do chefe com pouco contraste; "II" colado na borda.
3. **Portão humano:** João joga a campanha (feel, parry, ritmo). Checklist em `NEURO_SATISFACAO.md`.
4. Fechamento: merge em `codex/despertar`, atualizar `BIBLIA.md §6` e `ROADMAP.md`, build + instalador
   **só com OK do João**; página Steam/trailer/demo (sugestão: Rei + 1º Éon para o Next Fest).

## 5. O que a NUVEM pode e não pode
- Nuvem (Linux, sem GPU, sem tela, sem o Chrome/ChatGPT do João, sem Blender, sem `assets/_packs` brutos):
  serve para código, texto, QA headless, balance bot, correções da revisão, Fase B do combate, encenação,
  scripts de pipeline. Baixe o Godot 4.7.1 Linux headless (e export templates se for exportar) e rode as QAs
  com `--headless --audio-driver Dummy`. Capturas exigem renderer: tente `xvfb-run` + `--rendering-driver
  opengl3` (llvmpipe); se não der, deixe capturas para a sessão local.
- **Só na máquina do João (sessão local):** geração de arte no ChatGPT via Chrome (Claude in Chrome; aba
  logada em social.labmkt; download pelo botão "Copiar imagem"/clipboard e salvar via PowerShell, ou
  `<a download>` se o Chrome permitir vários downloads; upload de referência com `file_upload` no
  `input[type=file]`), RIFE (`C:\Users\jmtat\gnosis-tools\rife`), Blender 5.2, rembg, capturas no renderer real.
- Worktrees locais ficam em `C:\gnosis-wt\<cargo>` (fora do OneDrive), cada um com `override.cfg` (user://
  isolado — o `tools/save_qa.gd` antigo sobrescrevia o save REAL do João; backup em
  `C:\Users\jmtat\gnosis-tools\backup_save_*`). Nunca commitar `override.cfg`.

## 6. Ritual de cada diretor (já testado)
`REGRAS_DIRETORES.md`: um worktree/branch por cargo, arquivos disjuntos, pedidos entre áreas em
`docs/pedidos/<cargo>.md`, commit cedo e sempre (limites de uso derrubam agentes), validação verde,
capturas antes/depois, relatório honesto. O chefe integra, revalida, mostra ao João (imagens reduzidas) e
atualiza a BIBLIA/ROADMAP no fechamento. Termine commits com:
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## 7. Anexos nesta pasta
`REGRAS_DIRETORES.md` · `ONDA2.md` · `NARRATIVA_EMOCIONAL.md` (direção emocional; texto já implementado pelo
Roteiro, ganchos pendentes) · `NEURO_SATISFACAO.md` (22 recomendações de game feel com números) ·
`REVISAO.md` (17 achados verificados) · `artes/gpt/MANIFESTO.md` (folhas do GPT e nomes de quadro).
