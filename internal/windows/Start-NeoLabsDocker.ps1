param(
    [switch]$ValidateOnly,
    [int]$TimeoutSeconds = 180,
    [string]$ToolkitRoot = ''
)

$ErrorActionPreference = 'Stop'
$script:DockerCli = $null
$script:DockerContext = $null

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

function Test-DockerDesktopCli {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli desktop version *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Test-DockerDesktopRunning {
    if (-not (Test-DockerDesktopCli)) { return $false }
    try {
        $status = (& $script:DockerCli desktop status 2>$null | Out-String)
        return ($LASTEXITCODE -eq 0 -and $status -match '(?im)\brunning\b')
    } catch { return $false }
}

function Test-DockerContext([string]$Name) {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli context inspect $Name *> $null
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

function Resolve-NeoLabsDockerContext {
    # Docker Desktop for Linux containers normally exposes the desktop-linux context.
    # Use it only for this launcher process so an intern's global Docker context is not changed.
    if (Test-DockerContext 'desktop-linux') {
        $script:DockerContext = 'desktop-linux'
        $env:DOCKER_CONTEXT = 'desktop-linux'
        Write-Host '[OK] Docker context: desktop-linux (NeoLabs process only).' -ForegroundColor Green
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
        $args += @('info', '--format', '{{.OSType}}')
        $value = (& $script:DockerCli @args 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value) { return $value.Trim().ToLowerInvariant() }
    } catch { }
    return $null
}

function Wait-DockerEngine([int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $osType = Get-DockerOsType
        if ($osType) { return $osType }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Get-WslDockerOsType([string]$DistroName, [string]$LinuxPath) {
    try {
        $value = (& wsl.exe --distribution $DistroName --cd $LinuxPath --exec sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value) { return $value.Trim().ToLowerInvariant() }
    } catch { }
    return $null
}

function Wait-WslDocker([string]$DistroName, [string]$LinuxPath, [int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        $osType = Get-WslDockerOsType $DistroName $LinuxPath
        if ($osType) { return $osType }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Install-DockerDesktopWithWinget {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { return $false }
    Write-Step 'Docker Desktop is missing. Installing the official Docker Desktop package with Windows Package Manager...'
    & winget.exe install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { return $false }
    Start-Sleep -Seconds 3
    return $true
}

function Get-NeoLabsWindowsPlatform {
    $os = $null
    $system = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { }
    try { $system = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { }

    $caption = if ($os) { [string]$os.Caption } else { '' }
    $productType = if ($os) { [int]$os.ProductType } else { 0 }
    $manufacturer = if ($system) { [string]$system.Manufacturer } else { '' }
    $model = if ($system) { [string]$system.Model } else { '' }
    $family = if ($system -and $system.PSObject.Properties.Name -contains 'SystemFamily') { [string]$system.SystemFamily } else { '' }
    $identity = "$manufacturer $model $family".ToLowerInvariant()

    $virtualPatterns = @(
        'virtual machine','vmware','virtualbox','qemu','kvm','xen','amazon ec2',
        'google compute engine','digitalocean','openstack','parallels','bhyve','bochs',
        'nutanix','hvm domu'
    )
    $isVirtual = $false
    foreach ($pattern in $virtualPatterns) {
        if ($identity.Contains($pattern)) { $isVirtual = $true; break }
    }

    return [pscustomobject]@{
        Caption = $caption
        ProductType = $productType
        Manufacturer = $manufacturer
        Model = $model
        IsWindowsServer = ($productType -ne 0 -and $productType -ne 1) -or ($caption -match 'Windows Server')
        IsVirtualMachine = $isVirtual
    }
}

function Stop-UnsupportedWindowsPlatform([string]$Reason, $Platform) {
    Write-Host ''
    Write-Host '==============================================' -ForegroundColor DarkRed
    Write-Host '      NEOLABS SOC PLATFORM CHECK FAILED' -ForegroundColor Red
    Write-Host '==============================================' -ForegroundColor DarkRed
    Write-Host ''
    Write-Host $Reason -ForegroundColor Yellow
    if ($Platform) {
        if ($Platform.Caption) { Write-Host "Detected OS: $($Platform.Caption)" }
        if ($Platform.Manufacturer -or $Platform.Model) { Write-Host "Detected system: $($Platform.Manufacturer) $($Platform.Model)" }
    }
    Write-Host ''
    Write-Host 'NeoLabs internship platform policy:' -ForegroundColor Cyan
    Write-Host '  - Physical Windows 10/11 workstation: use START-NEOLABS-SOC.cmd'
    Write-Host '  - VPS / remote server: use Ubuntu or Debian Linux and run start-neolabs-soc.sh'
    Write-Host '  - Windows Server VPS and Windows VM/VPS guests are not supported for the SOC workstation.'
    Write-Host ''
    exit 3
}

if ($ValidateOnly) {
    Write-Host '[OK] Internal Windows Docker/WSL2 bootstrap contract is valid.'
    Write-Host '[OK] Docker Desktop readiness uses the Desktop CLI plus daemon health, not UI status alone.'
    Write-Host '[OK] NeoLabs prefers desktop-linux without permanently changing the intern global Docker context.'
    exit 0
}

if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 900) { throw 'TimeoutSeconds must be between 30 and 900 seconds.' }

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '      NeoLabs Windows Runtime Bootstrap' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

Write-Step 'Checking whether this is a supported physical Windows workstation...'
$platform = Get-NeoLabsWindowsPlatform
if ($platform.IsWindowsServer) {
    Stop-UnsupportedWindowsPlatform 'Windows Server was detected. NeoLabs SOC VPS/server deployments must use Ubuntu/Debian Linux rather than Docker Desktop + WSL2 on Windows Server.' $platform
}
if ($platform.IsVirtualMachine) {
    Stop-UnsupportedWindowsPlatform 'A Windows virtual machine/VPS guest was detected. NeoLabs does not use Windows VM/VPS guests for remote SOC work because WSL2 depends on host-provided nested virtualization. Use an Ubuntu/Debian VPS instead.' $platform
}
Write-Host '[OK] Supported physical Windows workstation path detected.' -ForegroundColor Green

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Write-Step 'WSL is not enabled. Requesting the Windows WSL feature installation...'
    $exitCode = Invoke-ElevatedPowerShell 'wsl.exe --install --no-distribution'
    if ($exitCode -ne 0) { throw 'Windows could not enable WSL automatically. Run `wsl --install` once from an Administrator PowerShell.' }
    throw 'WSL installation was started. Restart Windows if requested, then run START-NEOLABS-SOC.cmd again.'
}

Write-Step 'Checking WSL2...'
& wsl.exe --set-default-version 2 *> $null
if ($LASTEXITCODE -ne 0) { throw 'Windows could not set WSL2 as the default. Run `wsl --update`, confirm hardware virtualisation is enabled, restart if requested, and retry.' }

$defaultDistro = Get-DefaultWslDistribution
if (-not $defaultDistro) {
    Write-Step 'No Linux distribution is installed. Requesting an Ubuntu WSL2 installation...'
    $exitCode = Invoke-ElevatedPowerShell 'wsl.exe --install -d Ubuntu'
    if ($exitCode -ne 0) { throw 'Windows could not install Ubuntu WSL2 automatically.' }
    throw 'Ubuntu WSL2 installation was started. Restart Windows if requested, launch Ubuntu once to create its Linux user, then rerun START-NEOLABS-SOC.cmd.'
}
if ($defaultDistro.Version -ne 2) {
    Write-Step "Converting '$($defaultDistro.Name)' to WSL2..."
    & wsl.exe --set-version $defaultDistro.Name 2
    if ($LASTEXITCODE -ne 0) { throw "Could not convert '$($defaultDistro.Name)' to WSL2." }
    $defaultDistro = Get-DefaultWslDistribution
    if (-not $defaultDistro -or $defaultDistro.Version -ne 2) { throw 'The default Linux distribution is not running as WSL2 yet.' }
}
Write-Host "[OK] Default WSL distro: $($defaultDistro.Name) (WSL2)" -ForegroundColor Green

$linuxRoot = (& wsl.exe --distribution $defaultDistro.Name --exec wslpath -a $ToolkitRoot 2>$null | Select-Object -First 1)
if (-not $linuxRoot) { throw 'The SOC toolkit folder cannot be translated into WSL2.' }
$linuxRoot = $linuxRoot.Trim()

$script:DockerCli = Find-DockerCliExecutable
$desktopExe = Find-DockerDesktopExecutable
if (-not $script:DockerCli -and -not $desktopExe) {
    $installed = Install-DockerDesktopWithWinget
    if (-not $installed) {
        try { Start-Process 'https://docs.docker.com/desktop/setup/install/windows-install/' } catch { }
        throw 'Docker Desktop is missing and automatic installation failed.'
    }
    $script:DockerCli = Find-DockerCliExecutable
    $desktopExe = Find-DockerDesktopExecutable
    if (-not $script:DockerCli -and -not $desktopExe) { throw 'Docker Desktop installed but Windows has not exposed it yet. Restart/sign out if requested, then rerun the launcher.' }
}

if (-not $script:DockerCli) { $script:DockerCli = Find-DockerCliExecutable }
if (-not $script:DockerCli) { throw 'docker.exe could not be found.' }

Resolve-NeoLabsDockerContext
$osType = Get-DockerOsType

if ($osType) {
    Write-Host "[OK] Docker daemon already responding ($osType containers)." -ForegroundColor Green
} else {
    if (Test-DockerDesktopRunning) {
        Write-Host '[OK] Docker Desktop reports running; waiting only for daemon health.' -ForegroundColor Green
    } else {
        Write-Step 'Starting Docker Desktop...'
        $started = $false
        if (Test-DockerDesktopCli) {
            try {
                & $script:DockerCli desktop start --timeout $TimeoutSeconds *> $null
                $started = ($LASTEXITCODE -eq 0)
            } catch { $started = $false }
        }
        if (-not $started) {
            if (-not $desktopExe) { $desktopExe = Find-DockerDesktopExecutable }
            if (-not $desktopExe) { throw 'Docker Desktop is installed but its executable could not be located.' }
            Start-Process -FilePath $desktopExe | Out-Null
        }
    }

    Resolve-NeoLabsDockerContext
    Write-Step "Waiting for the Docker engine (maximum $TimeoutSeconds seconds)..."
    $osType = Wait-DockerEngine $TimeoutSeconds
}

if (-not $osType -and (Test-DockerDesktopRunning) -and (Test-DockerDesktopCli)) {
    Write-Host '[WARN] Docker Desktop UI is running but its daemon is not answering. Performing one automatic Desktop restart.' -ForegroundColor Yellow
    try { & $script:DockerCli desktop restart --timeout 120 *> $null } catch { }
    Resolve-NeoLabsDockerContext
    $osType = Wait-DockerEngine 90
}

if (-not $osType) {
    throw 'Docker Desktop is running but the Docker daemon is not responding. Open Docker Desktop once and review its engine/WSL error banner, then rerun START-NEOLABS-SOC.cmd.'
}

if ($osType -eq 'windows') {
    Write-Step 'Switching Docker Desktop to Linux containers...'
    if (-not (Test-DockerDesktopCli)) { throw 'Docker Desktop is using Windows containers and this version cannot be switched by the launcher CLI.' }
    & $script:DockerCli desktop engine use linux *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop could not switch to Linux containers.' }
    Resolve-NeoLabsDockerContext
    $osType = Wait-DockerEngine $TimeoutSeconds
}

if ($osType -ne 'linux') { throw 'NeoLabs SOC requires Docker Desktop Linux containers on the WSL2 backend.' }
Write-Host '[OK] Docker Desktop Linux engine is healthy.' -ForegroundColor Green

Write-Step "Verifying Docker access inside WSL2 distro '$($defaultDistro.Name)'..."
$wslDocker = Wait-WslDocker $defaultDistro.Name $linuxRoot 30

if ($wslDocker -ne 'linux') {
    Write-Host '[WARN] Docker engine is healthy on Windows but the WSL distro has not attached yet. Refreshing WSL/Docker once.' -ForegroundColor Yellow
    & wsl.exe --shutdown *> $null
    Start-Sleep -Seconds 2
    if (Test-DockerDesktopCli) {
        try { & $script:DockerCli desktop restart --timeout 120 *> $null } catch { }
    } else {
        if (-not $desktopExe) { $desktopExe = Find-DockerDesktopExecutable }
        if ($desktopExe) { Start-Process -FilePath $desktopExe | Out-Null }
    }
    Resolve-NeoLabsDockerContext
    $osType = Wait-DockerEngine 90
    if ($osType -ne 'linux') { throw 'Docker Desktop did not recover its Linux engine after the WSL refresh.' }
    $wslDocker = Wait-WslDocker $defaultDistro.Name $linuxRoot 60
}

if ($wslDocker -ne 'linux') {
    throw "Docker Desktop Linux engine is healthy, but Docker is not exposed inside '$($defaultDistro.Name)'. Confirm Docker Desktop > Settings > Resources > WSL Integration has that distro enabled, Apply, then rerun."
}

Write-Host '[OK] Docker is reachable from the WSL2 environment used by NeoLabs.' -ForegroundColor Green
