# ESTILO DE TEXTO — GNOSIS (guia de voz, glossário e regras de caixa)

> Diretor de Roteiro & Texto, Onda 1 (17/10/2026). **Vale para todo texto do
> jogo** — narrativa (`narrative.gd`, `gnosis.gd`, `cinematic.gd`) e UI
> (`scripts/ui/**`). Se a UI precisar de uma palavra do glossário, use a forma
> daqui. Dúvida = este arquivo manda; o código segue.

## 1. Dois registros, nunca misturados

> **MUDOU (29/10/2026, decisão do chefe/João: "texto de bíblia"):** o diegético passa a ser **PT-BR com
> "você"** (contrações na boca da Sophia e da Voz: "tô", "né", "pra", "a gente"; o Rei fala sem contração e
> com "nós" majestático). Já valem as telas 1–2 (prólogo, despertar, Cena A, duelo e queda do Rei, chegada ao
> Torpor). O resto do jogo ainda está em "tu" até a reescrita completa: a tabela abaixo é a regra ANTIGA.
> Texto e tom de referência: `_caps/narrativa/AMOSTRA_LIMIAR.md` (fora do git).

| Registro | Onde | Pessoa | Exemplo |
|---|---|---|---|
| **Diegético** (o mundo falando) | falas, legendas, Estelas, cards de prólogo/epílogo | **tu / vós** com conjugação correta | "Não pares. Sobe." |
| **Sistema** (o jogo falando ao jogador) | menus, dicas, toasts de mecânica, botões | **imperativo de "você"** ou impessoal | "Vença Athoth para liberar." · "Derrube a outra forma!" |

- No diegético: imperativo afirmativo de *tu* = 3ª do presente (*anda, sobe,
  olha, levanta*); negativo = subjuntivo (*não pares, não olhes, não confies,
  não filosofes*). Pronome oblíquo em ênclise na fala solene (*levanta-te,
  chama-me, ajoelha-te*), próclise permitida na fala da Sophia.
- "**para**" em todo texto diegético; "**pra**" só na boca da Sophia, e só em
  fala curta e emotiva. Na UI, sempre "para".
- **Nunca** "você" no diegético; **nunca** "tu" na UI.

## 2. Quem fala e como (falante = string exata do campo `speaker`)

**A Voz** (`"A Voz"`) — o guia sem corpo. *(Segredo: é Yaldabaoth. Ninguém sabe
até a tela 64.)* Solícita, possessiva, arcaizante. Frases curtas, imperativo
seco no fim ("Sobe."). Chama a Sophia de **Portadora** ou **faísca** — **nunca
pelo nome** (nega o nome na tela 40). Conta a cosmologia com o **viés do
carcereiro**: a Luz de cima abandonou as faíscas; "eu olho por ti"; "vieste de
mim"; "não confies nas pedras"; "não pares para ler". Chama o Demiurgo só de
**o Cego** (fala de si mesmo na 3ª pessoa sem saber-se denunciado — ironia).
Tique verbal: fecha ordens com "**Sobe.**" (é a palavra dela; ninguém mais a
usa sozinha). Pressa cresce Éon a Éon. Nunca mente de forma verificável antes
do roubo — **desvia** ("Ignora.", "Lembrar tem hora.").

**Sophia** (`"Sophia"`) — a faísca sem memória. Português brasileiro sóbrio,
perguntas curtas, frases de constatação. Usa *tu* ao dirigir-se à Voz e aos
outros (o mundo fala assim). **Pensamento** entre parênteses com maiúscula e
pontuação completa: "(Uma pedra escrita, logo adiante.)" A dúvida cresce de
Éon em Éon; ela cita as Estelas ("a pedra diz…") só **depois** da tela em que
a Estela fica (ver mapa em `ROTEIRO.md`).

**O Rei** (`"O Rei"`) — sacerdote branco, régio, gentil demais. Arcaico,
cerimonial, frases inteiras com ênclise ("Mostra-me a tua luz"). Fala de "lei"
e "limiar". Partilha com a Voz a mesma cadência — mas **nunca** o tique
"Sobe." (seria entregar).

