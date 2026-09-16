# GDD — GNOSIS (mundo: Kenoma)

> Documento vivo. Tudo aqui é ponto de partida e pode mudar. É o mapa pra
> gente orquestrar o desenvolvimento ponto a ponto. O plano de execução (fases
> F0–F6) está no topo de `ROADMAP.md`; o estado real em `BIBLIA.md §6`.

## 0. Nota de respeito (importante)

O jogo usa a **cosmologia gnóstica/neoplatônica** (Demiurgo, Mônada, Arcontes,
Pleroma, Éons, Sophia) como **mito abstrato de fantasia** — do mesmo jeito que
God of War usa a mitologia grega/nórdica. Regras que a gente adota:

- Tratar como **cosmologia filosófica antiga**, não como religião viva.
- Nomes de Arcontes são os **gnóstico-específicos** (Athoth, Harmas, Galila,
  Yabel, Astaphaios, Belias, Armupiel); Demiurgo = Yaldabaoth. **Nunca** usar
  nomes sagrados de fés vivas (Sabaoth, Adonai…) como vilão.
- **Não** é o Cristianismo Ortodoxo (Igreja Ortodoxa) — isso é fé viva; ficamos
  longe de retratá-la ou de seus santos/ritos.
- Tom: épico e melancólico, sobre libertação e ascensão — não zombaria.

## 1. Pitch

Beat-em-up 2.5D de rolagem lateral, rápido e direto como **Grand Chase**, com
combate de leitura estilo **God of War 2018** (parry, esquiva, golpes
imparáveis) e progressão de arma e magias.

**Gancho temático:** o mundo material — o **Kenoma** — é uma prisão moldada
pelo **Demiurgo**. Faíscas de luz da **Mônada** ficaram presas na matéria. Você
é a **Sophia**, o caco desperto do aeon caído, sem memória, atravessando os 7
Éons dos **Arcontes** para reunir os **7 Anéis** e chegar ao Demiurgo. → As
**Faíscas** são a moeda/XP: justificativa diegética do loop de coleta. (A
reviravolta dos Anéis e da Voz está em `docs/LORE.md ★`; nunca revelar antes do fim.)

## 2. Pilares de design

1. **Jogabilidade rápida** — resposta imediata, combos fluidos, sem input lag.
2. **Loop de progressão viciante** — sempre "só mais uma faísca / upgrade".
3. **Simples de entender, difícil de dominar** — poucos botões, muita técnica.
4. **Cada Arconte é uma pergunta** — o chefe é a mecânica do tema do Éon.

> **História densa:** a bíblia narrativa completa está em [`docs/LORE.md`](LORE.md).
> Meta realista da versão final: campanha de **2–3 h** com o arco completo.

## 3. Cosmologia / mundo (resumo — detalhes em LORE.md)

- **A Mônada** — a fonte primordial de luz, inalcançável e distante.
- **Pleroma** — a plenitude divina; o destino, o "céu" a reconquistar.
- **Kenoma** — o mundo material deficiente; a prisão onde o jogo se passa.
- **Demiurgo (Yaldabaoth)** — o falso criador que forjou o Kenoma; **chefe final**.
- **Arcontes** — carcereiros do Demiurgo; chefes de cada Éon.
- **Éons** — os 7 atos (Torpor, Fome, Corrente, Silêncio, Espelho, Praga, Coroa).
- **Faíscas** — luz da Mônada presa na matéria; libertada ao vencer inimigos.
- **Anéis** — 1 por Arconte = 1 magia nova (IMPLEMENTADO: `SkillData.ring`,
  seleção 1–7/Q/E/L2, HUD próprio; roubados na tela 50, cacos voltam no Centro).

Estrutura (o **Arco dos Anéis**, 54 telas): O Rei (1, duelo-tutorial) → 7 Éons
de 7 telas (2–50), cada um fechando num Arconte-chefe → o roubo (50) → o Centro
(51–53) → a batalha dupla (54). A progressão de arma/magia persiste na subida.

## 4. Personagem jogável

**Sophia**, única (sem seleção de personagem; o pré-jogo escolhe só a
dificuldade). Definida em `scripts/autoload/game_content.gd`. Cajado; HP 90,
Éter 100; magias começam trancadas e são adquiridas ao vencer chefes.

**Arte:** procedural (`character_art.gd`, feature "hero" = núcleo de luz no
peito); evolui de aparência com o nível da arma (ombreiras → elmo → braceletes →
coroa + aura) e com itens dos baús.

## 5. Combate (núcleo estilo God of War 2018/Ragnarok)

Sistema de ação com leitura de inimigo, não só mash de botão.

- **Dois ataques:** leve e forte. **Combos por sequência** (`ComboData.sequence`):
  14 golpes desbloqueados por nível de arma (5 tiers), lançador (`launcher`) +
  juggle, 2 golpes aéreos (Giro Celeste / Queda Estelar), multi-hit, golpes de
  área, finisher em câmera lenta com desmembramento, esquiva perfeita.
- **Esquiva:** rolar com **i-frames**; cancela ataque. Só ela salva de golpes
  imparáveis. Também **arrebenta a corrente** de Galila.
- **Defesa / Parry:** segurar bloqueio reduz dano (chip); apertar no tempo do
  golpe = **parry** — anula o dano, **atordoa** o inimigo, hitstop grande.
- **Telegrafos:** **amarelo** = aparável; **vermelho** = imparável (elites e
  explosões). Elites e chefes têm armadura durante o telegrafo.
