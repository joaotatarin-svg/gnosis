# GNOSIS: backlog do crítico de jogo (Onda 2)

Crítico de jogo (qualidade/visão), somente leitura. 17/10/2026.
Base: `integracao/onda1` @ `c1beb1c`, no worktree `/home/user/wt/_critico`, com `override.cfg` e user:// isolado.
Os branches `dir2/*` podem já ter corrigido parte disto. Antes de abrir um item, o dono confere no branch dele.

## Como as capturas foram feitas (e o que elas NÃO provam)
- `tools/Shot.tscn` sob xvfb, 1280×720, `--fixed-fps 60`, sem áudio. São 41 capturas (mais 6 quadros de sequência com metadados) em `/home/user/caps/critico/`: `<nome>.png` em tamanho cheio, `s_<nome>.png` reduzida e `c_*.png` com recortes de prova.
- **Artefatos da ferramenta, que NÃO são bugs:** o shot dá os 7 Anéis no começo (por isso o HUD mostra "Névoa do Sono" já na tela 1), pula diálogos e o prólogo, e zera as faíscas. Ninguém controla a Sophia: ela fica parada, a não ser no modo `clear`.
- Não avaliei feel, timing, som nem animação em movimento. Nada aqui substitui um playtest humano (item 14).
- Os bugs técnicos já descritos em `docs/QA_UX_BUGS.md` e `docs/handoff/REVISAO.md` entram aqui só quando afetam a venda. Nesses casos cito o ID original e não repito a análise.

Legenda: **I** = impacto (A/M/B) · **E** = esforço (P ≤ 1 dia de agente · M = 1–3 dias · G = semana ou mais, ou depende de arte/música nova).
Faixas: **[0]** bloqueia a demo ou a venda · **[1]** antes da Next Fest · **[2]** antes do lançamento · **[3]** polimento.
A ordem é impacto ÷ esforço, com as faixas como desempate.

---

## Índice (ordem de execução)

