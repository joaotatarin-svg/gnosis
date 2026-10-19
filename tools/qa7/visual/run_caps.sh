#!/bin/bash
# QA7 visual: roda uma lista de capturas (2 Godot por vez, janela 640x360 fora da vista).
# Linha da lista: nome|tela|frames|extras|nó|dj   (Shot via NodeShot)
# Uso: bash run_caps.sh lista.txt
G="/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe"
WT="C:/gnosis-wt/qa7"
OUT="C:/gnosis-wt/_caps/qa7/visual/raw"
mkdir -p "$OUT"
one() {
  IFS='|' read -r name scr fr ex node dj <<< "$1"
  [ -z "$name" ] && return
  QA7_NODE="$node" QA7_DJ="$dj" timeout 240 "$G" --audio-driver Dummy --fixed-fps 60 --path "$WT" \
    --resolution 640x360 --position 4000,4000 res://tools/qa7/visual/NodeShot.tscn -- \
    "$scr" "$OUT/$name.png" "$fr" $ex > "$OUT/$name.log" 2>&1
  echo "$name rc=$? err=$(grep -c 'SCRIPT ERROR\|Parse Error' "$OUT/$name.log")"
}
export -f one; export G WT OUT
grep -v '^#' "$1" | grep -v '^$' | xargs -d '\n' -P 2 -I{} bash -c 'one "$@"' _ {}
