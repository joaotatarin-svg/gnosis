# Onda 7 — Áudio7 (branch `dir7/audio7`, base `origin/integracao/onda1`)

> Som com identidade (sombrio, sacro, cósmico) para o conteúdo novo das Ondas 5–6. 100 % síntese própria
> (numpy, `tools/audio_synth/onda7.py`), determinística. Nenhum pack novo, nenhum crédito de terceiros novo.

## BILHETE PARA O SUCESSOR (atualizado a cada bloco)

**29/10 — DUBLAGEM (sucessor do Áudio7):** o jogo toca as vozes gravadas. Último commit de código:
ver `git log` (a partir de `08994eb`). Seção completa: "Dublagem" mais abaixo. Em uma linha: `Audio.play_voice(fala,
dono)` acha o `.ogg` pelo id `sha1(falante|texto_pt)[:12]` no MANIFESTO de dados
`assets/audio/voice/manifest.json` (hoje vazio); lote novo = copiar `.ogg` + acrescentar no manifesto, sem
código. Contrato com a Dublagem: `C:\gnosis-wt\_caps\dublagem\CONTRATO_AUDIO.md` (escrito por mim; o
Dublagem não tinha publicado). Prova: `tools/audio/VoiceProbe.tscn` (0 falhas) + validate 14/14.
- **Próximo passo:** integrar o 1º lote (Limiar/Rei) quando o Dublagem entregar; rodar a VoiceProbe (linha
  "manifesto real"). Regras do Guardião (`_caps/dublagem/REGRAS_GUARDIAO.md`) JÁ aplicadas nas partes do jogo
  (§1, §2, §5, §10, §18-20, §22); §3/§4 são do roteiro/Dublagem.
- **Armadilhas:** `stream_paused` deixa `playing` = false no Godot 4.7 (o dono da voz não pode ser limpo por
  isso). O id usa o texto PT EXATO (com rubrica e `\n`); texto mudou = voz some até regerar. Os blips saíram
  do bus Voice para o UI (mesmo ganho de antes).

**Estado anterior:** ENTREGA FINAL do Áudio7.
- 118 sons novos (143 arquivos com as variações) estão no CATALOG.
- API nova: `move_sfx`/`move_sound_for`.
- Ganchos por sinal + observador `_Watch` (eventos sem sinal, só bordas).
- AudioQA verde, com o bloco (h1–h10).
- `onda7_check.py` verde (R5/R11/R12/R13).
- Bot de balance (telas 2–64) confirma que os ganchos disparam jogando.

**O que falta (dos outros):** as TROCAS de som genérico na fonte, em `docs/pedidos/audio7.md` (player.gd,
`_enter_phase`, campeão, perigos, mapa, projétil hostil, cargas do VFX7). Até lá, esses eventos tocam o som
antigo. Nada fica mudo por causa disso.

**Armadilhas:**
- `M.choir(notas, dur, vogal, shift, ...)`: a 4ª posição é `shift`, então passe `vowel2=` por nome.
- `build_sfx.py` só grava `sfx_report.json` no fim; uma receita que quebra perde o relatório do lote.
- Os `.import` dos sons ANTIGOS aparecem como modificados depois do import (só CRLF): NÃO os commite.
- Na edição por script, `"# --- perigos do level6"` casa primeiro com o comentário do CATALOG. Use marcadores
  únicos.
- O observador lê propriedades de outros scripts por `get()`. Se um dono renomear uma delas, o evento fica mudo
  sem erro. A prova é rodar o bot com `GNOSIS_AUDIO_LOG=<arquivo.json>` e ver a contagem.

**Como refazer:**
1. `GNOSIS_PACKS=<cópia OneDrive>/assets/_packs python tools/audio_synth/build_sfx.py <nomes>`. Os nomes saem de
   `python tools/audio_synth/onda7.py --list`.
2. Import headless, depois AudioQA, depois `python tools/audio/onda7_check.py`.
3. Amostras: `python tools/audio/onda7_demos.py`.

## Paleta (a "cara" do som)
- **Luz** (Sophia, Mônada, Soter, altar): vidro (parciais de taça), sinos e coro aberto 'a' em **Mi maior**.
- **Trevas** (Arcontes, criaturas, perigos): serras graves desafinadas (2ª menor/trítono), formantes 'o/u',
  aspereza (AM 20–40 Hz), pedra e ferro.
- **O Rei/Yaldabaoth:** luz ROUBADA. Coro masculino grave + metal dourado + sub.
- **Cada Arconte tem a textura do seu Éon:**
  - Torpor: caixinha e bocejo.
  - Fome: sucção e mordida.
  - Corrente: elos e grades.
  - Silêncio: grito que corta e zumbido.
  - Espelho: vidro dos dois lados.
  - Praga: esporos e enxame.
  - Coroa: gongo, coro e lâmina dourada.

## Mixagem (M-max por categoria, mesmo método das ondas anteriores)
As categorias novas entram no `CAT` do `build_sfx.py`. Teto: pico de amostra −1 dBFS (limitador). Novo nesta
onda: depois do limitador, o PICO VERDADEIRO é forçado a ≤ −1 dBTP, com 0,3 dB de folga para o Vorbis.

