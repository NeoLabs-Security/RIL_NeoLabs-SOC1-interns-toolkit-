param(
    [switch]$ValidateOnly,
    [int]$TimeoutSeconds = 210
)

$ErrorActionPreference = 'Stop'
$script:DockerCli = $null
$script:DockerContext = $null

function Write-Step([string]$Message) {
    Write-Host "[NeoLabs Docker Recovery] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
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

function Get-DockerInstallMode {
    $desktopExe = Find-DockerDesktopExecutable
    if (-not $desktopExe) { return 'unknown' }

    if ($env:LOCALAPPDATA) {
        $perUserRoot = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop'
        if ($desktopExe.StartsWith($perUserRoot, [StringComparison]::OrdinalIgnoreCase)) {
            return 'per-user-wsl2'
        }
    }
    return 'all-users-or-custom'
}

function Invoke-ElevatedPowerShell([string]$Command) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
    $process = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
    )
    return $process.ExitCode
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

function Resolve-DockerContext {
    $script:DockerContext = $null
    Remove-Item Env:DOCKER_CONTEXT -ErrorAction SilentlyContinue
    if (-not $script:DockerCli) { return }
    try {
        & $script:DockerCli context inspect desktop-linux *> $null
        if ($LASTEXITCODE -eq 0) {
            $script:DockerContext = 'desktop-linux'
            $env:DOCKER_CONTEXT = 'desktop-linux'
        }
    } catch { }
}

function Invoke-DockerProbe([string[]]$ProbeArguments) {
    if (-not $script:DockerCli) { return $null }
    try {
        $arguments = @()
        if ($script:DockerContext) { $arguments += @('--context', $script:DockerContext) }
        $arguments += $ProbeArguments
        $value = (& $script:DockerCli @arguments 2>$null | Select-Object -First 1)
        if ($LASTEXITCODE -eq 0 -and $value) {
            return $value.Trim().ToLowerInvariant()
        }
    } catch { }
    return $null
}

function Get-DockerOsType {
    # Probe the real Desktop Linux engine endpoint, not com.docker.service. Per-user
    # WSL2 installs intentionally do not have the privileged Windows service.
    $value = Invoke-DockerProbe @('info', '--format', '{{.OSType}}')
    if ($value -in @('linux', 'windows')) { return $value }

    # Independent fallback for Docker versions/builds where info formatting is late
    # to become available while the server itself is already responding.
    $value = Invoke-DockerProbe @('version', '--format', '{{.Server.Os}}')
    if ($value -in @('linux', 'windows')) { return $value }
    return $null
}

function Wait-DockerLinuxEngine([int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        # desktop-linux can appear after the Desktop UI/backend has already reported
        # running, so refresh the context on every probe instead of pinning a stale
        # default context for the whole timeout window.
        Resolve-DockerContext
        if ((Get-DockerOsType) -eq 'linux') { return $true }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)

    # Avoid a boundary race where the daemon becomes ready immediately after the
    # final sleep/deadline comparison.
    Resolve-DockerContext
    return ((Get-DockerOsType) -eq 'linux')
}

function Stop-DockerDesktopGracefully {
    if (Test-DockerDesktopCli) {
        try {
            & $script:DockerCli desktop stop --timeout 60 *> $null
        } catch { }
    }
}

function Stop-StaleDockerProcesses {
    $processNames = @(
        'Docker Desktop',
        'com.docker.backend',
        'com.docker.build',
        'com.docker.dev-envs',
        'com.docker.proxy',
        'vpnkit'
    )
    foreach ($name in $processNames) {
        try {
            Get-Process -Name $name -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        } catch { }
    }
}

function Restart-DockerWindowsService {
    $service = Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue
    if (-not $service) {
        if ((Get-DockerInstallMode) -eq 'per-user-wsl2') {
            Write-Ok 'Per-user Docker Desktop WSL2 install detected; com.docker.service is intentionally absent.'
        } else {
            Write-Warn 'Docker Windows service is not installed; continuing with service-less WSL2 backend recovery.'
        }
        return $true
    }

    Write-Step 'Recycling the optional Docker Desktop privileged Windows service...'
    $command = @'
$ErrorActionPreference = 'Stop'
$service = Get-Service -Name 'com.docker.service' -ErrorAction Stop
if ($service.Status -ne 'Stopped') {
    Stop-Service -Name 'com.docker.service' -Force -ErrorAction Stop
    $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(45))
}
Start-Service -Name 'com.docker.service' -ErrorAction Stop
$service = Get-Service -Name 'com.docker.service' -ErrorAction Stop
$service.WaitForStatus('Running', [TimeSpan]::FromSeconds(45))
exit 0
'@
    try {
        $exitCode = Invoke-ElevatedPowerShell $command
        if ($exitCode -eq 0) {
            Write-Ok 'Docker Desktop privileged service is running.'
            return $true
        }
    } catch {
        Write-Warn "Docker service elevation/restart did not complete: $($_.Exception.Message)"
    }
    return $false
}

function Stop-DockerWslBackend {
    try { & wsl.exe --terminate docker-desktop *> $null } catch { }
    try { & wsl.exe --shutdown *> $null } catch { }
}

function Start-DockerDesktop {
    $desktopExe = Find-DockerDesktopExecutable
    if (-not $desktopExe) {
        throw 'Docker Desktop executable could not be found.'
    }
    Start-Process -FilePath $desktopExe | Out-Null
}

