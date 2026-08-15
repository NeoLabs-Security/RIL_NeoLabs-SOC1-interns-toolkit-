param(
    [ValidateSet('start','doctor','status','login','docker')]
    [string]$Action = 'start',
    [switch]$ValidateOnly,
    [switch]$NoBrowser,
    [switch]$NoClipboard
)

$ErrorActionPreference = 'Stop'
$WindowsRoot = $PSScriptRoot
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$GatewayUrl = 'https://pg1wb0sklb.execute-api.us-east-1.amazonaws.com'
$script:LinuxRoot = $null
$script:NeoLabsExitCode = 0

function Write-Step([string]$Message) { Write-Host "[NeoLabs] $Message" -ForegroundColor Cyan }
function Require-RepoFile([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required toolkit file is missing: $RelativePath" }
    return $path
}
function Get-LinuxRoot {
    $value = (& wsl.exe wslpath -a $Root 2>$null | Select-Object -First 1)
    if (-not $value) { throw 'Could not translate the SOC toolkit folder into WSL2.' }
    return $value.Trim()
}
function Invoke-NeoLabs([string[]]$CliArgs) {
    & wsl.exe --cd $script:LinuxRoot env "NEOLABS_LAB_BASE_URL=$GatewayUrl" python3 -m tools.cli @CliArgs
    $script:NeoLabsExitCode = $LASTEXITCODE
}
function Invoke-WslBash([string]$Command, [switch]$AsRoot) {
    if ($AsRoot) { & wsl.exe -u root --cd $script:LinuxRoot bash -lc $Command }
    else { & wsl.exe --cd $script:LinuxRoot bash -lc $Command }
    return $LASTEXITCODE
}
function Ensure-WslDependencies {
    Write-Step 'Checking Linux prerequisites inside WSL2...'
    Invoke-WslBash 'command -v bash >/dev/null && command -v python3 >/dev/null && command -v openssl >/dev/null && command -v curl >/dev/null && command -v git >/dev/null' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Step 'Installing missing WSL2 prerequisites...'
        $install = @'
set -e
if command -v apt-get >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y bash ca-certificates curl git openssl python3
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y bash ca-certificates curl git openssl python3
elif command -v yum >/dev/null 2>&1; then
  yum install -y bash ca-certificates curl git openssl python3
else
  echo "ERROR: unsupported WSL package manager; install bash, python3, openssl, curl and git manually." >&2
  exit 2
fi
'@
        & wsl.exe -u root --cd $script:LinuxRoot bash -lc $install
        if ($LASTEXITCODE -ne 0) { throw 'Could not install the required Linux packages inside WSL2.' }
    }

    # The indexer requires this kernel setting. On Windows we can make the WSL
    # change through the WSL root account rather than asking the student to guess
    # where sudo belongs in an internal setup script.
    $sysctl = @'
set -e
current="$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)"
if [ "${current:-0}" -lt 262144 ]; then
  sysctl -w vm.max_map_count=262144 >/dev/null
fi
'@
    & wsl.exe -u root bash -lc $sysctl
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure vm.max_map_count for the Wazuh indexer.' }

    # A Windows checkout can lose executable bits even when LF endings are correct.
    Invoke-WslBash 'find wazuh-stack/scripts -type f -name "*.sh" -exec chmod u+x {} +; chmod u+x start-neolabs-soc.sh 2>/dev/null || true' | Out-Null
}
function Get-WazuhAdminPassword {
    $password = (& wsl.exe --cd $script:LinuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_INDEXER_PASSWORD:-}"' 2>$null | Select-Object -First 1)
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

$dockerBootstrap = Join-Path $WindowsRoot 'Start-NeoLabsDocker.ps1'
Require-RepoFile 'tools\cli.py' | Out-Null
Require-RepoFile 'tools\__init__.py' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\compatibility-check.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\generate-local-secrets.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\prepare-stack.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\health-check.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\verify-telemetry-pipeline.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\repair-telemetry-pipeline.sh' | Out-Null
Require-RepoFile 'wazuh-stack\scripts\telemetry-freshness.sh' | Out-Null
if (-not (Test-Path -LiteralPath $dockerBootstrap -PathType Leaf)) { throw 'Internal Docker bootstrap is missing.' }

if ($ValidateOnly) {
    Write-Host '[OK] Root Windows SOC launcher contract is valid.'
    Write-Host '[OK] One entry point owns WSL/Docker prerequisites, first-run Wazuh preparation, NeoLabs authentication, telemetry verification and dashboard startup.'
    Write-Host '[OK] NeoLabs CLI is invoked as the tools.cli Python module to avoid script import-path failures.'
    exit 0
}

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host '       NeoLabs SOC Level 1 - Start Desk' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor DarkCyan
Write-Host ''

if ($Action -eq 'docker') {
    & $dockerBootstrap -ToolkitRoot $Root -TimeoutSeconds 180
    exit $LASTEXITCODE
}

Write-Step 'Preparing the Windows/WSL2/Docker runtime...'
& $dockerBootstrap -ToolkitRoot $Root -TimeoutSeconds 180
if ($LASTEXITCODE -ne 0) { throw 'Docker/WSL2 preparation failed.' }

$script:LinuxRoot = Get-LinuxRoot
Ensure-WslDependencies

if ($Action -eq 'login') {
    Invoke-NeoLabs @('login')
    exit $script:NeoLabsExitCode
}
if ($Action -eq 'status') {
    Invoke-NeoLabs @('status')
    exit $script:NeoLabsExitCode
}
if ($Action -eq 'doctor') {
    Invoke-NeoLabs @('doctor')
    exit $script:NeoLabsExitCode
}

Write-Step 'Checking workstation compatibility...'
& wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/compatibility-check.sh
if ($LASTEXITCODE -ne 0) { throw 'The workstation compatibility check found a blocking issue.' }

& wsl.exe --cd $script:LinuxRoot test -f wazuh-stack/.env
$firstRun = ($LASTEXITCODE -ne 0)
if ($firstRun) {
    Write-Step 'First run detected. Generating private Wazuh credentials...'
    & wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/generate-local-secrets.sh
    if ($LASTEXITCODE -ne 0) { throw 'Could not generate the private local Wazuh configuration.' }
}

& wsl.exe --cd $script:LinuxRoot test -f wazuh-stack/generated/config/wazuh_cluster/wazuh_manager.conf
$needsPreparation = ($LASTEXITCODE -ne 0)
if ($firstRun -or $needsPreparation) {
    Write-Step 'Preparing the pinned Wazuh stack. The first run can take several minutes while images/configuration are downloaded...'
    & wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/prepare-stack.sh
    if ($LASTEXITCODE -ne 0) { throw 'Wazuh stack preparation failed.' }
} else {
    Write-Host '[OK] Existing Wazuh installation/configuration found; it will be reused.' -ForegroundColor Green
}

$needsLogin = $false
& wsl.exe --cd $script:LinuxRoot bash -lc 'test -f "$HOME/.neolabs/soc/session.json"'
if ($LASTEXITCODE -ne 0) { $needsLogin = $true }
else {
    Write-Step 'Checking your saved NeoLabs session...'
    Invoke-NeoLabs @('status')
    if ($script:NeoLabsExitCode -ne 0) { $needsLogin = $true }
}
if ($needsLogin) {
    Write-Step 'Sign in with your assigned pod number and private NeoLabs Access Code.'
    Invoke-NeoLabs @('login')
    if ($script:NeoLabsExitCode -ne 0) { throw 'NeoLabs login did not complete successfully.' }
}

Write-Step 'Connecting the authorised VCC telemetry and starting Wazuh...'
Invoke-NeoLabs @('connect')
if ($script:NeoLabsExitCode -ne 0) { throw 'NeoLabs connect/Wazuh startup failed.' }

Write-Step 'Waiting for manager, indexer, dashboard and telemetry collector health...'
& wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/health-check.sh --wait 600
if ($LASTEXITCODE -ne 0) { throw 'Wazuh did not become healthy within the allowed startup period.' }

Write-Step 'Confirming current pod/scenario status...'
Invoke-NeoLabs @('status')
if ($script:NeoLabsExitCode -ne 0) { throw 'Final NeoLabs status check failed.' }

Write-Step 'Proving that assigned-pod VCC telemetry is searchable in Wazuh...'
& wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/verify-telemetry-pipeline.sh --wait 180
if ($LASTEXITCODE -ne 0) {
    Write-Host '[WARN] Telemetry is not searchable yet. Attempting one bounded local repair.' -ForegroundColor Yellow
    & wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/repair-telemetry-pipeline.sh
    if ($LASTEXITCODE -ne 0) { throw 'The local telemetry-to-indexer path could not be verified after one safe repair attempt.' }
}

Write-Step 'Checking latest-event freshness...'
& wsl.exe --cd $script:LinuxRoot bash wazuh-stack/scripts/telemetry-freshness.sh
if ($LASTEXITCODE -ne 0) { Write-Host '[WARN] Telemetry is searchable but its freshness needs review. Run START-NEOLABS-SOC.cmd doctor.' -ForegroundColor Yellow }

$dashboardPort = (& wsl.exe --cd $script:LinuxRoot bash -lc 'source wazuh-stack/.env >/dev/null 2>&1; printf "%s" "${WAZUH_DASHBOARD_PORT:-8443}"' | Select-Object -First 1)
if (-not $dashboardPort -or $dashboardPort.Trim() -notmatch '^\d{2,5}$') { $dashboardPort = '8443' } else { $dashboardPort = $dashboardPort.Trim() }
$dashboardUrl = "https://127.0.0.1:$dashboardPort"
$nightWatchUrl = "$dashboardUrl/app/dashboards#/view/neolabs-night-watch"
& wsl.exe --cd $script:LinuxRoot test -f wazuh-stack/state/dashboard-objects.ready
$savedObjectsReady = ($LASTEXITCODE -eq 0)
$openUrl = if ($savedObjectsReady) { $nightWatchUrl } else { $dashboardUrl }

$credentialCopied = $false
if (-not $NoClipboard) {
    try {
        $adminPassword = Get-WazuhAdminPassword
        Copy-SecretToClipboard $adminPassword
        $credentialCopied = $true
        $adminPassword = $null
        Remove-Variable adminPassword -ErrorAction SilentlyContinue
    } catch {
        Write-Host "[WARN] Wazuh is ready, but the admin password could not be copied to the clipboard: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'SOC WORKSTATION READY' -ForegroundColor Green
Write-Host "Dashboard: $dashboardUrl"
Write-Host 'Username:  admin'
if ($credentialCopied) { Write-Host 'Password:  copied to your Windows clipboard - press Ctrl+V on the Wazuh login page.' -ForegroundColor Green }
else { Write-Host 'Password:  remains private in wazuh-stack/.env as WAZUH_INDEXER_PASSWORD.' -ForegroundColor Yellow }
Write-Host 'Verified: assigned-pod VCC telemetry is indexed and searchable in Wazuh.' -ForegroundColor Green
Write-Host 'Troubleshooting: START-NEOLABS-SOC.cmd doctor'
Write-Host ''

if (-not $NoBrowser) {
    Write-Step 'Opening the NeoLabs SOC dashboard...'
    Start-Process $openUrl
}