| Categoria | M-max | Uso |
|---|---|---|
| `eatk` | −19 | golpe de inimigo comum, abaixo do swing da Sophia (−18) e do acerto (−12) |
| `eatk_big` | −16 | pancada, coluna e invocação de inimigo; `chain`/`glass` do kit |
| `charge` / `charge_big` | −19 / −16 | carga antes do tiro (cresce; quem pesa é o tiro) e carga do Rei |
| `sophia` / `sophia_layer` | −19 / −17 | pulo duplo; Queda Estelar pousando = camada POR BAIXO da `nova` (−12), sem baque próprio (R4) |
| `bsig` / `bsig_soft` | −13 / −15 | golpe-assinatura de chefe / feitiço longo de chefe |
| `boss_mid` / `death_hush` | −12 / −24 | passos da morte que somam com `boss_die` / a pausa (quase nada) |
| `hazard_big` / `hazard` / `hazard_soft` / `hazard_amb` | −15 / −18 / −22 / −28 | perigo que fere / perigo / aviso-presença / presença contínua |

Usam categorias existentes: `tell` (−17, `riposte_ready`), `swing_big`, `champion` (−12), `boss` (−10),
`elite`, `hit`, `reward` (−13), `ui_big`/`ui`/`shop`, `structure`, `story`.

**Vozes e anti-spam:**
- `atk_*`: 130 ms e no máximo 2 vozes (Guardião). Também variam ±4 % de tom e ±1,5 dB.
- Tiques e presenças: maré 300 ms, luz drenando 250 ms, Éter 400 ms, altar 1,5 s.
- Conquista: 2,5 s e 1 voz. Uma rajada de conquistas toca uma vez só.

## API nova do `Audio` (Onda 7)
- `move_sfx(mv: Dictionary, stage: String, pos := NO_POS, boss := false) -> bool` toca o som do golpe. A ordem:
  1. `BOSS_MOVE_SFX[id]`, só para chefes (id normalizado: `guarda3` → `guarda`, `corte_b` → `corte`).
  2. Tiro: teleguiado → `atk_homing`; de cima → `atk_shot_air`; vários → `atk_fan`.
  3. `KIND_SFX[kind]`.

  Etapas: `"wind"` (início do telegrafo; o `tell_*` continua à parte), `"strike"` e `"land"` (pouso do salto
  do chefe → `bs_land`).
- `move_sound_for(mv, stage, boss)`, `move_base_id(id)`, `death_step_sfx(passo)`, `spam_ms_for(nome)` e
  `max_same_for(nome)`: as consultas usadas pelo AudioQA.
- `played_counts` + variável de ambiente `GNOSIS_AUDIO_LOG=<json>`: conta o que tocou e grava no encerramento.
  É ferramenta de QA/bot; desligada, não custa nada.
- Cue `sink` (roubo): `king_sink`, `crack_open` 0,5 s depois e `fog_swell` 0,6 a −8 dB. Antes eram sons de
  combate reaproveitados (`dive` + `boss_step`).
- Buses: `riposte_ready` → Tell (fora do abafado da câmera lenta). `map_*` e `achievement` → UI.

### Quem liga cada som (para ninguém dobrar)

| Origem | Eventos |
|---|---|
| **Sinal** (`audio_manager.gd`) | `Enemy.boss_dying(0..4)` → morte em 5 passos. `Player.riposte_window_opened` → `riposte_ready`. `Progression.double_jump_granted` → `soter_gift`. `Progression.relics_changed` → `relic_equip`. `Achievements.unlocked` → `achievement` |
| **Observador `_Watch`** (borda de estado, nó PAUSÁVEL, perigo a > 720 px da câmera não soa) | Inimigos: WINDUP/STRIKE → `move_sfx`, inclusive TIRO (o vfx7 deixou o disparo hostil mudo e usa o `atk_*` como som do tiro); `_downed` 0→>0 (voador) → `fly_fall`; `_champ_fury` → `champion_fury`. Chefes: `brain.mv` → `move_sfx(..., true)`; `_airborne` true→false → `bs_land`; postura volta cheia + atordoado > 1,3 s → `guard_break`; hurtbox do olho do Rei → `eye_hit`. Sophia: `dive_landed` → `star_impact`. Totem/luz `_armed` → `zone_objective` (+`hz_totem_arm`). HUD `_tier_seen` sobe → `shop_seal`. Perigos mudos: feixe liga/desliga, plataforma-reflexo, névoa, pedra (afunda/volta), esporo incha, caco (sombra/queda), saída do silêncio, marca do segredo, guilhotina sobe, tique da maré, luz drenando |
| **Dono troca na fonte** (`docs/pedidos/audio7.md`) | 2º pulo, carga da Queda, contra-ataque (player.gd); fase 3; entrada do Campeão; perigos que já tocam som genérico; mapa; relíquia sem `shop_buy`; cargas do VFX7 |

O 2º pulo, a carga da Queda e o golpe do contra-ataque saíram do observador por reprovação do Guardião
(634bc91, som dobrado com jump/dive/swing). Quem troca é o polimento7.

## Verificação
- **AudioQA:** 0 falhas, 66 PASS. O bloco (h) da Onda 7 confere:
  - 18 tipos de golpe de inimigo com som; 55 golpes de chefe com som, lidos dos scripts e não de lista;
  - normalização de id;
  - variações de tiro;
  - `move_sfx`;
  - morte em 5 passos pelo sinal;
  - contra-ataque no bus Tell;
  - conquista em rajada = 1;
  - cue `sink`;
  - tom fixo dos sons de informação;
  - observador (golpe, voador, fúria; e que 2º pulo, contra-ataque e carga NÃO dobram);
  - anti-spam/vozes de `atk_*`.
