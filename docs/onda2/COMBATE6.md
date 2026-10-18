# Onda 6 — COMBATE DA SOPHIA (branch `dir6/combate6`, base `integracao/onda1` 37ea6f5) — relatório

Feedback do João (playtest 17/10): "dano da Sophia forte demais", "pular + triângulo roubado, sem cooldown",
"ataques frenéticos demais", "movimentação não lisa/travada, mas muito responsiva", "quer pulo duplo".
Todos os números novos estão numa régua só: `scripts/combat/sophia_tuning.gd` (`SophiaTuning`).
Medições: `tools/combate/FeelProbe.tscn` (headless, `--fixed-fps 60`); filmagens: `tools/combate/ActShot.tscn`.
Pedidos aos outros diretores: `docs/pedidos/onda6_combate6.md`.

## 1. O que estava "roubado" (achado)
- **Pulo + forte (Queda Estelar, `a_H`)**: saía no mesmo quadro (preparo 0,03 s), mergulhava a 760 px/s e o dano
  saía **duas vezes**: o contato do mergulho (100 %) **e** a onda do pouso (100 %, em área). No nível 5: 54 + 54.
  Pior: o 2º aperto do forte, guardado no buffer, **continuava o combo no chão** (`["heavy"]` → `m_HH` → `m_HHH`)
  sem recuperação nenhuma — a filmagem de antes mostra `a_H → m_HH → m_HHH → m_H` em sequência.
- **Arma**: +6 de dano FIXO por nível sobre um leve de 12 → nível 5 = 36 (×3). Com a economia generosa
  (nível máximo antes do 2º chefe), Harmas (≈417 hp) caía com 4 Quedas.
- **Frenético**: a janela de encadear abria na metade de todo golpe e, depois do 3º leve, o botão amassado
  **recomeçava** o combo direto da janela (L, LL, LLL, L, LL, LLL... sem recuperação): 4,5 golpes/s.
- **Travado**: a velocidade era um degrau (0 → 185 px/s em 1 passo; 185 → 0 em 1 passo); o botão de ataque
  apertado na recuperação **sumia**; o pulo apertado durante golpe/esquiva **sumia**; a câmera dava um chicote
  de 128 px no look-ahead a cada virada (no meio da luta, toda hora).

## 2. O que mudou
`scripts/entities/player.gd`, `scripts/combat/sophia_tuning.gd` (novo), `scripts/fx/camera_shake.gd`,
`tools/combat_test.gd`, `tools/combate/{feel_probe,act_shot}.gd` (+ .tscn).

**Dano** — base da tabela × 0,65 × (1 + 0,17 × (nível − 1)) (`move_damage`).
**Queda Estelar** — preparo de **0,24 s pairando** (pose `windup_heavy`), contato 35 %, onda do pouso 80 %;
**presa 0,40 s** no chão depois da onda (esquiva só depois de 0,22 s), recuperação 0,25 s, **1 por pulo** (o
pulo duplo não devolve) e **recarga de 1,0 s** contada do pouso; não continua em combo de chão.
**Giro Celeste** — até 2 por pulo, só o 1º paira.
**Ritmo** — preparo: leve 0,06 (3º leve 0,10), lançador 0,12, pesado 0,22, pesado final 0,28. Janela de encadear:
leve 55 %, pesado 68 % do golpe. Recuperação: leve 0,20, pesado 0,42, +0,06 por botão, +0,12 em string de 3+,
+0,20 com área. Da janela de encadear só sai o **próximo da string**; recomeçar espera a recuperação.
**Cancelar só em janelas** — esquiva: leve depois que o golpe saiu; pesado nos primeiros 40 % do preparo (finta)
ou na janela de encadear; Queda nunca no ar. Defesa/aparo: na janela de encadear (segurar antes = só defesa).
**Buffers** — ataque 0,18 s e pulo 0,12 s em QUALQUER estado (sai no 1º quadro livre; amassar antes não adianta).
O golpe de chão sai para onde o direcional aponta (no deslize da virada ela ainda olha para trás 2–3 quadros).
**Movimento** — curva ease-out (rápida no começo, assenta no fim): até a velocidade 0,10 s, freio 0,08 s,
virada 0,09 s; no ar 0,16/0,22 s. Arco do pulo **igual** (gravidade/velocidade intocadas: plataformas valem).
**Câmera** — o lado do look-ahead só troca quando ela FICA virada 0,35 s (ou corre de verdade para o outro
lado por 0,12 s); velocidade de virada 480 → 320 px/s. `CombatCamProbe` telas 3 e 22: fora=0, borda=0.
**Pulo duplo** — 2º pulo no ar (coyote vencido) com 0,9 × a velocidade do pulo (altura ≈ 0,81×; era 0,82 — pedido do level6), pirueta de
360° em 0,34 s (para em golpe/esquiva/dano/pouso), anel de luz nos pés. **Desligado** até
`Progression.has_double_jump()` (ou a propriedade `double_jump`) ser verdadeiro. `debug_double_jump` só para
ferramentas.

