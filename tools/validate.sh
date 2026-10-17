#!/usr/bin/env bash
# GNOSIS — validação em UM comando (equivalente Linux/nuvem do tools/validate.ps1).
# (a) editor headless compila tudo e reimporta; (b) roda as QAs headless; (c) resumo.
# Uso: tools/validate.sh [--full] [--only "CodexQA SaveQA"] [--skip "GnoseQA"] [--path <proj>]
# Variáveis: GODOT (padrão: godot no PATH), TIMEOUT (s por etapa, padrão 240), LOGDIR.
# Todo Godot roda com --headless --audio-driver Dummy (silêncio obrigatório).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(dirname "$HERE")"
FULL=0; ONLY=""; SKIP=""
while [ $# -gt 0 ]; do
	case "$1" in
		--full) FULL=1 ;;
		--only) ONLY="$2"; shift ;;
		--skip) SKIP="$2"; shift ;;
		--path) PROJ="$(cd "$2" && pwd)"; shift ;;
		*) echo "argumento desconhecido: $1"; exit 2 ;;
	esac
	shift
done
GODOT="${GODOT:-godot}"
TIMEOUT="${TIMEOUT:-240}"
LOGDIR="${LOGDIR:-${TMPDIR:-/tmp}/gnosis_validate/$(basename "$PROJ")}"
mkdir -p "$LOGDIR"
[ -f "$PROJ/project.godot" ] || { echo "ERRO: $PROJ não tem project.godot"; exit 2; }

FAST="ScriptCheck CodexQA AudioQA GnoseQA SaveQA PuppetQA HeroQA WaveQA"
SLOW="CodexPlaytest"
FATAL='SCRIPT ERROR|Parse Error|Failed to load script|Compile Error|Invalid call|Invalid access|Cannot call method|QA FAIL|PLAYTEST FAIL'

want() {
	local n="$1"
	if [ -n "$ONLY" ]; then case " $ONLY " in *" $n "*) ;; *) return 1 ;; esac; fi
	case " $SKIP " in *" $n "*) return 1 ;; esac
	return 0
}

FAILS=0; SUMMARY=""
step() {
	local name="$1"; shift
	local log="$LOGDIR/$name.log"
	local t0=$(date +%s)
	timeout --kill-after=5 "$TIMEOUT" "$GODOT" --headless --audio-driver Dummy --path "$PROJ" "$@" >"$log" 2>&1
	local code=$?
	local secs=$(( $(date +%s) - t0 ))
	local bad; bad=$(grep -E "$FATAL" "$log" | head -5)
	local passes; passes=$(grep -cE 'QA PASS|PLAYTEST PASS' "$log")
	local st="OK"
	if [ $code -eq 124 ] || [ $code -eq 137 ]; then st="TEMPO"
	elif [ $code -ne 0 ] || [ -n "$bad" ]; then st="FALHOU"; fi
	[ "$st" = "OK" ] || FAILS=$((FAILS+1))
	SUMMARY+=$(printf '%-14s %-7s %4ss  pass=%s  code=%s' "$name" "$st" "$secs" "$passes" "$code")$'\n'
	if [ "$st" != "OK" ]; then
		SUMMARY+="    log: $log"$'\n'
		[ -n "$bad" ] && SUMMARY+=$(echo "$bad" | sed 's/^/    | /')$'\n'
	fi
	echo "-> $name: $st (${secs}s)"
}

echo "GNOSIS validate — $PROJ"
echo "Godot: $GODOT   Logs: $LOGDIR"
if want Scripts; then step Scripts --editor --quit; fi
for q in $FAST; do want "$q" && step "$q" "res://tools/$q.tscn"; done
# QA do Técnico2 (checkpoints, demo, desbloqueios, conquistas): troca de cena
# e conta tempo em quadros → --fixed-fps 60, como as regressões.
if want TecnicoQA; then step TecnicoQA --fixed-fps 60 "res://tools/tecnico/TecnicoQA.tscn"; fi
if [ $FULL -eq 1 ]; then for q in $SLOW; do want "$q" && step "$q" "res://tools/$q.tscn"; done; fi
echo
echo "=== RESUMO ==="
printf '%s' "$SUMMARY"
if [ $FAILS -eq 0 ]; then echo "TUDO VERDE"; exit 0; else echo "VERMELHO: $FAILS etapa(s)"; exit 1; fi
