# Brief — COMBATE (dir2/combate)
Leia: REGRAS_NUVEM.md, docs/COMBATE.md INTEIRO (Fase A §2–§6 com código pronto; Fase B §7 com linhas), docs/handoff/NEURO_SATISFACAO.md, docs/QA_UX_BUGS.md (A4, A5), docs/handoff/REVISAO.md #11, docs/ANIMACAO.md (não quebrar os quadros da Sophia).

ARQUIVOS SEUS: scripts/entities/player.gd, scripts/entities/enemy.gd, scripts/autoload/juice.gd, scripts/fx/{camera_shake,spark_orb,projectile,impact_burst,aoe_nova,hazard_zone,damage_number,gib,vfx_library}.gd, scripts/combat/*, scripts/components/*, scenes/entities/*, tools/combat_cam_probe.gd, novos em tools/combate/, docs/COMBATE.md, docs/onda2/COMBATE.md.
NÃO: character_art/painted_library/boss_puppet, level.gd, hud.gd, audio_manager, project.godot, options_menu.

TAREFAS (commit a cada passo):
1. Câmera §2 (look-ahead no alvo; offset só tremor/chute). Sonda: `godot --headless --audio-driver Dummy --fixed-fps 60 --path . res://tools/CombatCamProbe.tscn -- <tela> [csv]` telas 3, 8, 10, 22, 50 antes/depois, meta fora=0 borda=0 (A5). Presença §2.3 com capturas.
2. Juice R2/R3/R8/R10: `reduce_flashes`, `signal slowmo_changed(active, scale)`, flash_strength, kick, hitstop_active.
3. Hitbox: um impacto por golpe (§3.4).
4. Misericórdia oculta (§4, aprovada) + reset_mercy(); REVISAO #11 (heal não revive, dano negativo não cura).
5. Orbes R6: na chegada `Audio.play_sfx("spark")` e call_group("hud","spark_orb_arrived") só se existir.
6. reset_physics_interpolation() nos teleportes (§6).
7. Fase B (§7) em player/enemy: R1, R5 (+ bug do _flash que apaga o telegrafo), R4, R10, R8 etc.; A4 (morta cai até o chão + anim de morte); gancho enemy._enter_phase2 → Gnosis.captions(Narrative.archon_phase2(type_id)) se chefe e run ativo; impact_at/hurt_power se simples.
8. `VfxLibrary.prewarm(parent)` (o chefe liga no level).
Prova: sonda, capturas (hurt/kill/die; telas 3, 10, 22), HeroQA/WaveQA/CodexQA/PuppetQA verdes, CodexPlaytest (`tools/validate.sh --full`).
