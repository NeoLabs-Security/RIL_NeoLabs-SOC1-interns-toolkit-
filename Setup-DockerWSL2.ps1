param(
    [switch]$ValidateOnly,
    [switch]$SkipInstall,
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "[NeoLabs] $Message" -ForegroundColor Cyan
}

function Find-DockerDesktopExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Docker\Docker\Docker Desktop.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Test-WindowsDocker {
    $docker = Get-Command docker.exe -ErrorAction SilentlyContinue
    if (-not $docker) { return $false }
    & docker.exe info *> $null
    return ($LASTEXITCODE -eq 0)
}

function Test-WslDocker {
    & wsl.exe bash -lc 'docker info >/dev/null 2>&1' *> $null
    return ($LASTEXITCODE -eq 0)
}

function Wait-Docker([int]$TimeoutSeconds = 180) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-WindowsDocker) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

if ($ValidateOnly) {
    Write-Host '[OK] Docker/WSL2 bootstrap contract is valid.'
    Write-Host '[OK] The helper checks WSL2, can install Docker Desktop through winget, starts Docker Desktop, waits for the engine, and verifies Docker access from WSL2.'
    exit 0
}

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ' NeoLabs Docker Desktop + WSL2 Setup' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Step 'WSL is not installed. Enabling WSL without forcing a Linux distribution...'
    try {
        & wsl.exe --install --no-distribution
    } catch {
        throw 'Windows could not enable WSL automatically. Run this helper from a supported Windows 10/11 workstation with permission to enable WSL.'
    }
    throw 'WSL was enabled, but Windows may require a restart. Restart Windows, install/launch a current WSL distribution once, then run SETUP-DOCKER-WSL2.cmd again.'
}

Write-Step 'Updating/checking WSL and setting WSL2 as the default...'
& wsl.exe --update *> $null
& wsl.exe --set-default-version 2 *> $null
if ($LASTEXITCODE -ne 0) { throw 'Could not set WSL2 as the default WSL version.' }

$wslList = (& wsl.exe -l -v 2>$null | Out-String)
if (-not $wslList -or $wslList -notmatch '\b2\s*$' -and $wslList -notmatch '\b2\r?\n') {
    Write-Host '[INFO] No ready WSL2 distribution was detected.' -ForegroundColor Yellow
    Write-Host 'Install or convert a current WSL distribution (Kali, Ubuntu, Debian, etc.) to WSL2, launch it once to complete Linux user setup, then rerun this helper.' -ForegroundColor Yellow
    exit 2
}
Write-Host '[OK] A WSL2 distribution is available.' -ForegroundColor Green

$desktopExe = Find-DockerDesktopExe
if (-not $desktopExe) {
    if ($SkipInstall) { throw 'Docker Desktop is not installed and -SkipInstall was supplied.' }
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw 'Docker Desktop is not installed and Windows Package Manager (winget) is unavailable. Install Docker Desktop for Windows, then rerun this helper.'
    }

    Write-Step 'Docker Desktop is missing. Installing the official Docker Desktop package with winget...'
    & winget.exe install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop installation through winget failed.' }
    $desktopExe = Find-DockerDesktopExe
    if (-not $desktopExe) { throw 'Docker Desktop installation completed but the launcher executable could not be located.' }
}
Write-Host "[OK] Docker Desktop installed: $desktopExe" -ForegroundColor Green

if (-not $NoStart) {
    if (-not (Test-WindowsDocker)) {
        Write-Step 'Starting Docker Desktop...'
        Start-Process -FilePath $desktopExe | Out-Null
    }

    Write-Step 'Waiting for the Docker engine to become ready...'
    if (-not (Wait-Docker -TimeoutSeconds 240)) {
        throw 'Docker Desktop started but the Docker engine did not become ready within four minutes. Open Docker Desktop once, complete any first-run/terms prompt, then rerun this helper.'
    }
    Write-Host '[OK] Docker Desktop engine is running.' -ForegroundColor Green
}

if ($NoStart) {
    Write-Host '[INFO] Docker startup/engine verification skipped because -NoStart was supplied.' -ForegroundColor Yellow
    exit 0
}

Write-Step 'Verifying Docker Desktop is reachable from the default WSL2 distribution...'
if (-not (Test-WslDocker)) {
    Write-Host '[ACTION REQUIRED] Docker Desktop is running, but Docker is not available inside the default WSL2 distribution.' -ForegroundColor Yellow
    Write-Host 'Open Docker Desktop > Settings > Resources > WSL Integration, enable integration for the WSL2 distribution used by NeoLabs, then Apply/Restart and rerun this helper.' -ForegroundColor Yellow
    Write-Host 'NeoLabs does not edit Docker Desktop private settings files because those formats are not a stable public automation contract.' -ForegroundColor DarkYellow
    exit 3
}

Write-Host '[OK] Docker is available from WSL2.' -ForegroundColor Green
Write-Host ''
Write-Host 'DOCKER + WSL2 READY' -ForegroundColor Green
Write-Host 'You can now double-click START-NEOLABS-SOC.cmd.' -ForegroundColor Green
exit 0
