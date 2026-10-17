# GNOSIS — DIREÇÃO DE NARRATIVA EMOCIONAL (Onda 1 → implementação na Onda 2)

> Diretor de Narrativa Emocional · 17/10/2026 · base lida: `codex/despertar` (run de 68 telas).
> Documento de DIREÇÃO: não editei código. Tudo aqui está pronto para o diretor de
> Roteiro & Texto colar/adaptar em `narrative.gd`, `gnosis.gd`, `cinematic.gd`,
> `npc_encounter.gd` (dele) e para pedir ganchos de 1 linha nos arquivos de outros
> donos (`level.gd`, `enemy.gd`, `final_battle.gd`, `sleeper.gd`, `dialogue_box.gd`).
>
> **Regras que este documento respeita:** Sophia única · a Voz = Yaldabaoth, revelado
> SÓ no roubo (tela 64) · "os Anéis são a Sophia" SÓ no reclamar (tela 68) · 7 Arcontes
> canônicos · Soter não luta · Velkar arrependido · Centro sem magias · batalha dupla ·
> 3 finais · nenhum nome sagrado de fé viva como vilão.
>
> **Limites de texto medidos no código:** caixa de diálogo (`DialogueBox`, ~500 px úteis,
> fonte 11/13/16) → **≤ 110 caracteres por fala**, ideal ≤ 90. Legenda de caminhada
> (`CaptionBar`, 2 linhas, 3–5 s) → **≤ 85 caracteres**. Todas as falas abaixo cabem.

---

## 0. A TESE EM UMA FRASE

**Sophia tem medo de ser abandonada porque um dia ela abandonou.** No mito real
(Apócrifo de João 10), Sophia vê o filho disforme que gerou, tem vergonha, o
envolve numa **nuvem luminosa com um trono no meio** e o esconde. O jogo inteiro é
ela, sem memória, sendo guiada justamente pela criança que ela escondeu — que
aprendeu com ela a esconder, mentir e prender. O "quarto branco" que ela lembra em
flashes é **aquela nuvem**. O clímax não é matar: é **olhar** para quem ela não
quis ver. Os três finais são três jeitos de nunca mais abandonar ninguém — e cada um
tem um preço.

Tudo neste documento serve essa tese: a Voz precisa ser AMADA (para o roubo doer),
os Arcontes precisam ser FILHOS (para Velkar e o reclamar fazerem sentido), e as
lembranças precisam vir em duas cores: **as quentes são falsas** (inventadas pela
Voz) e **as frias são verdadeiras** (vazam dos Anéis).

---

## 1. DIAGNÓSTICO EMOCIONAL (honesto)

