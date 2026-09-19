# GNOSIS — O Despertar (v1.1)

## Abrir e jogar

Abra **Jogar GNOSIS Codex.bat** nesta pasta (ou `GNOSIS.exe` do build). O menu:

| Botão | O que é |
|---|---|
| **Continuar — Éon (Tela N)** | Retoma a campanha do último checkpoint salvo (só aparece se houver um). |
| **Nova campanha** | O jogo de verdade: **68 telas** — o Rei, sete Éons de 9 telas (cada um fecha num Arconte), o roubo, o Centro e a Mente. Com save, pede confirmação antes de apagar o progresso. |
| **Provação — treino de 3 encontros** | Sandbox curto (arma nível 3, um Anel, um Arconte no fim). **Não é a campanha** e não grava progresso. |
| **Ateliê & Bestiário** | Vitrine da Sophia, dos Arcontes e das criaturas. |
| **Crônicas** | O caderno de lore (entradas desbloqueadas persistem entre runs). |
| **Opções** | Tela cheia, VSync, tremor de câmera, vibração, tamanho da legenda, volumes. |

Na campanha, **Esc/Start** abre a pausa: Continuar · **Golpes & Controles** (todos os
combos com a sequência de botões e o nível de arma que os abre, os 7 Anéis, a
tabela de controles) · Melhorias (a loja) · Opções · Abandonar run (o checkpoint
salvo permanece). O HUD mostra o papel da tela ("Torpor · Travessia II") e nove
pontinhos com o progresso do Éon.

Esta pasta é uma cópia independente; não compartilha saves com o GNOSIS original.
Guia de entrega e limites: [docs/CODEX_ENTREGA.md](docs/CODEX_ENTREGA.md).

---

# GNOSIS

> *Título oficial.* "Kenoma" é o nome do **mundo** dentro do jogo.

Beat-em-up 2.5D de rolagem lateral (estilo **Grand Chase**) com combate de ação
(estilo **God of War 2018**: leve/forte, esquiva com i-frames, parry, golpes
imparáveis) e progressão de arma e magias, ambientado numa releitura de fantasia
da **cosmologia gnóstica** (Demiurgo, Arcontes, Pleroma — nomes e figuras
ficcionalizados, sem retratar nenhuma fé viva). Feito em **Godot 4.7.1**, com
arte vetorial procedural desenhada em código.

## Como rodar

1. Instale o Godot 4.7 (Standard):
   `winget install --id GodotEngine.GodotEngine` ou https://godotengine.org/download
2. Abra o Godot, clique em **Import**, e aponte para a pasta deste projeto
   (o arquivo `project.godot`). Aperte **F5** (Play).
3. Ou use o atalho `Jogar GNOSIS.bat` na pasta do projeto.

## Controles (teclado · Xbox · DualShock/DualSense · genéricos)

O jogo carrega o **SDL_GameControllerDB** (open source, o mesmo banco da SDL/
Steam) no boot: centenas de controles são reconhecidos com o layout correto,
incluindo clones genéricos. Rumble em dano/parry/esquiva perfeita/chefe caindo.

| Ação | Teclado | Xbox | DualShock |
|------|---------|------|-----------|
| Mover | A / D (ou setas) | analógico esq. / D-pad | idem |
| Pular | Espaço | A | ✕ |
| Ataque leve | J | X | □ |
| Ataque forte | K | Y | △ |
| Esquiva (i-frames) | L / Shift | B | ○ |
| Defesa / Parry | I (segurar/no tempo) | LB | L1 |
| Anel equipado (magia) | U | RB | R1 |
| Esfera Solar (inata) | O | RT | R2 |
| Trocar Anel | Q / E ou 1–7 | LT / Back | L2 / Share |
| Pausar | Esc / P | Start | Options |
| FPS | F3 | — | — |

> Ergonomia: ataques no **polegar direito** (X/Y vizinhos — combos leve/forte
> fluem num rolar de polegar), parry **segurável no L1** sem largar os ataques,
> e a Esfera Solar no **gatilho** (é um projétil: gatilho = disparo).

**Combos:** sequências de leve/forte (`J,J,J` · `K,K,K` · ...). **Parry vs
Esquiva:** telegrafo **amarelo** = dá pra aparar (atordoa); **vermelho** = imparável
(elites, explosões), só a esquiva salva. **Escudeiros** só caem com golpe forte
ou magia. A **esquiva** também arrebenta a corrente do Arconte Galila.

> Os inputs são registrados por código em `game_manager.gd` (`_register_inputs`).
> Rebind virá depois.

## Fluxo do jogo — o Arco dos Anéis

Menu → Nova campanha (dificuldade) → **run de 68 telas**: **O Rei** (tela 1, duelo-
tutorial) → **7 Éons de 9 telas** (Torpor, Fome, Corrente, Silêncio, Espelho,
Praga, Coroa — chegada · travessias · o Desafio do Campeão · antessala · Arconte),
cada Éon fechando num **Arconte-chefe** com mecânica própria e 2 fases — cada
Arconte morto dropa seu **Anel** (uma magia nova) → **o roubo** (tela 64) → **o
Centro** (65–67, ecos dos Arcontes devolvem os cacos) → **a batalha dupla** (68:
as duas formas do Demiurgo precisam cair juntas) → escolha do final. Entre telas:
baús, Adormecidos, puzzle dos Selos, encontros com Soter e Velkar, e o Santuário
(loja) após cada chefe. **Morrer não reseta o run**: algo te recompõe (quem — e
por quê — é parte da história) e você volta ao início do trecho atual com a
progressão intacta, pagando 20% das faíscas. Fechar o jogo também não perde
nada: o menu ganha **"Continuar"** com seu checkpoint salvo.

## Estado

Protótipo jogável de ponta a ponta, em aprofundamento. Plano de fases rumo à
versão final no topo de `ROADMAP.md`; estado detalhado em `BIBLIA.md §6`. Sem
áudio ainda (última etapa).

## Arquitetura (resumo)

- **Autoloads** (`scripts/autoload`): sistemas globais sempre ligados
  (`GameManager`, `Progression`, `GameContent`, `Bestiary`, `RunManager`,
  `Narrative`, `SceneManager`, `Audio`, `SaveManager`, `Juice`, `FpsOverlay`).
- **Data** (`scripts/data`): "moldes" (`Resource`) — dados puros, sem lógica.
- **Combat / Components**: `Hitbox`, `Hurtbox`, `HealthComponent` reutilizáveis.
- **Entities**: `player.gd` (máquina de estados), `enemy.gd` (estilos, comportamentos
  de wave e kits de chefe), NPCs e objetos de fase.
- **FX**: `character_art.gd` (motor de arte procedural) e efeitos.
- **UI**: menu, pré-jogo, HUD (com barra de chefe), pausa, loja, diálogo, Codex.
- **Tools**: ferramentas de desenvolvimento (captura de tela, vitrine, bot de
  balance), fora do jogo.

Mapa completo para quem for continuar o projeto: `BIBLIA.md`.
