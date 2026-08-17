param(
    [ValidateSet('start','doctor','status','login')]
    [string]$Action = 'start',
    [switch]$ValidateOnly,
    [switch]$NoBrowser,
    [switch]$NoClipboard
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$GatewayUrl = 'https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com'
$CommonRelative = 'internal/common/Start-NeoLabsSOC.sh'

function Write-Step([string]$Message) { Write-Host "[NeoLabs] $Message" -ForegroundColor Cyan }
function Require-RepoFile([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required toolkit file is missing: $RelativePath" }
    return $path
}
function Get-LinuxRoot {
    $value = (& wsl.exe --exec wslpath -a $Root 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $value) { throw 'Could not translate the SOC toolkit folder into WSL2.' }
    return $value.Trim()
}
function Get-WazuhAdminPassword([string]$LinuxRoot) {
    $password = (& wsl.exe --cd $LinuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_INDEXER_PASSWORD:-}"' 2>$null | Select-Object -First 1)
    if (-not $password) { throw 'Could not read the private local Wazuh admin password.' }
    $password = $password.Trim()
    if ($password -notmatch '^[0-9a-fA-F]{48}$') { throw 'The local Wazuh admin password has an unexpected format.' }
    return $password
}
function Copy-SecretToClipboard([string]$Secret) {
    if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) { Set-Clipboard -Value $Secret; return }
    if (Get-Command clip.exe -ErrorAction SilentlyContinue) {
        $Secret | & clip.exe
        if ($LASTEXITCODE -eq 0) { return }
    }
    throw 'Windows clipboard support is unavailable.'
}

Require-RepoFile $CommonRelative | Out-Null
Require-RepoFile 'tools\cli.py' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\ensure-prepared.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\validate-local-rules.py' | Out-Null

if ($ValidateOnly) {
    Write-Host '[OK] Windows SOC adapter contract is valid.'
    Write-Host '[OK] Docker/WSL repair belongs only to Ensure-NeoLabsRuntime.ps1.'
    Write-Host '[OK] Post-runtime Wazuh/auth/telemetry startup is delegated to the shared Linux orchestrator.'
    exit 0
}

$linuxRoot = Get-LinuxRoot
Write-Step 'Handing off to the shared NeoLabs SOC/Wazuh startup path inside WSL2...'
$commonArgs = @($CommonRelative, $Action, '--host', 'windows', '--no-browser')
& wsl.exe --cd $linuxRoot env "NEOLABS_LAB_BASE_URL=$GatewayUrl" bash @commonArgs
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) { exit $exitCode }

if ($Action -ne 'start') { exit 0 }

$dashboardPort = (& wsl.exe --cd $linuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_DASHBOARD_PORT:-8443}"' | Select-Object -First 1)
if (-not $dashboardPort -or $dashboardPort.Trim() -notmatch '^\d{2,5}$') { $dashboardPort = '8443' } else { $dashboardPort = $dashboardPort.Trim() }
$dashboardUrl = "https://127.0.0.1:$dashboardPort"
$nightWatchUrl = "$dashboardUrl/app/dashboards#/view/neolabs-night-watch"
& wsl.exe --cd $linuxRoot test -f wazuh-stack/state/dashboard-objects.ready
$openUrl = if ($LASTEXITCODE -eq 0) { $nightWatchUrl } else { $dashboardUrl }

$adminPassword = $null
$credentialCopied = $false
try {
    $adminPassword = Get-WazuhAdminPassword $linuxRoot
    if (-not $NoClipboard) {
        try {
            Copy-SecretToClipboard $adminPassword
            $credentialCopied = $true
        } catch {
            Write-Host "[WARN] Wazuh is ready, but the admin password could not be copied to the clipboard: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "[WARN] Wazuh is ready, but the admin password could not be read: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'WINDOWS SOC DESK READY' -ForegroundColor Green
Write-Host 'Wazuh dashboard login'
Write-Host "  Dashboard: $dashboardUrl"
Write-Host '  Username:  admin'
if ($adminPassword) {
    Write-Host "  Password:  $adminPassword" -ForegroundColor Green
} else {
    Write-Host '  Password:  missing from wazuh-stack/.env (WAZUH_INDEXER_PASSWORD)' -ForegroundColor Yellow
}
if ($credentialCopied) {
    Write-Host 'Password was also copied to your Windows clipboard - press Ctrl+V on the Wazuh login page.' -ForegroundColor Green
}
$adminPassword = $null
Remove-Variable adminPassword -ErrorAction SilentlyContinue
Write-Host 'Runtime repair will be skipped on later launches while Windows/WSL2/Docker remains positively healthy.' -ForegroundColor Green

if (-not $NoBrowser) {
    Write-Step 'Opening the NeoLabs SOC dashboard...'
    Start-Process $openUrl
}

exit 0