**Yaldabaoth** (`"Yaldabaoth"`, só da tela 64 em diante) — quando a máscara
cai, a voz da Voz sem o veludo: mesma sintaxe, agora com desprezo. Uma palavra
em CAIXA ALTA por fala, no máximo. **Depois da queda (tela 68), minúsculas e
frases de criança**: "...mãe? eu não queria ser cego."

**Os Arcontes** (uma fala de tentação cada, antes da luta — sempre terminada
pela Voz com "Escolhe."):
- **Athoth** (Torpor): sussurro, reticências, oferta de sono. Quase canção de ninar.
- **Harmas** (Fome): sensorial, diminutivos, cheiro e gosto. Mercador.
- **Galila** (Corrente): jurídico, frio, cláusulas. Classifica, não odeia.
- **Yabel** (Silêncio): **não fala** — só rubrica entre parênteses.
- **Astaphaios** (Espelho): devolve as palavras dela; usa "nós".
- **Belias** (Praga): cansado, lento, fatalista. Não mente; confunde cansaço com verdade.
- **Armupiel** (Coroa): pomposo, título antes do nome, "quase" como ferida.

**Soter** (`"Soter"`) — o Ungido; nunca luta. Calmo, caloroso, proverbial;
imagens de **mãos** (abrir/fechar) e de **nomes**. Não ordena, convida; a única
ordem dele é "Escolhe." antes da bênção. Diz a verdade, mas pela metade.

**Velkar** (`"Velkar"`) — o Arconte arrependido. Frases quebradas, culpa,
concretude física (o braço que a corrente levou). A única voz que fala da
"criança cega".

**Estelas** (painel de leitura) — inscrição impessoal, tom de ensaio claro.
Linhas 1–5: o ensino histórico (fiel às fontes, com citação marcada quando é
citação). Última linha: o **gancho com o Éon** onde a pedra está, podendo usar
*tu*. Nunca falam da Voz nem do Rei.

**Narrador** (prólogo/epílogo, `cinematic.gd`/`epilogue_cards`) — mesma voz das
Estelas: 3ª pessoa, pretérito. Pode dirigir-se ao jogador (*tu*) só na última
frase de um final.

## 3. Glossário canônico (grafia única)

| Termo | Grafia | Nota |
|---|---|---|
| Mônada | **Mônada** | a Fonte inefável; "o Um", "a Fonte", "o Pai" (Estelas) |
| Pleroma | **o Pleroma** | a Plenitude; "a Luz de cima" (na boca da Voz) |
| Kenoma | **o Kenoma** | o mundo-prisão; "o vazio", "a falta" |
| Éon | **Éon / Éons** | maiúscula sempre (emanação do Pleroma **e** ato do jogo: "Éon do Torpor") |
| Arconte | **Arconte / Arcontes** | maiúscula sempre, inclusive nas Estelas |
| Demiurgo | **o Demiurgo** | só nas Estelas/UI; a Voz diz **o Cego** |
| Yaldabaoth | **Yaldabaoth** | também *Saklas* (o Tolo) e *Samael* (deus dos cegos) — só nas Estelas |
| Sophia | **Sophia** | nunca "Sofia" |
| faísca | **faísca / faíscas** | minúscula; é a luz presa **e** a moeda. Não usar "centelha" |
| Anel | **Anel / Anéis** | maiúscula; "o sétimo Anel" |
| gnose | **gnose** | minúscula (substantivo comum); "Gnose" só em título |
| hyle | **hyle** | minúscula, sem itálico (a matéria) |
| Heimarmene | **Heimarmene** | o Destino astral |
| o Chamado | **o Chamado** | maiúscula |
| Adormecido | **Adormecido(s)** | maiúscula (NPC) |
| Estela, Crônicas | **Estela(s)**, **Crônicas** | objetos de jogo, maiúscula |
| Portadora | **Portadora** | tratamento que a Voz, os Arcontes e Soter dão à Sophia |
| o Limiar, o Centro, a Mente | maiúscula | lugares do arco |
| Campeão, santuário, antessala, travessia | Campeão maiúsculo; os demais minúsculos | |
| Éter | **Éter** | o recurso de magia (UI) |
| Arcontes canônicos | **Athoth, Harmas, Galila, Yabel, Astaphaios, Belias, Armupiel** | nunca outros nomes |