- **Bot de balance jogando** (`GNOSIS_AUDIO_LOG`, telas 2–64, 108 min de jogo, 0 SCRIPT ERROR). Exemplos do que
  disparou sozinho:
  - morte em 5 passos 7/7 chefes;
  - `atk_swing` 641, `atk_combo` 608, `atk_pillar` 272, `fly_fall` 185, `atk_dive` 170;
  - `bs_land` 50, `bs_melee` 35, `bs_bite` 17, `bs_burrow` 14, `bs_royal_cut` 12;
  - `hz_beam_on` 130, `hz_spore_swell` 147, `hz_winch` 44, `hz_silence_out` 53;
  - `zone_objective` 17, `shop_seal` 5, `achievement` 8, `soter_gift` 1, `champion_fury` 7, `guard_break` 1.

  Não dispararam no bot porque o bot não faz isso ou não passa por lá:
  - `star_impact` (não usa a Queda) e `riposte_ready` (não apara);
  - `eye_hit` e `bs_ray/hand/rings` (o Rei está nas telas 1/68);
  - `hz_shard_*` (Centro 65–67), `hz_sink_start` (não fica parado em cima);
  - `chain` (o laço não pegou).

  A contagem é da versão anterior à correção de 130 ms.
- **`tools/audio/onda7_check.py`** (medição dos arquivos): pico verdadeiro ≤ −1 dBTP em todos; M-max no alvo
  (±1,5) em todos.
  - R12 pesados: 17/17 com sub ou corpo ≥ −14 dB do total.
  - R12 frequentes: nenhum com > 0,25 s de 2–5 kHz dominante; `chain` e `hz_chain_swing` foram filtrados para
    passar.
  - R11: variações diferentes entre si.
  - R5: os sons de informação a ≥ 29 de distância MFCC uns dos outros. O par mais perto é `charge_king` ~
    `swing_light` (29,6); a mediana entre variações do mesmo som fica abaixo de 10.

## CHECAGEM DE SATISFAÇÃO (docs/handoff/NEURO_SATISFACAO.md)

| Regra | Como o Áudio7 atende | Status |
|---|---|---|
| **R4** um acerto = um evento | O golpe do inimigo soa no STRIKE (sopro/rosnado, sem impacto: o acerto continua sendo o `hit`). Queda Estelar = camada de estrelas sob a `nova`, sem 2º baque. O 2º pulo, a carga e o contra-ataque saíram do observador (Guardião). As trocas na fonte estão pedidas (`TROCAR a → b`, nunca `a + b`). Tiro: o disparo hostil é mudo (vfx7, a63c40b) e o `atk_*` é o som do tiro. A carga é `charge_*`; não há 2 sons por tiro. | atendido no Áudio; as trocas na fonte dependem dos donos |
| **R5** telegrafo com som | O `tell_parry/unblock` continua intocado. `riposte_ready` (o "agora!" do contra-ataque) vai no bus Tell, com tom fixo, a 69 de distância MFCC do `tell_parry`. Os perigos que ferem mantêm o `tell_unblock` e ganham som próprio no golpe. | atendido |
| **R6** faísca | Não mexi. | — |
| **R7** adoçante do combo | Não mexi; nenhum som novo sobe de tom com o combo. | — |
| **R8** slow-mo | Sons novos no bus SFX passam pelo abafado da câmera lenta. Só `riposte_ready` fica fora (informação). | atendido |
| **R9** silêncio antes do chefe e na morte | O Campeão NÃO toca mais `boss_appear` (pedido), para não soltar a música de chefe fora de hora. A morte em 5 passos encaixa na abaixada que já existe (`duck_music` 3 s, −14 dB) e no corte de 150 ms do `boss_die`, com um passo de quase-silêncio (`boss_death_hush` −24). | atendido |
| **R11** variação | 2–3 variações nos frequentes (`atk_swing/shot` 3, `atk_combo/rush/leap/slam/wave/dive/shot_air` 2, `fly_fall` 2, `chain/glass` 3, `hz_shard_impact` 3, `hz_spears/chain_swing/totem_hit` 2, `eye_hit` 2, `bs_melee/cast` 2). Variação ±4 % e ±1,5 dB. Vozes: `atk_*` 2, padrão 3. Limitador −1 dB no Master. O AudioQA exige 2+ variações nos frequentes. | atendido |
| **R12** grave que sobrevive / sem agudo cansativo | Pesados com fundamental de 30–100 Hz e corpo de 120–250 Hz (medido). Leves sem sub. Frequentes e repetidos sem 2–5 kHz sustentado (medido: ≤ 0,25 s). `hz_tide_tick` e `hz_ward_drain` foram puxados para 600–2500 Hz. | atendido |
| **R13** loudness | Arquivos no alvo por categoria; pico verdadeiro ≤ −1 dBTP. NÃO medi os 10 min de combate gravado (alvo −20 a −23 LUFS integrados): exige captura de áudio do jogo rodando, e o driver é Dummy. | parcial (honesto) |
| **R14** estéreo discreto | Inimigos, chefes e perigos tocam por `play_sfx_at` (pan ±50 %, atenuação pela distância). Perigo a > 720 px da câmera não toca. Sophia e UI no centro. | atendido |
| **R22** vida baixa | Não mexi. Nenhum som novo é "bip" contínuo; as presenças (`hz_altar_hum`, `hz_ward_drain`) têm anti-spam e 1 voz. | — |
| **R4** (dublagem) sem poluição sonora | Fala dublada NÃO toca blips (um evento de voz por fala). Só uma voz por vez: a nova corta a velha; a legenda seguinte só entra depois da voz + 0,4 s; voz de luta sem folga por 4 s é DESCARTADA (nunca empilha — Guardião §22). Nenhuma voz de dor/esforço nova. | atendido (VoiceProbe) |
| **R5** (dublagem) aviso acima da voz | Durante um `tell_*` a voz desce 8 dB e perde graves (passa-altas 250 Hz, 10/300 ms); voz de luta não COMEÇA nos 400 ms depois de um aviso, com golpe avisado no ar (windup→strike + 0,3 s, lido pelo observador) nem até 0,5 s depois do stinger/morte do chefe (Guardião §10/§20). Nenhuma informação só por voz. | atendido (VoiceProbe) |
| **R9** (dublagem) ducking | Voz soando: música em −8 dB, ambiência em −6 dB, ataque 80 ms / release 700 ms, "vale o maior" (com o diálogo já em −9 a voz não soma: medido −9, não −12). Efeitos de gameplay e Tell NÃO baixam (medido: intocados). | atendido (VoiceProbe) |
| **R13** (dublagem) volume | Contrato: fala −20 a −22 LUFS short-term, grito ≤ +4 LU, ≤ −1 dBTP (Guardião §21). Bus Voice direto no Master, slider próprio (padrão 80 %), fora do −6 dB do SFX e do abafado do slow-mo. NÃO medi a mixagem com voz (driver Dummy). | parcial (honesto) |
| **R21** (dublagem) ritmo de leitura / controle | A caixa NUNCA avança sozinha e nunca segura o jogador: avanço livre desde o 1º quadro (fala dublada ignora o `wait_2s`); apertar com a voz soando completa o texto e corta a voz (80 ms); o seguinte avança. Texto e voz terminam juntos (medido 0,09 s; regra ±0,3). Nenhuma fala pausa o mundo em combate (legenda não bloqueante). Pausa congela a voz da legenda; morte, troca de cena e pular cortam (0,12 s); dono apagado = voz some. | atendido (VoiceProbe) |
| **§3/§4** sem cassino | Nada de moeda, caça-níquel, arpejo "jackpot" nem som que cresce com sorte. Conquista, selo, relíquia, altar e dom do Soter são coro, sino e vidro em Mi maior, de duração fixa e independentes do valor ganho. A conquista em rajada toca 1 vez. O `shop_buy` (moedas, antigo) não foi tocado nem ampliado. | atendido |

