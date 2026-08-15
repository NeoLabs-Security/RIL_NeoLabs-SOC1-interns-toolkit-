param(
    [switch]$ValidateOnly,
    [int]$DaemonTimeoutSeconds = 75,
    [string]$ToolkitRoot = ''
)

$ErrorActionPreference = 'Stop'
$MinimumWslVersion = [version]'2.1.5'
$MinimumDockerDesktopVersion = [version]'4.83.0'
$script:DockerCli = $null
$script:DockerContext = $null

if (-not $ToolkitRoot) {
    $ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

function Write-Step([string]$Message) {
    Write-Host "[NeoLabs AutoFix] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Invoke-ElevatedPowerShell([string]$Command) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
    )
    return $process.ExitCode
}

function Assert-PhysicalWindowsWorkstation {
    $os = $null
    $computer = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { }
    try { $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { }

    $caption = if ($os) { [string]$os.Caption } else { '' }
    $productType = if ($os) { [int]$os.ProductType } else { 0 }
    $manufacturer = if ($computer) { [string]$computer.Manufacturer } else { '' }
    $model = if ($computer) { [string]$computer.Model } else { '' }
    $identity = "$manufacturer $model".ToLowerInvariant()

    $virtualPatterns = @(
        'virtual machine', 'vmware', 'virtualbox', 'qemu', 'kvm', 'xen',
        'amazon ec2', 'google compute engine', 'digitalocean', 'openstack',
        'parallels', 'nutanix'
    )
    $isVirtual = $false
    foreach ($pattern in $virtualPatterns) {
        if ($identity.Contains($pattern)) {
            $isVirtual = $true
            break
        }
    }

    $isServer = (($productType -ne 0) -and ($productType -ne 1)) -or ($caption -match 'Windows Server')
    if ($isServer -or $isVirtual) {
        throw 'NeoLabs Windows SOC requires a physical Windows 10/11 workstation. Use Ubuntu/Debian directly for VPS/VM deployments.'
    }

    Write-Ok 'Supported physical Windows workstation detected.'
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

function Test-WslRuntimeHealthy {
    try {
        & wsl.exe --status *> $null
        if ($LASTEXITCODE -ne 0) { return $false }
        & wsl.exe -l -v *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Get-NeoLabsWslDistribution {
    try {
        $raw = (& wsl.exe -l -v 2>$null | Out-String) -replace "`0", ''
        $distros = @()
        foreach ($line in ($raw -split "`r?`n")) {
            if ($line -match '^\s*(\*)?\s*(.+?)\s+(Running|Stopped)\s+([12])\s*$') {
                $name = $Matches[2].Trim()
                if ($name -and $name -notmatch '^docker-desktop(?:-data)?$') {
                    $distros += [pscustomobject]@{
                        Name = $name
                        Version = [int]$Matches[4]
                        IsDefault = [bool]$Matches[1]
                    }
                }
            }
        }

        $selected = $distros | Where-Object { $_.IsDefault } | Select-Object -First 1
        if (-not $selected) {
            $selected = $distros | Where-Object { $_.Version -eq 2 } | Select-Object -First 1
        }
        if (-not $selected) {
            $selected = $distros | Select-Object -First 1
        }
        return $selected
    } catch {
        return $null
    }
}

function Update-WslRuntime {
    Write-Step 'Updating WSL to the current Microsoft runtime...'
    $updated = $false

    try {
        & wsl.exe --update
        $updated = ($LASTEXITCODE -eq 0)
    } catch { }

    if (-not $updated) {
        try {
            & wsl.exe --update --web-download
            $updated = ($LASTEXITCODE -eq 0)
        } catch { }
    }

    if (-not $updated) {
        $command = @'
wsl.exe --update
if ($LASTEXITCODE -ne 0) {
    wsl.exe --update --web-download
    exit $LASTEXITCODE
}
exit 0
'@
        $updated = ((Invoke-ElevatedPowerShell $command) -eq 0)
    }

    if (-not $updated) {
        throw 'WSL could not be updated automatically. Check Windows Update/network policy and retry NeoLabs.'
    }

    & wsl.exe --shutdown *> $null
    Write-Ok 'WSL update completed.'
}

function Ensure-WslRuntime {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Write-Step 'WSL is missing. Enabling WSL and VirtualMachinePlatform...'
        $command = @'
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
wsl.exe --install --no-distribution
exit $LASTEXITCODE
'@
        if ((Invoke-ElevatedPowerShell $command) -ne 0) {
            throw 'Windows could not enable WSL automatically.'
        }
        Write-Warn 'WSL was enabled. Restart Windows once, then rerun START-NEOLABS-SOC.cmd.'
        exit 3010
    }

    try { & wsl.exe --set-default-version 2 *> $null } catch { }

    $version = Get-WslPackageVersion
    $healthy = Test-WslRuntimeHealthy
    if (-not $version -or $version -lt $MinimumWslVersion -or -not $healthy) {
        if ($version) {
            Write-Warn "WSL runtime $version is below/failed the NeoLabs readiness check."
        } else {
            Write-Warn 'Modern WSL package version could not be read.'
        }
        Update-WslRuntime
        $version = Get-WslPackageVersion
    }

    if ($version) { Write-Ok "WSL runtime: $version" }

    $distro = Get-NeoLabsWslDistribution
    if (-not $distro) {
        Write-Step 'No user WSL distribution is installed. Installing Ubuntu WSL2...'
        if ((Invoke-ElevatedPowerShell 'wsl.exe --install -d Ubuntu') -ne 0) {
            throw 'Ubuntu WSL2 could not be installed automatically.'
        }
        Write-Warn 'Ubuntu was installed. Restart if requested, launch Ubuntu once to create its Linux user, then rerun NeoLabs.'
        exit 3010
    }

    if ($distro.Version -ne 2) {
        Write-Step "Converting '$($distro.Name)' to WSL2..."
        & wsl.exe --set-version $distro.Name 2
        if ($LASTEXITCODE -ne 0) {
            throw "Could not convert '$($distro.Name)' to WSL2."
        }
        $distro = Get-NeoLabsWslDistribution
    }

    & wsl.exe --set-default $distro.Name *> $null
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
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
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
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function ConvertTo-VersionOrNull([string]$Text) {
    if ($Text -and $Text -match '([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)') {
        try { return [version]$Matches[1] } catch { }
    }
    return $null
}

function Get-DockerDesktopVersion {
    $desktopExe = Find-DockerDesktopExecutable
    if ($desktopExe) {
        try {
            $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($desktopExe)
            foreach ($text in @($info.ProductVersion, $info.FileVersion)) {
                $version = ConvertTo-VersionOrNull $text
                if ($version) { return $version }
            }
        } catch { }
    }

    $uninstallRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $uninstallRoots) {
        try {
            $entry = Get-ItemProperty $root -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq 'Docker Desktop' } |
                Select-Object -First 1
            if ($entry) {
                $version = ConvertTo-VersionOrNull ([string]$entry.DisplayVersion)
                if ($version) { return $version }
            }
        } catch { }
    }
    return $null
}

function Test-DockerDesktopCli {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli desktop version *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-DockerContext([string]$Name) {
    if (-not $script:DockerCli) { return $false }
    try {
        & $script:DockerCli context inspect $Name *> $null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Resolve-NeoLabsDockerContext {
    $hasDesktopLinux = $false
    if ($script:DockerCli) {
        $hasDesktopLinux = Test-DockerContext 'desktop-linux'
    }

    if ($hasDesktopLinux) {
        $script:DockerContext = 'desktop-linux'
        $env:DOCKER_CONTEXT = 'desktop-linux'
    } else {
        $script:DockerContext = $null
        Remove-Item Env:DOCKER_CONTEXT -ErrorAction SilentlyContinue
    }
}

function Invoke-DockerProbe([string[]]$ProbeArguments) {
    if (-not $script:DockerCli) { return $null }
    try {
        $arguments = @()
        if ($script:DockerContext) {
            $arguments += @('--context', $script:DockerContext)
        }
        $arguments += $ProbeArguments
        $value = (& $script:DockerCli @arguments 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value) {
            return $value.Trim().ToLowerInvariant()
        }
    } catch { }
    return $null
}

function Get-DockerOsType {
    $value = Invoke-DockerProbe @('info', '--format', '{{.OSType}}')
    if ($value -in @('linux', 'windows')) { return $value }

    # Independent fallback: on some Desktop startups the server can answer the
    # version endpoint before `docker info --format` has settled.
    $value = Invoke-DockerProbe @('version', '--format', '{{.Server.Os}}')
    if ($value -in @('linux', 'windows')) { return $value }
    return $null
}

function Wait-DockerEngine([int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        # Docker Desktop can report "running" before desktop-linux is published.
        # Refresh the context every probe so the whole wait is not pinned to a
        # stale default endpoint.
        Resolve-NeoLabsDockerContext
        $value = Get-DockerOsType
        if ($value) { return $value }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    Resolve-NeoLabsDockerContext
    return (Get-DockerOsType)
}

function Start-DockerDesktop([int]$TimeoutSeconds = 120) {
    if (Test-DockerDesktopCli) {
        try {
            & $script:DockerCli desktop start --timeout $TimeoutSeconds *> $null
            if ($LASTEXITCODE -eq 0) { return $true }
        } catch { }
    }

    $desktopExe = Find-DockerDesktopExecutable
    if ($desktopExe) {
        try {
            Start-Process -FilePath $desktopExe | Out-Null
            return $true
        } catch { }
    }
    return $false
}

function Stop-DockerDesktop {
    if (Test-DockerDesktopCli) {
        try { & $script:DockerCli desktop stop --timeout 90 *> $null } catch { }
    }
}

function Restart-DockerDesktopCleanly {
    Stop-DockerDesktop
    Start-Sleep -Seconds 2
    try { & wsl.exe --shutdown *> $null } catch { }
    Start-DockerDesktop 150 | Out-Null
}

function Try-DockerDesktopUpdate {
    $attempted = $false

    if (Test-DockerDesktopCli) {
        try {
            $attempted = $true
            & $script:DockerCli desktop update --quiet
            Start-Sleep -Seconds 5
        } catch { }
    }

    $version = Get-DockerDesktopVersion
    if ($version -and $version -ge $MinimumDockerDesktopVersion) {
        return $true
    }

    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        try {
            $attempted = $true
            & winget.exe upgrade --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
            Start-Sleep -Seconds 7
        } catch { }
    }

    $script:DockerCli = Find-DockerCliExecutable
    return $attempted
}

function Ensure-DockerDesktopInstalled {
    $script:DockerCli = Find-DockerCliExecutable
    $desktopExe = Find-DockerDesktopExecutable
    if ($script:DockerCli -or $desktopExe) { return }

    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw 'Docker Desktop is missing and Windows Package Manager (winget) is unavailable.'
    }

    Write-Step 'Docker Desktop is missing. Installing it automatically...'
    & winget.exe install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Desktop automatic installation failed.'
    }
    Start-Sleep -Seconds 5
    $script:DockerCli = Find-DockerCliExecutable
    if (-not $script:DockerCli) {
        throw 'Docker Desktop installed but docker.exe is not available yet. Restart/sign out if requested, then rerun NeoLabs.'
    }
}

function Ensure-DockerDesktopVersion {
    Ensure-DockerDesktopInstalled
    $script:DockerCli = Find-DockerCliExecutable
    $version = Get-DockerDesktopVersion

    if ($version -and $version -ge $MinimumDockerDesktopVersion) {
        Write-Ok "Docker Desktop version: $version"
        return
    }

    Write-Warn "Docker Desktop must be $MinimumDockerDesktopVersion or newer for current WSL integration. Updating automatically."
    Try-DockerDesktopUpdate | Out-Null
    $script:DockerCli = Find-DockerCliExecutable
    $version = Get-DockerDesktopVersion

    if ($version -and $version -lt $MinimumDockerDesktopVersion) {
        throw "Docker Desktop is still $version; update to $MinimumDockerDesktopVersion or newer."
    }
    if ($version) {
        Write-Ok "Docker Desktop version: $version"
    } else {
        Write-Warn 'Docker Desktop version could not be read; daemon/integration health checks will decide readiness.'
    }
}

function Get-DockerSettingsPath {
    if ($env:APPDATA) {
        return (Join-Path $env:APPDATA 'Docker\settings-store.json')
    }
    return $null
}

function Get-JsonProperty($Object, [string]$Name) {
    return ($Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1)
}

function Set-JsonProperty($Object, [string]$Name, $Value) {
    $property = Get-JsonProperty $Object $Name
    if ($property) {
        $property.Value = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path, $Text, $encoding)
}

function Set-DockerWslIntegration {
    param(
        [string]$DistroName,
        [string]$SettingsPath = '',
        [switch]$NoBackup
    )

    if (-not $SettingsPath) { $SettingsPath = Get-DockerSettingsPath }
    if (-not $SettingsPath -or -not (Test-Path -LiteralPath $SettingsPath -PathType Leaf)) {
        return $false
    }

    $settings = (Get-Content -LiteralPath $SettingsPath -Raw) | ConvertFrom-Json
    if (-not $settings) { throw 'Docker settings-store.json is invalid JSON.' }

    if (-not $NoBackup) {
        $backupDir = Join-Path $env:LOCALAPPDATA 'NeoLabs\backups'
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        $backupPath = Join-Path $backupDir ("docker-settings-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Copy-Item -LiteralPath $SettingsPath -Destination $backupPath -Force
    }

    Set-JsonProperty $settings 'wslEngineEnabled' $true
    Set-JsonProperty $settings 'enableIntegrationWithDefaultWslDistro' $true

    $integratedProperty = Get-JsonProperty $settings 'integratedWslDistros'
    $existing = @()
    if ($integratedProperty -and $null -ne $integratedProperty.Value) {
        $existing = @($integratedProperty.Value | ForEach-Object { [string]$_ })
    }
    $integrated = @(
        @($existing + @($DistroName)) |
            Where-Object { $_ -and $_ -notmatch '^docker-desktop(?:-data)?$' } |
            Select-Object -Unique
    )
    Set-JsonProperty $settings 'integratedWslDistros' $integrated

    Write-Utf8NoBom $SettingsPath ($settings | ConvertTo-Json -Depth 100)

    $verified = (Get-Content -LiteralPath $SettingsPath -Raw) | ConvertFrom-Json
    $engineProperty = Get-JsonProperty $verified 'wslEngineEnabled'
    $defaultProperty = Get-JsonProperty $verified 'enableIntegrationWithDefaultWslDistro'
    $distrosProperty = Get-JsonProperty $verified 'integratedWslDistros'

    if (-not $engineProperty -or -not [bool]$engineProperty.Value) {
        throw 'Docker WSL engine setting did not persist.'
    }
    if (-not $defaultProperty -or -not [bool]$defaultProperty.Value) {
        throw 'Docker default WSL integration setting did not persist.'
    }
    if (-not $distrosProperty -or @($distrosProperty.Value) -notcontains $DistroName) {
        throw "Docker WSL integration list did not retain '$DistroName'."
    }

    return $true
}

function Test-DockerInsideWsl([string]$DistroName, [string]$LinuxRoot) {
    try {
        $value = (& wsl.exe --distribution $DistroName --cd $LinuxRoot --exec sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value -and $value.Trim().ToLowerInvariant() -eq 'linux') {
            return $true
        }
    } catch { }

    try {
        $value = (& wsl.exe --distribution $DistroName --cd $LinuxRoot --exec sh -lc 'docker version --format "{{.Server.Os}}" 2>/dev/null' 2>$null | Select-Object -First 1)
        return ($LASTEXITCODE -eq 0 -and $value -and $value.Trim().ToLowerInvariant() -eq 'linux')
    } catch {
        return $false
    }
}

function Wait-DockerInsideWsl([string]$DistroName, [string]$LinuxRoot, [int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        if (Test-DockerInsideWsl $DistroName $LinuxRoot) { return $true }
        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)
    return (Test-DockerInsideWsl $DistroName $LinuxRoot)
}

function Save-RuntimeDiagnostics([string]$Reason, [string]$DistroName = '') {
    $logDir = Join-Path $env:LOCALAPPDATA 'NeoLabs\logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $path = Join-Path $logDir ("runtime-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    Resolve-NeoLabsDockerContext
    @(
        'NeoLabs Windows runtime diagnostics',
        "Time: $(Get-Date -Format o)",
        "Reason: $Reason",
        "Docker Desktop version: $(Get-DockerDesktopVersion)",
        "NeoLabs engine probe: $(Get-DockerOsType)"
    ) | Out-File -FilePath $path -Encoding utf8

    "`n=== WSL VERSION ===" | Out-File -FilePath $path -Append
    try { (& wsl.exe --version 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }
    "`n=== WSL DISTROS ===" | Out-File -FilePath $path -Append
    try { (& wsl.exe -l -v 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }

    "`n=== DOCKER SERVICE ===" | Out-File -FilePath $path -Append
    try { (Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue | Format-List Name, Status, StartType | Out-String) | Out-File -FilePath $path -Append } catch { }

    "`n=== DOCKER PROCESSES ===" | Out-File -FilePath $path -Append
    try { (Get-Process | Where-Object { $_.ProcessName -match 'docker|vpnkit' } | Select-Object ProcessName, Id, Path | Format-Table -AutoSize | Out-String) | Out-File -FilePath $path -Append } catch { }

    if ($script:DockerCli) {
        "`n=== DOCKER CONTEXTS ===" | Out-File -FilePath $path -Append
        try { (& $script:DockerCli context ls 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }

        "`n=== DOCKER INFO ===" | Out-File -FilePath $path -Append
        try {
            $arguments = @()
            if ($script:DockerContext) { $arguments += @('--context', $script:DockerContext) }
            $arguments += 'info'
            (& $script:DockerCli @arguments 2>&1 | Out-String) | Out-File -FilePath $path -Append
        } catch { }
    }

    if (Test-DockerDesktopCli) {
        "`n=== DOCKER DESKTOP STATUS ===" | Out-File -FilePath $path -Append
        try { (& $script:DockerCli desktop status 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }
        "`n=== DOCKER DESKTOP LOGS (10m) ===" | Out-File -FilePath $path -Append
        try { (& $script:DockerCli desktop logs --priority 2 --since '10m' 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }
        # Intentionally do not run `docker desktop diagnose` here: that command can
        # spend many minutes building a support archive and made the one-click
        # launcher appear hung on cohort machines.
    }

    $settingsPath = Get-DockerSettingsPath
    if ($settingsPath -and (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        try {
            $settings = (Get-Content -LiteralPath $settingsPath -Raw) | ConvertFrom-Json
            $defaultProperty = Get-JsonProperty $settings 'enableIntegrationWithDefaultWslDistro'
            $distrosProperty = Get-JsonProperty $settings 'integratedWslDistros'
            "`n=== WSL INTEGRATION SETTINGS ===" | Out-File -FilePath $path -Append
            "Default integration: $($defaultProperty.Value)" | Out-File -FilePath $path -Append
            "Integrated distros: $(@($distrosProperty.Value) -join ', ')" | Out-File -FilePath $path -Append
        } catch { }
    }

    if ($DistroName) {
        "`n=== USER DISTRO DOCKER PROXY ===" | Out-File -FilePath $path -Append
        try {
            $command = 'command -v docker; docker info --format "{{.OSType}}" 2>&1; docker version --format "{{.Server.Os}}" 2>&1; ls -l /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker 2>&1; stat -c "%n size=%s mode=%a" /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker 2>&1'
            (& wsl.exe -d $DistroName --exec sh -lc $command 2>&1 | Out-String) | Out-File -FilePath $path -Append
        } catch { }
    }

    Write-Warn "Diagnostic log saved to: $path"
    return $path
}

function Ensure-DockerLinuxEngine {
    Ensure-DockerDesktopVersion
    Resolve-NeoLabsDockerContext

    $osType = Get-DockerOsType
    if ($osType -eq 'linux') {
        Write-Ok 'Docker Linux engine is healthy.'
        return
    }

    if ($osType -eq 'windows') {
        Write-Step 'Docker is using Windows containers. Switching to Linux containers...'
        if (-not (Test-DockerDesktopCli)) {
            throw 'Docker Desktop CLI cannot switch the engine automatically.'
        }
        & $script:DockerCli desktop engine use linux *> $null
        Resolve-NeoLabsDockerContext
        if ((Wait-DockerEngine $DaemonTimeoutSeconds) -eq 'linux') {
            Write-Ok 'Docker Linux engine is healthy.'
            return
        }
    }

    Write-Step 'Starting/recovering the Docker Linux engine...'
    Start-DockerDesktop $DaemonTimeoutSeconds | Out-Null
    Resolve-NeoLabsDockerContext
    if ((Wait-DockerEngine $DaemonTimeoutSeconds) -eq 'linux') {
        Write-Ok 'Docker Linux engine is healthy.'
        return
    }

    Write-Warn 'Docker daemon is not answering. Performing one clean Docker/WSL restart.'
    Restart-DockerDesktopCleanly
    Resolve-NeoLabsDockerContext
    if ((Wait-DockerEngine 120) -eq 'linux') {
        Write-Ok 'Docker recovered after clean restart.'
        return
    }

    $wslHealthy = Test-WslRuntimeHealthy
    if (-not $wslHealthy) {
        Write-Warn 'WSL itself is unhealthy; updating WSL once before the final Docker retry.'
        Update-WslRuntime
        Restart-DockerDesktopCleanly
        Resolve-NeoLabsDockerContext
        if ((Wait-DockerEngine 120) -eq 'linux') {
            Write-Ok 'Docker recovered after WSL repair.'
            return
        }
    }

    Write-Warn 'Applying one Docker Desktop update/recovery attempt.'
    Try-DockerDesktopUpdate | Out-Null
    $script:DockerCli = Find-DockerCliExecutable
    Restart-DockerDesktopCleanly
    Resolve-NeoLabsDockerContext
    if ((Wait-DockerEngine 150) -eq 'linux') {
        Write-Ok 'Docker recovered after Desktop update.'
        return
    }

    if ((Wait-DockerEngine 30) -eq 'linux') {
        Write-Ok 'Docker Linux engine became ready during the final grace probe.'
        return
    }

    $logPath = Save-RuntimeDiagnostics 'Docker Linux daemon did not recover after bounded automatic repair.'
    if ((Get-DockerOsType) -eq 'linux') {
        Write-Ok 'Docker Linux engine became healthy while diagnostics were being written; continuing.'
        return
    }
    throw "Docker Desktop needs attention on this workstation. Diagnostic log: $logPath"
}

function Apply-DockerWslIntegration([string]$DistroName) {
    Write-Step "Enabling Docker WSL integration for '$DistroName'..."
    & wsl.exe --set-default $DistroName *> $null

    Stop-DockerDesktop
    try { & wsl.exe --shutdown *> $null } catch { }

    $settingsChanged = $false
    try {
        $settingsChanged = Set-DockerWslIntegration -DistroName $DistroName
    } catch {
        Write-Warn $_.Exception.Message
    }

    if ($settingsChanged) {
        Write-Ok "Docker settings explicitly include '$DistroName'."
    } else {
        Write-Warn 'Docker settings-store.json is not available; continuing with default-distro integration and runtime re-test.'
    }

    Start-DockerDesktop 150 | Out-Null
    Resolve-NeoLabsDockerContext
    if ((Wait-DockerEngine 150) -ne 'linux') {
        Ensure-DockerLinuxEngine
    }
}

function Ensure-DockerInsideWsl($Distro) {
    $linuxRoot = (& wsl.exe --distribution $Distro.Name --exec wslpath -a $ToolkitRoot 2>$null | Select-Object -First 1)
    if (-not $linuxRoot) {
        throw 'Could not translate the NeoLabs toolkit path into WSL2.'
    }
    $linuxRoot = $linuxRoot.Trim()

    if (Test-DockerInsideWsl $Distro.Name $linuxRoot) {
        Write-Ok "Docker is available inside '$($Distro.Name)'."
        return
    }

    Write-Warn "Docker is healthy on Windows but '$($Distro.Name)' is not integrated. Repairing automatically."
    Apply-DockerWslIntegration $Distro.Name
    if (Wait-DockerInsideWsl $Distro.Name $linuxRoot 90) {
        Write-Ok "Docker WSL integration is healthy for '$($Distro.Name)'."
        return
    }

    Write-Warn 'WSL integration still failed. Applying one final Docker Desktop update and reasserting integration.'
    Try-DockerDesktopUpdate | Out-Null
    $script:DockerCli = Find-DockerCliExecutable
    Apply-DockerWslIntegration $Distro.Name
    if (Wait-DockerInsideWsl $Distro.Name $linuxRoot 120) {
        Write-Ok "Docker WSL integration recovered for '$($Distro.Name)'."
        return
    }

    $logPath = Save-RuntimeDiagnostics "Docker is healthy on Windows but unavailable inside '$($Distro.Name)'." $Distro.Name
    if (Test-DockerInsideWsl $Distro.Name $linuxRoot) {
        Write-Ok "Docker WSL integration became healthy while diagnostics were being written for '$($Distro.Name)'."
        return
    }
    throw "Docker WSL integration is still blocked after automatic repair. Diagnostic log: $logPath"
}

function Invoke-AutoFixSelfTest {
    if ($MinimumDockerDesktopVersion -lt [version]'4.83.0') {
        throw 'Minimum Docker Desktop version regressed below the WSL proxy fix.'
    }

    $fixturePath = Join-Path ([IO.Path]::GetTempPath()) ("neolabs-settings-{0}.json" -f [guid]::NewGuid().ToString('N'))
    try {
        $fixture = [ordered]@{
            wslEngineEnabled = $false
            enableIntegrationWithDefaultWslDistro = $false
            integratedWslDistros = @('Debian')
            unrelatedSetting = 7
        }
        Write-Utf8NoBom $fixturePath ($fixture | ConvertTo-Json -Depth 10)
        Set-DockerWslIntegration -DistroName 'Ubuntu' -SettingsPath $fixturePath -NoBackup | Out-Null
        $verified = (Get-Content -LiteralPath $fixturePath -Raw) | ConvertFrom-Json

        if (-not $verified.wslEngineEnabled) { throw 'Self-test failed: WSL engine was not enabled.' }
        if (-not $verified.enableIntegrationWithDefaultWslDistro) { throw 'Self-test failed: default WSL integration was not enabled.' }
        if (@($verified.integratedWslDistros) -notcontains 'Ubuntu') { throw 'Self-test failed: Ubuntu was not added.' }
        if (@($verified.integratedWslDistros) -notcontains 'Debian') { throw 'Self-test failed: existing distro was lost.' }
        if ($verified.unrelatedSetting -ne 7) { throw 'Self-test failed: unrelated Docker setting was changed.' }
    } finally {
        Remove-Item -LiteralPath $fixturePath -Force -ErrorAction SilentlyContinue
    }
}

if ($ValidateOnly) {
    Invoke-AutoFixSelfTest
    Write-Ok 'Windows AutoFix contract/self-test passed.'
    Write-Ok "Minimums: WSL $MinimumWslVersion, Docker Desktop $MinimumDockerDesktopVersion."
    exit 0
}

if ($DaemonTimeoutSeconds -lt 20 -or $DaemonTimeoutSeconds -gt 300) {
    throw 'DaemonTimeoutSeconds must be between 20 and 300 seconds.'
}

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '      NeoLabs Windows Runtime AutoFix' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

Assert-PhysicalWindowsWorkstation
$distro = Ensure-WslRuntime
Ensure-DockerLinuxEngine
Ensure-DockerInsideWsl $distro
Write-Ok 'Windows/WSL2/Docker runtime is ready for the SOC launcher.'
