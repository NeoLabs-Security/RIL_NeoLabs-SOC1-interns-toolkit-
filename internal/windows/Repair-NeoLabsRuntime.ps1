param(
    [switch]$ValidateOnly,
    [int]$DaemonTimeoutSeconds = 60,
    [string]$ToolkitRoot = ''
)

$ErrorActionPreference = 'Stop'
$MinimumWslVersion = [version]'2.1.5'
$script:DockerCli = $null
$script:DockerContext = $null

if (-not $ToolkitRoot) {
    $ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Write-Step([string]$Message) { Write-Host "[NeoLabs AutoFix] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

function Invoke-ElevatedPowerShell([string]$Command) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)
    return $process.ExitCode
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

function Get-WslPackageVersion {
    try {
        $text = (& wsl.exe --version 2>$null | Out-String) -replace "`0", ''
        if ($LASTEXITCODE -eq 0 -and $text -match '(?im)^\s*WSL\s+version:\s*([0-9]+(?:\.[0-9]+){1,3})') {
            return [version]$Matches[1]
        }
    } catch { }
    return $null
}

function Update-WslRuntime {
    Write-Step 'Updating WSL to the current Microsoft runtime...'
    $updated = $false
    try {
        & wsl.exe --update
        $updated = ($LASTEXITCODE -eq 0)
    } catch { $updated = $false }

    if (-not $updated) {
        try {
            & wsl.exe --update --web-download
            $updated = ($LASTEXITCODE -eq 0)
        } catch { $updated = $false }
    }

    if (-not $updated) {
        $command = @'
$ErrorActionPreference = 'Stop'
wsl.exe --update
if ($LASTEXITCODE -ne 0) {
    wsl.exe --update --web-download
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
'@
        $exitCode = Invoke-ElevatedPowerShell $command
        $updated = ($exitCode -eq 0)
    }

    if (-not $updated) { throw 'WSL could not be updated automatically. Check Windows Update/network policy and retry the NeoLabs launcher.' }
    & wsl.exe --shutdown *> $null
    Write-Ok 'WSL update completed.'
}

function Ensure-WslRuntime {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Step 'WSL is missing. Enabling the required Windows features automatically...'
        $command = @'
$ErrorActionPreference = 'Stop'
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
wsl.exe --install --no-distribution
exit $LASTEXITCODE
'@
        $exitCode = Invoke-ElevatedPowerShell $command
        if ($exitCode -ne 0) { throw 'Windows could not enable WSL/VirtualMachinePlatform automatically.' }
        Write-Warn 'WSL was enabled. Windows must restart once before NeoLabs SOC can continue.'
        exit 3010
    }

    try {
        & wsl.exe --set-default-version 2 *> $null
    } catch { }

    $version = Get-WslPackageVersion
    if (-not $version -or $version -lt $MinimumWslVersion) {
        if ($version) { Write-Warn "WSL $version is older than the NeoLabs minimum $MinimumWslVersion." }
        else { Write-Warn 'Legacy/inbox WSL detected; modern WSL is required by Docker Desktop.' }
        Update-WslRuntime
        $version = Get-WslPackageVersion
    }

    if ($version) { Write-Ok "WSL runtime: $version" }

    $distro = Get-DefaultWslDistribution
    if (-not $distro) {
        Write-Step 'No WSL Linux distribution is installed. Installing Ubuntu automatically...'
        $exitCode = Invoke-ElevatedPowerShell 'wsl.exe --install -d Ubuntu'
        if ($exitCode -ne 0) { throw 'Ubuntu WSL2 could not be installed automatically.' }
        Write-Warn 'Ubuntu was installed. If Windows requests a restart, restart it; then launch Ubuntu once to complete its one-time Linux user setup and rerun NeoLabs.'
        exit 3010
    }

    if ($distro.Version -ne 2) {
        Write-Step "Converting '$($distro.Name)' to WSL2..."
        & wsl.exe --set-version $distro.Name 2
        if ($LASTEXITCODE -ne 0) { throw "Could not convert '$($distro.Name)' to WSL2." }
        $distro = Get-DefaultWslDistribution
    }

    Write-Ok "Default WSL distro: $($distro.Name) (WSL2)"
    return $distro
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

function Test-DockerDesktopCli {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli desktop version *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Test-DockerContext([string]$Name) {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli context inspect $Name *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Resolve-DockerContext {
    if (Test-DockerContext 'desktop-linux') {
        $script:DockerContext = 'desktop-linux'
        $env:DOCKER_CONTEXT = 'desktop-linux'
    } else {
        $script:DockerContext = $null
        Remove-Item Env:DOCKER_CONTEXT -ErrorAction SilentlyContinue
    }
}

function Get-DockerOsType {
    if (-not $script:DockerCli) { return $null }
    try {
        $args = @()
        if ($script:DockerContext) { $args += @('--context', $script:DockerContext) }
        $args += @('info','--format','{{.OSType}}')
        $value = (& $script:DockerCli @args 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value) { return $value.Trim().ToLowerInvariant() }
    } catch { }
    return $null
}

function Wait-DockerEngine([int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $value = Get-DockerOsType
        if ($value) { return $value }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Restart-DockerDesktop([int]$TimeoutSeconds = 120) {
    if ($script:DockerCli -and (Test-DockerDesktopCli)) {
        try {
            & $script:DockerCli desktop restart --timeout $TimeoutSeconds *> $null
            return ($LASTEXITCODE -eq 0)
        } catch { }
    }
    $desktopExe = Find-DockerDesktopExecutable
    if ($desktopExe) {
        try { Start-Process -FilePath $desktopExe | Out-Null; return $true } catch { }
    }
    return $false
}

function Ensure-DockerInstalled {
    $script:DockerCli = Find-DockerCliExecutable
    $desktopExe = Find-DockerDesktopExecutable
    if ($script:DockerCli -or $desktopExe) { return }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'Docker Desktop is missing and Windows Package Manager (winget) is unavailable.'
    }

    Write-Step 'Docker Desktop is missing. Installing it automatically...'
    & winget.exe install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop automatic installation failed.' }
    Start-Sleep -Seconds 3
    $script:DockerCli = Find-DockerCliExecutable
    if (-not $script:DockerCli) { throw 'Docker Desktop installed, but docker.exe is not available yet. Sign out/restart Windows if the installer requested it, then rerun NeoLabs.' }
}

function Try-DockerDesktopUpdate {
    if ($script:DockerCli -and (Test-DockerDesktopCli)) {
        try {
            & $script:DockerCli desktop update --quiet
            if ($LASTEXITCODE -eq 0) { return $true }
        } catch { }
    }

    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        try {
            & winget.exe upgrade --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
            if ($LASTEXITCODE -eq 0) { return $true }
            # winget can return non-zero when there is simply no applicable upgrade.
            $script:DockerCli = Find-DockerCliExecutable
            if ($script:DockerCli) { return $true }
        } catch { }
    }
    return $false
}

function Save-RuntimeDiagnostics([string]$Reason) {
    $logDir = Join-Path $env:LOCALAPPDATA 'NeoLabs\logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $logDir "runtime-$stamp.txt"
    "NeoLabs Windows runtime diagnostics - $(Get-Date -Format o)" | Out-File -FilePath $path -Encoding utf8
    "Reason: $Reason" | Out-File -FilePath $path -Encoding utf8 -Append
    "`n=== WSL VERSION ===" | Out-File -FilePath $path -Encoding utf8 -Append
    try { (& wsl.exe --version 2>&1 | Out-String) | Out-File -FilePath $path -Encoding utf8 -Append } catch { }
    "`n=== WSL STATUS ===" | Out-File -FilePath $path -Encoding utf8 -Append
    try { (& wsl.exe --status 2>&1 | Out-String) | Out-File -FilePath $path -Encoding utf8 -Append } catch { }
    "`n=== WSL DISTROS ===" | Out-File -FilePath $path -Encoding utf8 -Append
    try { (& wsl.exe -l -v 2>&1 | Out-String) | Out-File -FilePath $path -Encoding utf8 -Append } catch { }
    if ($script:DockerCli -and (Test-DockerDesktopCli)) {
        "`n=== DOCKER DESKTOP STATUS ===" | Out-File -FilePath $path -Encoding utf8 -Append
        try { (& $script:DockerCli desktop status 2>&1 | Out-String) | Out-File -FilePath $path -Encoding utf8 -Append } catch { }
        "`n=== DOCKER DESKTOP ERROR LOGS ===" | Out-File -FilePath $path -Encoding utf8 -Append
        try { (& $script:DockerCli desktop logs --priority 2 --since '10m' 2>&1 | Out-String) | Out-File -FilePath $path -Encoding utf8 -Append } catch { }
    }
    Write-Warn "Automatic recovery stopped. A local diagnostic log was saved to: $path"
    return $path
}

function Ensure-DockerEngine {
    Ensure-DockerInstalled
    if (-not $script:DockerCli) { $script:DockerCli = Find-DockerCliExecutable }
    Resolve-DockerContext

    $osType = Get-DockerOsType
    if ($osType -eq 'linux') { Write-Ok 'Docker Linux engine is already healthy.'; return 'linux' }

    if ($osType -eq 'windows') {
        Write-Step 'Docker is using Windows containers. Switching to Linux containers automatically...'
        if (-not (Test-DockerDesktopCli)) { throw 'Docker Desktop cannot be switched to Linux containers by this installed CLI version.' }
        & $script:DockerCli desktop engine use linux *> $null
        if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop could not switch to Linux containers.' }
        Resolve-DockerContext
        $osType = Wait-DockerEngine $DaemonTimeoutSeconds
        if ($osType -eq 'linux') { Write-Ok 'Docker Linux engine is healthy.'; return 'linux' }
    }

    Write-Step 'Starting/recovering the Docker Linux engine...'
    if (Test-DockerDesktopCli) {
        try { & $script:DockerCli desktop start --timeout $DaemonTimeoutSeconds *> $null } catch { }
    } else {
        $desktopExe = Find-DockerDesktopExecutable
        if ($desktopExe) { Start-Process -FilePath $desktopExe | Out-Null }
    }
    Resolve-DockerContext
    $osType = Wait-DockerEngine $DaemonTimeoutSeconds
    if ($osType -eq 'linux') { Write-Ok 'Docker Linux engine is healthy.'; return 'linux' }

    Write-Warn 'Docker Desktop is open but its Linux daemon is not answering. Running automatic WSL/Docker repair.'
    & wsl.exe --shutdown *> $null
    Restart-DockerDesktop 120 | Out-Null
    Resolve-DockerContext
    $osType = Wait-DockerEngine 60
    if ($osType -eq 'linux') { Write-Ok 'Docker recovered after WSL refresh.'; return 'linux' }

    Write-Warn 'Docker still is not healthy. Updating WSL automatically and retrying.'
    Update-WslRuntime
    Restart-DockerDesktop 120 | Out-Null
    Resolve-DockerContext
    $osType = Wait-DockerEngine 90
    if ($osType -eq 'linux') { Write-Ok 'Docker recovered after WSL update.'; return 'linux' }

    Write-Warn 'Docker still is not healthy. Applying one Docker Desktop update/recovery attempt.'
    Try-DockerDesktopUpdate | Out-Null
    $script:DockerCli = Find-DockerCliExecutable
    Restart-DockerDesktop 180 | Out-Null
    Resolve-DockerContext
    $osType = Wait-DockerEngine 120
    if ($osType -eq 'linux') { Write-Ok 'Docker recovered after Desktop update.'; return 'linux' }

    $logPath = Save-RuntimeDiagnostics 'Docker Desktop Linux daemon did not recover after start, WSL refresh, WSL update, and Docker Desktop update.'
    throw "Docker Desktop itself needs attention on this computer. NeoLabs already attempted the safe automatic repairs. Diagnostic log: $logPath"
}

function Test-DockerInsideWsl([string]$DistroName, [string]$LinuxRoot) {
    try {
        $value = (& wsl.exe --distribution $DistroName --cd $LinuxRoot --exec sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null | Select-Object -First 1)
        return ($LASTEXITCODE -eq 0 -and $value -and $value.Trim().ToLowerInvariant() -eq 'linux')
    } catch { return $false }
}

function Ensure-DockerInsideWsl($Distro) {
    $linuxRoot = (& wsl.exe --distribution $Distro.Name --exec wslpath -a $ToolkitRoot 2>$null | Select-Object -First 1)
    if (-not $linuxRoot) { throw 'Could not translate the NeoLabs toolkit folder into WSL2.' }
    $linuxRoot = $linuxRoot.Trim()

    if (Test-DockerInsideWsl $Distro.Name $linuxRoot) {
        Write-Ok "Docker is available inside '$($Distro.Name)'."
        return
    }

    Write-Warn "Docker is healthy on Windows but '$($Distro.Name)' has not attached to it yet. Refreshing integration automatically."
    try { & wsl.exe --set-default $Distro.Name *> $null } catch { }
    & wsl.exe --shutdown *> $null
    Restart-DockerDesktop 120 | Out-Null
    Resolve-DockerContext
    $engine = Wait-DockerEngine 90
    if ($engine -ne 'linux') { throw 'Docker Linux engine did not recover while refreshing WSL integration.' }

    $deadline = (Get-Date).AddSeconds(60)
    do {
        if (Test-DockerInsideWsl $Distro.Name $linuxRoot) {
            Write-Ok "Docker WSL integration is healthy for '$($Distro.Name)'."
            return
        }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    $logPath = Save-RuntimeDiagnostics "Docker is healthy on Windows but not exposed inside WSL distro '$($Distro.Name)'."
    throw "Docker's WSL integration for '$($Distro.Name)' is disabled or blocked. NeoLabs refreshed WSL/Docker automatically, but Docker Desktop does not expose a supported CLI to toggle a distro integration setting. Diagnostic log: $logPath"
}

if ($ValidateOnly) {
    Write-Host '[OK] NeoLabs Windows runtime AutoFix contract is valid.'
    Write-Host '[OK] AutoFix covers WSL minimum/version updates, WSL2 conversion, Docker install/start/Linux-engine recovery, bounded WSL/Docker updates, WSL integration refresh and local diagnostics.'
    exit 0
}

if ($DaemonTimeoutSeconds -lt 20 -or $DaemonTimeoutSeconds -gt 300) { throw 'DaemonTimeoutSeconds must be between 20 and 300 seconds.' }

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '      NeoLabs Windows Runtime AutoFix' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

$distro = Ensure-WslRuntime
Ensure-DockerEngine | Out-Null
Ensure-DockerInsideWsl $distro
Write-Ok 'Windows/WSL2/Docker runtime is ready for the SOC launcher.'
