#!/bin/bash
# Captura as telas de aceite do cenário (1280x720). Uso: caps.sh <prefixo> [telas...]
# Linux/nuvem: roda sob xvfb (OpenGL por software). No Windows, defina G/WT/OUT.
# Variáveis: SHOT (cena; padrão CleanShot sem legenda), FRAMES (padrão 150), EXTRA (args).
G="${G:-godot}"
WT="${WT:-$(cd "$(dirname "$0")/../.." && pwd)}"
OUT="${OUT:-/home/user/caps/cenario}"
mkdir -p "$OUT"
P="$1"; shift
SCREENS="${@:-1 3 12 22 30 40 50 60 65 68}"
for s in $SCREENS; do
  if command -v xvfb-run >/dev/null 2>&1; then
    timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --audio-driver Dummy --rendering-driver opengl3 --path "$WT" --resolution 1280x720 "${SHOT:-res://tools/scenery/CleanShot.tscn}" -- $s "$OUT/${P}_$s.png" ${FRAMES:-150} $EXTRA 2>&1 | grep -E "SHOT|SCRIPT ERROR|Parse Error|ERROR" | head -5
  else
    timeout 240 "$G" --audio-driver Dummy --path "$WT" --resolution 1280x720 --position 4000,4000 "${SHOT:-res://tools/scenery/CleanShot.tscn}" -- $s "$OUT/${P}_$s.png" ${FRAMES:-150} $EXTRA 2>&1 | grep -E "SHOT|SCRIPT ERROR|Parse Error|ERROR" | head -5
  fi
done
