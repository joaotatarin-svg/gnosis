#!/bin/bash
# Mede o tempo de quadro do cenário nas telas dadas (janela 1280x720 fora da tela).
G="/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
for s in ${@:-3 22 50 68}; do
  timeout 120 "$G" --path "C:/gnosis-wt/cenario" --resolution 1280x720 --position 4000,4000 "res://tools/scenery/Bench.tscn" -- $s 2>&1 | grep -E "BENCH|SCRIPT ERROR|Parse Error"
done
