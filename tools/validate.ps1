<#
.SYNOPSIS
  GNOSIS — validação em UM comando: checa scripts (headless) + roda as QAs rápidas
  e imprime um resumo VERDE/VERMELHO. Sai com 0 (tudo verde) ou 1.

.DESCRIPTION
  (a) `godot --headless --editor --quit` no projeto: falha se houver SCRIPT ERROR /
      Parse Error / "Failed to load script" (também reimporta assets novos).
      Obs.: o editor NÃO reclama de .gd solto (sem cena/class_name) — por isso
      a etapa ScriptCheck carrega cada .gd do projeto.
  (b) roda as cenas de QA headless: ScriptCheck, CodexQA, AudioQA, GnoseQA, SaveQA, PuppetQA,
      HeroQA, WaveQA (cada uma sai com 0/1 sozinha). Com -Full também roda o
      CodexPlaytest (bot jogando o desafio por inputs reais; até ~3 min).
      Toda execução usa `--audio-driver Dummy` (sem som no PC do dono).
  (c) resumo: uma linha por etapa (OK/FALHOU/TEMPO), nº de "QA PASS", tempo,
      e as primeiras linhas de erro de quem falhou. Logs completos em -LogDir.

.PARAMETER Path      Pasta do projeto (worktree). Padrão: a pasta pai de tools/.
.PARAMETER Godot     Executável do Godot (console). Padrão: o do WinGet desta máquina.
.PARAMETER Only      Roda só estas QAs (ex.: -Only CodexQA,SaveQA). "Scripts" = só a etapa (a).
.PARAMETER Skip      Pula estas QAs.
.PARAMETER Full      Inclui as QAs lentas (CodexPlaytest).
.PARAMETER Timeout   Segundos por etapa (padrão 240).
.PARAMETER LogDir    Pasta dos logs (padrão %TEMP%\gnosis_validate\<nome-da-pasta>).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\validate.ps1
  powershell -ExecutionPolicy Bypass -File tools\validate.ps1 -Path C:\gnosis-wt\ui -Skip GnoseQA
#>
param(
	[string]$Path = "",
	[string]$Godot = "",
	[string[]]$Only = @(),
	[string[]]$Skip = @(),
	[switch]$Full,
	[int]$Timeout = 240,
	[string]$LogDir = ""
)

