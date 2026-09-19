# GNOSE — como o jogo ENSINA o gnosticismo (sistema `Gnosis`)

> Sessão 18/09/2026. Resposta à crítica do João: "não tem história, sem apelo
> narrativo, não ensina nada sobre gnosticismo (como God of War ensina sobre
> mitologia grega/nórdica)". Este doc lista o que existe e onde.

## Os 4 canais

| Canal | Arquivo | O que faz | Pausa? |
|---|---|---|---|
| **Estelas** | `scripts/entities/stela.gd` (+ tabela em `scripts/autoload/gnosis.gd`) | 18 pedras escritas nos descansos entre zonas. Perto delas aparece "J · ler a Estela"; golpe leve (J / X) ou Enter abre o painel (título + 5–6 linhas + fonte histórica). Ler desbloqueia a Crônica. | Sim (painel) |
| **Legendas de caminhada** | `scripts/ui/caption_bar.gd` + `Narrative.walk_arrival/walk_cleared` | ~95 falas curtas (3–5 s) na base da tela, na chegada e ao limpar cada zona. A Voz comenta o Éon com o viés dela; a Sophia responde a si mesma; as dúvidas crescem Éon a Éon. Nunca repete no run (`Narrative.once`). | Não |
| **Cinemáticas** | `scripts/fx/cinematic.gd` | `prologue()` (6 cards do mito, tela 1, uma vez por run) · `boss_card(nome, título)` (letterbox + nome + título, congela 1,8 s ao nascer Rei / Arconte / Campeão / batalha dupla) · `epilogue(final, n, total)` (cards do final + "Crônicas N/18" + créditos, antes do EndScreen). Qualquer tecla avança, Esc pula. | Sim |
| **Crônicas** | `scripts/ui/chronicles.gd` + `scenes/ui/Chronicles.tscn` | Caderno navegável (W/S, setas, gamepad; Esc volta ao menu). Trancadas mostram "???" + dica de onde ficam. Persistem ENTRE runs em `user://chronicles.json` (o `Gnosis` salva sozinho, sem SaveManager). | — |

**API pública** (`Gnosis`): `chronicles_count() -> int` · `chronicles_total() -> int`
· `unlock(id) -> bool` · `is_unlocked(id)` · `entries()` · `entry(id)` ·
`boss_card(id, screen)` · `caption(speaker, text)` · `persist_enabled` (ferramentas).

**Contrato com o Level** (já ligado em `level.gd`): `setup_screen(level, screen,
rest_points)` instancia a Estela da tela e enfileira a legenda de chegada;
`zone_cleared(screen, zone, total)` enfileira a legenda de zona limpa.
`level._start_wave` chama `Gnosis.boss_card` ao nascer o chefe/Campeão;
`final_battle.start` chama o card "YALDABAOTH · as duas faces";
`level._win` toca o epílogo. O prólogo toca em `_play_narrative_beats` da tela 1.

## Pedagogia: a contradição
As Estelas dão a versão do **Pleroma** (os textos antigos). A **Voz** — que é
o Demiurgo, segredo até a tela 64 — conta a mesma cosmologia com o viés dela:
"a Luz de cima não olha pra baixo, eu olho", "vieste de mim", "não confies nas
pedras", "não pares pra ler". O jogador aprende pela diferença entre as duas
fontes; a Sophia verbaliza a dúvida sem nunca entregar a virada.

## As 18 Estelas (id · tela · Éon · título · fonte)

