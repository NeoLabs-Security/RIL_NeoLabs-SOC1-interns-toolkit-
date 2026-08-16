[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true, Position = 0)]
    [string[]]$CliArgs
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Fail([string]$Message, [int]$Code = 2) {
    Write-Host "[FAILED] $Message" -ForegroundColor Red
    exit $Code
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Fail 'WSL2 is not available yet. Run .\START-NEOLABS-SOC.cmd first so the supported Windows runtime can be prepared.'
}

$linuxRoot = (& wsl.exe --exec wslpath -a $Root 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or -not $linuxRoot) {
    Fail 'Could not translate the toolkit path into WSL2. Run .\START-NEOLABS-SOC.cmd once to repair/prepare the supported runtime.'
}
$linuxRoot = $linuxRoot.Trim()

& wsl.exe --cd $linuxRoot python3 -m tools.cli @CliArgs
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = 1 }
exit $exitCode
