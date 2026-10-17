# Onda 3 — TÉCNICO3 (dir3/tecnico3) — relatório

Base: `origin/integracao/onda1` ab250ea. Sessão local (Windows, RX 7600, monitor 144 Hz).

## 1. O que mudou
- **qps / VSync** (`game_manager.gd`, porta do `fac9814` do `preview/noite`): `"vsync": false`
  no padrão; `_apply_fps_cap()` no fim de `apply_settings()` → `Engine.max_fps =
  fps_cap_for(roundi(screen_get_refresh_rate()))` (taxa do monitor, 60 se ≤ 0, teto 240).
  `fps_cap_for()` é pura (testada).
- **Migração de saves antigos** (`save_manager.gd`): opções ganham `settings_rev`
  (`GameManager.SETTINGS_REV = 1`, também no `SETTINGS_DEFAULT`). `migrate_settings()` roda no
  load: save sem a revisão (ou revisão inválida) com `vsync: true` → false, UMA vez; a revisão 1
  vai ao disco no próximo save, então quem religar o VSync depois é respeitado. Revisão futura
  (> 1) não é mexida. Nada é gravado no boot só por causa da migração (ela é idempotente).
- **Export** (`export_presets.cfg`, os 2 presets): exclui `assets/characters/*` e
  `assets/painted/{sophia,archons,yaldabaoth,architecture,inhabitants}.png`. Verificado: nenhum
  .gd/.tscn/.tres/.json referencia esses caminhos nem os uid deles; `set_rig()` (rig antigo da
  Sophia) não tem chamador; o `enemy.gd` usa `PaintedLibrary.region("yaldabaoth")` (→ derived).
  O `PaintedLibrary.sheet()` só cai na original se a derivada faltar — as 5 derivadas vão no
  .pck e a TecnicoQA agora falha se alguma sumir. `eons.png` FICA (não tem derivada).
- **Versão 1.2.0**: `project.godot`, `export_presets.cfg` (file/product_version, `company_name`
  "João Tatarin"), `installer/gnosis.iss` (`AppVersion` 1.2.0, `AppPublisher` "João Tatarin",
  arquivo em UTF-8 com BOM). **AppId mantido** (`{7C1E7A2A-GNOS-1S00-KENO-MA0000000001}`, o mesmo
  desde o 1.0.0 — não é GUID hexadecimal, mas o Inno aceita; trocar quebraria a atualização).
- **Ferramenta nova** `tools/perf/FpsReal.tscn`: mede qps real SEM forçar VSync/max_fps (vale o
  que o boot aplicou do save), tela escolhida, Sophia imortal batendo; `vsync=1` força o antigo.
- `docs/BUILD.md` atualizado (1.2.0, filtros, nome de patch, Inno ausente nesta máquina).
- Fora da minha lista, 1 linha: `tools/codex_qa.gd` conferia `AppVersion "1.1.0"` fixo; agora
  compara com `config/version` (sem isso o CodexQA ficaria vermelho com a 1.2.0).

## 2. Medição de qps (janela VISÍVEL 1280×720, tela 22, 25 s medidos, `--audio-driver Dummy`)
User dir de teste `%APPDATA%\GNOSIS-WT-tecnico3-fps` com cópia de
`gnosis-tools\backup_save_20261017_022254\save.json` (save antigo: `vsync: true`, sem revisão).
O save real (`GNOSIS-Codex`) não foi aberto; a cópia de teste ficou byte a byte igual (persist
desligado). JSONs em `C:\gnosis-wt\_caps\tecnico3\fps_*.json`.

| Caso | VSync | max_fps | qps médio | 1% pior | quadro p99 |
|---|---|---|---|---|---|
| **Padrão (save antigo migrado)** | off | 144 | **143,9** | 107,8 | 7,9 ms |
| Mesmo boot, VSync forçado on depois | on | 144 | 144,0 | 106,6 | 8,6 ms |
| Save com VSync religado (rev 1), boot com VSync | on | 144 | 143,8 | 103,6 | 8,7 ms |

Log do boot: `SaveManager: opções migradas (rev 0 → 1): VSync desligado (novo padrão).`
GPU "AMD Radeon RX 7600", `gl_compatibility`, monitor 144 Hz.

**Honestidade:** em JANELA, com VSync ligado, também deu ~144 — a queda para ~21 qps NÃO se
reproduziu aqui. Hipóteses não testadas: tela cheia (a 1ª execução abre em tela cheia sem borda)
ou janela fora do monitor/encoberta (o DWM estrangula janela invisível com VSync). Não testei
tela cheia para não tomar a tela do João por 30 s. Com o padrão novo o jogo fica a 144 qps de
qualquer jeito; vale o João conferir em tela cheia (F3 mostra o contador).

## 3. Conteúdo do .pck (`--export-pack "Windows Desktop"`, lido com `tools/revisao/pck_list.py`)
- Antes: 129.772.220 bytes, 862 arquivos. Depois: **120.125.764 bytes, 835 arquivos** (−9,6 MB).
- Saíram 13 `.ctex` (5 folhas originais: architecture 1,53 MB, archons 2,03, inhabitants 1,20,
  sophia 1,47, yaldabaoth 1,63; `assets/characters`: sophia/full 0,50 ×2, demiurgo 0,49, orbe,
  4 partes do rig) + os `.import` e o `rig.json`. Nenhum arquivo novo entrou.
- Dentro: `assets/LICENSES.md`, `assets/fonts/{alegreya,cinzel,cinzel_decorative}/OFL.txt`,
  `assets/input/gamecontrollerdb.txt` + `LICENSE_gamecontrollerdb.txt`, `eons.png` e as derivadas.
- Fora: nada de `tools/`, `artes/`, `docs/`, `shots/`, `builds/`, `installer/`, `assets/_packs/`.
- Por grupo: texturas .ctex 147 (74,2 MB), áudio 155 (37,8 MB), fontes 4 (0,56 MB), resto < 2 MB.
- Listas completas: `C:\gnosis-wt\_caps\tecnico3\{antes,depois}_lista.txt`.

## 4. Validação
`tools/validate.ps1 -Path C:\gnosis-wt\tecnico3 -Full`:
```
VERDE Scripts · ScriptCheck · CodexQA 53 · AudioQA 54 · GnoseQA 18 · SaveQA 49 (+8) ·
PuppetQA · HeroQA · WaveQA · TecnicoQA 43 (+7) · CodexPlaytest 1   → TUDO VERDE (11 etapas)
```
Novas: SaveQA (1ª execução sem VSync; save antigo → false; só o vsync muda; grava rev 1; religar
é respeitado; antigo com false fica false; rev inválida migra; rev futura intocada). TecnicoQA
(padrão desligado, teto 144/60/240, migração pura uma vez, boot com save antigo, export exclui as
folhas, catálogo resolve para derived/, originais nunca carregadas).

## 5. O que NÃO foi feito / limites
- .exe e instalador NÃO gerados (build só com OK do João; Inno Setup não está instalado aqui).
- Queda a ~21 qps não reproduzida em janela (ver §2); tela cheia não medida.
- O teto de qps é lido no `apply_settings` — se o jogador arrastar a janela para outro monitor
  com taxa diferente, o teto só muda na próxima aplicação de opções.
- Os `.import` do worktree aparecem modificados (só fim de linha LF/CRLF, gerado pelo import do
  Godot); não commitei (não são meus).
