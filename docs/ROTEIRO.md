# ROTEIRO — GNOSIS (mapa das 68 telas, cenas encenáveis e relatório de texto)

> Diretor de Roteiro & Texto, Onda 1 (17/10/2026). Texto do jogo em
> `scripts/autoload/narrative.gd` (falas e legendas), `scripts/autoload/gnosis.gd`
> (18 Estelas + cards de chefe), `scripts/fx/cinematic.gd` (prólogo, epílogo,
> créditos). Guia de voz e limites: `docs/ESTILO_TEXTO.md`. QA: `tools/GnoseQA.tscn`.

## 0. A espinha em uma página

| Ato | Telas | O que acontece | O que o jogador sabe | O que o jogador **não** sabe |
|---|---|---|---|---|
| 1 · O Limiar | 1 | Sophia acorda nas cinzas; a Voz a guia; o Rei sai da névoa, o "rito" vira duelo; o selo racha, sete tronos acordam | a Voz é amiga; o Rei é gentil | Voz = Rei = Yaldabaoth |
| 2 · Os sete Éons | 2–64 | 7 Éons × 9 telas; cada Arconte tenta, cai e vira um Anel (magia). Estelas ensinam o mito real; a Voz conta a versão dela | Anéis = poder do Arconte; a Voz desvia, tem pressa, nega o nome dela | Anéis = cacos da Sophia |
| 3 · O roubo | 64 | O Rei volta inteiro, arranca os sete Anéis um a um, fala com a voz da Voz; a máscara cai: "Eu sou o Cego de quem te falei" | **a Voz era Yaldabaoth** | por que ela esqueceu |
| 4 · O Centro | 65–67 | Sem Voz e sem Anéis; ecos dos Arcontes devolvem cacos de memória | a nuvem branca foi feita por ela | que ela é a Sophia inteira |
| 5 · A Mente | 68 | Batalha dupla (Rei + Colosso Oco); caem juntas; os Anéis voltam a ela; anagnórise; o filho é reclamado; três finais | **tudo**: Anéis = Sophia; ela entrou de propósito; o Cego é o filho dela | — |

**Pedagogia pela contradição** (dita em voz alta pelas legendas): a Voz diz
que a Sabedoria "viu o próprio rosto na água" (vaidade, tela 39); a Estela da
*Pistis Sophia* diz que ela foi enganada por **uma luz falsa** — a força com
rosto de leão (tela 39). Na tela 43 a Sophia confronta: "Foi uma luz falsa,
vista de cima." / Voz: "Pedras repetem o que querem." O mesmo padrão: Pleroma
"não olha para baixo" × Estela do Chamado; "vieste de mim" × Estela do barro;
"ninguém te mandou carta" × Hino da Pérola. No roubo, Yaldabaoth repete a frase
que a Estela da tela 12 ensinou ("e não há outro além de mim") — o jogador
reconhece o Cego pela citação.

**Foreshadow permitido (sem vazar):** a Voz nunca diz o nome da Sophia; some
quando Soter aparece (o Cego não o vê) e depois inventa desculpa (telas 18 e
36); usa "faísca perdida" na 4ª morte — a mesma expressão do Rei na tela 1; a
memória recorrente de "uma nuvem branca com um trono pequeno dentro" (o
esconderijo do Apócrifo de João, Estela 3) aparece no 1º Anel, no Espelho e no
Centro.

## 1. Mapa das 68 telas

Legenda das colunas: **Papel** (RunManager.screen_role) · **Beat** · **Aprende**
(Estela ou ideia) · **Falas** (diálogo de entrada D, legenda de chegada C,
legendas de zona Z0/Z1). Toda legenda tem lugar único — nenhuma repete.

### Ato 1 — O Limiar
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 1 | king | prólogo (6 cards) → Voz "Acorda." → o Rei sai da névoa → duelo-tutorial → a máscara racha, ele afunda | Estela 1 · A Mônada | D `intro`, `king_intro`, `king_fall` · C Voz "As cinzas ainda estão quentes…" / Sophia "(Uma pedra escrita…)" |

