# Build & Instalador

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
   **Compile**. Sai `installer/Output/GNOSIS-Setup-0.1.0.exe`.

## Patches menores (updates leves)

Gere um `.pck` só com o que mudou e nomeie `patch_01.pck`, `patch_02.pck`...
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
