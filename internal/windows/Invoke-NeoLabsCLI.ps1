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

# Local-file analysis has no WSL/Docker or session dependency. Keep Windows
# paths native and leave login/download/live commands on their existing runtime.
if ($CliArgs.Count -ge 2 -and $CliArgs[0] -eq 'offline' -and $CliArgs[1] -eq 'analyze') {
    foreach ($candidate in @('py', 'python', 'python3')) {
        if (-not (Get-Command $candidate -ErrorAction SilentlyContinue)) { continue }
        $prefix = @()
        if ($candidate -eq 'py') { $prefix = @('-3') }
        & $candidate @prefix -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        # Direct script entry preserves the caller's working directory, so
        # relative evidence paths work even when invoked outside the toolkit.
        & $candidate @prefix (Join-Path $Root 'tools\cli.py') @CliArgs
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 1 }
        exit $code
    }
    Fail 'Local analysis requires native Windows Python 3.10+. Install Python, then retry. WSL and Docker are not needed.'
}

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Fail 'WSL2 is not available yet. Run .\START-NEOLABS-SOC.cmd first so the supported Windows runtime can be prepared.'
}

$linuxRoot = (& wsl.exe --exec wslpath -a $Root 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or -not $linuxRoot) {
    Fail 'Could not translate the toolkit path into WSL2. Run .\START-NEOLABS-SOC.cmd once to repair/prepare the supported runtime.'
}
$linuxRoot = $linuxRoot.Trim()

# Import runs in the existing WSL Wazuh runtime, but accepts native Windows
# file paths. Resolve relative paths from the caller before crossing into WSL.
if ($CliArgs.Count -ge 2 -and $CliArgs[0] -eq 'offline' -and $CliArgs[1] -eq 'import') {
    for ($i = 2; $i -lt $CliArgs.Count; $i++) {
        if ($CliArgs[$i] -eq '--file' -and $i + 1 -lt $CliArgs.Count) {
            $sourcePath = (Resolve-Path -LiteralPath $CliArgs[$i + 1]).Path
            $translated = & wsl.exe --exec wslpath -a $sourcePath
            if ($LASTEXITCODE -ne 0 -or -not $translated) { Fail 'Could not translate telemetry file path into WSL.' }
            $CliArgs[$i + 1] = $translated.Trim()
        }
    }
}

# `neolabs.cmd connect` can start/reuse Wazuh directly through the Python CLI.
# Export the Windows workstation profile into WSL so dashboard exposure and
# preflight use the same policy as START-NEOLABS-SOC.cmd.
& wsl.exe --cd $linuxRoot env NEOLABS_HOST_MODE=windows python3 -m tools.cli @CliArgs
$exitCode = $LASTEXITCODE
if ($null -eq $exitCode) { $exitCode = 1 }
exit $exitCode