**O que já funciona (manter):**
- A dúvida que cresce nas legendas de caminhada ("A Voz diz muita coisa", "As pedras
  dizem uma coisa; a Voz, outra") — é o melhor fio do texto atual.
- As sementes do "quarto branco" (`ring_gained` sono, `_cleared_pool` Torpor e Espelho).
- `death_revive` antes do roubo: possessiva e urgente — o melhor foreshadow que existe.
- "Os ecos não gritam quando caem. Choram." · a fala de Velkar sobre a "criança cega".
- A pedagogia pela contradição (Estelas × Voz) e o epílogo da Ruptura.

**Onde é só informação:**
1. `eon_intro` (7 Éons): todas as falas são da Voz explicando o lugar ("Éon do X.
   Aqui...") — a Sophia não diz nada ao chegar. O jogador recebe um mapa, não um estado
   de espírito.
2. Cerca de 1/3 das falas da Sophia nas legendas começam com "A pedra diz/dizia...".
   Ela soa como aluna lendo, não como pessoa sentindo. Máximo 1 "a pedra diz" por Éon.
3. `final_lines`: o maior momento do jogo é um bloco de 3 falas explicando o lore
   ("Cacos meus que tu arrancaste e forjaste em correntes..."). Explica, não fere.
4. `echo_shard`: o pagamento central do tema (lembrar quem se é) é um **toast de HUD**
   ("Caco de memória: X volta a ti"). É entregue como item, não como lembrança.

**Onde falta motivação pessoal da Sophia:**
5. A intro diz "as cinzas eram a tua gente" e **nunca mais isso volta**: sem nomes,
   sem rostos. Harmas oferece "tua casa, tua gente, teu riso" — o jogador nunca viu
   nada disso, então a tentação é abstrata.
6. Soter diz "Carrego os nomes deles, se um dia quiseres ouvi-los" — **setup sem
   payoff**. Nunca ouvimos um nome.
7. A Sophia nunca diz o que QUER. Ela pergunta, duvida, mas não deseja, não ri, não
   chora. Sem desejo não há perda.

**Onde a virada não dói o suficiente:**
8. A Voz é tutor, não companheira. Contei ~30 imperativos ("Anda", "Sobe",
   "Escolhe") e **nenhum** momento de carinho que não seja instrumental. Ninguém chora
   a traição de um GPS. Para o roubo doer, o jogador precisa ter rido com a Voz, ter
   sido consolado por ela e ter dividido uma lembrança com ela.
9. No `theft()` a Sophia **não fala nenhuma vez**. É o vilão narrando o próprio plano.
   Nenhuma fala anterior da Voz é colhida (callback) — então a revelação é dita, não
   reconhecida.

**Onde personagens são funções:**
10. Arcontes falam uma vez (tentação) e morrem mudos; fase 2 sem texto. A tragédia
    deles (filhos do Cego, feitos "à sua imagem") é exatamente o que Velkar e o
    reclamar precisam — e não está em cena.
11. Soter: 3 encontros que terminam num menu de loja (bênção). Velkar: um monólogo; a
    Sophia não responde.
12. **Adormecidos não têm voz nenhuma** (`sleeper.gd` acorda por proximidade, só som +
    faíscas). O "contrapeso moral" do final Semente não existe em jogo.
13. "Ceder" à tentação só dá 80 faíscas; a Voz diz "eles cobram" e nada é cobrado.

**Bugs/inconsistências de texto (corrigir já):**
- `_arrival_pool(5)[6]` (tela **53**) a Sophia cita "Velkar disse..." — mas Velkar só
  aparece na tela **61** (`level._spawn_extras`: Éon 6, offset 5). E a tela 53 é a do
  3º Soter. Fala fora de ordem.
- Comentários desatualizados: `narrative.gd` cabeçalho "antes da tela 50"; Soter
  "telas 10, 24, 38" (real: **17, 35, 53**); Velkar "tela 45" (real: **61**);
  `final_battle.gd` "tela 54" (real: **68**); `theft` "tela 50" (real: **64**);
  `center_intro` "tela 51" (real: **65**).

---

## 2. O ARCO DA SOPHIA

| | |
|---|---|
| **Ferida (ela não sabe)** | Escondeu o próprio filho numa nuvem de luz e o deixou sozinho num trono pequeno. |
| **O que QUER (consciente)** | Saber quem é. E não estar sozinha — ter alguém que a guie e fique. |
| **O que TEME** | Ser deixada. O Pleroma "que não olha pra baixo" (a Voz explora isso: "Eu olho. Eu fiquei."). |
| **A MENTIRA em que acredita** | "Alguém de fora vai me dizer quem eu sou." |
| **A VERDADE que conquista** | "Lembrar é meu. E o que salva não é ser olhada — é olhar." |
| **O que PRECISA (inconsciente)** | Olhar para o que escondeu e reclamar (não destruir). |

**Regra do nome:** antes do Centro, **ninguém chama a Sophia de "Sophia" em voz alta**
(a Voz diz "Portadora", Soter e Velkar também; a Voz desconversa quando ela acha o
nome na pedra). O rótulo da caixa pode continuar "Sophia" (é UI). Ela só diz o próprio
nome no reclamar: **"Meu nome é Sophia. Fui eu quem te deu o teu."**

### Os 7 degraus (um por Éon)

| Éon | Ela entra acreditando | O que racha | Ela sai com | Fala-marco (nova, em `eon_intro`, depois da Voz) |
|---|---|---|---|---|
| Torpor | "A dor é o inimigo." | Athoth morre e diz que acordar dói e é bonito. | A dor é dela — é real. | **Sophia:** "Eu também queria deitar. ...Não vou." |
| Fome | "Preciso recuperar o que perdi." | Harmas sabe da "janela pro rio" que só a Voz contou. | Réplica não é retorno. E talvez nem fosse dela. | **Sophia:** "Eu nem sei o que perdi. Como vou recusar o que ele me oferecer?" |
| Corrente | "Obedecer me mantém segura." | Galila: a lei é medo de cair. | Começa a escolher, não só a obedecer. | **Sophia:** "Eu sigo uma voz que não vejo. Isso também é corrente?" · **Voz:** "É confiança. É diferente. Anda." |
| Silêncio | "Não perguntar me protege." | Ouve a voz fraca por baixo da Voz; Yabel fala ao morrer. | Perguntar é lembrar. | **Sophia:** "Tem uma voz por baixo da tua. Aqui, no silêncio, eu vou ouvi-la." |
| Espelho | "Sou quem a Voz diz que eu era." | O vidro racha: no lugar do rio, o quarto branco. | Existe outro passado — frio e verdadeiro. | **Sophia:** "Eu quero ver o meu rosto. Mesmo que ele me ataque." |
| Praga | "Não adianta." (cansaço) | Belias morre e algo brota; Soter dá os nomes. | Esperança sem garantia. | **Sophia:** "Estou cansada. Pela primeira vez eu digo em voz alta: cansada." |
| Coroa | "Preciso de alguém que me diga quem sou." | Nada racha — é o **pico do apego à Voz** ("ficar contigo"). | A mentira no ponto mais forte… e cai na 64. | **Sophia:** "Último degrau. Depois eu descubro quem sou. Tu prometeste." |
| Centro | "Sem a Voz eu não sou nada." | Cada eco devolve um caco frio e verdadeiro. | "Ninguém me levanta. Então eu." | (ver Momento 8) |
| Mente | "Ele é o monstro." | O Colosso é oco; dentro, uma criança cega. | Olhar, não matar. | "Levanta. Eu te seguro." |

**A escolha final dá sentido aos 3 finais** porque cada um é uma resposta ao medo dela
(ninguém mais abandonado) com um preço diferente:
- **Ascensão — "levar todos pra casa":** ninguém fica para trás… mas ninguém escolheu ir.
  Os que dormiam deixam de sonhar sem nunca terem acordado. Amor que não pergunta.
- **Ruptura — "ficar no trono e proteger":** ninguém abandonado, nunca mais… porque
  ela vira a Voz. O último card é a fala de abertura do jogo, na voz dela. Amor que prende.
- **Semente — "descer e acordar um por um":** respeita a escolha de cada um. Lento,
  incompleto, humano. Amor que solta. (Exige ter acordado Adormecidos — ou seja, ter
  olhado para eles no caminho.)

Troque os rótulos em `final_choices` para mostrar o MOTIVO, não só o nome:
`"Ascensão — levar todos pra casa"` · `"Ruptura — ficar no trono e proteger"` ·
`"Semente — descer e acordar um por um"`.

---

## 3. A VOZ COMO PERSONAGEM AMADA — plantio e colheita

**Princípio:** o amor da Voz **não é 100% mentira**. É o amor possessivo de uma
criança abandonada que finalmente tem a mãe por perto — e precisa dela para um plano.
Isso faz a releitura doer em dobro e deixa a porta aberta para o Jogo 2 (o Demiurgo
protagonista que "a amava à sua maneira"). Depois do roubo, a crueldade dele é **medo**.

**Guia de voz da Voz (antes do roubo):**
- Chama a Sophia de "Portadora". Nunca de "Sophia". Desconversa sobre o nome.
- Fala do Pleroma como "eles", "os de cima" — nunca "nós".
- Humor seco, autodepreciativo. 1 piada a cada ~2 Éons, não mais.
- **Nunca fala enquanto Soter está em cena** (o Cego não o vê) — e depois não sabe com
  quem ela falava.
- Reage à morte de cada Arconte com uma micro-pausa "(...)" antes de falar do Anel
  (é um pai ouvindo um filho morrer). Depois de Armupiel: só **"Sete."**
- A urgência cresce de Éon em Éon (já existe — manter).

### 12 momentos de afeto (plantio) → colheita no roubo/final

Os 7 santuários (tela de Desafio, offset 4: **6, 15, 24, 33, 42, 51, 60**) viram o
"fogo de acampamento" da dupla: uma conversa curta em `DialogueBox` **antes** de abrir
a loja. É o lugar natural do carinho (o jogador acabou de vencer o Campeão, está
seguro, a música baixa).

| # | Tela / gatilho | Fala (plantio) | Por que o jogador gosta | Releitura depois do roubo |
|---|---|---|---|---|
| V1 | 1 · intro | **Voz:** "Acorda. ...Isso. Devagar. Eu estou aqui." | Primeira voz do mundo é gentil. | Ele estava esperando a chave acordar. |
| V2 | 1ª morte do run | **Voz:** "Não. Não, não, não. LEVANTA." (já existe) | Pânico genuíno = alguém se importa. | Pânico de perder a chave. E de perder a mãe — os dois são verdade. |
| V3 | **6** · santuário Torpor | **Voz:** "Tu tinhas uma casa com uma janela pro rio. Contavas os barcos." · **Sophia:** "...Não lembro." · **Voz:** "Eu lembro por ti. Por enquanto." | Ela ganha um passado. Calor. | **Nunca houve rio.** Ele inventou. (Colhido no roubo.) |
| V4 | **12** · zona limpa (Fome) | **Voz:** "Bonito golpe. Eu teria aplaudido, se tivesse mãos." | Primeira piada. A Voz vira alguém. | No roubo, ele aplaude — com as mãos do Rei. |
| V5 | **15** · santuário Fome | **Sophia:** "Fala comigo até passar?" · **Voz:** "Falo. Tenho todo o tempo do mundo. ...Literalmente." | Companhia; humor. | Ele FEZ o tempo do mundo. |
| V6 | **19** · tentação de Harmas | **Voz:** "Ele está usando a tua janela. Não deixa. Essa lembrança é nossa." | A Voz defende o passado dela. Cumplicidade. | "Nossa" = dele. Harmas sabe da janela porque os dois são a mesma mente. |
| V7 | **24** · santuário Corrente | **Sophia:** "Como tu és? De verdade." · **Voz:** "Feio. Acredita: é melhor assim." · **Sophia:** "(e pela primeira vez desde as cinzas, eu rio.)" · **Voz:** "...Faz isso mais vezes. Combina contigo." | O riso dela. Ternura dele. | Cabeça de leão, corpo de serpente (Estela "O Aborto Cego"). Era verdade. |
| V8 | **33** · santuário Silêncio | **Voz:** "Aqui eu fico quieto. Fala tu, hoje. Eu escuto." · **Sophia:** "Sonhei de novo com o quarto branco. Tinha um trono pequeno no meio." · **Voz:** "(um silêncio longo demais) ...Sonhos. Descansa. Eu vigio." | Ela se abre; ele escuta. | Ele ouviu a mãe lembrar do berço onde o largou. |
| V9 | **42** · santuário Espelho | **Sophia:** "Como eu era? Antes." · **Voz:** "Teimosa. Contavas os barcos errado de propósito, só pra eu te corrigir." | Uma intimidade "compartilhada". | O "eu" da memória é ele se pondo num passado que não existiu. |
| V10 | **46** · Anel do Espelho (`ring_gained` espelho, troca o "Ignora") | **Voz:** "Este Anel pesa, não? ...Eu também não sei bem o que sou." · **Voz:** "Só sei que não quero ficar sozinho de novo." | Vulnerabilidade. A Voz também sofre. | "De novo": a nuvem. É a fala mais verdadeira que ele diz antes do roubo. |
| V11 | **51** · santuário Praga | **Voz:** "Se cansares, encosta em mim. Não tenho ombro. Mas tenho paciência de eras." | Conforto no Éon do desespero. | Eras de paciência = eras de espera pela chave. |
| V12 | **60** · santuário Coroa | **Voz:** "Quando acabar... o que vais fazer?" · **Sophia:** "Não sei. Ficar contigo? Se deixares." · **Voz:** "...Sim. Comigo. Sempre." | O pico do vínculo. O jogador sorri. | Colhido no roubo: "Tu disseste que ficavas." — a frase que mais dói do jogo. |

### Pistas sutis (só fazem sentido na releitura — nenhuma entrega a virada)

| Pista | Onde | Status |
|---|---|---|
| "Não temas — **eu o conheço**. É um rei antigo, e é gentil." (ele fala de si mesmo) | `king_intro` | já existe — manter |
| O Rei ao cair: "Tua luz é maior do que **eu lembrava**." (ele a conhece) | `king_fall` | já existe — manter |
| A Voz nunca diz "Sophia"; "É um nome comum" | `_arrival_pool(4)[2]` | já existe — manter |
| "Vieste de mim. Eu te achei." — eco do grito do Cego ("não há outro além de mim") | `_arrival_pool(2)[6]` | já existe — manter |
| "Um nome aqui vira coleira." — ela é quem deu o nome a ele | `_cleared_pool(1)[6]` | já existe — colher no reclamar |
| **A Voz não vê Soter**: "Com quem falavas? ...Não vi ninguém." (Soter: "o Cego não me vê") | legenda após Soter 1 | **novo** |
| "Dizem que um tal Soter anda por aqui. **Eu nunca o vi.**" | troca `_arrival_pool(1)[6]` | **novo** |
| A Voz se cala na antessala do Silêncio ("Nem eu falo lá dentro") — ele calou Yabel | `_arrival_pool(3)[7]` | já existe — manter |
| Harmas e Astaphaios conhecem a "janela pro rio" | tentações 19 e 46 | **novo** |
| "Eu preciso de ti INTEIRA" (a chave inteira) | `death_revive` | já existe — manter |
| "Eu refaria o mundo inteiro pra te pôr de pé." | `death_revive` T4 | **novo** |
| Micro-pausa "(...)" antes de cada Anel; "Sete." seco após Armupiel | `ring_gained` | **novo** |
| Velkar: "Tu inclinas a cabeça como quem escuta alguém." | `velkar_meeting` | **novo** (ver §5 — pista forte, opcional) |
| Estela "Desconfia da voz que chama e depois não solta." (57) | `gnosis.gd` | já existe — manter: quem lê as pedras entende antes |

**O que NÃO fazer:** nenhuma negação direta da Voz ("Eu não sou o Cego") — negar
planta a hipótese. Nenhum Arconte chama a Voz de "pai" diante da Sophia antes da 64.

---

## 4. ARCONTES COMO TRAGÉDIAS

Fato canônico (Estela "Os Sete Arcontes"): Yaldabaoth os gerou "à sua semelhança".
**Cada Arconte é um filho do Cego carregando um pedaço da solidão do pai** — e cada
tentação é o jeito que aquele filho achou de não sentir a ferida. Assim Velkar ("era
meu pai") e o reclamar ("eu só queria que alguém olhasse pra mim") viram o fecho de
um padrão que o jogador já viu sete vezes.

**Onde entra cada fala:**
- **Entrada** = a tentação (`temptation`, já pausa com Recusar/Ceder). Substitui a 1ª fala.
- **Fase 2** = legenda sem pausar (`Gnosis.caption`) disparada em `enemy._enter_phase2`
  — gancho de 1 linha (pedido ao dono do `enemy.gd`).
- **Morte** = primeira fala de `ring_gained` (já é um `DialogueBox` após a queda —
  **muda só `narrative.gd`**, nenhum outro arquivo). Seguida da micro-pausa da Voz.

### Athoth — Torpor
- **Ferida:** o primeiro filho. Viu a solidão do pai antes de todos e escolheu dormir
  para não senti-la. Faz os outros dormirem por **piedade**, não por crueldade.
- **Eco no Éon:** a cidade que sonha que não morreu.
- **Entrada:** "Portadora... tu também não dormes, não é? Eu conheço esse cansaço. Deita. Eu sonho o resto por ti."
- **Fase 2:** "Por que acordar?! Lá fora só tem a falta!"
- **Morte:** "Ah... então é isto, estar acordado. Dói. ...É bonito."
- **Voz depois:** "(um silêncio curto demais) ...O primeiro Anel. Sente." + a fala do quarto branco (já existe).

### Harmas — Fome
- **Ferida:** feito da falta (o Kenoma). Não tem nenhuma lembrança própria; coleciona
  as dos outros para sentir alguma coisa.
- **Eco:** o mercado onde todos mastigam e ninguém come.
- **Entrada (3 falas):**
  - **Harmas:** "A tua casa. A janela pro rio. Os barcos que contavas. Tenho tudo aqui, quentinho. Fica."
  - **Sophia:** "(como ele sabe da janela?)"
  - **Voz:** "Arcontes roubam lembranças. Essa é nossa. Não deixa. Escolhe."
- **Fase 2:** "Me dá UMA! Uma lembrança que seja minha!"
- **Morte:** "Eu nunca provei nada que fosse meu. Guarda as tuas. Guarda bem."

### Galila — Corrente
- **Ferida:** medo de desabar. Acorrentou primeiro a si mesmo. A lei é o abraço que
  nunca recebeu.
- **Eco:** o tribunal de selos; "um trono feito de elos".
- **Entrada:** "Sem lei, tudo cai. Eu caí uma vez. Ajoelha, e ninguém te solta nunca mais."
- **Fase 2:** "Se eu soltar, eu caio! TODOS caem!"
- **Morte:** "Leve... é assim, sem elo? Ninguém me disse... que era leve."

### Yabel — Silêncio
- **Ferida:** quando o pai gritou "Eu sou deus e não há outro", uma voz de cima
  respondeu: "Erras, Samael" (Hipóstase dos Arcontes). Yabel perguntou, em voz alta,
  de quem era aquela voz. O pai costurou a boca dele.
- **Eco:** a biblioteca apagada; a verdade calada.
- **Entrada:** "(ele não fala. Aponta a própria boca costurada. Depois, a tua. Oferece o descanso de nunca mais responder.)"
- **Fase 2:** "(os pontos da boca dele esticam. Alguma coisa lá dentro quer sair.)"
- **Morte (versão A, recomendada):** "(os pontos se rompem. A primeira palavra em eras:) Alguém respondeu a ele, lá de cima. Era... a tua voz."
- **Morte (versão B, se o Roteiro achar forte demais):** "(os pontos se rompem) Alguém respondeu a ele uma vez. Eu ouvi. Ele me costurou por isso."
- *(A versão A sugere que ela é a Sophia do mito — já sugerido pela pedra com o nome
  dela. Não revela a Voz.)*

### Astaphaios — Espelho
- **Ferida:** feito à imagem de uma imagem. Nunca teve rosto próprio. Quer o dela.
- **Eco:** as poças; "em cada poça, eu".
- **Entrada:** "Olha. Tu, antes das cinzas, à janela, contando barcos. Fica deste lado do vidro. Eu fico com o resto."
- **Fase 2 (2 legendas):**
  - "(o vidro racha. No lugar do rio, por um instante: um quarto branco. Alguém pequeno chorando.)"
  - **Astaphaios:** "Esse não! Esse reflexo não é pra ti!"
- **Morte:** "Fica com o teu rosto. Eu nunca tive um. ...Era bonito, o teu."

### Belias — Praga
- **Ferida:** um jardineiro que viu morrer tudo o que plantou. O desespero dele é
  compaixão torta: quer poupar os outros do fim.
- **Eco:** o pântano onde as faíscas apagam como velas.
- **Entrada:** "Tudo apodrece, Portadora. Vi morrer tudo que plantei. Rende-te agora e te poupo do fim."
- **Fase 2:** "Por que insistes? Eu só quero que pare de doer!"
- **Morte:** "(na poça dele, uma coisa verde, minúscula) ...Brotou? Não olha pra mim. Olha aquilo."

### Armupiel — Coroa
- **Ferida:** o filho que quase-foi-pai. Quis ser visto pelo Cego tomando o lugar dele.
- **Eco:** os tronos vazios esperando alguém sentar.
- **Entrada:** "O Cego nunca olhou pra mim. Talvez olhe pra ti. Toma a coroa. Sê o que eu quase fui."
- **Fase 2:** "Corte! Ao rei! ...Ninguém vem. Nunca ninguém vem."
- **Morte:** "Diz a ele que eu... não. Ele não escuta. Nunca escutou."
- **Voz depois (substitui a fala atual da coroa):** "Sete." · "(...)" · "Vem. Sobe ao santuário. É hora do ritual."
  *(Na releitura: o pai ouviu o último filho morrer pedindo para ser ouvido, e disse um número.)*

---

## 5. SOTER e VELKAR

### Soter — ensina a GRAÇA (receber sem pagar) e que as pessoas eram REAIS
Contraste com a Voz: cada volta da Voz **custa faíscas**; Soter dá e não pede nada.
Soter carrega os **nomes** do povo das cinzas — o fio que paga a intro e o final Semente.
Os nomes são inventados (sem carga religiosa): **Ina, Merou, Tasso.** Note: **não há
rio** nas lembranças de Soter — há um **poço**. A verdade é mais humilde que a mentira.

**Encontro 1 — tela 17 (Fome)**
- **Soter:** "Paz, Portadora. Guarda a lâmina. O Cego não me vê — e contigo não brigo."
- **Sophia:** "Quem és tu?"
- **Soter:** "Alguém que desce sem precisar. Conheci a gente das cinzas onde acordaste."
- **Soter:** "Carrego os nomes deles. Quando quiseres ouvir, pergunta. Hoje, deixa-me só ungir o que já é teu."
- → bênção · **legenda depois que ele some:** **Voz:** "Com quem falavas? ...Não vi ninguém. Anda."

**Encontro 2 — tela 35 (Silêncio) — o "senta"**
- **Soter:** "De novo tu. Mais funda, mais forte, mais cansada. Senta. O mundo espera."
- **(sem rótulo):** "(tu sentas. Por um instante, nada te persegue.)"  ← *pausa de 2 s: ver §8*
- **Sophia:** "Os nomes. Me diz um."
- **Soter:** "Ina. Padeira. Cantava errado de propósito, pra filha rir. A filha ria sempre."
- **Soter:** "Sabes por que não luto? Toda lâmina, até a justa, ensina a mão a fechar. A tua ainda abre."
- → bênção · **legenda depois:** **Voz:** "Paraste muito tempo. Não para. ...Por favor."

**Encontro 3 — tela 53 (Praga)**
- **Soter:** "Última vez deste lado, Portadora. Lá em cima, nem eu alcanço."
- **Soter:** "Merou, que tirava água do poço pra quem não podia. Tasso, que dormia no telhado pra ver os astros."
- **Sophia:** "Eles eram a minha gente?"
- **Soter:** "Eram de todos. Por isso também são teus. Lembra disso, quando te disserem outra coisa."
- **Soter:** "E quando ficares sozinha, não tenhas medo do silêncio. O silêncio também é teu."
- → bênção · **legenda depois:** **Voz:** "Falta pouco. Não deixa ninguém te atrasar agora."

### Velkar — ensina a MISERICÓRDIA com o monstro, e a FICAR
Velkar é a prova de que um filho do Cego pode acordar. Ele prepara o reclamar ("acaba
direito") e prefigura o Semente (alguém tem de ficar com os que acordam tarde).

**Encontro — tela 61 (Coroa)**
- **Velkar:** "Não recua a lâmina, Portadora. Já fui Arconte. Larguei a corrente... e ela levou meu braço junto."
- **Sophia:** "Por que largaste?"
- **Velkar:** "Porque uma faísca me olhou como tu olhas os Adormecidos. Não aguentei ser olhado assim."
- **Velkar:** "Lá em cima não há tirano. Há uma criança cega, num trono grande demais, chamando pela mãe."
- **Sophia:** "...Tu choras por ele?"
- **Velkar:** "Todo dia. Era meu pai."
- **Velkar (pista forte — OPCIONAL):** "Tu inclinas a cabeça como quem escuta alguém. Eu já inclinei assim."
- **Velkar:** "Quando chegares nele, acaba direito. Toma: faíscas que colhi quando era monstro. Pesam menos em ti."
- *(opcional, escolha sem efeito mecânico: "Vem comigo" / "Fica em paz")* → **Velkar:** "Não. Alguém tem de ficar com os que acordam tarde."
- **legenda depois:** **Sophia:** "Ele disse 'criança'. Tu nunca me disseste isso." · **Voz:** "Velkar perdeu o braço e o juízo. Anda."
- *(isso substitui a fala que hoje está fora de ordem na tela 53)*

---

## 6. MOMENTOS-ÂNCORA (10)

Ferramentas que já existem: `DialogueBox` (pausa), `Gnosis.caption` (não pausa),
`Cinematic` (cards/letterbox), `Juice.slow_mo/shake/hit_stop`, `Audio.play_music/stop_music`,
faixas `theme, rei, eon_*, boss, roubo, centro, mente, epilogo`.
**Proposta transversal:** a faixa **`theme` vira o tema da Voz** (o jogador a ouviu
no menu; volta nos santuários, distorcida no roubo, simples no reclamar).

### M1 — Acordar (tela 1)
- **Gatilho:** fim do prólogo em cards.
- **Encenação:** tela preta 1,5 s, **sem música**; um batimento (sfx); fade-in na
  Sophia caída nas cinzas. Só depois da 1ª fala da Voz entra a faixa `rei` baixa.
- **Falas (substitui `intro`):**
  - *(sem rótulo)* "(escuro. Um coração batendo. Depois, cinza na boca.)"
  - **Voz:** "Acorda. ...Isso. Devagar. Eu estou aqui."
  - **Sophia:** "Onde... quem...?"
  - **Voz:** "Uma pergunta de cada vez. Primeiro: as cinzas sob teus pés eram a tua gente."
  - **Voz:** "A dor que sentes é a única coisa real que este mundo te deu. Ela quebrou o feitiço."
  - **Voz:** "Sobe. Cada faísca que libertares lembrará o que tu és. E eu lembrarei contigo."
- **Por que emociona:** a primeira coisa que o jogador recebe é cuidado. E a frase "a
  dor é a única coisa real" é, na releitura, a primeira mentira — o luto era emprestado.

### M2 — Harmas sabe da janela (tela 19)
- **Gatilho:** tentação. **Encenação:** música do chefe cai para -10 dB na linha
  "(como ele sabe da janela?)"; meio segundo de silêncio antes da Voz responder.
- **Falas:** ver §4 Harmas.
- **Por que emociona:** a primeira vez que o passado "quente" é usado como arma — e a
  primeira vez que a Voz soa protetora ("essa é nossa").

### M3 — Soter: "Senta." (tela 35)
- **Gatilho:** aproximar de Soter. **Encenação:** música do Éon cai para -14 dB ao
  abrir o diálogo; na linha "(tu sentas...)" a caixa espera 2 s sem aceitar input
  (ou só a linha, sem o "▸ continuar"); depois o nome de Ina.
- **Falas:** ver §5 Encontro 2.
- **Por que emociona:** primeiro respiro real do jogo e primeiro rosto (um nome, um
  gesto: cantar errado para a filha rir) do povo que ela diz ter perdido.

### M4 — O espelho racha (tela 46)
- **Gatilho:** fase 2 de Astaphaios. **Encenação:** `Juice.hit_stop(0.25)` +
  legenda; a luta continua. No `ring_gained` do Espelho, a Voz se abre (V10).
- **Falas:** ver §4 Astaphaios + V10.
- **Por que emociona:** o passado bonito (rio) é trocado à força por um passado
  estranho (quarto branco, alguém chorando). E logo depois a Voz, pela primeira vez,
  admite medo de ficar sozinha.

### M5 — "Ficar contigo" + Velkar (telas 60 e 61)
- **Gatilho:** santuário da Coroa (60), Velkar (61).
- **Encenação:** no santuário, a faixa `theme` toca baixa (tema da Voz). Na fala
  "...Sim. Comigo. Sempre." a música **para** — 1 s de silêncio — e a loja abre.
- **Falas:** V12 + §5 Velkar.
- **Por que emociona:** o jogador vê a promessa que vai ser quebrada daqui a 4 telas.
  Velkar, logo em seguida, chora pelo pai — o jogador ainda não sabe que o pai está ouvindo.

### M6 — O ROUBO (tela 64) — o coração do jogo
- **Gatilho:** queda de Armupiel → `ring_gained` ("Sete.") → `theft()`.
- **Encenação (ordem):**
  1. Logo após "Sete." a música do chefe **corta seca** (sem crossfade).
  2. A Voz fala na caixa com o rótulo **"A Voz"** (como sempre).
  3. O Rei sai da névoa (inteiro). **Truque principal:** a fala seguinte vem com o
     rótulo **"A Voz"**, mas a rubrica diz que sai da boca do Rei. O jogador entende
     pelo rótulo antes de qualquer explicação.
  4. Os Anéis são arrancados (sfx `ring_steal`, `Juice.shake(0.8)`, os ◆ do HUD ficam
     cinza **durante** o diálogo se possível).
  5. Só depois de o jogador entender, o rótulo muda para **"Yaldabaoth"**. A faixa
     `roubo` entra.
  6. Última fala dele, baixa, sem música. Fade para o Centro.
- **Falas (substitui `theft`):**
  - **Voz:** "Chegaste. Todos os sete. Fizeste tudo tão bem, minha fiel."
  - **Sophia:** "E agora? Tu prometeste me mostrar."
  - *(sem rótulo)* "(passos na névoa. Um vulto que tu conheces. A máscara sem rachadura.)"
  - **A Voz:** "(a voz já não vem de dentro de ti. Vem da boca do Rei.) Mostrar. Sim."
  - **A Voz:** "(ele aplaude, devagar.) Eu disse que aplaudiria, se tivesse mãos. Tenho."
  - **Sophia:** "...Não."
  - *(sem rótulo)* "(os sete Anéis se arrancam dos teus dedos e voam pra ele, como quem volta pra casa.)"
  - **Yaldabaoth:** "Chama-me pelo nome que nunca te disse: Yaldabaoth. Portadora... sabes o que portavas? A mim."
  - **Yaldabaoth:** "Nunca houve rio. Nunca houve janela. Tua gente? Cinzas de uma colheita qualquer."
  - **Yaldabaoth:** "Eu te dei um luto pra te dar um caminho. Luto é a coleira mais macia."
  - **Sophia:** "Eu chorei por eles."
  - **Yaldabaoth:** "Choraste por mim. Os sete eram meus filhos — e tu me trouxeste o que restou deles."
  - **???:** "(de dentro dos Anéis, fraca) ...espera... eu... lembro..."
  - **Yaldabaoth:** "(mais baixo, quase a Voz de antes) Tu disseste que ficavas comigo."
  - **Yaldabaoth:** "(ele vira um motor de anéis girando e afunda no chão) Desta vez, não levanta."
- **Por que emociona:** cada fala dele **colhe** uma fala anterior (aplauso V4, rio
  V3/V9, "portadora", "ficar" V12, "levanta" das mortes). O jogador não aprende a
  virada — ele a **reconhece**. E a Sophia fala: "...Não." e "Eu chorei por eles." são
  as duas falas mais curtas e mais pesadas do jogo.

### M7 — A descida: o Centro (tela 65)
- **Gatilho:** entrada da tela 65.
- **Encenação:** **nenhuma música** (só ambiente/vento) até o primeiro eco quebrar.
  HUD dos Anéis todo cinza. Caixa de diálogo com pausas longas.
- **Falas (substitui `center_intro`):**
  - *(sem rótulo)* "(silêncio. Nenhuma voz. Pela primeira vez, só o som da tua respiração.)"
  - **Sophia:** "Voz?"
  - **Sophia:** "..."
  - **Sophia:** "Ninguém. ...Então eu."
  - **Sophia:** "Os ecos dele estão aqui embaixo. Cada um guarda um pedaço que ele me tirou. Vou buscar."
- **Por que emociona:** o "Voz?" é o jogador também — ele se acostumou com a
  companhia. "Então eu" é a virada do arco da Sophia, em duas palavras.

### M8 — O primeiro eco devolve um caco (tela 65) — "música = memória"
- **Gatilho:** `level._restore_echo` (hoje: toast). Passa a disparar legenda.
- **Encenação:** `Juice.slow_mo(0.3, 0.6)` na quebra do eco; o caco voa para a
  Sophia; **a faixa `centro` entra pela primeira vez** (memória voltando = música
  voltando). Cada caco seguinte sobe a música um degrau (ver §8).
- **As 6 lembranças verdadeiras (uma por eco, na ordem dos ecos; a 7ª é M9).** Contam
  o Apócrifo de João em 1ª pessoa — o jogador que leu as Estelas reconhece o mito; agora
  é DELA. Cada uma = 1–2 legendas (`Gnosis.caption`, sem pausar — o Centro tem larvas):
  1. **Torpor:** "Antes de tudo, eu não dormia. Ninguém dormia. Éramos muitos, olhando juntos."
  2. **Fome:** "Eu quis ver a Fonte sozinha. Tive fome de um rosto que ninguém tinha visto."
  3. **Corrente:** "Do meu querer sem par nasceu alguém. Pequeno. Torto. Meu."
  4. **Silêncio:** "Tive vergonha. Fiz uma nuvem de luz, pus um trono pequeno no meio... e fechei." · "O quarto branco. Era isso."
  5. **Espelho:** "Ele gritou que não havia outro além dele. Eu respondi lá de cima: 'Erras, Samael.'" · "Foi a última vez que falei com ele."
  6. **Praga:** "Eu chorei. Das lágrimas veio a água; do medo, a matéria. Este mundo é o meu luto."
  - Depois do 2º caco, uma legenda extra (paga Soter): **Sophia:** "Não havia rio. Havia um poço. Merou tirava água dele. Eles existiram."
- **Por que emociona:** o tema central (lembrar = gnose) vira experiência: o jogador
  monta a verdade junto com ela, caco a caco, enquanto luta. E descobre que ela não é
  só vítima — ela é a origem da ferida.

### M9 — O 7º Anel volta na queda (tela 68)
- **Gatilho:** `final_battle._on_form_down`, primeira queda (já devolve o Anel da Coroa).
- **Encenação:** `Juice.slow_mo(0.2, 1.2)`; o anel dourado voa de órbita para a mão
  dela; flash; a faixa `mente` sobe +3 dB. Legendas (a luta continua — o relógio de
  14 s está correndo, então **não pausar**):
  - **Sophia:** "A Coroa voltou. E com ela, o porquê. Eu desci de propósito."
  - **Sophia:** "Pra desfazer o que tu fazias. E pra te buscar."
- **Por que emociona:** o pico de poder mecânico coincide com o pico de memória. Ela
  não veio destruir; veio buscar. Isso muda o que o jogador sente ao bater nas duas formas.

### M10 — O reclamar e os 3 finais (tela 68)
- **Encenação:** quando as duas formas caem: `slow_mo` (já existe), **corte de
  música**, os 7 Anéis descem até ela um a um (≈0,3 s cada, sfx `shard`). A faixa
  `theme` (tema da Voz) volta **sozinha, lenta**, na fala "Levanta. Eu te seguro."
- **Falas (substitui `final_lines`):**
  - *(sem rótulo)* "(as duas formas caem juntas. Os sete Anéis param no ar... e voltam pra ti, um por um.)"
  - **Sophia:** "Eles não são o teu corpo. São o meu. Cacos meus, que tu forjaste em correntes."
  - **Sophia:** "Entrei no teu mundo pra te deter. E os meus próprios cacos me fizeram esquecer."
  - *(sem rótulo)* "(o Colosso se abre. Está oco. Lá no fundo, encolhido, cego, alguém pequeno.)"
  - **Yaldabaoth:** "...mãe? eu não queria ser cego. eu só queria que alguém olhasse pra mim."
  - **Sophia:** "Fui eu quem fechou a nuvem. Fui eu quem te deixou lá. Eu estou olhando agora."
  - **Sophia:** "Levanta. Eu te seguro."
  - **Sophia:** "(ela o recolhe pra dentro de si — não pra morrer: pra ser visto.) Meu nome é Sophia. Fui eu quem te deu o teu."
  - **Sophia:** "Falta o mais difícil: um mundo inteiro de gente que dorme. Ninguém vai escolher por mim."
  - → escolha (rótulos novos, §2).
- **Fala curta de cada final (nova função `ending_lines(idx)`, `DialogueBox` antes do epílogo):**
  - **Ascensão:** **Sophia:** "Vamos pra casa. Todos." · *(sem rótulo)* "(o Kenoma começa a se desfazer, como sonho ao amanhecer. Ela olha pra trás uma vez.)"
  - **Ruptura:** **Sophia:** "Ninguém mais vai ser abandonado. Eu fico. Eu olho por todos." · *(sem rótulo)* "(o trono ainda está morno. Serve.)"
  - **Semente:** **Sophia:** "Não vou subir. Não vou sentar. Vou descer e bater em cada porta." · *(sem rótulo)* "(lá embaixo, nas cinzas onde ela acordou, alguém começa a se mexer.)"
- **Epílogos (substitui `epilogue_cards`; 3 cards cada):**
  - **Ascensão** (música: `epilogo`):
    1. "As sete esferas apagaram como lamparinas ao amanhecer. Os Arcontes viraram o que sempre foram: nomes."
    2. "Os que dormiam não acordaram. Só deixaram de sonhar. Ninguém perguntou se queriam."
    3. "No colo da Fonte, uma criança aprendeu a ver. A mãe olhou pra trás uma vez. Bastou pra lembrar. Não pra ficar."
  - **Ruptura** (música: `theme` lenta — o tema da Voz, agora dela):
    1. "A coroa pesava menos do que ele dizia. Isso devia ter sido o aviso."
    2. "Sete tronos, sete cascas novas. O Kenoma não percebeu a diferença. Ela cuidava de todos. De todos."
    3. "Um dia, numa cidade de cinzas, alguém acordou e ouviu uma voz gentil: 'Acorda. As cinzas sob teus pés eram a tua gente.'"
  - **Semente** (música: `epilogo`; se houver, o tema da Voz cantarolado simples):
    1. "Ela desceu, tela por tela, batendo à porta dos que dormem. Alguns abriram. Outros pediram mais um pouco de sonho. Ela esperou."
    2. "Na cidade das cinzas, aprendeu os nomes. Ina, que cantava errado. Merou, do poço. Tasso, do telhado. Disse cada um em voz alta."
    3. "Não eram a gente dela. Agora são. E dentro dela, pequeno, alguém aprendia a ver."
- **(Opcional, gancho do Jogo 2, depois dos créditos em qualquer final):** card preto,
  sem música: *"...mãe?"* — 2 s. Não contradiz nenhum final e prepara o Demiurgo protagonista.
- **Por que emociona:** a frase do carcereiro ("Levanta") vira, na boca dela, a frase
  da mãe. Os nomes trocados (o dela, o dele) fecham a pergunta central do jogo. E cada
  final é uma forma de amor — nenhum é "o final mau".

---

## 7. MORTE COM SIGNIFICADO (`death_revive`)

Hoje: 4 blocos em ciclo, iguais do início ao fim. Proposta: **faixas por número de
mortes** (antes do roubo), **por cacos recuperados** (Centro) e **por mortes dentro da
Mente** (final). Todas cabem na mesma assinatura `death_revive(screen, deaths, lost)`.
Mantém o `%d faíscas` em uma fala por faixa.

### Antes do roubo (telas 1–64) — a Voz, de ternura a posse
- **T1 · mortes 1–2 (ternura em pânico)**
  - a) **Voz:** "Não. Não, não, não. LEVANTA." · "Agarra a minha voz e sobe por ela. Não te perco numa vala do Kenoma." · "(a luz te costura de volta; %d faíscas escorrem da tua mão aberta)"
  - b) **Voz:** "Shh. Já passou. Eu te tenho." · "Respira. Ou o que quer que tu faças no lugar disso."
- **T2 · mortes 3–6 (cuidado que vira posse)**
  - c) **Voz:** "De novo. Fica quieta. Eu seguro a tua faísca — ela não escapa de mim."
  - d) **Voz:** "Custa caro, cada volta. Paga com as faíscas, não contigo. Tu vales cada fagulha. (%d escorreram)"
  - e) **Voz:** "O corpo lembra da queda? Que lembre também de quem te ergueu. Todas as vezes."
