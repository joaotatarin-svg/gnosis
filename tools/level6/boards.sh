#!/bin/bash
# Gera as faixas de layout (Board.tscn) de várias telas.
# Uso: tools/level6/boards.sh <prefixo> <tela> [tela...]   (ex.: antes 2 3 12)
G="/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="/c/gnosis-wt/_caps/level6"
mkdir -p "$OUT"
pre="$1"; shift
for s in "$@"; do
  timeout 150 "$G" --audio-driver Dummy --path "$WT" --resolution 320x180 --position 4000,4000 \
    res://tools/level6/Board.tscn -- "$s" "C:/gnosis-wt/_caps/level6/${pre}_$(printf %02d $s).png" $EXTRA 2>&1 \
    | grep -E "BOARD|SCRIPT ERROR|Parse Error" | head -5
done
