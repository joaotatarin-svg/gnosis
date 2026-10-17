#!/bin/bash
# Captura as telas de aceite do cenário (1280x720). Uso: caps.sh <prefixo> [telas...]
G="/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
WT="C:/gnosis-wt/cenario"
OUT="C:/gnosis-wt/_caps/cenario"
P="$1"; shift
SCREENS="${@:-1 3 8 22 36 50 64 68}"
for s in $SCREENS; do
  timeout 120 "$G" --path "$WT" --resolution 1280x720 --position 4000,4000 "res://tools/Shot.tscn" -- $s "$OUT/${P}_$s.png" ${FRAMES:-150} 2>&1 | grep -E "SHOT|SCRIPT ERROR|Parse Error|ERROR" | head -5
done
