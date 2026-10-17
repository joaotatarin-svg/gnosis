#!/usr/bin/env bash
# GNOSIS — DESEMPENHO em um comando (agente de Desempenho, Onda 2).
# Uso: tools/perf/run.sh [perfil|engasgos|alloc|pck|resumo|tudo]   (padrão: tudo)
# Variáveis:
#   OUT    pasta de saída (padrão /home/user/caps/perf/run)   GODOT (padrão: godot)
#   TELAS  telas do perfil (padrão "1 3 10 22 36 50 63 64 65 68")
#   N      criaturas extras no perfil (padrão 12)   SEG  segundos medidos (padrão 8)
#   REPS   repetições da sonda de engasgos por configuração (padrão 3; usa-se o MÍNIMO)
#   ETELA  tela da sonda de engasgos (padrão 3: travessia, sem inimigos até andar)
#   GL     1 = também roda com janela (xvfb + llvmpipe) p/ draw calls e shaders (padrão 1)
# Silêncio obrigatório: todo Godot com --audio-driver Dummy.
# NA NUVEM (sem GPU): o tempo do llvmpipe NÃO vale como medida absoluta — use o
# headless para CPU e a janela só para CONTAR draw calls e shaders compilados.
# Numa máquina com GPU (o PC do João), rode com GL=1 e olhe também os ms.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${OUT:-/home/user/caps/perf/run}"
TELAS="${TELAS:-1 3 10 22 36 50 63 64 65 68}"
N="${N:-12}"; SEG="${SEG:-8}"; REPS="${REPS:-3}"; ETELA="${ETELA:-3}"; GL="${GL:-1}"
MODE="${1:-tudo}"
mkdir -p "$OUT"
cd "$PROJ" || exit 2

# user:// do projeto (o cache de shaders do GLES3 mora em user://shader_cache)
udir() {
	local name
	name=$(sed -n 's/^config\/custom_user_dir_name="\(.*\)"/\1/p' override.cfg project.godot 2>/dev/null | head -1)
	if [ -n "$name" ]; then echo "$HOME/.local/share/$name"; else echo "$HOME/.local/share/godot/app_userdata/GNOSIS"; fi
}
SHADER_CACHE="$(udir)/shader_cache"

hl() {  # headless
	timeout --kill-after=5 "${TMO:-400}" "$GODOT" --headless --audio-driver Dummy --path "$PROJ" "$@"
}
gl() {  # janela (xvfb) pequena: conta draw calls/shaders; tempo só relativo
	timeout --kill-after=5 "${TMO:-900}" xvfb-run -a -s "-screen 0 1280x720x24" \
		"$GODOT" --audio-driver Dummy --rendering-driver opengl3 --path "$PROJ" --resolution 320x180 "$@"
}

perfil() {
	for t in $TELAS; do
		echo "-> perfil tela $t"
		hl res://tools/PerfProbe.tscn -- tela=$t n=0 seg=$SEG out="$OUT/perfil_t${t}_n0_cpu.json" >"$OUT/perfil_t${t}_n0_cpu.log" 2>&1
		hl res://tools/PerfProbe.tscn -- tela=$t n=$N seg=$SEG out="$OUT/perfil_t${t}_n${N}_cpu.json" >"$OUT/perfil_t${t}_n${N}_cpu.log" 2>&1
		if [ "$GL" = "1" ]; then
			LP_NUM_THREADS=2 gl res://tools/PerfProbe.tscn -- tela=$t n=$N seg=4 out="$OUT/perfil_t${t}_n${N}_gl.json" >"$OUT/perfil_t${t}_n${N}_gl.log" 2>&1
		fi
	done
}

engasgos() {
	for r in $(seq 1 "$REPS"); do
		for pw in 0 1; do
			echo "-> engasgos rep $r prewarm=$pw (headless)"
			hl res://tools/perf/HitchProbe.tscn -- tela=$ETELA prewarm=$pw out="$OUT/hitch_cpu_pw${pw}_r${r}.json" >"$OUT/hitch_cpu_pw${pw}_r${r}.log" 2>&1
			if [ "$GL" = "1" ]; then
				echo "-> engasgos rep $r prewarm=$pw (janela, cache de shaders FRIO)"
				rm -rf "$SHADER_CACHE"
				MESA_SHADER_CACHE_DISABLE=true LP_NUM_THREADS=2 gl res://tools/perf/HitchProbe.tscn -- tela=$ETELA prewarm=$pw out="$OUT/hitch_gl_pw${pw}_r${r}.json" >"$OUT/hitch_gl_pw${pw}_r${r}.log" 2>&1
			fi
		done
	done
	if [ "$GL" = "1" ]; then
		# 2ª sessão do jogador: cache de shaders do Godot já QUENTE (sem prewarm)
		echo "-> engasgos cache QUENTE (2ª sessão)"
		LP_NUM_THREADS=2 gl res://tools/perf/HitchProbe.tscn -- tela=$ETELA prewarm=0 out="$OUT/hitch_gl_quente.json" >"$OUT/hitch_gl_quente.log" 2>&1
	fi
}

alloc() {
	echo "-> alocação por quadro (REVISAO #16)"
	hl res://tools/perf/AllocBench.tscn -- n=20000 out="$OUT/alloc.json" >"$OUT/alloc.log" 2>&1
	grep "^ALLOC " "$OUT/alloc.log"
}

pck() {
	echo "-> .pck (export-pack, sem templates)"
	TMO=900 hl --export-pack "Windows Desktop" "$OUT/gnosis.pck" >"$OUT/pck.log" 2>&1
	python3 "$HERE/pck_peso.py" "$OUT/gnosis.pck" --proj "$PROJ" --prof 3 --top 25 --json "$OUT/pck.json" >"$OUT/pck.md"
	head -20 "$OUT/pck.md"
	rm -f "$OUT/gnosis.pck"
}

case "$MODE" in
	perfil) perfil ;;
	engasgos) engasgos ;;
	alloc) alloc ;;
	pck) pck ;;
	resumo) ;;
	tudo) alloc; perfil; engasgos; pck ;;
	*) echo "modo desconhecido: $MODE"; exit 2 ;;
esac
python3 "$HERE/resumo.py" "$OUT" | tee "$OUT/RESUMO.md"
