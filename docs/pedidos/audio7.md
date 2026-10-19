# Pedidos do Áudio7 (Onda 7) aos donos dos pontos de chamada

Todos os sons abaixo JÁ EXISTEM: arquivo, CATALOG e AudioQA verde.

## O que JÁ TOCA sem ninguém mexer
Ganchos do `audio_manager.gd`: sinais existentes e o observador `_Watch`, que olha o estado público dos nós e
toca só na BORDA. Nos itens abaixo **NÃO acrescentem chamada**: o som dobraria (R4).

- **Inimigos:** golpe de cada tipo no WINDUP→STRIKE (`atk_*`, pelo `_mv.kind`) e "aparecer atrás" no WINDUP.
- **Voadores:** derrubado no ar (`fly_fall`). **Campeão:** fúria (`champion_fury`).
- **Chefes:**
  - golpe-assinatura no telegrafo e/ou no golpe (`bs_*` pela tabela `BOSS_MOVE_SFX`);
  - pouso do salto (`bs_land`), quebra de guarda (`guard_break`), olho do Rei (`eye_hit`, pela hurtbox do olho);
  - morte em 5 passos (sinal `boss_dying`).
- **Sophia:** 2º pulo (`double_jump`), Queda Estelar carregando (`star_charge`), pouso da Queda (`star_impact`,
  camada sob a `nova`), janela do contra-ataque (`riposte_ready`) e golpe do contra-ataque (`riposte`).
- **Objetivo e progressão:**
  - objetivo da zona: totem ou luz armados (`zone_objective`, mais `hz_totem_arm`);
  - selo aberto (`shop_seal`, quando o HUD sobe `_tier_seen`);
  - relíquia (`relic_equip`), conquista (`achievement`), dom do Soter (`soter_gift`).
- **Perigos que eram MUDOS:**
  - feixe liga/desliga, plataforma-reflexo troca, névoa respira, pedra começa a afundar/volta;
  - esporo incha, caco (sombra e queda), saída do campo de silêncio, marca do segredo acende;
  - guilhotina sobe, tique da maré, luz do Adormecido drenando.
- **Roubo:** cue `sink` = `king_sink` + `crack_open`.

O observador lê as propriedades com `get()`. Se renomearem `estate`, `_mv`, `brain.mv`, `_downed`,
`_champ_fury`, `_air_jumps_left`, `windup_timer`, `dive_landed`, `_riposte_t`, `_armed`, `_tier_seen` ou os
campos dos perigos, o evento fica MUDO (sem erro): avisem o Áudio. Quem preferir chamar direto, me avise, que
eu tiro o evento do observador.

## O que falta: TROCAR o som genérico (o observador não faz isso sem dobrar)
Formato: `arquivo:linha função` → chamada. "TROCAR a → b" = apagar a chamada de `a` e pôr a de `b` no
mesmo lugar. Linhas de `origin/integracao/onda1` @ 4cfd64c.

### chefes6 (`scripts/entities/bosses/**`, `_enter_phase` em `enemy.gd`)
1. `enemy.gd:1009 _enter_phase(n)`: TROCAR → `Audio.play_sfx("boss_phase3" if n >= 3 else "boss_phase2")`.
2. `boss_hazard.gd:77` (logo depois de `struck.emit()`): `_tell_sound("hz_column")`. Para `look == "saw"`, ao
   nascer: `_tell_sound("hz_saw")`. `_tell_sound` só toca nome do CATALOG.
3. (opcional) `boss_brain.gd:543 ground_wave()`: `sfx("atk_wave", e.global_position)`, 1 vez por onda.

### polimento7 / inimigos (`enemy.gd` fora do kit, `projectile.gd`)
1. `enemy.gd:333 _boss_intro_fx()`: TROCAR → `Audio.play_sfx("champion_enter" if is_champion and not is_boss_enemy else "boss_appear")`.
   O stinger de chefe libera a música de chefe (R9) e não deve tocar para Campeão.
2. `projectile.gd:55 _ready()`: tocar `proj_fire` SÓ nos tiros da Sophia. Nos hostis, o golpe de tiro já soa
   no strike pelo observador (`atk_shot`/`atk_fan`/`atk_homing`/`atk_shot_air`). Hoje são 2 sons por tiro.

### polimento7 / combate (`player.gd`)
1. `player.gd:432 _double_jump()`: TIRAR `Audio.play_sfx("jump")`. O `double_jump` (anel de luz) já toca pelo
   observador.