### Éon 0 — Torpor (telas 2–10) · nigredo · esquecimento
| Tela | Papel | Beat | Aprende | Falas (início) |
|---|---|---|---|---|
| 2 | chegada | a cidade que sonha | — | D `eon_intro(0)` · C "Eles dormem de pé…" · Z "voltam ao chão" / "como se agradecessem" |
| 3 | travessia I | a Voz vende o sono como paz | Estela 2 · Pleroma e Éons | C "Os que dormem não sofrem…" |
| 4 | travessia II | 1ª dúvida: o Silêncio parece lembrança | — | C Sophia + Voz "Não confies demais nas pedras" |
| 5 | travessia III | "quem era o meu par?" | sizígias | C Voz "Sobe-se sozinha. Comigo." |
| 6 | Desafio | Campeão de Athoth, santuário | — | C "Acorda-o a golpes." |
| 7 | travessia IV | **a tese da Voz** | o viés: "a Luz de cima não olha para baixo. Eu olho." | C |
| 8 | travessia V | a névoa de Athoth | Estela 3 · Sophia, a Sabedoria | C "É o hálito de Athoth" |
| 9 | antessala | o nome Sophia dói | — | C "Nunca te deites." · Z "(…Por que esse nome me dói?)" |
| 10 | Arconte | **Athoth** tenta (sono) · Anel 1 · 1ª memória: nuvem branca | — | D `temptation`, `ring_gained` · C "Um trono num quarto de sonho" |

### Éon 1 — Fome (11–19) · hyle, o Cego
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 11 | chegada | mercados que devoram | — | D `eon_intro(1)` · C "Ninguém come. Todos mastigam." |
| 12 | trav. I | a matéria tem fome do que brilha | Estela 4 · O Aborto Cego | C |
| 13 | trav. II | Kenoma = "cheio de falta" | — | C Sophia/Voz |
| 14 | trav. III | quem deixou o Cego sozinho? "Os de cima… paciência" | — | C |
| 15 | Desafio | o Glutão | Estela 5 · Kenoma e hyle (santuário) | C |
| 16 | trav. IV | a Voz recusa dizer o próprio nome | — | C "Um nome, aqui, vira coleira." |
| 17 | trav. V | **Soter #1** (entre as zonas) — "a tua gente não está ali" | Estela 6 · Os Sete Arcontes | C "alguém de branco…" · Z1 "Enquanto ele falava, a Voz não disse nada." |
| 18 | antessala | a Voz "te perdeu de vista" | — | C · Z "derrubo o quê?" |
| 19 | Arconte | **Harmas** (fome) · Anel 2 | — | D · C "ainda me olha com fome" |

### Éon 2 — Corrente (20–28) · Heimarmene, barro e faísca
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 20 | chegada | selos e cadeados | — | D `eon_intro(2)` |
| 21 | trav. I | a Voz nomeia a Heimarmene | Estela 7 · Heimarmene | C |
| 22 | trav. II | sete elos, sete céus — "tu já partiste dois" | — | C |
| 23 | trav. III | Galila classifica | — | C · Z "(Os dois Anéis tilintam…)" |
| 24 | Desafio | o Carcereiro (esquiva quebra a corrente) | mecânica dita em fala | C |
| 25 | trav. IV | "quem usa a coroa?" — "O Cego. Ninguém mais." (ironia) | Estela 8 · Homem de barro | C · Z "Nem será. Eu não deixaria." |
| 26 | trav. V | **"Vieste de mim."** | contradiz a Estela 8 | C |
| 27 | antessala | correntes que cantam de medo | — | C · Z "Parece choro." |
| 28 | Arconte | **Galila** (lei) · Anel 3 | — | D |

