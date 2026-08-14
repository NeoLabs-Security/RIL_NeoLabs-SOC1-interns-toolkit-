$ErrorActionPreference = 'Stop'

$client = Join-Path $PSScriptRoot 'tools\cli.py'
if (-not (Test-Path $client)) { throw 'NeoLabs client file is missing from this toolkit.' }

# The SOC Wazuh stack is Linux-based. On Windows, prefer WSL2 for the entire
# CLI invocation so `neolabs connect` and `neolabs doctor` use the same
# Bash/Docker environment as setup/startup.
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wsl) {
    try {
        $linuxRoot = (& wsl.exe wslpath -a $PSScriptRoot 2>$null | Select-Object -First 1).Trim()
        if ($linuxRoot) {
            $baseUrl = $env:NEOLABS_LAB_BASE_URL
            if (-not $baseUrl) { $baseUrl = 'https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com' }
            & wsl.exe --cd $linuxRoot env "NEOLABS_LAB_BASE_URL=$baseUrl" python3 tools/cli.py @args
            exit $LASTEXITCODE
        }
    } catch {
        Write-Warning 'WSL2 was detected but the toolkit could not be launched inside it.'
    }
}

# Commands that inspect or control the local Wazuh runtime require WSL2.
if ($args.Count -gt 0 -and ($args[0] -eq 'connect' -or $args[0] -eq 'doctor')) {
    throw 'SOC `connect` and `doctor` require WSL2. Install/enable any WSL2 Linux distro (Ubuntu, Kali, Debian, etc.) and Docker Desktop WSL integration, then run .\setup-windows.cmd once.'
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3 $client @args
    exit $LASTEXITCODE
}
if (Get-Command python -ErrorAction SilentlyContinue) {
    & python $client @args
    exit $LASTEXITCODE
}
throw 'Python 3.10 or newer is required.'