| # | Faixa | Item | I | E | Dono |
|---|---|---|---|---|---|
| 1 | 0 | A câmera tira a Sophia do quadro | A | P | combate |
| 2 | 0 | Controle: A não confirma, B não volta (softlock na tentação) | A | P | tecnico |
| 3 | 0 | Morrer no Arconte devolve 8 telas (checkpoint no início do Éon) | A | P | tecnico (+balance) |
| 4 | 0 | Legenda de caminhada em cima do chão de combate | A | P | ui-hud |
| 5 | 0 | Estela abre com o golpe leve, ao lado do spawn da tela 1 | A | P | ui-menus + tecnico |
| 6 | 0 | Abertura: 6 cards + 11 falas antes do 1º comando | A | P | encenacao |
| 7 | 0 | Bots de Éon são miniaturas dos Arcontes (estraga o chefe) | A | P→G | arte-GPT local |
| 8 | 0 | Batalha final: instrução ilegível e uma barra para dois chefes | A | M | ui-hud + encenacao |
| 9 | 0 | Telegrafo pinta o chefe inteiro de amarelo | A | M | combate (+audio) |
| 10 | 0 | Duelo do Rei não ensina nada (nenhuma dica de controle) | A | M | encenacao + ui-hud |
| 11 | 0 | Arte gerada por IA: divulgação na Steam e risco de review | A | P | João/chefe + loja |
| 12 | 0 | Jogo só em português | A | G | i18n + ui-menus |
| 13 | 1 | Morte sem animação (a Sophia congela) | A | P | combate |
| 14 | 1 | Playtest externo gravado (5 pessoas que nunca jogaram) | A | P | chefe/João |
| 15 | 1 | Morte × queda do Arconte (REVISAO #1) e save não atômico (REVISAO #3) | A | P | encenacao + tecnico |
| 16 | 1 | Decidir a "regra do nome": o prólogo e a UI já entregam Sophia = mãe do Cego | A | P | João + encenacao |
| 17 | 1 | Ateliê exposto como ferramenta de desenvolvedor | M | P | ui-menus |
| 18 | 1 | Tentação com o Arconte fora de cena | M | P | encenacao |
| 19 | 1 | Card de chefe corta o HUD ao meio | M | P | ui-hud |
| 20 | 1 | "O CAMPEÃO" genérico em todos os Desafios | M | P | encenacao |
| 21 | 1 | Legenda de chegada falando por cima da luta de chefe | M | P | encenacao |
| 22 | 1 | Primeira fala do jogo é uma rubrica entre parênteses | M | P | encenacao + ui-hud |
| 23 | 1 | Destroços (gibs) acumulam e atravessam telas | M | P | combate |
| 24 | 1 | Tela cheia desligada por padrão | M | P | tecnico |
| 25 | 1 | Toasts sem placa de fundo (texto some no cenário) | M | P | ui-hud |
| 26 | 1 | Provação e Bestiário mostram todos os chefes desde o início (spoiler) | M | P | ui-menus + tecnico |
| 27 | 1 | Build de demo (Rei + Torpor) com fim e lista de desejos | A | M | tecnico + ui-menus + loja |
| 28 | 1 | Cena A: o Rei sai da névoa (é o minuto 1 da demo) | A | M | encenacao |
| 29 | 1 | Limiar e Torpor: 10 telas com o mesmo fundo (a demo inteira) | A | M | cenario (+arte-GPT) |
| 30 | 1 | Inimigos escuros sobre fundo escuro | A | M | cenario + combate |
| 31 | 1 | Presença em tela: Sophia com 12% da altura, faixa inferior morta | A | M | combate (câmera) |
| 32 | 1 | Executar NEURO R1–R5 e R10 (impacto, hitstop, flash) | A | M | combate |
| 33 | 1 | Ícones de botão dinâmicos (teclado × Xbox × PlayStation) | M | M | ui-menus + ui-hud |
| 34 | 1 | Opções que faltam para PC/Steam | A | M | ui-menus + tecnico |
| 35 | 1 | Bestiário revela reúso de sprite e não tem lore | M | M | ui-menus (+arte) |
| 36 | 1 | Erro de polígono na barra do HUD (spam no log) | B | P | ui-hud |
| 37 | 1 | Ferramentas de dev e banco de controles na build (REVISAO #4, #6) | M | P | tecnico |
| 38 | 2 | Cena B: o roubo está escrito em rubricas, não encenado | A | G | encenacao |
| 39 | 2 | Cena D e escolha final (caixa estoura a borda, A6) | A | M | encenacao + ui-hud |
| 40 | 2 | Trilha de banco reconhecível e uma só música de chefe | A | G | audio + João |
| 41 | 2 | Repetição estrutural: 7 × o mesmo molde de 9 telas | A | G | combate + encenacao + cenario |
| 42 | 2 | Tamanho dos chefes inconsistente | M | P | combate |
| 43 | 2 | Mesma plataforma e mesmo chão em todos os Éons | M | M | cenario |
| 44 | 2 | "Ceder" à tentação não custa nada | M | M | encenacao + balance |
| 45 | 2 | Epílogos sem arte própria | M | M | arte-GPT + encenacao |
| 46 | 2 | Progressão de arma invisível (Sophia Nv.1 = Nv.5) | M | M | arte-GPT |
| 47 | 2 | NEURO áudio R6, R9, R11 (faísca, silêncio antes do chefe, variação) | M | M | audio |
| 48 | 2 | Adormecidos sem voz (o final Semente depende deles) | M | P | encenacao |
| 49 | 2 | Steam Cloud, conquistas e rich presence | M | M | tecnico |
| 50 | 2 | Trailer de 60–90 s (depende de 1, 4, 9, 31) | A | M | loja |
| 51 | 3 | Centro: a fala diz "chão de engrenagens" e o chão é de pedra | B | P | cenario |
| 52 | 3 | Pré-jogo entrega "O Centro · A Mente" e mede o jogo em "68 telas" | B | P | ui-menus |
| 53 | 3 | Ornamentos por cima de controles e textos | B | P | ui-menus |
| 54 | 3 | Registro do português (tu europeu × BR) | B | P | encenacao |
| 55 | 3 | Animação das criaturas comuns (não verificado em movimento) | M | G | arte-GPT local |

---

## Detalhe

### [0] Bloqueiam a demo ou a venda

**1. A câmera tira a Sophia do quadro.** I:A · E:P · dono: combate (`scripts/fx/camera_shake.gd`)
- *Problema:* nas capturas, a Sophia está fora da imagem em 9 de 16 telas de combate. Os metadados provam: na tela 2 ela está em x = −84 px (quadro 200) e na tela 10, parada, em x = −79 e −84 px (`/home/user/caps/critico/meta_s02_meta.json`, `meta_s10_meta.json`). Na tela 10 o Athoth atira em direção à borda esquerda, num alvo que não está na tela (`s10_hurt.png`). Também em `s01.png`, `s02.png`, `s10.png`, `s19.png`, `s29.png`, `s55.png`, `s64.png` e `s12_die.png` (é o renascimento: ela volta já fora do quadro). Na tela 12 ela fica cortada na borda (`s12.png`, `s22.png`, `s50.png`). É o bug A5 do QA, ainda aberto: o look-ahead é somado ao `offset` depois dos `limit_*`.
- *Por que importa:* num beat-em-up, perder a personagem de vista é o defeito mais visível que existe. Vai aparecer em toda captura de streamer e em todo vídeo de loja.
- *Proposta:* limitar o look-ahead para que o centro final fique dentro dos limites (calcular `framing` e fazer clamp por `limit_left + meia_largura`). Também garantir que a Sophia fique entre 15% e 85% da largura. Uma sonda automática falha o teste se `player.x` sair de [0, 1280] em qualquer quadro das 68 telas.

**2. Controle: A não confirma e B não volta.** I:A · E:P · dono: tecnico (`scripts/autoload/game_manager.gd _register_inputs`)
- *Problema:* em tempo de execução, `ui_accept` = Enter, Kp Enter, Space e `ui_cancel` = Escape, sem nenhum botão de controle (`/home/user/caps/critico/inputmap.txt`). Os botões do Godot só confirmam com `ui_accept`. Só com controle não dá para começar a campanha, e a escolha Recusar/Ceder da tela 10 trava o jogo (B1 do QA).
- *Por que importa:* sem isso não há Steam Deck, não há "suporte total a controle" na página, e na Next Fest metade do público joga de controle.
- *Proposta:* acrescentar `JOY_BUTTON_A` em `ui_accept` e `JOY_BUTTON_B` em `ui_cancel`. Em gameplay, o B continua sendo esquiva, porque `ui_cancel` só é lido em menus. Teste: PadProbe do QA.

**3. Morrer no Arconte devolve até 8 telas.** I:A · E:P · dono: tecnico (`run_manager.gd checkpoint_for`) + balance para medir de novo
- *Problema:* `checkpoint_for()` devolve sempre a primeira tela do Éon. Morri na tela 12 e voltei para "Fome · Chegada" (11) (`s12_die.png`). Morrer no Arconte (19) também volta para a 11. "Continuar" depois de fechar o jogo usa o mesmo checkpoint, então sair no meio do Éon perde até ~15 min.
- *Por que importa:* "perdi 15 minutos por uma morte no chefe" é uma das reclamações mais comuns em reviews negativas de jogos de ação, e cai dentro da janela de reembolso de 2 h.
- *Proposta:* um checkpoint também no santuário (Desafio, offset 4) e na antessala (offset 7), ou "tentar o chefe de novo" direto na tela do Arconte. O custo continua sendo −20% de faíscas. "Continuar" retoma da última tela iniciada.

**4. A legenda de caminhada fica em cima do chão de combate.** I:A · E:P · dono: ui-hud (`caption_bar.gd`)
- *Problema:* a faixa ocupa y 260–304 (de 360), exatamente onde estão pés, larvas, poças e névoa. No recorte, ela cobre as pernas do inimigo e a larva inteira (`/home/user/caps/critico/c_s05_inimigos.png`). Aparece em quase toda captura, e com 2 linhas em `s17.png`, `s61.png`, `s63.png` e `s64.png`.
- *Por que importa:* esconde telegrafos de chão (veja o item 9) e tira atenção na hora do perigo.
- *Proposta:* levar a legenda para o topo central, abaixo do título do Éon, ou para a faixa morta abaixo do chão (y > 318), com a barra de chefe logo acima. Com chefe ativo, só uma linha. A legenda não deve sobrepor nenhum inimigo vivo.

**5. A Estela abre com o golpe leve, e na tela 1 ela fica ao lado do spawn.** I:A · E:P · dono: ui-menus (`stela.gd`) + tecnico (nova ação `interact`)
- *Problema:* a Estela da tela 1 fica colada na Sophia (`s01_dialog.png`, o obelisco azul). O texto do jogo diz "aperte o golpe leve (J / X) para ler" (`chron.png`). O primeiro botão que um jogador novo aperta abre um painel e pausa o jogo (M7 do QA).
- *Proposta:* criar uma ação `interact` (↑/W ou Y/△, mostrada só perto da Estela). O ataque não deve abrir nada.

**6. A abertura tem 6 cards e 11 falas antes do primeiro comando.** I:A · E:P · dono: encenacao (`level.gd _play_narrative_beats`, `cinematic.gd`)
- *Problema:* "Nova campanha" mostra o prólogo (6 cards, cerca de 29 s), depois `intro()` (6 falas) e `king_intro()` (5 falas), tudo antes de o jogador mexer. Na captura sem pulos, a primeira tela de jogo é uma rubrica numa caixa (`s01_dialog.png`).
- *Por que importa:* na Next Fest e em vídeos de streamer, o jogador decide nos primeiros 60 s. Hoje esse tempo é leitura.
- *Proposta:* prólogo em 3 cards (até 20 s). "Acorda." e logo em seguida o controle. O resto da `intro` vira legenda enquanto ela anda até a Estela. O `king_intro` cai para 3 falas, com o Rei saindo da névoa (item 28). Meta: primeiro comando em até 45 s depois de "Começar a travessia".

**7. Os bots de Éon são miniaturas dos Arcontes.** I:A · E:P (recolor) → G (arte própria) · dono: arte-GPT local (`painted_library.gd`, mapa `families`)
- *Problema:* a tabela `families` dá a cada bot de Éon o sprite do seu Arconte em escala de criatura. Na tela 5 já aparece um "Athoth" pequeno (`c_s05_inimigos.png`; compare com o Athoth da tela 10 em `c_s10_telegrafo.png`). Na tela 17, o Glutão é um Harmas (`s17.png`, dois quadros antes do chefe). Na Coroa (63), o "alado" é o Yabel (`s63.png`).
- *Por que importa:* o chefe perde a entrada (o jogador já matou o "mesmo bicho" dez vezes) e quem joga confunde chefe com criatura comum. Somado ao item 35, passa a impressão de jogo de assets reaproveitados.
- *Proposta:* agora, silhueta diferente (sem auréola/coroa), paleta dessaturada, máscara ou capuz e escala menor que 0,7. Depois, arte própria para os 7 bots.

**8. Batalha final: a instrução é ilegível e há uma barra para dois chefes.** I:A · E:M · dono: ui-hud (`hud.gd show_boss/toast`) + encenacao (`final_battle.gd`)
- *Problema:* a única regra da luta, "AS DUAS FORMAS PRECISAM CAIR JUNTAS", aparece em texto escuro sobre o céu roxo, coberta por um anel (`/home/user/caps/critico/c_s68_toast.png`). Há uma barra só, "O Colosso Oco — a Verdade", enquanto quem está em cena é o Rei (`s68.png`, `s68_hurt.png`; é o A3 do QA). O Colosso não aparece em nenhuma das duas capturas.
- *Por que importa:* é o clímax do jogo. Se o jogador não entende a regra, ele morre sem saber por quê, e acontece no último minuto.
- *Proposta:* duas barras empilhadas, Rei em cima e Colosso embaixo, cada uma com um relógio circular de "refaz em 14 s" quando o chefe cai. A regra vai em card grande no início e de novo na primeira vez que alguém se refaz. A câmera se afasta para enquadrar os dois.

**9. O telegrafo pinta o chefe inteiro de amarelo.** I:A · E:M · dono: combate (`enemy.gd:447`) + audio
- *Problema:* no wind-up, `visual.modulate` vai para amarelo sólido. A ilustração vira uma mancha (Athoth em `c_s10_telegrafo.png`, Belias em `s55.png`, o Rei em `s68.png`, o Sonâmbulo em `c_s05_inimigos.png`). O único aviso é a cor (NEURO R5, "O que NÃO fazer" nº 11).
- *Por que importa:* destrói justamente a arte que é o ponto forte do jogo. Daltônicos não leem amarelo × vermelho. O bug `enemy.gd:778` ainda apaga o aviso quando o golpe acerta.
- *Proposta:* aplicar a R5. Contorno ou rim light por 180 ms no início do wind-up, tingir 40–50% no máximo, um símbolo de forma acima da cabeça (◇ aparável, ✕ imparável) e um som distinto para cada tipo. Corrigir a linha 778.

**10. O duelo do Rei não ensina nada.** I:A · E:M · dono: encenacao (`level.gd`) + ui-hud
- *Problema:* nenhuma dica de controle na campanha (`s01.png`; A7 do QA). O Rei é o "chefe-tutorial", mas mover, golpe leve/forte, esquiva e aparar só estão no menu "Golpes & Controles".
- *Proposta:* dicas contextuais com o ícone do dispositivo em uso (item 33). Mover/pular no começo. Leve/forte quando ela se aproxima. Na primeira preparação do Rei, o jogo congela 0,3 s e mostra "◇ amarelo = apare (L1/K)". No primeiro golpe vermelho, "esquiva (B/L)". Cada dica aparece uma vez e some quando o jogador usa o comando.

**11. Arte gerada por IA: divulgação e risco de review.** I:A · E:P (decisão) · dono: João/chefe + loja
- *Problema:* personagens, fundos e menu foram gerados por IA (GPT/Kairogen). A Steam exige que isso seja declarado no formulário de conteúdo, e o aviso aparece na página. Parte do público rejeita esse tipo de arte. Os reviews negativos costumam apontar incoerências, como o mesmo sprite com 3 nomes (item 35) ou um chefe repetido como criatura (item 7).
- *Proposta:* declarar com honestidade, sem esconder. Antes da demo, fazer uma curadoria humana procurando artefatos (mãos, glifos sem sentido, bordas de recorte). O capsule e as capturas da loja precisam de retoque humano. Não sei medir o impacto em vendas; o risco é real e quem decide é o João.

**12. O jogo está só em português.** I:A · E:G · dono: i18n + ui-menus
- *Problema:* não há seletor de idioma (`options.png`). A maior parte do público da Steam e da Next Fest lê inglês.
- *Proposta:* inglês completo (Narrative, Gnosis/Estelas, UI, créditos) com seletor em Opções. Verificar se o texto cabe nas caixas: o inglês costuma ficar −10%, e alemão ou espanhol, +20%. A demo da Next Fest precisa estar em inglês.

### [1] Antes da Next Fest

**13. A morte não tem animação.** I:A · E:P · dono: combate (`player.gd:116`)
- *Problema:* `_physics_process` retorna em `State.DEAD` antes de `move_and_slide` e `_sync_anim`. Ela congela no ar ou de pé e nunca toca "dead" (A4 do QA, ainda presente nesta base).
- *Proposta:* em DEAD, aplicar gravidade, chamar `move_and_slide` e `set_anim("dead")`, e esperar 1 s antes do "LEVANTA." da Voz.

**14. Playtest externo gravado.** I:A · E:P · dono: chefe/João
- Cinco pessoas que nunca jogaram, com tela e voz gravadas, jogando do Rei até o Athoth, antes de mexer em números. Usar o checklist da NEURO §5. As capturas não respondem feel, timing nem se o parry se aprende sozinho.

**15. Dois riscos técnicos que viram review negativa.** I:A · E:P · dono: encenacao (`level.gd`) + tecnico
- REVISAO #1: se o Arconte cai logo depois da morte da Sophia, ela volta ao início do Éon com o Anel no bolso.
- REVISAO #3: o save não é atômico. Fechar durante a gravação apaga "Continuar" e os finais vistos.
- "Perdi meu save" é review de 1 estrela garantido. As duas correções estão descritas no `REVISAO.md`.

**16. Decidir a "regra do nome".** I:A · E:P · dono: João + encenacao
- *Problema:* o roteiro trata "ela é a Sophia, mãe do Cego" como revelação da tela 68, e a NARRATIVA diz que ninguém fala o nome antes do Centro. Mas o card 3 do prólogo conta que Sophia teve um filho sem forma e o escondeu numa nuvem, e o card 4 que esse filho é o deus cego que fez o mundo (`cinematic.gd:59-60`). Além disso, o menu (`menu.png`, "SOPHIA"), o pré-jogo (`pregame.png`), o ateliê e o HUD dão o nome, e ela mesma diz "Sophia" na tela 40 (`s40.png`). A virada da tela 64 (a Voz é Yaldabaoth) continua de pé.
- *Proposta:* escolher um caminho.
  - **(A) Ironia dramática:** o jogador sabe e ela não. É barato e honesto, porque a página da Steam vai dizer "Sophia" de qualquer jeito. A cena D passa a ser sobre ela *lembrar*, e a "regra do nome" muda nos docs.
  - **(B) Esconder:** tirar o nome da UI e o card 3.
- Recomendo (A).

**17. O Ateliê parece ferramenta de desenvolvedor.** I:M · E:P · dono: ui-menus (`character_atelier.gd`)
- *Problema:* "Receita visual · Conceito → ilustração → poses", "Ver articulações", "Arma +", "Paleta" e os 7 Arcontes abertos desde o início (`atelier.png`).
- *Proposta:* virar "Galeria". Cada entrada abre depois do encontro, com 2–3 linhas de lore. Os botões de dev ficam atrás de uma flag de debug.

**18. Tentação com o Arconte fora de cena.** I:M · E:P · dono: encenacao
- O Athoth fala "Portadora." pelo retrato, e a arena está vazia (`s10_dialog.png`). O Arconte deveria nascer antes do diálogo, enquadrado e em idle. O card do chefe vem depois da escolha.

**19. O card de chefe corta o HUD.** I:M · E:P · dono: ui-hud
- A tarja do letterbox passa sobre o retrato e as barras (`s06.png`, `s60.png`; M4 do QA). Esconder o HUD com fade durante o card.

**20. "O CAMPEÃO" é genérico em todos os Desafios.** I:M · E:P · dono: encenacao
- O mesmo card aparece no Torpor e na Coroa (`s06.png`, `s60.png`), enquanto o roteiro diz "o Glutão", "o Carcereiro"... Usar o nome do bot do Éon ("O GLUTÃO — guardião do santuário da Fome"). Isso também evita a colisão com a dificuldade "Campeão".

**21. Legenda de chegada falando por cima da luta de chefe.** I:M · E:P · dono: encenacao
- "Anda: a névoa não espera ninguém" aparece durante o duelo do Rei (`s01.png`). "...E ele nem abriu os olhos" aparece enquanto o Athoth ataca (`s10.png`). Nas telas de chefe, as legendas devem vir antes do card ou depois da queda, nunca durante a luta.

**22. A primeira fala do jogo é uma rubrica.** I:M · E:P · dono: encenacao + ui-hud
- "(Escuro. Um coração batendo. Depois, cinza na boca.)" aparece numa caixa de diálogo comum (`s01_dialog.png`). O roubo também é contado em rubricas (item 38). Melhor fazer tela preta, som de coração e texto centralizado em itálico, sem caixa. Rubricas não deveriam aparecer na caixa de diálogo.

**23. Destroços acumulam.** I:M · E:P · dono: combate (`gib.gd`)
- Pilhas de cacos marrons no chão do Desafio (`s60.png`), e a tela 11 já começa suja (`s10_clear.png`). Os gibs devem sumir em 3–4 s, com no máximo 30 por vez, e não podem passar de uma tela para outra.

**24. Tela cheia desligada por padrão.** I:M · E:P · dono: tecnico (`game_manager.gd:24`)
- `"fullscreen": false` (`options.png`). Na Steam, a primeira impressão deve ser em tela cheia (borderless).

**25. Toasts sem placa de fundo.** I:M · E:P · dono: ui-hud (`hud.gd toast`)
- O texto se perde no cenário (`c_s68_toast.png`) e cola no nome do Anel (M2 do QA). Toast precisa de placa escura e de uma faixa própria, separada da fileira de Anéis.

**26. Provação e Bestiário mostram todos os chefes desde o início.** I:M · E:P · dono: ui-menus + tecnico (`codex_session.gd`)
- A Provação deixa escolher qualquer um dos 7 Arcontes, e o Bestiário mostra Colosso, Demiurgo e Sombra (`gallery.png`). Na demo, isso é spoiler e tira a vontade de descobrir. Cada chefe deve abrir depois de vencido na campanha. Corrigir também a música errada da Provação (REVISAO #8).

**27. Build de demo (Rei + Torpor).** I:A · E:M · dono: tecnico + ui-menus + loja
- Uma flag `demo` que termina depois do Athoth (Anel 1) com um card "Fim da demo — adicione à lista de desejos" (botão abre a página da loja). Save separado. Bestiário, Ateliê e Provação limitados ao Torpor. Créditos curtos. Em inglês (item 12).
- Duração estimada pela régua do bot (72 min de jogo / 68 telas): ~15–25 min para um humano. Isso é bom para a Next Fest.

**28. Cena A: o Rei sai da névoa.** I:A · E:M · dono: encenacao
- Hoje o Rei já está em cena, gigante, quando a luta começa (`s01.png`). É o minuto 1 da demo. Implementar a Cena A do ROTEIRO (névoa, passos, a máscara acende) em ~9 s, sem perder o controle por mais tempo do que isso.

**29. Dez telas com o mesmo fundo.** I:A · E:M · dono: cenario (+arte-GPT para fundos novos)
- O Limiar (1) e as 9 telas do Torpor usam a mesma pintura azul de catedral com lua (`s01.png`, `s02.png`, `s05.png`, `s06.png`, `s10.png`). Os outros Éons também têm um fundo só (`s12.png`, `s17.png` e `s19.png` são iguais).
- *Proposta:* curto prazo, gradação por papel da tela, com mais névoa e luz mais fria à medida que se aproxima do Arconte, e outro recorte ou parallax na antessala e no trono. O Limiar ganha fundo próprio, de cinzas. Médio prazo, 2–3 fundos por Éon.

**30. Inimigos escuros sobre fundo escuro.** I:A · E:M · dono: cenario + combate (shader)
- A larva some no chão (`c_s05_inimigos.png`, `s29.png`, `s02.png`). A Sophia lê bem porque veste branco; os inimigos não. Aplicar a NEURO R18: contorno de 1 px ou rim light na cor do Éon, a faixa de jogo do fundo 15% mais escura e dessaturada, e sombra de contato.

**31. Sophia pequena e terço inferior morto.** I:A · E:M · dono: combate (câmera) + cenario
- A Sophia mede ~90 px em 720 (12,5% da altura; `c_s05_sophia.png`). Abaixo do chão há ~25% de pedra lisa sem uso (`c_s01_faixa_inferior.png`).
- *Proposta:* zoom de 1,15–1,25 no combate e linha do chão a ~78% da altura. A faixa de baixo passa a guardar legenda e barra de chefe (casa com o item 4). Fazer depois do item 1 e testar junto.

**32. NEURO R1–R5 e R10.** I:A · E:M · dono: combate
- Flash no hitstop, hitstop por peso, tremor sem soma, um acerto = um evento, telegrafo (item 9) e um máximo de 3 flashes/s com a opção "Reduzir flashes". Já está planejado (Fases A/B). Listo aqui porque é o maior ganho de "sensação" barato e precisa entrar antes da demo.

**33. Ícones de botão dinâmicos.** I:M · E:M · dono: ui-menus + ui-hud
- Hoje convivem "J · ler a Estela", "qualquer tecla avança · Esc pula" (`s68_clear.png`) e rodapés mistos como "W/S · setas · analógico rolam · Esc / B volta" (`credits.png`, `chron.png`). O ícone deve seguir o último dispositivo usado (teclado, Xbox ou PlayStation). Isso é necessário para o Deck Verified.

**34. Opções que faltam.** I:A · E:M · dono: ui-menus + tecnico
- Hoje: tela cheia, VSync, tremor, vibração, legendas e 3 volumes (`options.png`).
- Faltam: idioma, remapeamento de teclas e botões, reduzir flashes, velocidade do texto, números de dano liga/desliga e janela/resolução.
- Também falta trocar a dificuldade no meio da campanha (ex.: só para baixo).
- Remapeamento e "reduzir flashes" são os pedidos de acessibilidade que mais aparecem em reviews.

**35. O Bestiário revela reúso de sprite e não tem lore.** I:M · E:M · dono: ui-menus (+arte-GPT)
- "Larva do Kenoma", "Sombra Errante" e "Larva Ardente" têm o mesmo desenho, assim como "Guardião Espinhoso" e outros (`gallery.png`). O motivo: 22 tipos de inimigo usam só 6 recortes de `inhabitants`. Nenhuma entrada tem texto.
- *Proposta:* variantes por recolor ou acessório para cada nome, e 2 linhas de lore + 1 dica tática por criatura, liberadas por encontro.

**36. Erro de polígono na barra do HUD.** I:B · E:P · dono: ui-hud (`hud.gd:371`)
- Dez erros "Invalid polygon data, triangulation failed" quando a barra-fantasma fica mais estreita que o chanfro, por exemplo na morte (`log_s12_die.txt`). Usar largura mínima de `2*s` ou não desenhar.

**37. Ferramentas de dev e banco de controles na build.** I:M · E:P · dono: tecnico
- REVISAO #6: com `GNOSIS.exe res://tools/Showcase.tscn`, qualquer um vê todos os chefes. REVISAO #4: o `gamecontrollerdb.txt` não é exportado.
- Ajustar `exclude_filter` e `include_filter` no preset.

### [2] Antes do lançamento

**38. Cena B: o roubo é contado em rubricas.** I:A · E:G · dono: encenacao
- O coração do jogo é texto entre parênteses: "(Os sete Anéis se arrancam dos teus dedos...)" em `narrative.gd theft()`. A captura passa direto para o Centro (`s64_clear.png`, onde o HUD já mostra "roubados"). A API existe (`hud.detach_ring`). Implementar a Cena B do ROTEIRO e a NARRATIVA M6: os anéis saem do HUD, a voz troca de lugar e a máscara cai.

**39. Cena D e escolha final.** I:A · E:M · dono: encenacao + ui-hud (`dialogue_box.gd _show_choices`)
- A6 do QA: a caixa com 3 opções estoura a borda direita, e "Semente" aparece bloqueado sem explicação.
- Os rótulos devem mostrar o motivo (NARRATIVA §2) e a condição do Semente, sem depender de tooltip de mouse. A anagnórise precisa de encenação, não de bloco de texto.

**40. Trilha de banco reconhecível e uma música de chefe para todos.** I:A · E:G · dono: audio + João
- As 14 faixas são de Kevin MacLeod ("Volatile Reaction", "Night of Chaos", "Crossing the Chasm"...; `assets/LICENSES.md`), conhecidas de milhares de vídeos. Existe um único `boss.ogg` para 9 chefes.
- A licença está correta. O problema é a percepção de produto barato.
- Mínimo original: tema do menu, música de Arconte, música do final e do Centro (a NARRATIVA M8, "música = memória", depende disso). As faixas de MacLeod podem ficar como temporárias.

**41. Repetição estrutural.** I:A · E:G · dono: combate + encenacao + cenario
- As telas 2–64 repetem 7 vezes o mesmo molde de 9 telas (chegada, travessias, Desafio, travessias, antessala, Arconte), com o mesmo fundo em cada Éon (item 29). O bot leva 72 min; um humano, 2–2,5 h. O risco é a review dizer "repetitivo depois da 1ª hora".
- *Proposta:* uma travessia por Éon que mude a regra com as mecânicas que já existem. Torpor: névoa que lenta e fecha a visão. Fome: chão que suga. Corrente: correntes no cenário. Silêncio: sem magia e sem música. Espelho: a Sombra imita. Praga: chão venenoso. Coroa: ondas de servos.
- Se o playtest (item 14) mostrar cansaço, cortar 1–2 travessias por Éon do meio.

**42. Tamanho dos chefes inconsistente.** I:M · E:P · dono: combate (escala no Bestiary)
- O Astaphaios tem praticamente a altura da Sophia (`s46.png`), o Athoth ~1,5× (`s10.png`), o Rei ocupa meia tela (`s01.png`). Arconte deveria ter pelo menos ~1,8× a altura dela, e o Espelho pode ser a exceção de propósito.

**43. Mesma plataforma e mesmo chão em todos os Éons.** I:M · E:M · dono: cenario
- A laje de pedra com veio roxo e o chão escuro se repetem em `s05.png`, `s12.png`, `s22.png`, `s29.png`, `s50.png` e `s64_clear.png`. Precisam de material por Éon: madeira de mercado, ferro, papel, vidro, musgo, ouro.

**44. "Ceder" à tentação não custa nada.** I:M · E:M · dono: encenacao + balance
- Ceder dá 80 faíscas, e o "eles cobram" da Voz nunca se cumpre (`level.gd`; NARRATIVA §1, item 13). Uma escolha sem consequência ensina o jogador a ignorar escolhas. Opções: um custo visível depois (Anel rachado, −1 nível até o Centro), efeito no final, ou retirar a escolha.

**45. Epílogos sem arte própria.** I:M · E:M · dono: arte-GPT + encenacao
- O final Ascensão é texto sobre o fundo do Silêncio escurecido (`s68_clear.png`). Fazer uma ilustração por final e uma do "reclamar".

**46. Progressão de arma invisível.** I:M · E:M · dono: arte-GPT local
- "Sophia Nv.1", "Nv.3" e "Nv.5" são quase idênticas; muda só um arco de luz (`gallery.png`). O GDD promete que a aparência evolui. A recompensa de 5 níveis precisa ser vista: brilho do cajado, bracelete, manto.

**47. NEURO no áudio: R6, R9 e R11.** I:M · E:M · dono: audio
- Som da faísca quando ela chega, silêncio antes do chefe, round-robin com limite de vozes. Ganho alto de "sensação" com pouco esforço.

**48. Adormecidos sem voz.** I:M · E:P · dono: encenacao (`sleeper.gd`)
- O final Semente pede que o jogador tenha "olhado" para eles, mas hoje acordam mudos. O texto está pronto na NARRATIVA §8 (`sleeper_line`).

**49. Steam Cloud, conquistas e rich presence.** I:M · E:M · dono: tecnico
- O Steam Cloud é só configuração. Proposta de ~20 conquistas: uma por Arconte, os 3 finais, 18/18 Estelas, um chefe sem dano. Nada que dependa de sorte ou de "volte amanhã".

**50. Trailer.** I:A · E:M · dono: loja
- 60–90 s com combate em que a Sophia aparece no quadro, 3 chefes, o Rei e uma pergunta do mito. Depende dos itens 1, 4, 9 e 31, porque gravar antes disso mostra os defeitos.

### [3] Polimento

**51. O chão do Centro não é de engrenagens.** I:B · E:P · dono: cenario
- A fala diz "O chão é feito de engrenagens. Giram devagar", e o chão é a mesma pedra lisa (`s65.png`). Ou o chão ganha engrenagens animadas, ou a fala muda.

**52. O pré-jogo entrega a estrutura.** I:B · E:P · dono: ui-menus
- "68 telas · sete Éons · sete Arcontes · O Centro · A Mente" (`pregame.png`): "O Centro" e "A Mente" vêm depois da virada, e "68 telas" soa como lista de tarefas. Melhor: "Sete Éons · Sete Arcontes · ~2–3 h".

**53. Ornamentos sobre controles.** I:B · E:P · dono: ui-menus (`codex_sanctum.gd`)
- Círculos decorativos em cima do slider de Música e dos títulos (`options.png`, `atelier.png`, `pregame.png`; P1 do QA). Parecem cursores.

**54. Registro do português.** I:B · E:P · dono: encenacao
- O "tu" de registro europeu ("Prometi mostrar-te", `s63.png`; "Chama-me Voz") se mistura com próclise brasileira ("eu te mostro"). Se for estilo mítico, que seja consistente. Conferir com `docs/ESTILO_TEXTO.md`.

**55. Animação das criaturas comuns.** I:M · E:G · dono: arte-GPT local
- As criaturas são um quadro único com movimento procedural (ROADMAP "Falta"). Não verifiquei em movimento, porque as capturas são quadros parados. Se o playtest disser que elas "deslizam", isso entra na faixa [1].

---

## O que já está bom (não mexer sem motivo)
- O **menu principal** tem cara de produto (`menu.png`), e a Sophia ilustrada lê bem no combate por vestir branco (`c_s05_sophia.png`).
- **Fundos por Éon** com identidade clara de cor: Fome vermelha, Corrente cinza de gaiolas, Silêncio violeta com sol negro, Espelho de vidro, Praga verde, Coroa dourada (`s12.png`, `s22.png`, `s29.png`, `s40.png`, `s50.png`, `s63.png`).
- **Chefes ilustrados** fortes: Harmas (`s19.png`), Belias (`s55.png`), Armupiel (`s64.png`).
- **Santuário/loja**, **Crônicas** e **tela de fim** limpos e legíveis (`upgrade.png`, `chron.png`, `end.png`). O fluxo morte → checkpoint funciona (`s12_die.png`), e o 64 → roubo → Centro passa sem travar (`s64_clear.png`).
- O texto das legendas é bom e tem voz própria. O problema é onde e quando ele aparece, não o conteúdo.
- Nenhum `SCRIPT ERROR` nas 41 capturas. O único erro é o item 36.

## Limites desta crítica
- Sem áudio, sem controle real, sem jogar de verdade: feel, dificuldade e ritmo humano são estimativas, e só o item 14 responde.
- As telas 1–68 foram amostradas, não percorridas inteiras. Telas que não capturei: 3, 4, 7–9, 11, 13–16, 18, 20–21, 23–28, 30–34, 36–39, 41–45, 47–49, 51–54, 56–59, 62 e 66 (essa passou só no `clear`).
- O Colosso Oco não apareceu em nenhuma captura da 68. Não sei se é enquadramento ou momento da luta: vale uma sonda.