## 3. Números antes × depois (FeelProbe, tela 3, 60 Hz, interpolação de física ligada)
| medida | antes | depois |
|---|---|---|
| arrancada até 90 % da velocidade | 1 quadro (degrau) | 6 quadros (100 ms): 45, 83, 115, 142, 166, 185 |
| freio até parar | 1 quadro | 5 quadros (83 ms): 129, 84, 47, 17, 0 |
| virada (direita → esquerda) | vira no 1º quadro, 100 % no 1º | vira no 4º, 90 % do outro lado no 9º |
| botão leve amassado (2 s) | 9 golpes (4,5/s), 240 de dano bruto nv3 | 5 golpes (2,5/s), 57 |
| botão forte amassado (2 s) | 5 golpes (2,5/s), 204 | 3 golpes (1,5/s), 82 |
| Queda Estelar: preparo | 1–4 quadros | 17 quadros desde o aperto (0,24 s pairando) |
| Queda Estelar: depois do pouso | 1 quadro e já encadeia HH→HHH | 29 quadros presa + 0,25 s de recuperação |
| Quedas em 4 pulos × 2 apertos | (o 2º aperto vira combo de chão) | 2 (1 por pulo + recarga 1 s) |
| altura do pulo / 2º pulo | 81 / — | 81 / +66 px (no ápice: ~147 px; saliência do level6 a 116) |

Dano por golpe (nível de arma 1 / 3 / 5):
| golpe | antes | depois |
|---|---|---|
| L, LL | 12 / 24 / 36 | 8 / 10 / 13 |
| LLL | 20 / 32 / 44 | 13 / 17 / 22 |
| H | 24 / 36 / 48 | 16 / 21 / 26 |
| HHH | — / 56 / 68 | — / 38 / 48 |
| Queda Estelar (contato + onda) | — / 42+42 / 54+54 | — / 9+21 / 12+26 |
| LLLH (+onda) | — / — / 64+51 | — / — / 44+35 |

Golpes LEVES para matar (vida no meio de cada Éon × nível de arma da curva sugerida nv1 Torpor → nv5 Coroa;
"antes" = nível 5, como o João jogou):
| | antes (nv5) | depois |
|---|---|---|
| larva / sombra | 1 | 3 |
| servo / sonâmbulo | 1–2 | 4–5 |
| canino | 2–3 | 6–7 |
| escudeiro / carcereiro | 2–3 | 8–9 |
| bruto / pretoriano | 3–5 | 12–13 |
| Athoth (289 hp) | 9 leves / 3 Quedas | 37 leves / 10 Quedas |
| Galila (564 hp) | 16 / 6 Quedas | 57 / 19 |
| Armupiel (1332 hp) | 37 / 13 Quedas (HHH 20) | 103 / 36 (HHH 28) |
(Conta com a vida atual do `bestiary.gd` × `screen_multiplier`. Larva/sombra ficam em 3: pedido ao inimigos6.)

## 4. Movimento "travado": de onde vem (medido)
1. **Degrau de velocidade** (0↔185 px/s num passo) e **botões que sumiam** — eram do combate: corrigido (acima).
2. **Física 60 Hz × monitor 144 Hz**: a interpolação de física está LIGADA e a câmera segue por física
   (`top_level`, interpolada). Isso está certo; não é a fonte.
