# CHEFES6 — lutas de chefe de verdade (Onda 6, 17–18/10/2026)

Branch `dir6/chefes6`. Feedback do João: "chefes morrem com 5–6 porradas", "boss fights iguais, sem graça",
"o Rei tem UM ataque e a bola sai do olho lá em cima, fora do alcance", "a dificuldade vinha de tomar dano
ao ENCOSTAR", "a morte do chefe é murcha".

## Arquitetura
- `scripts/entities/bosses/boss_brain.gd` (`BossBrain`): filho do Enemy do chefe. Escolhe o golpe por
  FASE (sorteio ponderado semeado pela tela; não repete 3×), distância e altura da Sophia; executa
  (`melee`/`slam`/`charge`/`shot`/`leap`/`cast`); cadeias de golpes; 3 fases (66 % / 33 %) com rugido
  intocável de 1,3 s, flash, nova, tremor, música +3,5 % de pitch por fase e legenda (fase 3 se a
  Narrativa criar `archon_phase3`).
- Regras comuns (justiça, NEURO_SATISFACAO): todo golpe telegrafa FORMA+SOM (círculo amarelo = aparável,
  losango vermelho = imparável — o Enemy no WINDUP; os perigos de chão desenham o próprio aviso que se
  FECHA até o golpe). Quadros desenhados: preparação em 2 etapas (antecipação leve → máxima aos 30 %,
  SEGURA o resto), golpe em 2 etapas (impacto → follow-through), hurt no atordoamento, death no colapso.
  - **Postura**: o chefe não recua a cada cutucada; 12 golpes seguidos quebram a guarda → atordoado 1,5 s.
  - **Janelas** (`window_mult`): armado (preparando/golpeando) ×0,5 · andando ×0,85 · recuperando ×1,1 ·
    atordoado ×1,3 · golpe com `expose` (ajoelhado) ×1,35. O jogo paga quem espera a hora.
  - **Sai de cima**: 3–5 golpes em 2,5 s → golpe de repulsão/fuga do chefe (vermelho, curto).
  - **Sem dano de contato** no corpo: o ContactHitbox só liga durante investidas.
  - **Aparo**: chefe aparado fica 1,1 s atordoado e perde postura.
- `boss_hazard.gd` (`BossHazard`): perigo telegrafado (círculo, faixa, coluna, arena-com-abrigos, serra),
  pode seguir a Sophia e travar 0,35–0,5 s antes, andar, crescer, quicar nas paredes; efeitos sono,
  corrente, silêncio, sem-voo, puxão.
- `boss_tuning.gd` (`BossTuning`): **vida = golpes-alvo × golpe médio da Sophia na tela** (lê a tabela de
  golpes do GameContent e o nível de arma esperado) — se o combate6 mudar o dano, os chefes acompanham.
- **Morte = momento** (pedido do João): `Enemy.boss_dying(step)` 0 impacto (hitstop + câmera lenta) →
  1 cambaleia (quadro hurt) → 2 colapso (quadros death) → 3 pausa → 4 desintegração (`defeated` + gibs).
- `enemy.gd`: só ganchos mínimos (lista em `docs/pedidos/onda6_chefes6.md`) + `_boss_setup`,
  `_boss_phase_check`, `_enter_phase(n)`.
- `final_battle.gd`: as duas formas são PARCEIRAS (uma ataca de cada vez — nunca dois telegrafos
  juntos); 1ª queda → a outra entra na fase 2; 1ª forma que se refaz → as duas na fase 3.

## Os chefes (assinatura · fases · janelas)
| Chefe | Assinatura | Fase 1 | Fase 2 (+) | Fase 3 (+) | Janela / ponto fraco |
|---|---|---|---|---|---|
| Rei (1) | Olho-orbe é PONTO FRACO (desce à altura do cajado) | Leque, Gesto, Raio rasteiro (pule), Mão que esmaga c/ ondas | Anéis-serra (quicam), Larvas, Leque→Raio | Teleporte+golpe, Mão dupla | ajoelha após Mão/Raio/combos: olho ×1,3 + corpo ×1,35 |
| Athoth (10) | Sonolência (meia-lua enche; cochila; rolar acorda); vira NÉVOA ao conjurar | Orbes lentos, Bocejo (nuvem segue), Toque, Deslize | plataformas; Maré de Sono (meio chão); Canção (muro baixo de névoa: pule) | Sono Profundo (chão todo: suba); Chuva de Sono; Deslize p/ as costas | boceja após Canção/Chuva |
| Harmas (19) | Sucção (puxa; a boca engole golpe de frente) + Mordida; come se morder (cura 5 %) | Punhos, Sucção, Investida, Salto faminto | bocas no chão sob ela; punhos duplos c/ ondas | goela nas bordas (chão encolhe); Sopro empurra; Banquete | mastiga 1,6 s após a Mordida |
| Galila (28) | Corrente que prende, Puxão que arrasta + corte | Corrente, Estocada, Corte, Queda (sobe na corrente) | 2 pêndulos-gaiola; Estocada dupla; Puxão | 3 pêndulos rápidos; Prisão (colunas); Giro | espada cravada 1,2 s após Estocada |
| Yabel (37) | Aura muda; zonas mudas (sem magia e SEM PULO) que são o ABRIGO do Grito | Sopro, Asas, Pergaminhos, Mergulho | zonas mudas + Grito Costurado (arena toda menos as zonas) | zonas trocam mais; Lâminas; Pisca+Asas | de joelhos 1,8 s após o Grito |
| Astaphaios (46) | Guarda do Espelho DEVOLVE o golpe; reflexos SEM SOMBRA | Estocada, Corte, Cacos, Guarda | Reflexos (quebrar espirra cacos), Troca de lugar | Sala de espelhos (cacos voltam da parede), Sombra da Sophia | espelho trinca 1,3 s após a Guarda |
| Belias (55) | Poças que crescem; APARAR seca as poças | Bote (rastro), Mordida, Esporos, Enterrar | Nuvem que persegue; 2 fendas de veneno; mordida dupla | poças crescem mais; Enterrar+mordida | derrapa após o Bote; meio enterrado 1,4 s |
| Armupiel (64) | Corte blindada (Pretorianos: blindado enquanto vivem); onda rasteira | Espadão c/ onda, Varredura baixa (pule), Decreto, Investida | Corte Real; Espadão duplo | Coroação (feixe varre a arena); Triplo | espadão cravado 1,8 s após o Triplo |
| Rei-Mentira + Colosso (68) | um ataca por vez; refazem-se em 14 s | Rei: todo o repertório do Rei · Colosso: Punhos c/ ondas, Pisotear, Investida | Colosso: Salto c/ ondas, punhos em dobro | Colosso: Desabamento (colunas com vão seguro) | olho do Rei; Colosso preso após Pisotear/Salto |