### Éon 3 — Silêncio (29–37) · gnose, Nag Hammadi, Apócrifo · magias caladas
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 29 | chegada | biblioteca apagada | — | D `eon_intro(3)` |
| 30 | trav. I | a Palavra calada | Estela 9 · Gnose: saber é lembrar | C |
| 31 | trav. II | **"uma voz por baixo da tua"** — a Voz: "Eco. Ignora." | — | C |
| 32 | trav. III | só o cajado fala | — | C |
| 33 | Desafio | o Bibliotecário | Estela 10 · Nag Hammadi, 1945 | C |
| 34 | trav. IV | "a verdade sobrevive enterrada" — "não é o mesmo que vencer" | — | C |
| 35 | trav. V | **Soter #2** — "toda lâmina ensina a mão a fechar" | Estela 11 · O Apócrifo de João | Z1 "Por que tu te calas quando Soter aparece?" |
| 36 | antessala | a Voz se justifica ("não falo com quem não luta") | — | C (2 falas da Voz) |
| 37 | Arconte | **Yabel** (não fala) · Anel 4 | — | D |

### Éon 4 — Espelho (38–46) · albedo · Pistis Sophia
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 38 | chegada | em cada poça, eu | — | D `eon_intro(4)` |
| 39 | trav. I | **a versão da Voz**: vaidade na água | Estela 12 · Pistis Sophia (a luz falsa) | C |
| 40 | trav. II | "O nome na pedra é o meu." — "Nome comum." | — | C |
| 41 | trav. III | Astaphaios vai oferecer "tu, antes de tudo" | — | C · Z "Puxam… uns para os outros." |
| 42 | Desafio | o Reflexo | — | C |
| 43 | trav. IV | **confronto**: "Foi uma luz falsa." — "Pedras repetem o que querem." | Estela 13 · Valentino e Basílides | C · Z "(…uma nuvem branca, e alguém pequeno chorando)" |
| 44 | trav. V | treze arrependimentos | — | C |
| 45 | antessala | alguém respira no ritmo dela | — | C |
| 46 | Arconte | **Astaphaios** ("somos nós") + Sombra da Sophia · Anel 5 | — | D |

### Éon 5 — Praga (47–55) · Tomé, Pérola
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 47 | chegada | velas num pântano | — | D `eon_intro(5)` |
| 48 | trav. I | "a única lei que o Cego não escreveu" | Estela 14 · Evangelho de Tomé | C |
| 49 | trav. II | o Reino dentro e fora | — | C |
| 50 | trav. III | Belias cansado | — | C · Z "E se o que está dentro for escuro?" |
| 51 | Desafio | Portador de Esporos | — | C |
| 52 | trav. IV | "Mais dois, e eu te mostro o fim" | Estela 15 · Hino da Pérola | C |
| 53 | trav. V | **Soter #3** — a pergunta final "não será sobre força"; "Ninguém te mandou carta. Tens a mim." | — | C · Z1 "Sobre o quê, então?" |
| 54 | antessala | "só a Coroa e eu" | — | C |
| 55 | Arconte | **Belias** · Anel 6 | — | D |

### Éon 6 — Coroa (56–64) · rubedo · o Chamado
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 56 | chegada | tronos vazios em cada esquina | — | D `eon_intro(6)` |
| 57 | trav. I | "Quase" | Estela 16 · O Chamado ("o verdadeiro desperta, e deixa ir") | C |
| 58 | trav. II | "Foi assim que me achaste?" — "Eu chamei; tu ouviste." | — | C |
| 59 | trav. III | gente de joelhos | — | C · Z "(Sei o bastante para desconfiar…)" |
| 60 | Desafio | o Pretoriano | — | C |
| 61 | trav. IV | **Velkar** — "uma criança cega chamando pela mãe"; a Voz desdenha | Estela 17 · Docetismo | C "Seis Anéis… partes de uma coisa só" |
| 62 | trav. V | "Tu nunca me disseste isso." — "Porque não há." | — | C |
| 63 | antessala | "o ritual. Prometi mostrar-te." | — | C · Z "Uma das duas está errada. Ou as duas." |
| 64 | Arconte + **ROUBO** | **Armupiel** · Anel 7 → "Não te mexas." → **cena B** | — | D `temptation`, `ring_gained`, `theft` |

