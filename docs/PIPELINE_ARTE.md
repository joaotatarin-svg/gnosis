# PIPELINE DE ARTE ILUSTRADA — referência (rota aposentada em 2026-09-09)

> **STATUS (2026-09-09): rota ilustrada APOSENTADA como base do jogo.** Decisão
> em `BIBLIA.md §10`: procedural é a base (herói, waves, Arcontes); PNG só pro
> Rei/Demiurgo (`assets/characters/demiurgo.png` + `_orb.png`, já integrados). O
> PNG de manto da Sophia (`assets/characters/sophia/`) foi testado no jogo,
> colidiu com o mundo vetorial e **não é mais carregado** (`player._refresh_look`
> só usa `CharacterArt`). O texto abaixo fica como referência técnica caso o
> usuário decida reabrir a rota; o rig cutout (rig.json/parts) está sem uso.

Objetivo: levar os personagens principais do vetor procedural pro nível
**ilustrado** (referência: personagem com anatomia/roupa/sombras). É ARTE, não
código — precisa de assets. Abaixo, o melhor MCP por etapa.

## As etapas e o melhor MCP de cada

| Etapa | Melhor MCP | Situação |
|-------|-----------|----------|
| 1. Gerar a arte (personagem consistente) | **Kairogen** (já conectado — tem Nano Banana, Seedream, Flux, GPT Image) | ✅ já temos |
| 1-alt. Gerador dedicado | **Nano Banana MCP** (Gemini, "character consistency" até 5 chars) ou **shinpr/mcp-image** | opcional |
| 2. Remover fundo (transparência) | **rembg-mcp** (holocode-ai) — local, sem API key, modelo `isnet-anime` | instalar (ou pular, ver nota) |
| 3. Fatiar em partes (cabeça/torso/braços/pernas) | semi-manual (Krita/GIMP grátis) ou gerar cada parte via Nano Banana; rembg tem `sam` | sem MCP mágico |
| 4. Rigar + animar no Godot (Skeleton2D, AnimationPlayer/Tree) | **godot-mcp** (tugcantopaloglu — 157 tools, **testado no Godot 4.7 = nossa versão**) | instalar (p/ rig avançado) |

> **Nota importante:** pra começar HOJE dá pra usar SÓ o Kairogen (já conectado):
> gerar o herói com **fundo transparente** (GPT Image faz PNG transparente) ou
> fundo verde sólido; eu ligo como **sprite único** no jogo com animação simples.
> `rembg-mcp` e `godot-mcp` só são necessários pro **rig articulado** (partes
> animadas separadas) — o passo avançado.

## Pré-requisitos (Windows)
- **Node.js 18+** (pro godot-mcp): `winget install OpenJS.NodeJS.LTS`
- **Python 3.10+** (pro rembg-mcp): `winget install Python.Python.3.12`
- **Git**: `winget install Git.Git`

## Instalar rembg-mcp (remover fundo)
```
git clone https://github.com/holocode-ai/rembg-mcp
cd rembg-mcp
setup.bat
rembg\Scripts\activate.bat
python download_models.py
```
Config (Claude Desktop: `%APPDATA%\Claude\claude_desktop_config.json`):
```json
{ "mcpServers": { "rembg": {
  "command": "C:\\caminho\\rembg-mcp\\start_server.bat",
  "cwd": "C:\\caminho\\rembg-mcp" } } }
```
Reinicie o Claude. Modelo recomendado p/ ilustração: `isnet-anime`.

## Instalar godot-mcp (controlar o editor Godot: rig/animação)
```
git clone https://github.com/tugcantopaloglu/godot-mcp
cd godot-mcp
npm install
npm run build
```
Config:
```json
{ "mcpServers": { "godot": {
  "command": "node",
  "args": ["C:\\caminho\\godot-mcp\\build\\index.js"],
  "env": { "GODOT_PATH": "C:\\caminho\\Godot_v4.7.1-stable_win64.exe" } } } }
```
Depois: copie `build/scripts/mcp_interaction_server.gd` pra dentro do projeto e
registre como **autoload `McpInteractionServer`** (Project Settings > Autoload).
O editor do Godot precisa estar ABERTO com o projeto pra o MCP conversar com ele.

## O que dá pra entregar HOJE vs. depois
- **HOJE (zero instalação):** Kairogen gera o herói ilustrado (bg transparente) →
  eu ligo como sprite único no jogo (fallback procedural mantido) + animação
  simples (bob/squash). Resultado: herói com cara de ilustração já.
- **DEPOIS (com rembg + godot-mcp):** rig articulado — partes separadas animadas
  (idle/walk/attack) na estrutura de nós Visual > Corpo/Cabeça/Braços/Pernas.

## PROMPT PRA MIM MESMO (colar numa sessão com os MCPs conectados)

```
Contexto: jogo GNOSIS, Godot 4.7, pasta C:\Users\jmtat\OneDrive\Desktop\Gnosis.
Leia BIBLIA.md (esp. §10 direção de arte) e GUIA_IA.md antes.
Meta: colocar o HERÓI ILUSTRADO no jogo, mantendo fallback procedural
(CharacterArt) se a arte não existir. Valide headless após cada mudança.

ETAPA 1 — Gerar (Kairogen):
Gere o herói em pose neutra frontal (braços levemente afastados), estilo
"ilustração vetorial de jogo, contornos limpos, sombras suaves, proporção
heroica". Identidade GNOSIS: guerreiro, armadura vermelha, faísca dourada
brilhando no peito, olho/olhar de luz. Fundo TRANSPARENTE (GPT Image) — se não
der, fundo verde chroma sólido. Se possível, gere versões consistentes das
PARTES (cabeça, torso, braço, perna, arma) com Nano Banana/Seedream.

ETAPA 2 — Transparência (se precisou de chroma): rembg-mcp modelo isnet-anime.
Salve em assets/characters/hero/full.png (e part_<nome>.png se fatiado).

ETAPA 3 — Integrar (edição de arquivos):
Faça o Player desenhar o sprite ilustrado (Sprite2D em Visual) SE existir
assets/characters/hero/full.png; senão, usa o CharacterArt procedural atual.
Animação simples por código: idle bob, squash no ataque, flash no dano. Valide.

ETAPA 4 (stretch, com godot-mcp) — Rig articulado:
Monte Visual > Corpo/Cabeça/Braço_E/Braço_D/Perna_E/Perna_D/Arma como Sprite2D
das partes; Skeleton2D + AnimationPlayer/AnimationTree com estados
idle/walk/attack/hurt/dead. Reaproveite a lógica de estados do player.gd. Valide.
```

## Fontes (repos)
- godot-mcp (157 tools, Godot 4.7): https://github.com/tugcantopaloglu/godot-mcp
- rembg-mcp (remover fundo): https://github.com/holocode-ai/rembg-mcp
- Nano Banana MCP (gerar, consistência): https://github.com/ryaker/nanobanana-mcp-server
- mcp-image (Nano Banana + GPT Image + Seedream): https://github.com/shinpr/mcp-image
