# REGRAS DOS AGENTES — GNOSIS, Onda 2 (nuvem, 17/10/2026)

Você é um AGENTE contratado pelo chefe (orquestrador). Só o chefe fala com o dono (João).
Leia também `docs/handoff/REGRAS_DIRETORES.md` do seu worktree (as regras de lá valem, EXCETO
os caminhos Windows: aqui é Linux na nuvem, sem GPU, sem Chrome/GPT, sem Blender/RIFE).

## Ambiente
- Seu worktree: `/home/user/wt/<cargo>` (branch `dir2/<cargo>`, base `integracao/onda1`). Trabalhe SÓ nele.
  Já está importado (`.godot/` existe) e tem `override.cfg` (user:// isolado em `GNOSIS-WT-<cargo>`).
  NUNCA commite `override.cfg` nem `.import` reescritos só por fim de linha.
- Godot 4.7.1: `godot` no PATH. TODA execução com `--headless --audio-driver Dummy` (silêncio obrigatório),
  exceto capturas (abaixo), que também levam `--audio-driver Dummy`.
- Validar (SEMPRE após editar código): `cd /home/user/wt/<cargo> && tools/validate.sh` (ou `--only "Scripts CodexQA"`).
  Base atual: tudo verde, MENOS `AudioQA` (bug conhecido do ducking — é do agente de Áudio) e, com o
  override.cfg, o item do CodexQA "diretório de save independente" pode falhar (falso; o Técnico conserta o teste).
  Não piore nada: qualquer QA que estava verde tem que continuar verde. Nunca afrouxe um teste para passar.
- Capturas (a IA ENXERGA o jogo):
  `xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --rendering-driver opengl3 --path . --resolution 1280x720 "res://tools/Shot.tscn" -- <tela|res://cena.tscn> /home/user/caps/<cargo>/<nome>.png [frames] [hurt|kill|clear|wave|die|dialog]`
  (leia `tools/shot.gd` para os modos). Salve em `/home/user/caps/<cargo>/` (fora do git). Para economizar,
  reduza antes de olhar: `python3 -c "from PIL import Image;i=Image.open('a.png');i.thumbnail((800,800));i.save('a_s.png')"`.
  Faça ANTES e DEPOIS de toda mudança visual.
- Python3 com PIL e numpy; ffmpeg. Use timeouts (`timeout 300 ...`). Mate só processos que VOCÊ abriu.
- Convenções: GDScript com TAB, comentários em PORTUGUÊS, tipagem explícita (`var x =` para valor sem tipo).
  Textos de UI seguem `docs/ESTILO_TEXTO.md` ("para", nunca "pra", exceto na boca da Sophia).

## Propriedade de arquivos (CRÍTICO)
Você só ESCREVE nos arquivos listados no seu briefing (e em arquivos NOVOS dentro das pastas indicadas).
Precisa de algo em arquivo de outro agente? Escreva em `docs/pedidos/onda2_<cargo>.md` e siga sem ele.
Quando precisar chamar uma API que OUTRO agente está criando agora, chame de forma que compile sem ela:
`if obj.has_method("x"): obj.call("x", ...)` / `if obj.has_signal("s"): obj.connect("s", cb)` /
`if "prop" in obj: obj.set("prop", v)`. Nunca edite `BIBLIA.md`, `ROADMAP.md`, `CLAUDE.md`, `AGENTS.md`,
`README.md`, `docs/handoff/*` (são do chefe).

## Pausa (contrato já integrado)
`scripts/autoload/pause_stack.gd` (`class_name PauseStack`): `PauseStack.push(self)` / `PauseStack.pop(self)` /
`is_held()` / `clear()`. Quem pausa o mundo usa isso; ninguém mais escreve `get_tree().paused = ...` direto.

## Commits
Commite CEDO e SEMPRE no seu branch (a cada passo validado), com `git add <arquivos>` explícitos.
Mensagem em português terminando com a linha:
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
NÃO faça push, merge, rebase nem toque em outros branches/worktrees (o chefe faz push e integra).

## Relatório final ao chefe (português, enxuto, honesto — sem hype)
Escreva também em `docs/onda2/<CARGO>.md` (arquivo seu). Conteúdo: 1. commits; 2. o que mudou (arquivos);
3. capturas antes/depois (caminhos) e o que provam; 4. validação (cole as linhas do resumo do validate.sh);
5. o que NÃO ficou bom / não deu tempo; 6. pedidos a outros agentes. Não invente resultado: se não testou, diga.
A sua resposta final (a mensagem que você devolve) deve ser esse relatório, curto.

## Reinício do container (aconteceu às 06:05 UTC de 17/10)
O container da nuvem pode reiniciar e matar os agentes; o disco (/home/user) sobrevive, mas trabalho NÃO commitado
fica solto. Por isso: commite no mínimo a cada ~15 min (mesmo passos intermediários que compilam — mensagem "WIP: ...").
Se você é a CONTINUAÇÃO de um agente interrompido: comece com `git log --oneline integracao/onda1..HEAD`, `git status`
e `git diff`; revise o que o anterior deixou (não jogue fora sem motivo), valide, commite e siga o brief do seu cargo
em `docs/handoff/briefs/`. Os `.uid` não rastreados das sondas (tools/qa_ux, tools/revisao, pause_stack, scenery_library)
NÃO são seus: não commite.
