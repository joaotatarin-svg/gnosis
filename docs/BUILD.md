# Build & Instalador

> **Versão do projeto: 1.2.0 (17/10/2026)** — ainda NÃO exportada em .exe/instalador
> (build só com o OK do João). Comandos, todos por linha de comando:
> ```
> & $godot --headless --audio-driver Dummy --path . --export-release "Windows Desktop" builds/GNOSIS.exe
> & "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" installer\gnosis.iss   # padrão 1.2.0
> ```
> Templates 4.7.1.stable instalados (`%APPDATA%\Godot\export_templates`). O Inno Setup
> NÃO estava instalado em 17/10/2026 (`winget install JRSoftware.InnoSetup`).
> Cuidado: `export_presets.cfg` NÃO pode ter BOM (o Godot deixa de achar o preset);
> `installer/gnosis.iss` TEM BOM (UTF-8, por causa do "ã" do publicador).
>
> **1.2.0 — o que mudou no build:**
> - Publicador **João Tatarin** (instalador `AppPublisher` e `company_name` do .exe).
>   `AppId` = o MESMO desde o 1.0.0 (`{7C1E7A2A-GNOS-1S00-KENO-MA0000000001}`; não é
>   GUID hexadecimal, mas o Inno aceita texto) — nunca trocar, senão o Windows
>   instala um 2º GNOSIS em vez de atualizar.
> - `.pck` sem as 5 folhas cromáticas originais (`assets/painted/{sophia,archons,
>   yaldabaoth,architecture,inhabitants}.png`) nem `assets/characters/*`: o jogo usa
>   as versões de `assets/painted/derived/` (o `PaintedLibrary` só cai na original se
>   a derivada faltar — a TecnicoQA confere) e o rig antigo da Sophia não tem quem
>   chame. `eons.png` FICA (não tem derivada). −9,6 MB (129,8 → 120,1 MB, 862 → 835
>   arquivos, medido com `--export-pack` + `tools/revisao/pck_list.py`).
> - Dentro do .pck: `assets/LICENSES.md`, os 3 `OFL.txt` das fontes,
>   `assets/input/gamecontrollerdb.txt` + licença. Fora: tools/, artes/, docs/,
>   shots/, builds/, installer/, assets/_packs/.
> - VSync desligado por padrão + `Engine.max_fps` = taxa do monitor (60 se o sistema
>   não informar, teto 240); saves antigos com `vsync: true` migram UMA vez
>   (`settings_rev` 1). Medição: `tools/perf/FpsReal.tscn` (ver docs/onda2/TECNICO3.md).
> - Patches: só entram `patch_1.2.0_*.pck` (os de 1.1.0 são ignorados no boot).

> Histórico: build 1.1.0 em 18/09/2026 (Inno Setup 6.7.3 via winget naquela época).

> ✅ **Já está tudo pronto no projeto:** `export_presets.cfg` (preset "Windows
> Desktop" → `builds/GNOSIS.exe`), `installer/gnosis.iss` (Inno Setup) e o
> carregamento de `patch_*.pck` no boot (`game_manager._load_patches`).

## Gerar o build agora — 3 passos

1. **Baixar os templates de exportação (1x só, ~600 MB):** abra o Godot →
   **Editor → Manage Export Templates → Download and Install**. (Sem isso o
   export falha com "Nenhum modelo de exportação encontrado".)
2. **Exportar:** menu **Project → Export → Windows Desktop → Export Project**,
   salve em `builds/GNOSIS.exe`. Gera `GNOSIS.exe` + `GNOSIS.pck`.
   (Ou por linha de comando: `godot --headless --export-release "Windows Desktop"
   builds/GNOSIS.exe`.)
3. **Instalador:** abra `installer/gnosis.iss` no **Inno Setup Compiler** →
   **Compile**. Sai `installer/Output/GNOSIS-Setup-1.2.0.exe`.

## Patches menores (updates leves)

Gere um `.pck` só com o que mudou e nomeie `patch_<versão>_01.pck` (ex.: `patch_1.2.0_01.pck`); outro nome ou outra versão é ignorado no boot.
Solte na pasta do jogo instalado (ao lado do `.exe`). O jogo carrega no boot,
em ordem, por cima do base — sem reinstalar. (Descomente a linha `patch_*` no
`.iss` pra o instalador incluí-los.)

---

## Princípios que já seguimos (pra continuar exportável)

- Tudo referenciado por `res://` — **sem caminhos absolutos** no código.
- Conteúdo desacoplado (personagens/combos/magias em `game_content.gd`, dados
  em `Resource`) → fácil de ajustar num patch sem mexer no motor do jogo.
- Save em `user://` (pasta do usuário), que **não é sobrescrita** ao atualizar.
- Sem dependências externas de runtime além do próprio binário do Godot.

## Export (quando chegar a hora)

1. Godot → **Project → Export → Add → Windows Desktop**.
2. Baixar os *export templates* da versão (Godot pede na 1ª vez).
3. Gerar `GNOSIS.exe` (+ `.pck` com os assets). Renderer já é
   `gl_compatibility` (roda em PC fraco).
4. Dá pra "embed pck" pra sair só um `.exe`, ou manter `.pck` separado — **manter
   separado facilita patch** (troca só o `.pck` ou um `.pck` de patch).

## Instalador

- **Inno Setup** (grátis, script `.iss`): empacota `GNOSIS.exe` + `.pck`, cria
  atalhos, entrada em Programas, e desinstalador. Simples e confiável no Windows.
- Alternativa: NSIS. Inno é mais fácil de manter.

## Estratégia de patch (updates menores)

- Versão em `project.godot` (`config/version`) + um `version.txt` no build.
- Godot suporta **PCK adicional**: `ProjectSettings.load_resource_pack("patch.pck")`
  no boot carrega/override arquivos por cima do `.pck` base → dá pra distribuir
  correções pequenas (ajuste de dano, novo combo, fix) sem reinstalar tudo.
- Fluxo pensado: instalador full nos marcos grandes; entre eles, `patch_XX.pck`
  leves. (Camada de checagem/download de update fica pra depois — começa manual.)

## A decidir mais pra frente

- Distribuição (itch.io? Steam? site próprio?).
- Assinatura de código (evita alerta do SmartScreen) — opcional/custo.

## Validação antes de qualquer build (desde a Onda 1)
`powershell -ExecutionPolicy Bypass -File tools\validate.ps1` → precisa dar **TUDO VERDE**
(scripts + ScriptCheck + 7 QAs headless, ~1 min; `-Full` inclui o bot do desafio).
O export exclui `tools/*, artes/*, shots/*, docs/*`, `assets/_packs/*`, `builds/*`, `installer/*`, `assets/characters/*` e as 5 folhas originais (`export_presets.cfg`).
Toda execução de ferramenta usa `--audio-driver Dummy`. Detalhes: `docs/QA_BASELINE.md`.
