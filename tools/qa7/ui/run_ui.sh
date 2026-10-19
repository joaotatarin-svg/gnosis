#!/usr/bin/env bash
# QA7 UI: capturas PT e EN via LangWrap (Shot.tscn). Uso: bash run_ui.sh <grupo> [par=2]
set -u
WT=/c/gnosis-wt/qa7
G=/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe
RAW=/c/gnosis-wt/_caps/qa7/ui/raw
RAWW=C:/gnosis-wt/_caps/qa7/ui/raw
mkdir -p $RAW
export WT G RAW RAWW
one() {  # one "<lang> <nome> <alvo> <frames> [extras]"
	set -- $1
	local lang=$1 name=$2 tgt=$3 fr=$4; shift 4
	QA7_LANG=$lang QA7_TARGET=res://tools/Shot.tscn timeout --kill-after=5 200 "$G" --audio-driver Dummy --fixed-fps 60 \
		--path $WT --resolution 1280x720 --position 4000,4000 res://tools/qa7/ui/LangWrap.tscn -- \
		"$tgt" "$RAWW/${lang}_$name.png" "$fr" "$@" > "$RAW/${lang}_$name.log" 2>&1
	echo "${lang}_$name rc=$? err=$(grep -cE 'SCRIPT ERROR|^ERROR' $RAW/${lang}_$name.log)"
}
export -f one
GRP=${1:-menus}; PAR=${2:-2}
L=()
case $GRP in
menus) for s in MainMenu PreGame OptionsMenu PauseMenu UpgradeMenu CharacterAtelier Chronicles Gallery Credits EndScreen WorldMap; do
	for l in pt_BR en; do L+=("$l $s res://scenes/ui/$s.tscn 90"); done; done ;;
hud) for l in pt_BR en; do
	L+=("$l hud22 22 240 kill" "$l hud10f2 10 360 hurt" "$l hud68f2 68 420 hurt" "$l hud50 50 200" "$l hud3 3 200"); done ;;
dialog) for l in pt_BR en; do for s in 1 10 17 37 64 65 68; do L+=("$l dlg$s $s 40 dialog"); done; done ;;
esac
printf "%s\n" "${L[@]}" | xargs -P $PAR -I{} bash -c 'one "{}"'
