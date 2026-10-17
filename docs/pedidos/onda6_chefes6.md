# Pedidos para chefes6 (de: arte / dir2/arte-gpt)

## Morte de chefe com peso (feedback do João: "só desmonta no final / acaba murcha / pobrinha")
Pronto no `CharacterArt` (branch dir2/arte-gpt): `visual.play_boss_death(cor := eon da tela)` toca ~1,9 s
com a PRÓPRIA pintura — cambaleio (quadro de dano, tremor, 2 lampejos) → queda (quadro de morte, impacto,
`Juice.shake`) → pausa dramática (luz do Éon vazando pela borda) → estilhaça em ~40 cacos triangulares do
atlas com física + clarão + faíscas → sinal `visual.death_finished`. `visual.is_dying()` informa.
Troca pedida em `enemy.gd` `_on_died()` (bloco do chefe), no lugar do desmembramento imediato:
```gdscript
if is_boss_enemy and visual.has_boss_frames() and not revivable:
	hurtbox.set_deferred("monitoring", false)
	contact_hitbox.set_deferred("monitoring", false)
	Juice.hit_stop(0.12)
	visual.play_boss_death()
	await visual.death_finished
	queue_free()
	return
```
(o `defeated.emit(self)`, faíscas e rumble continuam antes, como hoje). Formas revivíveis da batalha final:
mesma coisa até a pausa, se quiserem, ou manter a dissolução parcial — mas sem `tween` de `modulate`/escala
(isso é o "murcha"). GIF: `C:\gnosis-wt\_caps\arte-gpt\gifs\morte_chefes_antes.gif` × `morte_chefes_depois.gif`.