- **T3 · mortes 7–12 (urgência; a máscara range)**
  - f) **Voz:** "Levanta. Eu preciso de ti INTEIRA." · "...De ti. Eu preciso de ti. Foi o que eu quis dizer."
  - g) **Voz:** "Não morras antes da hora. ...Antes de acabarmos. Antes de acabarmos juntos."
  - h) **Voz:** "Quantas vezes forem precisas. Eu não sei desistir de ti. Não agora. Não tão perto."
- **T4 · mortes 13+ (cansaço, o ciclo)**
  - i) **Voz:** "Tu cais e eu te refaço. Já fizemos isto antes, tu e eu. Muito antes."
  - j) **Voz:** "Eu refaria o mundo inteiro pra te pôr de pé." · "...Não me olha assim. É modo de falar."
- **Variante de tela de Arconte (qualquer faixa, 1ª morte naquele Arconte):**
  - **Voz:** "Ele não fica contigo. Ninguém fica contigo. Só eu." · "Sobe. Os tronos não se vencem deitada."
- *Releitura:* "Já fizemos isto antes" (o ciclo da Ruptura), "refaria o mundo" (ele o fez),
  "INTEIRA" (a chave), "Ninguém fica contigo. Só eu." (a nuvem ao contrário).

### O Centro (65–67) — cacos dela mesma (por `Progression.restored_rings.size()`)
- **0 cacos:** **Sophia:** "(escuro. Nenhuma voz. Só os cacos, quentes, me juntando do chão.)" · "Ninguém me levanta. ...Então eu levanto."
- **1–2 cacos:** **Sophia:** "(os cacos que já voltaram me costuram. Têm a minha letra.)" · "Eu já fui despedaçada antes. Não foi assim que acabou."
- **3–4 cacos:** **Sophia:** "Ina cantava errado. Merou carregava água. Tasso via os astros." · "Eu levanto por eles."
- **5–6 cacos:** **Sophia:** "(quase inteira. Os cacos não me erguem por obrigação.)" · "Me erguem por saudade."