**Proibido** (respeito a fés vivas): Sabaoth, Adonai/Adonaios, Iao, Eloaios
ou qualquer nome sagrado como vilão. Citações históricas de textos que
mencionam Jesus/salmos ficam **neutras e marcadas como citação**.

## 4. Pontuação e tipografia

- **Reticências**: três pontos `...` (não o caractere `…`). Sem espaço antes.
- **Travessão**: `—` (em dash) com espaço dos dois lados, para aposto e pausa.
  Nunca dois travessões na mesma fala.
- **Aspas**: curvas duplas `“ ”` para citação; simples curvas `‘ ’` dentro de
  citação. Aspas retas `'` não.
- **Rubrica** (ação visível): entre parênteses, **minúscula inicial**,
  presente, ≤ 10 palavras, no começo da fala: `(sai da névoa) Tão bem...`
- **Pensamento** da Sophia: frase inteira entre parênteses, maiúscula inicial.
- **Narrador** na caixa (ex.: o custo da queda): falante vazio `""`, rubrica entre
  parênteses com maiúscula — "(A luz te costura de volta. 37 faíscas escorrem…)".
- **Marcação de cena**: falas encenadas levam `cue` (ver `docs/ROTEIRO.md` §2);
  o texto nunca depende do efeito para ser entendido.
- **CAIXA ALTA**: no máximo **uma palavra** por fala, para grito. Nunca frase.
- **Números**: por extenso nas falas ("o sétimo Anel", "treze arrependimentos");
  algarismos só na UI e em datas/referências das Estelas (1945, NHC II,1).
- Ponto de exclamação: raro. A Voz quase nunca grita; Yaldabaoth sim.

## 5. Comprimento (base 640×360; medido pelo `tools/GnoseQA`)

| Lugar | Limite | Por quê |
|---|---|---|
| Fala na **caixa de diálogo** | **≤ 2 linhas** no tamanho M (13 px) e **≤ 3** no G (16 px) — na prática ≤ 115 caracteres (medido: ~75 car./linha a 13 px, ~55 a 16 px) | texto de 488 px; a 3ª linha a 13 px empurra o "▸ continuar" |
| **Legenda** de caminhada | **≤ 2 linhas** a 11 px — na prática ≤ 95 caracteres | faixa de 26 px; dura 3–5,2 s |
| Linha de **Estela** | ≤ 170 caracteres; **≤ 6 linhas**; painel inteiro ≤ 330 px de altura | painel 500 px a 11 px |
| **Card de chefe** | nome ≤ 18 caracteres; título ≤ 52 | letterbox de 600 px |
| **Card de prólogo/epílogo** | ≤ 4 linhas de ~60 caracteres | coluna de 470 px a 13 px |
| **Toast** do HUD | ≤ 60 caracteres | uma linha |

Uma fala = uma ideia. Se precisa de "e" duas vezes, vira duas falas.

## 6. Regras de ouro (narrativa)

1. **A virada não vaza antes da tela 64.** Nada diz, nem por ironia explícita,
   que a Voz é o Rei/Yaldabaoth ou que os Anéis são a Sophia. Permitido:
   ambiguidade (a Voz desvia, nega o nome, tem pressa; a Estela ensina que o
   Chamado verdadeiro "deixa ir").
2. **A Sophia só cita o que já pôde ler.** Legenda que menciona uma Estela toca
   na tela da Estela **+1** ou depois.
3. **Nenhuma fala repete no run.** Cada legenda tem lugar fixo (Éon × tela × zona).
4. **Metalinguagem proibida** no diegético: "tela", "fase", "chefe", "HP",
   "botão". (O Campeão e o santuário existem no mundo; "Desafio" é palavra da UI.)
5. **Respeito**: filosofia antiga contada com seriedade; nunca zombaria de fé
   viva; docetismo e afins como disputa histórica, sem tomar partido.