## Dublagem (29/10/2026)

Pedido do João: dublagem na próxima versão, entrando AOS POUCOS (lotes da Dublagem, começando pelo
Limiar/Rei). Segue as regras do Guardião (`C:\gnosis-wt\_caps\dublagem\REGRAS_GUARDIAO.md`) nas partes
que são do jogo: §1 controle, §2 legenda, §5 mixagem, §10/§20 janelas. §3/§4 (frequência, duração,
intensidade, legião, reverb) são do roteiro/Dublagem. Desenho do Dublagem (`dir7/dublagem`, `docs/onda2/DUBLAGEM.md` §7) implementado com uma mudança:
os blips ficam no bus UI e o slider "Vozes" só controla a dublagem (0 = desligada → blips).

**Dados (sem código por lote):** `assets/audio/voice/manifest.json` → `lines.<id>.<pt|en>.file`. O id é
calculado pelo jogo: `sha1(falante + "|" + texto_pt)[:12]` (falante `"card"` nos cards, `"estela"` nas pedras).
Idioma = o do texto; sem arquivo nele, o outro. Arquivo ainda não importado (lote recém-copiado no editor) é
lido cru (`AudioStreamOggVorbis.load_from_file`); o build exportado usa o importado. Variável
`GNOSIS_VOICE_MANIFEST=<arquivo>` troca o manifesto (sonda). Contrato completo:
`C:\gnosis-wt\_caps\dublagem\CONTRATO_AUDIO.md`.

**API do Audio:** `play_voice(fala, dono) -> duração` (0 = sem voz), `stop_voice(dono, fade)`,
`pause_voice(dono, on)`, `is_voice_playing(dono)`, `voice_entry(fala)`, `voice_id(falante, texto)`,
`voice_manifest()` / `reload_voice_manifest()`, `voices_enabled()`; `set_volume("Voice", v)`. Dois players
no bus Voice (a fala nova entra enquanto a velha some); a voz só é cortada pelo próprio dono (a legenda não
cala a caixa que abriu depois).

**Onde as falas nascem (edição mínima por delegação do chefe, registrada em cada arquivo):**

| Arquivo (dono) | O que mudou |
|---|---|
| dialogue_box.gd (UI) | `_start_voice` em `_show_line`; com voz, sem blips e CPS pela duração (`voice_cps`); avançar/fechar/abortar corta a voz |
| caption_bar.gd (UI) | `_show` toca a voz e segura a legenda ≥ voz + 0,4 s; sem blips; `pause_voice` enquanto escondida; `_hide` corta |
| cinematic.gd (Encenação) | card segura ≥ voz + 0,6 s; fim do card, `_finish` e `_exit_tree` cortam |
| options_menu.gd (UI) | slider "Vozes" (0 = "Desligadas") na coluna JOGO, depois de "Vibração do controle": na coluna de Áudio a tela transbordava (título e "Voltar" cortados). Captura: `C:\gnosis-wt\_caps\audio7\opcoes_vozes_640.png` |
| save_manager.gd (Técnico) | `vol_voice` no save e em `DEFAULT_VOLUMES` (padrão 0,8 — Guardião §18) |
| en_table.gd (i18n) | "Vozes" → "Voices", "Desligadas" → "Off" |

O npc_encounter usa DialogueBox e `Gnosis.captions` (CaptionBar): coberto sem edição. O narrative.gd não
precisou mudar (o id sai do texto). Estelas: o painel mostra tudo de uma vez — "ouvir a pedra" fica para
depois (botão novo no `stela.gd`, outro dono).

