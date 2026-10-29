#!/bin/bash
# Pranchas ANTES (código) × DEPOIS (pintura) dos perigos, nas TELAS REAIS.
# Uso: tools/hazards7/boards.sh [code|paint|both] [tipo:tela:nó ...]
# Janela mínima fora da vista; o SubViewport interno renderiza a 1280x720.
G="/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="C:/gnosis-wt/_caps/perigos7/raw"
mkdir -p "$OUT"
mode="${1:-both}"; shift
JOBS="$@"
[ -z "$JOBS" ] && JOBS="pendulum:21:e2.1a bell:34:e3.5a guillotine:56:e6.0b spears:34:e3.5a shackles:21:e2.1a maw:13:e1.2a spores:48:e5.1a totem:3:e0.1b sinking:4:e0.2a mirror:40:e4.2a shards:65: tide:4:e0.2b vault:8:e0.6a altar:3:e0.1c ward:3:e0.1c"
for m in code paint; do
  [ "$mode" != "both" ] && [ "$mode" != "$m" ] && continue
  timeout 900 "$G" --audio-driver Dummy --path "$WT" --resolution 320x180 --position 4000,4000 \
    res://tools/hazards7/HzBoard.tscn -- shots "$OUT" $m $JOBS 2>&1 | grep -E "SCRIPT ERROR|Parse Error|HZ:" | head -20
done
ls "$OUT" | wc -l
