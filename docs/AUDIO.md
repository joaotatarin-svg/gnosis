# Áudio do GNOSIS — lista de compras (a ÚLTIMA etapa)

O código já toca tudo automaticamente. Você só precisa **gerar os arquivos** e
soltar na pasta. Enquanto não existirem, o jogo roda em silêncio, sem erro.

## Onde colocar

- SFX  → `assets/audio/sfx/<nome>.ogg`  (aceita .ogg / .wav / .mp3)
- Música → `assets/audio/music/<nome>.ogg`

Use **exatamente** estes nomes de arquivo (é por eles que o jogo chama):

| Arquivo | Quando toca | Prompt sugerido (curto, seco) |
|---------|-------------|-------------------------------|
| `sfx/hit.ogg` | todo golpe que acerta | "short punchy melee impact, fantasy sword hit, dry, no tail" |
| `sfx/parry.ogg` | parry perfeito | "metallic parry clang with bright shimmer, satisfying deflect" |
| `sfx/dodge.ogg` | esquiva/rolar | "quick whoosh dash, short air swipe" |
| `sfx/cast.ogg` | magia lançada | "magical light burst cast, holy shimmer whoosh" |
| `sfx/enemy_die.ogg` | Arconte morre | "creature death poof with light release, soft magical dissipate" |
| `sfx/ui.ogg` | clique/slider de menu | "soft UI tick, subtle click, warm" |

Extras (opcionais, dá pra adicionar depois — me peça pra ligar):
`spark_pickup`, `chest_open`, `boss_appear`, `player_hurt`, `level_clear`.

### Do Arco dos Anéis (novos, também opcionais — me peça pra ligar)

| Arquivo | Quando toca | Prompt sugerido |
|---------|-------------|-----------------|
| `sfx/ring_gain.ogg` | Arconte cai → Anel se condensa | "sacred ring chime forming, crystalline resonance, ascending, short" |
| `sfx/ring_steal.ogg` | o roubo (tela 50) | "seven chimes ripped away in reverse, hollow loss, dark whoosh" |
| `sfx/shard.ogg` | caco de memória volta (Centro) | "small memory shard click into place, soft crystalline warm" |
| `sfx/revive.ogg` | forma do Demiurgo se refaz (tela 54) | "dark resurrection surge, deep inhale of power, ominous rebuild" |

## Música

| Arquivo | Onde | Prompt sugerido |
|---------|------|-----------------|
| `music/theme.ogg` | menu principal | "melancholic epic gnostic ambient, choir pads, distant, hopeful-sad, loopable" |

Depois expandimos: uma faixa por Éon (nigredo→rubedo), tema de chefe, tema do Demiurgo.

## Qual IA usar (recomendação)

- **SFX:** **ElevenLabs — Sound Effects** (elevenlabs.io/sound-effects) — melhor
  pra efeitos curtos de jogo, exporta rápido. Alternativa: **Stable Audio**.
- **Música:** **Suno** ou **Udio** (faixas com clima), ou **Stable Audio** pra
  loops ambientes. Peça versões **loopáveis**.

## Dica

Gera em .wav/.mp3 mesmo — o Godot importa mp3/ogg nativo. Se vier .wav grande,
converte pra .ogg (menor) antes de buildar. Manda que eu ajusto volumes/mixagem
por SFX (pitch já tem variação automática pra não enjoar).
