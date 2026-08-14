param(
    [switch]$ValidateOnly,
    [switch]$NoBrowser,
    [switch]$NoClipboard
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

function Write-Step([string]$Message) {
    Write-Host "[NeoLabs] $Message" -ForegroundColor Cyan
}

function Require-File([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required toolkit file is missing: $RelativePath"
    }
    return $path
}

function Get-WazuhAdminPassword([string]$LinuxRoot) {
    # The dashboard human login uses the locally generated OpenSearch/Wazuh
    # `admin` password. Read it into memory without ever writing it to stdout.
    $password = (& wsl.exe --cd $LinuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_INDEXER_PASSWORD:-}"' 2>$null | Select-Object -First 1)
    if (-not $password) {
        throw 'Could not read the local Wazuh admin password from wazuh-stack/.env.'
    }
    $password = $password.Trim()
    if ($password -notmatch '^[0-9a-fA-F]{48}$') {
        throw 'The local Wazuh admin password has an unexpected format. Run the normal setup/repair path rather than exposing or regenerating credentials manually.'
    }
    return $password
}

function Copy-SecretToClipboard([string]$Secret) {
    $setClipboard = Get-Command Set-Clipboard -ErrorAction SilentlyContinue
    if ($setClipboard) {
        Set-Clipboard -Value $Secret
        return
    }

    $clip = Get-Command clip.exe -ErrorAction SilentlyContinue
    if ($clip) {
        $Secret | & clip.exe
        if ($LASTEXITCODE -eq 0) {
            return
        }
    }

    throw 'Windows clipboard support is unavailable on this workstation.'
}

$setupCmd = Require-File 'setup-windows.cmd'
$neoLabsCmd = Require-File 'neolabs.cmd'
$healthScript = Require-File 'wazuh-stack\scripts\health-check.sh'
$telemetryVerifyScript = Require-File 'wazuh-stack\scripts\verify-telemetry-pipeline.sh'
$telemetryRepairScript = Require-File 'wazuh-stack\scripts\repair-telemetry-pipeline.sh'

if ($ValidateOnly) {
    Write-Host '[OK] One-click SOC launcher contract is valid.'
    Write-Host '[OK] Setup, NeoLabs CLI, Wazuh health, telemetry verification, bounded repair and secure clipboard login support are present.'
    exit 0
}

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '       NeoLabs SOC Level 1 - Start Desk' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    throw 'WSL2 is required. Enable Windows Subsystem for Linux, install any current WSL2 distro, and enable Docker Desktop WSL integration.'
}

Write-Step 'Checking the Windows/WSL2 workstation...'
$linuxRoot = (& wsl.exe wslpath -a $Root 2>$null | Select-Object -First 1)
if (-not $linuxRoot) {
    throw 'Could not translate the toolkit folder into WSL. Move/clone the toolkit to a location visible to WSL2 and try again.'
}
$linuxRoot = $linuxRoot.Trim()

# First-run setup is only needed when the private local Wazuh configuration
# has not yet been generated. Existing secrets/configuration are preserved.
& wsl.exe --cd $linuxRoot test -f wazuh-stack/.env
if ($LASTEXITCODE -ne 0) {
    Write-Step 'First run detected. Preparing Wazuh and workstation prerequisites...'
    & $setupCmd --no-pause
    if ($LASTEXITCODE -ne 0) {
        throw 'NeoLabs Windows setup did not complete successfully. Resolve the message above and run START-NEOLABS-SOC.cmd again.'
    }
} else {
    Write-Host '[OK] Existing Wazuh configuration found; it will not be replaced.' -ForegroundColor Green
}

# A saved session is reused only when the gateway confirms it is still valid.
# Otherwise the student gets one normal interactive login prompt.
$needsLogin = $false
& wsl.exe --cd $linuxRoot bash -lc 'test -f "$HOME/.neolabs/soc/session.json"'
if ($LASTEXITCODE -ne 0) {
    $needsLogin = $true
} else {
    Write-Step 'Checking your saved NeoLabs session...'
    & $neoLabsCmd status
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[INFO] Your saved session is missing, expired, or no longer accepted.' -ForegroundColor Yellow
        $needsLogin = $true
    }
}