2. `player.gd:542`: TROCAR `Audio.play_sfx("dive" if heavy else "swing_air")` → `if not heavy: Audio.play_sfx("swing_air")`.
   Na Queda Estelar, o `star_charge` já toca pelo observador.
3. `player.gd:~850 _start_riposte()`: o swing do pesado desse golpe pode ficar; o `riposte` (lâmina) soma por
   cima. Se soar cheio demais no teste, TIREM o swing dele.

### perigos7 (`scripts/entities/hazards/**`)
| Onde | TROCAR / acrescentar |
|---|---|
| `dark_tide.gd:41` | TROCAR `fog_swell` → `hz_tide_wake` |
| `guillotine.gd:60` | TROCAR `hit_heavy` → `hz_guillotine` |
| `maw.gd:43` / `maw.gd:34` | TROCAR `hit_heavy` → `hz_maw_bite` / SOMAR ao `tell_unblock`: `hz_maw_warn` |
| `pendulum.gd:45` | TROCAR `swing_heavy` → `"hz_chain_swing" if style == "chain" else "hz_bell_toll"` |
| `pendulum.gd:59-61` (o badalo apaga o Éter) | `Audio.play_sfx("hz_ether_drain")` |
| `silence_field.gd:29` (entra) | TROCAR `cast_fail` → `hz_silence_in`. O `cast_fail` de tentar magia lá dentro é do player e continua. A saída já toca pelo observador. |
| `silence_field.gd:31-33` (Éter escorrendo) | `Audio.play_sfx("hz_ether_drain")`; pode chamar por quadro (anti-spam de 0,4 s) |
| `sinking_platform.gd:67` (some) | TROCAR `land` → `hz_sink_gone` |
| `spear_trap.gd:56` | TROCAR → `"hz_shackles" if style == "shackles" else "hz_spears"` |
| `spore_pod.gd:69` / `:47` (destruída) | TROCAR `cast_praga` → `hz_spore_burst` / `hz_spore_pop` (o `enemy_hurt` do `:46` só nos golpes que não matam) |
| `shard_fall.gd:55` | TROCAR `shard` → `hz_shard_impact` |
| `summon_totem.gd:126` / `:74` / `:88` | TROCAR `portal_open` → `hz_totem_summon` / `chest_hit` → `hz_totem_hit` / `seal_solved` → `hz_totem_break` |
| `ward_light.gd:65` / `:44` | TROCAR `cast_fail` → `hz_ward_out` / `sleeper_wake` → `hz_ward_saved` |
| `sanctuary_altar.gd:40` | TROCAR `sleeper_wake` → `hz_altar` |
| `secret_vault.gd` (quando a porta/selo abrir; hoje não há lógica) | `hz_secret_open` |
| (opcional) `sanctuary_altar.gd` `_physics_process`, altar não usado e Sophia a < 200 px | `hz_altar_hum` (anti-spam 1,5 s) |

### UI do integrador (`world_map.gd`, `upgrade_menu.gd`)
1. `world_map.gd:55 _ready`: `CodexStyle.pop_in(_canvas, "ui_open", …)` → `"map_open"`.
2. `world_map.gd:233` e `:236 _confirm`: TROCAR `ui_confirm` → `map_select`.
3. `world_map.gd:228 _confirm` (nó trancado): TROCAR `ui_back` → `map_locked`.
4. `upgrade_menu.gd:321 _equip_relic`: TIRAR `shop_buy` (o `relic_equip` toca pelo sinal `relics_changed`). Na
   compra (`buy_relic`), o `shop_buy` continua.
5. NÃO ponham som no toast do selo, da conquista nem do objetivo: já tocam.

### narrativa (cenas)
1. Nada obrigatório: o roubo (`sink`) já está no `Audio.cue`. Se a rachadura da Staging (`staging.gd:756`)
   abrir muito antes ou depois de 0,5 s, me digam o atraso e eu ajusto `CRACK_DELAY`.
2. (opcional) `staging.gd:760-765`, laço de tremor de 6 passos: `Audio.play_sfx("boss_step", -1, -6)` por passo.

### vfx7 (cargas antes do tiro: pedido dele)
`Audio.play_sfx_at("charge_light" | "charge_dark" | "charge_king", pos)` no INÍCIO da carga.
- **light:** Sophia, ~0,6 s;
- **dark:** Arcontes e criaturas, ~0,6 s;
- **king:** o Rei, luz roubada, ~0,9 s.

Se a carga durar bem mais ou menos que isso, me digam a duração e eu refaço.
