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

## BILHETE PARA O SUCESSOR (pausa 18/10, retomada pós-integração ec64161)
- Feito nesta retomada: merge de integracao/onda1 (ec64161); `BossTuning.expected_hit` agora usa
  `SophiaTuning.move_damage` (o dano real ×0,65 +17 %/nível) — era por isso que a vida não acompanhava;
  `enemy.stagger()` usa set_deferred; reflexo/cacos do Espelho com call_deferred (0 erros de monitoring);
  Armupiel tinha ERRO DE PARSE (rodava sem cérebro nas rodadas r5/r6) — corrigido; corte vem 1× por fase,
  Pretorianos com vida de ~6 golpes e meio dano; larvas da final a cada 9 s, máx. 2.
- Sonda r6 (3 grupos em paralelo, `_caps/chefes6/r6?.txt`) e r7 (`r7?.txt`). Ainda FORA da meta (r7):
  Armupiel 219 s / 10 quase-mortes (dano "outro" 371 = Pretorianos + dupla_b 204), Astaphaios 196 s / 5,
  final 292 s / 14. Rei 80 s ok; Athoth 177 s; Harmas 127; Galila 122; Yabel 105; Belias 131 (r6).
- PRÓXIMO PASSO: baixar dano do Armupiel (dmg_scale 0,5→0,4; dupla mais lenta), Pretorianos 1 por fase ou
  vida 4 golpes; Astaphaios 34→28 golpes e dmg 0,5→0,42; final 22/26 → 18/20 e dmg 0,45→0,38; re-sondar
  (3 instâncias), validate -Repeat 2, commit/push, relatório com tabela antes (bossprobe_ec64161.log) /depois.

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
