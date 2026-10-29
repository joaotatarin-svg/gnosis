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

## BILHETE PARA O SUCESSOR (atualizado 29/10 — CHEFES6 sucessor, Coroa/Praga pelo PADRÃO)
- Estado: branch `dir6/chefes6` com a integração `34a55dd` (merge cfe6ac3). validate 14/14 VERDE.
- Feito agora (ver seção "Coroa e Praga pelo PADRÃO — 29/10"): Armupiel ganhou o JUÍZO DA COROA (postura que
  defende + Réplica imparável se baterem nela; quem espera pega ele EXPOSTO); Belias ganhou PÚSTULAS (bolhas
  contáveis de golpe fora da janela → Estouro), RECUO+Bote (resposta a quem cola) e JORRO (3 respingos). BossBrain
  ganhou `guard_rec` (recuperação de golpe-resposta não é janela). Ajuste leve: Galila 38→34 golpes, Yabel 28→25,
  final refaz em 11 s (era 9).
- Ferramentas: BossProbe ganhou `semente=N`, `capmv=id1,id2` (filma ~2,6 s na 1ª vez de cada golpe) e imprime
  `estados=` (dano por estado do chefe), `golpes_chefe=` e `tempo_estado=`. Runner com BelowNormal + 4 CPUs:
  `C:\gnosis-wt\_caps\chefes6\run_probe.ps1` e `batch.ps1 -Tag x -N 6 -Telas "55,64"` (médias por perfil).
- ARMADILHA: a sonda NÃO é determinística (mesma semente varia ±15–25 %): use ≥ 6 sementes antes de concluir.
- PENDENTE: Praga no agressivo subiu menos (65→76 s) e o médio subiu mais (92→118 s) — o bot médio respeita as
  bolhas cheias (`no_touch`) e espera o Estouro. Final (68) médio ainda 139–207 s com 1–3 quase-mortes (só 3
  sementes). Som próprio da postura/bolhas pedido ao Áudio (`docs/pedidos/chefes6.md`). Espelho a 55 px (pendente 2
  antigo) segue igual. Playtest humano do Juízo (o timing da Réplica, 0,32 s depois do golpe dado na postura).

## CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)
| Decisão das lutas | R atendidas | R violadas / risco | Como ficou |
|---|---|---|---|
| Telegrafo de todo golpe (círculo amarelo = aparável, losango vermelho = imparável, brilho a 180 ms, som `tell_*`) | R5 | — | do Enemy; golpes UTILITÁRIOS (piscar, guarda, chamar a corte) não acendem telegrafo (`"tell": false`) — amarelo só quando dá pra aparar |
| Perigos de chão (`BossHazard`): contorno que se FECHA até o golpe + losango + som | R5, R10 (pulso 2 Hz) | antes: 0,05–0,35 s de aviso (QA7 #20) | mínimo de 0,45 s para qualquer área que fere (`MIN_WARN`) |
| Guarda do Espelho (reflete) | R5 | antes: reflexo sem aviso nos 0,4 s de preparo (Guardião) | anel de vidro + som "glass" desde o INÍCIO do preparo |
| Carga dos tiros (VFX7 ChargeFX) | R5, R11 | antes: carga e disparo com o mesmo "proj_fire" | carga com `charge_dark` / `charge_king` (toca quando o Áudio7 entrar no CATALOG; até lá muda, sem repetir o disparo) |
| Tremor | R3, §4.1 | antes: colunas tremiam a cada queda; morte com 4 tremores grandes | só golpe de arena inteira treme (0,35); pancadas 0,35; MORTE: um grande (0,8) no golpe final + micro (0,15). O 0,7 da queda na arte é do integrador de arte (pedido) |
| Hitstop | R2 | — | fase 0,15; golpe final 0,2 (teto) |
| Câmera lenta | R8 | — | só na morte do chefe (0,3× por 0,8 s) e no golpe que mata (Enemy); nada nas fases |
| Silêncio/ducking | R9 | — | fase: −8 dB por 0,8 s; morte: −14 dB por 3 s (o `boss_die` soa sozinho) |
| Confirmação de morte | R17 | — | morte em 5 etapas: impacto → cambaleio → queda (quadros desenhados) → estilhaço → fim; `boss_dying(step)` |
| Um acerto = um evento | R4 | olho do Rei: golpe que pega corpo E olho conta 2× (de propósito: ponto fraco) | o olho só fica atingível exposto |
| Flash | R1, R10 | — | flash do Enemy (limitado pelo Juice); postura quebrada/fase: 1 flash cada |
| Respiro | R21 | risco: lutas longas cansam (QA7) | pausa entre golpes por fase (1,0→0,6 s), rugido de fase 1,3 s intocável, janelas de punição após golpes grandes; recalibrado para 1,5–2,5 min no bot médio |
| Legibilidade | R18 | antes: Sophia sumia atrás do manto do Rei (QA7 #3) | o chefe é desenhado ATRÁS da Sophia; o Rei não encosta na parede (margem 110–120 px) |
| Sorteio de golpes | §3 (sem recompensa variável manipulativa) | — | sorteio semeado pela tela, entre golpes legíveis; não repete 3× |
§4 conferido: 1 (tremor raro) ok · 2 (soma por inimigo) n/a · 3 (empilhar VFX) — a morte desenhada substitui os gibs, sem segundo final · 4 (clarão) só fase e morte · 5 (slow-mo racionado) ok · 6 (hitstop longo em golpe rápido) n/a · 11 (só cor) ok, forma+som · 13 (tudo de uma vez) — risco real: mexi em muitos chefes juntos; precisa do playtest do João.

## RECALIBRAÇÃO pós-combate6 (integração ec64161 → 0a77007, 19/10)
Causa: o `BossTuning` somava o bônus antigo de arma (+6/nível) à tabela crua; o combate6 passou o dano para
`SophiaTuning.move_damage` (×0,65, +17 %/nível) e os golpes ficaram mais lentos → vida dos chefes ~2× maior
que o planejado. Agora a vida usa o dano REAL. Além disso: Armupiel tinha ERRO DE PARSE (lutava sem cérebro);
corte com 1 Pretoriano (só na fase 2, meio dano, vida de 4 golpes) e o rei só comanda enquanto a guarda vive.
Bot médio, vida 120 (sonda r_i, `_caps/chefes6/ri?.txt`):
| tela | chefe | ec64161 (integração) | DEPOIS | golpes | quase-mortes |
|---|---|---|---|---|---|
| 1 | Rei | 123 s / 1 qm | 61 s (alvo subido p/ 27 golpes depois) | 18 | 0 |
| 10 | Athoth | 288 s / 3 | 133 s | 21 | 1 |
| 19 | Harmas | 255 s / 5 | 127 s | 30 | 2 |
| 28 | Galila | 211 s / 6 | 114 s | 38 | 2 |
| 37 | Yabel | 307 s / 4 | 154 s | 28 | 2 |
| 46 | Astaphaios | 234 s / 6 | 124 s | 27 | 2 |
| 55 | Belias | 324 s / 6 | 140 s | 32 | 3 |
| 64 | Armupiel | 420 s TIMEOUT / 22 | 126 s | 29 | 2 |
| 68 | Rei-Mentira + Colosso | 420 s TIMEOUT / 21 | 117 s (fase 3 alcançada) | 47 | 3 |
Variação entre rodadas iguais: ±25 % (ex.: Armupiel 126–178 s; Rei 61–112 s). GIFs novos: luta + MORTE
desenhada do Rei e do Athoth em `C:\gnosis-wt\_caps\chefes6\gif2\` (`morte\*_morte.gif`, `_sheet.png`).

## PLAYTEST DO JOÃO NO REI (28/10) — manto atravessável + "quadrado"
Print: `C:\gnosis-wt\_caps\joao\rei_hitbox_quadrado.webp`. O bug existe na prévia 3 (`origin/preview/3`) E neste
branch: o `enemy._fit_hurtbox` é o mesmo nos dois.
1. **Manto atravessável** — causa: a caixa genérica (`enemy._fit_hurtbox`, dono inimigos6/polimento7) é UM retângulo
   com metade da largura do recorte em volta da pélvis; o manto do Rei abre em leque do joelho para baixo e as pontas
   ficavam fora. Correção do lado do chefe: `scripts/entities/bosses/boss_body_box.gd` (`BossBodyBox`, uma Área só
   com 6 faixas horizontais que seguem o QUADRO mostrado, a mola `_body_xform`, o vira-lado e o teleporte). A largura de
   cada faixa vem da silhueta PINTADA (`tools/chefes6/body_slabs.py` → `rei_body_data.gd`): coluna só conta se opaca em
   ≥ 30 % das linhas da faixa (franja fina não entra), 3 px de folga para dentro. Enquanto ela vale, a HurtShape
   genérica do Rei fica DESLIGADA (uma Área = um acerto por golpe, R4). Vale também para o Rei-Mentira da final
   (herda o `boss_rei.gd`). Pedido de coordenação ao Polimento7: `docs/pedidos/chefes6.md`.
   Medida em TODOS os 24 quadros (`tools/chefes6/body_cover.py`, `_caps/chefes6/rei_quadros.txt/.png`):
   | metade de baixo do corpo | cobre o desenho | caixa fora do desenho |
   |---|---|---|
   | ANTES (genérica) média / pior quadro | 80 % / 54 % | 6 % |
   | DEPOIS (faixas) média / pior quadro | 96 % / 95 % | 8 % |
   No jogo (`tools/chefes6/ReiProbe.tscn`, `_caps/chefes6/rei_antes.txt` × `rei_depois.txt`): cobertura nas poses
   parado/preparo/golpe/recupera 76–88 % → 96–98 %, fora 0–13 % → 2–12 %; golpe leve da Sophia de 150→50 px:
   ANTES 1 "atravessa" (cajado no manto a 70 px, sem dano), DEPOIS 0 atravessa e 0 apelão.
2. **"Quadrado" num poder** — causa: o **Raio do olho** (`raio`/`raio_b`) era um `BossHazard` "band" desenhado com
   `draw_rect` chapado (40×36 px bege) correndo pelo chão — lia-se como um bloco. Agora `look = "beam"`: no aviso a luz
   se junta no chão + risco/seta do caminho + losango vermelho; ativo, ORBE de luz rente ao chão (halo → corpo → núcleo
   branco), cauda que afina atrás, brilho no piso, faíscas girando. Mesma área que fere (o desenho não promete mais).
   Antes/depois: `_caps/chefes6/raio_depois_cima_antes_baixo.png`.
3. **atk_shot no voleio do Astaphaios** — já estava feito (4574a19, `_bounce_volley`: 1 som por salva).
Balanço depois da caixa nova (BossProbe, `_caps/chefes6/r_corpo.txt`): Rei 74 s / 24 golpes / 0 quase-mortes (antes
61–112 s); final 196 s / 7 qm (antes 117–292 s) — dentro da variação.

### CHECAGEM DE SATISFAÇÃO (28/10)
| Decisão | R atendidas | R violadas / risco | Como ficou |
|---|---|---|---|
| Caixa de dano = manto desenhado | R18 (o que se vê é o que vale), R4 (1 Área = 1 acerto) | apelão: faixa de cima pega o braço estendido nos quadros de golpe (até 15 % fora no corpo todo); na metade de baixo, 8 % | franjas finas e pontas fora; olho exposto continua somando (ponto fraco, já documentado) |
| Raio vira orbe com cauda | R5 (aviso: risco/seta + losango + `tell_unblock`), R18 | — | forma de LUZ (não bloco); mesma área de dano; sem clarão novo (R10) |
| Sem mexer em tremor/hitstop/flash | R1–R3, R10 | — | nada novo |

## BodyBox do SONO (Athoth) e do ESPELHO (Astaphaios) — 28/10 (pedido do chefe após o Guardião aprovar 8d00636)
Com a hurtbox genérica do Polimento7 (contorno `body_poly`), o Athoth deixava 15–27 px de pano fora na altura do
cajado e o Astaphaios cobria 50–76 % do desenho. Agora os dois usam `BossBodyBox` (como o Rei). Tabelas:
`body_slabs.py bosses/<id> ... --abrir 3 --fill 0.3`: antes de medir, uma ABERTURA leve (3 px) + maior peça conexa
tira o que está SOLTO (cacos flutuando do Espelho, o espelho que se separa) e fiapos de 1–2 px; o resto é o
critério do Rei. Os ecos/clones do Astaphaios (inimigos comuns) seguem na genérica.
Medida em todos os quadros (`body_cover.py ... --abrir 3 --mundo 0.34`, `_caps/chefes6/{athoth,astaphaios}_quadros.*`;
azul = contorno do Polimento7 reproduzido em Python, verde = faixas). "Pano fora" = px de mundo por linha, dos pés
até 1 Sophia, desenho BRUTO (com fiapos), 2 lados — a métrica da BossHurtProbe:
| | ½ recorte (prévia 3) | contorno (Polimento7) | FAIXAS |
|---|---|---|---|
| Athoth: pano fora / sobra (média) | 22,7 / 3,5 | 25,5 / 2,6 | **7,0 / 2,8** |
| Athoth: pano fora no pior quadro | 46,6 | 40,3 | **11,3** |
| Astaphaios: pano fora / sobra | 15,9 / 3,8 | 18,9 / 1,3 | **7,8 / 2,6** |
| Astaphaios: pano fora no pior quadro | 62,2 | 29,5 | **12,6** |
| metade de baixo: cobre (Athoth / Astaphaios) | 77 % / 79 % | 77 % / 78 % | **95 % / 94 %** |
No jogo (ReiProbe `tela=10/46`, `_caps/chefes6/arc{10,46}_{antes,depois}.log`, antes = ½ recorte deste branch):
Athoth pano fora 19–25 → 10–20 px (com fiapos), golpe que atravessa 1 → 0; Astaphaios 5–14 → 7–12 px com sobra
4–11 → 1–3 px; 1 golpe a 55 px ainda "atravessa" (a ponta do cajado toca a ponta do véu/cajado dele).
Ressalva honesta: a área de caixa fora do desenho fica em ~33 % nos dois — o desenho deles é rendado (fiapos de
névoa, véu em tiras); o contorno também fica em 26–28 %. Na faixa do cajado a sobra por linha é 2,6–2,8 px.

## Re-teste 3.1 (QA7 N2): final e Éons altos leves — 28/10
Causa medida: o bot do QA7 bate SEM PARAR e chega com arma um nível acima do esperado. A minha sonda no perfil
`agressivo` com a arma do QA7 reproduz (Fome 56 s, Praga 62, Coroa 41,5, final 33 s com 0 quase-morte); no perfil
`medio` (a meta 1,5–2,5 min) as lutas já estavam na faixa. Ou seja: quem MARTELA não era punido — o problema é de
leitura, não de vida.
Correção (padrão): `BossBrain.guard_up(k_neutro, k_armado, postura)` — "guarda alta" nos chefes do fim: golpe dado
com o chefe no neutro ou no meio do golpe dele sai no "armado" (faísca azul, dano baixo) e a postura demora mais a
quebrar; as janelas (recuperação, golpe exposto, atordoado, aparo) continuam pagando cheio. Harmas 0,7/0,4/×1,3 ·
Yabel 0,65/0,4/×1,3 · Belias 0,7/0,45/×1,3 · Armupiel, Rei-Mentira e Colosso 0,55/0,35/×1,5. Números: Coroa 26→32
golpes; final com dano dos golpes 0,30→0,38 (QA7: dano tomado caiu de 668–954 para 86–128).
BossProbe (`_caps/chefes6/qa_*.txt` antes, `g1_* … g5_*.txt` depois; agressivo = arma do QA7, médio = arma esperada):
| chefe | agressivo antes → depois | médio depois | quase-mortes (médio) |
|---|---|---|---|
| Harmas (19) | 56 → 58 s | 142 s | 3 |
| Yabel (37) | 64 → 78 s | 147 s | 1 |
| Belias (55) | 62 → 64–71 s | 92–116 s | 2 |
| Armupiel (64) | 41,5 → 65 s | 107–117 s | 1 |
| Final (68) | 33 → 87 s | 188 s | 7 |
Harmas quase não mudou (ele foge/salta, a guarda pega pouco); fica para o playtest. Variação entre rodadas iguais ±25 %.

## QA7 3.1 — Colosso cortado na borda esquerda (tela 68) — 28/10
Causa: a INVESTIDA do Colosso passa da Sophia e para colada na parede; depois, com a Sophia a 40–110 px (dentro
do `keep_dist`), ele não anda mais — fica ali com metade do corpo fora da câmera (Shot 68 seq: centro a 61–87 px
da borda da imagem). Correção: `BossBrain.chase` — colado na parede (dentro de `wall_margin`) o chefe SAI andando
para o meio; Colosso com `wall_margin` 115 (o Rei já tinha 120). Depois: centro a 113–124 px.
Antes/depois: `_caps/chefes6/colosso68_antes_esq_depois_dir.png` (`c68a/` × `c68d/` com o `_meta.json`).

## Fim do jogo pela CURVA DA PROGRESSÃO (e78feb4) em cima da integração ba91602 — 28/10
- Trouxe a integração `ba91602` para o branch (merge 463c148, sem conflito). O `e78feb4` da Progressão conflita
  em arquivos de outros donos (`upgrade_menu.gd`, i18n) — NÃO commitei; medi num worktree descartável
  (`C:\gnosis-wt\chefes6_med` = este branch + e78feb4 com `-X theirs`).
- BossProbe ganhou `curva=1` (arma e vida da tabela de `docs/pedidos/progressao7.md` por tela: 64 → Nv.5/372,
  68 → Nv.5/392) e `vida=N`.
- Integração antes destes ajustes, curva: final 112 s médio / **39 s agressivo** (0 quase-morte); Coroa 98 / 53 s.
- Ajustes (padrão primeiro): batalha final — a forma caída se refaz em **9 s** (era 14): derrubar as DUAS juntas
  é a leitura (baixar as duas, depois fechar), não martelar uma; vida 16/18 → 20/22 golpes. Dano dos chefes do fim
  dimensionado para a vida que a curva entrega (~330–390): Belias 0,45→0,55, Armupiel 0,27→0,38, Rei-Mentira e
  Colosso 0,38→0,48; Coroa 34 golpes.
- Depois (curva, `_caps/chefes6/cv4_*.txt`): final **155 s médio (2 qm) / 76 s agressivo**; Coroa 87–129 s médio /
  57 s agressivo; Praga 90–110 s médio. Coroa e Praga no agressivo seguem curtos (~57–60 s): o bot agressivo acerta
  >1 golpe/s quase sem ser punido — é o próximo passo de PADRÃO (não de vida) para o Armupiel; fica para o playtest.
- Não é meu: ecos do Centro (bestiary.gd) — pedido da Progressão segue para inimigos.

## Ressalvas do Guardião sobre 82454b2 — 29/10
1. Guarda alta: 2º sinal = som "block" curto (máx. 1 a cada 0,25 s) junto da faísca azul (R5/R11).
2. Final: nos últimos 2,5 s antes de a forma caída se refazer, luz crescente que se fecha nela + `charge_king` 1×.
3. Chefe que sai da parede só anda se `rooted_timer <= 0` (o root da Corrente da Lei vale).
4. Espelho a 55 px: o cajado raspa 4 pontos da ponta do véu (`arc46_depois2.txt`, `toque=4`); com `--fill 0.22` não
   fecha e a sobra sobe — mantido sem inflar (ver BILHETE, pendente 2).

## Coroa e Praga pelo PADRÃO (não pela vida) — 29/10 (sucessor)
Diagnóstico (BossProbe com `estados=`): o bot agressivo tira 55–65 % do dano nas RECUPERAÇÕES (que são janelas
legítimas) e o resto no neutro/no meio do golpe — sem nunca sair de perto. Inflar vida alongaria o médio junto
(a Coroa já estava em 151 s no médio). Então o que mudou é o que acontece com QUEM COLA:
- **Armupiel — JUÍZO DA COROA** (fases 1–3; e é a resposta quando a Sophia acerta 4 golpes em 2,5 s, no lugar do
  empurrão, ou 3 golpes fora da janela): crava o espadão de pé, meia-cúpula dourada virada para a Sophia (gira com
  ela) e 3 pontas de coroa sobre a cabeça + som de luz. Golpe na postura = faísca dourada, 0 de dano, e a RÉPLICA
  (corte largo imparável, losango vermelho, joga longe; fase 3 + ondas para os dois lados), que volta à postura UMA
  vez. Recuperação da Réplica = guarda (`guard_rec`, não é janela). Quem ESPERA a postura (1,5 s) ganha ele
  arrancando o espadão, EXPOSTO 1,1 s (×1,35). Capturas: `_caps\chefes6\novos2\s64_juizo_sheet.png`/`.gif`,
  `s64_replica.gif`.
- **Belias — PÚSTULAS / ESTOURO**: cada golpe dado FORA da janela faz brotar uma bolha verde no dorso (contável, até
  4; cheias pulsam rápido). Cheio, ele se encolhe (contorno no chão + losango) e ESTOURA (fere + veneno) e fica
  MURCHO exposto 1,3 s. Encostar nas bolhas cheias estoura NA HORA (sem murcho; peste em volta dele 1,4 s).
  **RECUO + BOTE** (resposta a 3 golpes em 2,5 s, no lugar de se enterrar): salta para trás deixando uma poça onde
  estava e emenda o Bote (vermelho, 0,7 s). **JORRO** (fases 2–3): 3 respingos de bile à frente, um depois do outro
  (círculos, não um bloco — lição do Raio do Rei). Guarda alta igual à da Coroa (0,55/0,35/×1,5: coerente no fim).
  Capturas: `novos2\s55_estouro_toque.gif`, `s55_recuo.gif`, `s55_jorro.gif` (+ `_sheet.png`); 1ª versão em `novos\`.
- Belias e Armupiel não encostam mais na borda da câmera (`wall_margin` 120/110; o Recuo para a 140 px da parede).

BossProbe, curva da Progressão, integração 34a55dd + estes commits (`_caps\chefes6\b0_*` antes, `f2_*` depois;
antes = 3 sementes, depois = 6; tempo médio e faixa):
| chefe | agressivo antes → depois | médio antes → depois | quase-mortes (médio, depois) |
|---|---|---|---|
| Praga (55) | 65 s (57–70) → **76 s** (61–90) | 92 s (91–93) → **118 s** (96–146) | 0–1 |
| Coroa (64) | 57 s (55–62) → **75 s** (65–83) | 151 s (135–164) → **146 s** (119–189) | 0–1 |
Leitura honesta: na Coroa o padrão fez o que devia (agressivo +32 %, médio igual). Na Praga o agressivo subiu
17 % e o médio 28 % — o médio também paga (espera as bolhas), mas segue dentro de 1,5–2,5 min.
Ajuste leve pedido pelo chefe (integração 34a55dd, `_caps\chefes6\all_*` → `fin_*`, 3 sementes, médio):
Galila 166 s (39–47 golpes: vida) → 141 s com 34 golpes-alvo; Yabel 158 → 142 s com 25; final 218 s (187–278,
preso em ciclos de refazer) → 169 s (139–207) com a forma caída refazendo em 11 s. Rei 71, Athoth 118, Harmas 96,
Astaphaios 96 s no médio — não mexi.

### CHECAGEM DE SATISFAÇÃO (29/10)
| Decisão | R atendidas | R violadas / risco | Como ficou |
|---|---|---|---|
| Juízo (postura que defende) | R5 (forma própria: lâmina+meia-cúpula+coroa, + som desde o início), R18 | som emprestado (`mask_light`) até o Áudio entregar `stance_crown` (R11 parcial) | utilitário: sem contorno amarelo (não é aparável); faísca DOURADA ≠ azul do "armado" |
| Réplica 0,32 s depois do golpe na postura | R5 (o aviso é a postura de 1,5 s; a Réplica ainda tem losango + `tell_unblock`) | risco: parecer "contra-ataque injusto" — playtest | só nasce de golpe DADO na postura; volta à postura 1× (máx. 2 Réplicas) |
| Janela de quem espera (exposto) | R21 (respiro), recompensa por leitura (§3 sem sorte) | — | ×1,35 por 1,1 s (Juízo) e 1,3 s (Estouro); determinístico |
| `guard_rec` (resposta não é janela) | R4/R5 (o "armado" mostra faísca azul + `block`) | — | só nos golpes-resposta (Réplica, Estouro por toque, Recuo) |
| Pústulas contáveis | R5 (forma: bolhas 1–4, pulso rápido cheio), R11 (sem só cor) | sons pedidos (`pus_grow`/`pus_burst`) | 4 = teto fixo; janelas não enchem (nada escondido) |
| Recuo + Bote | R5 (Bote: 0,7 s com losango) | — | substitui o "enterrar" como resposta (o enterrar segue no repertório) |
| Jorro em 3 respingos | R5 (contorno que se fecha ≥0,45 s), R4 (1 aviso sonoro por golpe) | 3 losangos na tela (§4.13 tela cheia) — aceitável, são 3 áreas | círculos, não bloco (playtest do Rei 28/10) |
| Galila/Yabel/final | R21 | — | menos vida/mais tempo para derrubar as duas; nenhum golpe novo |
§4 conferido: 1 tremor (Réplica usa o tremor padrão de pancada 0,35, sem novo) · 3 sem empilhar VFX novo além do
desenho da postura/bolhas · 4 sem clarão · 5 sem câmera lenta nova · 11 forma+som · 13 risco: dois chefes mexidos
juntos — precisa do playtest do João. Nada de cassino: nenhum sorteio novo (o Juízo da pressão é regra fixa).

### Ressalva do Guardião sobre db14a1a (Réplica "pegadinha") — 29/10
- A Réplica só arma depois que a postura está ACESA (`STANCE_LIT` 0,3 s, o tempo do desenho acender); golpe dado
  antes disso entra como no "armado" (faísca azul, dano baixo) e não conta para a pressão.
- A 1ª Réplica de cada luta tem preparo de 0,45 s (`FIRST_REPLICA_WIND`; as seguintes 0,32 s) — dá para rolar
  na primeira vez, antes de conhecer a postura (R5).
- Recaptura com o código final (postura que gira com a Sophia): `_caps\chefes6\novos2\v2_s64_juizo{.gif,_sheet.png}`,
  `v2_s64_replica*`, `v2_s64_replica_b*` — meia-cúpula do lado da Sophia, coroa sobre a cabeça.

### QA7 #24 de novo (3.2.1, base 0400a19) — Anéis do Rei no canto do HUD — 29/10
- Causa: o desvio antigo descia o Anel só até y 88 (base 640×360); com o halo de 16 px a borda ficava em 72,
  encostada em "Névoa do Sono" (print do QA7 `_caps\qa7\p32\b68_f2.png`), e a linha da órbita não desviava.
- Agora (`final_battle._hud_safe`): na faixa do medalhão o centro do Anel fica em y ≥ 104 (borda ≥ 88; o HUD acaba
  em 70), entrada suave entre x 290 e 250, e a órbita desvia junto. Antes × depois (16 quadros, ~12 s):
  `C:\gnosis-wt\_caps\chefes6\aneis68_antes_cima_depois_baixo.png` (quadros em `_caps\chefes6\aneis68\`).
- validate: 1ª rodada teve o FlashParryProbe vermelho 1× (intermitente: passou 2×/2× aqui e na integ 0400a19);
  2ª rodada 14/14 VERDE.
