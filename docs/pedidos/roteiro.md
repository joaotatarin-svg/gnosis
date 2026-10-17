# PEDIDOS do Diretor de Roteiro & Texto (Onda 1, 17/10/2026)

> Textos em arquivos que NÃO são do roteiro. Regras em `docs/ESTILO_TEXTO.md`
> (UI = imperativo de "você" ou impessoal; "para", nunca "pra"; glossário §3).
> Linhas conferidas na base `codex/despertar` (d291db0).

## Para a UI (`scripts/ui/**`)

| Arquivo:linha | Hoje | Sugestão | Motivo |
|---|---|---|---|
| `codex_menu.gd:51` | "A centelha que não se curva" | "A faísca que não se curva" | glossário: o termo é **faísca** (nunca "centelha") |
| `codex_menu.gd:59` | "Sete anéis. Uma prisão. A luz ainda se lembra de você." | "Sete Éons. Sete Arcontes. Uma faísca que ainda se lembra." | "Anel" é maiúsculo; e "anéis + prisão" lado a lado sugere a virada (Anéis = correntes) antes da hora |
| `moves_screen.gd:128` | "dá pra aparar" | "dá para aparar" | "pra" só na boca da Sophia |
| `pause_menu.gd:95` | "Volta pro menu. O checkpoint salvo permanece: …" | "Volta para o menu. O checkpoint salvo permanece: …" | idem |
| `pause_menu.gd:97` | "Volta pro menu. A Provação não grava progresso." | "Volta para o menu. A Provação não grava progresso." | idem |
| `pregame.gd:18` | "Mais que o dobro. Pra quem já leu o vermelho e o amarelo." | "Mais que o dobro. Para quem já lê o vermelho e o amarelo." | idem |
| `character_atelier.gd:11` | "…e uma aura que silencia anéis." | "…e uma aura que silencia os Anéis." | Anel maiúsculo |
| `upgrade_menu.gd:72` | "+20 Vida máx   (60 faíscas)" | "+20 de vida máx.   (60 faíscas)" | mesmo formato da bênção de Soter ("Vigor (+25 de vida máx.)") |
| `upgrade_menu.gd:73` | "+15 Éter máx   (60 faíscas)" | "+15 de Éter máx.   (60 faíscas)" | idem |
| `upgrade_menu.gd:36` / `hud.gd:282` | "Arma Nv.%d" / "Arma Nv. %d" | padronizar "Arma Nv. %d" (com espaço) | consistência |
| `chronicles.gd:105` | "Chegue perto e aperte o golpe leve (J / X) para ler." | (ok) | — o prompt da Estela agora também diz "J / X · ler a Estela" |

**Nome de magia mudou** (`game_content.gd`): o Anel de Armupiel passou de
"Coroa da Mônada" para **"Coroa Partida"** (a Mônada não tem coroa; a magia é a
coroa do Arconte partida em luz). O item de gear "Coroa da Mônada" virou
**"Diadema da Fonte"** (`bestiary.gd`), para não colidir com o nome da magia e
para a Sophia não usar "coroa" (o tema da Ruptura). A UI lê os nomes por
`display_name`; nada a mudar em código, só conferir textos fixos/capturas.

## Para quem cuida de `scripts/levels/` (Técnico)

- `final_battle.gd:34` — toast "As duas formas precisam cair JUNTAS." →
  "As duas formas precisam cair juntas." (CAIXA ALTA só em grito de personagem).
- `player.gd:642` — só comentário: "Coroa da Mônada" → "Coroa Partida".

## Para a encenação da Onda 2 (cenas A–D de `docs/ROTEIRO.md`)

As falas das cenas trazem um campo extra **`cue`** (a `DialogueBox` ignora):

| Função | `cue` (na ordem) |
|---|---|
| `Narrative.king_intro()` | `fog_thickens` · `king_emerges` · `mask_lights` |
| `Narrative.king_fall()` | `mask_cracks` · `king_sinks` |
| `Narrative.theft()` | `king_emerges` · `rings_fly` · `voice_merge` · `mask_falls` · `sink` |
| `Narrative.final_lines()` | `rings_return` · `flash` · `colossus_shrinks` · `reclaim` |

Pedido: a `DialogueBox` (UI) emitir um sinal `line_shown(index: int, line:
Dictionary)` ao mostrar cada fala — assim o Level dispara o efeito pelo `cue`
sem a caixa saber de nada. Com o HUD expondo `ring_dot_global_pos(i)` e
`detach_ring(i)`, o `rings_fly` faz as 7 gemas voarem (roteiro na cena B).