**Verificação (`--audio-driver Dummy`, nada tocado no PC):**
`godot --headless --audio-driver Dummy --path . res://tools/audio/VoiceProbe.tscn` → `VOICE PROBE: 0 falhas`.
Monta um manifesto de teste ligando 4 falas REAIS às amostras da Dublagem (intro da Voz `d6059a40ad2f`,
legenda da Sophia no Limiar, chegada do Rei, card 1 do prólogo `a4f2a4baab4a`). Resultados medidos:
caixa com voz 4,02 s, música −4,4 → −13,4 dB (−9 do diálogo, a voz não empilha), ambiência −6; fala
dublada sem blips; texto termina 0,09 s antes da voz; a caixa espera o jogador; aperto no 2º quadro completa
o texto e corta a voz (80 ms), o seguinte avança; fala sem arquivo volta aos blips; `wait_2s` não trava fala
dublada; dono apagado = voz some; legenda 5,94 s fica 6,62 s no ar, música −8, efeitos e Tell intocados,
pausa congela e retoma; card do prólogo segura 8,1 s de voz (tempo do card 5,9 s); `tell_unblock` → voz
−8 dB + passa-altas 250 Hz; voz logo após o aviso espera 0,67 s; golpe avisado no ar segura a voz e ela
começa 0,3 s depois; sem folga por 4 s = descartada; stinger (2,58 s) segura a voz 3,09 s; Vozes = 0 →
blips; padrão do slider 80 %. Também checa o manifesto REAL: todo arquivo listado existe e carrega.

## O que NÃO ficou bom / não verifiquei (honesto)
- **Dublagem:** ninguém ouviu a mixagem voz + música + luta (driver Dummy); os dB acima são do mixer, não de
  medida de loudness. A única mudança de tela é o slider "Vozes" nas Opções (capturado, cabe).
  O manifesto do jogo está vazio até o 1º lote.
- **Ninguém ouviu.** Vozes por formantes (rugidos, grito do Yabel, coros) podem soar "de computador".
  Amostras para o João: `C:\gnosis-wt\_caps\audio7\AMOSTRAS.md`.
- R13 de combate gravado não foi medido.
- O observador depende de nomes de propriedades de outros donos. Renomear = evento mudo (sem erro). O bot com
  `GNOSIS_AUDIO_LOG` é a prova.
- `hz_secret_open` não tem onde tocar: `secret_vault.gd` ainda não tem lógica de abrir.
- Galila `chain` e o olho do Rei não dispararam no bot; estão cobertos só pelo AudioQA e pela leitura do código.
- `guard_break` usa uma heurística (postura volta cheia + atordoado > 1,3 s). Se o chefes6 mudar
  `BREAK_STAGGER` para ≤ 1,3 s, ela para de disparar.

## Catálogo dos sons novos

Todos são síntese própria (S). Var = nº de arquivos (`nome`, `nome_2`, ...).

