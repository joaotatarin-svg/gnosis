# Pedidos do chefes6 (Onda 6) aos outros diretores

Branch `dir6/chefes6`. Os chefes agora têm CÉREBRO (`scripts/entities/bosses/`):
3 fases (66 % / 33 %), golpes por fase, postura, repulsão, perigos telegrafados
(`BossHazard`), plataformas da arena criadas pelo próprio chefe. A vida vem de
`BossTuning.boss_health()` = golpes-alvo × golpe médio da Sophia na tela.

## Para o inimigos6 (dono do resto de `enemy.gd`) — CONTRATO DOS GANCHOS
Mexi o mínimo no `enemy.gd` fora das funções de chefe. Por favor, PRESERVE
estas linhas se reorganizar o arquivo (todas comentadas com `# chefes6`):
1. `_ready()`: `_boss_setup()` logo depois de `player = get_tree()...`.
2. `_process_chase()`: 1ª linha `if brain != null and brain.chase(delta): return`.
3. `_begin_windup()`: o pisca do Silêncio fase 2 só vale com `brain == null`.
4. `_begin_strike()`: depois de `attack_impact.emit()`: `if brain != null and brain.strike(): return`.
5. `_process_strike()`: `if brain != null: brain.strike_tick(delta)` (o `elif` é o charge antigo).
6. `_on_hit_received()`: antes do bloco `armored`: `damage = brain.filter_damage(...)` (0 = ignora o golpe);
   a checagem de fase virou `if is_boss_enemy and not health.is_dead() and _boss_phase_check(): return`
   seguida de `if brain != null and not brain.flinch(damage, launcher_hit): return` (POSTURA: chefe não
   recua a cada cutucada).
7. `_kit_passive()`: com cérebro, delega para `brain.passive(delta)`.
Minhas funções no fim do arquivo: `_boss_setup`, `_boss_phase_check`, `_enter_phase2` (legado),
`_enter_phase(n)`, vars `brain`, `phase_marks`. Uso de vocês (só leitura/chamada): `_begin_windup`,
`_blink_to`, `_separation`, `_flash`, `_summon`, `_minions`, `armored`, `attack_hitbox`, `_orb`,
`_art_scale`, `eye_color`, `wind_up/strike_time/recover_time`, `attack_style`, `rooted_timer/slow_timer`.
Se renomearem algum, me avisem (ou ajustem `scripts/entities/bosses/boss_brain.gd`).
- `Projectile` e `HazardZone` não foram alterados (uso Projectile como está).

## Para o combate6
1. **Dano da Sophia**: a vida dos chefes lê a tabela de golpes (`GameContent` combos) — se mudarem
   os números lá, os chefes acompanham. O bônus por nível de arma hoje é `(wl-1)*6` (player.gd);
   se mudar, exponham `const WEAPON_DMG_STEP` em `player.gd` e eu leio sozinho.
2. Opcional: `var nojump_timer: float` em `player.gd` (se > 0, não pula/não pula duplo). O Yabel
   (zonas mudas) usa se existir; senão eu corto a velocidade de subida por fora (funciona, mas é feio).
3. A misericórdia oculta continua intacta (não mexi).

## Para o progressao6
- Publiquem `Progression.expected_weapon_level(tela) -> int` (nível de arma esperado ao chegar em cada
  chefe com a economia nova). Hoje uso a tabela `BossTuning.EXPECTED_WL` = Rei 1 · Athoth 2 · Harmas 2 ·
  Galila 3 · Yabel 3 · Astaphaios 4 · Belias 4 · Armupiel 5 · final 5. Se a economia de vocês der
  outro ritmo, ou mudem lá (eu leio) ou me digam os números.

## Para o level6
- Telas de chefe: a ARENA é montada pelo chefe (plataformas que sobem por fase, perigos). Mantenham a
  tela de chefe LIMPA (sem plataformas fixas) — `_build_platforms` já pula telas de chefe; por favor
  não mudem isso. Se quiserem dar cara à arena (parede de fundo, pilares decorativos), ok, desde que
  não tenham colisão no miolo (centro ± 470 px). As plataformas dos chefes ficam a 62 px e 118 px do
  chão (alcançáveis com o pulo simples; o pulo duplo só facilita).

## Para o narrativa6
- Falas de **fase 3** (legenda sem pausar, 1 linha, tom de filho ferido): crie
  `Narrative.archon_phase3(boss_id) -> Array` no mesmo formato de `archon_phase2`. `enemy._enter_phase(3)`
  chama se existir. Sugestões (ajuste à vontade):
  Athoth "Só mais um pouco... deixa eu dormir só mais um pouco." · Harmas "Ainda tenho fome. Sempre." ·
  Galila "Se eu soltar... quem me segura?" · Yabel "(um fio arrebenta; um som, quase uma palavra)" ·
  Astaphaios "Qual de nós é o reflexo?" · Belias "Está bem. Está bem. Só mais uma vez, então." ·
  Armupiel "De pé, corte! ...De pé..."

## Para o ui5 (HUD)
- A barra de chefe desenha o marcador só em 50 %. Agora há 3 fases: o Enemy expõe
  `phase_marks: Array` (ex.: `[0.66, 0.33]`). Desenhem um marcador por item e "FASE III"/medalhão "III"
  quando `phase >= 3` (`boss_phase(3)` já é chamado).

## Para o Áudio
- `boss_phase2` toca em toda troca de fase (2 e 3). Se fizerem um `boss_phase3`, troco. A música sobe
  o pitch 3,5 % por fase (`Audio.set_music_pitch`) — se tiverem camadas por fase, me digam a API.

## Para o integrador de ARTE (dir2/arte-gpt) — MORTE DE CHEFE = MOMENTO
Feedback do João: "só desmonta no final; acaba murcha". Agora a morte de todo chefe com cérebro
(não vale para as formas revivíveis da batalha final enquanto a outra está de pé) segue uma
SEQUÊNCIA em tempo real, e o Enemy emite `signal boss_dying(step: int)`:
| passo | tempo (s reais) | o que o jogo faz | estado/quadro |
|---|---|---|---|
| 0 impacto | 0,35 | hitstop 0,2 + câmera lenta 0,3× por 1 s + tremor + flash branco + música abaixa | STAGGER → quadro `hurt` |
| 1 cambaleia | 0,55 | flash quente + vibração | `hurt` segurado |
| 2 colapso | 0,95 | `estate = DEAD` → quadros `dead` (de joelhos/desmoronando) | `dead` |
| 3 pausa | 0,60 | nada (silêncio, corpo caído) | `dead` |
| 4 desintegração | — | `_on_died` normal: `boss_die`, recompensa, `defeated`, quadro de morte 0,4 s e gibs | `dead` → some |
O chefe NÃO é removido antes do passo 4. Para os fragmentos de pintura em luz: ouçam
`boss_dying(4)` (ou troquem `_burst_gibs`/`_death_pose_then_burst`, que são de vocês/do inimigos6).
Se quiserem outros tempos, mudem `BossBrain.DEATH_STEPS` comigo.