$ErrorActionPreference = "Stop"
if ($Path -eq "") { $Path = Split-Path -Parent $PSScriptRoot }
$Path = (Resolve-Path $Path).Path
if (-not (Test-Path (Join-Path $Path "project.godot"))) {
	Write-Host "ERRO: $Path não tem project.godot" -ForegroundColor Red
	exit 2
}
if ($Godot -eq "") {
	$Godot = "C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
	if (-not (Test-Path $Godot)) {
		$cmd = Get-Command godot -ErrorAction SilentlyContinue
		if ($null -ne $cmd) { $Godot = $cmd.Source }
	}
}
if (-not (Test-Path $Godot)) {
	Write-Host "ERRO: Godot não encontrado ($Godot). Use -Godot <exe>." -ForegroundColor Red
	exit 2
}
if ($LogDir -eq "") { $LogDir = Join-Path $env:TEMP ("gnosis_validate\" + (Split-Path -Leaf $Path)) }
New-Item -ItemType Directory -Force $LogDir | Out-Null

# QAs headless conhecidas (nome -> cena). Rápidas: < 20 s cada nesta máquina.
$fast = [ordered]@{
	"ScriptCheck" = "res://tools/ScriptCheck.tscn"   # compila TODO .gd (até os soltos)
	"CodexQA"  = "res://tools/CodexQA.tscn"
	"AudioQA"  = "res://tools/AudioQA.tscn"
	"GnoseQA"  = "res://tools/GnoseQA.tscn"
	"SaveQA"   = "res://tools/SaveQA.tscn"
	"PuppetQA" = "res://tools/PuppetQA.tscn"
	"HeroQA"   = "res://tools/HeroQA.tscn"
	"WaveQA"   = "res://tools/WaveQA.tscn"
	"TecnicoQA" = "res://tools/tecnico/TecnicoQA.tscn"   # checkpoints/demo/desbloqueios/conquistas (--fixed-fps 60)
}
$slow = [ordered]@{
	"CodexPlaytest" = "res://tools/CodexPlaytest.tscn"
}

# Padrões que reprovam qualquer etapa (erros de script/carregamento).
$fatal = 'SCRIPT ERROR|Parse Error|Failed to load script|Compile Error|Invalid call|Invalid access|Cannot call method|QA FAIL|PLAYTEST FAIL'

function Invoke-Step([string]$name, [string[]]$godotArgs) {
	$out = Join-Path $LogDir "$name.out.log"
	$err = Join-Path $LogDir "$name.err.log"
	$sw = [Diagnostics.Stopwatch]::StartNew()
	$argLine = ($godotArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
	$p = Start-Process -FilePath $Godot -ArgumentList $argLine -WorkingDirectory $Path `
		-NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
	$null = $p.Handle   # (PS 5.1) sem tocar no Handle o ExitCode volta vazio
	$timedOut = -not $p.WaitForExit($Timeout * 1000)
	if ($timedOut) {
		try { Stop-Process -Id $p.Id -Force } catch {}   # mata só o processo que ESTE script abriu
	}
	$p.WaitForExit()
	$sw.Stop()
	$text = ""
	if (Test-Path $out) { $text += [IO.File]::ReadAllText($out) }
	if (Test-Path $err) { $text += "`n" + [IO.File]::ReadAllText($err) }
	$lines = $text -split "`r?`n"
	$bad = @($lines | Where-Object { $_ -match $fatal })
	$passes = @($lines | Where-Object { $_ -match 'QA PASS|PLAYTEST PASS' }).Count
	$code = if ($timedOut) { -1 } else { $p.ExitCode }
	$ok = (-not $timedOut) -and ($code -eq 0) -and ($bad.Count -eq 0)
	return [pscustomobject]@{
		Name = $name; Ok = $ok; TimedOut = $timedOut; Code = $code; Passes = $passes
		Secs = [math]::Round($sw.Elapsed.TotalSeconds, 1); Bad = $bad; Log = $out
	}
}

$results = @()
Write-Host "GNOSIS validate — $Path" -ForegroundColor Cyan
Write-Host "Godot: $Godot"
Write-Host "Logs:  $LogDir`n"

# (a) scripts: abrir o editor headless compila todos os scripts e reimporta.
if ($Only.Count -eq 0 -or $Only -contains "Scripts") {
	Write-Host "-> Scripts (editor headless)..." -NoNewline
	$r = Invoke-Step "Scripts" @("--headless", "--audio-driver", "Dummy", "--path", $Path, "--editor", "--quit")
	$results += $r
	Write-Host (" {0} ({1}s)" -f $(if ($r.Ok) { "ok" } else { "FALHOU" }), $r.Secs)
}

# (b) QAs headless
$todo = [ordered]@{}
foreach ($k in $fast.Keys) { $todo[$k] = $fast[$k] }
if ($Full) { foreach ($k in $slow.Keys) { $todo[$k] = $slow[$k] } }
if ($Only.Count -gt 0) { foreach ($k in $slow.Keys) { if ($Only -contains $k) { $todo[$k] = $slow[$k] } } }
foreach ($name in $todo.Keys) {
	if ($Only.Count -gt 0 -and -not ($Only -contains $name)) { continue }
	if ($Skip -contains $name) { continue }
	$scene = $todo[$name]
	$file = Join-Path $Path ($scene -replace '^res://', '')
	if (-not (Test-Path $file)) {
		Write-Host "-> $name ... ausente (pulado)" -ForegroundColor DarkYellow
		continue
	}
	Write-Host "-> $name..." -NoNewline
	$stepArgs = @("--headless", "--audio-driver", "Dummy", "--path", $Path)
	# A TecnicoQA troca de cena e conta tempo em quadros (como as regressões).
	if ($name -eq "TecnicoQA") { $stepArgs += @("--fixed-fps", "60") }
	$r = Invoke-Step $name ($stepArgs + @($scene, "--quit-after", "20000"))
	$results += $r
	Write-Host (" {0} ({1}s, {2} PASS)" -f $(if ($r.Ok) { "ok" } elseif ($r.TimedOut) { "TEMPO ESGOTADO" } else { "FALHOU" }), $r.Secs, $r.Passes)
}

# (c) resumo
Write-Host ""
Write-Host "==================== RESUMO ====================" -ForegroundColor Cyan
$fails = 0
foreach ($r in $results) {
	if ($r.Ok) {
		Write-Host ("  VERDE     {0,-14} {1,5}s  {2,3} PASS" -f $r.Name, $r.Secs, $r.Passes) -ForegroundColor Green
	} else {
		$fails++
		$why = if ($r.TimedOut) { "tempo esgotado (${Timeout}s)" } else { "exit=$($r.Code)" }
		Write-Host ("  VERMELHO  {0,-14} {1,5}s  {2}" -f $r.Name, $r.Secs, $why) -ForegroundColor Red
		$r.Bad | Select-Object -First 6 | ForEach-Object { Write-Host "            $_" -ForegroundColor Red }
		Write-Host "            log: $($r.Log)" -ForegroundColor DarkGray
	}
}
Write-Host "================================================" -ForegroundColor Cyan
if ($fails -eq 0) {
	Write-Host ("TUDO VERDE ({0} etapas)" -f $results.Count) -ForegroundColor Green
	exit 0
}
Write-Host ("VERMELHO: {0} de {1} etapas falharam" -f $fails, $results.Count) -ForegroundColor Red
exit 1