### A Mente (68) — os Anéis contra o dono das mãos (contador de mortes só da tela 68)
- **1ª:** **Yaldabaoth:** "MORRE. Por que tu não MORRES?" · **Sophia:** "(os Anéis param de girar... descem... e me costuram, caco por caco)" · "Eles lembram de mim. Mesmo nas mãos dele."
- **2ª:** **Yaldabaoth:** "Eu os forjei! Eles são MEUS!" · **Sophia:** "Tu os forjaste. Mas foi de mim que os tiraste."
- **3ª:** **Yaldabaoth (na voz antiga, gentil):** "Fica no chão, Portadora. Eu cuido de tudo. Como sempre." · **Sophia:** "Não. Já não é a tua voz que me levanta."
- **4ª+:** **Yaldabaoth:** "...Por que eles te escolhem?" · **Sophia:** "Porque eu nunca os prendi."

---

## 8. RESPIRO E CONTRASTE (com direção de áudio)

| # | Onde | O que acontece | Áudio / silêncio (para o diretor de Áudio) |
|---|---|---|---|
| R1 | Tela 1, depois do prólogo | Acordar (M1) | 1,5 s de **silêncio total** + 1 batimento; `rei` entra baixa só após a 1ª fala da Voz. |
| R2 | Os 7 santuários (6, 15, 24, 33, 42, 51, 60) | Conversa da dupla (V3, V5, V7, V8, V9, V11, V12) antes da loja | Faixa do Éon cai para -12 dB (ou troca para **`theme`** baixa = tema da Voz). Sem SFX de combate. A loja mantém a música baixa. |
| R3 | Soter 2 (35) | "Senta." (M3) | Música do Éon a -14 dB; na linha "(tu sentas...)" 2 s sem nada; um sino/acorde suave quando ele diz "Ina". |
| R4 | Cada Adormecido (≈13 no run) | Acorda e fala uma legenda (lista abaixo) | `sleeper_wake` + **duck** da música -6 dB por 3 s. |
| R5 | Santuário da Coroa (60) | "...Sim. Comigo. Sempre." (V12) | `theme` toca baixa; **para** na última palavra; 1 s de silêncio antes da loja. |
| R6 | Centro (65–67) | Sophia sozinha (M7/M8) | **Sem música** até o 1º eco. Depois `centro` entra e **sobe com os cacos** (volume em degraus: 1 caco -18 dB … 6 cacos 0 dB; se um dia houver stems, cada caco acrescenta um instrumento). Morrer no Centro não reseta: a música lembra o que ela lembrou. |
| R7 | Final Semente | Epílogo | Se o João conseguir: o motivo do `theme` cantarolado, simples, uma voz só. Senão, `epilogo`. |

