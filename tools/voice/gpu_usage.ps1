# Mede o uso médio da GPU (todas as engines 3D/Compute) por N segundos.
# Regra do PC (_REGRAS.md §GPU): síntese de voz ≤ 25% de uso médio da RX.
# Uso: powershell -File tools\voice\gpu_usage.ps1 [segundos]
param([int]$Segundos = 60)
$amostras = @()
for ($i = 0; $i -lt $Segundos; $i += 2) {
	$e = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -match "engtype_(3D|Compute)" }
	# por engine: soma dos processos; o uso da GPU = a engine mais ocupada
	$porEngine = $e | Group-Object { ($_.Name -replace "^pid_\d+_", "") } | ForEach-Object { ($_.Group | Measure-Object UtilizationPercentage -Sum).Sum }
	$amostras += ($porEngine | Measure-Object -Maximum).Maximum
	Start-Sleep -Seconds 2
}
$m = ($amostras | Measure-Object -Average -Maximum)
"GPU uso medio {0:N1}% (pico {1:N0}%) em {2} s" -f $m.Average, $m.Maximum, $Segundos