function Save-RecoveryDiagnostics([string]$Reason) {
    $logDir = Join-Path $env:LOCALAPPDATA 'NeoLabs\logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $path = Join-Path $logDir ("docker-backend-recovery-{0}.txt" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

    Resolve-DockerContext
    $engineProbe = Get-DockerOsType
    @(
        'NeoLabs Docker Desktop backend recovery diagnostics',
        "Time: $(Get-Date -Format o)",
        "Reason: $Reason",
        "Install mode: $(Get-DockerInstallMode)",
        "NeoLabs engine probe: $engineProbe"
    ) | Out-File -FilePath $path -Encoding utf8

    "`n=== DOCKER SERVICE ===" | Out-File -FilePath $path -Append
    try { (Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue | Format-List * | Out-String) | Out-File -FilePath $path -Append } catch { }

    "`n=== DOCKER PROCESSES ===" | Out-File -FilePath $path -Append
    try { (Get-Process | Where-Object { $_.ProcessName -match 'docker|vpnkit' } | Select-Object ProcessName, Id, Path | Format-Table -AutoSize | Out-String) | Out-File -FilePath $path -Append } catch { }

    "`n=== WSL DISTROS ===" | Out-File -FilePath $path -Append
    try { (& wsl.exe -l -v 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }

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
        if (Test-DockerDesktopCli) {
            "`n=== DOCKER DESKTOP STATUS ===" | Out-File -FilePath $path -Append
            try { (& $script:DockerCli desktop status 2>&1 | Out-String) | Out-File -FilePath $path -Append } catch { }
        }
    }

    Write-Warn "Backend recovery diagnostic log saved to: $path"
    return $path
}

function Invoke-BackendRecovery {
    $script:DockerCli = Find-DockerCliExecutable
    if (-not $script:DockerCli) {
        throw 'docker.exe could not be found; the normal AutoFix installer must repair/reinstall Docker Desktop first.'
    }
    if (-not (Find-DockerDesktopExecutable)) {
        throw 'Docker Desktop.exe could not be found; the normal AutoFix installer must repair/reinstall Docker Desktop first.'
    }

    Resolve-DockerContext
    if ((Get-DockerOsType) -eq 'linux') {
        Write-Ok 'Docker Linux engine is already healthy; deeper backend recovery is not required.'
        return
    }

    # The Desktop CLI is the least-disruptive recovery mechanism. Try it before
    # terminating WSL or killing backend processes.
    if (Test-DockerDesktopCli) {
        Write-Step 'Docker Linux engine is not answering. Requesting one bounded Docker Desktop restart...'
        try { & $script:DockerCli desktop restart --timeout 120 *> $null } catch { }
        if (Wait-DockerLinuxEngine 120) {
            Write-Ok 'Docker Linux engine recovered after Docker Desktop restart.'
            return
        }
    }

    Write-Step 'Docker Desktop is installed but its Linux daemon is still not responding. Performing a deeper non-destructive WSL2 backend recycle...'
    Stop-DockerDesktopGracefully
    Start-Sleep -Seconds 2
    Stop-StaleDockerProcesses
    Stop-DockerWslBackend
    Restart-DockerWindowsService | Out-Null
    Start-DockerDesktop

    if (Wait-DockerLinuxEngine $TimeoutSeconds) {
        Write-Ok 'Docker Linux engine recovered after WSL2 backend recycle.'
        return
    }

    if (Test-DockerDesktopCli) {
        Write-Warn 'Docker is still not ready; asking Docker Desktop itself for one final restart.'
        try { & $script:DockerCli desktop restart --timeout 180 *> $null } catch { }
        if (Wait-DockerLinuxEngine 180) {
            Write-Ok 'Docker Linux engine recovered after Docker Desktop restart.'
            return
        }
    }

    # The uploaded cohort logs showed the daemon becoming healthy at the exact
    # point the previous timeout expired. Give one short, non-destructive final
    # probe before declaring the workstation broken.
    if (Wait-DockerLinuxEngine 30) {
        Write-Ok 'Docker Linux engine became ready during the final grace probe.'
        return
    }

    $path = Save-RecoveryDiagnostics 'Docker Linux daemon remained unavailable after bounded WSL2 backend recovery.'
    if ((Get-DockerOsType) -eq 'linux') {
        Write-Ok 'Docker Linux engine became healthy while diagnostics were being written; accepting the live engine.'
        return
    }
    throw "Docker Desktop backend recovery did not succeed. Diagnostic log: $path"
}

if ($ValidateOnly) {
    if ($TimeoutSeconds -lt 60 -or $TimeoutSeconds -gt 300) {
        throw 'TimeoutSeconds must be between 60 and 300 seconds.'
    }
    if ('$args = @()' -match '^$') { throw 'Unreachable validation guard.' }
    Write-Ok 'Docker Desktop backend recovery helper contract is valid.'
    Write-Ok 'Per-user WSL2 installs are service-optional and readiness is decided by the real Linux engine endpoint.'
    exit 0
}

if ($TimeoutSeconds -lt 60 -or $TimeoutSeconds -gt 300) {
    throw 'TimeoutSeconds must be between 60 and 300 seconds.'
}

Invoke-BackendRecovery
