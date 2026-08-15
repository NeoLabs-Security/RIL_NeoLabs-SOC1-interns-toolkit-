param(
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$MinimumWslVersion = [version]'2.1.5'
$MinimumDockerDesktopVersion = [version]'4.83.0'

function Write-Ok([string]$Message) {
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function ConvertTo-VersionOrNull([string]$Text) {
    if ($Text -and $Text -match '([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)') {
        try { return [version]$Matches[1] } catch { }
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

function Get-DockerDesktopVersion {
    $desktopExe = Find-DockerDesktopExecutable
    if (-not $desktopExe) { return $null }
    try {
        $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($desktopExe)
        foreach ($text in @($info.ProductVersion, $info.FileVersion)) {
            $version = ConvertTo-VersionOrNull $text
            if ($version) { return $version }
        }
    } catch { }
    return $null
}

function Test-SupportedPhysicalWindows {
    $os = $null
    $computer = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { return $false }
    try { $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { return $false }

    $caption = [string]$os.Caption
    $productType = [int]$os.ProductType
    $identity = ("{0} {1}" -f [string]$computer.Manufacturer, [string]$computer.Model).ToLowerInvariant()
    if ((($productType -ne 0) -and ($productType -ne 1)) -or ($caption -match 'Windows Server')) { return $false }

    foreach ($pattern in @(
        'virtual machine','vmware','virtualbox','qemu','kvm','xen','amazon ec2',
        'google compute engine','digitalocean','openstack','parallels','nutanix'
    )) {
        if ($identity.Contains($pattern)) { return $false }
    }
    return $true
}

function Get-WslPackageVersion {
    try {
        $lines = @(& wsl.exe --version 2>$null)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) { return $null }
        $text = (($lines | ForEach-Object { [string]$_ }) -join "`n") -replace "`0", ''
        if ($text -match '(?im)^\s*WSL\s+version:\s*([0-9]+(?:\.[0-9]+){1,3})') {
            return [version]$Matches[1]
        }
    } catch { }
    return $null
}

function Get-DefaultWslDistribution {
    try {
        $lines = @(& wsl.exe -l -v 2>$null)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) { return $null }
        $text = (($lines | ForEach-Object { [string]$_ }) -join "`n") -replace "`0", ''
        foreach ($line in ($text -split "`r?`n")) {
            if ($line -match '^\s*\*\s+(.+?)\s+(Running|Stopped)\s+([12])\s*$') {
                $name = $Matches[1].Trim()
                if ($name -and $name -notmatch '^docker-desktop(?:-data)?$') {
                    return [pscustomobject]@{ Name = $name; Version = [int]$Matches[3] }
                }
            }
        }
    } catch { }
    return $null
}

function Convert-DockerOsType([object[]]$Lines, [int]$ExitCode, [switch]$FullInfo) {
    if ($ExitCode -ne 0) { return $null }
    $clean = @()
    foreach ($line in @($Lines)) {
        $value = ([string]$line).Trim()
        if ($value) { $clean += $value }
    }
    if ($FullInfo) {
        foreach ($line in $clean) {
            if ($line -match '^OSType:\s*(linux|windows)\s*$') { return $Matches[1].ToLowerInvariant() }
        }
        return $null
    }
    foreach ($line in $clean) {
        $value = $line.ToLowerInvariant()
        if ($value -eq 'linux' -or $value -eq 'windows') { return $value }
    }
    return $null
}

function Get-DockerHostOsType([string]$DockerCli) {
    try {
        & $DockerCli context inspect desktop-linux *> $null
        if ($LASTEXITCODE -ne 0) { return $null }

        # Capture the native process completely before examining its output. This
        # avoids a readiness false negative caused by terminating the native
        # output pipeline after its first object while Docker Desktop is starting.
        $lines = @(& $DockerCli --context desktop-linux info --format '{{.OSType}}' 2>$null)
        $exitCode = $LASTEXITCODE
        $osType = Convert-DockerOsType $lines $exitCode
        if ($osType) { return $osType }

        # The 2026-08-15 field diagnostics proved that full `docker info` could
        # already reach a Linux server even when the narrow readiness probe said
        # the daemon was unavailable. Treat the full server response as a second,
        # independent positive confirmation before any Docker restart is allowed.
        $lines = @(& $DockerCli --context desktop-linux info 2>$null)
        $exitCode = $LASTEXITCODE
        return (Convert-DockerOsType $lines $exitCode -FullInfo)
    } catch { }
    return $null
}

function Get-DockerWslOsType([string]$DistroName) {
    try {
        $lines = @(& wsl.exe --distribution $DistroName --exec sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null)
        $exitCode = $LASTEXITCODE
        return (Convert-DockerOsType $lines $exitCode)
    } catch { }
    return $null
}

function Test-NeoLabsDockerRuntime {
    if (-not (Test-SupportedPhysicalWindows)) { return $false }

    $wslVersion = Get-WslPackageVersion
    if (-not $wslVersion -or $wslVersion -lt $MinimumWslVersion) { return $false }

    $distro = Get-DefaultWslDistribution
    if (-not $distro -or $distro.Version -ne 2) { return $false }

    $desktopVersion = Get-DockerDesktopVersion
    if ($desktopVersion -and $desktopVersion -lt $MinimumDockerDesktopVersion) { return $false }

    $dockerCli = Find-DockerCliExecutable
    if (-not $dockerCli) { return $false }

    if ((Get-DockerHostOsType $dockerCli) -ne 'linux') { return $false }
    if ((Get-DockerWslOsType $distro.Name) -ne 'linux') { return $false }

    return $true
}

function Invoke-SelfTest {
    if ((Convert-DockerOsType @('linux') 0) -ne 'linux') { throw 'Formatted Docker OSType parser failed.' }
    if ((Convert-DockerOsType @('Client:', 'Server:', ' OSType: linux', ' CPUs: 4') 0 -FullInfo) -ne 'linux') { throw 'Full docker info fallback parser failed.' }
    if ($null -ne (Convert-DockerOsType @('linux') 1)) { throw 'Docker parser accepted a failed command.' }
}

if ($ValidateOnly) {
    Invoke-SelfTest
    Write-Ok 'Windows Docker runtime confirmation helper contract/self-test passed.'
    exit 0
}

try {
    if (Test-NeoLabsDockerRuntime) {
        Write-Ok 'Existing Windows/WSL2/Docker Linux runtime is fully reachable; repair can be skipped.'
        exit 0
    }
} catch {
    Write-Warn "Fast runtime confirmation could not prove readiness: $($_.Exception.Message)"
}

exit 1