### Ato 4 — O Centro (65–67) e Ato 5 — A Mente (68)
| Tela | Papel | Beat | Aprende | Falas |
|---|---|---|---|---|
| 65 | Centro I | **cena C** (descida) · silêncio · ecos de Athoth e Harmas | memória: "a nuvem branca… fui eu que a fiz" | D `center_intro` · C "(O chão é feito de engrenagens…)" |
| 66 | Centro II | ecos de Galila e Yabel | Estela 18 · A salvação como retorno | C · Z "Chaves abrem dos dois lados." |
| 67 | Centro III | ecos de Astaphaios e Belias | — | C · Z "Os ecos não gritam quando caem. Choram." |
| 68 | Mente | batalha dupla → **cena D** (anagnórise) → três finais → epílogo | o 7º caco volta na 1ª queda | D `final_pre`, `final_lines` · C "Como um quarto de criança visto do chão." |

## 2. Cenas encenáveis (pendentes para a Onda 2)

Convenções: base 640×360; tempos em segundos reais (`set_ignore_time_scale`);
"C:" = câmera; "S:" = som (ids do `audio_manager.gd` CATALOG quando existem;
novos marcados ★); "Fala" = qual entrada de `Narrative` aparece (os `cue` estão
no código, ver `docs/pedidos/roteiro.md`). Tudo por código (tween, modulate,
Polygon2D, VfxLibrary) — nenhum asset novo é obrigatório.

### Cena A — O Rei sai da névoa (tela 1) · ~9 s antes do duelo
Contexto: termina o `intro` (Sophia: "…Quem és tu?" / Voz: "Chama-me Voz").
O Rei ainda NÃO está no palco.

| t | Imagem | C | S | Fala |
|---|---|---|---|---|
| 0,0 | A Sophia sozinha à esquerda; névoa baixa | trava; zoom 1,0 → 1,08 em 2 s, centro desliza 60 px para a direita | música do Limiar desce a 40% | — |
| 0,0–1,6 | a névoa **adensa** do lado direito (3 bancos de `smoke` com alpha 0→0,7, escala 1→1,4) | — | ★ `fog_swell` (grave, sopro) | **Voz** "Olha. Alguém vem da névoa…" (`fog_thickens`) |
| 1,6–4,0 | **silhueta** do Rei (modulate preto 0,85, alpha 0→1) anda de x=+220 até x=+90 do centro, passo lento (2 passos, 1,2 s cada); o orbe-olho é o único ponto de luz (amarelo pálido, pulsando 0,8 Hz) | segue a silhueta, 30% | passos ★ `king_step` ×2; música `rei` entra em fade 2 s | — |
| 4,0–5,0 | a névoa abre em volta dele; a cor volta (modulate → branco em 0,8 s); capa assenta | leve push-in até 1,15 | `boss_appear` baixo (−8 dB) | **Rei** "Faísca perdida… que bom que acordaste." (`king_emerges`) |
| 5,0 | rosto amigável; mão estendida | estático | — | **Rei** "Mas o limiar tem uma lei…" · **Voz** "É um rito…" |
| 5,0+ (na última fala) | ergue o orbe; **a máscara acende** (flash dourado 0,15 s na região da máscara + `VfxLibrary` halo) | micro-shake 2 px | ★ `mask_light` (sino agudo) | **Rei** "Vem." (`mask_lights`) |
| fim | o diálogo fecha → `Gnosis.boss_card("rei")` → duelo | volta à câmera de jogo em 0,5 s | — | card "O REI · Guardião do Limiar" |

Silhueta = mesma do Colosso na tela 68 (regra de LORE: o contorno gentil sai da
**névoa**; o monstro sairá da **fumaça**). Na queda (`king_fall`): `mask_cracks`
= rachadura branca desenhada por cima da máscara (Line2D, 3 segmentos, 0,3 s);
`king_sinks` = ele afunda 60 px em 1,2 s enquanto a névoa o cobre.

