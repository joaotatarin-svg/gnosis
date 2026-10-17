#!/bin/bash
# Mede o tempo de quadro do cenário nas telas dadas (janela 1280x720).
# Linux/nuvem: xvfb + OpenGL por SOFTWARE (llvmpipe) — o número absoluto não vale
# para GPU de verdade, mas a COMPARAÇÃO antes/depois na mesma máquina vale (e o
# software exagera o custo de pixel, que é o que o cenário gasta).
# No Windows, defina G e WT. Uso: bench.sh [telas...]
G="${G:-godot}"
WT="${WT:-$(cd "$(dirname "$0")/../.." && pwd)}"
for s in ${@:-3 22 50 68}; do
  if command -v xvfb-run >/dev/null 2>&1; then
    timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$G" --audio-driver Dummy --rendering-driver opengl3 --path "$WT" --resolution 1280x720 "res://tools/scenery/Bench.tscn" -- $s 2>&1 | grep -E "BENCH|SCRIPT ERROR|Parse Error"
  else
    timeout 120 "$G" --audio-driver Dummy --path "$WT" --resolution 1280x720 --position 4000,4000 "res://tools/scenery/Bench.tscn" -- $s 2>&1 | grep -E "BENCH|SCRIPT ERROR|Parse Error"
  fi
done
