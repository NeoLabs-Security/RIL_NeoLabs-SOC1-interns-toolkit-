param(
    [switch]$ValidateOnly,
    [int]$TimeoutSeconds = 180,
    [string]$ToolkitRoot = ''
)

$ErrorActionPreference = 'Stop'
$script:DockerCli = $null

if (-not $ToolkitRoot) {
    $ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Write-Step([string]$Message) {
    Write-Host "[NeoLabs Docker] $Message" -ForegroundColor Cyan
}

function Find-DockerDesktopExecutable {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\Docker Desktop.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Docker\Docker\Docker Desktop.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Find-DockerCliExecutable {
    $command = Get-Command docker.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source) { return $command.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Docker\Docker\resources\bin\docker.exe'),
        (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe')
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $candidate }
    }
    return $null
}

function Get-DefaultWslDistribution {
    $raw = (& wsl.exe -l -v 2>$null | Out-String) -replace "`0", ''
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '^\s*\*\s+(.+?)\s+(Running|Stopped)\s+([12])\s*$') {
            return [pscustomobject]@{ Name = $Matches[1].Trim(); Version = [int]$Matches[3] }
        }
    }
    return $null
}

function Invoke-ElevatedPowerShell([string]$Command) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    return $process.ExitCode
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

function Install-DockerDesktopWithWinget {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { return $false }
    Write-Step 'Docker Desktop is missing. Installing the official Docker Desktop package with Windows Package Manager...'
    & winget.exe install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { return $false }
    Start-Sleep -Seconds 3
    return $true
}

if ($ValidateOnly) {
    Write-Host '[OK] Internal Windows Docker/WSL2 bootstrap contract is valid.'
    exit 0
}

if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 900) { throw 'TimeoutSeconds must be between 30 and 900 seconds.' }

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '      NeoLabs Windows Runtime Bootstrap' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Step 'WSL is not enabled. Requesting the Windows WSL feature installation...'
    $exitCode = Invoke-ElevatedPowerShell 'wsl.exe --install --no-distribution'
    if ($exitCode -ne 0) { throw 'Windows could not enable WSL automatically. Run `wsl --install` once from an Administrator PowerShell.' }
    throw 'WSL installation was started. Restart Windows if requested, then run START-NEOLABS-SOC.cmd again.'
}

Write-Step 'Checking WSL2...'
& wsl.exe --set-default-version 2 *> $null
if ($LASTEXITCODE -ne 0) { throw 'Windows could not set WSL2 as the default. Run `wsl --update`, restart if requested, and retry.' }

$defaultDistro = Get-DefaultWslDistribution
if (-not $defaultDistro) {
    Write-Step 'No Linux distribution is installed. Requesting an Ubuntu WSL2 installation...'
    $exitCode = Invoke-ElevatedPowerShell 'wsl.exe --install -d Ubuntu'
    if ($exitCode -ne 0) { throw 'Windows could not install a WSL2 Linux distribution automatically. Install any current WSL2 distro and retry.' }
    throw 'The WSL2 Linux distribution installation was started. Restart Windows if requested and launch the new Linux distro once to create its Linux user, then rerun START-NEOLABS-SOC.cmd.'
}
if ($defaultDistro.Version -ne 2) {
    Write-Step "Converting '$($defaultDistro.Name)' to WSL2..."
    & wsl.exe --set-version $defaultDistro.Name 2
    if ($LASTEXITCODE -ne 0) { throw "Could not convert '$($defaultDistro.Name)' to WSL2. Run the conversion once from an Administrator PowerShell." }
    $defaultDistro = Get-DefaultWslDistribution
    if (-not $defaultDistro -or $defaultDistro.Version -ne 2) { throw 'The default Linux distribution is not running as WSL2 yet. Restart Windows if requested and retry.' }
}
Write-Host "[OK] Default WSL distro: $($defaultDistro.Name) (WSL2)" -ForegroundColor Green

$linuxRoot = (& wsl.exe wslpath -a $ToolkitRoot 2>$null | Select-Object -First 1)
if (-not $linuxRoot) { throw 'The SOC toolkit folder cannot be translated into WSL2. Move/clone it to a location visible to WSL2 and retry.' }
$linuxRoot = $linuxRoot.Trim()

$script:DockerCli = Find-DockerCliExecutable
$desktopExe = Find-DockerDesktopExecutable
if (-not $script:DockerCli -and -not $desktopExe) {
    $installed = Install-DockerDesktopWithWinget
    if (-not $installed) {
        try { Start-Process 'https://docs.docker.com/desktop/setup/install/windows-install/' } catch { }
        throw 'Docker Desktop is missing and automatic winget installation was unavailable or failed. The official install page has been opened.'
    }
    $script:DockerCli = Find-DockerCliExecutable
    $desktopExe = Find-DockerDesktopExecutable
    if (-not $script:DockerCli -and -not $desktopExe) { throw 'Docker Desktop installed but Windows has not exposed it yet. Restart/sign out if the installer requested it, then rerun START-NEOLABS-SOC.cmd.' }
    Write-Host '[OK] Docker Desktop installed.' -ForegroundColor Green
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
        if (-not $desktopExe) { throw 'Docker Desktop is installed but its executable could not be located.' }
        Start-Process -FilePath $desktopExe | Out-Null
    }
}
if (-not $script:DockerCli) { $script:DockerCli = Find-DockerCliExecutable }
if (-not $script:DockerCli) { throw 'Docker Desktop started, but docker.exe could not be found.' }

Write-Step "Waiting up to $TimeoutSeconds seconds for the Docker Linux engine..."
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Seconds 3
    $osType = Get-DockerOsType
    if ($osType) { break }
} while ((Get-Date) -lt $deadline)
if (-not $osType) { throw 'Docker Desktop did not become ready before the timeout. Resolve any first-run/licence/update/virtualisation prompt and retry.' }

if ($osType -eq 'windows') {
    Write-Step 'Switching Docker Desktop to Linux containers...'
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
if ($osType -ne 'linux') { throw 'NeoLabs SOC requires Docker Desktop Linux containers on the WSL2 backend.' }
Write-Host '[OK] Docker Desktop Linux engine is running.' -ForegroundColor Green

Write-Step "Verifying Docker access inside WSL2 distro '$($defaultDistro.Name)'..."
$wslDocker = (& wsl.exe --cd $linuxRoot sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or -not $wslDocker -or $wslDocker.Trim().ToLowerInvariant() -ne 'linux') {
    throw "Docker Desktop is running, but Docker is not available inside '$($defaultDistro.Name)'. In Docker Desktop > Settings > Resources > WSL Integration, enable that distro, Apply, then retry."
}
Write-Host '[OK] Docker is reachable from the WSL2 environment used by NeoLabs.' -ForegroundColor Green