3. **Quadros desenhados da corrida** (do diretor de arte): `rund` tem 16 quadros trocados pela distância; a
   185 px/s cada quadro fica **[19, 15, 38, 29, 33, 53, 27, 1, 34, 5, 16, 32, 54, 19, 29, 27] ms** na tela
   (ciclo 430 ms = 80 px; média 37 trocas/s). O 8º (1 ms) e o 10º (5 ms) **nunca aparecem** a 60 Hz e o 6º/13º
   seguram 3+ passos: a passada engasga 2× por ciclo com o corpo deslizando liso. Pedido à arte.
4. **VSync desligado + teto de qps = 144** (`game_manager.gd`): ritmo de quadro irregular/rasgo. Pedido ao técnico.
5. **Câmera**: chicote do look-ahead a cada virada — corrigido (histerese).

## 5. Provas (fora do git: `C:\gnosis-wt\_caps\combate6\`)
- `antes\aereo_follow.gif` (1280×720, antes da regra de janela mínima) × `depois\aereo_min.gif`:
  mesmo roteiro (pula e aperta forte 2× a cada 42 quadros). Antes: `a_H → m_HH → m_HHH → m_H` emendados.
  Depois: preparo pairando, pouso preso, e as Quedas seguintes só saem depois da recarga.
- `antes\{andar,amassa,combo}_min.gif` × `depois\{andar,amassa,combo,duplo}_min.gif` (320×180, janela mínima
  fora da tela por pedido do João, que estava jogando). `depois\duplo_zoom.png`: pirueta + anel de luz do 2º
  pulo e o preparo da Queda (recorte ampliado).
- Logs: `feel_antes.log`, `feel_depois.log`; bot: `balance\base_1_10.*` × `balance\c6_1_10.*`.

## 6. Validação (18/10, depois do merge de `integracao/onda1` 06feb8b)
- `tools/validate.ps1 -Path C:\gnosis-wt\combate6 -Repeat 2`: **TUDO VERDE (11 etapas, 2/2 em cada)** —
  CodexQA 53, AudioQA 54, GnoseQA 20, SaveQA 49, TecnicoQA 43, LangQA 1, Puppet/Hero/Wave OK. (Na 1ª sessão o
  AudioQA e o GnoseQA reprovaram uma vez cada com a máquina carregada; passaram sozinhos e passam no merge.)
- `tools/CombatTest.tscn` nv5 e nv1: `QA PASS` (todas as strings, `a_H` 1 por pulo, 2 pulos duplos).
- `tools/combate/FeelProbe.tscn`: `QA PASS`. `tools/combate/HitboxProbe.tscn`: `QA PASS` (§8).
- Bot de balance, telas 1–10, seed 1, `--fixed-fps 60`:
  | | base 37ea6f5 | Onda 6 (dano/ritmo) | + hitbox/contato |
  |---|---|---|---|
  | tempo | 2,8 min | 3,7 min | 3,7 min |
  | dano tomado | 304 | 443 | 378 |
  | quase-mortes | 0 | 2 | 1 |
  | timeouts | 0 | 0 | 0 |
  O run não quebrou. O bot chega ao **nível 4 de arma ainda no Torpor** (economia — progressao6).

## 7. O que NÃO ficou bom / não testei
- **Feel é do João**: curvas (100/83 ms), janelas e preparo da Queda são números de partida; a régua é um
  arquivo só para ajustar no playtest. Se o João achar "lento", a 1ª alavanca é `RECOVERY_*` (não o preparo).
- As magias não mudaram (base + 12/nível de magia); se ainda parecerem fortes, é a próxima alavanca.
- A pirueta gira a pintura inteira (sem quadros próprios); o preparo da Queda usa a pose de chão. Pedido à arte.
- Balance completo (68 telas) não rodei — só a faixa curta, como pedido. Com o corte de dano, Éons do meio em
  diante vão ficar bem mais longos para o bot até inimigos6/chefes6/progressao6 fecharem os números juntos.