| Arquivo | Categoria / M-max | Var | Como soa |
|---|---|---|---|
| `sfx/chain.ogg` | eatk_big -16 | 3 | Galila: o laço pega — elos acelerando + PUXÃO (sopro) + trava de ferro. |
| `sfx/glass.ogg` | eatk_big -16 | 3 | Astaphaios: a guarda de espelho devolve o golpe — vidro 'ping' que se espelha (o mesmo som ao contrário do outro lado) + lascas. |
| `sfx/charge_light.ogg` | charge -19 | 1 | Sophia carrega: coro em Mi maior que abre, fio de luz subindo, faíscas. |
| `sfx/charge_dark.ogg` | charge -19 | 1 | Arconte carrega: serras graves desafinadas inspirando (sucção), sub que cresce e um sussurro 'u' — a escuridão puxa o ar antes do tiro. |
| `sfx/charge_king.ogg` | charge_big -16 | 1 | O Rei carrega: luz ROUBADA — coro masculino grave 'o' + gongo ao contrário + sino dourado no topo; mais longo e mais largo. |
| `sfx/double_jump.ogg` | sophia -19 | 2 | 2º pulo (dom do Soter): sopro para cima + ANEL de luz (vidro em Mi-Si). |
| `sfx/star_charge.ogg` | charge -19 | 1 | Queda Estelar carregando (paira): estrelas se juntando, sobe e segura. |
| `sfx/star_impact.ogg` | sophia_layer -17 | 1 | Queda Estelar pousa — CAMADA de estrelas sobre a `nova` (que já é o baque, R4: um impacto por evento): chuva de estrelas caindo + cascalho + sino. |
| `sfx/riposte_ready.ogg` | tell -17 | 1 | Aparo perfeito → a janela do contra-ataque ABRIU: dois 'tins' de lâmina subindo (Si6→Mi7), curtos — o ouvido aprende 'agora!'. |
| `sfx/riposte.ogg` | swing_big -16 | 1 | Contra-ataque: estocada — sopro rasgado + 'xing' de lâmina + peso. |
| `sfx/combo_tick.ogg` | combo -28 | 1 | Adoçante do combo (R7): tique de vidro CURTÍSSIMO (~70 ms) em Mi5, sem agudo sustentado — fica "dentro" do impacto; o Audio sobe a pentatônica. |
| `sfx/atk_swing.ogg` | eatk -19 | 3 | Garra/osso cortando o ar: sopro médio + estalo ósseo. |
| `sfx/atk_combo.ogg` | eatk -19 | 2 | Duas garradas coladas (a 2ª mais grave). |
| `sfx/atk_rush.ogg` | eatk -19 | 2 | Investida: pé que firma + sopro acelerando + rosnado. |
| `sfx/atk_leap.ogg` | eatk -19 | 2 | Bote: sibilo + sopro para cima (o bicho salta). |
| `sfx/atk_slam.ogg` | eatk_big -16 | 2 | Pancada no chão: soco grave + cascalho. |
| `sfx/atk_wave.ogg` | eatk -19 | 2 | Onda pelo chão: pedra rolando que se afasta (grave rugoso + estalos). |
| `sfx/atk_shot.ogg` | eatk -19 | 3 | Tiro das trevas: 'thum' grave + zunido descendo (não o zip claro da Sophia). |
| `sfx/atk_shot_air.ogg` | eatk -19 | 2 | Tiro de CIMA (voador): o mesmo tiro com 'queda' de tom e sopro de asa. |
| `sfx/atk_fan.ogg` | eatk -19 | 1 | Leque: 3 zunidos abrindo em leque (esq → centro → dir). |
| `sfx/atk_burst.ogg` | eatk -19 | 1 | Rajada: catraca de 4 disparos secos (o arco do atirador). |
| `sfx/atk_homing.ogg` | eatk -19 | 1 | Teleguiado: fogo-fátuo que ondula (vibrato largo) + sussurro. |
| `sfx/atk_lob.ogg` | eatk -19 | 1 | Arco: arremesso 'fuup' para cima + giro (bamboleio) no ar. |
| `sfx/atk_pillar.ogg` | eatk_big -16 | 1 | Coluna de luz (profana) brotando: sub crescendo → explosão de coro rachado. |
| `sfx/atk_fissure.ogg` | eatk -19 | 1 | Lâmina rasteira pelo chão: raspar de pedra que corre + rachaduras. |
| `sfx/atk_grab.ogg` | eatk -19 | 1 | Agarrão: avanço + mão que fecha (pano/carne) + puxão. |
| `sfx/atk_blink.ogg` | eatk -19 | 1 | Aparece ATRÁS: sucção ao contrário + estalo + sussurro do outro lado. |
| `sfx/atk_summon.ogg` | eatk_big -16 | 1 | Invocação: canto grave 'u' + borbulho do chão + rachadura. |
| `sfx/atk_nova.ogg` | eatk_big -16 | 1 | Pulso escuro: ar sendo puxado → estouro grave. |
| `sfx/atk_dive.ogg` | eatk -19 | 2 | Mergulho do voador: guincho descendo + vento rasgando. |
| `sfx/atk_glide.ogg` | eatk -19 | 1 | Planar: 2 batidas de asa + sopro longo. |
| `sfx/fly_fall.ogg` | eatk -19 | 2 | Voador atingido cai: asas descompassadas + assobio de queda + baque. |
| `sfx/champion_enter.ogg` | champion -12 | 1 | Campeão entra: trompa de guerra grave (serra em 5ª) + ferro arrastado + rugido. |
| `sfx/champion_fury.ogg` | champion -12 | 1 | Fúria do Campeão: rugido que acende (sobe) + labareda. |
| `sfx/boss_phase3.ogg` | boss -10 | 1 | Fase 3 (desespero): rugido duplo + coro em cluster que racha + impacto. |
| `sfx/guard_break.ogg` | elite -13 | 1 | Quebra de guarda: armadura racha (pedra+vidro) + ar escapando + sino abafado. |
| `sfx/eye_hit.ogg` | hit -12 | 2 | Olho do Rei atingido (ponto fraco): vidro perfurado (ping desafinado) + chiado molhado + guincho de coro curto — dói e soa como ACERTO CRÍTICO. |
| `sfx/boss_death_impact.ogg` | boss -10 | 1 | Morte 0 — IMPACTO: golpe final que PARA o tempo (baque + metal + ar sugado). |
| `sfx/boss_death_stagger.ogg` | boss_soft -14 | 1 | Morte 1 — CAMBALEIA: gemido grave descendo + rangido de armadura. |
| `sfx/boss_death_collapse.ogg` | boss_mid -12 | 1 | Morte 2 — COLAPSO: joelho, corpo, pedra (3 baques) + estrondo baixo. |
| `sfx/boss_death_hush.ogg` | death_hush -24 | 1 | Morte 3 — PAUSA: quase nada. Um sopro que sai do corpo + zumbido de ouvido. |
| `sfx/boss_death_shatter.ogg` | boss_mid -12 | 1 | Morte 4 — ESTILHAÇO: o corpo vira cacos de luz (vidro em cascata) + coro que sobe (a centelha sai) + sino grave. |
| `sfx/bs_melee.ogg` | bsig -13 | 2 | Golpe pesado de chefe (reserva do tipo melee): lâmina larga + peso. |
| `sfx/bs_cast.ogg` | bsig_soft -15 | 2 | Feitiço de chefe (reserva do tipo cast): canto escuro que cresce. |
| `sfx/bs_leap.ogg` | bsig -13 | 1 | Salto do chefe: tomada de impulso + sopro subindo e sumindo. |
| `sfx/bs_land.ogg` | bsig -13 | 1 | Queda do chefe: estrondo + rachadura de chão. |
| `sfx/bs_yawn.ogg` | bsig_soft -15 | 1 | Athoth (Torpor) — bocejo: voz gigante 'a→o' descendo, com ar. |
| `sfx/bs_lullaby.ogg` | bsig_soft -15 | 1 | Athoth — canção de ninar: caixinha de música desafinada que desacelera. |
| `sfx/bs_rain.ogg` | bsig_soft -15 | 1 | Athoth — chuva de orbes: pingos de sono caindo de cima, espalhados. |
| `sfx/bs_suck.ogg` | bsig -13 | 1 | Harmas (Fome) — sucção: inspiração enorme e úmida que cresce. |
| `sfx/bs_bite.ogg` | bsig -13 | 1 | Harmas/Belias — mordida: duas dentadas pesadas e molhadas + rosnado. |
| `sfx/bs_breath.ogg` | bsig -13 | 1 | Sopro (Harmas/Yabel): rajada rugindo, grave e larga. |
| `sfx/bs_cage.ogg` | bsig -13 | 1 | Galila (Corrente) — prisão: 3 grades de ferro descendo + correntes. |
| `sfx/bs_scream.ogg` | bsig -13 | 1 | Yabel (Silêncio) — grito: guincho que sobe e CORTA seco → zumbido. |
| `sfx/bs_pages.ogg` | bsig_soft -15 | 1 | Yabel — pergaminhos: revoada de papel + sussurros. |
| `sfx/bs_wings.ogg` | bsig -13 | 1 | Yabel — asas: duas batidas grandes (corpo de pano + vento). |
| `sfx/bs_split.ogg` | bsig_soft -15 | 1 | Astaphaios (Espelho) — reflexos: acorde de vidro que se DIVIDE nos dois lados. |
| `sfx/bs_swap.ogg` | bsig_soft -15 | 1 | Astaphaios — troca: vidro ao contrário de um lado, estalo do outro. |
| `sfx/bs_spores.ogg` | bsig_soft -15 | 1 | Belias (Praga) — esporos: sopros úmidos espalhados + bolhas. |
| `sfx/bs_cloud.ogg` | bsig_soft -15 | 1 | Belias — nuvem: gás sibilando que cresce + enxame miúdo. |
| `sfx/bs_burrow.ogg` | bsig -13 | 1 | Belias — enterrar: escavar descendo (terra + grave que afunda). |
| `sfx/bs_decree.ogg` | bsig -13 | 1 | Armupiel (Coroa) — decreto: gongo + coro masculino em uníssono que proclama. |
| `sfx/bs_coronation.ogg` | bsig -13 | 1 | Armupiel — coroação: coro que sobe + sinos dourados + metal da coroa. |
| `sfx/bs_royal_cut.ogg` | bsig -13 | 1 | Armupiel — corte real: lâmina dourada pesada (shing longo) + ar cortado. |
| `sfx/bs_sweep.ogg` | bsig -13 | 1 | Armupiel — varredura: sopro LARGO e longo de um lado ao outro. |
| `sfx/bs_ray.ogg` | bsig -13 | 1 | Rei — raio: zumbido de luz roubada (serra brilhante em coro) + estouro. |
| `sfx/bs_hand.ogg` | bsig -13 | 1 | Rei — mão: mão gigante descendo (sopro grave) + pancada enorme. |
| `sfx/bs_rings.ogg` | bsig_soft -15 | 1 | Rei — anéis: os 7 tons dos Anéis girando em volta (espiral estéreo). |
| `sfx/bs_collapse.ogg` | bsig -13 | 1 | Colosso — desabamento: rochas caindo do teto em cascata. |
| `sfx/hz_tide_wake.ogg` | hazard_big -15 | 1 | Maré escura acorda: muralha de treva subindo + sussurros de olhos. |
| `sfx/hz_tide_tick.ogg` | hazard_soft -22 | 1 | Maré corroendo (tique de dano): chiado ácido curto. |
| `sfx/hz_guillotine.ogg` | hazard_big -15 | 1 | Guilhotina cai: ferro raspando no trilho (rápido) + CHOP pesado. |
| `sfx/hz_winch.ogg` | hazard_soft -22 | 1 | Guilhotina sobe: catraca de manivela. |
| `sfx/hz_maw_bite.ogg` | hazard_big -15 | 1 | Boca do chão morde: dentada de pedra molhada + rosnado da fenda. |
| `sfx/hz_maw_warn.ogg` | hazard -18 | 1 | Boca acordando (aviso): rosnado grave subindo da rachadura. |
| `sfx/hz_beam_on.ogg` | hazard -18 | 1 | Feixe do espelho acende: zumbido de vidro em laser (1,2 s). |
| `sfx/hz_beam_off.ogg` | hazard_soft -22 | 1 | Feixe apaga: vidro que esfria (tom caindo curto). |
| `sfx/hz_mirror_warn.ogg` | hazard_soft -22 | 1 | Plataforma-reflexo vai sumir: vidro tremendo (trêmulo 12 Hz). |
| `sfx/hz_mirror_flip.ogg` | hazard_soft -22 | 1 | Plataforma-reflexo troca de lado: sopro de vidro de um canal ao outro. |
| `sfx/hz_mist_breath.ogg` | hazard_soft -22 | 1 | Névoa do Torpor respira: inspira-expira lento e sonolento + caixinha abafada. |
| `sfx/hz_chain_swing.ogg` | hazard -18 | 2 | Pêndulo de corrente: rangido do elo no topo + lâmina cortando o ar. |
| `sfx/hz_bell_toll.ogg` | hazard_big -15 | 1 | Badalo do Silêncio (o sino MUDO): baque de bronze abafado, sem brilho, com o ar sendo puxado depois — o som que 'apaga' o som. |
| `sfx/hz_ether_drain.ogg` | hazard -18 | 1 | Éter arrancado: vidro sugado para baixo + crepitar azul. |
| `sfx/hz_silence_in.ogg` | hazard -18 | 1 | Entrar no campo de silêncio: o som é SUGADO (sopro crescente) e corta; sobra só um zumbido de ouvido baixinho. |
| `sfx/hz_silence_out.ogg` | hazard_soft -22 | 1 | Sair do campo: ouvido destampando (estalo grave + ar de volta). |
| `sfx/hz_sink_start.ogg` | hazard_soft -22 | 1 | Pedra adormecida afunda: ranger de pedra grave + bolhas de lodo. |
| `sfx/hz_sink_gone.ogg` | hazard_soft -22 | 1 | Pedra some no fundo: 'plof' grave e abafado. |
| `sfx/hz_sink_return.ogg` | hazard_soft -22 | 1 | Pedra volta: subida suave (pedra + caixinha). |
| `sfx/hz_spears.ogg` | hazard_big -15 | 2 | Lanças da guarda brotam: 3 'shink' de ferro em cascata + estalo de pedra. |
| `sfx/hz_shackles.ogg` | hazard_big -15 | 1 | Grilhões do chão: correntes saltando + argola que FECHA (clank). |
| `sfx/hz_spore_swell.ogg` | hazard_soft -22 | 1 | Cápsula de esporos incha: rangido orgânico úmido subindo. |
| `sfx/hz_spore_burst.ogg` | hazard -18 | 1 | Cápsula estoura: 'plop' molhado + sopro de nuvem chiando. |
| `sfx/hz_spore_pop.ogg` | hazard -18 | 1 | Cápsula destruída: estalo seco + sopro fraco. |
| `sfx/hz_shard_warn.ogg` | hazard_soft -22 | 1 | Céu rachando (sombra no chão): vidro estalando lá no alto. |
| `sfx/hz_shard_fall.ogg` | hazard_soft -22 | 1 | Caco caindo: assobio de vidro descendo (0,18 s). |
| `sfx/hz_shard_impact.ogg` | hazard -18 | 3 | Caco se espatifa no chão. |
| `sfx/hz_totem_arm.ogg` | hazard -18 | 1 | Totem profano acorda: zumbido grave em trítono acendendo. |
| `sfx/hz_totem_summon.ogg` | hazard -18 | 1 | Totem chama reforço: canto invertido + rasgo (portal escuro). |
| `sfx/hz_totem_hit.ogg` | hazard -18 | 2 | Totem atingido: pedra oca ressoando (não madeira). |
| `sfx/hz_totem_break.ogg` | hazard_big -15 | 1 | Totem desaba: pedra rachando em cascata + o mal expirando. |
| `sfx/hz_ward_drain.ogg` | hazard_soft -22 | 1 | Luz do Adormecido sendo drenada: chama tremeluzindo, chiado frio. |
| `sfx/hz_ward_out.ogg` | hazard -18 | 1 | A luz apaga: vela soprada + sino de vidro descendo e morrendo. |
| `sfx/hz_ward_saved.ogg` | reward -13 | 1 | A luz resistiu: acorde de coro em Mi maior que respira aliviado. |
| `sfx/hz_altar.ogg` | reward -13 | 1 | Altar do Santuário cura: água de luz + acorde sacro (Mi maior aberto). |
| `sfx/hz_altar_hum.ogg` | hazard_amb -28 | 1 | Coluna de luz do altar (presença, perto dele): zumbido sacro baixinho. |
| `sfx/hz_secret_mark.ogg` | hazard_soft -22 | 1 | Marca do segredo acende (pulo duplo): brilho dourado de 2 notas. |
| `sfx/hz_secret_open.ogg` | reward -13 | 1 | Sala secreta / selo abre: pedra deslizando + correntes caindo + coro. |
| `sfx/hz_column.ogg` | hazard_big -15 | 1 | Perigo de chefe golpeia (coluna/arena): estouro de energia escura vertical. |
| `sfx/hz_saw.ogg` | hazard -18 | 1 | Serra-Anel girando (perigo do chefe): zunido metálico com giro (AM 18 Hz). |
| `sfx/map_open.ogg` | ui_big -18 | 1 | Mapa abre: pergaminho desenrolando + sino grave longe. |
| `sfx/map_select.ogg` | ui_big -18 | 1 | Nó escolhido: carimbo de cera + sino em Mi (o caminho foi decidido). |
| `sfx/map_locked.ogg` | ui -22 | 1 | Nó trancado: batida surda em pedra + corrente curta. |
| `sfx/shop_seal.ogg` | shop -18 | 1 | Loja: SELO aberto — cera estalando + luz que sai (vidro subindo) + coro curto. |
| `sfx/relic_equip.ogg` | shop -18 | 1 | Relíquia equipada: metal antigo assentando + brilho de 2 notas. |
| `sfx/zone_objective.ogg` | structure -15 | 1 | Objetivo da zona: trompa grave curta + sino (chama a atenção, sem alarme). |
| `sfx/achievement.ogg` | ui_big -18 | 1 | Conquista: arpejo sacro de vidro (Mi-Sol#-Si-Mi) + sino — 'você entendeu algo'. |
| `sfx/soter_gift.ogg` | reward -13 | 1 | O Soter concede o pulo duplo: coro alto que se abre + anel de luz em espiral. |
| `sfx/crack_open.ogg` | story -15 | 1 | Roubo — a rachadura abre: pedra/vidro rasgando devagar + luz vazando (zumbido). |
| `sfx/king_sink.ogg` | story -15 | 1 | Roubo — o Rei afunda: estrondo descendo de tom + gemido de metal + coro que cai. |
