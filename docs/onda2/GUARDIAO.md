# GUARDIÃO DA SATISFAÇÃO — auditorias (branch `dir7/guardiao`)

> Lei: `docs/handoff/NEURO_SATISFACAO.md` (§2 R1–R22, §3 recompensa ética, §4 o que NÃO fazer, §5 checklist).
> Vereditos: **APROVADO** / **APROVADO COM RESSALVAS** (entra; ressalva vira pedido ao dono) / **REPROVADO** (não entra).
> Branch que muda depois de aprovado precisa de reauditoria do DELTA (o veredito vale para o commit citado).
> Sondas: `tools/guardiao/**`. Capturas e logs: `C:\gnosis-wt\_caps\guardiao\`.

## TAREFA 1 — auditoria do que JÁ está no jogo (origin/integracao/onda1 @ 0cc4aa5, 19/10)

Método: li o código integrado (worktree de sonda `C:\gnosis-wt\guardiao_sonda`), rodei sondas headless
(HitboxProbe, FeelProbe, FlashParryProbe), medi os .ogg offline (ffmpeg ebur128 + numpy, NADA tocado:
`_caps\guardiao\audio\base_meas.json`) e fiz 4 capturas mínimas 320×180 (telas 3, 22, 40, 58:
`_caps\guardiao\r18_grade.png` e `r18_grade_cinza.png`). O feel e o timing finos ainda dependem do playtest do João (§5).

| R | Estado | Evidência | Dono da correção |
|---|---|---|---|
| R1 flash + vibração no hitstop | **ATENDIDA** | `enemy.gd` `_flash()` é instantâneo (camada aditiva) e apaga em `FLASH_FADE 0,11` s reais. Vibração `VIB_LIGHT 1,5` / `VIB_HEAVY 3,0` px em relógio real. Sophia: `FLASH_TIME 0,10`, `VIB_AMP 1,5` | — |
| R2 hitstop por peso, o maior vence | **ATENDIDA** | `juice.gd:192-201`: 50/90/108 ms, +33 na morte, +17 na multidão, 25 no multi-hit, 75 no dano, 100 na queda, teto 200. `hit_stop()` estende até o maior (l. 263-269). Um por golpe (`hitbox.gd` `_flush_impact`). A entrada apertada no hitstop fica guardada | — |
| R3 tremor dedup / Perlin / chute | **PARCIAL** | Na Sophia está ok: maior pedido do quadro (`camera_shake.gd` `_frame_trauma`), Simplex 15 Hz, chute 2/4 px, leve = 0, pesado 0,30, dano 0,35. O problema são os inimigos COMUNS, que tremem a tela em golpe de rotina: pancada 0,35 (`enemy.gd:802` e `:1846`), explosão 0,45 (`:874`), agarrão 0,35 (`:2266`), fúria do Campeão 0,4 (`:2080`). A morte de chefe ainda empilha 0,8 + 0,5 + 0,9 (`boss_brain` + `_death_pose_then_burst`). §4.1 | inimigos6 (comuns: ≤ 0,15 ou só quando ACERTA a Sophia); chefes6 (morte com um ápice só) |
| R4 um acerto = um evento | **ATENDIDA** | `hitbox.gd:133-139`: um VFX por par, no ponto de contato. Som 1× por golpe, e o pesado toca NO LUGAR do leve (`:173`). Voz de dor ≤ 1 a cada 250 ms. `ImpactBurst` → `ProjectileFX`/`_claim` evita duplicar | (audio7: não pode reintroduzir a dobra) |
| R5 telegrafo glint / forma / som | **ATENDIDA** (com ressalvas) | Glint 180 ms antes (`enemy.gd:701`), redondo amarelo × losango vermelho, em Z+7/+8. Os sons `tell_parry`/`tell_unblock` existem. Tinta 45 % + pulso 2 Hz (`enemy.gd:52-54`). `_flash` volta à cor-base (bug corrigido). Ressalvas: `tell_parry` dura ~93 ms (alvo 40); o golpe aparado que ainda feria só foi corrigido no polimento7 87290ca | polimento7 (integrar 87290ca); Áudio |
| R6 faísca na chegada, em escala | **ATENDIDA** | `spark_orb.gd:102-109`: `spark` toca na CHEGADA (5 variações em sequência subindo) e o HUD conta 1 a 1 | — |
| R7 adoçante tonal do combo | **PARCIAL (quase nada feito)** | `hud.gd:312-320` só tem o pop 1,25→1,0. Não há tique de combo, nem marcos 10/25/50, nem filete de validade | Áudio (`combo_tick`) + UI |
| R8 slow-mo abafado, em rampa, racionado | **ATENDIDA** | Racionado: chefe sempre; inimigo comum só no fim da tela ou com golpe grande (`enemy.gd:1176-1183`). Rampa de 0,18 s. Passa-baixas pelo `slowmo_changed`. Detalhe: a morte de chefe (escala 0,3) cai no corte de "esquiva" (2,5 kHz) | Áudio (o Juice informa o tipo do slow-mo) |
| R9 ducking e silêncio | **PARCIAL** | Silêncio pré-chefe e duck na morte do chefe ok. Falta duck em ring_gain, ring_steal, level_clear e weapon_upgrade (−6..−8 dB) e no parry (−3 dB): `audio_manager.gd:1065` só trata boss_appear e boss_die | Áudio |
| R10 ≤ 3 flashes/s, "Reduzir flashes" | **ATENDIDA** | `Juice.flash_strength`: 333 ms, meia força, chefe 2,0, ×0,5 no modo reduzido. Opção no menu (`options_menu.gd:79`). Dano na Sophia em branco quente, não vermelho. `screen_flash` só na fase 2 e na morte de chefe, 35 % no modo reduzido. Ressalvas: a FlashParryProbe falha com `--fixed-fps` (artefato do relógio de parede); o clarão de tela usa a `eye_color` do chefe, então um chefe de olho vermelho dá clarão vermelho a α 0,6 (§4.4). Conferir | combate (sonda); VFX (clarão sem vermelho saturado) |
| R11 round-robin, vozes, limitador | **ATENDIDA** | 3 variações de hit, hit_heavy, swing, step e enemy_hurt; `MAX_SAME 3`; HardLimiter no Master | — |
| R12 grave com harmônicos | **PARCIAL** | `hit_heavy` tem 78–86 % da energia abaixo de 90 Hz e `nova` 69 %: ok. Mas o `hit` LEVE tem 42–44 % abaixo de 90 Hz em 2 das 3 variações, e a R pede leve sem sub | Áudio |
| R13 loudness | **PARCIAL / não medida** | Não gravei a mixagem de 10 min (regra de silêncio). Arquivos base com true peak acima de −1 dBTP: hit −0,7, hit_heavy −0,6, nova −0,4, swing_heavy_3 −0,5 (o limitador segura) | Áudio (gravar 10 min offline com o bot + ebur128) |
| R14 estéreo × 0,5 | **ATENDIDA** | `audio_manager.gd:62-68` | — |
| R15 fagulhas na direção do golpe | **VIOLADA** | No golpe corpo a corpo, que é o mais comum, o `hit()` de `vfx_library.gd` usa `spread 180` (360°) e o talho sai em `randf_range(-0.7,0.7)` (±40°). `impact_burst.gd:32-34` solta 7 fagulhas em 360°. O vfx7 fase 2 só corrigiu os tiros | vfx7 (API com o lado do golpe) + polimento7 (`hitbox.gd` passa o `facing`) |
| R16 números de dano | **PARCIAL** | A opção liga/desliga existe (`options_menu.gd:105`). Falta agrupar os acertos em 300 ms, o teto de 6 e o pop de entrada (`damage_number.gd:19-29`) | UI |
| R17 confirmação de morte | **PARCIAL** | O golpe que mata ganha +33 ms de hitstop. Falta o impacto 2 semitons abaixo / +2 dB e o contorno branco de 1 quadro. A morte de chefe em 4 etapas está desenhada, mas NÃO está ligada ao jogo (ver arte-gpt 4038d12) | Áudio + combate; chefes6 + arte |
| R18 legibilidade 3:1 | **PARCIAL (risco alto)** | No teste do apertar de olhos em cinza (`r18_grade_cinza.png`), as telas 40 e 58 têm fundo claro e cheio de contraste interno (raios, arcos), e a Sophia, que é clara, se mistura. Estimativa grosseira Sophia × fundo local: 1,5–2,2 : 1 (alvo ≥ 3:1; medida a 320×180, sem inimigos na tela). A Sophia não tem luz de contorno (o `painted_flex` não tem rim; os inimigos têm o `enemy_grade`) | cenario7 (fundos HD com 15–25 % menos contraste e saturação no plano de jogo) + arte (rim de 1 px na Sophia) |
| R19 smear + segurar pose | **ATENDIDA** | Smear do cajado de 110 ms (`character_art.gd` `_draw_smear`; o alvo é 60–90, um pouco longo). Não verifiquei se a pose de impacto é segurada | (arte, ajuste fino) |
| R20 squash moderado | **ATENDIDA** | `player.gd` `_squash` limita a ±7 % (x·y ≈ 1), 60 + 160 ms | — |
| R21 respiro + HUD recua | **PARCIAL** | O HUD recua a α 0,6 após 4 s (`hud.gd:55-58`). Mas entre ondas são só **0,8 s** (`level.gd:803`), e o alvo é 2–4 s | level6 |
| R22 vida baixa discreta | **ATENDIDA** | Vinheta abaixo de 25 %, 0,9 Hz, no máximo 8 s por dano (`hud.gd:60-62, 492-500`); coração em 63 Hz | — |

### §3 (recompensa ética) e §4 (excessos): economia, baús, segredos, faíscas, mapa
(um funcionário leu e citou arquivo:linha; eu conferi os pontos críticos)
- **Determinística, sem cassino.** Cada inimigo paga `spark_reward × _reward_mult` (curva por tela × dificuldade). O baú paga
  `15 + 2·tela` (`chest.gd:85-101`). Selos, Adormecido e baú saem por `tela % N` (`level.gd:540-556`). A recompensa do nó do mapa
  vem de tabela fixa e aparece ANTES da escolha (`eon_map.gd:108-114`, `world_map.gd:249-250`). RNG só existe em VFX, som e IA,
  ou com semente por tela. **Nenhum** `Time.get_date` ou `unix` ligado a recompensa, nenhuma sequência diária, e as conquistas são permanentes.
- **RISCO §3 / grind (donos level6 + mapa6).** Morrer e refazer o trecho paga DE NOVO o baú, os Selos, o Adormecido e a
  recompensa do nó, porque nada registra o que já foi coletado. Com banco baixo, morrer pode dar lucro e anular o custo da morte.
  Bug junto: `sleepers_freed` conta 2× (`sleeper.gd:43-44`), o que afeta o final "Semente" e uma conquista.
- **RISCO leve §3 (aversão à perda).** Morrer tira 20 % das faíscas não gastas (`level.gd:1009-1011`). É anunciado e
  proporcional, então é aceitável, mas só fica coerente depois de corrigir o item acima.
- **Balanceamento (progressao6).** A dificuldade multiplica a RENDA (Difícil 1,5×, Muito Difícil 2,2×) e os preços não mudam,
  então no Difícil a loja inteira cabe. Falta decidir se a dificuldade deve escalar as faíscas.
- **Misericórdia oculta** (`health_component.gd`): limiar acima de 10 % (o doc sugere acima de 30 %), 1× por zona, com flash e hitstop. Ok;
  decidir o limiar com o João.
- Até o 2º chefe (bot, PROGRESSAO6), dá para comprar ~27–45 % do que está aberto, e o selo por Arconte impede maximizar
  cedo. O item 8 do playtest ("upgrades no máximo antes do 2º chefe") está resolvido no integrado.

### §5: checklist do João, o que o código já garante × o que só o playtest diz
1 Peso leve/pesado: o código está ok (R2, R4); o `hit` leve ainda tem sub (R12).
2 Golpe "entra": ok (R1); o aparo justo só vem com o polimento7 87290ca.
3 Responsividade: buffers no hitstop ok.
4 Cansaço visual: risco nos tremores de inimigo comum (R3) e no fundo cheio (R18).
5 Parry: forma, som e 180 ms ok; falta a guarda do Astaphaios (chefes6).
6 Telegrafo coberto: o glint fica acima de tudo, ok.
7 Faíscas: ok (R6).
8 Finalização: racionada, ok (R8).
9 Ouvido: risco de repetição dos `atk_*` quando o audio7 entrar (§4.7).
10 Momento grande: o silêncio pré-chefe está ok; a morte de chefe empilha tremores (R3).
Bônus de acessibilidade: tremor 0 e "Reduzir flashes" existem, e o telegrafo continua (o glint não é cortado).
**Tudo isso precisa do playtest para ser confirmado.**

### Prioridade das correções (impacto ÷ esforço)
1. R15: fagulhas na direção do golpe (vfx7 + polimento7). É barato e é o acerto mais visto do jogo.
2. R3: tremor de inimigo comum ≤ 0,15 ou só no acerto (inimigos6), e um ápice só na morte de chefe (chefes6).
3. R18: fundo do plano de jogo com menos contraste + rim na Sophia (cenario7 + arte). É o maior risco de "não dá pra ler".
4. §3: não pagar de novo o que já foi coletado depois de morrer (level6 + mapa6), e corrigir o `sleepers_freed` contado 2×.
5. R21: 2–4 s entre ondas (level6).
6. R7 combo e R9 ducks (Áudio + UI).
7. R16 e R17 (UI, Áudio).

## Índice de vereditos (o mais novo em cima)

| Branch | Commit auditado | Veredito | R |
|---|---|---|---|
| dir6/chefes6 5b076cb + dir5/encenacao5 b415c40 | Mentira do Rei + texto do Limiar v3 | APROVADO COM RESSALVAS (enigma justo mesmo sem a pose; os 5 ajustes da amostra entraram; edições nos testes de voice_probe e gnose_qa corretas; falta a opção Dicas na UI e um "dong" próprio) | REGRAS_GUARDIAO_TEXTO §1-6, §4 |
| (texto) | AMOSTRA_LIMIAR.md (Narrativa, sem código) | APROVADO COM RESSALVAS (Mentira do Rei justa e solúvel; combate ≤6 palavras; a cena seguida da tela 2 vira legenda atrasada 10 s; 5 ajustes) | REGRAS_GUARDIAO_TEXTO §1-6 |
| (prévia) | Reescrita do texto (Narrativa) | REGRAS ESCRITAS em `C:\gnosis-wt\_caps\narrativa\REGRAS_GUARDIAO_TEXTO.md` (29 regras: ritmo, humor, gancho, enigma justo, ensinar mecânica, interrupção) | §0, §3, §4, R5, R9, R21 |
| dir6/chefes6 (+ arte-gpt 64e92cf) | 1c4b0c7 | APROVADO COM RESSALVAS (Rei HD: parada/andar estáveis, telégrafo amarelo e glint legíveis, pés pregados; 4 de 8 trocas secas já conhecidas; +190 MB de VRAM; ReiProbe só pelos números do dono) | R5, justiça, build |
| dir7/dublagem-lote | 4920893 (lote limiar-1: 11 falas PT) | APROVADO COM RESSALVAS (ética e licença ok: referência 100 % sintética, Apache-2.0; medidas dentro das REGRAS; caudas de reverb de 280-360 ms e A Voz do king_fall com CER 0,103 no limite) | REGRAS_GUARDIAO §6, §3, §4; ética |
| dir7/audio7 | b655563 (delta de 656dfc0) | APROVADO (ressalvas (a), (b) e (c) fechadas: guarda de vozes de luta, 1 aperto corta e avança, Vozes 80 %) | REGRAS_GUARDIAO §3, §9 |
| dir7/audio7 | 656dfc0 (infra de dublagem; delta próprio 08994eb, 122aea4, 656dfc0) | APROVADO COM RESSALVAS (controle e legenda cumprem as REGRAS; faltam as travas de frequência/duração de fala em combate e o 1º aperto que só corta a voz) | R4, R9, R5, REGRAS_GUARDIAO |
| (prévia) | Dublagem: regras do Guardião para a produção | REGRAS ESCRITAS em `C:\gnosis-wt\_caps\dublagem\REGRAS_GUARDIAO.md` (22 regras: controle, legenda, frequência, escada de intensidade, mixagem) | R4, R5, R9, R10, R11, R13, R21, §4 |
| dir2/arte-gpt + dir6/chefes6 | 63f597a (delta de 9ad0b06) + b587064 | APROVADO (Rei a 450 px legível sem o halo; telégrafo intacto por ser outro mecanismo; ReiProbe tela 1: atravessa=0, apelão=0, 96-99 %) | R5, R18, justiça |
| dir2/arte-gpt + dir6/chefes6 | 9ad0b06 (delta de a238686) + 6c2bd29 (delta de 0e8d761; inclui a arte) | APROVADO COM RESSALVA (Rei v11: parada 16q e andar 12q estáveis, sem borracha medida; ReiProbe atravessa=0, apelão=0, cobertura 97-98 %; a troca seca parada->preparo fica até os golpes novos) | R5, R18, justiça |
| dir2/arte-gpt | a238686 (delta de 8916611: parada r4 = a pintura s16 animada em camadas) | APROVADO (a ressalva de identidade fecha: cabelo branco com mecha azul, mesmo corpo; sem "borracha" medida; R18 volta ao nível da pintura, Coroa ~2,7 aceita) | R18, coerência |
| dir2/arte-gpt | 8916611 (delta de 118cb99; base 95ec4b3) | APROVADO COM RESSALVAS (R18 3,23-3,79 em 9 telas; reversível; o pulo de estilo parada 3D x resto pintado é REAL, pior no cabelo e na anatomia, e fica para o playtest decidir) | R18, coerência, R16 |
| dir7/polimento7 | b087740 (delta de 28d8df7; commits próprios 7652917, 0353991, b087740) | APROVADO (só RuleProbe e docs; nenhum arquivo de jogo) | R16 |
| dir6/chefes6 | 0e8d761 (delta de 213d292: um commit próprio) | APROVADO (anéis e órbita passam abaixo do HUD; é só visual, a luta não muda) | R18, R21 |
| dir6/chefes6 | 213d292 (delta de db14a1a: um commit) | APROVADO (a pegadinha da Réplica fechou; postura gira para a Sophia nas recapturas) | R5, §4 |
| dir6/chefes6 | db14a1a (delta de 61645f7: d9f4aed, 8252a50, fcf0f43, db14a1a; merges ignorados) | APROVADO COM RESSALVAS (Estouro e Jorro legíveis e justos; pústulas são contáveis e não escondem nada; a Réplica é quase inevitável na 1ª vez, porque o Juízo nasce quando a Sophia já está martelando e a defesa arma a Réplica desde o 1º quadro) | R5, §4, R21 |
| dir2/arte-gpt | 118cb99 (delta de 50f807a; base com cenario7 1b1c69f) | APROVADO COM RESSALVAS (fio de contorno funciona e a pintura se mantém; R18 3,0-3,2 em 7 de 10 telas, Coroa 2,67-2,85 e Mente 2,33 abaixo de 3:1; o cajado e as botas clareiam e perdem saturação nas telas frias) | R18, R10, §4 |
| dir6/progressao6 | 68bcaea (delta de 3d13bbd: 1 commit) | APROVADO COM RESSALVAS (as 2 ressalvas antigas FECHADAS; morte só leva o ganho da tela, edições fora da área mínimas e corretas; restam comentários velhos "−20%" e a morte agora sem custo econômico real) | §3, §4, R21 |
| dir6/chefes6 | 61645f7 (delta de 82454b2) | APROVADO (3 ressalvas fechadas; `block` 4/s no pior caso, só se reclamarem) | R5, R4, R10 |
| dir7/cenario7 | 1b1c69f (delta de ba91602) | APROVADO COM RESSALVAS (R18 1,6-2,4 -> 2,75-2,97, ainda < 3:1; Coroa diante da estátua não confirmada; halo em movimento só no playtest) | R18, R10 |
| dir6/chefes6 | 82454b2 (delta de 8d00636: 5eeea79, 04c46e0, 9bf99e2, 846314d, d439998, 82454b2) | APROVADO COM RESSALVAS (BodyBox do Sono/Espelho aceitável; guarda alta justa e sinalizada; falta aviso da forma que se refaz e o root no muro) | R5, R18, R21, SDT |
| dir7/polimento7 | 28d8df7 (delta de 0ba25d8) | APROVADO (as 2 ressalvas fecharam) | R5, R18, R4/R9 |
| dir6/progressao6 | 3d13bbd (= e78feb4 + merge ba91602; delta da base 4dad743: eea11d9, 941e8a0, b12455d, a22e1d7, 0e8fc37) | APROVADO COM RESSALVAS (curva ok; `claim_once` com chave de baú que colide e sem aviso) | §3, §4, R21 |
| dir7/mapa7 | 4e4b9cc (delta de 8e8afc3) | APROVADO (a observação do SOTER_SCREEN fixo fecha; sem mudança de som no world_map) | §3/§4, R4 |
| dir7/polimento7 | 0ba25d8 (delta de 2854fc0: 222dc38, 0ba25d8) | APROVADO COM RESSALVAS (Campeão com 1 som: ok; teto do invocador ok; o "esgotado" é discreto e ele AINDA recua andando, ao contrário do que o doc diz) | R4, R9, R18, R5/§5 |
| dir7/polimento7 | 2854fc0 (delta de 2d54867: d639053, 4305f1d, 5898825, 2854fc0) | APROVADO COM RESSALVAS (cast mudo e proj_fire hostil FECHADOS; contorno dos chefes melhora, mas o Arconte do Sono ainda tem pano de 15-27 px sem dano; Astaphaios fica mudo sem o 4574a19 do chefes6) | R4, R5/§5.5, §3, R1 |
| dir6/chefes6 | 8d00636 (delta de b0b52f0: 4574a19, 42d4804, 09b7989, 8d00636) | APROVADO COM RESSALVAS (hitbox fiel sem apelão; Raio legível; resta o Raio com halo/cauda além da área e a integração com a genérica) | R5, R18, R4, R10, R21 |
| dir7/polimento7 | 2d54867 (delta de 87290ca; 4b022a8, d5586a9, 2d54867 + merges vfx7/audio7) | APROVADO COM RESSALVAS (R3, R15, ressalva do audio7 e a do flash fechadas; cast com 3 sons; doc incompleto) | R3, R15, R4, R5, R9, §3 |
| dir2/arte-gpt | 50f807a (delta de de546f8) | APROVADO (ressalva do halo fechada; R18 segue parcial, depende do cenário) | R18, R10 |
| dir7/ui7 | 12c6643 FINAL | APROVADO | R16 atende, R18, R21, R4 (shop_buy) |
| dir7/perigos7 | 04afd65 FINAL (delta de a1c0e4c) | APROVADO | R5, R18 (≥ 3,5:1), R4 |
| dir2/arte-gpt | e3966e6 + de546f8 (delta de 2c219b4) | APROVADO COM RESSALVAS | R18 (melhora, ainda < 3:1; halo leve no cajado), R3 fechado |
| dir7/mapa7 | 8e8afc3 FINAL (delta de 26d28b3) | APROVADO | §3/§4 (nenhuma isca impossível) |
| dir7/vfx7 | a63c40b (delta de 2a5919b) | APROVADO COM RESSALVAS (ressalvas anteriores fechadas; tiro hostil "legado" ficou mudo) | R4, R10, R17 |
| dir5/encenacao5 | 0561f28 (delta de ab957ac: sons das cenas + QA7 #12) | APROVADO COM RESSALVAS | R4 (aparição do Campeão em dobro), R9 ok |
| dir6/chefes6 | b0b52f0 (delta de ed66a82: trocas de som) | APROVADO COM RESSALVAS | R4 (pancada/pouso com onda = 3 sons até a troca do proj_fire hostil), R11 ok |
| dir7/mapa7 | 26d28b3 | APROVADO | §3 (nada de cadeado que não abre), R10 |
| dir7/perigos7 | a1c0e4c (topo, sem FINAL) | APROVADO COM RESSALVAS (falta o doc com CHECAGEM) | R5, R10, R18 |
| dir6/chefes6 | ed66a82 FINAL | APROVADO COM RESSALVAS (ressalvas anteriores fechadas; resta o 0,7 da arte) | R5, R17, R3 |
| dir7/audio7 | 6df9411 FINAL | APROVADO COM RESSALVAS (REPROVADO anterior fechado; troca do proj_fire hostil tem de entrar junto) | R4 |
| dir7/vfx7 | 2a5919b | APROVADO COM RESSALVAS (R15 fechada; poça armando pisca 4,8 Hz) | R15, R5, R10 |
| dir5/encenacao5 | ab957ac (delta de 0f04eff) | APROVADO (ressalvas anteriores fechadas) | R6, §3, R21 |
| dir2/arte-gpt | e114a52 (+f30ed17/2c219b4 docs; delta de 4038d12) | APROVADO | R18 |
| dir7/polimento7 | 87290ca (delta de 661a1a0) | APROVADO COM RESSALVAS (ressalvas anteriores fechadas; nova: dono único dos 3 sons) | R5 (aparo justo), R10, R4 |
| dir7/vfx7 | 44e587d (fase 2: e99ff1d..cc9e736) | APROVADO COM RESSALVAS | R15 só nos tiros (o acerto corpo a corpo da Sophia segue em 360°) |
| dir7/perigos7 | dc8eaa7 (WIP) | APROVADO (inofensivo: só recorte/ferramenta; auditoria real quando o perigo pintado entrar no jogo) | — |
| dir7/cenario7 | 54e3717 (WIP) | APROVADO (inofensivo: ferramenta HdShot + chave `hd_disabled`) | — |
| dir7/audio7 | 634bc91 (WIP) | **REPROVADO** sozinho (entra junto das 3 trocas do player.gd ou com o observador sem os 3 eventos) | R4/§4.3 (som dobrado), §4.7 (atk_* sem teto), true peak |
| dir7/dublagem | bf0c8b3 | APROVADO COM RESSALVAS (só ferramenta; nada entra no jogo) | R13 (true peak após codificar), bus Voice, tell × voz grave |
| dir2/arte-gpt | 4038d12 (delta de 62f3ed0) | APROVADO COM RESSALVAS (inofensivo, mas a R17 NÃO chega ao jogo) | R17 não entregue; R3/R21 no dia em que ligar |
| dir6/chefes6 | 7a934d9 (WIP) | APROVADO COM RESSALVAS (só o retrato WIP; reauditar o delta final) | R5/§5.6 (guarda do Astaphaios sem aviso), R11 (som da carga repete), falta CHECAGEM |
| dir5/encenacao5 | 0f04eff | APROVADO COM RESSALVAS | R6 parcial (faíscas do degrau sem orbe), §3 (presente de arma fura o selo — antigo) |
| dir7/polimento7 | 661a1a0 | APROVADO COM RESSALVAS | R10 (flash dos inimigos ainda 0,55), falta CHECAGEM DE SATISFAÇÃO no doc |
| dir2/arte-gpt | 62f3ed0 (+60a8cf7 já integrado) | APROVADO COM RESSALVAS | R10 (flash dos inimigos após a cor real), R18 |

---

## dir2/arte-gpt — 62f3ed0 (e 60a8cf7, já integrado em a2ea6c2)

**O que muda (código):** `assets/shaders/painted_flex.gdshader` (cor do vértice em `varying`: a pintura deixa de sair
"ao quadrado", mais escura e saturada); `scripts/fx/character_art.gd` (+`stop_action()`, poses `hold` de cena,
`bless_light()` = coluna de luz aditiva do Soter); `tools/anim_qa.gd` (`soter_board`); folha/JSON da Sophia
(poses `soter_look/land/bow`). O topo atual do branch é **14277f6 (WIP: morte de chefe em 4 etapas) — NÃO auditado**,
não integrar sem nova auditoria.

**Checagem:**
- **R10 (fotossensibilidade) — ok na luz do Soter:** `bless_light` tem alfa de pico 0,26 (faixa larga) e 0,30 (miolo),
  o miolo respira 0,55↔1,0 em 0,9 s + 0,9 s = **0,56 Hz** (limite 3 Hz), área estreita (≈1,2 × altura da Sophia de
  largura), cor morna, sem vermelho. `character_art.gd` (`bless_light`, laços de 2 camadas × 10 faixas).
- **R10 — RESSALVA (efeito colateral do 60a8cf7, já integrado):** com a cor real a pintura ficou mais clara
  (luminância média do atlas da Sophia 0,39 → 0,53, medida do polimento7). A Sophia foi recalibrada no
  polimento7 (`Player.FLASH_ADD` 0,6 → 0,42), mas o flash dos INIMIGOS continua `Enemy.FLASH_ADD := 0.55`
  (`scripts/entities/enemy.gd:59`) — calibrado para a cor antiga. Pela mesma conta (×0,7), o equivalente é ≈ **0,38–0,40**.
  Sem isso, cada acerto estoura mais área do corpo do inimigo em branco (mais "clarão" por acerto, §4.4; R4: dose média).
  **Dono:** polimento7 (o pedido dele já cobre "hitbox/flash" em `enemy.gd`) — correção mínima: `FLASH_ADD` dos inimigos
  ≈ 0,40, medido no atlas das criaturas como foi feito na Sophia.
- **R18 (legibilidade) — ok/a confirmar:** a cor real aumenta a luminância dos personagens; contra os fundos escuros dos
  Éons isso tende a SUBIR o contraste. Não medi 3:1 em escala de cinza nesta rodada (fica para a auditoria geral, TAREFA 1).
- **R19/R20 (animação):** as poses de cena são paradas (`hold`), sem squash; a pose solta sozinha quando ela se mexe
  (`_tick_action`: `anim_state != "idle"` → `_action = ""`) — o jogador nunca fica preso pela arte. ok.
- **§3/§4:** nada de economia. ok.

**Veredito: APROVADO COM RESSALVAS** (62f3ed0 pode entrar; ressalva R10 vai para o polimento7). 14277f6+ = reauditar.

---

## dir7/polimento7 — 661a1a0

**O que muda:** `enemy.gd` `_fit_hurtbox_geometry()` (hurtbox = 80 % da largura × 92 % da altura do corpo DESENHADO por
quadro, `frame_geometry(true).body`, suavizado 0,5/quadro); `player.gd` `FLASH_ADD` 0,6 → 0,42 (cor real da pintura);
`tools/combate/hitbox_probe.gd` mede contra o corpo da API; docs.

**Medido (HitboxProbe no 661a1a0, worktree de sonda, headless 60 fps)** — log `C:\gnosis-wt\_caps\guardiao\hitbox_polimento7.log`:
- caixa do cajado desenhado: esperados 128, reais 134, certos 128, **atravessa 0**, **apelão 6 (4 %)**
  (base do próprio polimento7, 18/10: atravessa 1, apelão 11 — melhorou nas duas pontas).
- contra o corpo (frame_geometry): o cajado encostou 134×, sem dano em **5 (3,7 %)** — sobra um resto pequeno do
  "cajado atravessa" (playtest 2 #3), aceitável.
- contato: Sophia colada num bruto 1,5 s: vida 120 → 120 (dano de contato continua desligado).
- `QA PASS: HitboxProbe (atravessa 0 %, apelão 4 %)`.

**Checagem:**
- **§5 item 2 ("o golpe entra?") / SDT competência:** acerto mais fiel ao desenho, sem ímã — atende.
- **R1:** flash continua instantâneo, ≤ 100 ms reais (`FLASH_TIME 0.10`, `FLASH_HOLD 0.035`). Atende.
- **R10:** Sophia recalibrada (0,42, mesmo pico de luminância medido, 35 % do corpo estourado). Atende para ela.
  **RESSALVA:** o flash dos inimigos (`Enemy.FLASH_ADD := 0.55`, `enemy.gd:59`) não foi recalibrado para a cor real
  (o 60a8cf7 vale também para as criaturas). Correção mínima: medir igual no atlas das criaturas e baixar para ≈ 0,40.
- **Regra da equipe:** `docs/onda2/POLIMENTO7.md` **não tem a seção "CHECAGEM DE SATISFAÇÃO"** (obrigatória desde 18/10).
  Correção mínima: acrescentar (hurtbox → §5.2/R1; FLASH_ADD → R1/R10).
- Nada de economia, tremor, hitstop, som ou VFX novo.

**Veredito: APROVADO COM RESSALVAS** (entra; as 2 ressalvas vão para o próximo commit do polimento7).

---

## dir5/encenacao5 — 0f04eff (cena do Soter; inclui o merge de arte-gpt 62f3ed0, aprovado acima)

**Delta próprio (fbd46c8..0f04eff):** `scripts/entities/npc_encounter.gd` (poses do Soter lift/talk/offer/rest, poses de
cena da Sophia soter_look/land/bow com `stop_action()` ao fechar, `bless_light` com sprite antigo de reserva, 0,9 s de
respiro antes do prompt, `rest` + 1,6 s antes de partir) e `docs/onda2/NARRATIVA6.md` (CHECAGEM DE SATISFAÇÃO).

**Checagem (conferida contra o código, não só contra o doc):**
- **R21 (respiro):** 0,9 s sem prompt depois da fala (`npc_encounter.gd`, `create_timer(0.9, …, true)`), 1,6 s de `rest`
  antes de partir. Atende.
- **Autonomia (SDT) / sem armadilha:** o mini-desafio do degrau espera até `LEDGE_WAIT = 45 s` (l. 20) e libera se ela se
  afastar > 520 px; a pose `hold` solta assim que ela se mexe (character_art). Ninguém fica preso. Atende.
- **Ensinar fazendo (playtest #10/#11):** concede o pulo duplo, mostra o degrau aceso e pede o duplo na hora, com o
  degrau ficando para treinar. Atende (competência).
- **R10:** coluna de luz 0,56 Hz, alfa ≤ 0,3; sem clarão de tela. Atende.
- **§3:** recompensa FIXA de 30 faíscas ao pisar no degrau (l. 178), sem sorteio, sem prazo visível. Atende.
- **R6 — PARCIAL:** as 30 faíscas são creditadas de uma vez (`Progression.add_orbs(30)`) com `stele_unlock` a −4 dB, sem
  orbe voando nem o tique pentatônico na chegada. Correção mínima (opcional, não bloqueia): soltar os orbes do degrau
  pelo `SparkOrb` (mesmo caminho das mortes) para o som chegar junto da recompensa.
- **§3 — RESSALVA ANTIGA (não é deste delta):** o presente de arma do Soter faz `weapon_level += 1` direto
  (`npc_encounter.gd:~109-113`) e fura o selo por Arconte de `Progression.gift_weapon_level()` (PROGRESSAO6 §8).
  Dono: narrativa6/encenacao5 + progressao6. Correção mínima: chamar `gift_weapon_level()`.
- O doc alega "música −14 dB no encontro" (R9): não medi o áudio nesta rodada (sem som); fica como alegação.

**Veredito: APROVADO COM RESSALVAS.**

---

## dir6/chefes6 — 7a934d9 (WIP; d09566d auditado por funcionário + bf67430/5abf958/7a934d9 por mim)

**O que muda:** recalibração de vida/dano para o dano REAL da Sophia (`BossTuning.expected_hit` ← `SophiaTuning.move_damage`;
golpes-alvo: Rei 30, Sono 21, Fome 30, Corrente 38, Silêncio 28, Espelho 28, Praga 26, Coroa 26, final 16/forma, Colosso 18;
`dmg_scale` Armupiel 0,27, Colosso/final 0,30, Astaphaios 0,42, Belias 0,45, Harmas 0,55); Armupiel: corte 1×/fase,
Pretorianos com vida ≈ 4 golpes, `spark_reward` 0 e meio dano; Espadão com recuperação maior (1,25 s) e onda mais lenta;
ganchos do VFX7 (carga no preparo do tiro, cancelada em STAGGER/HURT/DEAD); golpes utilitários com `"tell": false`.

**Checagem:**
- **R3 (tremor raro) — atende/melhora:** `boss_brain.gd` strike 0,5 → 0,35; Colosso 0,8 → 0,5; `boss_hazard.gd` coluna deixa
  de tremer (só "arena" 0,35). Corte real: `AoeNova` treme 0,45, mas agora 1×/fase.
- **R5 (telegrafo) — atende nos golpes:** todo tiro tem carga (forma de círculo que fecha + cor + som) pelo `wind_up` inteiro
  (0,65–0,85 s), glint Z+7/Z+8 acima da carga (Z). Decreto do Armupiel avisa 1,15 s; `dupla_b` 0,7 s. O `_glint_done` é
  rearmado a cada `_begin_windup` (`enemy.gd:689`), então o `"tell": false` não vaza para o golpe seguinte.
- **R5 / §5.6 — RESSALVA (Astaphaios `guarda`):** a guarda REFLETE o golpe da Sophia (`_filter`: dano × REFLECT_K,
  imparável) e agora não tem nenhum aviso no preparo (0,4 s, `"tell": false`); o anel de vidro só aparece quando a guarda
  já está ativa (`_on_strike` → `_show_ring`). Uma Sophia no meio do combo (o final "compromete") toma o reflexo sem
  aviso legível. Tirar o AMARELO está certo (amarelo = aparável), mas a guarda precisa de um aviso PRÓPRIO.
  Correção mínima: mostrar o `MirrorRing` (ou um anel de vidro azul crescendo) + som "glass" já no INÍCIO do wind
  (0,4 s), não no strike. Os outros `"tell": false` (pisca, deslize, troca, teleporte, larvas, corte real, reflexos)
  não causam dano por si — ok.
- **R4/R11 — DÚVIDA (dono vfx7/audio7, não o chefes6):** sem `charge_dark` no catálogo, a carga usa "proj_fire" a pitch
  0,55/−9 dB e o disparo toca "proj_fire" de novo: o mesmo arquivo 2× por tiro de chefe. Pedido já em
  `docs/pedidos/vfx7.md`; precisa entrar antes da 3.1.
- **Dano de contato:** continua desligado (`enemy.gd` `monitoring=false`); chefe só fere no contato em investida. Atende.
- **§3:** Pretorianos e reflexos com `spark_reward` 0 (fixo). Atende.
- **Dificuldade (playtest #3/#9):** ainda FORA da meta pelo próprio CHEFES6 (r7: Armupiel 219 s/10 quase-mortes,
  final 292 s/14). Não sondei o 7a934d9 (WIP). Lembrete §4/§3: dificuldade por leitura e padrão, não por vida inflada; a
  queda de dano do Armupiel (0,4 → 0,27) vai na direção certa.
- **Regra da equipe:** `docs/onda2/CHEFES6.md` não tem a seção "CHECAGEM DE SATISFAÇÃO". Correção: acrescentar.
- Nada de hitstop > 200 ms, slow-mo novo, clarão de tela ou flash vermelho novos.

**Veredito: APROVADO COM RESSALVAS para o retrato 7a934d9** — não bloqueia a prévia se for preciso integrar o WIP, mas a
ressalva da guarda do Astaphaios (R5) deve ser corrigida antes da versão "redonda"; o commit final exige reauditoria do delta.

---

## dir2/arte-gpt — 4038d12 (delta 62f3ed0..4038d12: morte de chefe em 4 etapas)

**O que muda:** folhas `boss_<n>_<nome>_death_a.png` → estado `dying` nos 9 `*_frames.json` (tranco, cambaleio, joelhos,
tombado; `dur` 0,17/0,17/0,28, o tombado segura); `character_art.gd`: `_death_seq` prefere `dying`, `_boss_index` indexa
pelo relógio da morte (`_death_t`); `tools/anim_bosses/add_death.py`; AnimQA `death_board`; CHECAGEM (R17–R20) no ARTE_GPT.md.

**Prova vista:** `C:\gnosis-wt\_caps\arte-gpt\fila9\death_board.png` — as 4 etapas leem bem nos 9 chefes (silhueta muda
de verdade: em pé → curvado → joelhos → deitado com contorno). Como arte, atende R17 ("acabou" sem olhar a barra).

**ACHADO PRINCIPAL — a morte em 4 etapas não aparece no JOGO:** `_death_seq` só roda com `_death_t >= 0`
(`character_art.gd` `_boss_seq`, ~l. 2305), e `_death_t` só é ligado por `play_boss_death()` (l. 2503–2505). Ninguém
chama `play_boss_death()` fora das ferramentas: `git grep` em integracao/onda1, arte-gpt, chefes6, vfx7 e polimento7 → só
`tools/anim_qa.gd:523,697` e `tools/puppet_qa.gd:215`. O sinal `Enemy.boss_dying(step)` (emitido pelo
`BossBrain._death_sequence`, 0..4) não tem nenhum ouvinte. No jogo, a morte do chefe continua: cérebro (2,45 s:
`DEATH_STEPS [0.35, 0.55, 0.95, 0.6]`) → `_death_pose_then_burst` (quadro "dead" 0,4 s) → gibs. A prova é da AnimQA, que
chama `play_boss_death()` direto. → a CHECAGEM do doc ("R17 atendida") **não se confirma no jogo**.

**R8 / R21 / R3 — o que fica em risco NO DIA em que alguém ligar (`play_boss_death` no `boss_dying(0)`):**
- duas linhas do tempo competindo: a arte estilhaça em 1,08 s e encerra em 1,9 s; o cérebro segura até 2,45 s e então
  `_death_pose_then_burst` (+0,4 s) faz OUTRO fim (gibs). Resultado: dois finais ou um corpo invisível esperando 1,4 s.
- tremor empilhado em ~2,9 s: cérebro 0,8 (impacto) + arte 0,7 (joelhos, `_tick_death`) + cérebro 0,5 (colapso) +
  `_death_pose_then_burst` 0,9 (gibs). R3 pede o ápice UMA vez (morte de chefe 0,9–1,0); 4 tremores grandes seguidos
  é o §4.1. O slow-mo (0,3 × 1,0 s, só chefe) e o hitstop 0,2 s estão dentro do R8/R2.
- duração: 2,45 + 0,4 = **2,85 s reais** até os gibs, com duck de música −14 dB por 3 s (R9 ok). Aceitável para
  um chefe (evento raro), mas não pode crescer: somar 1,9 s da arte por cima passaria de ~3 s com o controle "morto".

**Correção mínima (dono: chefes6 + arte, combinar por docs/pedidos):** UM dono da linha do tempo — o `BossBrain`
chama `visual.play_boss_death(eye_color)` no passo 0 (ou o `CharacterArt` ouve `boss_dying`), alinha `DEATH_STEPS` com
os 0,34/0,62/1,08/1,9 da arte, e o `_on_died` NÃO faz o `_death_pose_then_burst` quando `visual.is_dying()` (os cacos da
arte já são o fim). Tremor: só o do impacto (≤ 0,5) e o do estilhaço (0,9); tirar o 0,7 dos joelhos ou o 0,5 do
colapso. Depois disso, reauditoria com captura em jogo (Shot `kill` num chefe).

**Veredito: APROVADO COM RESSALVAS** — o delta é inofensivo (não muda timing, tremor nem som do jogo; só dados de
quadros e o índice), então pode entrar; mas a R17 pretendida **não está entregue** até a ligação acima existir, e a
ligação precisa vir com a linha do tempo única (R3/R21).

---

## dir7/audio7 — 634bc91 (WIP: a3c2317 sons, 8803bd2 CATALOG/ganchos, bf3bcc3/634bc91 pedidos, 70044eb observador `_Watch`)

Medições offline (funcionário, ffmpeg ebur128 + numpy; NADA tocado): `C:\gnosis-wt\_caps\guardiao\audio\audio7_meas.json`,
`base_meas.json`. 143 .ogg novos (118 sons).

**Atende (com evidência):**
- **R8:** passa-baixas no slow-mo 1,5 kHz (2,5 kHz na esquiva), entra 60 ms / sai 250 ms, música −4 dB; bus Tell fora do
  filtro (`audio_manager.gd:56-70`, ~1048).
- **R9:** silêncio pré-chefe (`PRE_BOSS_FADE` 0,6 s, faixa de chefe 0,3 s depois do stinger); morte do chefe
  `duck_music(3, −14)` + −30 dB no `boss_die`.
- **R11:** `MAX_SAME 3`, limitador no Master −1 dB, round-robin sem repetir, ±1,5 dB, ±4 % tom; 3 variações em
  hit/hit_heavy/swing/step/enemy_hurt (land 2).
- **R12:** atk_slam/atk_nova com transiente 4–7 ms e 42–79 % da energia < 90 Hz; leves sem sub (atk_swing 0 % < 90 Hz).
- **R13:** música de Éon −16,0 LUFS × chefe −15,9 no arquivo; os 3 LU vêm do `EON_MUSIC_DB −3` no código.
- **R14:** pan × 0,5 em 5 degraus; sons novos de inimigo/perigo por `play_sfx_at`.
- **R6, R22, §4.8, §4.10:** tique na chegada do orbe subindo; coração 63 Hz ≤ 8 s; voz de dor ≤ 1/250 ms; impacto não
  sobe de tom com o combo.

**VIOLA (introduzido pelo branch):**
- **R4 / §4.3 — dois sons no MESMO evento:** o `_Watch` toca `double_jump` e o `player.gd:432` continua tocando `jump`
  (o próprio código diz "o `jump` do player continua"); `star_charge` + `dive` (`player.gd:542`) na Queda Estelar;
  `riposte` + `_swing_sfx` (`player.gd:628`) no contra-ataque. Nos tiros hostis, `atk_shot/fan/homing` (observador) +
  `proj_fire` (`projectile.gd:55`) = 2 sons por tiro (o próprio `docs/pedidos/audio7.md` admite "Hoje são 2 sons por tiro").
  O branch depende de TROCAS que outros donos ainda não fizeram: integrado sozinho, o jogo fica com som dobrado.
- **§4.7 — risco de repetição:** um `atk_*` em TODO golpe de TODO inimigo, só com o anti-spam de 40 ms; atk_fan, burst,
  homing, lob com 1 variação, atk_combo/rush/leap/slam/wave/dive com 2. Com 4–6 inimigos isso passa de dezenas/min.

**Parciais:** R5 `tell_parry` ~93 ms acima de −20 dB (alvo 40 ms); R9 sem ducking de −6..−8 dB em ring_gain/ring_steal/
level_clear/weapon_upgrade nem −3 dB no parry; R8 o slow-mo da morte de chefe (escala 0,3) cai no caso "esquiva" (2,5 kHz);
true peak: o funcionário mediu 7 arquivos acima de −1 dBTP (hz_spears −0,2; boss_death_impact, boss_phase3, bs_bite,
bs_hand, bs_land −0,8; bs_wings −0,9); minha contraprova do hz_spears deu −1,0 dBTP (limiar). O limitador do Master
segura o pico de amostra; vale baixar 0,5–1 dB nesses 7 na síntese (`onda7.py`) para ter folga.

**Correção mínima para virar APROVADO:**
1. Até as trocas do `player.gd` e do `projectile.gd` entrarem, o `_Watch` NÃO toca `double_jump`, `star_charge` e `riposte`
   (ou o chefe integra o audio7 JUNTO do commit do combate/polimento que faz as 3 trocas + a do `proj_fire` hostil).
   Melhor: o observador checa uma flag do player (`sfx_owned_by_watch`) antes de tocar.
2. `SPAM_OVERRIDE` 120–150 ms e `MAX_SAME_OVERRIDE` 2 para `atk_*`.
3. (não bloqueia) 3ª variação para atk_combo/rush/leap/dive e 2ª–3ª para atk_fan/burst/homing; −0,5 a −1 dB nos 7 arquivos.

**Veredito: REPROVADO no 634bc91 como entrega isolada** (R4 violada por construção). Com o item 1 resolvido (por qualquer
dos dois caminhos) e o item 2, passa a APROVADO COM RESSALVAS — reauditoria só do delta.

---

## dir7/dublagem — bf0c8b3

**O que muda:** só ferramentas/docs (`voicelib.py`, DUBLAGEM.md); nenhum `.gd` e nenhuma voz no jogo. Amostras
medidas (72, `_caps/dublagem/amostras`; medições `C:\gnosis-wt\_caps\guardiao\audio\dub_meas.json`):
loudness −21,7 / −19,0 / −17,8 LUFS (alvo −18; 36/72 mais de 1 LU abaixo), true peak máx −0,5 dBTP — **29/72 acima de −1
dBTP** (o teto de −1 dBFS é aplicado ANTES do Vorbis, `voicelib.py:224-227`, e a codificação sobe o pico), 2–5 kHz mediana
2 % (ok). Plano de ducking (DUBLAGEM §7.6: música −9 dB no diálogo, −3 dB extra com voz) atende R9.

**Ressalvas para quando a voz ENTRAR (não bloqueiam este branch):**
- **R13:** medir o true peak DEPOIS de codificar e renormalizar (loudnorm 2 passes, −18 LUFS / −1,5 dBTP).
- **bus Voice** está dentro do SFX (`audio_manager.gd:298`): pegaria o slider de efeitos e o abafado do slow-mo. Levar ao Master.
- **R5:** nada protege o `tell_unblock` (80–250 Hz) de vozes graves (Yaldabaoth/Armupiel, F0 95–138 Hz) ao mesmo tempo:
  legenda falada em luta com voz −3 dB e o bus Tell nunca abaixa.
- Sem fala repetida em combate (cada fala é única) — ok para §4.8.

**Veredito: APROVADO COM RESSALVAS** (não muda o jogo; as ressalvas são condição para a integração das vozes, versão 3.3).

---

## dir7/vfx7 — 44e587d (fase 2: e99ff1d, 58e2d3a, 994e0f1, cc9e736; base da diferença 0a77007)

**O que muda:** `enemy_overlay.gd` observa o golpe do inimigo (carga `charge_up` no wind-up de TIRO, cancelada se o golpe
morrer; rastro `melee_slash` quando a caixa corpo a corpo liga); `vfx_library.gd` (`melee_slash`, `claw_impact`,
`_spray` em cone ±50° + 20 % em 360°, contagem do teto sem montar Array); `impact_burst.gd` (acerto de inimigo na Sophia →
`claw_impact` no lugar do `hit`); `hazard_zone.gd` premium (névoa, bolhas, coluna); `projectile.gd` não redesenha com
visual premium; CHECAGEM DE SATISFAÇÃO no VFX7.md.

**Checagem (código lido):**
- **R4:** `claw_impact` SUBSTITUI o `VfxLibrary.hit` no acerto de inimigo (o `ImpactBurst` retorna antes); `_claim` evita
  o segundo `hit` no mesmo ponto. Um evento por acerto — atende. Dose do `claw_impact` (3 garras + luz + anel + 8–12
  fagulhas + fumaça) é alta, mas é dano RECEBIDO (informação, ≤ 1 por golpe inimigo) e passa pelo `flash_budget()`.
- **R5:** o rastro do golpe sai no STRIKE (depois do glint, nunca por cima do aviso); imparável ganha borda vermelha na mesma
  forma; z do rastro = inimigo + 2 (relativo), glint em Z+7/Z+8. Carga dos tiros com forma (espinhos fechando). Atende.
  Obs. de integração: os chefes já criam a própria carga no `BossBrain._start` (chefes6). A overlay só existe para inimigos com
  `moves`/Elite/Campeão (`enemy._setup_layers`), então não há carga dupla nos chefes hoje — se um chefe ganhar `moves`,
  vira carga dupla.
- **R10:** `flash_budget()` (3 cheios/s, resto 30 %, "Reduzir flashes" corta) em todo clarão novo; sem `screen_flash`; o
  brilho que corre na borda das zonas gira a 2–5 rad/s (≤ 0,8 Hz por ponto). Atende.
- **R15 — PARCIAL (RESSALVA):** o cone ±50° está no `_spray` (impactos de PROJÉTIL/ataque premium). O acerto MAIS COMUM do
  jogo, o golpe corpo a corpo da Sophia (`hitbox.gd` → `ImpactBurst.spawn` → `VfxLibrary.hit`), continua com
  `direction (0,−1)`, `spread 180` (círculo inteiro), as 7 fagulhas vetoriais do `ImpactBurst._ready` em ângulo aleatório
  em 360° e o talho do pesado em `randf_range(-0.7, 0.7)` (±40°; a R15 pede ±15° alinhado ao arco). O próprio VFX7.md
  admite que o `ImpactBurst` não recebe o lado do golpe. Correção mínima: `ImpactBurst.spawn(..., dir_x)` com o `facing`
  do dono (o `hitbox.gd` já o calcula para o `Juice.kick`) → `hit()` usa o cone do `_spray` e o talho ±15°. Donos:
  vfx7 (API) + polimento7/combate (passar o lado no `hitbox.gd`).
- **R18:** o doc mede 10,2–12,7 : 1 para os tiros novos (alvo ≥ 3:1); zonas de chão atrás dos personagens (z −1). Aceito
  como medida do dono (não refiz).
- **§4:** sem `Juice.shake` novo, sem clarão de tela, nada de economia.

**Veredito: APROVADO COM RESSALVAS** (R15 incompleta no golpe principal; a ressalva não piora nada que já existe).

---

## dir7/perigos7 — dc8eaa7 (WIP) e dir7/cenario7 — 54e3717 (WIP)

- **perigos7:** só o recorte das folhas `hz_1..hz_7` (`tools/hazards7/*.py`, PNGs, `assets/painted/hazards/hazards_data.gd`
  +4 linhas de catálogo). Nenhum perigo do jogo muda ainda.
- **cenario7:** ferramenta `tools/cenario7/HdShot` + `Scenery.hd_disabled` (static, falso por padrão; só ferramenta liga).
- Nada toca combate, VFX de jogo, som, economia ou UI → **APROVADO (inofensivo)**. A auditoria de verdade vem quando o
  perigo pintado e o fundo HD entrarem no jogo. Vou cobrar: R5 (todo perigo avisa com forma + som antes de ferir; o
  audio7 já tem `hz_*`), R18 (fundo HD 10–25 % menos saturado que os personagens, contraste ≥ 3:1 em escala de cinza),
  R10 (perigos que piscam ≤ 3 Hz) e §4.11 (cor nunca é o único aviso).

---

## dir7/polimento7 — 87290ca (reauditoria do delta 661a1a0..87290ca; f7bdd80 é merge da integração)

**O que muda:** `hitbox.gd` (`_off`: golpe encerrado deixa de ferir NA HORA, mesmo dentro do sinal de acerto; `monitoring`
desliga adiado em `_sync_monitoring`; `rearm()` para multi-hit); `enemy.gd` (`FLASH_ADD` 0,55 → 0,40 × `luma_k()` do atlas;
morte desliga caixas adiado); `enemy_flash_layer.gd` (`LUMA_K` por atlas, tabela gerada offline por
`tools/combate/flash_luma.py`, faixa 0,55–1,25); `player.gd` (sons próprios do Áudio7: `double_jump`, `star_charge`,
`riposte`, com o genérico de reserva quando o som não existe no CATALOG); `staff_reach.gd`; `validate.ps1` (+FeelProbe/HitboxProbe);
CHECAGEM DE SATISFAÇÃO no POLIMENTO7.md.

**Medido no 87290ca (worktree de sonda, headless 60 fps):** importação sem `SCRIPT ERROR`;
HitboxProbe `QA PASS (atravessa 0 %, apelão 9 %; corpo desenhado: sem dano 0.0 %, apelão 0.6 %)` — 140 esperados, 154 reais,
contra o corpo (frame_geometry) 153 encostos e **0 sem dano**, 1 dano sem encostar (0,6 %); contato 120 → 120.
Log `C:\gnosis-wt\_caps\guardiao\p7b_HitboxProbe.log`. FeelProbe `QA PASS` (aéreo 1/pulo, pulo duplo travado, 2º pulo mais baixo). FlashParryProbe: aparo, janela do contra-ataque
e contra-ataque `PASS`; o item "≤ 3 flashes cheios/s" FALHA com `--fixed-fps 60` (pico1 0,12 = pico2 0,12) mas PASSA em tempo real
(pico1 0,25 → pico2 0,12) — e a integração atual falha igual com `--fixed-fps`. É artefato da sonda: o `Juice.flash_strength`
mede o intervalo em `Time.get_ticks_msec()` (relógio de parede) e o headless com passo fixo corre mais rápido que o relógio.
No jogo a 60 fps reais o limite vale. Pedido (combate/polimento7, não bloqueia): rodar a FlashParryProbe SEM `--fixed-fps` no
`validate.ps1`, ou o `flash_strength` contar em passos como o hitstop.

**Checagem:**
- **R5 / §5.5 (aparo justo) — CORRIGE o bug mais grave do QA7:** antes, `deactivate()` dentro do sinal de acerto era
  bloqueado pelo Godot e o golpe APARADO continuava ferindo — o jogador fazia a coisa certa e era punido (o oposto de
  competência, SDT). Agora `_on_area_entered` sai cedo com `_off` (`hitbox.gd`, início de `_on_area_entered`). Atende.
- **R10:** inimigo 0,40 × fator do atlas; atlas claros (Astaphaios 0,57, Soter 0,56, Rei 0,73) deixam de estourar o corpo
  grande; escuros sobem até 1,25 para o acerto continuar visível (R1). Fecha a minha ressalva do 661a1a0. Atende.
  Obs.: a tabela é estática — atlas repintado (ex.: arte-gpt e114a52 nos Campeões) pede rodar `flash_luma.py` de novo.
- **R4 — atende no código do player, com RESSALVA de integração:** o `player.gd` agora toca o som próprio NO LUGAR do
  genérico. Mas o `dir7/audio7` (634bc91) ainda toca os mesmos 3 pelo observador `_Watch` (`audio_manager.gd` ~1811/1820/1829
  do audio7). O anti-spam de 40 ms do mesmo nome provavelmente engole a 2ª chamada no mesmo quadro, mas isso é sorte, não
  desenho, e o `riposte` do observador sai pela borda de `_riposte_t` (pode cair fora dos 40 ms). Correção mínima (dono:
  **audio7**): tirar `double_jump`, `star_charge` e `riposte` do `_Watch` — quem toca agora é o player. Com isso o meu
  item 1 do audio7 também fecha.
- **R1/R2/R3/R16/R20:** intocados (conferido no diff).
- CHECAGEM no doc: presente e confere com o código (exceto a frase "o observador do Áudio7 deixa de tocá-los", que ainda
  não é verdade no audio7 634bc91).

**Veredito: APROVADO COM RESSALVAS** — entra; a ressalva é do audio7 (tirar os 3 do observador).

---

## dir2/arte-gpt — e114a52 (+ f30ed17, 2c219b4 só bilhete; delta de 4038d12)

`despill_full` nas folhas de 2 Campeões (`champ_carcereiro_frames.png`, `champ_esporos_frames.png`: franja rosada pintada
→ ferrugem/vinho), ajustes no pipeline (`build_frames.py`, `boss_frames.py`, `mk_champ_recipes.py`, 2 receitas) e doc.
- **R18:** tira a franja rosada (cor de "chave" vazando) e mantém o brilho dos esporos (lê como esporos acesos). Melhora.
- **R17:** Campeão de vidro morre estilhaçando EM PÉ de propósito, com monte de cacos no chão — morte distinta. Ok.
- Nenhum código de jogo, som, tremor ou economia.
- Lembrete: o `LUMA_K` do polimento7 tem esses 2 atlas (0,99 e 0,93); a mudança de luminância do despill é pequena,
  mas rodar o `flash_luma.py` de novo depois da integração.

**Veredito: APROVADO.**

---

## dir5/encenacao5 — ab957ac (delta de 0f04eff; 2c20de2 é merge da integração)

**O que muda:** `npc_encounter.gd` (as 30 faíscas do degrau agora voam em 9 orbes `SparkOrb.burst` do degrau até ela; presente
de arma do Soter por `Progression.gift_weapon_level()`, com 120 faíscas EM ORBES quando a arma está selada/no máximo);
`gnosis.gd` (o mesmo card de chefe não repete na mesma tela em < 8 s); `staging.gd` (descida ao Centro ~5 s sem controle,
antes 8–10 s; Tween nunca vazio); `cinematic.gd` (quebra equilibrada, sem viúvas); lore do acólito/espectro; i18n.

**Checagem:**
- **R6 — fecha a ressalva:** crédito na hora + orbes com o tique em escala na chegada (mesmo caminho das mortes). Atende.
- **§3 — fecha a ressalva antiga:** o presente respeita o selo por Arconte (`gift_weapon_level()` devolve false se selada ou
  no máximo, `progression_manager.gd:292-297`); a troca é fixa (120). Determinístico, sem sorteio. Atende.
- **R21 — melhora:** perda de controle na descida cai de 8–10 s para ~5 s, com o peso na ilustração/câmera e não no preto.
- **Card sem repetir:** usa `Time.get_ticks_msec()` (relógio de sessão, não data real) só para não duplicar o anúncio —
  sem efeito de recompensa. Ok (§4: menos ruído).
- Nada de tremor, flash ou slow-mo novo.

**Veredito: APROVADO.**

---

## dir6/chefes6 — ed66a82 FINAL (reauditoria do delta 7a934d9..ed66a82: 7316741, 723f190, 3f620df, ed66a82; os outros são merges)

**O que muda:**
- QA7: a Sophia é desenhada na frente do chefe; o Rei fica longe da borda (margem de 110–120 px); a investida não sai do quadro;
  `BossHazard.MIN_WARN 0,45` s em toda área que fere; as formas da final voltam mais fracas a cada vez (`0,45 − 0,1·n`, mín. 0,2)
  e mais devagar (`REVIVE_AFTER + 3·n`).
- Ressalvas do Guardião:
  - a guarda do Espelho mostra o anel desde o INÍCIO do wind (`_on_windup`: `_show_ring(wind + strike)`);
  - a carga do tiro tem som próprio (`charge_dark`/`charge_king`; muda até o Áudio7 entrar, sem repetir o `proj_fire`).
- Morte desenhada ligada: o `BossBrain._death_sequence` chama `visual.play_boss_death()` e segue os marcos 0,34/0,62/1,08 s
  da arte (`_until_death_t`), espera o `death_finished`, e o `Enemy._on_died` não faz o segundo final quando `visual.is_dying()`.
- Recalibração: Rei 27 golpes, Fome 26, Rei-tutorial sem larvas até a fase 3, Armupiel com 1 Pretoriano só na fase 2.
- CHECAGEM DE SATISFAÇÃO no CHEFES6.md.

**Medido por mim (BossProbe no ed66a82, headless, vel=3, bot médio skill 0,65, vida 120; importação 0 erros;
log `C:\gnosis-wt\_caps\guardiao\c6_bossprobe.log`):**

| Tela | Chefe | Tempo | Golpes | Quase-mortes | Fases |
|---|---|---|---|---|---|
| 1 | Rei | 95 s | 23 | 1 | 2@41 s, 3@66 s |
| 46 | Astaphaios | 130 s | 30 | 2 | 2@62 s, 3@99 s |
| 68 | Rei-Mentira + Colosso | 149 s | 64 | **5** | 2@49 s, 3@63 s |

Os tempos ficam dentro de 1,5–2,5 min e da variação de ±25 % que o próprio doc declara. Na final eu medi 5 quase-mortes (o doc diz 3);
é a última luta e o bot tem vida fixa de 120, então não reprova. Fica para o playtest.

**Checagem:**
- **R5, fecha a ressalva:** a guarda que reflete avisa com anel de vidro + som desde o início dos 0,4 s de preparo. Nenhuma área
  fere com menos de 0,45 s de contorno (QA7 #20). "Amarelo" agora só aparece em golpe que dá para aparar.
- **R4/R11, fecha a ressalva:** a carga e o disparo deixam de ser o mesmo arquivo.
- **R17, fecha o achado do arte-gpt 4038d12:** a morte em 4 etapas desenhada agora APARECE no jogo, e há um só final
  (sem gibs depois do estilhaço).
- **R3: quase fechado.** Do lado do cérebro sobra um tremor grande no golpe final (0,8) e micro-tremores de 0,15.
  **Resta** o `Juice.shake(0.7)` da ARTE em 0,34 s (`character_art.gd` `_tick_death`, "cai de joelhos"): são dois grandes em
  ~0,34 s. Com o decaimento de 1,4/s ele lê quase como um tremor longo, mas o ápice deveria ser um só. O próprio CHEFES6 já
  aponta isso como pedido à arte. Correção mínima (dono: **arte-gpt**): 0,7 → 0,15 (micro), ou nada.
- **R8:** slow-mo 0,3× por 0,8 s, só na morte do chefe. Atende.
- **R9:** fase −8 dB por 0,8 s; morte −14 dB por 3 s. Atende.
- **R21:** a final converge (as formas voltam mais fracas e mais devagar). É regra visível, não um quase-acerto fabricado (§3). Atende.
  As lutas ficam em 1,5–2,5 min (antes chegavam a 420 s com TIMEOUT).
- **R18:** a Sophia na frente do manto do Rei e o Rei longe da borda (QA7 #3). Atende.
- **§3:** sorteio de golpes semeado por tela, entre golpes legíveis, sem repetir 3×. Pretorianos e reflexos com 0 faíscas. Atende.
- A CHECAGEM do doc confere com o código.

**Veredito: APROVADO COM RESSALVAS.** Entra na 3.1. A única ressalva é do arte-gpt (o tremor de 0,7 na queda), que não bloqueia.

---

## dir7/audio7 — 6df9411 FINAL (reauditoria do delta 634bc91..6df9411: 801f46e + 6df9411)

**O que muda:**
- `audio_manager.gd`: o `_Watch` deixa de tocar `double_jump`, `star_charge` e `riposte`. Fica só `star_impact`, como camada sob a `nova`.
- `atk_*` passa a ter anti-spam de 130 ms e no máximo 2 vozes (`ENEMY_ATK_SPAM_MS`, `ENEMY_ATK_MAX_SAME`, `max_same_for()`).
- Síntese refeita com pico verdadeiro ≤ −1 dBTP (`onda7.py`, `build_sfx.py`) e verificação offline nova (`tools/audio/onda7_check.py`).
- `AUDIO7.md` com a tabela "quem liga cada som" e a CHECAGEM DE SATISFAÇÃO.

**Contraprova (ffmpeg ebur128, offline, nada tocado):** hz_spears −1,0 · boss_death_impact −1,0 · boss_phase3 −1,3 ·
bs_land −1,1 · bs_wings −1,0 dBTP. Antes iam até −0,2. Atende o teto de −1 dBTP.

**Checagem:**
- **R4: fecha o REPROVADO do 634bc91.** Os 3 eventos dobrados saíram do observador. O polimento7 87290ca toca o som
  próprio na fonte (troca, não soma). O `star_impact` é camada desenhada sob a `nova` (sem baque próprio), e isso a R4 permite.
- **§4.7 / R11: atende.** `atk_*` com 130 ms e 2 vozes evita a "metralha" num grupo de 5–6 inimigos.
- **R13: parcial, e honesto.** Os arquivos estão no alvo, mas a mixagem de 10 min não foi gravada (driver Dummy). Mesma pendência da TAREFA 1.
- **RESSALVA (R4, de integração):** o tiro hostil ainda soa DUAS vezes no mesmo instante assim que o audio7 entrar. O observador
  toca `atk_shot`/`atk_fan`/`atk_homing` no STRIKE, e o `projectile.gd:55` continua com `Audio.play_sfx("proj_fire")` para
  todo projétil, tanto no integrado quanto no polimento7. O pedido existe (`docs/pedidos/audio7.md:46`), mas ninguém fez a troca.
  Correção mínima: 1 linha no `projectile.gd` (`if team == "player": Audio.play_sfx("proj_fire")`), do dono do
  projétil (polimento7/inimigos), integrada JUNTO com o audio7.

**Veredito: APROVADO COM RESSALVAS.** Entra. A troca do `proj_fire` hostil precisa entrar na mesma integração; sem ela, os tiros
inimigos ficam com som dobrado.

---

## dir7/vfx7 — 2a5919b (reauditoria do delta 44e587d..2a5919b: 9d9d353, 5bd7ecd, 2a5919b; 92d8d34 é merge)

**O que muda:**
- **R15:** `ImpactBurst.spawn(..., dir)`, `VfxLibrary.hit(..., dir)` e `claw_impact(..., dir)`. Sem `dir`, a direção é deduzida pela
  posição da Sophia (`_guess_dir`). O resultado é um cone de ±50° no sentido do golpe, 20 % das fagulhas soltas em 360° e o talho
  do pesado alinhado em ±15°. Das 7 fagulhas vetoriais, 6 saem no cone.
- QA7: as poças hostis ARMAM por 0,5 s antes de ferir (#8); a aparição do fantasma/reflexo tem 0,6 s de wind, marca
  (anel + fumaça) e o som do telegrafo (#9); a repulsa vale até 90 px (#15); a coleira `EnemyAggro.leash_x` está pronta
  (#10, falta a chamada no `enemy.gd`).
- A carga fica muda sem o nome no CATALOG (antes caía num `proj_fire` grave, som dobrado).
- Desempenho medido pelo dono: 8,3 → 4,2 ms.

**Checagem:**
- **R15, fecha a ressalva:** o acerto mais comum agora sai no sentido do golpe (`vfx_library.gd` `hit`: `direction = dir + (0,−0,25)`,
  `spread 50`; talho em `dir.angle() ± 0,26`). Atende.
- **R5:** a aparição pelas costas passa de 0,25 s para 0,6 s, com marca e som. A poça não fere no quadro em que nasce. Atende,
  e isso é justiça pura (§5.6).
- **R4/R11:** a carga não dobra o som do disparo. Atende.
- **R10 / R5, RESSALVA pequena:** enquanto a poça arma, a borda pulsa a `sin(_t * 30)` = **4,8 Hz** por 0,5 s
  (`hazard_zone.gd`, `if arming: pulse = 0.5 + sin(_t * 30.0) * 0.5`). A área é pequena e dura pouco, então não fere a
  WCAG. Mas a R5/R10 pede pulso de aviso ≤ 3 Hz (o telegrafo usa 2 Hz) e o §4.4 diz "nunca acima de 3 Hz". Correção mínima:
  `sin(_t * 18.0)` (≈ 2,9 Hz), ou crescer sem piscar.
- **R21 / justiça:** a coleira impede que atirador e voador fujam para a borda. Bom, mas só vale quando o `enemy.gd` chamar
  (pedido ao polimento7).

**Veredito: APROVADO COM RESSALVAS** (só o pulso de 4,8 Hz da poça armando).

---

## dir7/mapa7 — 26d28b3 (6ccf9c3, 5d02ed9, 1d8973f, 26d28b3)

**O que muda:**
- O segredo de ANTES do Soter (e0.6a, e1.3a) vira o tipo `hidden`, a **câmara oculta**: não pede pulo duplo, alcança-se com pulos
  simples por torres, tem um perigo opcional no chão e paga o MESMO prêmio da sala secreta (`EonMap.REWARDS.hidden = secret`).
- As salas `secret` (pulo duplo) só existem depois da tela 17 (1º Soter) e abrem no mesmo run.
- No `world_map.gd`, o selo (asas + cadeado) diz "precisa de asas" / "aberta". Enquanto está fechado, a recompensa aparece como
  "escondida" e o texto diz por quê e quando. Há um aviso único, "as salas secretas se abrem", com halo de 4 s.
- MapQA 28 e LayoutQA verdes; i18n `--strict`.

**Checagem (código lido):**
- **§3 / §4.12:** prêmio fixo por tipo (`hidden` = `{"orbs": 20, "per_eon": 6, "hp": 8, "mp": 8}`), mostrado antes da escolha.
  Sem sorteio. Atende.
- **§3, aversão à perda, resolvida de verdade:** o "ponto honesto" do próprio MAPA7.md (e0.6a e e1.3a nunca abriam em nenhum
  run, ou seja, um cadeado que não abre) foi corrigido em 26d28b3. Antes do Soter não existe mais sala trancada; depois dele, ela
  abre no mesmo run. Nada de FOMO nem de "volte amanhã". Atende.
- **Autonomia (SDT):** o mapa mostra o mundo inteiro, e o fechado explica o motivo. O aviso "abriu" sai 1× por run e é ligado
  à história (o Soter), não à sorte (princípio 4). Atende.
- **R10:** o halo pulsa a ~0,6 Hz por 4 s, numa área pequena, sem clarão. Atende.
- **§4.11:** forma (asas, chave, cadeado) + texto além da cor lilás/azul. Atende.
- **R18 / R5 na câmara oculta:** torres de pulo simples e perigo opcional; nada obrigatório. Ok (o perigo segue as regras de
  aviso do perigos7).
- O MAPA7.md tem a CHECAGEM. O parágrafo "Ponto honesto" ficou desatualizado depois do 26d28b3; vale atualizar (não bloqueia).

**Veredito: APROVADO.**

---

## dir7/perigos7 — a1c0e4c (topo atual; 01b2705, 709a517, dc8eaa7 + merge do audio7 6df9411 em 9873c70). Ainda sem "FINAL".

**O que muda:**
- `scripts/fx/hazard_art.gd` (novo): desenho pintado de 15 perigos a partir das folhas `hz_1..hz_7`.
- `level_hazard.gd` `warn_outline()`: borda ESCURA por fora e VERMELHA por dentro, pulsando a `WARN_HZ 2,0`.
- Os 15 perigos usam a arte e ligam os sons `hz_*` do audio7 na fonte (aviso e golpe). A porta do selo toca ao abrir.
- Prancha antes/depois em `C:\gnosis-wt\_caps\perigos7\prancha_*.png` (vi a das lanças: no aviso, a grade fica com contorno
  vermelho e borda escura e lê bem no fundo violeta).

**Checagem:**
- **R5 (aviso antes de ferir):** as janelas de aviso dos perigos cíclicos são guilhotina 0,7 s (`WARN_AT 1,9 → DROP_AT 2,6`), boca 0,8 s,
  lanças 0,6 s, esporos 0,8 s, feixe do espelho 0,5 s, plataforma-espelho 0,6 s e cacos 0,8 s. Todas ≥ 0,45 s (o mesmo mínimo
  dos chefes). Cada uma tem FORMA (contorno da peça), cor e som de aviso (`hz_*_warn`). Atende.
- **R10:** o pulso do aviso é de 2 Hz (`HazardArt.pulse`); o aviso é informação e não cai com "Reduzir flashes", como pede a R10 para
  o glint. A "tremedeira" da boca e das correntes é a PEÇA vibrando 1 px (`sin(_t*50)`), não a câmera nem um flash. Atende.
- **R18 / §4.11:** borda escura + borda vermelha lê em fundo claro (Coroa, Pleroma) e escuro (Silêncio, Torpor), conforme o
  QA7 #25. Não medi 3:1 por perigo. A prancha das lanças lê bem.
- **R3:** nenhum `Juice.shake` novo nos perigos. Atende.
- **R4:** o som do perigo é ligado NA FONTE e o observador do audio7 cuida só dos perigos que eram mudos. Ver na integração se
  algum perigo ficou tocando pelos dois caminhos: o `docs/pedidos/audio7.md` lista as trocas `dark_tide` e `guillotine`.
- **Regra da equipe:** não há `docs/onda2/PERIGOS7.md` com CHECAGEM DE SATISFAÇÃO no branch. Correção: escrever antes do FINAL.

**Veredito: APROVADO COM RESSALVAS** (falta só o doc/CHECAGEM). Quando sair o FINAL, reaudito só o delta.

---

## dir6/chefes6 — b0b52f0 (delta ed66a82..b0b52f0: 9fae4af = merge do audio7 6df9411, já aprovado; commit próprio b0b52f0)

**O que muda (b0b52f0):**
- `enemy.gd` `_enter_phase`: `boss_phase3` NO LUGAR de `boss_phase2` na fase 3 (troca, não soma).
- `boss_hazard.gd`: `hz_saw` 1× por serra (`_saw_sfx`); `hz_column` no golpe da coluna, exceto quando quem criou já soa
  (`strike_sound = false` no pouso do salto, que já toca `bs_land` pelo observador).
- `boss_brain.gd` `ground_wave()`: `atk_wave` com guarda de 120 ms (duas ondas do mesmo golpe = 1 som).

**Checagem (R4 e R11):**
- **Fase 3, coluna e serra: atende R4.** São trocas na fonte e nada mais toca nesses eventos. O observador não trata `BossHazard`, e o
  Decreto do Armupiel tem `strike: ""` na `BOSS_MOVE_SFX`, então a coluna dele soa uma vez só.
- **Pouso do salto: atende.** `bs_land` (observador) e a coluna-sombra muda.
- **R11: atende.** `atk_wave` herda o anti-spam de 130 ms e as 2 vozes do prefixo `atk_` do audio7. A guarda de 120 ms do cérebro
  é redundante, mas inofensiva. `atk_wave` tem 2 variações (ideal 3, não bloqueia).
- **R4, RESSALVA (pancada `slam` com `waves` e pouso de salto com ondas):** no MESMO quadro tocam o som do golpe
  (`bs_royal_cut`/`atk_slam` no strike, ou `bs_land` no pouso, pelo observador), o `atk_wave` (novo) e o `proj_fire` de cada
  onda, porque a onda rasteira é um `Projectile` (`projectile.gd:55` toca `proj_fire` em todo projétil). Hoje são **3 sons**.
  Com a troca já pendente do `proj_fire` hostil (só o tiro da Sophia toca), caem para 2: golpe + onda, que é aceitável como
  camada (a onda é um objeto visível que parte do impacto). Correção mínima:
  (1) a troca do `projectile.gd` (dono polimento7/inimigos), que já é condição do audio7;
  (2) opcional, `atk_wave` a −3 dB (`sfx(..., -3)`) para soar como camada sob o golpe, não como segundo impacto.
- AoeNova com dano 0 continua mudo (`aoe_nova.gd:29`). Ok.

**Veredito: APROVADO COM RESSALVAS** (a ressalva depende da mesma linha do `projectile.gd` que já trava o audio7).

---

## dir5/encenacao5 — 0561f28 (delta ab957ac..0561f28: commit próprio 0561f28; 7d7fb98 e 80617fb são merges do audio7 6df9411 e da integração)

**O que muda:**
- `staging.gd` (roubo): a fenda abre em `Audio.CRACK_DELAY`, junto com o `crack_open` do cue `sink`; cada pulso do tremor
  leva `boss_step` a −6 dB.
- `npc_encounter.gd` (Soter): `Audio.duck_music(600, −24)` na fala da leveza, e o `soter_gift` entra no silêncio.
- `level.gd` (QA7 #12): o Campeão nasce no chão, 150 px à frente da Sophia, dentro da zona e do quadro
  (`_champion_x`). O card sai só quando ele está visível (≥ 0,6 s, teto de 2 s; `_champion_card_when_visible`).
  ChampionProbe 0 falhas.
- NARRATIVA6.md atualizado.

**Checagem (código lido; nada tocado):**
- **R9: atende.** Antes do grande momento vem o vazio: a música para e a fenda abre COM o `crack_open` (princípio 1 de sincronia:
  imagem e som no mesmo evento). No Soter, −24 dB sob o dom. A soltura vem do `Staging._on_finished` (`duck_music(0, 0)` quando
  `_ducked`), e a cena do Soter liga `_ducked` (`staging.gd:377`). Como o envelope é um só, a soltura sobrescreve o −24.
  Conferido por leitura, não no jogo.
- **R4 no roubo: atende.** O `boss_step` a −6 dB acompanha o tremor como camada. É 1× por run, então não cansa (§4.7).
- **R5 / R18 no Campeão: atende.** Nascer dentro do quadro e à frente acaba com o "golpe de fora da tela"; o card só sai com ele visível.
  O ataque dele segue o telegrafo de sempre (glint + wind-up).
- **R4, RESSALVA (aparição do Campeão em dobro):** o `Enemy._ready` já chama `_boss_intro_fx` (deferred) para todo
  `is_boss_enemy or is_champion` (`enemy.gd:322-334`: `boss_appear` + `VfxLibrary.boss_appear` na posição dele). O novo
  `_champion_card_when_visible` chama de novo `VfxLibrary.boss_appear(self, champ.global_position + (0,−20))`. São DUAS colunas
  de luz no mesmo ponto e no mesmo quadro. Correção mínima: tirar a chamada do `level.gd`, porque o Enemy já faz a aparição.
- **Lembrete fora deste delta (dono polimento7/inimigos, pedido do audio7):** o `_boss_intro_fx` toca o stinger `boss_appear` também
  para o Campeão. O audio7 pediu `champion_enter` para ele, porque o stinger de chefe é o que solta a música de chefe (R9).

**Veredito: APROVADO COM RESSALVAS.** Entra no pacote de som; a ressalva é 1 linha no `level.gd`.

---

## dir7/vfx7 — a63c40b (delta 2a5919b..a63c40b: commit próprio a63c40b; o resto é o merge do audio7 6df9411, já aprovado)

**O que muda:**
- `projectile.gd`: `proj_fire` só quando `target_team == "enemy"` (tiro da Sophia).
- `hazard_zone.gd`: a poça armando pulsa com `sin(_t * 18)`, ≈ 2,9 Hz.
- `vfx_library.gd`: `kill_confirm()` (estrela branca em X, anel fino e risco vertical de luz, ~120 ms, dentro do `flash_budget`),
  chamado no `enemy_death` de inimigo comum.

**Checagem:**
- **R4: fecha a ressalva do audio7 e do chefes6 b0b52f0.** O tiro hostil soa só pelo `atk_*` do observador e a onda rasteira
  (Projectile) só pelo `atk_wave`. Pancada e pouso com ondas caem de 3 sons para 2 (golpe + onda), o que é aceitável como camada.
- **R10: fecha a ressalva.** Poça a 2,9 Hz (≤ 3).
- **R17: parcial → quase atende.** O golpe que mata o inimigo comum ganha uma forma própria (estrela em X ≠ fagulha redonda do
  acerto), curta e no orçamento de flashes. Ainda falta a parte do SOM (impacto 2 semitons abaixo / +2 dB, dono Áudio + combate).
- **R4/R5, RESSALVA NOVA (tiro hostil que ficou MUDO):** o observador do audio7 só toca o golpe quando o inimigo tem `_mv`
  (repertório do EnemyMoves; `audio_manager.gd:1780`). Atiram com `_mv` vazio, e agora sem nenhum som no disparo:
  - o caminho antigo `attack_style "ranged"` (`enemy.gd:733` `_begin_strike`, projéteis em `:762`). Pega os ECOS dos Arcontes
    de estilo "ranged" (eco do Athoth, do Yabel e do Rei, `bestiary.gd:370/379/395`), que entram nas ondas finais
    (`run_manager.gd:351-352`). Os tipos comuns têm todos repertório próprio;
  - o voleio que quica do Astaphaios (`boss_astaphaios.gd:153`, `_bounce_volley`), que sai 0,9 s depois do golpe;
  - os restos de kit em `enemy.gd:826/856` (`_kit_strike`/`_ground_wave`), se algum chefe ainda passar por eles.
  O aviso (glint + `tell_*`) continua; o que falta é o som do DISPARO, que localiza a ameaça fora da tela (R14).
  Correção mínima (dono inimigos/polimento7 no `enemy.gd`; chefes6 no Astaphaios): nesses pontos, tocar
  `Audio.play_sfx_at("atk_shot", pos)` 1× por salva (ou `move_sfx({"kind": "shot"}, "strike", pos)`).

**Veredito: APROVADO COM RESSALVAS.** O pacote de som pode fechar; a ressalva é som que FALTA (não som dobrado) em inimigos de
fim de jogo.

---

## dir7/mapa7 — 8e8afc3 FINAL (delta 26d28b3..8e8afc3: 0e9ff0c, 932ae93, 8e8afc3)

**O que muda:** `screen_layouts.gd` `_high_cache(screen)`: antes da tela 17 (1º Soter) o baú alto é uma TORRE de pulo simples
(`tower_cache`); a saliência de pulo duplo (`dj_cache`, com setas no chão) só aparece a partir da 17. `map_qa.gd` confere
isso. MAPA7.md com a decisão final e a CHECAGEM atualizada (o "ponto honesto" foi resolvido).

**Checagem:**
- **§3/§4 (nada de isca impossível, nenhum "quase" fabricado):** antes do pulo duplo o jogador não vê mais um prêmio que não
  alcança, e todo baú visível é alcançável com o que ele tem. Atende. É o mesmo princípio da câmara oculta do 26d28b3.
- Prêmio e posição são determinísticos (sem sorteio). Atende.
- **Observação (não bloqueia):** a regra usa o NÚMERO da tela (`SOTER_SCREEN := 17`), não o fato de ter o pulo duplo. Se um dia
  o Soter mudar de tela, ou o mapa permitir chegar na 17+ sem o encontro, volta a existir saliência inalcançável. Mais robusto:
  `RunManager.has_double_jump()` na hora de montar a tela (o layout é por tela; se precisar ser estático, ao menos uma
  checagem no MapQA de que todo caminho até a 17 passa pelo Soter).

**Veredito: APROVADO.**

---

## dir2/arte-gpt — e3966e6 + de546f8 (delta depois de 2c219b4; 380a5c1 é merge da integração)

**O que muda:**
- `painted_flex.gdshader`: `rim_amt` acende a borda POR DENTRO, só onde a pintura é escura (botas, calça, cabelo na sombra), e
  `halo_amt` põe um halo de ~1 px POR FORA, mais forte junto das partes escuras. A cor é a do Éon misturada a 35 % com branco quente.
- `character_art.gd`: só na Sophia (`HERO_RIM 0,6`, `HERO_HALO 0,4`, `rim_px 1,6`); tremor da queda na morte desenhada
  0,7 → 0,15.
- `belias.json`: `foot_gap 0` (pés no chão).
- Sondas `ContrastProbe` / `FeetProbe` / `contrast_r18.py` e pedido ao cenario7.

**Prova vista:** `C:\gnosis-wt\_caps\arte-gpt\r18\r18_antes_depois.png` (Torpor 3, Corrente 30, Praga 57) e o meu recorte ampliado
2× das pernas/botas: `C:\gnosis-wt\_caps\guardiao\r18_arte_zoom.png`.

**O rim "lava" a pintura? NÃO.** O miolo da pintura fica igual: o manto branco e o turquesa não mudam, porque a luz de recorte só entra nas
bordas ESCURAS (fator `dark`). O que se nota é o HALO de fora:
- ele cria um filete claro e translúcido em volta das botas e, principalmente, ao longo do CAJADO, uma faixa pálida vertical de
  ~3–4 px dos dois lados da haste. Em Torpor e Corrente, ampliado, ela lê como um "fantasma" e não como luz da cena;
- no tamanho do jogo é sutil, mas o cajado é fino e está sempre em movimento, então o halo dele vai chamar atenção
  em golpe e smear.
- **Ponto:** o rim está bom. O halo está no limite: baixar `HERO_HALO` 0,4 → ~0,25, ou não aplicar halo em partes finas
  (ex.: pular texels cuja vizinhança tem `mx` alto só num eixo), resolve sem perder a separação nas botas.

**Checagem:**
- **R18: melhora, mas continua PARCIAL.** O dono mediu 1,4–2,0 → 1,7–2,4 : 1, ainda abaixo de 3:1. O resto tem de vir do FUNDO
  (pedido ao cenario7: plano de jogo com 15–25 % menos contraste e saturação), como já está no despacho da TAREFA 1. Correto não
  forçar mais luz na Sophia: rim forte vira "recorte de adesivo" e briga com a pintura.
- **R3: fecha a ressalva do chefes6.** A morte de chefe agora tem UM tremor grande (0,8 no golpe final) + micro de 0,15.
- **R10:** o rim/halo é estático (não pisca). Atende.
- **Pés do Belias:** sem fresta entre pé e chão. Favorece o R18 (contato com o chão = leitura de peso). Ok.

**Veredito: APROVADO COM RESSALVAS** (halo 0,4 → ~0,25 ou sem halo no cajado; o R18 fecha só com o cenário).

---

## dir7/ui7 — 12c6643 FINAL (f913fc8, fdb785e, 8b5cf25, 0daadb7, 12c6643; o resto é o merge do audio7)

**O que muda (UI de jogo):**
- `damage_number.gd` (R16): soma acertos no MESMO alvo em ≤ 0,3 s (mesma cor, ≤ 36 px), no máximo 6 vivos (some o mais velho),
  pop 1,35 → 1,0 em 80 ms com ease-out-back no relógio real (o hitstop não estica), e pop de 1,22 a cada soma.
- `hud.gd`: HUD na CanvasLayer 20, acima do mundo, da vinheta do cenário (1) e do clarão (5); Pausa/Loja em 45. Ganha uma
  sombra de leitura macia atrás do medalhão e das barras (α 0,32, ou 0,5 com chefe) e uma faixa escura atrás do nome/título do
  chefe (QA7 #17/#23). "Siga em frente" sai do CENTRO e vira seta com chevrons na borda direita por 3,2 s (QA7 #30).
- `dialogue_box.gd`: a caixa fecha sozinha se a cena trocar (QA7 #14).
- `upgrade_menu.gd`: relíquia sem `shop_buy` por cima do `relic_equip`.
- Traduções (QA7 #6/#16 e outros).

**Checagem:**
- **R16: ATENDE agora** (era PARCIAL na TAREFA 1): agrupar, teto, pop e opção liga/desliga (já existia).
- **R18:** a sombra de leitura e a faixa do card separam o HUD do mundo sem caixa dura. Atende.
- **R21:** tirar o "Siga em frente" do centro desafoga o meio da tela (legenda, dica e convite já estavam lá). Atende. Os chevrons
  correm a ~1,6 ciclos/s, numa área pequena, ≤ 3 Hz (R10).
- **R22:** a vinheta de vida baixa continua no próprio HUD (agora acima do clarão). Sem mudança no ritmo. Atende.
- **R4:** relíquia = 1 som (`relic_equip`). Atende.
- **Justiça/UX:** caixa de diálogo órfã tapando botões (QA7 #14) resolvida.
- Nada de economia mudou (só o som da compra), nada de tremor nem flash novo.

**Veredito: APROVADO.**

---

## dir7/perigos7 — 04afd65 FINAL (delta a1c0e4c..04afd65: a0cf7e1, 04afd65)

**O que muda:** `level_hazard.gd`: um terceiro fio CLARO e quente (`WARN_HOT`) no meio da borda de aviso (escuro, vermelho, claro),
para ler em fundo de luminância média, onde nem o escuro nem o vermelho passam de 3:1. `tools/hazards7/contrast.py` mede.
`PERIGOS7.md` com a CHECAGEM DE SATISFAÇÃO. uid do HazardArt.

**Checagem:**
- **R18: atende.** O dono mediu ≥ 3,51:1 em todos os fundos (é o primeiro elemento do jogo com 3:1 medido). Não refiz a medida.
- **R5:** forma + cor + som, aviso ≥ 0,45 s (tempos inalterados), a frente visível da maré coincide com o dano. Atende.
- **R4/R11 (som dobrado):** conferido no código. A fonte toca `hz_guillotine` (queda) e `hz_tide_wake` (maré acorda); o observador
  do audio7 só toca `hz_winch` (lâmina subindo) e `hz_tide_tick` (`audio_manager.gd:1919/1924`). São eventos diferentes, nada dobra. Atende.
- **Atenção leve (§4.9, não bloqueia):** o `hz_tide_tick` repete a cada ≥ 300 ms enquanto a Sophia está sendo corroída (1 voz). É
  informação (dano contínuo), mas um tique contínuo é o tipo de som que irrita. Se o playtest reclamar, espaçar para ~600 ms ou
  baixar 3 dB.
- **R10:** pulso de 2 Hz; o feixe deixou de piscar a ~6 Hz; decorativo × 0,5 com "Reduzir flashes", e o aviso não reduz. Atende.
- A CHECAGEM do doc confere com o código.

**Veredito: APROVADO.**

---

## dir7/polimento7 — 2d54867 (delta de 87290ca: d5586a9, 4b022a8, 2d54867; 46d525c/2a7cf2c são merges de vfx7/audio7)

**Medido no 2d54867 (worktree de sonda, headless, `--audio-driver Dummy`):** importação sem `SCRIPT ERROR`;
FeelProbe `QA PASS` com `tremor leve=0.00 pesado=0.30 inimigo_comum=0.12 sophia_ferida=0.35`; HitboxProbe `QA PASS (atravessa 0 %,
apelão 8 %; corpo desenhado: sem dano 0.0 %, apelão 0.6 %)`; FlashParryProbe (SEM `--fixed-fps`) todos `PASS`, inclusive
"<= 3 flashes cheios por segundo", "o contra-ataque acerta quem foi aparado" e "chefe não se parte na hora". Logs em
`C:\gnosis-wt\_caps\guardiao\p7c_*.log`.

**O que muda (código próprio):**
- `enemy.gd`: `_shake_routine` limita o tremor de golpe de rotina de inimigo COMUM a 0,12 (chefe segue); coleira
  (`EnemyAggro.leash_x`/`retreat_dir`) em atirador e voador; atirador colado esquece a intenção de longe; aviso da fúria nunca
  abaixo de ~0,42 s; arte própria sem tinta/graduação; `champion_enter` no lugar de `boss_appear` para Campeão;
  `atk_shot` (1 por salva) nos tiros legados e no kit (corrente, colosso, coroa/rei fase 2); renda de faíscas igual em
  todas as dificuldades (`_reward_mult` só pela tela).
- `hitbox.gd`: direção do golpe (quem bate -> quem apanha; lançador sobe, Queda desce) vai para o `ImpactBurst`.
- `player.gd`: sons próprios direto na fonte; `charge_up` de 0,12 s no cast (não atrasa o disparo); contra-ataque mira onde o
  aparado vai estar (`RIPOSTE_LEAD` 0,2 s).
- `enemy_overlay.gd` (vindo do vfx7): carga nos tiros e rastro nos golpes corpo a corpo, lendo o estado do inimigo.

**Checagem:**
- **R3: ATENDE.** Os golpes de rotina de inimigo comum (pancada, explosão, pouso, salto, agarrão, fúria) caem para <= 0,12; o
  que sobra é raro: fase 2 de chefe (0,7+), morte desenhada de chefe (0,9), quebra de guarda (0,25) e de barreira (0,3). Confere
  com o `grep` de `Juice.shake` em `enemy.gd` e com a FeelProbe. §4.1 e §4.2 ok.
- **R15: ATENDE.** `hitbox.gd` passa a direção; `VfxLibrary.hit` e `ImpactBurst.spawn` têm o parâmetro `dir`. O acerto corpo a
  corpo mais comum deixa de sair em 360 graus (era a minha violação do início).
- **R4 / §4.3: ressalva nova, pequena.** (a) O cast da Sophia agora soa `cast_*` + `charge_light` (o ChargeFX toca o próprio som
  no `_ready`) + `proj_fire` do projétil, tudo no mesmo quadro. O doc diz "um som por evento". Correção mínima: passar
  `silent = true` no `charge_up` do cast (a carga é de 0,12 s; o `cast_*` já anuncia) ou tirar o `proj_fire` do projétil da Sophia.
  (b) O `atk_shot` novo nos tiros legados fecha o "tiro hostil mudo" do vfx7, mas esses tiros continuam com o `proj_fire`
  do `projectile.gd:55` por cima: o item antigo (trocar o `proj_fire` hostil) segue aberto, agora como camada dupla em vez de
  tiro mudo. Não bloqueia. A ressalva do 87290ca fecha: o `_Watch` do audio7 (801f46e) já não toca `double_jump`,
  `star_charge` nem `riposte`.
- **R5 / §5.5 (justiça):** fúria com piso de 0,42 s de aviso (a conta `maxf(wind*0.85, minf(wind, 0.42))` não encurta aviso
  menor que 0,42 e nunca passa de -15 %): atende. O contra-ataque que mira o recuo do aparado (FlashParryProbe: acerta; o doc
  diz 4 de 4, eram 0 de 3) premia o aparo certo, que é competência (SDT). Atende.
- **R9:** `champion_enter` no lugar do stinger de chefe para Campeão: atende. Lembrete de integração: o encenacao5 também toca
  o seu cue na aparição do Campeão (ressalva R4 dele, 0561f28); conferir que não dobra quando os dois entrarem.
- **R10:** `charge_up` solta um clarão pequeno ao fim (0,3 de tamanho, 0,1 s); a FlashParryProbe confirma <= 3 cheios/s e o
  `flash_strength` do `Juice` é o mesmo. Atende.
- **R21:** coleira impede o atirador de fugir da arena fechada. Atende.
- **§3 (economia): ATENDE e melhora.** Faíscas iguais em todas as dificuldades tira o ganho extra de 1,5x e 2,2x do Difícil e do
  Muito Difícil: a dificuldade escolhida deixa de ser atalho de economia e não há escassez artificial (a renda segue
  `Bestiary.screen_multiplier`, determinística por tela). Observação para o chefe: o Difícil rende menos que antes por
  inimigo de HP maior; o balance (BALANCE.md r7) foi medido com a regra antiga e pede um olhar rápido.
- **Doc:** a CHECAGEM está presente e confere com o código, mas (1) o doc cita "ver §12" (bot QA7 das telas de timeout e
  `validate.ps1 -Repeat 2`) que NÃO existe: resultado não registrado; (2) a CHECAGEM não lista a mudança de economia nem o
  `atk_shot`; (3) os commits são "WIP". Pedido: fechar o §12 com os números reais antes do FINAL.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: cast com 3 sons (`silent = true` na carga), `proj_fire` hostil ainda
por trocar, §12 do doc por registrar.

---

## dir2/arte-gpt — 50f807a (delta de de546f8; a51ea97 é merge da integração)

**O que muda:** `painted_flex.gdshader` (o halo por fora deixa de ter o piso de 0,3 e passa a valer `halo_amt * ndark`: só junto das
partes escuras) e `character_art.gd` (`HERO_HALO` 0,4 -> 0,25). Mais a nota no doc. Nada de combate, som, tremor nem economia.
- **Ressalva do de546f8: FECHADA nas duas formas que pedi.** Baixou o halo para 0,25 E tirou o piso, então o cajado dourado
  (claro e fino) fica praticamente sem halo, que era a faixa pálida de 3 a 4 px. O halo continua nas botas e no manto escuro, onde
  separa a silhueta do fundo escuro. `halo_amt` só é ligado para o herói (`hero_rim`), então os inimigos não mudam.
- **R18: segue PARCIAL**, mas não regride: o dono mediu tela 3: 1,76 -> 2,06; tela 30: 2,02 -> 2,37; tela 57: 1,45 -> 1,71 : 1
  (antes do halo novo e depois dele, contra a integração atual). Abaixo de 3:1; o resto depende do pedido ao cenario7. Correto
  não forçar mais luz na Sophia. Não refiz a medida.
- **R10:** o halo é estático. Atende.

**Veredito: APROVADO.**

---

## dir6/chefes6 — 8d00636 (delta de b0b52f0: 4574a19, 42d4804, 09b7989, 8d00636)

**Medido no 8d00636 (worktree de sonda, headless):** importação sem `SCRIPT ERROR`; `tools/chefes6/ReiProbe` (log
`C:\gnosis-wt\_caps\guardiao
ei_g.txt`): BodyBox cobre **96-98 %** do desenho do Rei em todas as poses e deixa **2 % (parado) a
12 % (recuperação)** da caixa fora do desenho; golpe leve da Sophia de 150 a 50 px: esperado = real em todas as 14 distâncias,
**0 atravessa, 0 apelão** (começa a ferir a 70 px, que é onde o cajado encosta no manto). A tabela de faixas cobre os 24
quadros do `rei_frames.json` (conferido: nenhum quadro sem faixa, então não há instante sem caixa por falta de dados).

**O que muda:** `boss_body_box.gd` + `rei_body_data.gd` (gerado): uma Área só com 6 faixas por quadro, seguindo a mola, o vira-lado e
o teleporte; liga a HurtShape genérica OFF (um acerto por golpe, R4); herdada pelo Rei-Mentira (`boss_rei_final` chama o
`super._on_setup`, mesma arte). `boss_hazard.gd`: `look="beam"`, o Raio vira orbe com cauda e brilho no piso; no aviso, luz que
junta, risco + seta + losango vermelho + `tell_unblock` (inalterados). `boss_rei.gd`/`final_battle.gd`: olho e Anéis descem fora
do HUD, recuo com margem de parede (`boss_brain.wall_margin`). `boss_astaphaios.gd`: `atk_shot` 1x por salva.

**Checagem:**
- **Justiça da caixa (R18, §5.5): ATENDE.** O que se vê é o que fere, medido nos 24 quadros e no jogo. Os 12 % fora são a faixa de
  cima pegando o braço estendido nos golpes (o doc diz até 15 %), dentro da banda pedida; a metade de baixo fica em ~8 %. Franja
  fina e ponta de pano não contam (coluna precisa de >= 30 % de opacidade na faixa). Os screenshots (`raio_depois_cima_antes_baixo.png`)
  mostram as faixas verdes acompanhando a silhueta.
- **Raio, legibilidade do aviso (R5/R11): ATENDE.** Aviso de 0,9 s (`raio_b`: 0,6 s, acima do piso de 0,45 s): luz que cresce no chão,
  risco que avança com seta branca, losango vermelho imparável e som. Forma + som + cor, não só cor (§4.11). Ativo, o orbe tem a
  mesma área de dano (meia largura 20 x altura 28); lê-se como luz e não como bloco (antes e depois nas capturas). Não vira
  hazard decorativo: o orbe rasteiro continua pulável (`hit_air=false`), coerente com o que o desenho promete.
- **Ressalva de leitura (pequena):** o halo do orbe (raio 0,75 x altura = 21 px) e a cauda (64 px atrás, alfa 0,55 -> 0) passam
  da área de dano (14 px de meia altura; 20 de meia largura). É luz suave e a cauda fica ATRÁS do orbe em movimento, então não
  promete dano à frente; se o playtest reclamar de "tomei dano fora da luz", encurtar a cauda para ~2 x `half_w`.
- **R10:** sem clarão novo. O flicker do orbe é 40 rad/s x 8 % de amplitude, só no raio, sem alternar luminância cheia: atende.
- **R21:** olho e Anéis fora da área do HUD (QA7 #24), chefe não cola na parede, teleporte com margem maior (arte larga não corta na
  borda): atende.
- **R4:** uma Área = um acerto; `atk_shot` do Astaphaios 1 por salva. O Rei segue somando corpo + olho (ponto fraco, preexistente).
- **R1 a R3, R9, §3:** intocados. Balance: Rei 74 s / 0 quase-mortes e final 196 s / 7 (dentro da variação documentada).
- **Integração:** o polimento7 já protege a caixa (`enemy.gd` do 2d54867: "nem forma, nem `disabled`" quando há `BodyBox`),
  então as duas branches convivem; confirmar com o ReiProbe depois do merge.
- CHECAGEM do doc presente e confere com o código.

**Veredito: APROVADO COM RESSALVAS** (cauda/halo do orbe um pouco além da área de dano; reconferir o ReiProbe pós-merge).

---

## dir7/polimento7 — 2854fc0 (delta de 2d54867: d639053, 4305f1d, 5898825, 2854fc0)

**Medido no 2854fc0 (worktree de sonda, headless):** importação sem `SCRIPT ERROR`; FeelProbe `QA PASS`; FlashParryProbe 17 `QA PASS`, 0 falhas;
HitboxProbe `QA PASS (atravessa 0 %, apelão 9 %; corpo desenhado: sem dano 0.0 %, apelão 1.3 %)` (era 8 % e 0,6 % no 2d54867; ruído,
dentro do limite). A BossHurtProbe precisa de janela; li o log do dono (`C:\gnosis-wt\_caps\polimento7\hurt_chefes\{antes,depois}	odos.log`)
e não abri janela.

**O que muda:** `enemy.gd` (hurtbox dos chefes = casco convexo do `body_poly` + 2 cantos de baixo, encolhido 0,9 em largura e cortado
no topo; chefe com `BodyBox` é pulado, sem tocar na forma nem no `disabled`; Campeão vida x1,7 -> x1,35 e dano x1,15 -> x1,0);
`boss_puppet.gd` (casco da malha para o boneco de reserva); `player.gd` (carga do cast com `silent = true`); `projectile.gd`
(`proj_fire` só quando `target_team == "enemy"`, o tiro da Sophia).

**Checagem:**
- **R4, cast: FECHADA.** O `ChargeFX` nasce com `silent = true` antes do `add_child` (o som tocava no `_ready`). Cast = `cast_*` +
  `proj_fire` do tiro da Sophia: 2 sons de eventos diferentes (conjurar e disparar).
- **R4, `proj_fire` hostil: FECHADA, com UMA dependência.** Conferi todos os `Projectile.new()` hostis: o caminho legado e o kit já têm
  `atk_shot` (2d54867); `_fire_shots`, `_lob`, `_wave_pair`, `_ground_spike` e os tiros de `boss_brain` (`_fire`, `ground_wave`) saem de golpes
  com som de golpe (`atk_*`, `BOSS_MOVE_SFX`). A exceção é o **voleio que quica do Astaphaios** (`boss_astaphaios.gd:153`): neste branch ele
  não tem som nenhum, e agora também perdeu o `proj_fire`. O `atk_shot` dele está no chefes6 `4574a19` (que está no 8d00636, aprovado antes).
  **Condição de integração:** integrar o chefes6 ANTES ou JUNTO deste commit; sozinho, o tiro de Astaphaios fica mudo.
- **R5 / §5.5 (justiça nos chefes): PARCIAL, melhora.** Da BossHurtProbe (média dos 10 chefes, poses parado/andar/preparo/golpe/dor,
  faixa do cajado): pano desenhado sem dano 25,1 -> 12,5 px; cobertura da silhueta 73 -> 79 %; caixa que acerta o ar 22 -> 15 %.
  Rei sozinho sem a BodyBox: 30,2 -> 9,2 px/linha. Com a BodyBox do chefes6 o Rei fica em 96-98 % (auditado). Mas **o Arconte do Sono
  (`arconte_sono`) continua com pano que o cajado atravessa: 15,6 a 27,1 px à esquerda em todas as poses** (caixa 36-51 px para
  uma silhueta de 75-110; cobertura 62-71 %), e o do Espelho cobre só 50-76 %. O `body_poly` é o corpo, não a cauda de pano. É o
  caso que o João reclamou do Rei, agora no Sono. Pedido (combate/polimento7, não bloqueia): para os Arcontes sem BodyBox, ou
  estender o casco com as bordas do recorte opaco (como a barra do manto), ou gerar a tabela de faixas do chefes6
  (`tools/chefes6/body_slabs.py <char>`) para o Sono e o Espelho.
- **R1:** a caixa não é suavizada e segue o quadro; no hitstop o quadro não troca, a caixa fica parada. Atende.
- **§3 (Campeão x1,35, dano x1,0):** luta mais curta, recompensa intocada (`spark_reward *= 2`), repertório e letreiro iguais. É um
  alívio ao jogador, sem escassez nem sorteio. O bot (doc §15) mostra os timeouts 13 -> 9 e menos dano tomado. Atende. §3 (renda igual) já
  está na CHECAGEM e confere com o código. Observação: o dano x1,0 vale também nas Provações do Campeão; o balance de ritmo é do chefe.
- **Doc:** §12 a §15 existem agora (a ressalva do "§12 que não existe" fecha) e a CHECAGEM lista renda, chefes, Campeão e R4. O doc não
  menciona o Sono; a frase "o manto que se vê é acertável" vale para o Rei, não para todos os Arcontes.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: (1) integrar com o chefes6 4574a19 (Astaphaios), (2) Arconte do Sono/Espelho
ainda com pano sem dano de 15-27 px, (3) reconferir a BossHurtProbe depois do merge com a BodyBox.

---

## dir7/polimento7 — 0ba25d8 (delta de 2854fc0: 222dc38, 0ba25d8)

**Medido no 0ba25d8 (worktree de sonda, headless):** importação sem `SCRIPT ERROR`; FeelProbe `QA PASS`. O log do dono
(`C:\gnosis-wt\_caps\polimento7otudio_t15.json`) mostra `champion_enter` = 1 e nenhum `boss_appear` na tela do Campeão. Li as
capturas `C:\gnosis-wt\_caps\polimento7\esgotado\` (antes, depois e sopro, telas 38 e 48).

**O que muda:** `cinematic.gd` (`boss_card(..., sting = true)`, o `boss_appear` só toca se `sting`), `level.gd` (`_champion_card` passa
`sting = false`, inclusive a reserva "O CAMPEÃO"), `enemy.gd` (invocador: teto total de 3 chamadas, 2 larvas cada = 6; ESGOTADO = cinza
x0,62 no corpo, um sopro, sem o golpe `recuo`).

**Checagem:**
- **R4 / R9, Campeão: ATENDE.** A aparição fica com `champion_enter` e sem o stinger de chefe, então a música do Éon não vira música
  de chefe e o Rei e os Arcontes mantêm a "entrada de chefe" só para eles. Prova no log de áudio. Também tira de cena o risco que eu
  tinha anotado de a aparição do Campeão dobrar com o cue do encenacao5. Observação: o ramo `"campeao"` do `Gnosis.boss_card` ficou
  sem chamador e ainda toca o stinger (código morto; se alguém o religar, dobra).
- **§3 / §4, teto do invocador: ATENDE.** A zona passa a ter fim previsível (no máximo 6 larvas), sem número escondido e sem
  multiplicador de dano. É alívio ao jogador, não escassez. O bot (doc §16) mostra o tempo nas 16 telas com invocador 1928,6 -> 1754,1 s,
  timeouts 9 -> 7 e quase-mortes 208 -> 189. O estado esgotado não muda o dano.
- **R5 / clareza, RESSALVA (o doc promete mais do que o código faz):** o doc diz "para de recuar, fica ao alcance do cajado". O
  invocador usa o repertório (`moves`), então anda por `_chase_moves` -> `_desired_x`, e no papel `shooter` essa função continua o
  empurrando para `px + lado * 175` quando a Sophia chega a menos de 120 px. O `_summon_exhausted` só entra em dois lugares: o ramo
  legado de `_process_chase` (linha 651), que o invocador não usa porque tem `moves`, e o filtro do golpe `retreat` em `_pick_move`.
  Resultado: ele perde o salto de recuo, mas continua se afastando a pé (velocidade baixa, e a coleira da arena o limita). Correção
  mínima: em `_desired_x`, no ramo `shooter`, `if _summon_exhausted: return px + side * 60.0` (ou o `ring` melee). Não bloqueia: o
  teto, sozinho, já encurta a luta (bot).
- **R18 / leitura visual: RESSALVA leve.** Nas capturas o esgotado é só um corpo ~38 % mais escuro (`self_modulate` x 0,62) e um sopro
  cinza de 1 quadro. No fundo claro (tela 38) lê como "apagado"; no fundo escuro (tela 48) a capa verde-escura quase some no
  cenário, só o contorno de luz de recorte a salva, e é o inimigo que ainda atira (orbe e semente). Escurecer o inimigo perigoso
  pesa contra o R18 ("sempre salta do fundo"). Sugestão: dessaturar para cinza em vez de escurecer (manter a luminância, ou clarear
  um pouco o tom), e/ou deixar um sinal contínuo (fumaça fina) em vez de só o sopro de 1 quadro. A mudança é pequena, por isso
  não reprovo.
- **R1 a R3, R10, §3 (economia):** intocados neste delta.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: (1) `_desired_x` não respeita o esgotado (o doc exagera); (2) o cinza escuro
atrapalha a leitura em fundo escuro.

---

## dir7/mapa7 — 4e4b9cc (delta de 8e8afc3: um commit)

**Medido no 4e4b9cc (worktree de sonda, headless):** importação sem `SCRIPT ERROR`; MapQA 29 `QA PASS` (inclui a nova "lugar do Soter lido de
`SOTER_SLOTS` (17/35/53, Velkar 61)", "nenhum cadeado antes do Soter" e "o bot sem pulo duplo nunca entra em segredo"); LayoutQA
`QA PASS`, 1246 verificações em 129 telas. Logs em `C:\gnosis-wt\_caps\guardiao\p7g_*.log`.

**O que muda:** `RunManager` ganha `SOTER_SLOTS = [[1,6],[3,6],[5,6]]`, `VELKAR_SLOT = [6,5]`, `soter_meeting_at()`, `velkar_at()` e
`double_jump_screen()`. `screen_layouts.gd` (`npc_on_screen`, `_high_cache`), `level.gd` (`reserved_spans`, `_spawn_extras`) e a
MapQA leem dali em vez do número 17 fixo e das condições `off == 6 and eon in [1,3,5]` copiadas em 3 lugares.

**Checagem:**
- **§3 / §4 (nenhuma isca impossível): continua ATENDENDO, e a minha observação do 8e8afc3 fecha.** Eu pedi que a regra não dependesse do
  número 17 solto. Agora é uma fonte só: mudar o Soter de lugar muda juntos o encontro, o espaço reservado, o layout (torre de pulo
  simples antes dele, saliência de pulo duplo depois) e a QA. Conferi a equivalência com o código antigo: os pares (Éon, camada) são
  os mesmos, o índice do encontro (`meeting`) sai da posição na tabela como antes (`[1,3,5].find(eon)`), e o 1º slot concede o pulo
  duplo como antes. A MapQA confirma 17/35/53, Velkar 61 e a tela 16 sem encontro. Saída do LayoutQA idêntica.
- **Resto da observação (não bloqueia):** a tabela continua posicional, não por `has_double_jump()`. É aceitável: o pulo duplo só vem do
  slot 0 e a MapQA prova que nenhum nó o exige antes dele.
- **Sons do world_map: sem mudança neste delta.** `world_map.gd` não foi tocado desde o 26d28b3 (já auditado): `ui_move`,
  `ui_confirm`, `ui_back`, e o segredo fechado dá "voltar" com o texto do requisito, sem punição nem tremor (§4.1). Um som por ação (R4).
- **Justiça / previsibilidade:** nenhuma regra de jogo, recompensa, dano ou sorteio mudou; é refatoração com o mesmo comportamento.
- MAPA7.md ganhou a seção 1d com a validação (confere com o que medi).

**Veredito: APROVADO.**

---

## dir6/progressao6 — 3d13bbd (= e78feb4 + merge da integração ba91602; delta da base 4dad743; 8757da6 é merge)

**Medido no 3d13bbd (worktree de sonda, headless):** importação sem `SCRIPT ERROR`; ProgQA **58 `QA PASS`**, 0 falhas. O 3d13bbd só soma ao e78feb4 o merge da integração (arquivos de outros donos; o código da Progressão é o mesmo, conferido por diff; a única mudança em arquivo dela é a quebra de linha da placa dos Selos, por i18n). Não refiz o ProgBot
(15 a 25 min); conferi a conta contra o doc (§9.4) e o código.

**O que muda:** arma espalhada (custos 200/500/1100/1800; Nv.3 após Athoth, Nv.4 após Yabel, Nv.5 após Belias); 6ª compra de Éter só após Belias
(`MP_LAST_TIER = 6`); segundo engaste (1500, após Astaphaios) e Coro das Faíscas (700): relíquias de fim de run; `claim_once` (baú, Selos,
Adormecido e recompensa de camada pagam 1 vez por run, no save); respiro entre ondas 0,8 -> 2,0 s; ProgBot com a loja real.

**Checagem:**
- **§3, a curva: ATENDE.** Preços e selos fixos e mostrados na loja ("vença Belias"), sem prazo nem sorteio; nada se perde por não comprar (sem
  FOMO). A recompensa vem de ter vencido o Arconte (competência). ~15 mil faíscas, 26 a 31 compras (uma a cada 2-3 telas, maior jejum 3-6
  telas), nenhuma trilha no topo antes da tela 56, loja inteira ~21,4 mil: o jogador escolhe. Fecha o item 8 do playtest ("tudo no máximo cedo").
  Observação: no perfil focado a arma fica no Nv.3 da tela 19 até ~46 (Nv.4) e 59 (Nv.5): ~27 telas sem golpe novo. É decisão de ritmo, não
  violação; vale o playtest do João ficar de olho (se reclamar de "nada novo", baixar o preço do Nv.4, 1100).
- **§3, `claim_once` (era o meu risco "morrer dá lucro"): ATENDE, com uma RESSALVA.** A chave do baú é `bau:<tela>` para o baú comum e para o baú
  SECRETO. O baú comum fica em toda tela `screen % 3 == 1` e o secreto (`tower_cache`/`dj_cache`, em layouts de santuário, escalada e segredo) pode cair
  na mesma tela (ex.: o santuário da trilha baixa do Torpor na tela 7: 7 % 3 == 1, e o layout de santuário põe `tower_cache`). Quem abre o segundo
  recebe 0 faíscas, calado (o baú abre, soa e cura, sem aviso). O secreto vale o dobro: o prejuízo cai no prêmio por esforço. Não consegui enumerar
  todas as telas sem rodar o jogo (o `--script` não carrega os autoloads), então é "provável, conferir". Correção mínima:
  `"bau:%d%s" % [screen, ":s" if secret else ""]`. Além disso, quando `claim_once` nega (baú, Selo, Adormecido), mostrar um aviso curto ("já
  recolhido") em vez de calar; sem isso lê como bug.
- **R21: ATENDE.** Respiro de 2,0 s entre ondas (era 0,8). Sem slow-mo.
- **Coro das Faíscas:** dano fixo 14, raio fixo 80, sem sorteio, sem tremor nem som próprio; a última faísca de cada inimigo solta o anel pequeno (o
  `nova_ring` de raio < 140 não entra no orçamento de flashes, e o clarão central é de 0,7 por 0,1 s). Premia derrubar inimigos agrupados (habilidade).
  Atenção leve (R10): uma cadeia de mortes pode repetir o anel várias vezes por segundo; é pequeno, mas se o playtest incomodar, limitar a 1 anel por segundo.
- **§4:** sem recompensa variável, sem timer, sem escassez artificial. Conferido.

**OPINIÃO (pedida, não é deste branch): a perda de 20 % das faíscas ao morrer (`level.gd:1012`).** Pela §4 não é "perda artificial" no sentido do cassino:
é anunciada, proporcional, determinística, sem FOMO, sem timer. Mas é o item mais fraco do conjunto, por três motivos: (1) não há recuperação (some
para sempre), o que é puro custo; (2) o texto da morte é de "checkpoint, algo te recompõe" e a perda contradiz o tom; (3) pune quem guarda, e a loja
só abre pela pausa; o dono diz que "quem gasta não perde nada", mas o jogador novo não sabe disso. Com `claim_once` o "morrer dá lucro" acabou, então
o piso de proteção já existe e a perda deixa de ser necessária como contrapeso. Recomendo: manter, porém com teto (ex.: o menor entre 20 % e ~150
faíscas) ou só sobre as faíscas ganhas NA tela, e dizer na própria fala de morte que dá para gastar antes. Se o chefe quiser o mínimo de risco: zerar
a perda e deixar o custo da morte no tempo de refazer a tela. Não bloqueia.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: chave do baú secreto (`bau:<tela>`), aviso quando `claim_once` nega.

---

## Mentira do Rei — chefes6 5b076cb e Limiar v3 — encenacao5 b415c40

**Medido:** li o diff próprio do 5b076cb (`boss_rei.gd`, `boss_brain.gd`, `gnosis.gd`, `boss_probe.gd`), os commits 76ff840 e b415c40 do encenacao5 (`narrative.gd`, `gnosis.gd`, `cinematic.gd`, QAs) e confrontei com a minha AMOSTRA. NÃO rodei a sonda do Rei nem o ReiDuelProbe (o dono dá 6/6 e 29 checagens, 0 falhas; validate 15/15).
- **(1) A Mentira sem a pose do joelho: JUSTA, pode entrar.** Pistas reais hoje: o olho desce `ORB_LOW` 132 px (posição/forma) e o "dong" (som; hoje reaproveita `king_step`), além do card escrito ("Um rei jamais se curva.") e de uma pista nova na fala da Voz ("Muita pose, joelho fraco."). A ação do Desmentido (bater no olho enquanto ele está baixo) é a que a luta já ensinava (ponto fraco 1,5x), então ninguém depende de entender a metáfora para vencer; errar não custa nada (`lie_was_exposed` só liga o bônus), o bônus é fixo e dito (toast "Mentira exposta · o Rei fica 8 s sem guarda"; 8 s PARADO, sem escolher golpe nem fase, 1x), e a mentira cai na queda. Ficam
  menos "aha": sem a pose o jogador vê "o olho desceu", não "ele se curvou". **A pose é melhoria, não bloqueio**; e como a pista de som é emprestada, vale um "dong" próprio (Áudio) para não se confundir com o passo.
- **Meus 5 ajustes da amostra: ATENDIDOS.** (2) degrau 2 agora é pergunta ("Ele se curvou? Jamais, né?", 5 palavras); (3) os 8 s: `chase()` devolve true, velocidade 0, `check_phase()` bloqueada e sem telégrafo; (4) orçamento de 6 respeitado (C2 virou "Nossa luz rasteja. Pule." e C5 "Sempre atrás de você."); (5) C1 só toca se não houve aparo e C2/C3 saem na recuperação ou com >= 1 s de folga (`move_will_start`). A regra 3 também: o Torpor virou legenda após 10 s.
- **Texto do Limiar v3 (encenacao5):** igual à amostra (você, Sophia seca, Voz "a gente", Rei "nós"), falas de combate de 4-5 palavras, Estela só quando para (>= 0,6 s) ou lê, sem corte da Cena A (teto 8 s). Mantém a regra 3 (nenhuma cena pausada colada na outra).
- **Edições em arquivos de outros donos: CORRETAS E MÍNIMAS.** `tools/audio/voice_probe.gd`: troca o texto fixado e os dois ids (`9c8e9fd7cd28`, `7bce0dcd8a25`) pelos da reescrita, sem mudar nenhuma checagem. `tools/gnose_qa.gd`: o "você" deixa de ser proibido no diegético (decisão do chefe), mas a aspa simples e a lista de nomes proibidos continuam checadas: a exigência de respeito (nomes canônicos) está intacta.
- **Ressalvas:** (a) falta a OPÇÃO "Dicas" nas Opções: o código já lê `GameManager.lie_hints` (padrão ligado), mas nada no menu a liga/desliga, então a regra 17 ("desligável") só vale quando a UI entregar o botão; (b) ids novos: as 11 falas dubladas do 1º lote voltam ao blip até serem regravadas (a Dublagem tem de gravar o v3 final); (c) o en_table do chefes6 isolado perdeu "Vozes"/"Desligadas"; no tip do encenacao5 eles voltaram: o integrador deve conferir EN após o merge; (d) o "dong" é som emprestado.
**Veredito: APROVADO COM RESSALVAS** (entra; as ressalvas (a) e (d) são pedidos de UI e Áudio).

---

## Texto — AMOSTRA_LIMIAR.md (tela 1, sem código) contra `REGRAS_GUARDIAO_TEXTO.md`

**Medido:** li a amostra inteira e conferi o kit do Rei em `boss_rei.gd` (`origin/integracao/onda1`): a Mão e o Raio têm `expose: true`, o Rei se ajoelha e o olho desce `ORB_LOW` 132 px, e bater no olho já vale 1,5x (o ponto fraco já existe). Nada rodado (a amostra não tem código).
- **Tamanho e ritmo (§1): ATENDE.** Falas de combate com 5-6 palavras (C1-C6a, 1,9-2,2 s estimados, <= 80 caracteres); fala de cena mais longa 66 caracteres (<= 140); troca de falante a cada 1-2 falas; cena A 7 falas e cena da queda 9 (<= 12 de marco). Humor ~1 em 3 na abertura (acima do 1 em 4, aceito e com os cortes sugeridos pelo autor: A4, D10-D11).
- **Mentira do Rei: JUSTA E SOLÚVEL (§4).** A frase fica escrita no card e no Bestiário (não é só fala que se pula); 2 pistas antes: a pose de ajoelhar (forma) e o olho que desce com "dong" (posição + som), nenhuma só por cor; o Desmentido é bater no olho enquanto ele está baixo, que é o que a luta já ensina; errar não custa nada, a recompensa é fixa e declarada (8 s, 1x por luta) e ela cai sozinha na queda. É fácil de propósito (tutorial do sistema), o que o autor admite.
- **Ressalvas na Mentira (aplicar antes de implementar):** (1) a pista 3 (C3 "Esta mão, nem você apara") NÃO aponta o ajoelhar, só o golpe; não conte como pista (as 2 reais bastam, mas elas dependem do "dong" e do rastro de luz, que são som e VFX NOVOS: sem eles sobra 1 pista só e viola a regra 11); (2) o degrau 2 (C6a) entrega a resposta em vez de uma pergunta: troque por algo como "Ele se curvou? Jamais, né?" (5 palavras) para apontar sem dizer o que fazer; (3) definir o que são os "8 s sem guarda": o Rei tem de PARAR de atacar nesse tempo (estado de atordoado) e o olho baixo não pode ficar ao alcance de um golpe dele; senão o bônus vira armadilha;
  (4) o orçamento de combate fica exatamente em 6 (5 fixas + C6a), sem folga: a C6b sem voz está certo, e nenhuma fala nova pode entrar na tela 1; (5) C1 só toca se o jogador ainda não aparou o Leque (se já aparou, calar), e C2/C3 nascem na escolha do golpe com >= 1 s de folga antes do windup: confirmar com o chefes6 que essa gabolice não alonga a luta (`gap_by_phase`).
- **Decisão da regra 3 (cena seguida da tela 2): VIRA LEGENDA.** `eon_intro(0)` passa a legenda (CaptionBar, sem pausar) e só dispara depois de >= 10 s de jogo na tela 2 (não na entrada); a cena da queda do Rei (9 falas) fica como está. Se o card de Éon tiver só título (sem fala), pode ficar na entrada.
- **"Você" no jogo todo: ok para a leitura; avisos:** muda ~1380 textos e os ids do i18n, então as 11 falas dubladas do 1º lote (ids por texto) VOLTAM AO BLIP até serem regravadas; a Dublagem só grava com o texto fechado; o EN acompanha a troca. O "nós" do Rei como pista (G1, tela 64) tem 2 pistas antes (A2/A4 + "a gente" da Voz): ok.
- **As 7 Mentiras (esboço): sinalizo antes de escrever:** Astaphaios ("o único COM sombra") e Belias ("muda verde na poça") arriscam pixel-hunt (regra 16): a pista precisa ser GRANDE e dada por forma/som, não por sombra ou detalhe pequeno; Galila ("aparar o Puxão"): conferir se o Puxão é aparável (se for vermelho, a mentira se contradiz); Harmas ("acertar pelas costas durante a Sucção") pede ficar atrás de quem puxa: arriscado, conferir o alcance; Armupiel ("derrubar um Pretoriano parado") convive com o Juízo novo: conferir com o chefes6 o que o kit tem de verdade. Cada Desmentido tem de ser possível sem mais risco que o declarado e sem tirar a luta da regra que ela já tem; o bônus de 8 s em cada chefe pede remedir o tempo de luta (as curvas do BALANCE não contam com ele).

**Veredito: APROVADO COM RESSALVAS** (entra para virar código, com os 5 ajustes da Mentira e a decisão da regra 3 acima).

---

## Rei HD — chefes6 1c4b0c7 (contém arte-gpt 64e92cf)

**Medido:** importação do 1c4b0c7 sem `SCRIPT ERROR` (`_caps\guardiao\p16_import.txt`); li `new_sec.txt`, vi `prancha_rei_hd.png` e `windup36.png`; medi o atlas publicado (`rei_frames.json/png`, 2048x8192, 450 px de corpo). **O ReiProbe do 1c4b0c7 que eu lancei não terminou a tempo do relatório** (log em `p16_rei1.txt`, se existir): os números 97-99 %, atravessa=0, apelão=0 são os do dono.
- **Nada "borracha":** parada 16q: capuz 0,9 px, tronco 1,8, barra 7,1 de 457 px (1,6 %), base 3 px; andar 12q: capuz 0,8, tronco 3,4, barra 6,1; nos golpes a base fica em 0-1 px (pés pregados) e o topo sobe até 98 px só no `windup` (é o braço/olho se erguendo: o gesto do telégrafo).
- **Telégrafo legível:** no windup o contorno amarelo brilhante (`telegraph_color`, mecanismo próprio, não o `rim_mul`) e o glint de 180 ms antes aparecem nítidos sobre o azul-petróleo, com o manto creme e o olho erguido bem separados do fundo. A pose de preparo (braço no alto + a outra mão aberta) agora é a mesma em todos os quadros do `windup`, então o gesto é mais claro que no v11.
- **Justiça:** BodyBox de 16 faixas (fill 0,30) regenerada nos 56 quadros; o dono mede atravessa=0, apelão=0, cobertura 97-99 %. As trocas secas (4 de 8) não mexem em tempo nem em alcance: o golpe segue os timers do Enemy.
- **Ressalvas (build):** +~190 MB de VRAM sem compressão (página própria 2048x8192 x3 texturas): conferir em máquina de 4 GB; dano/morte/cenas do Rei ainda usam a pintura antiga (estilo diferente dentro da mesma luta); 4 de 8 trocas de pose secas.
**Veredito: APROVADO COM RESSALVAS.**

---

## dir7/dublagem-lote — 4920893 (1º lote: prólogo, despertar, Rei do Limiar; 11 falas PT)

**Medido OFFLINE (sem tocar nada), no commit:** extraí `assets/audio/voice` e rodei `ffmpeg ebur128=peak=true` + silêncios (`_caps\guardiao\lote`). Não rodei o VoiceProbe/validate (o dono dá 0 falhas e verde).
- **Ética da voz: OK.** "Voz fixa clonada" = clonagem de uma referência SINTÉTICA: cada voz-base nasce de uma descrição em texto no Qwen3-TTS **VoiceDesign** (`job_refs.json`, `mode: design`, `instruct: "A deep, warm... baritone of an ancient being..."`), e o modo Base (`gen_qwen.py`, `create_voice_clone_prompt`) só clona
  esse `.wav` gerado (`refs\<voz>_sNN.wav` -> `escolhidas.json`). Nenhuma referência vem de pessoa real, e as vozes de voluntários (Piper) foram descartadas pelo próprio dono por ética. O ator-base do Rei/A Voz é o mesmo ser (`demiurgo`), como o LORE pede.
- **Licenças: OK.** Qwen3-TTS Base, VoiceDesign e Tokenizer: `license: apache-2.0` nos README locais (uso comercial livre). O ASR (faster-whisper-small) só mede o CER e não vai no jogo; XTTS/F5/Fish (sem uso comercial) ficaram de fora. Falta só o aviso de atribuição Apache-2.0 nos créditos do jogo (pedir ao Polimento/UI).
- **Números (REGRAS §6/§21):** 11 arquivos, todos mono 24 kHz, durações 3,1-10,4 s (<= 12 s da regra 13); loudness integrada -20,8 a -21,0 LUFS (alvo -21, regra -20 a -22), true peak -1,6 a -5,1 dBTP (<= -1); início 13-78 ms (<= 80); manifesto bate com os arquivos (durações idênticas).
- **Intensidade:** Rei com `nivel` 2 (teto da tela 1 = 1-2, regra 15) e `onde: cena`; nenhuma fala de combate neste lote, então as guardas de luta (8 s, 6/tela) ainda não foram exercitadas por voz real.
- **Ressalvas pequenas:** (a) as 3 falas do Rei (e 2 do Narrador) têm cauda de 263-361 ms até -45 dB, acima dos 250 ms do contrato (é a cauda de reverb de catedral; a legenda segura a voz + 0,4 s, então só alonga 0,1 s); (b) `lufs_s` máx. do manifesto -19,6/-19,7 em 3 falas, ~0,4 LU acima da faixa (-20 a -22) da regra 21;
  (c) `A Voz` do `king_fall` (1dbe2dd77839) tem CER 0,103 pós-efeito: é a mais baixa em inteligibilidade, vale ouvir (nomes próprios saem mal no ASR, como o doc admite); (d) o jogador em inglês ouve a voz PT com legenda EN (`_voice_langs`), decisão aceita até haver `en/`; (e) a IA não ouve: o veredito sobre atuação ("dark/épico, não leitura") e sobre o grito do Rei na final é do ouvido do João.

**Veredito: APROVADO COM RESSALVAS** (entra o lote; ressalvas de ouvido e a atribuição Apache-2.0).

---

## dir7/audio7 — b655563 (reauditoria do delta de 656dfc0)

Li o diff (não rodei o validate de novo; o dono dá VoiceProbe no `validate.ps1`, 15/15, e meu VoiceProbe no 656dfc0 já tinha dado 0 falhas).
- **(a) Guarda de voz de luta: FECHADA.** `play_voice(..., combat)` barra fala > 2,5 s, a mesma fala 2x na tela, intervalo < 8 s desde o FIM da última voz de luta e mais de 6 por tela (8 na batalha final, via `screen_role == "final"`); contagem zera por tela (`reset_combat_voices` no hook de tela). Barrada = só legenda, sem blips (`_voice_refused`). A CaptionBar marca "luta" por combate perto (`_hot`/`_in_fight`) ou `urgent`.
- **(b) 1 aperto: FECHADA.** Digitando: completa o texto e corta a voz (80 ms); texto completo: 1 aperto corta a voz e avança.
- **(c) Vozes 80 %: conferido** (padrão do código e da captura nova).
**Veredito: APROVADO.**

---

## dir7/audio7 — 656dfc0 (infraestrutura de dublagem contra `REGRAS_GUARDIAO.md`)

**Medido:** li o código (`audio_manager.gd`, `dialogue_box.gd`, `caption_bar.gd`, `cinematic.gd`, `options_menu.gd`, `save_manager.gd`) e a captura `_caps\audio7\opcoes_vozes_640.png`. O VoiceProbe do dono (0 falhas) NÃO foi refeito por mim no fechamento deste relatório (import do worktree de sonda ainda rodando; log em `_caps\guardiao\p15_*`).
- **Controle: cumpre (regras 1-5).** Nada pausa nem trava o mundo por voz: a `CaptionBar` (combate) só segura o TEXTO enquanto a voz espera a folga e desiste em 4 s (`VOICE_WAIT_MAX`), sem `lock_advance` nem DialogueBox. Em cena, o aperto completa o texto e corta a voz em 80 ms; a fala dublada ignora o `wait_2s`; morte, troca de cena, `_finish`/`_exit_tree`, legenda que sai e cinemática cortam em 120 ms. Sem arquivo ou Vozes 0 %: `play_voice` devolve 0 e tudo volta como antes.
- **Legenda sempre: cumpre (regra 6).** As Opções só têm TAMANHO (P/M/G, `% 3`), não há "desligada"; o `DialogueBox` e a `CaptionBar` mostram o texto de qualquer jeito, com ou sem voz.
- **Janelas e mixagem: cumprem (10, 19, 20).** Voz de luta não nasce com golpe avisado no ar (+300 ms), nem colada num `tell_*` (+400 ms), nem sobre o stinger (+500 ms); ducking -8/-6 dB "vale o maior", ataque 80 ms, release 700 ms, e os efeitos não baixam; ao soar um `tell_*` a voz desce 8 dB e perde graves (passa-altas 250 Hz).
- **Ressalvas:** (a) a infra NÃO impõe as regras de frequência de combate (>= 8 s entre falas, <= 6 por luta, <= 2,5 s, grito <= 1,2/2,0 s): hoje só valem pelo manifesto; antes da 1ª fala de combate entrar, pôr um guarda no `play_voice` (intervalo mínimo e contador por luta, só com o mundo rodando). (b) o 1º aperto com a voz soando COMPLETA o texto e corta a voz, mas não avança mesmo que o texto já esteja inteiro (a cauda de até 0,3 s): preferível que, com o texto completo, 1 aperto corte a voz e avance. (c) a captura das Opções mostra Vozes em 100 %, e o padrão do código é 80 %: conferir se é só a captura. (d) uma fala nova corta a anterior (sem prioridade cena > Rei > Arconte): ok enquanto o manifesto está vazio.
- Manifesto vazio = jogo igual a hoje. Edições fora da área (dialogue_box, caption_bar, cinematic, options_menu, save_manager, en_table) são aditivas e protegidas por `has_method`/`_voice_dur > 0`.

**Veredito: APROVADO COM RESSALVAS** (a infraestrutura entra; as travas (a) e o ajuste (b) antes de entrar fala de combate).

---

## Rei nítido — arte-gpt 63f597a (delta de 9ad0b06) e chefes6 b587064

**Medido (sonda no b587064, headless):** importação sem erro (`_caps\guardiao\p14_import.txt`). **ReiProbe tela 1** (`p14_rei1.txt`): `atravessa=0`, `apelao=0`, golpe esperado x real batem (fere de 70 a 50 px, nada a >= 75), parada cobre 96 % (6 % fora), golpe 99 % (14 % fora).
Na tela 68 a sonda mede o COLOSSO (sem BodyBox, `punhos_*`; `apelao=1` a 55 px), arquivo que este branch não toca: não é regressão do Rei; o Rei da 68 não foi medido pela sonda.
Li o diff de `character_art.gd`/`rei.json` e vi `_caps\arte\rei_nitido\prancha_antes_depois.png`, `cmp_rim.png`, `depois.png`.

- **Legibilidade do Rei sem o halo: ok.** O manto creme claro contra o azul-petróleo do Limiar tem contraste de sobra; no zoom 4x, o contorno fino azul-Éon some (2ª metade) e a borda continua nítida pelo próprio recorte do atlas de 450 px (1:1 na janela). A pintura fica mais limpa que a de 300 px com halo. É a mesma lógica da Sophia: o contorno só ajuda onde o fundo é claro e o personagem escuro; aqui é o oposto.
- **Telégrafo: NÃO perdeu força.** O aviso dos golpes não vem do `rim` nem do `Rim` do Enemy: o contorno do telégrafo é `telegraph_color` (8 cópias da silhueta, 1,3 px, alfa 0,9, pulsando; `character_art.gd` ~l.1735), mais a tinta de 45 % e o glint 180 ms antes. Esse caminho não lê `rim_mul`, `outline_mul` nem `rim_px_mul`, e a escala em mundo é a mesma (`k` compensa os 450 px), então a largura do brilho é igual.
  O que o `rim_mul 0,2` reduz é só o contorno de leitura na cor do Éon (que dobrava na preparação, 0,64 -> 0,13): era um reforço secundário, rosado, não o aviso. Ressalva leve: a cor amarela do telégrafo some em um manto creme se alguém olhar só a tinta; por isso vale conferir no playtest que o contorno brilhante e o glint bastam no Rei (nas capturas v11 já bastavam).
- **BodyBox (chefes6 b587064):** regenerada no atlas de 450 px com folga de 4 px (`body_slabs.py --folga`), o resultado acima. A faixa do cajado fica abaixo do que o olho vê, igual ao v11.
- §4: sem recompensa, flash ou tremor novo; Rei so; outros chefes leem `outline_mul/rim_mul = 1,0` por padrão (não mudam).

**Veredito: APROVADO.** Pendente só para o playtest: o Rei da tela 68 (lado a lado com o Colosso) a 450 px e o telégrafo contra o fundo roxo.

---

## Rei v11 — arte-gpt 9ad0b06 (delta de a238686) e chefes6 6c2bd29 (delta de 0e8d761)

**Medido (sonda `guardiao_sonda` no 6c2bd29, headless, sem som):** importação sem `SCRIPT ERROR`/`Parse Error` (`_caps\guardiao\p13_import.txt`). **ReiProbe na tela 1** (`p13_rei1.txt`): `atravessa=0`, `apelao=0`; golpe esperado x real batem em todas as distâncias (nenhum toque a >= 75 px, acerta de 70 a 50 px, dano 7);
caixa do BodyBox: cobre 97-98 % do desenho e fica 6-14 % fora (o dono dá 7,3 % de média); pano fora da faixa do cajado 2,7-4,0 px, sobra 6,6-8,0 px. Medi o atlas publicado do Rei (`rei_frames.json/png`, quadros alinhados pela âncora): **parada 16 quadros** (6 fps): capuz 1,1 px, tronco 1,2 px, topo 1 px, base 2 px,
barra 5,0 px (1,6 % da altura de 303); **andar "deslizar" 12 quadros**: capuz 1,0 px, tronco 1,2 px, barra 4,2 px. Vi `luta_andar_golpe.png` e o zoom do capuz.

- **"Borracha": não há.** O corpo e o capuz quase não saem do lugar (~1 px); só a barra do manto ondula (4-5 px), que é o que se quer de um manto. Duas chaves do dono ajudam e estão corretas no código: `spring_mul 0,3` (a mola `sx/sy/curvatura` dos golpes passa a valer 30 %: era o que esticava o cartão) e
  `flex_off_states` idle/walk (`ca = 0` quando a sequência mostrada é uma delas: a folha já ondula o manto, o vento do shader não dobra). Só vale para quem tem as chaves no JSON (o Rei); os outros chefes leem 1,0 e `[]` por padrão, então não mudam.
- **Legibilidade/justiça (chefes6 6c2bd29): ok.** A caixa nova casa com os 28 quadros de parada/andar (fill 0,26 só neles) e os golpes seguem iguais; o golpe só fere quando o cajado de fato toca o pano (nenhum "acerta o ar"), e o "esperado=false" a >= 75 px confere com o desenho. R5 (telegrafo do Rei) não mudou.
- **Ressalva (já conhecida do dono): a troca parada -> preparo ainda é SECA.** Na `luta_andar_golpe.png` o Rei passa de braços junto ao corpo (parada/andar) para o gesto de preparo (braço levantado, manto aberto) sem quadro de transição; não atrapalha a leitura (o telegrafo amarelo/vermelho e o
  `tell` seguem na hora certa), mas é o único ponto onde o Rei lê como "troca de cartão". Espera os golpes em produção; baixa prioridade.
- §4: nada de recompensa, flash ou tremor novo.

**Veredito: APROVADO COM RESSALVA** (a troca seca, que o dono já listou).

---

## dir2/arte-gpt — a238686 (delta de 8916611: parada r4)

**Medido:** li o diff de `character_art.gd` (`_hero_no_flex`, remoção do `walk3d`/`persist`), `hero_qa.gd` e a receita; vi `_caps\arte\loco_r4\zoom2x_parada.png`, `p_idle_golpe.png`, `p_idle_corrida.png`. Medi o atlas publicado (`_caps\guardiao\atl\`, 12 quadros `s20.idle_00..11`, alinhados pela âncora do pé): botas 0,00 px de deslocamento, pernas 0,34 px (diferença de cor
entre quadros 0,7-2,4 em 255), cajado com ponta fixa (0,0 px), tronco 1,3 px e cabeça/cabelo 1,9 px (em px de atlas, escala 0,78). Não rodei o HeroQA nem o jogo.

- **Identidade (minha ressalva do 8916611): FECHADA.** Cabelo branco-violeta ondulado com a mecha azul, rosto, torso fino e manto são a mesma pintura que corre e golpeia; a parada não é mais "outra pessoa". No par parada -> golpe e parada -> corrida a transição some (mesma silhueta, mesmo manto, de 3/4 para perfil só pelo ângulo do próprio atlas).
- **"Borracha": não há.** Só o que deve se mexer se mexe: tronco respira ~1 px e cabelo/abas ondulam ~2 px; botas, pernas e cajado ficam pregados (0 a 0,3 px), então os pés não deslizam e o cajado não balança. O `no_flex` desliga o vento do shader na parada, então não dobra o vento já pintado nos quadros (o `_hero_no_flex` vale por sequência, e as outras seguem com o vento do shader).
  Ciclo de 12 quadros a 6 qps = 2 s, sem pulo de laço visível na folha. Se o playtest achar o cabelo "degrau" a 6 qps, subir para 8 qps (o doc já tem a opção).
- **Código:** o `walk3d` e o `persist` saíram (some o risco de pose presa que eu tinha apontado); `idle_pintado` continua de reserva; HeroQA agora confere `idle_pintado`, `s20`, 12 quadros e `no_flex`.
- **R18:** volta ao nível da pintura (Coroa 2,68-2,73, abaixo de 3:1 pelo fundo dourado, já aceita e anotada como pendência do Cenário); o ganho extra da 3D, que vinha de ser mais clara, se foi, mas valia menos que a identidade.
- §4: nada de recompensa, flash ou tremor.

**Veredito: APROVADO.**

---

## dir2/arte-gpt — 8916611 (delta de 118cb99: Sophia 3D na parada)

**Medido:** li o diff (`character_art.gd` 6 linhas, `sophia_recipe.json`, `build_frames.py`, `hero_qa.gd`, doc) e vi `_caps\arte\loco3d\p_idle_golpe.png`, `p_idle_corrida.png` e `z_zoom.png`. Não rodei o HeroQA nem o jogo; os contrastes são os do dono.

**Jogo / reversão:** a mudança de código é mínima e segura. `idle` aponta para `s20` (12 quadros, 6 qps), a pintada fica em `idle_pintado` (troca de nome = volta). `walk3d` só roda por `play_action` e `persist` até `stop_action()`; nada do `player.gd` muda.
Risco de pose presa: se uma cena chamar `walk3d` e esquecer o `stop_action`, ela fica andando; hoje ninguém a chama no jogo (só o HeroQA), então é só para a encenação futura. `ready` (até 1,8 s depois de lutar) segue pintado, então o 3D só aparece em parada longa (entre ondas, diálogo, mapa).

**R18:** atendida: 2,71-3,09 -> 3,23-3,79:1 nas 9 telas, inclusive as duas da Coroa, que antes ficavam em 2,7-2,85. É o melhor ganho de legibilidade da sequência (e sem mexer no halo).

**O pulo de estilo (a pergunta do chefe): é REAL, e não é pequeno.** No zoom lado a lado: o 3D perde o cabelo branco com a mecha azulada e ondulado (fica cinza liso e parado), o rosto muda (mais liso, de render), os braços e o torso engrossam (mais frontal e musculosa), o manto fica mais rígido. A pose de corrida e de golpe seguem
finas, de perfil, com o cabelo solto: o corpo "vira outra pessoa" na parada. Onde dói: (1) em cada começo de luta, parada (3D, 3/4 para frontal) -> `ready`/golpe (pintado, perfil); (2) ao fim da luta, `ready` pintado -> 1,8 s -> parada 3D (um pop sem transição); (3) nos diálogos e no mapa, que são onde a jogadora mais olha para ela parada.
O que ameniza: altura e pé batem (256,0-256,8 x 256,0-256,5), luminância média igual (131), o contorno fino é o mesmo, e a parada só aparece depois de 1,8 s de calma, então não pisca durante o combate.
**Meu juízo:** não fere a LEGIBILIDADE (silhueta, altura e contraste estão iguais ou melhores; o estado "parada" é lido). Fere a COERÊNCIA de identidade (cabelo e anatomia), que não é R18 mas é a queixa original do dono ("parece outra arte"). Como é reversível em uma linha e o ganho de R18 é concreto, **aceito para o playtest decidir**, desde que o playtest
pergunte isso de forma explícita ("a Sophia parada parece a mesma que corre e bate?"). Se a resposta for não, a saída barata é voltar `idle` para `idle_pintado` e manter só o `walk3d`; a saída boa é repintar o cabelo do 3D (branco com mecha azulada, ondulado) e afinar o torso para casar com o resto.
Não vi o cabelo se mexer (o vento do shader só age sobre a máscara; o doc diz que a máscara é a mesma): conferir em movimento.

**§4:** nada de recompensa, tremor ou flash novo. R16 ok.

**Veredito: APROVADO COM RESSALVAS** (entra). Ressalvas: pulo de estilo cabelo/anatomia, a decidir no playtest (reversível); `walk3d` sem `stop_action` prende a pose; cabelo em movimento não visto.

---

## 3.2.1 — chefes6 0e8d761 e polimento7 b087740 (reauditorias curtas)

**Medido:** importação do 0e8d761 sem `SCRIPT ERROR`/`Parse Error` (`_caps\guardiao\p12_import.txt`); li os commits PRÓPRIOS (os `a...b` vêm sujos de merges da integração); vi `_caps\chefes6\aneis68_antes_cima_depois_baixo.png`.

- **chefes6 0e8d761 (só `final_battle.gd` + doc): APROVADO.** `_hud_safe(p)` empurra o centro do Anel para y >= 104 (base 640x360) na faixa do medalhão, com entrada suave entre x 290 e 250, e a linha da órbita usa o mesmo desvio.
  Só muda o Y de DESENHO: os Anéis não são alvo nem perigo; as larvas nascem em `Vector2(pos.x, arena_center.y)` (só o X do Anel vale), então a luta, o alcance e a curva não mudam. Os outros usos de `_ring_pos` são as cenas (`release_rings`, o Anel da Coroa voltando),
  que só ficam mais limpas. Na prancha antes x depois os Anéis deixam de encostar em "Névoa do Sono" e seguem à vista, por baixo do medalhão, sem cobrir Sophia nem chefe. R18 ok (HUD legível); sem efeito em R21.
- **polimento7 b087740: APROVADO.** Os 3 commits próprios mexem só em `tools/combate/rule_probe.gd` (a RuleProbe passa a conferir a soma da R16: mesmo alvo soma, outra cor cria, desligado não cria) e em `POLIMENTO7.md`. Nenhum arquivo de jogo.
- **FlashParryProbe (intermitência): não vi.** Rodei 5x seguidas (headless, sem `--fixed-fps`, máquina quase parada) no 0e8d761: 5/5 `QA RESULT: 0 falhas`, 17 PASS cada (`p12_fp1..5.txt`). A falha única do dono é compatível com o que já anotei: a sonda mede flashes pelo relógio de parede
  e fica sensível a carga da máquina (validate em paralelo). Não é regressão de código; se voltar, rodar de novo com a máquina livre.

**Vereditos:** chefes6 0e8d761 APROVADO; polimento7 b087740 APROVADO.

---

## dir6/chefes6 — 213d292 (reauditoria do delta de db14a1a: um commit)

**Medido:** importação sem `SCRIPT ERROR`/`Parse Error` (`_caps\guardiao\p11_import.txt`); li o diff de `boss_armupiel.gd` (só ele muda no código) e vi `_caps\chefes6\novos2\v2_s64_juizo_sheet.png` e `v2_s64_replica_sheet.png`. Não rodei BossProbe.

- **Pegadinha da Réplica: FECHADA.** A postura só defende e arma a Réplica quando `lit_t() >= 0,3 s` (`_stance_lit()`); antes disso o golpe entra como dano normal (o Juízo está se acendendo), e não conta como pressão (`not _in_stance()`).
  A 1ª Réplica da luta tem `wind` 0,45 s e as demais 0,32 s (`_replicas_done`, contador por instância: cada tentativa nova de luta recomeça com o preparo longo, leniente). Resto do desenho (guard_rec, volta à postura 1x) intacto.
  Efeito: o golpe que já estava no buffer quando ele crava o espadão não castiga; quem bate depois de acesa recebe a faísca dourada e um aviso de 0,45 s na 1ª vez. Os 0,32 s seguintes ficam como padrão aprendido (aceito).
- **Desenho final: CONFERIDO.** Nas recapturas a lâmina e a meia-cúpula ficam SEMPRE do lado da Sophia (quadros 3 a 6, ela troca de lado e a cúpula acompanha), 3 pontas de coroa sobre a cabeça, faísca/anel dourado na defesa.
  A Réplica mostra o contorno vermelho pulsando por ~3 quadros antes do anel largo dourado, e a Sophia sai jogada para longe (quadro 6). Legível.
- Nada novo em §4 (sem sorteio, sem timer). Sons próprios continuam pendentes (Áudio); `mask_light` emprestado.

**Veredito: APROVADO.** Resta só o pedido de som e o playtest humano do timing de 0,32 s.

---

## dir6/chefes6 — db14a1a (delta de 61645f7: Juízo da Coroa, Pústulas/Estouro/Recuo/Jorro, Galila/Yabel, final 11 s)

**Medido:** importação do db14a1a sem `SCRIPT ERROR`/`Parse Error` (`C:\gnosis-wt\_caps\guardiao\p10_import.txt`); li o diff completo de `boss_armupiel.gd`, `boss_belias.gd`, `boss_brain.gd`, `boss_tuning.gd`, `final_battle.gd` e o
CHEFES6.md; vi as folhas `_caps\chefes6\novos2\*_sheet.png`. **As capturas são das 00:59 (estado do fcf0f43); o db14a1a (01:05) é que faz a postura girar com a Sophia.** Nas folhas do Juízo a lâmina e a
meia-cúpula aparecem do lado OPOSTO à Sophia, que é o bug que o db14a1a corrige. Pelo código a correção está certa (`_signature` vira `_stance_fx.dir` e o `scale.x` para o lado da Sophia, e `_from_front` usa esse `dir`),
mas o desenho final eu NÃO vi. Não rodei BossProbe (longo, não determinístico, o dono avisa ±15-25 %); os tempos (Coroa 57->75 s agressivo, Praga 65->76 s) são os do dono.

**Juízo / Réplica (Armupiel): legível, mas com uma pegadinha de 1ª vez.**
- Aviso: bom. Forma própria (lâmina dourada de pé + meia-cúpula + 3 pontas de coroa), faísca DOURADA ao defender (diferente da azul do "armado"), som `mask_light` (emprestado até o Áudio entregar o próprio) e 1,85 s de postura antes de qualquer perigo.
  Quem espera ganha ele exposto 1,1 s (x1,35): recompensa por leitura, determinística (§3 ok).
- Punição: proporcional (`dmg` 1,0 x base 0,38, tremor 0,35 padrão, joga longe 460; fase 3 soma 2 ondas de 0,45). A recuperação da Réplica é guarda (`guard_rec`), então quem apanhou não ganha janela de graça. Volta à postura 1x, máx. 2 Réplicas. Sem sorteio.
- **RESSALVA principal (justiça):** (a) a defesa e o gatilho da Réplica valem desde o INÍCIO da `wind` de 0,35 s, mas o brilho leva 0,3 s para acender; (b) o Juízo é escolhido exatamente quando a Sophia está colada e martelando (3 golpes
  fora da janela, ou `escape_hits` 4) e o golpe seguinte dela já está no buffer (o hitstop guarda a entrada, de propósito); (c) a Réplica sai 0,32 s depois, imparável, contra uma esquiva de 0,24 s de i-frames e um tempo de reação humano de
  ~0,2-0,25 s. Resultado: na primeira vez é quase certo apanhar sem ter tido chance de ler, e depois dela ainda é difícil de esquivar; o jogo ensina por castigo. É o risco que o próprio doc anota ("parecer contra-ataque injusto").
  **Correção barata:** só armar a Réplica depois da postura acesa (>= 0,3 s do início); golpe que cai antes disso é só defendido (faísca dourada, sem Réplica) e já vira o aviso. Ou `wind` da 1ª Réplica 0,32 -> ~0,45 s.
  O restante (a postura, o expor, o `guard_rec`) pode ficar.
- O contador `_pressure` (3 golpes fora da janela) é escondido, mas só escolhe O QUE ele faz (a postura), que se anuncia sozinha; não pune por si. Aceito (não é o tipo de §4 "contador punitivo escondido").

**Pústulas / Estouro / Recuo / Jorro (Belias): LEGÍVEL E JUSTO.**
- Pústulas: 1 bolha por golpe fora da janela, de 1 a 4, desenhadas no dorso (forma, não só cor); a 4ª e o inchaço pulsam rápido. Teto fixo, sem prazo, sem sorteio; as janelas (recuperação, atordoado, murcho) não enchem nada.
  Não decaem com o tempo, mas só sobem por escolha da jogadora e ficam À VISTA. §4 ok: não é contador escondido.
- Estouro: `wind` 0,65 com contorno de 100 px no chão (sair dele = salvo), dano 0,9 + veneno + empurrão 320, uma vez; depois ele fica MURCHO exposto 1,3 s: aviso claro, punição proporcional, recompensa por esperar.
  O Estouro NA HORA (bater com as bolhas cheias): `wind` 0,45, mesmo contorno, sem murcho e peste 1,4 s em volta dele. Mais apertado (colada, ela precisa sair de 100 px em ~0,2 s úteis ou esquivar), mas o aviso é longo e visível
  (4ª bolha pulsando, `no_touch`) e o jogador que viu já parou. Aceito; se o playtest reclamar, 0,45 -> 0,55 s.
- Recuo + Bote: acionado por 3 golpes em 2,5 s (padrão visível), salta para trás deixando uma poça de 28 px (onde ele estava) e emenda o Bote vermelho de 0,7 s: justo. Poça sem som (`silent`), sem aviso próprio, mas de raio pequeno e
  tique de 0,7 s, não pega quem está a ~60 px.
- Jorro: 3 círculos de 32 px com 0,7/0,8/0,9 s de aviso, dano 0,45: justo (e é a lição do Raio do Rei).
- Som próprio (`pus_grow`/`pus_burst`, `stance_crown`) ainda pendente; R11 fica parcial (forma ok, som emprestado).

**Galila/Yabel, final:** Galila 38->34 e Yabel 28->25 golpes-alvo (o próprio doc diz que era vida, não padrão); forma caída da final se refaz em 11 s (era 9; o aviso de 2,5 s fica). R21 ok (menos preso em ciclos de refazer;
médio da final 218 -> 169 s). Tudo determinístico, sem golpe novo.

**§4:** sem sorteio, sem timer, sem clarão novo, sem câmera lenta; 1 tremor padrão na Réplica; dois chefes mexidos juntos (§4.13): só o playtest do João fecha.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: (1) Réplica quase inevitável na 1ª vez (armar só depois da postura acesa); (2) capturas anteriores à correção da postura que gira, desenho final não visto; (3) sons próprios pendentes; (4) Estouro por toque a 0,45 s, ajustar se o playtest reclamar.

---

## dir2/arte-gpt — 118cb99 (delta próprio de 1b1c69f: a3569eb, e9746eb, 99b4d08, 118cb99; 4 arquivos de código/doc)

**Medido:** li o diff (`painted_flex.gdshader`, `character_art.gd`, `contrast_probe.gd`) e as capturas do dono (`_capsrte
18in2_*_off/on.png`, 640x360, rim desligado x ligado). Recortes 5x meus:
`C:\gnosis-wt\_caps\guardiao\p9_fin2_{3,40,58,68}.png`. Não rodei o ContrastProbe de novo (os números 3,0-3,2 são os do dono); não vi em movimento.

**O que muda:** o rim interno da Sophia pondera dois raios (70 % no meio raio, 30 % no raio cheio): `HERO_RIM` 1,6, `HERO_RIM_PX` 3,0 (~1 px de tela); halo de fora igual (`HERO_HALO` 0,25, `halo_px` 1,6).
A 1ª tentativa (0,9 com raio 6) lavava as botas e o chefe a reprovou: o dono refez como fio. Boa decisão (a pintura vale mais que o número).

**R18:** 7 de 10 telas em 3,0-3,2 (3 Torpor 3,16, 13 3,11, 22 3,15, 31 3,11, 40 3,01, 49 3,10, 66 3,19); **Coroa 57/58 2,85/2,67 e Mente 68 2,33 abaixo de 3:1** (fundo claro dourado/roxo atrás). Evolução
(1b1c69f 2,75-2,97 -> 3,0-3,2) é real e a leitura nas capturas confirma a silhueta separada. Aceito abaixo da meta (o resto é do fundo, não da Sophia); mantém-se como pendência do Cenário.

**Faixa pálida / pintura:**
- Corpo, manto, cabelo: **sem lavagem.** O fator `dark` apaga o rim onde a pintura é clara; interior das botas e da calça igual ao "antes" no zoom 2x do dono e nos meus recortes.
- **Cajado: clareia, e nas telas frias dessatura.** Como ele tem 1-2 px de largura, TODO o miolo cai no "fio" e é escuro (ocre), então recebe a luz cheia: tela 3 (Torpor) (81,67,32) -> (148,145,109);
  tela 58 (73,52,16) -> (171,139,72); tela 40 (86,66,29) -> (174,154,117). Não é uma "faixa" larga, é uma linha de 1 px que passa de ocre escuro a ouro pálido (na tela fria, quase cinza-dourado). Lê como luz
  batendo no metal e separa o cajado do fundo (bom para R18), mas é o ponto onde a cor da pintura mais muda. Ressalva menor: se o playtest achar o cajado "branco", limitar o rim por
  largura local (por ex., reduzir quando `c.a - mn` já satura nos 2 raios) ou tingir menos o rim nas telas de Éon frio. Botas ganham um contorno creme discreto (visível a 5x, discreto a 1x).
- **Tremulação:** pela leitura do shader, não há termo temporal além do vento do cabelo/manto, que desloca o `uv` do pixel central e dos vizinhos juntos; o fio acompanha a malha. Cor do rim fixa por tela
  (`eon_light`). Sem pulso, sem flash (R10 ok). "Provável sem tremulação, conferir em movimento": linha de 1 px pode cintilar um pouco no subpixel como qualquer arte 1 px, e só o jogo mostra.
- §4: sem truque, sem aviso por cor, nada de recompensa; R16 não afetada.

**Veredito: APROVADO COM RESSALVAS** (entra). Ressalvas: Coroa 2,67-2,85 e Mente 2,33 < 3:1 (fundo; Cenário), cajado mais pálido nas telas frias (conferir no playtest), movimento não verificado.

---

## dir6/progressao6 — 68bcaea (delta de 3d13bbd: um commit; 20 arquivos, 8 de código)

**Medido (sonda `guardiao_sonda` no 68bcaea, headless, sem som):** importação sem `SCRIPT ERROR`/`Parse Error`; **ProgQA 62 `QA PASS`, 0 falhas** (+4 novos);
**TecnicoQA 43 PASS** (morte REAL no Arconte 19 -> antessala 18 com 100 de carteira e 30 da tela: 70 faíscas; "Continuar" do disco volta com 70; travessia 17 -> 15).
Logs: `C:\gnosis-wt\_caps\guardiao\p8_progqa.txt`, `p8_tecnico.txt`, `p8_import.txt`. Não rodei o ProgBot (longo) nem o jogo com janela.

**Ressalvas do 3d13bbd:**
- **Chave do baú secreto: FECHADA.** `chest.gd:102` usa `"bau:%d%s" % [screen, ":s" if secret else ""]`; `secret` é o `var` do próprio baú (l. 12), definido antes de abrir. Os dois baús da mesma tela pagam.
- **Aviso quando o `claim_once` nega: FECHADA.** `claim_once_or_notice` (baú, Selo, Adormecido) e `notice_claimed()` em `run_manager._grant_reward` (recompensa de camada). Vai pelo `toast` do HUD
  (grupo `hud`, `hud.gd:150/341`), que enfileira se houver cena/pausa e não cobre card nem diálogo; sem HUD (mapa) tenta de novo 1x/s por até 6 s. Sem clarão nem som (R10/R21 ok).
  Risco pequeno: se um HUD da tela ANTIGA ainda existir durante a troca de cena, o aviso pode cair nele e sumir; o caso é raro e o efeito é só o aviso não aparecer.

**Morte leva SÓ as faíscas ganhas na tela (decisão do chefe): CORRETA e dentro da §3/§4.**
- Fiação conferida: `add_orbs(+)` soma em `screen_gain` (já com a Pérola); `RunManager.screen_changed` zera, e ele é emitido em TODA troca (início de run, avançar, `choose_node`, `continue_run` e
  `respawn_at_checkpoint`), então uma 2ª morte na mesma tela não cobra de novo o que já saiu. `death_loss()` = `clampi(screen_gain, 0, orbs)`: nunca passa da carteira, e gastar na loja primeiro só
  reduz a perda (o gasto consome o saldo antigo; a conta bate). A recompensa do mapa é paga ANTES do `screen_changed`, então não conta como ganho da tela; o suborno do Arconte (+80) CONTA, e morrer
  nessa tela o devolve (antes era lucro líquido, agora não). Só vale com run ativo (`level.gd:_on_player_died` já separa o fora-de-run). Não é salvo: "Continuar" abre com 0 (leniente).
- §4: sem sorteio, sem timer, sem FOMO; a perda é anunciada, determinística e do que a própria tela rendeu. Resolve as 3 queixas do meu antecessor (não recupera, tom de checkpoint, pune quem guarda).
- A fala da morte agora diz a regra ("A tela recomeça, e as faíscas dela também. N faíscas escorrem da tua mão aberta."). Boa. Só aparece quando `lost > 0`, e "a tela" é aproximação: o checkpoint
  pode estar 1 a 3 telas atrás (offsets 0/4/7 do Éon), então o trecho inteiro recomeça. Aceitável.
- **Observação (não bloqueia):** na prática a morte deixou de ter custo econômico: perde o ganho da tela e REPAGA em dobro ao refazer, e as telas de trás do checkpoint pagam inimigo de novo
  (até ~3 telas, cerca de 840 faíscas). Morrer de propósito rende ~125/min contra ~214/min seguindo em frente, então não há incentivo a "farmar morte"; o custo da morte é só o tempo, o que é
  exatamente a opção "mínimo risco" que eu tinha oferecido. Vale o chefe saber que a barra de balanço (BALANCE r7) foi medida com bot que não morre de verdade e fica intacta.

**Edições fora da área (delegação do chefe): MÍNIMAS E CORRETAS.**
- `level.gd`: 1 linha (`lost := Progression.death_loss()`) + comentário; o resto de `_commit_death` intacto.
- `narrative.gd` + `01_narrative_a.tsv` + `en_table.gd`/`en.po`/csv: 1 fala, chave nova (`d0115e`), tradução em inglês fiel; a antiga só sobra em `_orfas.csv` (lista de órfãs, gerada).
- `tecnico_qa.gd`: `screen_gain = 30` + `morte_custa_faiscas_da_tela` (70) nos 2 pontos; o teste continua exercitando a morte real (confirmei rodando). Só o cabeçalho do arquivo ainda diz "-20% de faíscas".
- Nada de efeito colateral em combate, áudio ou arte.

**Nits (consertar quando passar por lá):** comentários velhos "-20%" em `run_manager.gd:92`, no cabeçalho do `tecnico_qa.gd` e no doc `PROGRESSAO6.md` (§ do bot, "a morte custa 20% das faíscas").

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: só os comentários velhos e a observação de que morrer agora não custa faíscas de verdade (decisão do chefe; o playtest dirá se a morte "pesa").

---

## dir7/polimento7 — 28d8df7 (delta de 0ba25d8: um commit)

**Medido:** li o código e as capturas `C:\gnosis-wt\_caps\polimento7\esgotado\` (telas 38 e 48, `depois` × `v1_escuro`).

**Minhas 2 ressalvas do 0ba25d8:**
- **(1) `_desired_x` ainda o afastava: FECHADA.** `_process_chase` agora sai logo se `_summon_exhausted`, ANTES do ramo `moves` e do legado: ele
  desacelera até parar, vira para a Sophia e não tem golpe nenhum (nem tiro, nem recuo, nem passo). O doc agora diz exatamente isso. É uma janela de
  punição clara (competência), sem número escondido.
- **(2) escuro some no fundo escuro: FECHADA.** A cor sai por dessaturação (`grade_sat` 0,08) com luz x2 (cinza CLARO), mais um sopro e uma fumaça
  leve contínua (10 partículas, alfa 0,5). Nas capturas, na tela 48 (fundo verde escuro) o corpo é um cinza claro que salta do cenário e na 38
  (fundo claro) continua legível; a fumaça é discreta, quem carrega a leitura é o cinza. É estático, sem pisca (R10).
- **Ramo órfão do `Gnosis.boss_card("campeao")`: FECHADO** (passa `sting = false`; agora nada toca `boss_appear` para Campeão, por nenhum caminho).
- Efeito no jogo: bot nas telas com invocador -7,5 % do tempo (era -9 %), dano tomado 7740 -> 6637, run 93,6 -> 89,6 min, quase-mortes 208 -> 179. Nota
  do doc: a tela 35 passou a dar timeout por um cornudo colado, sorteio e não o invocador.

**Veredito: APROVADO.**

---

## dir6/chefes6 — 82454b2 (delta de 8d00636: 5eeea79, 04c46e0, 9bf99e2, 846314d, d439998, 82454b2; 463c148 é merge da integração)

**Medido no 82454b2 (worktree de sonda, headless):** importação sem `SCRIPT ERROR`; ReiProbe nas telas 10 (Athoth) e 46 (Astaphaios), logs
`C:\gnosis-wt\_caps\guardiao\arc_t10.txt` e `arc_t46.txt`: Athoth parado cobre 88 % do desenho, 22 % da caixa fora, 0 atravessa, 0 apelão;
Astaphaios cobre 78 %, 26 % fora, 1 golpe a 55 px ainda atravessa (a ponta do cajado toca a ponta do véu, como o doc admite), 0 apelão. Não rodei o
BossProbe de curva (longo); li os números do dono.

**Checagem:**
- **BodyBox do Sono e do Espelho (~33 % da caixa fora): ACEITÁVEL.** O número é de ÁREA e o desenho deles é rendado (véu em tiras, fiapos); o que
  decide a justiça é a faixa do cajado: pano sem dano 25,5 -> 7,0 px (Sono) e 18,9 -> 7,8 (Espelho), sobra por linha de 2,6 a 2,8 px, e o contorno
  do polimento7 já tinha 26-28 % fora. Na faixa onde a Sophia bate, o "acerta o ar" é de 2-3 px por lado, abaixo do que o olho vê. R18 atende (o que se vê
  fere), com a ressalva do 1 golpe a 55 px no Espelho.
- **Guarda alta (04c46e0): JUSTA E SINALIZADA, com uma ressalva.** `guard_up` escala o dano que o chefe SOFRE no neutro (x0,55 a 0,7) e armado (x0,35 a
  0,45) e a postura (x1,3 a 1,5); a punição cheia fica nas janelas (recuperação, golpe exposto, atordoado, aparo). É a mesma lógica de janelas que já
  existia (0,5/0,5/0,85), só mais dura, e a leitura tem sinal: toda vez que o golpe é reduzido sai o `ImpactBurst` azul pálido em vez do acerto
  dourado (`filter_damage`). Quem espera a hora sente pouco (médio 1,5 a 2,5 min; final 155 s); quem martela cai de 33 s para 76-87 s, e o bot
  agressivo continua curto em Coroa/Praga (~57-60 s, o doc admite). Boa direção: premia o padrão certo, é competência (SDT), não vira vida inflada.
  Risco de frustração: no neutro ele agora aguenta só 55-70 % do dano, e o jogador novo no Harmas (tela 19) vê a faísca azul mas pode não entender o
  porquê. Mitigação barata: uma dica no 1º chefe ("o Arconte se protege enquanto ataca: bata quando ele recuperar"), ou um som de guarda no acerto armado
  (hoje só a cor muda; §4.11, cor não deve ser o único aviso).
- **Forma caída se refaz em 9 s (era 14): ATENDE com RESSALVA.** O desenho é bom (derrubar as duas juntas; ela volta mais fraca e o prazo sobe 3 s por
  refeita, R21 converge). Mas não há aviso visível da contagem: só o toast no momento da volta (`final_revive`) e o tremor 0,6. Em 9 s o jogador não
  sabe quanto falta; um brilho que cresce na forma caída nos últimos ~2,5 s tornaria isso um telegrafo (R5), não uma surpresa.
- **Dano ajustado à vida da curva (~390): ATENDE.** Belias 0,45 -> 0,55, Armupiel 0,27 -> 0,38, Rei-Mentira e Colosso 0,38 -> 0,48, coerente com a vida e a arma Nv.5
  que a Progressão entrega. O médio no final dá 2 quase-mortes (antes 7): menos frustração, e a luta é mais longa (155 s) mas não infinita. Bom.
- **Chefe encenado intocável (Galila antes do gatilho): ATENDE.** `filter_damage` devolve 0 quando `can_process()` é falso; o mesmo mecanismo que o rugido e a
  morte já usavam. É correção de bug (a fase trocava fora do quadro). Sem aviso visual de "imune", o que é aceitável para um chefe congelado em cena.
- **Chefe colado na parede volta ao meio (Colosso): ATENDE, com um bug leve.** O override novo de `chase()` roda DEPOIS do `if e.rooted_timer > 0: dir = 0`,
  então um chefe preso pela Corrente da Lei dentro da margem da parede caminha para o meio e "sai" da prisão. Correção mínima: `and e.rooted_timer <= 0.0`
  nas duas condições novas.
- **R1 a R4, R10:** nenhum tremor, flash ou som novo. **§3:** nenhuma recompensa mexida.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: (1) aviso visível antes de a forma caída se refazer; (2) o root não pode ser anulado pelo
empurrão da parede; (3) dar um segundo sinal (som/dica) ao golpe "armado" da guarda alta.

---

## dir7/cenario7 — 1b1c69f (delta de ba91602: c4963ee, dbae0df, 05b69b7, 2fa2c49, 477768b, 861d62a, 1b1c69f; fc1a811 é merge)

**Medido no 1b1c69f (worktree de sonda):** importação sem `SCRIPT ERROR`. Não refiz a medida de contraste do dono (`ProbeBg` + `contrast_r18.py`, 10 telas). Li
`scenery.gd` (`LaneHalo`), a CENARIO7.md e as capturas do dono (`C:\gnosis-wt\_caps\cenario7\final\`), e tirei 4 capturas minhas com o HdShot (janela mínima 320x180
fora da vista, `--audio-driver Dummy`) em `C:\gnosis-wt\_caps\guardiao\c7s_*.png` (Espelho e Coroa, Sophia em 2 posições).

**O que muda:** fundos HD (far, mid, asas, chão) nos 9 Éons, só a variante `_a`; véu escuro na faixa de luta; `LaneHalo` (elipse macia de raio 58 x 84 px lógicos, miolo
chato até 36 %, alfa 0,66 a 0,72 por Éon, cor do ar do Éon escurecida, z -1: atrás dos lutadores, segue a Sophia, some com ela); halo das plataformas vira elipse
aditiva (QA7 #22, o retângulo claro do Espelho some). Nada de combate, som, tremor, flash nem economia.

**Checagem:**
- **R18: MELHORA MUITO, continua PARCIAL.** Do dono: 1,58-2,40 -> 2,75-2,97 : 1 nas 10 telas (as minhas anteriores, 2,06/2,37/1,71 nas telas 3/30/57, vão para 2,89/2,82/2,78).
  Ainda abaixo de 3:1. O dono já viu o teto: o fundo imediato está em ~0,013-0,029 de luminância e escurecer mais não sobe a razão (a borda dela cai junto). O alfa 0,84 foi
  rejeitado por virar bolha no Espelho e na Coroa: decisão certa (beleza e honestidade acima do número).
- **Espelho (fundo lilás claro): a sombra resolve e não vira bolha, com uma ressalva de movimento.** Na captura minha, Sophia em combate no meio do Espelho: o fundo
  atrás dela escurece em névoa, sem borda dura, e ela (branca e dourada) salta do cenário; o contorno dos inimigos também lê. Em foto parada a sombra parece
  profundidade de ar, não recorte. Risco que só o playtest decide: ela é colada à Sophia enquanto o cenário anda em parallax, então em movimento pode ler como
  uma nuvem escura que segue o corpo; a borda longa e o alfa limitado ajudam, mas é onde eu olharia primeiro.
- **Coroa (estátua dourada atrás de Sophia clara): NÃO CONFIRMADO.** Nas capturas do dono (tela 58) a Sophia está sobre o entulho e o chão escuro, e nas minhas ela
  ficou escondida atrás de inimigos; nenhuma tem a Sophia DIANTE da estátua dourada, que é o caso que o chefe temia. A razão medida na 57/58 (2,78/2,75) é a mais baixa
  da tabela depois do Espelho. Pendente: uma captura com ela na frente da estátua (HdShot `x=` na tela 57/58, `nohud`, sem inimigos: `solo`) antes de dar por
  fechado. Não bloqueia.
- **Inimigos:** o `LaneHalo` não vai neles (certo: em onda cheia escureceria a faixa toda), e o contraste deles contra o fundo novo não foi medido (o doc admite). Nas
  capturas eles seguem legíveis pelo contorno próprio.
- **R10 / §4:** tudo estático, sem pulso nem flash; sem recompensa nem aleatoriedade (os fundos variam por tela de forma determinística). Atende.
- **Peso:** o doc cita só a variante `_a` por memória e a validate verde (14). Não medi desempenho.

**Veredito: APROVADO COM RESSALVAS** — entra. Ressalvas: R18 ainda < 3:1 (falta a borda da Sophia); conferir a Coroa com a Sophia diante da estátua; olhar o halo
em movimento no playtest.

**OPINIÃO sobre pedir à Arte borda da Sophia +0,02-0,03:** a favor, com cuidado no ONDE. (1) O gargalo é mesmo do lado dela: o fundo já está no piso, e o doc do dono mostra
que +0,02 de luminância de borda passa de 3:1. (2) Suba a luz de recorte INTERNA (`HERO_RIM`, hoje 0,6, só nas bordas escuras) e NÃO o halo de fora (`HERO_HALO`, 0,25):
foi o halo que fez a faixa pálida no cajado e o filete nas botas (de546f8 -> 50f807a). (3) O ganho só existe porque o fundo atrás dela está escuro; se a Sophia sair
do `LaneHalo` (por exemplo, no ar acima da névoa), um rim mais forte numa borda já clara contra fundo claro pode até baixar o contraste, então confira o cajado
e a saia branca contra o céu do Espelho. (4) +0,02-0,03 de luminância é pequeno o bastante para não "colar um adesivo"; peça à Arte para repetir o
`contrast_r18.py` nas mesmas 10 telas e a captura do cajado ampliada, como fiz em r18. (5) O número é uma proxy: 3:1 na borda de 2 px não é percepção; se subir de
2,9 para 3,0 sem a Sophia ler melhor, não vale mexer mais.

---

## dir6/chefes6 — 61645f7 (delta de 82454b2: db313fd, ba5ffb1, 61645f7)

**Medido:** li o código (não rodei: o delta é de 3 trechos curtos e já tenho a base do 82454b2 na sonda).

- **Guarda alta, 2º sinal (db313fd): ATENDE, com uma observação.** `sfx("block")` no acerto armado, limitado a 1 a cada 0,25 s por `_t` (tempo de jogo), só se
  o som existe no CATALOG, com variação de tom (`block` está em `JITTER_FAMILIES`) e anti-spam de 40 ms do mesmo nome. Fecha a minha ressalva (cor não pode ser o
  único aviso, §4.11). Metralhadora? No pior caso (martelando sem parar) sai ~4 por segundo, junto do som do golpe; é o jogador que mais precisa do sinal, mas 4/s
  é perto do que a §4.7 chama de cansativo. Se o playtest reclamar: 0,25 -> 0,4 s. Não bloqueia.
- **Aviso de 2,5 s antes de a forma se refazer (ba5ffb1): ATENDE.** Luz que cresce e se fecha na forma caída (círculo 18 -> 64 px, anel branco que se fecha de 70 -> 30 px,
  núcleo) + `charge_king` UMA vez (guardado em `_warned`, só se existe no CATALOG), apagado quando ela volta. Fecha a minha ressalva R5 (telegrafo da contagem).
  R10: o pulso vai de 1,6 a 3,8 Hz, mas modula só 25 % do alfa de um círculo de até 64 px (não é tela cheia); aceitável, sem flash cheio.
- **Root não é anulado pela parede (db313fd): FECHADA.** O empurrão para o meio só vale com `rooted_timer <= 0`.
- **Espelho a 55 px mantido (61645f7):** a sonda mede o raspão de 4 pontos na ponta do véu; concordo em não inflar a caixa (piorava o apelão). É o resíduo que eu já aceitava.

**Veredito: APROVADO.** (Observação de 0,25 -> 0,4 s do `block` só se o playtest reclamar.)

---

## BILHETE PARA O SUCESSOR (atualizado 29/10, antes da pausa)

**Quem sou:** Guardião da Satisfação. Worktree `C:\gnosis-wt\guardiao` (branch `dir7/guardiao`, push em `origin/dir7/guardiao`). Reporto SÓ ao chefe (relatório curto, o limite que ele pedir, normalmente <= 3 linhas). Commit em português, termina com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
**Ler ao começar:** `C:\gnosis-wt\_REGRAS.md`; `docs/handoff/NEURO_SATISFACAO.md` (R1-R22, §3, §4); `C:\gnosis-wt\_caps\dublagem\REGRAS_GUARDIAO.md` (dublagem, 22 regras); este doc (índice no topo, o mais novo em cima).

**Método:** (1) `git fetch`; auditar o delta PRÓPRIO (`git show <commits do dono>`; `a...b` vem sujo de merge da integração). (2) ler código e doc do dono. (3) rodar só o indispensável, headless, `--audio-driver Dummy`, sem janela. (4) escrever a seção, a linha no índice, commit e push. (5) relatório curto. Honesto: "li" x "rodei"; a IA não ouve (áudio só por análise de arquivo).
**Sonda:** worktree destacado `C:\gnosis-wt\guardiao_sonda`: `git checkout -q -f --detach <commit>`, importar com `Godot --headless --audio-driver Dummy --path ... --editor --quit` (3-10 min com atlas grandes; rode em segundo plano), depois a sonda. Godot em `C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`.
Sondas: `tools/progressao6/ProgQA` (62 PASS), `tools/tecnico/TecnicoQA` (43 PASS), `tools/combate/FlashParryProbe` (SEM `--fixed-fps`; 5/5 PASS, sensível a carga), `tools/chefes6/ReiProbe -- out=<p> tag=<x> tela=<N>` (na tela 68 mede o Colosso, não o Rei), `tools/audio/VoiceProbe` (0 falhas), `tools/cenario7/HdShot`.
Medidas de atlas: ler `assets/painted/derived/{sophia_frames,bosses/rei_frames}.json/png` e alinhar os quadros pela âncora (capuz/tronco/barra/base) para provar "sem borracha".
Pastas: capturas e logs meus em `C:\gnosis-wt\_caps\guardiao\` (`p7-p16_*`, `lote\`, `atl\`).

**Estado (29/10):** todos os branches da Onda 7 e 3.2.x têm veredito no índice. Entrou/aprova: progressao6 68bcaea, arte-gpt 118cb99/8916611/a238686 (parada r4), Rei v11/nítido/HD (9ad0b06, 63f597a, 64e92cf), chefes6 213d292/0e8d761/b587064/1c4b0c7, polimento7 b087740, audio7 b655563 (infra de dublagem), dublagem-lote 4920893 (11 falas).

**PENDENTES que eu cobraria:**
1. **R18:** Coroa 2,67-2,85 e Mente 2,33 abaixo de 3:1 (fundo; Cenário). Halo do Cenário em movimento e a borda da Sophia: só o playtest.
2. **Rei HD:** +190 MB de VRAM (testar em 4 GB), 4 de 8 trocas de pose secas, dano/morte/cenas na pintura antiga; Rei da tela 68 ao lado do Colosso.
3. **Chefes:** Réplica 0,32 s (playtest humano); sons próprios da postura/bolhas/Estouro (Áudio); `block` 0,25 -> 0,4 s só se reclamarem; Estouro por toque 0,45 s.
4. **Dublagem:** atribuição Apache-2.0 do Qwen3-TTS nos créditos; caudas de reverb 263-361 ms (> 250 ms do contrato); `A Voz` do king_fall CER 0,103; vozes EN (hoje voz PT + legenda EN); nenhuma fala de COMBATE gravada ainda (guardas de 8 s/6 por tela só foram testadas pela sonda); o Rei da final com legião 4-5 e grito é do ouvido do João.
5. **Progressão:** a morte agora só leva o ganho da tela (sem custo real): ver no playtest se "pesa"; ritmo da arma (~27 telas no Nv.3).
6. **audio7/perigos7 (antigos):** `hz_tide_tick` a 300 ms (espaçar para ~600 ms se reclamarem).
7. **FlashParryProbe:** falhou 1x para o dono (carga); não vi em 5 rodadas.

**Armadilhas:**
- `claim_once` e `LaneHalo` só se avaliam bem rodando o jogo; sem rodar, marque "provável, conferir".
- Tabelas de atlas estáticas (`LUMA_K`) pedem `tools/combate/flash_luma.py` de novo se a Arte repintar atlas.
- Nunca chame de "aprovado" sem ver o delta PRÓPRIO. Capturas do dono podem ser anteriores a uma correção (aconteceu com a postura do Juízo): confira o horário do commit.
- Não toque no worktree do dono nem faça merge; não deixe processo Godot rodando.

---
