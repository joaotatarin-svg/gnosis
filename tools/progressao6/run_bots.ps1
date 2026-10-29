# Progressão 7 — lote do ProgBot (run inteiro, headless, sem som) em BelowNormal
# e no máximo 4 CPUs lógicas (regra dos lotes longos, 19/10).
# Uso: powershell -File tools/progressao6/run_bots.ps1 -Out C:\gnosis-wt\_caps\progressao7\r1 `
#        -Jobs "dif=0 perfil=arma seed=1;dif=1 perfil=arma seed=1"   (jobs separados por ;)
# Cada job vira <Out>\<nome>.csv/.txt/.log (nome = argumentos sem espaço).
param(
	[Parameter(Mandatory = $true)][string]$Out,
	[Parameter(Mandatory = $true)][string]$Jobs,
	[string]$Project = "",
	[int]$Speed = 4,
	[int64]$Affinity = 0xF0
)
$godot = "C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
if ($Project -eq "") { $Project = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path }
$procs = @()
foreach ($j in ($Jobs -split ';')) {
	$name = ($j -replace '[ =]', '_')
	$base = (Join-Path $Out $name) -replace '\\', '/'
	$argv = @("--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", "`"$Project`"",
		"res://tools/progressao6/ProgBot.tscn", "--", "1", "68", "$Speed", "ia=3", "loja=real") + ($j -split ' ') + @("out=$base")
	$p = Start-Process -FilePath $godot -ArgumentList $argv -PassThru -WindowStyle Hidden `
		-RedirectStandardOutput "$base.log" -RedirectStandardError "$base.err"
	Start-Sleep -Milliseconds 1500
	try { $p.PriorityClass = 'BelowNormal'; $p.ProcessorAffinity = [IntPtr]$Affinity } catch {}
	# o *_console.exe abre o Godot de verdade como FILHO: a regra vale para ele também
	Get-CimInstance Win32_Process -Filter "ParentProcessId = $($p.Id)" | ForEach-Object {
		try { $c = Get-Process -Id $_.ProcessId; $c.PriorityClass = 'BelowNormal'; $c.ProcessorAffinity = [IntPtr]$Affinity } catch {}
	}
	$procs += $p
	"PID $($p.Id) $j"
}
$procs | Wait-Process -Timeout 7200 -ErrorAction SilentlyContinue
foreach ($p in $procs) { if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force } }
"fim" | Out-File (Join-Path $Out "done.txt")