### Cena B — O roubo dos Anéis (tela 64) · ~22 s, o épico do jogo
Contexto: Armupiel caiu; `ring_gained("arconte_coroa")` termina com a Voz:
"Sete. Todos os sete… Não te mexas. Fica bem aí." O HUD mostra 7 ◆ coloridos.

| # | t | Imagem | C | S | Fala (`cue`) |
|---|---|---|---|---|---|
| 1 | 0,0–2,5 | silêncio de 0,6 s; a névoa do Limiar (a **mesma** da cena A, mesma cor) entra pela direita; o Rei sai **inteiro**, máscara sem rachadura, mesmo passo | push-in lento 1,0→1,12 | música corta em 0,3 s; `roubo` entra baixo; ★ `king_step` | Rei "Faísca perdida… fizeste tudo tão bem." (`king_emerges`) |
| 2 | — | Sophia recua meio passo (pose de bloqueio) | — | — | Sophia "Tu caíste. Eu te vi cair." · Rei "Caí, para que tu subisses…" |
| 3 | 0,0–5,6 | **os 7 Anéis voam**: para i em 0..6, a cada 0,8 s: `hud.detach_ring(i)` → gema-fantasma nasce em `hud.ring_dot_global_pos(i)` (convertido para o mundo pela câmera), arco de Bézier até a mão do Rei (0,7 s, ease in), rastro na cor do Anel (`SkillData.color`), pisca a mão dela; o ◆ do HUD fica cinza | trava no par Sophia–Rei; a cada gema, micro-zoom +0,01 | `ring_steal` em cada gema, tom subindo um semitom por gema; no 7º, `boss_phase2` abafado | Rei "(estende a mão…) Vem. Vem… vem." (`rings_fly`) — a fala fica na tela durante as 7 gemas; avançar fica bloqueado até a última chegar |
| 4 | — | Sophia olha para cima, para o nada | corte para plano mais aberto | — | Sophia "Voz! Faz alguma coisa!" |
| 5 | 0,0–1,5 | o Rei inclina a cabeça; a voz dele passa a sair com o **filtro da Voz** (se o áudio tiver voz) — sem voz gravada: a caixa troca a cor do nome "O Rei" para a cor da Voz durante a fala | estático, 1,5 s de silêncio antes do texto | ★ `voice_merge` (as duas vozes em uníssono) | Rei "Estou fazendo, Portadora. Sobe… ah, não. Agora já não precisas subir." (`voice_merge`) |
| 6 | 0,0–1,2 | **a máscara cai**: o sprite do rosto desce 30 px girando 20° e some (alpha 0 em 0,6 s); no lugar, preto + **um olho cego** (círculo branco-leitoso, sem pupila) ; o modulate do Rei esfria (branco → cinza-azulado) | shake 6 px 0,3 s + flash branco 0,08 s | `boss_appear` grave, −4 semitons; a música para | Yaldabaoth "(a máscara cai…) Eu sou o Cego de quem te falei. E não há outro além de mim." (`mask_falls`) |
| 7 | — | as 7 gemas orbitam a cabeça dele (raio 50 px, 1 volta/2 s) | — | — | Yaldabaoth "Sete Arcontes, sete Anéis: o meu corpo…" |
| 8 | — | as gemas pulsam fracas, fora de ritmo | — | ★ sussurro (voz feminina reversa) | "Uma voz nos Anéis": "…espera… eu… lembro…" |
| 9 | 0,0–2,5 | ele **vira o motor**: o manto colapsa vazio (scale.y 1→0,2), as gemas viram 3 anéis concêntricos girando (Line2D/arc) ao redor de um núcleo negro; tudo afunda 120 px no chão, que racha (VfxLibrary `portal` invertido, escuro) | segue a descida; fade para preto em 0,8 s no fim | `dive` + grave longo | Yaldabaoth "(vira um motor de anéis e afunda no chão) Desce, se tiveres coragem…" (`sink`) |
| fim | — | `Progression.steal_rings()` → `advance_and_reload()` | — | — | — |

