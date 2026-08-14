$ErrorActionPreference = 'Stop'

$client = Join-Path $PSScriptRoot 'tools\neolabs.py'
if (-not (Test-Path $client)) { throw 'NeoLabs client file is missing from this toolkit.' }

# The SOC Wazuh stack is Linux-based. On Windows, prefer WSL2 for the entire
# CLI invocation so `neolabs connect` does not accidentally fall back to Git
# Bash/MSYS and so the same Bash/Docker environment is used for setup/startup.
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wsl) {
    try {
        $linuxRoot = (& wsl.exe wslpath -a $PSScriptRoot 2>$null | Select-Object -First 1).Trim()
        if ($linuxRoot) {
            $baseUrl = $env:NEOLABS_LAB_BASE_URL
            if (-not $baseUrl) { $baseUrl = 'https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com' }
            & wsl.exe --cd $linuxRoot env "NEOLABS_LAB_BASE_URL=$baseUrl" python3 tools/neolabs.py @args
            exit $LASTEXITCODE
        }
    } catch {
        Write-Warning 'WSL2 was detected but the toolkit could not be launched inside it.'
    }
}

# Login/status can still be useful on Windows without WSL2, but connect needs
# the Linux Wazuh runtime. Keep the fallback for diagnostics and clear errors.
if ($args.Count -gt 0 -and $args[0] -eq 'connect') {
    throw 'SOC `connect` requires WSL2. Install/enable any WSL2 Linux distro (Ubuntu, Kali, Debian, etc.) and Docker Desktop WSL integration, then run .\setup-windows.cmd once.'
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