| # | id | Tela | Éon | Título | Fonte histórica |
|---|---|---|---|---|---|
| 1 | `monada` | 1 | O Limiar | A Mônada, o Inefável | Apócrifo de João (NHC II,1); Evangelho da Verdade (NHC I,3) |
| 2 | `pleroma` | 3 | Torpor | O Pleroma e os Éons | Irineu, Contra as Heresias I,1; Apócrifo de João |
| 3 | `sophia` | 8 | Torpor | Sophia, a Sabedoria | Apócrifo de João 9–10; Irineu I,2–4; Hipólito VI |
| 4 | `cego` | 12 | Fome | O Aborto Cego (Yaldabaoth / Saklas / Samael) | Apócrifo de João 10–11; Hipóstase dos Arcontes (NHC II,4) |
| 5 | `kenoma` | 15 | Fome | O Kenoma e a Hyle | Irineu I,4–5; Evangelho da Verdade |
| 6 | `arcontes` | 17 | Fome | Os Sete Arcontes e as Esferas | Apócrifo de João 10–12; Orígenes, Contra Celso VI |
| 7 | `heimarmene` | 21 | Corrente | Heimarmene, o Destino em Corrente | Apócrifo de João 28; Excertos de Teódoto 69–78 |
| 8 | `barro` | 25 | Corrente | O Homem de Barro e a Faísca | Apócrifo de João 15–20; Hipóstase dos Arcontes |
| 9 | `gnose` | 30 | Silêncio | A Gnose: saber é lembrar | Evangelho da Verdade; Excertos de Teódoto 78; Tomé 3 |
| 10 | `nag_hammadi` | 33 | Silêncio | Nag Hammadi, 1945 | Robinson, The Nag Hammadi Library (1977) |
| 11 | `apocrifo` | 35 | Silêncio | O Apócrifo de João | NHC II,1 / III,1 / IV,1; BG 8502,2 |
| 12 | `pistis` | 39 | Espelho | Pistis Sophia e os Arrependimentos | Pistis Sophia (Códice Askew), livros I–II |
| 13 | `mestres` | 43 | Espelho | Valentino e Basílides | Irineu I; Clemente, Stromata; Hipólito VII |
| 14 | `tome` | 48 | Praga | O Evangelho de Tomé | NHC II,2, lógia 1, 3, 70, 113 |
| 15 | `perola` | 52 | Praga | O Hino da Pérola | Atos de Tomé 108–113 |
| 16 | `chamado` | 57 | Coroa | O Chamado e o Despertar | Apócrifo de João 30–31; Evangelho da Verdade 22 |
| 17 | `docetismo` | 61 | Coroa | Docetismo: o corpo aparente | Irineu I,24; 2º Tratado do Grande Set (NHC VII,2); Apocalipse de Pedro (NHC VII,3) |
| 18 | `retorno` | 66 | O Centro | A Salvação como Retorno | Tomé 18; Tratado Tripartite (NHC I,5); Irineu I,7 |

Posição: em telas com 2–3 zonas a Estela fica no descanso ENTRE zonas
(índice `1 + tela % (n-1)`, 200 px à esquerda do centro, longe do baú/Adormecido/
Selos); em telas de 1 zona (desafio, Centro, Limiar) fica 150 px à direita do
descanso 0, visível já na chegada. Nunca em tela de Arconte.

## Tom e respeito
Filosofia antiga, contada com respeito: nunca zombaria de fé viva, nunca nomes
sagrados de fés atuais como vilão (só Yaldabaoth, e os nomes do Apócrifo para
os Arcontes). O docetismo é apresentado como disputa histórica, sem tomar partido.

## Ganchos pedidos a outros arquivos (não editados aqui)
- **Menu principal**: botão "Crônicas" → `SceneManager.change_scene("res://scenes/ui/Chronicles.tscn")`
  e, opcionalmente, o contador `Gnosis.chronicles_count()/chronicles_total()`.
- **Pausa**: item "Crônicas" opcional (a cena volta ao MainMenu ao sair — para
  abrir da pausa, precisaria de um `return_scene`).
- **Áudio**: SFX `stela` (abrir pedra), `caption` (legenda entra), `ui`
  (fechar painel); `boss_appear` já existe no catálogo.
- **shot.gd** (ferramenta): não pula `Cinematic`; pra capturar o jogo na tela 1
  sem o prólogo, chame `Narrative.once("prologue")` antes de trocar de cena
  (o `tools/gnose_qa.gd` faz isso).

## Validação
`tools/GnoseQA.tscn` (com janela salva `shots/gnose_*.png`; headless só valida):
Estela instanciada → prompt ao chegar perto → painel pausa → Crônica desbloqueia
→ painel fecha → card de chefe congela/libera na tela 10 → prólogo e epílogo
puláveis → Crônicas lista 18.