Regra: **nenhuma gema voa antes da fala 3**, e a palavra "Yaldabaoth" só
aparece como nome do falante a partir da fala 6.

### Cena C — A descida ao Centro (início da tela 65) · ~6 s antes do `center_intro`
| t | Imagem | C | S |
|---|---|---|---|
| 0,0–1,0 | preto (vindo da cena B); o HUD dos Anéis mostra 7 ◆ cinzentos | — | grave contínuo; nenhum som da Voz |
| 1,0–3,5 | o Centro aparece **de cima**: a câmera começa 200 px acima do chão e desce até a altura de jogo; a paleta vai do frio da Coroa (dourado) para o cinza-violeta do Centro (`CanvasModulate` em tween 2,5 s); engrenagens do chão giram devagar | descida com ease out | música `centro` em fade 2 s |
| 3,5–5,0 | a Sophia cai de joelhos no centro e se ergue (pose de queda → idle) | assenta | `land` |
| 5,0–6,0 | silêncio total 1 s (nem música) — a ausência da Voz se ouve | estático | — |
| 6,0 | `center_intro`: "…Silêncio. Desde as cinzas, é a primeira vez que não há voz nenhuma na minha cabeça." | — | música volta |

### Cena D — A anagnórise (tela 68, após as duas formas caírem) · ~20 s
Contexto: a batalha dupla terminou (`final_battle`). Os 7 Anéis giram no céu.
| # | t | Imagem | C | S | Fala (`cue`) |
|---|---|---|---|---|---|
| 1 | 0,0–1,2 | as duas formas caem **juntas** (Rei de joelhos à esquerda, Colosso tomba à direita); os 7 Anéis **param** no ar | câmera recua para enquadrar os três | tudo para; 0,8 s de silêncio | — |
| 2 | 1,2–4,0 | **os Anéis voltam**: um a um (0,35 s cada), cada um desce em espiral até o peito da Sophia (inverso da cena B: mesmas cores, agora entrando); o ◆ correspondente do HUD volta a colorir (`hud` reverso de `detach_ring`) | push-in na Sophia, 1,0→1,25 | `ring_gain` em cada um, tom DESCENDO até a tônica | Sophia "(as duas formas caem juntas…) Ah…" (`rings_return`) |
| 3 | 4,0–4,4 | **clarão**: tela branca 0,12 s, decai em 0,3 s; ao voltar, a Sophia tem aura (modulate +20%) e o fundo da Mente fica menos escuro | shake 4 px | `nova` + acorde | Sophia "Agora eu vejo. Os Anéis são eu…" (`flash`) · "Eu entrei aqui de propósito…" · "Fizeram-me caçar a mim mesma. Para ti." |
| 4 | 0,0–3,0 | **o Colosso encolhe**: scale 1→0,25 em 3 s (ease in-out), alpha da carcaça 1→0,4; revela-se **oco** (por dentro, só o olho cego, pequeno); o Rei enfraquecido se desfaz em névoa e a névoa entra no Colosso | acompanha o encolhimento, até o "minúsculo" caber ao lado do pé da Sophia | ★ respiração de criança | Yaldabaoth "…mãe? eu não queria ser cego…" (`colossus_shrinks`) — nome em minúsculas é proposital |
| 5 | — | Sophia ajoelha (pose de bloqueio baixa) diante do pequeno | baixa à altura dela | música `epilogo` começa | Sophia "Eu estou olhando. Fui eu que te escondi numa nuvem…" |
| 6 | 0,0–2,0 | ela abre a mão; o pequeno vira luz e entra na mão dela (partículas douradas sugadas) | push-in final | `revive` suave | Sophia "(ela abre a mão) Volta para dentro de quem te fez…" (`reclaim`) |
| 7 | — | a Sophia de pé, inteira, sozinha na Mente clareada | abre o quadro | — | Sophia "Agora, a última escolha…" → botões Ascensão / Ruptura / Semente |

