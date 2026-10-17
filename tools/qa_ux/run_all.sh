#!/usr/bin/env bash
# QA-UX: roda a RunProbe em todas as telas (paralelo), 1 log + PNGs por tela.
# Uso: bash tools/qa_ux/run_all.sh <pasta_saida> [paralelo=4] [modo=fight] [telas="1..68"]
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-/c/gnosis-wt/_caps/qa-ux/run}"
PAR="${2:-4}"
MODE="${3:-fight}"
SCREENS="${4:-$(seq 1 68)}"
GODOT="${GODOT:-/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe}"
mkdir -p "$OUT"
OUTW="$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")"
export WT OUT OUTW MODE GODOT
one() {
	s="$1"
	timeout 260 "$GODOT" --audio-driver Dummy --path "$WT" --resolution 1280x720 --position 4000,4000 \
		"res://tools/qa_ux/RunProbe.tscn" -- "$s" "$OUTW" 200 "$MODE" > "$OUT/s$(printf %02d "$s").log" 2>&1
	echo "tela $s rc=$? $(grep -h '|END|' "$OUT/s$(printf %02d "$s").log" | cut -c1-160)"
}
export -f one
printf "%s\n" $SCREENS | xargs -P "$PAR" -I{} bash -c 'one {}'
