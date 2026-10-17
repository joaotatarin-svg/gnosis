#!/usr/bin/env bash
# QA-VISUAL: FPS real com tools/PerfProbe.tscn (renderer de verdade, GPU local).
# Uso: bash tools/qa_visual/perf.sh <pasta_saida> [telas="3 22 50 64 68"] [n="12 24"] [seg=12]
# Roda UMA medição por vez (nada em paralelo, senão o número é falso).
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-/c/gnosis-wt/_caps/qa-visual/perf}"
TELAS="${2:-3 22 50 64 68}"
NS="${3:-12 24}"
SEG="${4:-12}"
GODOT="${GODOT:-/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe}"
mkdir -p "$OUT"
OUTW="$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")"
for t in $TELAS; do for n in $NS; do for v in ${VSYNCS:-0 1}; do
	name="t${t}_n${n}_v${v}"
	timeout 240 "$GODOT" --audio-driver Dummy --path "$WT" --resolution 1280x720 --position 4000,4000 \
		res://tools/qa_visual/PerfTimeline.tscn -- tela=$t n=$n seg=$SEG vsync=$v ataque=1 out="$OUTW/$name.json" > "$OUT/$name.log" 2>&1
	rc=$?
	echo "$name rc=$rc $(grep -h -E '^PERF|^SPIKES' "$OUT/$name.log" | cut -c1-400 | paste -sd' ')"
done; done; done
