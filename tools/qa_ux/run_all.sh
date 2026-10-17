#!/usr/bin/env bash
# QA-UX: roda a RunProbe em todas as telas (paralelo), 1 log (+ PNGs) por tela.
# Uso: bash tools/qa_ux/run_all.sh <pasta_saida> [paralelo=2] [modo=fight] [telas="1..68"]
# Variáveis:
#   RENDER=headless (padrão: rápido, determinístico com --fixed-fps 60, SEM PNG)
#   RENDER=xvfb     (janela virtual Xvfb + opengl3: grava os PNGs; ~2x mais lento)
#   RENDER=window   (Windows/Git Bash ou Linux com monitor: janela fora da tela)
#   GODOT (padrão: godot no PATH), TEMPO (s por tela, padrão 260)
# Todo Godot roda com --audio-driver Dummy (silêncio obrigatório).
# Saída: <pasta>/sNN.log por tela e <pasta>/RESUMO.txt (uma linha por tela).
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-/home/user/caps/qa/run}"
PAR="${2:-2}"
MODE="${3:-fight}"
SCREENS="${4:-$(seq 1 68)}"
RENDER="${RENDER:-headless}"
TEMPO="${TEMPO:-260}"
if [ -z "${GODOT:-}" ]; then
	if command -v godot >/dev/null 2>&1; then GODOT=godot
	else GODOT=/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe; fi
fi
mkdir -p "$OUT"
OUTW="$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")"
export WT OUT OUTW MODE GODOT RENDER TEMPO
one() {
	s="$1"
	log="$OUT/s$(printf %02d "$s").log"
	case "$RENDER" in
		headless)
			timeout --kill-after=5 "$TEMPO" "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path "$WT" \
				"res://tools/qa_ux/RunProbe.tscn" -- "$s" "$OUTW" 200 "$MODE" > "$log" 2>&1 ;;
		xvfb)
			timeout --kill-after=5 "$TEMPO" xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --audio-driver Dummy \
				--rendering-driver opengl3 --path "$WT" --resolution 1280x720 \
				"res://tools/qa_ux/RunProbe.tscn" -- "$s" "$OUTW" 200 "$MODE" > "$log" 2>&1 ;;
		*)
			timeout --kill-after=5 "$TEMPO" "$GODOT" --audio-driver Dummy --path "$WT" --resolution 1280x720 --position 4000,4000 \
				"res://tools/qa_ux/RunProbe.tscn" -- "$s" "$OUTW" 200 "$MODE" > "$log" 2>&1 ;;
	esac
	rc=$?
	end="$(grep -h '|END|' "$log" | head -1 | cut -c1-200)"
	nb="$(grep -c '|BUG?|' "$log")"
	# "resources still in use at exit" = vazamento inofensivo ao sair (REVISAO #15): não conta.
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
