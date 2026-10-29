<#
.SYNOPSIS
  GNOSIS - integracao em LOTE por script: merge de varios branches, reimport 2x,
  tools\validate.ps1 e UM veredito curto (VERDE / VERMELHO + linhas de erro).

.DESCRIPTION
  Para cada item "branch commit" (nesta ordem):
    git merge --no-ff -m "Merge <branch> <sha> into integracao/onda1" <sha>
  Se der conflito SO em arquivos de i18n gerados (assets/i18n/strings.csv, _orfas.csv,
  _descartadas.txt, _relatorio.txt, godot/*), fica com o "nosso" lado, conclui o merge e, ao
  fim do lote, regenera tudo pelo tools/i18n (normaliza LF -> extract.py -> build.py --strict)
  e commita "i18n regenerado". Qualquer outro conflito: aborta o merge, imprime VERMELHO.
  Depois: reimport headless 2x, validate.ps1 -Repeat N e o veredito.

  Silencio: Godot sempre --headless --audio-driver Dummy (nenhuma janela); o processo roda
  em BelowNormal (os filhos herdam). Log completo em C:\gnosis-wt\_caps\integ\integrar_*.log.

.PARAMETER Itens     Lista de "branch commit" (ex.: "dir7/vfx7 a63c40b" "dir6/chefes6 b0b52f0").
.PARAMETER Path      Worktree de integracao (padrao: a pasta pai de tools/).
.PARAMETER Repeat    -Repeat do validate.ps1 (padrao 1).
.PARAMETER Push      Se VERDE, faz push de HEAD para origin integracao/onda1.
.PARAMETER SemValidar Pula reimport+validate (so merges + i18n).
.PARAMETER Branch    Branch de destino do push (padrao integracao/onda1).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\integrar.ps1 "dir7/vfx7 a63c40b" "dir6/chefes6 b0b52f0" -Repeat 2
#>
[CmdletBinding(PositionalBinding = $false)]
param(
	[Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Itens = @(),
	[string]$Path = "",
	[int]$Repeat = 1,
	[switch]$Push,
	[switch]$SemValidar,
	[string]$Branch = "integracao/onda1",
	[string]$Godot = ""
)

$ErrorActionPreference = "Continue"
try { (Get-Process -Id $PID).PriorityClass = 'BelowNormal' } catch {}
if ($Path -eq "") { $Path = Split-Path -Parent $PSScriptRoot }
$Path = (Resolve-Path $Path).Path
if ($Godot -eq "") {
	$Godot = "C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
}
$logDir = "C:\gnosis-wt\_caps\integ"
New-Item -ItemType Directory -Force $logDir | Out-Null
$logFile = Join-Path $logDir ("integrar_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Log([string]$s) { Add-Content -Path $logFile -Value $s -Encoding UTF8 }
function Falha([string[]]$linhas) {
	Write-Host "VERMELHO"
	foreach ($l in $linhas) { Write-Host $l; Log $l }
	Write-Host "log: $logFile"
	exit 1
}
# git sempre no worktree; devolve as linhas e deixa o codigo em $script:gcode
function G {
	$o = & git -C $Path @args 2>&1 | ForEach-Object { "$_" }
	$script:gcode = $LASTEXITCODE
	foreach ($l in $o) { Log ("git " + ($args -join ' ') + " :: " + $l) }
	return $o
}

# Arquivos de i18n gerados: conflito so neles se resolve regenerando.
$i18nRx = '^assets/i18n/(strings\.csv|_orfas\.csv|_descartadas\.txt|_relatorio\.txt|godot/.+)$'

if ($Itens.Count -eq 0 -and -not $SemValidar) { Falha @("uso: integrar.ps1 `"branch commit`" ... [-Repeat N] [-Push]") }

# 1) worktree limpo? (so ruido de .import/.uid pode ser descartado)
$sujo = @(G status --porcelain --untracked-files=no)
$naoRuido = @($sujo | Where-Object { $_ -notmatch '\.(import|uid)"?$' })
if ($naoRuido.Count -gt 0) { Falha (@("worktree sujo (alem de .import):") + ($naoRuido | Select-Object -First 8)) }
if ($sujo.Count -gt 0) { $null = G checkout -- . }

$base = @(G rev-parse --short HEAD)[0]
Log "base inicial: $base"
$precisaI18n = $false

# 2) merges em ordem
foreach ($it in $Itens) {
	$p = $it.Trim() -split '\s+'
	if ($p.Count -lt 2) { Falha @("item invalido: '$it' (use `"branch commit`")") }
	$br = $p[0]; $sha = $p[1]
	$null = G cat-file -e "$sha^{commit}"
	if ($gcode -ne 0) { $null = G fetch origin --quiet; $null = G cat-file -e "$sha^{commit}" }
	if ($gcode -ne 0) { Falha @("commit $sha nao existe (branch $br)") }
	$msg = "Merge $br $sha into $Branch"
	$o = G merge --no-ff -m $msg $sha
	if ($gcode -ne 0) {
		$conf = @(G diff --name-only --diff-filter=U)
		$outros = @($conf | Where-Object { $_ -notmatch $i18nRx })
		if ($conf.Count -gt 0 -and $outros.Count -eq 0) {
			foreach ($f in $conf) { $null = G checkout --ours -- $f; $null = G add -- $f }
			$null = G commit --no-edit
			if ($gcode -ne 0) { $null = G merge --abort; Falha @("merge $br $sha : nao consegui concluir apos resolver i18n") }
			$precisaI18n = $true
			Log "conflito so de i18n em $br $sha : resolvido com --ours"
		} else {
			$lista = if ($conf.Count -gt 0) { $outros } else { @($o | Select-Object -Last 4) }
			$null = G merge --abort
			Falha (@("merge $br $sha : CONFLITO (base do lote: $base)") + ($lista | Select-Object -First 12 | ForEach-Object { "  conflito: $_" }))
		}
	}
}

# 3) i18n regenerado (so se algum conflito de i18n foi resolvido)
if ($precisaI18n) {
	foreach ($f in @("assets/i18n/strings.csv", "assets/i18n/_orfas.csv", "assets/i18n/godot/gnosis_text.csv")) {
		$full = Join-Path $Path $f
		if (Test-Path $full) {
			$b = [IO.File]::ReadAllBytes($full)
			$ms = New-Object IO.MemoryStream
			for ($i = 0; $i -lt $b.Length; $i++) {
				if ($b[$i] -eq 13 -and ($i + 1) -lt $b.Length -and $b[$i + 1] -eq 10) { continue }   # CRLF -> LF
				$ms.WriteByte($b[$i])
			}
			[IO.File]::WriteAllBytes($full, $ms.ToArray())
		}
	}
	Push-Location $Path
	$env:PYTHONIOENCODING = "utf-8"
	$o1 = & python tools/i18n/extract.py 2>&1 | ForEach-Object { "$_" }
	$c1 = $LASTEXITCODE
	$o2 = & python tools/i18n/build.py --strict 2>&1 | ForEach-Object { "$_" }
	$c2 = $LASTEXITCODE
	Pop-Location
	($o1 + $o2) | ForEach-Object { Log "i18n :: $_" }
	if ($c1 -ne 0 -or $c2 -ne 0) {
		Falha (@("i18n: extract/build --strict falhou (extract=$c1 build=$c2)") + (($o1 + $o2) | Select-Object -Last 8))
	}
	$null = G add -- assets/i18n
	$null = G commit -m "i18n regenerado apos o lote (extract + build --strict)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
}

# 4) reimport 2x + validate
if (-not $SemValidar) {
	for ($i = 1; $i -le 2; $i++) {
		$o = Join-Path $logDir "reimport$i.out.log"
		$p = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--audio-driver", "Dummy", "--path", "`"$Path`"", "--editor", "--quit") `
			-NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError ($o + ".err")
		$null = $p.Handle
		if (-not $p.WaitForExit(600000)) { try { Stop-Process -Id $p.Id -Force } catch {} }
		Log "reimport $i exit=$($p.ExitCode)"
	}
	$vlog = Join-Path $logDir "validate_ultimo"
	$saida = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Path "tools\validate.ps1") -Path $Path -Repeat $Repeat -LogDir $vlog 2>&1 | ForEach-Object { "$_" }
	$vcode = $LASTEXITCODE
	$saida | ForEach-Object { Log "validate :: $_" }
	if ($vcode -ne 0) {
		$ruins = @($saida | Where-Object { $_ -match 'VERMELHO|^\s{8,}\S|log:' -and $_ -notmatch '^=+$' })
		Falha (@("validate -Repeat $Repeat falhou (base do lote: $base)") + ($ruins | Select-Object -First 25))
	}
}

# 5) push (so VERDE)
if ($Push) {
	$null = G push origin "HEAD:$Branch"
	if ($gcode -ne 0) { Falha @("push falhou") }
}
$head = @(G rev-parse --short HEAD)[0]
Write-Host "VERDE $head"
Log "VERDE $head"
exit 0
