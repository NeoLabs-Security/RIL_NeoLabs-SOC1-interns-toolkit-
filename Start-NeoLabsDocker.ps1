param(
    [switch]$ValidateOnly,
    [int]$TimeoutSeconds = 180,
    [string]$ToolkitRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$script:DockerCli = $null

function Write-Step([string]$Message) {
    Write-Host "[NeoLabs Docker] $Message" -ForegroundColor Cyan
}

function Find-DockerDesktopExecutable {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Find-DockerCliExecutable {
    $command = Get-Command docker.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) { return $command.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Get-DefaultWslDistribution {
    $raw = (& wsl.exe -l -v 2>$null | Out-String) -replace "`0", ''
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '^\s*\*\s+(.+?)\s+(Running|Stopped)\s+([12])\s*$') {
            return [pscustomobject]@{
                Name = $Matches[1].Trim()
                Version = [int]$Matches[3]
            }
        }
    }
    return $null
}

function Get-DockerOsType {
    if (-not $script:DockerCli) { return $null }
    try {
        $value = (& $script:DockerCli info --format '{{.OSType}}' 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value) { return $value.Trim().ToLowerInvariant() }
    } catch { }
    return $null
}

function Test-DockerDesktopCli {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli desktop version *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

if ($ValidateOnly) {
    Write-Host '[OK] NeoLabs Docker/WSL2 bootstrap contract is valid.'
    Write-Host '[OK] It checks WSL2, starts Docker Desktop, requires Linux containers, waits for the daemon and verifies Docker inside the default WSL2 distro.'
    return
}

if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 900) {
    throw 'TimeoutSeconds must be between 30 and 900 seconds.'
}

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '   NeoLabs Docker Desktop / WSL2 Bootstrap' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    throw 'WSL is not enabled on this PC. Open an Administrator PowerShell once, run `wsl --install`, restart if Windows requests it, then run this shortcut again.'
}

Write-Step 'Checking WSL...'
try {
    & wsl.exe --status *> $null
} catch {
    throw 'WSL is installed but not healthy. Run `wsl --update` from an Administrator PowerShell, restart if requested, and retry.'
}

# This affects future distro installs only; it does not silently convert an existing WSL1 distro.
& wsl.exe --set-default-version 2 *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'Windows could not set WSL 2 as the default. Run `wsl --update` from an Administrator PowerShell and retry.'
}

$defaultDistro = Get-DefaultWslDistribution
if (-not $defaultDistro) {
    throw 'No default WSL Linux distribution is available. Install or select a current WSL2 distro (Kali, Ubuntu, Debian, etc.), then retry.'
}
if ($defaultDistro.Version -ne 2) {
    throw "The default WSL distribution '$($defaultDistro.Name)' is still WSL1. Convert it once with: wsl --set-version `"$($defaultDistro.Name)`" 2"
}
Write-Host "[OK] Default WSL distro: $($defaultDistro.Name) (WSL2)" -ForegroundColor Green

$linuxRoot = (& wsl.exe wslpath -a $ToolkitRoot 2>$null | Select-Object -First 1)
if (-not $linuxRoot) {
    throw 'The SOC toolkit folder cannot be translated into the default WSL2 distribution. Move/clone it to a location visible to WSL2 and retry.'
}
$linuxRoot = $linuxRoot.Trim()

$script:DockerCli = Find-DockerCliExecutable
$desktopExe = Find-DockerDesktopExecutable
if (-not $script:DockerCli -and -not $desktopExe) {
    try { Start-Process 'https://docs.docker.com/desktop/setup/install/windows-install/' } catch { }
    throw 'Docker Desktop is not installed. The official Docker Desktop for Windows installation page has been opened. Install Docker Desktop with the WSL 2 backend, then rerun START-NEOLABS-SOC.cmd.'
}

Write-Step 'Starting Docker Desktop if needed...'
$osType = Get-DockerOsType
if (-not $osType) {
    $startedWithCli = $false
    if ($script:DockerCli -and (Test-DockerDesktopCli)) {
        try {
            & $script:DockerCli desktop start --timeout $TimeoutSeconds *> $null
            $startedWithCli = ($LASTEXITCODE -eq 0)
        } catch { $startedWithCli = $false }
    }
    if (-not $startedWithCli) {
        if (-not $desktopExe) { $desktopExe = Find-DockerDesktopExecutable }
        if (-not $desktopExe) {
            throw 'Docker Desktop is installed but the launcher could not locate its executable. Start Docker Desktop manually once, then retry.'
        }
        Start-Process -FilePath $desktopExe | Out-Null
    }
}

# Re-resolve the CLI after Desktop starts in case installation PATH registration was not visible initially.
if (-not $script:DockerCli) { $script:DockerCli = Find-DockerCliExecutable }
if (-not $script:DockerCli) {
    throw 'Docker Desktop started, but the Docker CLI could not be found. Repair/reinstall Docker Desktop so its resources\bin\docker.exe is present, then retry.'
}

Write-Step "Waiting up to $TimeoutSeconds seconds for the Docker Linux engine..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Seconds 3
    $osType = Get-DockerOsType
    if ($osType) { break }
} while ((Get-Date) -lt $deadline)

if (-not $osType) {
    throw 'Docker Desktop did not become ready before the timeout. Open Docker Desktop once, resolve any licence/update/virtualisation prompt, then retry.'
}

if ($osType -eq 'windows') {
    Write-Step 'Docker is currently using Windows containers; attempting to switch to the Linux engine...'
    $switched = $false
    if (Test-DockerDesktopCli) {
        try {
            & $script:DockerCli desktop engine use linux *> $null
            $switched = ($LASTEXITCODE -eq 0)
        } catch { $switched = $false }
    }
    if ($switched) {
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        do {
            Start-Sleep -Seconds 3
            $osType = Get-DockerOsType
            if ($osType -eq 'linux') { break }
        } while ((Get-Date) -lt $deadline)
    }
}
if ($osType -ne 'linux') {
    throw 'NeoLabs SOC requires Docker Desktop Linux containers on the WSL2 backend. Switch Docker Desktop to Linux containers and retry.'
}
Write-Host '[OK] Docker Desktop Linux engine is running.' -ForegroundColor Green

Write-Step "Verifying Docker access inside WSL2 distro '$($defaultDistro.Name)'..."
$wslDocker = (& wsl.exe --cd $linuxRoot sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or -not $wslDocker -or $wslDocker.Trim().ToLowerInvariant() -ne 'linux') {
    throw "Docker Desktop is running, but Docker is not available inside the default WSL2 distro '$($defaultDistro.Name)'. In Docker Desktop open Settings > Resources > WSL Integration, enable '$($defaultDistro.Name)', select Apply, then retry."
}

Write-Host '[OK] Docker is reachable from the WSL2 environment used by the SOC toolkit.' -ForegroundColor Green
Write-Host ''
Write-Host 'NEOLABS DOCKER READY' -ForegroundColor Green
Write-Host 'You can now start the SOC workstation with START-NEOLABS-SOC.cmd.'