## 3. Relatório de mudanças de texto (Onda 1)

### Erros de continuidade corrigidos
1. **Velkar citado antes de aparecer**: a Sophia falava dele na tela 53 (Praga);
   ele só surge na 61. Movido para a 62.
2. **Estelas citadas antes de existirem**: jarro de Nag Hammadi (citado na 31,
   pedra na 33), Pérola (52 = mesma tela), docetismo (61 = mesma tela), Kenoma
   (13 × pedra na 15), Sophia (Z da 4 × pedra na 8). Todas re-posicionadas
   (regra: tela da pedra + 1).
3. **Legendas repetiam no run**: o pool de zona era varrido com módulo (`off*3+zone
   % 8`) — cada fala tocava ~2× por Éon. Agora cada fala tem endereço fixo
   (Éon × tela × zona); o GnoseQA confirma 0 repetidas em 184 legendas.
4. **A Voz anunciava Soter** ("Soter anda por aqui") — mas o Cego não pode vê-lo.
   Agora a Voz **se cala** nos encontros e depois se justifica (foreshadow).
5. **"Lâmina"**: a Sophia luta com cajado. Corrigido onde era a arma dela
   (Soter, Velkar, Silêncio); mantido só como metáfora ("a recusa também é uma lâmina").
6. **"Desceu, tela por tela"** (epílogo Semente) — metalinguagem. → "Éon por Éon".
7. Comentários com números antigos (telas 45/50, 54 telas) atualizados para o mapa de 68.
8. `ring_gained`: "O 7º" (algarismo) e "Faltam %d. Sobe." genérico → ordinal por
   extenso + uma linha própria por Arconte.
9. `death_revive` dizia "0 faísca escorrem" quando não havia perda; agora a
   rubrica só aparece se `lost > 0`, com singular/plural.
10. Prólogo terminava em "Acorda." e a Voz repetia "Acorda." — agora o card
    final só diz "Uma delas acaba de sentir dor." e quem diz "Acorda." é a Voz.

### Exatidão histórica (Estelas) — o que estava errado
| Estela | Antes | Agora |
|---|---|---|
| Pleroma | "Cada **par** era um Éon" | cada um é um Éon; os pares são **sizígias**; Ogdóade valentiniana correta (Abismo/Silêncio → Mente/Verdade → Palavra/Vida → Homem/Igreja); 30 Éons |
| Os Arcontes | "assim os nomeia o Apócrifo" (os 7) | 6 nomes vêm da lista das **autoridades**; Astaphaios, da lista dos **sete reis**; paixões por Éon assumidas como invenção do jogo; subida pelas esferas creditada ao *Poimandres* |
| O Cego | "fez um mundo à sua imagem" | fez um mundo **copiando às cegas** o Pleroma; "deus dos cegos" (Hipóstase 87); "aparência de serpente e de leão" |
| Kenoma | "Os gnósticos não odiavam o corpo" (generalização falsa) | "Há textos que desprezam a carne e outros que a tratam com piedade"; citação do Evangelho da Verdade 24 sobre a deficiência |
| Heimarmene | citação entre aspas que não é literal | paráfrase marcada + citação real de Teódoto (Exc. 78,1) |
| Barro | "corpo de barro … rastejava" atribuído ao Apócrifo | "ficava no chão, imóvel" (Apócrifo/Hipóstase); "como um verme" creditado a Irineu I,24,1 (Saturnino); citação "Façamos um homem…" |
| Gnose | "Quem conhece a si mesmo conhece o Todo" sem fonte | citação do **Livro de Tomé, o Atleta** (NHC II,7, 138) + a fórmula de Teódoto 78,2 |
| Nag Hammadi | "treze códices" | **doze** códices + folhas de um décimo terceiro; o forno como "conta-se" |
| Apócrifo | "Irineu já o cita" | Irineu **resume um mito muito próximo** (I,29); o fim é o hino da Providência ("Levanta-te e lembra-te") |
| Pistis Sophia | "viu uma luz refletida nas águas" | viu a **força com rosto de leão do Arrogante** e a tomou pela Luz; salmos interpretados por discípulos (Maria Madalena) |
| Mestres | 365 céus atribuídos ao mesmo relato do "Deus que não é" | Hipólito (Deus que não é) × Irineu (365 céus); "quase bispo" atribuído a **Tertuliano** |
| Tomé | apresentado como gnóstico sem ressalva | "Se é gnóstico, os estudiosos discutem" |
| Docetismo | "Alguns gnósticos" (genérico) | Basílides segundo Irineu I,24,4; Apocalipse de Pedro (NHC VII,3); "Nem todo gnóstico era docetista" |
| Retorno | "Quem tiver ouvidos, ouça. O fim está onde o princípio está" (dois ditos fundidos) | dito 18 literal; destino do Cego segundo Irineu I,7,1 × **Sobre a Origem do Mundo** (NHC II,5) |
| Mônada | fontes vagas | Apócrifo (Mônada, Espírito Invisível) + Irineu I,1,1 (Abismo e Silêncio) |

