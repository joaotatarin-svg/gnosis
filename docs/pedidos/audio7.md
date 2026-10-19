# Pedidos do Áudio7 (Onda 7) aos donos dos pontos de chamada

Todos os sons abaixo JÁ EXISTEM (arquivo + CATALOG, AudioQA verde). Falta só a chamada, de uma linha, no
arquivo de cada dono. **Regra:** UMA chamada por evento. Onde o pedido diz "TROCAR", tire o som genérico; não
toque os dois por cima (NEURO R4). O aviso `tell_*` dos telegrafos continua como está: o som próprio do perigo
ou do golpe soma com ele, não o substitui (R5: o ouvido aprende o aviso padrão).

Sem posição = `Audio.play_sfx(nome)`. Com posição (inimigo, perigo, projétil) = `Audio.play_sfx_at(nome, pos)`,
que dá o pan pela tela (R14). Números de linha conferidos em `origin/integracao/onda1` @ 4cfd64c.

**NÃO precisa chamar (o Áudio liga sozinho por sinal):**
- morte do chefe em 5 passos (`Enemy.boss_dying`);
- janela do contra-ataque (`Player.riposte_window_opened`);
- dom do Soter (`Progression.double_jump_granted`);
- relíquia equipada (`Progression.relics_changed`);
- conquista (`Achievements.unlocked`);
- cue `sink` do roubo.

Não acrescentem chamada para esses eventos; se acrescentarem, o som dobra.

---

## inimigos6 (`enemy.gd` fora do kit de chefe, `projectile.gd`)
1. **Golpe por tipo (cobre TODO o repertório, um ponto só).** `enemy.gd` `_strike_move()` (~1808), 1ª linha
   depois de `var kind := ...`: `Audio.move_sfx(_mv, "strike", global_position)`.
   O tipo resolve o som: combo, investida, bote, pancada, onda, leque, rajada, teleguiado, arco, coluna,
   lâmina rasteira, agarrão, mergulho, planar, invocação, tiro de cima (`air`).
2. **Aparecer atrás.** `_start_move()` (~1775), logo antes de `_blink_to(...)`:
   `Audio.move_sfx(mv, "wind", global_position)`, que toca `atk_blink`.
3. **Voador cai ao ser atingido.** `_on_hit_received` (~1219), quando `_downed` passa de 0 para > 0 (só na
   borda, não a cada golpe): `Audio.play_sfx_at("fly_fall", global_position)`. O mesmo vale para `stagger()`
   (~1279), quando derruba um voador.
4. **Campeão entra.** `_boss_intro_fx()` (~333), TROCAR:
   `Audio.play_sfx("champion_enter" if is_champion and not is_boss_enemy else "boss_appear")`.
   O stinger de chefe fica só para chefe; ele libera a música de chefe (R9).
5. **Fúria do Campeão.** `_champion_fury_check()` (~2077), junto do VFX:
   `Audio.play_sfx_at("champion_fury", global_position)`.
6. **Tiros inimigos.** Com o item 1, o golpe de tiro já soa no strike. Em `projectile.gd:55`, toquem
   `proj_fire` só nos tiros da Sophia (os hostis ficam mudos no nascimento). Isso evita dois sons por tiro (R4).

## chefes6 (`scripts/entities/bosses/**`, kit em `enemy.gd`)
1. **Golpe de chefe (assinaturas).** `boss_brain.gd`:
   - `_start(m)` (~420), depois de `e._begin_windup()`: `Audio.move_sfx(m, "wind", e.global_position, true)`;
   - `strike()` (~243), antes de `_on_strike(mv)`: `Audio.move_sfx(mv, "strike", e.global_position, true)`;
   - `_leap_land(h)` (~455), junto da nova: `Audio.move_sfx(mv, "land", e.global_position, true)`.

   A tabela id → som está em `audio_manager.gd` (`BOSS_MOVE_SFX`); o AudioQA confere que os 55 golpes dos
   scripts têm som. Golpe novo sem entrada cai no som do tipo (melee/slam/charge/shot/cast/leap).
2. **Fase 3.** `enemy.gd` `_enter_phase(n)` (~1009), TROCAR:
   `Audio.play_sfx("boss_phase3" if n >= 3 else "boss_phase2")`.