- `ComboData.windup_time()/recovery_time()` ficaram sem uso pela Sophia (arquivo não é meu).
- Hitbox: a sonda testa inimigo parado, no chão e na mesma altura; inimigo no ar/voador e chefes grandes não
  entraram na bateria (próximo passo: chefes6/inimigos6 rodarem a sonda com os tipos deles).

## 8. Playtest 2 (18/10): "o cajado atravessa", dano de contato, sonda de hitbox
- **Caixa do cajado** (`scripts/combat/staff_reach.gd` + `player._update_staff_hitbox`): a cada passo de física,
  lê o quadro que o Visual está desenhando (mesma conta do CharacterArt) e a ponta do cajado medida no atlas;
  a caixa cobre mão → ponta (+ o arco do quadro anterior nos quadros de arrasto) com folga de 4×9 px. Ligada
  só em **quadro de impacto** (arrasto marcado no atlas, mergulho, ou cajado ≥ 4 px à frente do pé); fica viva até
  o fim do golpe (antes desligava na metade) mas cada alvo toma **1 acerto por golpe** (o multi-hit religa).
  Varredura mínima de 10 px à frente do pé (o 2º leve desenhado bate atrás do pé). Sem quadros desenhados →
  caixa antiga.
- **Contato**: `Hitbox` ignora o `ContactHitbox` de inimigo contra a Sophia (salvo `contact_hurts = true`).
- **Sonda** `tools/combate/HitboxProbe.tscn` (headless): 5 golpes (L, LLL, H, LH, HHH) × 4 tipos (larva, servo,
  canino, bruto) × 8 distâncias (8–64 px), com a caixa nova e com a antiga:
  | | esperados (cajado desenhado encosta na hurtbox) | acertos | atravessa | apelão (acerta sem encostar) |
  |---|---|---|---|---|
  | caixa ANTIGA 34×42 | 127 | 155 | 0 | **28** |
  | caixa NOVA (cajado) | 127 | 136 | 0 | **9** (bordas: folga + avanço) |
  Contra o CORPO DESENHADO: o cajado encosta no desenho 141 vezes; sem dano em **8 (6 %)** com a caixa nova —
  é a hurtbox mais estreita que o desenho (canino 24 × 52 px, bruto 38 × 68): pedido ao inimigos6/chefes6.
  Contato: Sophia colada num bruto 1,5 s → 120 → 120 (sem o filtro: 120 → 114).
- **Prancha** (headless, PIL): `python tools/combate/hitbox_overlay.py <geo.json> <saida.png>` desenha, sobre o
  quadro do atlas, o cajado (amarelo), a caixa (vermelha ligada / cinza desligada) e a hurtbox (azul / verde se
  encostou). `C:\gnosis-wt\_caps\combate6\hitbox_overlay.png` (200 quadros, servo a 24 px) e `_top.png`.
- **API do contra-ataque**: `riposte_window_opened` + `is_riposte_window_open()` (pedido da encenação).

## BILHETE PARA O SUCESSOR (18/10)
- Estado: tudo da Onda 6 + playtest 2 feito, validado (`validate.ps1 -Repeat 2` verde) e no `dir6/combate6`.
- Régua única: `scripts/combat/sophia_tuning.gd` (dano, ritmo, movimento, pulo duplo); caixa do cajado:
  `scripts/combat/staff_reach.gd`; contato: `Hitbox._is_harmless_contact`.
- Sondas (headless, `--fixed-fps 60`): `tools/combate/FeelProbe.tscn`, `tools/combate/HitboxProbe.tscn`,
  `tools/CombatTest.tscn -- 3 user://c.png 5`; filmagem: `tools/combate/ActShot.tscn` (janela mínima 320×180 em
  4000,4000 — regra do João); bot curto: `tools/BalanceBot.tscn -- 1 10 1 seed=1 out=...`.
- Pendências: feel no playtest do João (curvas, preparo da Queda, recuperação); hurtboxes dos inimigos (pedido);
  getters públicos da Arte; FeelProbe/HitboxProbe no `validate.ps1` (pedido ao estab5); magias sem retoque.
