#!/usr/bin/env bash
# QA-VISUAL 2: RunProbe (tools/qa_ux) em todas as telas com JANELA REAL no canto do monitor.
# Uso: bash tools/qa_visual/run_window.sh <pasta_saida> [paralelo=2] [modo=fight] [telas="1..68"]
# POS (padrão 1200,600) = posição da janela; todo Godot com --audio-driver Dummy.
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?pasta}"; PAR="${2:-2}"; MODE="${3:-fight}"; SCREENS="${4:-$(seq 1 68)}"
GODOT="${GODOT:-/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe}"
TEMPO="${TEMPO:-260}"; POS="${POS:-1200,600}"
mkdir -p "$OUT"
OUTW="$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")"
export WT OUT OUTW MODE GODOT TEMPO POS
one() {
	s="$1"; log="$OUT/s$(printf %02d "$s").log"
	timeout --kill-after=5 "$TEMPO" "$GODOT" --audio-driver Dummy --path "$WT" --resolution 1280x720 --position "$POS" \
		"res://tools/qa_ux/RunProbe.tscn" -- "$s" "$OUTW" 200 "$MODE" > "$log" 2>&1
	rc=$?
	end="$(grep -h '|END|' "$log" | head -1 | cut -c1-200)"
	nb="$(grep -c '|BUG?|' "$log")"
	ne="$(grep -E 'SCRIPT ERROR|^ERROR' "$log" | grep -vc 'resources still in use at exit')"
	echo "tela $s rc=$rc bugs=$nb erros=$ne ${end:-SEM_END}"
}
export -f one
printf "%s\n" $SCREENS | xargs -P "$PAR" -I{} bash -c 'one {}' | sort -k2 -n | tee "$OUT/RESUMO.txt"
tot=$(grep -c . "$OUT/RESUMO.txt")
ok=$(grep -cE '\|END\|(ADVANCED|ENDSCREEN)\|' "$OUT/RESUMO.txt")
nb=$(grep -vc ' bugs=0 ' "$OUT/RESUMO.txt")
ne=$(grep -vc ' erros=0 ' "$OUT/RESUMO.txt")
echo "TOTAL: $ok/$tot telas avançaram · telas com BUG?: $nb · telas com ERROR: $ne" | tee -a "$OUT/RESUMO.txt"