if ($needsLogin) {
    Write-Step 'Sign in with your assigned pod number and private NeoLabs Access Code.'
    & $neoLabsCmd login
    if ($LASTEXITCODE -ne 0) {
        throw 'NeoLabs login did not complete successfully.'
    }
}

Write-Step 'Connecting your SOC workstation to the currently authorised VCC learning surface...'
& $neoLabsCmd connect
if ($LASTEXITCODE -ne 0) {
    throw 'NeoLabs connect failed. Review the message above; no unsafe retry or pod change was attempted.'
}

Write-Step 'Waiting for Wazuh manager, indexer, dashboard and telemetry collector health...'
& wsl.exe --cd $linuxRoot bash wazuh-stack/scripts/health-check.sh --wait 600
if ($LASTEXITCODE -ne 0) {
    throw 'Wazuh did not become healthy within the allowed startup period. Review the health output above.'
}

Write-Step 'Confirming current pod/scenario status...'
& $neoLabsCmd status
if ($LASTEXITCODE -ne 0) {
    throw 'Wazuh is healthy, but the final NeoLabs runtime status check failed.'
}

# Do not tell an intern the workstation is ready merely because containers are up.
# Prove that a real, server-scoped VCC event has reached the local telemetry file,
# matched the NeoLabs Wazuh rules and become searchable in wazuh-alerts-*.
Write-Step 'Proving that your assigned-pod VCC telemetry is searchable in Wazuh...'
& wsl.exe --cd $linuxRoot bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 180
if ($LASTEXITCODE -ne 0) {
    Write-Host '[WARN] The services are running, but VCC telemetry is not searchable yet. Attempting one bounded local repair.' -ForegroundColor Yellow
    & wsl.exe --cd $linuxRoot bash wazuh-stack/scripts/repair-telemetry-pipeline.sh
    if ($LASTEXITCODE -ne 0) {
        throw 'The local Wazuh telemetry path could not be verified after one safe repair attempt. The launcher will not report READY until assigned-pod VCC telemetry is searchable.'
    }
}

$dashboardPort = (& wsl.exe --cd $linuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_DASHBOARD_PORT:-8443}"' | Select-Object -First 1)
if (-not $dashboardPort -or $dashboardPort.Trim() -notmatch '^\d{2,5}$') {
    $dashboardPort = '8443'
} else {
    $dashboardPort = $dashboardPort.Trim()
}
$dashboardUrl = "https://127.0.0.1:$dashboardPort"

$credentialCopied = $false
if (-not $NoClipboard) {
    try {
        $adminPassword = Get-WazuhAdminPassword $linuxRoot
        Copy-SecretToClipboard $adminPassword
        $credentialCopied = $true
        # Remove the plaintext variable as soon as the clipboard operation has completed.
        $adminPassword = $null
        Remove-Variable adminPassword -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[WARN] Wazuh is ready, but the admin password could not be copied to the Windows clipboard: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'SOC WORKSTATION READY' -ForegroundColor Green
Write-Host "Dashboard: $dashboardUrl"
Write-Host 'Username:  admin'
if ($credentialCopied) {
    Write-Host 'Password:  copied to your Windows clipboard - press Ctrl+V on the Wazuh login page.' -ForegroundColor Green
    Write-Host 'Security:  after signing in, copy any non-sensitive text to replace the password in your clipboard.' -ForegroundColor DarkYellow
} elseif ($NoClipboard) {
    Write-Host 'Password:  clipboard copy was disabled with -NoClipboard.' -ForegroundColor Yellow
} else {
    Write-Host 'Password:  not printed. It remains stored privately in wazuh-stack/.env as WAZUH_INDEXER_PASSWORD.' -ForegroundColor Yellow
}
Write-Host 'Verified: assigned-pod VCC telemetry is indexed and searchable in Wazuh.' -ForegroundColor Green
Write-Host 'Your pod and scenario scope remain server-controlled by NeoLabs.'
Write-Host ''

if (-not $NoBrowser) {
    Write-Step 'Opening the local Wazuh dashboard...'
    Start-Process $dashboardUrl
} else {
    Write-Host '[INFO] Browser launch skipped because -NoBrowser was supplied.'
}