3. **Quebra de guarda.** `boss_brain.gd` `flinch()`, no ramo da quebra (~286, junto de `stun(BREAK_STAGGER)`):
   `Audio.play_sfx_at("guard_break", e.global_position)`.
4. **Olho do Rei (ponto fraco).** `boss_rei.gd` `_on_eye_hit()` (~125), junto do VFX:
   `sfx("eye_hit", e._orb.global_position)`.
5. **Ondas pelo chão do chefe.** `boss_brain.gd` `ground_wave()` (~543), 1 vez por chamada:
   `sfx("atk_wave", e.global_position)`.
6. **Perigo de chefe.** `boss_hazard.gd`:
   - golpe (~77, depois de `struck.emit()`): `_tell_sound("hz_column")`;
   - serra (`look == "saw"`), ao nascer: `_tell_sound("hz_saw")`.

   `_tell_sound` só toca o que está no CATALOG, então pode chamar sem medo.
7. **Rei: cargas (com o VFX7).** Quando o Rei carrega um tiro, use `charge_king` (ver VFX7 abaixo).

## level6 (`scripts/entities/hazards/**`)
Linhas do mapa feito na varredura. A coluna "evento novo" precisa de uma flag de borda (bool) onde o código
ainda não tem; está marcado.

| Perigo | Onde | Chamada |
|---|---|---|
| maré escura | `dark_tide.gd:41` (acorda) | TROCAR `fog_swell` → `hz_tide_wake` |
| maré escura | `:58` (tique de dano) | `hz_tide_tick` |
| guilhotina | `guillotine.gd:60` (cai) | TROCAR `hit_heavy` → `hz_guillotine` |
| guilhotina | sobe (borda nova em `c >= STUCK_END`, ~41) | `hz_winch` |
| boca | `maw.gd:43` (morde) | TROCAR `hit_heavy` → `hz_maw_bite` |
| boca | `:34` (aviso) | SOMAR ao `tell_unblock`: `hz_maw_warn` |
| feixe | liga (borda nova st==2, ~42) / desliga (`:40`) | `hz_beam_on` / `hz_beam_off` |
| plataforma-reflexo | aviso (`mirror_platform.gd:69`, borda w>0) / troca (`_apply` :61, não no `force`) | `hz_mirror_warn` / `hz_mirror_flip` |
| névoa | `mist_patch.gd:30`, borda ao passar de THICK (subindo) | `hz_mist_breath` |
| pêndulo (corrente) | `pendulum.gd:45` | TROCAR `swing_heavy` → `hz_chain_swing` (style "chain") |
| badalo (sino) | `:45` (style "bell") | `hz_bell_toll` no lugar do `swing_heavy` |
| badalo apaga o Éter | `:59-61` | `hz_ether_drain` |
| campo de silêncio | entra `silence_field.gd:29` / sai (borda nova, :30) | TROCAR `cast_fail` → `hz_silence_in` / `hz_silence_out` (o `cast_fail` ao tentar magia lá dentro continua no player) |
| campo de silêncio | Éter drenando (:31) | `hz_ether_drain` (anti-spam próprio 0,4 s: pode chamar por quadro) |
| pedra que afunda | começa `sinking_platform.gd:57` / some `:67` / volta `:70` | `hz_sink_start` / TROCAR `land` → `hz_sink_gone` / `hz_sink_return` |
| lanças / grilhões | `spear_trap.gd:56` | TROCAR → `"hz_shackles" if style == "shackles" else "hz_spears"` |
| esporos | incha (borda nova SWELL_AT ~61) / estoura `:69` / destruída `:47` | `hz_spore_swell` / TROCAR `cast_praga` → `hz_spore_burst` / `hz_spore_pop` |
| cacos (Centro) | sombra nasce `shard_fall.gd:36` / começa a cair (borda WARN, ~39) / quebra `:55` | `hz_shard_warn` / `hz_shard_fall` / TROCAR `shard` → `hz_shard_impact` |
| totem | arma `summon_totem.gd:55` / invoca `:126` / atingido `:74` / destruído `:88` | `hz_totem_arm` / TROCAR `portal_open` → `hz_totem_summon` / TROCAR `chest_hit` → `hz_totem_hit` / TROCAR `seal_solved` → `hz_totem_break` |
| luz do Adormecido | drenando `ward_light.gd:61` / apaga `:65` / resistiu `:44` | `hz_ward_drain` (pode por quadro) / TROCAR `cast_fail` → `hz_ward_out` / TROCAR `sleeper_wake` → `hz_ward_saved` |
| altar | cura `sanctuary_altar.gd:40` | TROCAR `sleeper_wake` → `hz_altar` |
| altar (opcional) | presença, a cada ~2 s com a Sophia a < 200 px e altar não usado | `hz_altar_hum` (anti-spam 1,5 s) |
| marca do segredo | acende (`secret_mark.gd:25`, borda `_has_dj`) | `hz_secret_mark` |
| sala secreta / selo | quando a porta/selo abrir (ainda não há lógica em `secret_vault.gd`) | `hz_secret_open` |