## Sonda (tools/chefes6/BossProbe.tscn)
Bot "jogador médio": bate em sequências de 3–4 e se afasta ~0,8 s; decide uma vez por telegrafo (vermelho:
rola 65 %; amarelo: apara ~36 %, rola ~29 %, senão come); evita perigos de chão 75 %; respeita guarda/névoa
85 %. Quase-morte = vida < 25 % (conta e cura). Arma no nível ESPERADO da tela, vida base 120 (sem compras).
Uso: `godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/chefes6/BossProbe.tscn -- telas=all vel=3`.

### Antes (base 37ea6f5, mesmo bot)
| tela | chefe | arma | tempo | golpes | dano tomado | quase-mortes |
|---|---|---|---|---|---|---|
| 1 | Rei | 1 | 23 s | 17 | 24 | 0 |
| 10 | Athoth | 1 | 15 s | 16 | 16 | 0 |
| 19 | Harmas | 1 | 23 s | 23 | 122 | 1 |
| 28 | Galila | 3 | 45 s | 20 | 198 | 2 |
| 37 | Yabel | 3 | 52 s | 25 | 251 | 2 |
| 46 | Astaphaios | 4 | 29 s | 27 | 256 | 2 |
| 55 | Belias | 4 | 73 s | 35 | 792 | 8 |
| 64 | Armupiel | 5 | 25 s | 35 | 280 | 2 |
| 68 | Rei+Colosso | 5 | 75 s | 82 | 752 | 7 |
(Com a arma no máximo já na tela 19, como o João jogou, cada golpe vale +18 → os "5–6 golpes".)

### Depois
Rodada r4 (`_caps/chefes6/r4.txt`; depois dela só baixei o dano do Armupiel e da batalha final ~15 %):
| tela | chefe | arma | tempo | golpes | dano tomado | quase-mortes | fases (início) |
|---|---|---|---|---|---|---|---|
| 1 | Rei | 1 | 61 s | 33 | 79 | 0 | 2@17 s · 3@48 s |
| 10 | Athoth | 2 | 160 s | 43 | 216 | 2 | 2@53 · 3@102 |
| 19 | Harmas | 2 | 99 s | 46 | 200 | 2 | 2@37 · 3@63 |
| 28 | Galila | 3 | 120 s | 51 | 318 | 3 | 2@51 · 3@77 |
| 37 | Yabel | 3 | 101 s | 40 | 199 | 2 | 2@57 · 3@79 |
| 46 | Astaphaios | 4 | 118 s | 58 | 368 | 3 | 2@43 · 3@71 |
| 55 | Belias | 4 | 127 s | 54 | 372 | 3 | 2@48 · 3@76 |
| 64 | Armupiel | 5 | 115 s | 71 | 425 | 4 | 2@35 · 3@81 |
| 68 | Rei-Mentira + Colosso | 5 | 123 s | 108 (as duas) | 593 | 6 | 2@50 · 3@64 |
Variação entre rodadas iguais: ±20 % no tempo (temporizadores reais no bot). "Golpes" inclui os de meia
força dados no chefe armado; quem pune só nas janelas precisa de menos (perto do alvo do BossTuning).
GIFs (capturas 320×180 fora da tela, 10 qps, ~10 s de cada fase): `C:\gnosis-wt\_caps\chefes6\gif\s<tela>_<chefe>.gif`
e folhas `..._sheet.png`.

## Honestidade
- O bot NÃO é um humano: reage no quadro certo e nunca erra a distância. Meu palpite (não medido): um
  jogador médio leva ~1,3–1,6× o tempo do bot. Feel e timing precisam do playtest do João.
- O nível de arma esperado é uma TABELA minha (progressao6 pode publicar `Progression.expected_weapon_level`).
- Vida máxima da Sophia fixa em 120 na sonda; com compras de vida as lutas ficam mais fáceis.
- Hurtbox dos chefes não foi refeita por quadro (a sonda de hitbox ficou com combate6/inimigos6).
- Projéteis ainda usam o `Projectile` padrão; quando sair a API do VFX7 (dir7/vfx7), trocar o visual em
  `BossBrain._fire` / `ground_wave` (um ponto só).
