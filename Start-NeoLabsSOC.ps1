param(
    [switch]$ValidateOnly,
    [switch]$NoBrowser
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

$setupCmd = Require-File 'setup-windows.cmd'
$neoLabsCmd = Require-File 'neolabs.cmd'
$healthScript = Require-File 'wazuh-stack\scripts\health-check.sh'

if ($ValidateOnly) {
    Write-Host '[OK] One-click SOC launcher contract is valid.'
    Write-Host '[OK] setup-windows.cmd, neolabs.cmd and health-check.sh are present.'
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

$dashboardPort = (& wsl.exe --cd $linuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_DASHBOARD_PORT:-8443}"' | Select-Object -First 1)
if (-not $dashboardPort -or $dashboardPort.Trim() -notmatch '^\d{2,5}$') {
    $dashboardPort = '8443'
} else {
    $dashboardPort = $dashboardPort.Trim()
}
$dashboardUrl = "https://127.0.0.1:$dashboardPort"

Write-Host ''
Write-Host 'SOC WORKSTATION READY' -ForegroundColor Green
Write-Host "Dashboard: $dashboardUrl"
Write-Host 'Your pod and scenario scope remain server-controlled by NeoLabs.'
Write-Host ''

if (-not $NoBrowser) {
    Write-Step 'Opening the local Wazuh dashboard...'
    Start-Process $dashboardUrl
} else {
    Write-Host '[INFO] Browser launch skipped because -NoBrowser was supplied.'
}
