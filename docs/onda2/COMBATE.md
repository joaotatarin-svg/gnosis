# Onda 2 — COMBATE (branch `dir2/combate`) — relatório

Continuação do agente derrubado às 06:05. O anterior deixou ~10 arquivos sem commit. Revisei tudo,
corrigi 2 regressões que ele tinha criado, commitei em passos e terminei as tarefas do brief.

## 1. Commits (base `integracao/onda1`)
- `b018762` Juice: hitstop por peso, chute, slow-mo em rampa, flash_strength, reduce_flashes
- `aac9596` Câmera: look-ahead/enquadramento no alvo, trava de margem, zoom 1,2, tremor contínuo, snap()
- `47ec3cf` Vida: misericórdia oculta + REVISAO #11
- `29fb6de` Hitbox: um impacto por golpe + um VFX por alvo no ponto de contato
- `03c8b5d` VFX: brilho de aviso, screen_flash com Reduzir flashes, prewarm
- `3b0568c` Orbes: chegadas em fila, spark + hud.spark_orb_arrived na chegada
- `e83393f` Fase B em player/enemy (R1, R4, R5, R8, R10, A4, interpolação, gancho fase 2)
- `c21e66c` Orbes sem órbita, todo orbe entrega; projétil tremor 0,2; vida herdada mínimo 1; sonda do prewarm
- `b3a9108`, `4f1198d` (+ uid) sondas; `50957e3` pedidos; `8536db0` COMBATE.md
- `eda97ae` **BLOQUEANTE (achado do Balance)**: o golpe que mata não sobrescreve mais DEAD com HURT. Antes a forma
  revivível da tela 68 ficava com vida 0 em HURT, o `revive()` não fazia nada e a batalha final não tinha como ser vencida.
- `138d4fa` **Achado ALTA do revisor**: hitstop medido em tempo de PASSO (timer que ignora o time_scale), não
  no relógio de parede. Antes, com `--fixed-fps`, um hit_stop(0.1) durava milhares de quadros e mudava a cada rodada.

## 2. O que mudou
`scripts/autoload/juice.gd`, `scripts/fx/camera_shake.gd`, `scripts/components/health_component.gd`,
`scripts/combat/hitbox.gd`, `scripts/fx/{impact_burst,vfx_library,spark_orb,projectile}.gd`,
`scripts/entities/{player,enemy}.gd`, sondas novas em `tools/combate/` (OrbProbe, PrewarmProbe,
DeathProbe), `docs/COMBATE.md`, `docs/pedidos/onda2_combate.md`.

Corrigi no que o anterior deixou:
- `enemy.gd` chamava `Audio.play_sfx("tell_unblock"/"tell_parry")`, nomes fora do catálogo → AudioQA
  reprovava. Tirei; pedi os sons ao Áudio.
- O slow-mo de finalização passou a valer para `attacker == null` (magia **e** as ferramentas de QA):
  o resultado do encontro 3 do CodexQA chegava tarde → "resultado e pausa do encontro 3" FALHOU.
  Voltei a exigir golpe da Sophia (`attacker is Player`); magia não ganha slow-mo extra.
- `heal()` não revive mais: o `player.gd` herdava `carry_health` e curava 30 %. Um carry 0 faria a
  Sophia nascer "morta sem morrer". Agora o mínimo é 1.
- Orbes: 1–2 de cada 9 entravam em órbita e sumiam sem chegar (o HUD perderia contagem). Agora a
  curva fecha conforme a atração cresce, e depois de 2,2 s o orbe entrega de qualquer jeito.

## 3. Provas (fora do git, em `/home/user/caps/combate/`)
- **Sonda da câmera** (`CombatCamProbe`, telas 3/8/10/22/50, `--fixed-fps 60`):
  antes `fora=1 borda=16 minx=-1` (tela 10: 0/0) → depois **`fora=0 borda=0 minx=38`** em todas.
  CSV em `antes/probe*.csv` e `depois2/probe*.csv`.
- `cmp_tela10_hurt.png`: antes a Sophia está FORA do quadro (só a sombra na borda, A5); depois aparece.
- `sheet_combo_antes.png` × `sheet_combo_depois.png` (tela 3, combo): antes a Sophia fica fora da tela
  na maioria dos quadros; depois está em todos.
- `cmp_tela10.png`, `cmp_tela22.png`, `cmp_tela3.png`: presença (§2.3) com zoom 1,2: a Sophia fica
  ~20 % maior.
