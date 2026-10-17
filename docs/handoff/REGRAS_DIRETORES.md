# REGRAS DOS DIRETORES — GNOSIS, Onda 1 (17/10/2026)

Você é um DIRETOR contratado pelo orquestrador (o "chefe"). Só o chefe fala com o
dono do jogo (João). Você se reporta ao chefe no relatório final.

## O jogo
GNOSIS — beat-em-up 2.5D (Grand Chase) + combate God of War, tema gnóstico.
Godot 4.7.1 / GDScript. Protagonista ÚNICA: Sophia. Arte ilustrada (PNG pintado
por IA em `assets/painted/`, catálogo `scripts/fx/painted_library.gd`). Leia
`BIBLIA.md` (§4 arquitetura, §6 estado, §7 decisões) e `CLAUDE.md` do SEU worktree
antes de começar. Viewport base 640×360, janela 1280×720, stretch canvas_items.

Queixa central do João: "o jogo tem cara, mas longe de versão final; os personagens
quando se movem parecem uma foto cortada movida em peças independentes". Meta:
versão final vendável. João NÃO comprará créditos de IA: só ferramentas grátis.

## Onde trabalhar
- Seu worktree: `C:\gnosis-wt\<cargo>` (branch `dir/<cargo>`, base `codex/despertar`).
  Trabalhe SÓ nele. NUNCA edite o projeto original no OneDrive
  (`C:\Users\jmtat\OneDrive\Desktop\Gnosis-Codex - Copia`) — apenas leitura, se precisar
  (ex.: `assets/_packs/`, que está fora do git e só existe lá).
- Primeira coisa: importar o projeto no worktree (gera `.godot/`):
  `& $godot --headless --path C:\gnosis-wt\<cargo> --editor --quit` (pode levar minutos).
- Capturas e GIFs: salve em `C:\gnosis-wt\_caps\<cargo>\` (fora do git). Faça ANTES e DEPOIS.

## SILÊNCIO OBRIGATÓRIO (pedido do dono)
TODA execução do Godot que abre janela ou roda cena (Shot, QAs, bot, jogo) deve levar
`--audio-driver Dummy` (ex.: `& $godot --audio-driver Dummy --path <wt> ...`). Só o diretor de
Áudio pode ouvir algo, e mesmo ele analisa arquivos offline (ffmpeg/Python), não tocando no PC.

## Ferramentas desta máquina
- Godot: `C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`
- Validar: `& $godot --headless --path <wt> --editor --quit` → ZERO `SCRIPT ERROR`/`Parse Error`.
- Ver o jogo: `& $godot --path <wt> --resolution 1280x720 --position 4000,4000 "res://tools/Shot.tscn" -- <tela|res://cena.tscn> "<saida.png>" [frames] [hurt|kill|clear|wave|die|dialog]`
  (leia o PNG com a ferramenta Read — você ENXERGA imagens). Leia `tools/shot.gd` para detalhes.
- QA geral: `tools/CodexQA.tscn` (leia `tools/codex_qa.gd` p/ saber rodar e o que significa verde).
- Blender 5.2.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (`--background --python x.py`).
- Python 3.12 com PIL, numpy, opencv-contrib (cv2 5.0), scipy, scikit-image, rembg
  (modelos `isnet-anime` — ótimo p/ ilustração — e `u2net` já baixados), pydub, librosa.
- ffmpeg 9 no PATH. Node 24.
- RIFE (interpolação de quadros por IA, roda na GPU AMD RX 7600 via Vulkan):
  `C:\Users\jmtat\gnosis-tools\rife\rife-ncnn-vulkan.exe -0 a.png -1 b.png -o mid.png -m rife-v4.6`
  (bom entre poses PRÓXIMAS; entre poses muito diferentes vira borrão).
- Hardware: Ryzen 5 5600G, RX 7600 8 GB, 31 GB RAM. Pode usar CPU/GPU pesado.
- Ferramentas externas extras: instale em `C:\Users\jmtat\gnosis-tools\` (só fontes oficiais,
  licença livre p/ uso comercial).

## Convenções de código (SIGA)
GDScript com indentação TAB, comentários em PORTUGUÊS, tipagem explícita; valor sem
tipo (`load()`) → `var x =` (não `:=`). Balanceamento determinístico por tela.
Tudo exportável (`res://`). Sem libs externas no runtime do jogo. Scripts Python/Blender
de pipeline ficam em `tools/` (versionados) e geram assets versionados.

## Propriedade de arquivos (CRÍTICO)
Você só ESCREVE nos arquivos listados como seus no seu briefing. Precisa de algo em
arquivo de outro? Escreva o pedido em `docs/pedidos/<cargo>.md` (no seu worktree) e
siga sem ele. Nunca edite: `BIBLIA.md`, `ROADMAP.md`, `docs/PLANO_FINAL.md`,
`CLAUDE.md`, `AGENTS.md`, `README.md`, `project.godot` (salvo o Técnico).
Escreva seu relatório técnico em `docs/<AREA>.md` (área sua).

## Commits
Commite CEDO e SEMPRE no seu branch (a cada passo validado) — limites de uso podem
derrubar agentes; trabalho não commitado se perde. Mensagem em português. Termine
cada mensagem com a linha:
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
Não faça merge, rebase nem push. Não toque em outros branches.

## Processos
Mate só os processos Godot/Blender que VOCÊ iniciou (pelo PID). O João pode ter o
editor aberto. Use timeouts nas execuções.

## Relatório final ao chefe (português, enxuto, honesto — sem hype)
1. Branch e lista de commits. 2. O que mudou (arquivos). 3. Capturas antes/depois
(caminhos absolutos) e o que elas provam. 4. Resultado de validação/QA (cole as linhas
relevantes). 5. O que NÃO ficou bom ou não deu tempo. 6. Pedidos a outros diretores.
Não invente resultado: se não testou, diga.
