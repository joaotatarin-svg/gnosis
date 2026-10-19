# QA7 — re-teste: roda o QA7Bot nas 3 sementes em paralelo, em prioridade BelowNormal,
# e depois o analisador. Uso: powershell -File tools/qa7/reteste.ps1 -Out C:\gnosis-wt\_caps\qa7\bot31
param(
	[string]$Out = "C:\gnosis-wt\_caps\qa7\bot31",
	[string]$Proj = "C:\gnosis-wt\qa7",
	[int[]]$Seeds = @(1, 2, 3),
	[int]$Vel = 4
)
$godot = "C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
$procs = @()
foreach ($s in $Seeds) {
	$outBase = ($Out -replace '\\', '/') + "/s$s"
	$args = @("--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", $Proj,
		"res://tools/qa7/QA7Bot.tscn", "--", "1", "68", "$Vel", "seed=$s", "ia=3", "out=$outBase")
	$p = Start-Process -FilePath $godot -ArgumentList $args -NoNewWindow -PassThru `
		-RedirectStandardOutput "$Out\s$s.log" -RedirectStandardError "$Out\s$s.err"
	try { $p.PriorityClass = "BelowNormal" } catch {}
	$procs += $p
	Write-Output "semente $s -> PID $($p.Id) (BelowNormal)"
}
foreach ($p in $procs) {
	if (-not $p.WaitForExit(7200 * 1000)) { try { $p.Kill() } catch {}; Write-Output "PID $($p.Id) estourou 2 h e foi encerrado" }
}
$env:PYTHONIOENCODING = "utf-8"
$labels = $Seeds | ForEach-Object { "s$_" }
python "$Proj\tools\qa7\analisa_bot.py" $Out @labels | Out-File -Encoding utf8 "$Out\analise.md"
Write-Output "pronto: $Out\analise.md"