**Tema da Voz (proposta barata):** usar a faixa **`theme`** como leitmotiv da Voz:
santuários (baixa) → roubo (a mesma faixa com `pitch_scale` 0,7–0,8 por 3–4 s, antes
de cortar para `roubo`) → reclamar (normal, lenta, sozinha) → Ruptura (de novo, agora é
dela). Requer só um parâmetro de pitch em `Audio.play_music` (pedido ao Áudio).

### Adormecidos — legendas ao acordar (nova `Narrative.sleeper_line(screen)`)
Speaker: "Adormecido" / "Adormecida". Determinístico por tela (a fala 7, da Ina, só depois da tela 35). Mistura gratidão,
medo e recusa (é o contrapeso moral do Semente):
1. "Eu estava sonhando com a minha mãe. Por que me acordaste?"
2. "Está frio aqui fora. Sempre esteve?"
3. "Quanto tempo eu dormi? ...Não. Não me diz."
4. "Obrigada. Acho."
5. "Tu também estavas dormindo? Tens a cara."
6. "Se eu acordo, quem cuida do meu sonho?"
7. "Eu lembro de uma mulher que cantava errado. Ina? Tu conheceste a Ina?"
8. "Deixa a luz acesa. Só um pouco."
9. "Ele disse que dormir era bondade. Quem disse? Não lembro quem disse."
10. "Meu filho dorme duas ruas pra lá. Vai lá também? Por favor?"
11. "Dói. Por que acordar dói?" · **Sophia:** "Porque é teu."
12. "Eu não pedi isso. ...Mas agora que vejo, não quero fechar os olhos."
(Recomendação ao dono do `sleeper.gd`/gameplay, opcional: acordar por botão, como a
Estela, em vez de por proximidade — acordar alguém tem de ser um GESTO.)