- **Magias:** Esfera Solar inata (O/Y) + **7 Anéis** (U/X; um por Arconte
  vencido): Névoa do Sono, Boca Voraz, Corrente da Lei, Grito Mudo, Reflexo,
  Flor Podre, Coroa da Mônada. Consomem Éter, cooldown longo.
- **Status impostos por chefes:** preso (Corrente), lento (névoa do Torpor),
  silenciado (aura do Silêncio).
- **Game feel:** hitstop, screen shake, hit flash, lunge, squash/stretch,
  coyote time + jump buffer, buffer de combo (`scripts/autoload/juice.gd`).

### 5.1 Inimigos de wave (15 tipos, por tier de tela)

Estilos: **melee**, **ranged** (kita e atira), **charge** (investida), **slam**
(onda de choque). Comportamentos especiais:
- **Larva Ardente** (tier 1): corre e explode — ensina a esquivar.
- **Escudeiro do Selo** (tier 2): leve bate no escudo; só pesado ou magia ferem.
- **Fantasma do Vazio** (tier 3): teleporta pro outro lado da Sophia.
- **Invocador de Larvas** (tier 3): mantém distância, atira, chama larvas.

**Bots temáticos por Éon** (entram nas waves do seu ato, peso dobrado):
Sonâmbulo (tiro que deixa lenta), Glutão (mordida cura ele), Carcereiro
(corrente que prende), Bibliotecário Mudo (aura cala magias), Reflexo (recua
no instante do teu golpe), Portador de Esporos (poça de veneno ao morrer),
Pretoriano da Coroa (broquel: golpe leve pela frente = metade do dano).

IA de grupo: inimigos se afastam uns dos outros (cercam, não empilham). O
último inimigo da última wave de cada tela é **Elite** (maior, imparável).

### 5.2 Os 7 Arcontes (chefes, 2 fases cada)

Fúria a 50% de vida (+velocidade, cooldown menor) e a assinatura sobe de nível.

| Éon | Arconte | Assinatura visual | Mecânica |
|-----|---------|-------------------|----------|
| Torpor | Athoth (wraith) | pálpebra pesada | salva de 3 + **névoa do sono** no chão (lentidão) |
| Fome | Harmas (colosso) | boca sem fim no torso | slam + **sucção** durante o wind-up |
| Corrente | Galila (bruto) | correntes penduradas | investida + **corrente que prende** (esquiva quebra) |
| Silêncio | Yabel (wraith alado) | boca costurada | **aura cala magias**; fase 2 pisca pra trás de você |
| Espelho | Astaphaios (humanoide) | cacos orbitando, cajado | lunge; fase 2 **invoca a Sombra da Sophia** |
| Praga | Belias (besta) | gavinhas podres | investida deixa **poças de veneno** |
| Coroa | Armupiel (colosso) | coroa alta + halo | slam; fase 2 **chama servos e fica blindado** + onda rasteira |

**Chefes especiais do arco:** O Rei (tela 1, duelo-tutorial; PNG ilustrado +
orbe-olho, com shader de posterização/tinta) · Rei enfraquecido + **Colosso
Oco** na batalha dupla da tela 54 (`final_battle.gd`: quem cai se refaz em 14 s
se o outro não cair junto; os 7 Anéis giram no céu spawnando larvas) · ecos
translúcidos dos Arcontes no Centro (51–53).

## 6. Progressão (o coração — estilo God of War)

Gerenciada por `scripts/autoload/progression_manager.gd`.

- **Faíscas:** dropam de inimigos (escalam com tela e dificuldade). Moeda única.
- **Nível de arma (1→5):** custa `nível × 50`. Dá +3 de dano por nível, muda a
  aparência e **desbloqueia combos novos** (14 golpes em 5 tiers).
- **Níveis de magia:** cada magia sobe até `max_level`; custa `nível × 40`.
- **HP/Éter máximo:** compráveis (equivalente aos Gorgon Eyes / Phoenix Feathers).
- **Itens** (peças de gear) em baús de telas específicas; mudam o visual do herói.
- **Santuário de Ascensão** (a loja): abre após cada chefe e na pausa.
- **Bênçãos de Soter** (3 encontros) e faíscas de Velkar (1 encontro).

## 7. Dificuldade

`GameManager.Difficulty`: Normal, Difícil, Muito Difícil, Campeão. Multiplica
HP/dano/recompensa (`difficulty_multiplier`). Balanceamento base é
determinístico por tela (`Bestiary.screen_multiplier`: +3%/tela).

## 8. Estrutura de tela

Uma arena (`Level01.tscn`) reusada por todas as 54 telas, dirigida pelo
`RunManager`: waves (2 a 5, 3 inimigos cada), conteúdo determinístico por tela
(baú `%3==1`, Adormecido `%4==2`, puzzle dos Selos `%7==3`, Soter em 10/24/38,
Velkar em 45), plataformas one-way, props e paleta por Éon (nigredo → rubedo).
Tela limpa → portal à direita (o jogador anda até ele). Tela de chefe = só o
chefe, sem extras.

## 9. Onde está o plano

O roadmap por fases (F0 rede de segurança → F1 visual → F2 combate → F3 arco
canônico → F4 balance → F5 áudio → F6 build) está no topo de `ROADMAP.md`, com
o histórico dos passos antigos embaixo. Este GDD descreve o *quê*; o ROADMAP, a
*ordem*.
