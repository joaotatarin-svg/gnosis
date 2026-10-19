#!/usr/bin/env bash
# UI7: roda a sonda em PT e EN. Uso: bash tools/ui7/run_probe.sh <pasta_saida> [casos]
set -u
WT=$(cd "$(dirname "$0")/../.." && pwd)
G=/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe
OUT=${1:?pasta}; CASOS=${2:-all}
mkdir -p "$OUT"
OUTW=$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")
for L in pt en; do
	ARGS=("$OUTW")
	[ "$CASOS" != "all" ] && ARGS+=("$CASOS")
	GNOSIS_LANG=$L timeout --kill-after=5 400 "$G" --audio-driver Dummy --fixed-fps 60 --path "$WT" \
		--resolution 320x180 --position 4000,4000 res://tools/ui7/UI7Probe.tscn -- "${ARGS[@]}" --bestiario-tudo \
		> "$OUT/probe_$L.log" 2>&1
	echo "$L rc=$? $(grep -c 'UI7|FALHA' "$OUT/probe_$L.log") falha(s), $(grep -cE 'SCRIPT ERROR' "$OUT/probe_$L.log") script error(s)"
done
