#!/usr/bin/env bash
# GNOSIS — rodada do BOT DE BALANCE em UM comando (Linux/nuvem).
# Uso: tools/balance/run.sh <rotulo> [tela_ini=1] [tela_fim=68] [vel=1] [seed=1] [opções do bot...]
#   Opções extras vão direto ao bot (ex.: loja=gasta).
#   Gera <OUT>/<rotulo>.txt (tabela), .csv (por tela, com dano por fonte) e .log.
#   Sempre --fixed-fps 60 (determinístico: mesma semente = mesma rodada).
#   Variáveis: OUT (padrão /home/user/caps/balance/runs), GODOT (padrão godot),
#   TIMEOUT (s, padrão 3600), BG=1 roda em segundo plano (nohup) e retorna já.
# Comparar duas rodadas (ex.: r8 × r9 depois do Combate):
#   python3 tools/balance/compare.py <OUT>/r8.csv <OUT>/r9.csv
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
LABEL="${1:?uso: run.sh <rotulo> [ini] [fim] [vel] [seed]}"
INI="${2:-1}"; FIM="${3:-68}"; VEL="${4:-1}"; SEED="${5:-1}"
shift $(( $# < 5 ? $# : 5 ))
EXTRA=("$@")
OUT="${OUT:-/home/user/caps/balance/runs}"
GODOT="${GODOT:-godot}"
TIMEOUT="${TIMEOUT:-3600}"
mkdir -p "$OUT"
CMD=(timeout --kill-after=10 "$TIMEOUT" "$GODOT" --headless --audio-driver Dummy --fixed-fps 60
	--path "$PROJ" res://tools/BalanceBot.tscn -- "$INI" "$FIM" "$VEL" "seed=$SEED" "out=$OUT/$LABEL" "${EXTRA[@]}")
echo "balance: $LABEL (telas $INI-$FIM, vel $VEL, seed $SEED ${EXTRA[*]}) -> $OUT/$LABEL.{txt,csv,log}"
if [ "${BG:-0}" = "1" ]; then
	nohup "${CMD[@]}" >"$OUT/$LABEL.log" 2>&1 &
	echo "em segundo plano (pid $!). Progresso: grep BAT $OUT/$LABEL.log | tail -1"
	exit 0
fi
"${CMD[@]}" >"$OUT/$LABEL.log" 2>&1
code=$?
grep -E 'SCRIPT ERROR|Parse Error' "$OUT/$LABEL.log" | head -5
if [ -f "$OUT/$LABEL.txt" ]; then
	grep -E '^(BALANCE|TOTAL|FONTES)' "$OUT/$LABEL.txt"
else
	echo "ERRO: a rodada não gerou $OUT/$LABEL.txt (código $code) — veja $OUT/$LABEL.log"
	exit 1
fi
exit $code
