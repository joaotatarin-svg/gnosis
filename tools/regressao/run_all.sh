#!/usr/bin/env bash
# GNOSIS — QAs de REGRESSÃO dos bugs conhecidos (QA_UX_BUGS + REVISAO).
# Cada teste roda num Godot próprio (headless, silêncio, --fixed-fps 60) e
# imprime REG|<ID>|PASS ou REG|<ID>|FAIL. PASS = o bug NÃO acontece mais.
# Uso: tools/regressao/run_all.sh [IDs...]        (padrão: todos)
#      AUTOTESTE=1 tools/regressao/run_all.sh B1  (o teste simula a correção: deve dar PASS)
# Variáveis: GODOT (padrão godot), TEMPO (s por teste, padrão 400; a máquina compartilhada pode ser lenta), LOGDIR.
# Saída: tabela ID · bug · estado · falhas; código 0 só se TODOS passarem.
# SEGURANÇA: R3 grava no user:// e só roda com override.cfg isolado (GNOSIS-WT-<cargo>).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
GODOT="${GODOT:-godot}"
TEMPO="${TEMPO:-400}"
LOGDIR="${LOGDIR:-${TMPDIR:-/tmp}/gnosis_regressao/$(basename "$PROJ")}"
mkdir -p "$LOGDIR"

declare -A BUG=(
	[B1]="Controle: A não confirma / B não volta (softlock na tentação)"
	[A1]="Loja sem foco; setas/Enter/Esc não funcionam"
	[A2]="Legenda por cima da pausa/loja/Opções/Golpes"
	[A3]="Batalha final: uma barra para dois chefes"
	[A4]="Morte congela no ar e não anima 'dead'"
	[A5]="Câmera: Sophia fora da tela na parede; mostra além do limite"
	[A6]="Escolha final estoura a caixa; motivo do Semente invisível"
	[R1]="Morte × queda do Arconte: volta ao início do Éon com o Anel"
	[R3]="Save não atômico: queda na gravação apaga o progresso"
	[R10]="Pausa global: quem fecha despausa tudo; timer de morte ignora pausa"
)
ORDEM="B1 A1 A2 A3 A4 A5 A6 R1 R3 R10"
IDS="${*:-$ORDEM}"
EXTRA=""
[ "${AUTOTESTE:-0}" = "1" ] && EXTRA="autoteste"

TOTAL=0; OK=0; LINHAS=""
for id in $IDS; do
	log="$LOGDIR/$id.log"
	t0=$(date +%s)
	timeout --kill-after=5 "$TEMPO" "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path "$PROJ" \
		"res://tools/regressao/Reg.tscn" -- "$id" $EXTRA >"$log" 2>&1
	code=$?
	secs=$(( $(date +%s) - t0 ))
	if grep -q "^REG|$id|PASS" "$log"; then st="PASS"; OK=$((OK+1))
	elif grep -q "^REG|$id|FAIL" "$log"; then st="FAIL"
	elif [ $code -eq 124 ] || [ $code -eq 137 ]; then st="TEMPO"
	else st="QUEBRADO"; fi
	# erro de script durante o teste invalida um PASS
	if [ "$st" = "PASS" ] && grep -qE 'SCRIPT ERROR|Parse Error' "$log"; then st="PASS*ERRO"; OK=$((OK-1)); fi
	TOTAL=$((TOTAL+1))
	falhas=$(grep -c "^REG|$id|CHECK|.*|FALHA|" "$log")
	checks=$(grep -c "^REG|$id|CHECK|" "$log")
	LINHAS+=$(printf '%-4s %-10s %2s/%-2s falhas  %3ss  %s' "$id" "$st" "$falhas" "$checks" "$secs" "${BUG[$id]:-?}")$'\n'
	echo "-> $id: $st ($falhas/$checks falhas, ${secs}s)  log: $log"
	grep "^REG|$id|CHECK|.*|FALHA|" "$log" | cut -c1-220 | sed 's/^/     /'
done
echo
echo "=== REGRESSÃO (PASS = bug não acontece mais) ==="
printf '%s' "$LINHAS"
echo "PASS: $OK/$TOTAL   logs: $LOGDIR"
[ $OK -eq $TOTAL ] && exit 0 || exit 1
