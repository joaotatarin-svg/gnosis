#!/usr/bin/env bash
# QA-VISUAL: capturas extras (menus, HUD, diálogos, GIFs da Sophia e de chefes).
# Uso: bash tools/qa_visual/shots.sh <pasta_saida> [grupo: menus|hud|dialog|gif|all]
# Todo Godot com --audio-driver Dummy e janela fora do monitor (silêncio obrigatório).
set -u
WT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-/c/gnosis-wt/_caps/qa-visual/extra}"
GRP="${2:-all}"
GODOT="${GODOT:-/c/Users/jmtat/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.1-stable_win64_console.exe}"
mkdir -p "$OUT"
OUTW="$(cygpath -m "$OUT" 2>/dev/null || echo "$OUT")"
shot() {  # shot <nome> <tela|res://> [frames] [extras...]
	local name="$1"; shift
	local target="$1"; shift
	local fr="${1:-120}"; shift || true
	timeout 300 "$GODOT" --audio-driver Dummy --fixed-fps 60 --path "$WT" --resolution 1280x720 --position "${POS:-1200,600}" \
		res://tools/Shot.tscn -- "$target" "$OUTW/$name.png" "$fr" "$@" > "$OUT/$name.log" 2>&1
	echo "$name rc=$? $(grep -c 'SCRIPT ERROR\|ERROR:' "$OUT/$name.log") erros"
}
if [ "$GRP" = menus ] || [ "$GRP" = all ]; then
	for s in MainMenu PreGame OptionsMenu Chronicles Credits CharacterAtelier Gallery EndScreen UpgradeMenu PauseMenu; do
		shot "menu_$s" "res://scenes/ui/$s.tscn" 90
	done
	shot menu_Provacao "res://scenes/levels/CodexTrial.tscn" 240
fi
if [ "$GRP" = hud ] || [ "$GRP" = all ]; then
	for s in 10 37 64; do shot "hud_boss${s}_f2" "$s" 360 hurt; done
	shot hud_68 68 240
	shot hud_68_f2 68 420 hurt
	shot hud_22_kill 22 240 kill
	shot hud_50 50 200
	shot hud_66 66 200
	shot hud_die 12 240 die
fi
if [ "$GRP" = dialog ] || [ "$GRP" = all ]; then
	for s in 1 10 19 55 64 68; do shot "dlg_$s" "$s" 40 dialog; done
fi
if [ "$GRP" = gif ] || [ "$GRP" = all ]; then
	for a in walk combo heavy dodge magic jump; do
		shot "sophia_$a" 3 60 seq=50 every=2 act=$a solo hold
		python "$WT/tools/seq_to_media.py" "$OUT/sophia_$a" --follow player --suffix _follow --no-mp4 >/dev/null 2>&1
	done
	for s in 10 37 64; do
		shot "boss_$s" "$s" 200 seq=90 every=2 act=idle hold
		python "$WT/tools/seq_to_media.py" "$OUT/boss_$s" --follow boss --suffix _follow --no-mp4 >/dev/null 2>&1
	done
fi