### Santuários — texto completo (nova `Narrative.sanctuary(eon)`)
- **0 Torpor (6):** V3.
- **1 Fome (15):** **Sophia:** "Fala comigo até passar?" · **Voz:** "Falo. Tenho todo o tempo do mundo. ...Literalmente."
- **2 Corrente (24):** V7.
- **3 Silêncio (33):** V8.
- **4 Espelho (42):** V9.
- **5 Praga (51):** **Sophia:** "Eu não aguento mais." · **Voz:** "Então encosta em mim. Não tenho ombro. Mas tenho paciência de eras."
- **6 Coroa (60):** V12.

---

## 9. LISTA DE IMPLEMENTAÇÃO (Onda 2 — ordem de impacto ÷ esforço)

Legenda de dono: **R** = Roteiro (implementa direto) · **P** = precisa de gancho de
1–3 linhas em arquivo de outro dono (Roteiro escreve o pedido em `docs/pedidos/`).

| # | Arquivo / função | Mudança | Impacto | Esforço | Dono |
|---|---|---|---|---|---|
| 1 | `narrative.gd` `theft()` | Reescrever conforme M6 (callbacks, rótulo "A Voz" saindo da boca do Rei, Sophia fala). | Máximo | Baixo | R |
| 2 | `narrative.gd` `final_lines()` + `final_choices()` + nova `ending_lines(idx)` + `epilogue_cards()` | M10 completo; rótulos com motivo; Ruptura fecha com a fala de abertura. | Máximo | Baixo | R (+P `level._win`: tocar `ending_lines` entre a escolha e o epílogo — 1 linha) |
| 3 | nova `narrative.gd` `sanctuary(eon)` | 7 conversas (V3, V5, V7, V8, V9, V11, V12). | Alto (é o que faz amar a Voz) | Baixo | R + **P** `level._on_screen_cleared` ramo "trial": `await DialogueBox.play(Narrative.sanctuary(eon)).finished` antes da loja |
| 4 | `narrative.gd` `temptation()` + `ring_gained()` | Entradas novas dos 7 Arcontes; **fala de morte prepended** em `ring_gained`; micro-pausa da Voz; "Sete."; V10 no Espelho. | Alto | Baixo | R (só `narrative.gd`) |
| 5 | `narrative.gd` `death_revive()` | Faixas T1–T4, Centro por cacos, Mente com contador próprio (`final_deaths` em `Narrative`, zera em `reset()`). | Alto | Baixo | R |
| 6 | nova `narrative.gd` `echo_memory(boss_id)` + `gnosis.gd` `captions(lines)` | 6 lembranças verdadeiras (M8) + a do poço após o 2º caco. | Alto | Baixo | R + **P** `level._restore_echo`: trocar o toast por `Gnosis.captions(Narrative.echo_memory(boss_id))` (pode manter o toast) |
| 7 | `narrative.gd` `center_intro()` + `walk_arrival/walk_cleared` do Centro | M7 ("Voz?" / "Então eu"); trocar "berçário dele" por falas coerentes com os cacos. | Alto | Baixo | R |
| 8 | `npc_encounter.gd` + `soter_meeting()` + `velkar_meeting()` | Novos textos (§5); legenda da Voz depois de cada encontro (`Gnosis.caption` após o fade); escolha opcional de Velkar. | Alto | Baixo | R |
| 9 | **Bug** `_arrival_pool(5)[6]` (tela 53) | Trocar a fala que cita Velkar por: **Sophia:** "Um homem com um braço só me olhou de longe. Não se aproximou." · **Voz:** "Arcontes caídos rondam estas bandas. Não lhes dá ouvidos." | Médio (coerência) | Mínimo | R |
| 10 | `_arrival_pool(1)[6]` (tela 17) | "Dizem que um tal Soter anda por aqui. Eu nunca o vi." | Médio (pista) | Mínimo | R |
| 11 | `eon_intro()` | Acrescentar a fala-marco da Sophia por Éon (§2). | Médio | Mínimo | R |
| 12 | `intro()` | M1 (Sophia fala; "Eu estou aqui"). | Médio | Mínimo | R |
| 13 | nova `narrative.gd` `archon_phase2(boss_id)` | 7 legendas de fase 2 (§4). | Médio | Baixo | R + **P** `enemy._enter_phase2`: `if is_boss_enemy and RunManager.run_active: Gnosis.captions(Narrative.archon_phase2(type_id))` |
| 14 | nova `narrative.gd` `seventh_ring()` | 2 legendas de M9. | Médio | Mínimo | R + **P** `final_battle._on_form_down` (bloco `_first_fall_done`): 1 linha + `Juice.slow_mo(0.2, 1.2)` |
| 15 | nova `narrative.gd` `sleeper_line(screen)` | 12 falas de Adormecidos. | Médio (moral do Semente) | Baixo | R + **P** `sleeper._on_body_entered`: `Gnosis.caption(...)` |
| 16 | `_cleared_pool` / `_arrival_pool` | Trocar 4–6 falas "A pedra diz..." da Sophia por falas sensoriais/humor; incluir V4 ("Eu teria aplaudido...") em `_cleared_pool(1)`, substituindo "Mais faíscas. Sente como pesam menos?". | Médio | Baixo | R |
| 17 | `dialogue_box.gd` | Campo opcional `"cue"` na fala (`music_stop`, `music:<faixa>`, `shake`, `wait:<s>`) — permite encenar o roubo, o "senta" e o reclamar sem espalhar `await` no `level.gd`. | Médio (habilita M3/M5/M6/M10) | Médio | **P** (dono da UI) |
| 18 | `audio_manager.gd` | `play_music(faixa, loop, pitch)`; duck temporário; volume de `centro` por cacos; corte seco. | Médio | Médio | **P** (Áudio) |
| 19 | Comentários desatualizados | `narrative.gd` (50→64, Soter 17/35/53, Velkar 61), `final_battle.gd` (54→68). | Baixo | Mínimo | R (+P) |
| 20 | `concession_response()` / epílogo Ruptura | Se `concessions >= 4`: card extra na Ruptura: "Sete vezes provou os presentes deles. O trono só lhe pareceu familiar." | Baixo | Baixo | R |
| 21 | Gancho Jogo 2 | Card "...mãe?" após os créditos. | Baixo (estratégico) | Mínimo | R (`cinematic.gd`) |

**Checagem anti-vazamento (o Roteiro deve rodar antes de commitar):** procurar em
todas as falas com tela < 64 por "Yaldabaoth", "pai", "Rei" (na boca da Voz, exceto
`king_intro`), "Demiurgo", "meu corpo", "chave". Nenhuma pode ligar a Voz ao Cego.
"Sophia" dita em voz alta antes da 65 → só na pedra (rótulo de UI pode).

**Teste de sentimento (barato):** depois de implementar, rodar o `Shot` no modo
`dialog` nas telas 6, 24, 60, 64, 65 e 68 e ler as capturas em sequência. Se a 64 não
parecer a colheita das 6/24/60, falta plantio — não falta texto na 64.