### Cinco falas, antes → depois
1. **Voz, tela 1** — antes: "Acorda. As cinzas sob teus pés eram a tua gente." (logo após o prólogo terminar em "Acorda.")
   → depois: "Acorda." / "As cinzas sob os teus pés eram a tua gente." / "A dor que sentes é a única coisa verdadeira que este mundo te deu. Foi ela que quebrou o feitiço." / Sophia: "…Quem és tu?" / Voz: "Alguém que te procurou por muito tempo. Chama-me Voz."
2. **Soter, tela 17** — antes: "Eu conheci tua gente. Carrego os nomes deles, se um dia quiseres ouvi-los." (confirmava a mentira da Voz)
   → depois: "Disseram-te que a tua gente está nas cinzas? Eu conheço a tua gente. Não está ali."
3. **Galila** — antes: "Sem lei, tudo cai. Ajoelha, e faço de ti o meu selo mais belo."
   → depois: "Consta que estás fora do teu lugar. Ajoelha-te, e serás registrada como o meu selo mais belo." (voz de cartório; ênclise correta)
4. **O roubo** — antes: "A voz que te guiou desde o primeiro dia…" / "…era EU. Nunca houve amigo."
   → depois: Sophia "Voz! Faz alguma coisa!" / Rei "Estou fazendo, Portadora. Sobe… ah, não. Agora já não precisas subir." / Yaldabaoth "Eu sou o Cego de quem te falei. E não há outro além de mim." (a revelação pelo tique verbal e pela frase que a Estela 4 ensinou)
5. **Espelho, tela 43** — antes: nada; a contradição Voz × Estela ficava implícita.
   → depois: Sophia "A pedra diz que não foi o rosto dela na água. Foi uma luz falsa, vista de cima." / Voz "Pedras repetem o que querem. Água é água. Sobe."

### Nomes e UI tocados (só campos de texto)
- Magia do 7º Anel: "Coroa da Mônada" → **"Coroa Partida"**; item de gear
  "Coroa da Mônada" → **"Diadema da Fonte"**; "Braceletes de Éon" → "do Éon".
- Descrições de magia sem "você/te" (registro de sistema impessoal).
- Descrição da Sophia não usa mais "faísca perdida" (é o tique do Rei/Voz).
- Prompt da Estela: "J / X · ler a Estela".
- Pedidos para arquivos de outros diretores: `docs/pedidos/roteiro.md`.

### Validação
`tools/GnoseQA.tscn` ganhou a etapa **TEXTO**: mede com as fontes e larguras
reais cada fala da caixa (13 e 16 px), cada legenda (2 linhas), cada painel de
Estela (≤ 330 px), cada card de prólogo/epílogo (≤ 6 linhas); confere legendas
repetidas, termos proibidos/registro e a regra de ouro (ninguém diz
Yaldabaoth/Demiurgo antes do roubo).
