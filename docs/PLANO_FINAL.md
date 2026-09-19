# PLANO FINAL — GNOSIS rumo à versão 1.0 (escrito em 17/09/2026)

> Decisão do usuário: "desenvolve até o máximo; polir todos os pormenores;
> versão final". Este documento é o plano-mestre desse esforço. A execução é
> por ONDAS de agentes em paralelo (cada um dono de arquivos distintos), com
> integração, validação headless, capturas reais e commit a cada onda.
> Estado por item: `[ ]` a fazer · `[~]` em andamento · `[x]` feito.

## Diagnóstico de partida (o que o usuário sentiu)
- **Curto demais.** 54 telas, cada tela uma arena única com 2–4 waves nascendo
  no mesmo ponto → 1º Arconte em ~5 min; run em 1–1,5 h. Meta: 2,5–3 h.
- **Falta a "aula" de mitologia.** Só há caixas de diálogo (que pausam). Meta:
  ensinar gnosticismo como GoW ensina a mitologia — histórias em caminhada,
  santuários de lore, códex.
- **Detalhes de versão final ausentes:** menu prioriza o "desafio" (era demo);
  fim de jogo é uma tela nua; sem prólogo; sem cards de chefe; sem tela de
  controles; opções só têm volume; áudio 100% ausente; save sem versão;
  sem executável.

## ONDA 1 (FEITA 18/09) — comprimento + Gnose
- [x] **Estrutura do run (agente A):** Éons de 9 telas (68 no total), cada tela
  uma travessia de 1–3 ZONAS de combate (anda → bolsão trava → limpa → segue);
  papéis por tela: chegada · travessia · **Desafio (Campeão do Éon + Santuário)**
  · travessia · antessala pesada · Arconte. Tiers e multiplicadores por Éon.
  Bot de balance atualizado e rodado (rodada 4 em `docs/BALANCE.md`).
- [x] **Gnose (agente B, refeito 18/09):** ~18 Estelas (inscrições que ensinam o gnosticismo
  real em ordem pedagógica), conversa de caminhada com legendas sem pausar
  (a Voz conta a cosmologia COM O VIÉS do Demiurgo, sem se denunciar; as
  Estelas dão a versão do Pleroma — o jogador aprende pela contradição),
  tela **Crônicas** persistente entre runs, antessala narrada.
- [x] Templates de exportação do Godot baixados (build fica pro fim, após polir).

## ONDA 2 (FEITA 18/09, exceto itens marcados) — cinema, UX, áudio, visual
### C. Cinemática leve (`scripts/fx/cinematic.gd`, prólogo, fim, chefes)
- [x] **Prólogo** (antes da tela 1): 5–6 cards de texto sobre as pinturas dos
  Éons contando o mito (Mônada → Éons → Sophia → o Cego → Kenoma → faíscas →
  "acorda"), pulável. Estilo GoW: pouco texto, imagem grande.
- [x] **Card de chefe:** ao Arconte aparecer, letterbox + nome/título
  ("ATHOTH · Arconte do Torpor") com congelamento curto; idem Rei/Colosso.
- [ ] **O Rei sai da névoa** (tela 1): névoa adensa, silhueta anda até o centro,
  máscara acende — antes do diálogo. **O roubo** (tela 64): os 7 ◆ do HUD voam
  pro Rei um a um; a máscara "cai" (troca de cor/olho); ele afunda no chão.
  **O Centro** (65): descida (câmera desce, cor muda). **Anagnórise** (68):
  Anéis voam pra Sophia, clarão, Colosso encolhe.
- [x] **Epílogos:** tela de fim com pintura do Éon/Mente, texto do final em
  cards, "Crônicas: N/18", créditos curtos; "Melhor progresso" some.
### D. UX de versão final (menus, HUD, opções, loja)
- [x] **Menu principal:** Continuar (se houver) · Nova campanha · Provação (o
  antigo "desafio") · Ateliê / Bestiário · Crônicas · Opções · Sair. Título sem
  "edição isolada". Nome do projeto "GNOSIS".
- [x] **Pausa:** + Crônicas, + Controles/Golpes. **Tela de golpes** (lista dos
  combos desbloqueados com a sequência de botões e o que cada nível da arma abre)
  — a progressão precisa ser LEGÍVEL. Loja mostra o que o próximo nível abre.
- [x] **Opções:** tela cheia, vsync, tremor de câmera, vibração, tamanho da
  legenda; salvar tudo.
- [x] **HUD:** rótulo por papel ("Torpor · Travessia II", "Torpor · O Desafio",
  "Antessala do Arconte") em vez de "Tela 27"; progresso do Éon (pontos).
- [x] **Save com versão** (`save_version`): runs de mapa antigo são descartados
  com aviso, sem crash. Faíscas/melhor progresso preservados.
### E. Áudio (código pronto; usuário gera os arquivos por IA)
- [x] Ligar TODOS os ganchos: golpe leve/pesado/aéreo, lançador, parry, esquiva,
  esquiva perfeita, bloqueio, dano na Sophia, morte, magia por Anel (8 sons),
  inimigo ferido/morto/elite/campeão, chefe aparece/fase 2/cai, baú, Adormecido,
  selo certo/errado, faísca, portal, zona trava/limpa, estela, legenda, UI.
- [x] Música com crossfade: menu, uma faixa por Éon (nigredo→albedo→rubedo),
  chefe, Rei/roubo, Centro, Mente, epílogo. `docs/AUDIO.md` vira a lista de
  compras completa com prompts e duração sugerida.
### F. Visual
- [x] Sophia: poses de esquiva/dano/queda/bloqueio por transformação (como as
  criaturas), prancha `tools/HeroQA.tscn`.
- [ ] Partículas ambientais por Éon (motes, brasas, esporos, cinza, cacos de
  luz, faíscas orbitando no Centro, vazio na Mente).
- [ ] Arena de chefe com cenografia simétrica (braseiros/obeliscos flanqueando).
- [ ] Limpar código morto da geração vetorial antiga em `scenery.gd`.
- [ ] Fundos por Éon em 1536×1024 quando o usuário gerar (hook + parallax).

## ONDA 3 — fechamento
- [ ] Bot de balance no run inteiro (68 telas) nas 4 dificuldades; ajustes.
- [ ] Revisão de texto (todos os diálogos/inscrições): tom, erros, spoilers.
- [ ] Playtest HUMANO (usuário): feel dos golpes, parry, Anéis, ritmo das
  travessias, leitura das Estelas. Ajustes com base no relato.
- [ ] `docs/`: BIBLIA §6, ROADMAP, GDD (estrutura nova), README (controles),
  CODEX_ENTREGA (obsoleto → aponta pra cá).
- [ ] Build `GNOSIS.exe` + instalador (Inno) — SÓ quando o usuário disser.

## Regras desta fase
- Um agente por conjunto de arquivos; nunca dois no mesmo arquivo na mesma onda.
- Cada agente: validar headless (zero `SCRIPT ERROR`), capturar telas reais,
  rodar `CodexQA`, commitar no próprio branch. O integrador (Claude) faz merge,
  revalida, captura de novo, atualiza docs e commita na `codex/despertar`.
- Nada de assets novos sem o usuário (arte = Astra; áudio = ElevenLabs/Suno).
- Regra de ouro narrativa (LORE.md): a virada não vaza antes do final.