## combate6 (`player.gd`)
1. **Pulo duplo.** `_double_jump()` (432), TROCAR `jump` → `Audio.play_sfx("double_jump")`. É o anel de luz
   do Soter.
2. **Queda Estelar carregando.** Golpes aéreos (542): `Audio.play_sfx("star_charge" if heavy else "swing_air")`.
   Hoje toca `dive` na saída; `dive` passa para o mergulho de verdade, quando a carga acaba e ela despenca.
3. **Queda Estelar pousa.** No pouso (650-654), junto da `AoeNova`: `Audio.play_sfx("star_impact")`. É camada
   de estrelas a −17, POR BAIXO da `nova`; não é outro baque (R4).
4. **Contra-ataque.** `_start_riposte()` (~845), quando o golpe sai: `Audio.play_sfx("riposte")`, no lugar do
   swing do pesado nesse golpe. O "agora!" (`riposte_ready`) já toca sozinho pelo sinal.
5. **Aparo perfeito.** `parry` continua; o `riposte_ready` soma por cima, pelo sinal. Nada a fazer.

## mapa6 (`world_map.gd`)
1. Abrir: `_ready` (55), `CodexStyle.pop_in(_canvas, "ui_open", ...)` → TROCAR por `"map_open"`.
2. Escolher nó: `_confirm` (233 e 236), TROCAR `ui_confirm` → `map_select`.
3. Nó trancado: `_confirm` (228), TROCAR `ui_back` → `map_locked`.

## ui5/ui6 (`hud.gd`) e progressao6 (`upgrade_menu.gd`)
1. **Selo aberto.** `hud.gd` `_check_seal` (~870), junto do `toast(msg)`: `Audio.play_sfx("shop_seal")`.
   Toque 1 vez por selo; o reexibir depois da troca de cena (191) fica mudo.
2. **Relíquia equipada.** `upgrade_menu.gd` `_equip_relic` (321): TIRAR o `shop_buy`. O `relic_equip` já toca
   pelo sinal `relics_changed`. Na compra (`buy_relic`), o `shop_buy` continua e o `relic_equip` soma por cima,
   de propósito: comprar e vestir.
3. **Conquista.** Nada a fazer (sinal). Não ponham som no `_on_achievement` do HUD.

## level6/narrativa6 (`level.gd`)
1. **Objetivo da zona.** `_arm_objective` (617), junto do `toast`: `Audio.play_sfx("zone_objective")`. Só
   quando há mensagem (totem/proteger).

## narrativa6 (`staging.gd`)
1. **Roubo.** O cue `sink` agora toca `king_sink` + `crack_open` (0,5 s depois). Nada a fazer. Se a rachadura
   da Staging (756) abrir muito antes ou depois disso, me digam o atraso real e eu ajusto `CRACK_DELAY`.
2. (Opcional) O laço de tremor de 6 passos (760-765) pode chamar `Audio.play_sfx("boss_step", -1, -6)` por
   passo. Hoje está mudo.

## VFX7 (pedido dele: cargas antes do tiro)
- `charge_light`: carga da Sophia (luz). ~0,6 s, cresce até o disparo.
- `charge_dark`: carga dos Arcontes e criaturas (treva que inspira). ~0,6 s.
- `charge_king`: carga do Rei (luz roubada). ~0,9 s, mais largo.

Chamada: `Audio.play_sfx_at("charge_dark", pos)` no INÍCIO da carga. O som foi feito para durar o telegrafo
de ~0,6 s. Se a carga for bem mais longa ou mais curta, me digam a duração e eu refaço.