- `depois/tele/zoom.png` (tela 22): brilho de aviso amarelo aparece antes do golpe; flash de dano da Sophia.
- **DeathProbe** (`res://tools/combate/DeathProbe.tscn`): misericórdia segura o 1º golpe fatal (vida=1),
  só uma vez; heal não revive; dano negativo não cura; morta no ar: `y 219 → 286, no_chao=true,
  anim=dead` (antes: congelava em y=219, A4). 0 falhas.
- **OrbProbe**: 9/9 orbes chegam em todos os casos (antes 7–8/9); passo típico 55–65 ms.
- **PrewarmProbe**: ~12 ms, nenhum tremor, o nó some sozinho.
- **repro_revive** (`godot ... -s tools/combate/repro_revive.gd`, copiado do Balance): antes do conserto
  `depois do golpe: hp=0 estado=HURT` e `revive → hp=0 HURT`. Depois: `hp=0 estado=DEAD` e
  `revive(0.45) → hp=369 STAGGER`.
- **HitstopProbe** (`--fixed-fps 60`, 2 rodadas idênticas): `hit_stop(0.1)=7 quadros` (6 + 1 da contagem),
  extensão = 7, `slow_mo(0.25,0.6)` + rampa = 47 quadros, a escala volta a 1,00.

## 4. Validação (`TIMEOUT=900 tools/validate.sh --full`)
Rodada final, depois de todos os commits:
```
Scripts        OK        21s  pass=0  code=0
ScriptCheck    OK         4s  pass=0  code=0
CodexQA        FALHOU    17s  pass=32  code=1   | QA FAIL: diretório de save independente  (falso conhecido, override.cfg)
AudioQA        FALHOU     5s  pass=23  code=1   | QA FAIL: duck(): música -4.4 dB          (bug conhecido do Áudio)
GnoseQA        OK        22s  pass=18  code=0
SaveQA         OK         1s  pass=13  code=0
PuppetQA       OK         2s  pass=0  code=0
HeroQA         OK        56s  pass=0  code=0
WaveQA         OK        12s  pass=0  code=0
CodexPlaytest  OK        36s  pass=1  code=0
```
As duas falhas são as mesmas da base. No meio do caminho o código do anterior também reprovava
"resultado e pausa do encontro 3" (CodexQA) e "tell_unblock" (AudioQA). As duas foram consertadas.

## 5. O que não ficou bom / não testei
- Se a zona tranca com a Sophia colada na parede, ela fica a ~40 px (de 640) da borda: a trava não
  mostra além da parede. Antes ela SAÍA do quadro.
- Inimigos pintados de escuro quase não mostram o tingimento de 45 % do telegrafo. O que avisa de
  fato é o brilho (estrela). Ainda está sem som (falta `tell_*` no Áudio).
- Espaçamento dos orbes: no headless, com a máquina carregada, às vezes passa de 100 ms. Medido em
  tempo real, ainda não no jogo rodando no PC.
- Interpolação de física: não liguei (é no `project.godot`) e não testei a 144 Hz.
- Feel (hitstop, chute, vibração, rampa do slow-mo): os números estão em constantes; quem decide é
  o playtest do João.
- Nada de GIF `--follow`: só folhas de quadros.
- Ainda usam o relógio de parede, mas só no visual/som (não mexem na jogabilidade nem no bot): fila de
  chegada dos orbes, limite de flashes (≤ 3/s), pulso do telegrafo, vibração da vítima e voz de dor
  (≤ 1 a cada 250 ms).
- Ferramentas: com "heal não revive", uma ferramenta que cura a Sophia todo quadro (o modo god do
  `store_shot`) não levanta mais uma Sophia já morta. Só afeta ferramenta: ela precisa curar ANTES da
  morte ou usar `health.current_health = ...` direto.

## 6. Pedidos (`docs/pedidos/onda2_combate.md`)
- Técnico: `reset_mercy()` ao trancar a zona, chamar `VfxLibrary.prewarm(self)` na fase,
  `snap()`/reset de interpolação nos teleportes da fase, da Provação e do shot.gd, ligar
  `physics_interpolation`, campo `ComboData.hitstop`. A espera de 0,65 s no CodexQA é frágil.
- Áudio: sons `tell_parry`/`tell_unblock`. Tirar "spark" do crédito, porque o orbe já toca na
  chegada. Escutar `Juice.slowmo_changed`.
- UI: `hud.spark_orb_arrived()` e a opção "Reduzir flashes" ligada em `Juice.reduce_flashes`.
- Animação-Chefes: sinal `attack_impact` e as metas `impact_at`/`hurt_power` no visual.
