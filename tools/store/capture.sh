#!/bin/bash
# Capturas REAIS do jogo para a loja (1920x1080, sem legendas, sem som).
# Grava uma sequência por tela (Sophia fazendo o roteiro "demo") para escolher
# o quadro mais forte. NÃO é determinístico (é o jogo rodando); os quadros
# escolhidos são copiados para assets/store/src/ e daí o build_store.py é
# determinístico.
# Uso: tools/store/capture.sh [saida] [telas...]
#   ex.: tools/store/capture.sh /home/user/caps/loja/raw 1 10 65 68
# Variáveis: FRAMES (início, padrão 150), SEQ (quadros, 24), EVERY (12), RES (1920x1080),
#   EXTRA (padrão "drive god": a Sophia luta de perto e não morre; ex.: "drive god hurt").
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-/home/user/caps/loja/raw}"; shift || true
SCREENS="${@:-1 10 19 28 37 46 55 64 65 66 68}"
mkdir -p "$OUT"
for s in $SCREENS; do
  RESV="${RES:-1920x1080}"
  timeout 1800 xvfb-run -a -s "-screen 0 ${RESV}x24" godot --audio-driver Dummy \
    --rendering-driver opengl3 --fixed-fps 60 --path "$WT" --resolution "$RESV" \
    "res://tools/store/StoreShot.tscn" -- "$s" "$OUT/s${s}.png" "${FRAMES:-150}" \
    "seq=${SEQ:-24}" "every=${EVERY:-12}" ${EXTRA:-drive god} 2>&1 \
    | grep -E "SHOT|SCRIPT ERROR|Parse Error" | head -5
done
