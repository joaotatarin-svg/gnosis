#!/usr/bin/env bash
# QA7: cinemáticas (CineShot), cenas (CenaShot) e Soter via LangWrap, PT e EN. Uso: bash run_cenas.sh <grupo> [par=2]
set -u
WT=/c/gnosis-wt/qa7
G=/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe
RAW=/c/gnosis-wt/_caps/qa7/ui/cena
RAWW=C:/gnosis-wt/_caps/qa7/ui/cena
mkdir -p $RAW
export WT G RAW RAWW
one() {  # "<lang> <nome> <alvo.tscn> <args...>"  (args: __P__ = prefixo de saída)
	set -- $1
	local lang=$1 name=$2 tgt=$3; shift 3
	local args=()
	for x in "$@"; do args+=("${x//__P__/$RAWW/${lang}_$name}"); done
	QA7_LANG=$lang QA7_TARGET=$tgt timeout --kill-after=5 ${TEMPO:-300} "$G" --audio-driver Dummy --fixed-fps 60 \
		--path $WT --resolution 1280x720 --position 4000,4000 res://tools/qa7/ui/LangWrap.tscn -- "${args[@]}" \
		> "$RAW/${lang}_$name.log" 2>&1
	echo "${lang}_$name rc=$? err=$(grep -cE 'SCRIPT ERROR|^ERROR' $RAW/${lang}_$name.log)"
}
export -f one
GRP=${1:-cine}; PAR=${2:-2}
L=()
for l in pt_BR en; do
case $GRP in
cine) for m in prologue ascensao ruptura semente; do L+=("$l cine_$m res://tools/qa7/ui/CineShot.tscn $m __P__"); done ;;
cenas) for s in 64 65 66 67 68; do L+=("$l cena$s res://tools/encenacao/CenaShot.tscn $s __P__ hold=70 kill=60 free=6 max=5000"); done ;;
soter) L+=("$l soter res://tools/encenacao/SoterProbe.tscn __P__") ;;
esac
done
printf "%s\n" "${L[@]}" | xargs -P $PAR -I{} bash -c 'one "{}"'
