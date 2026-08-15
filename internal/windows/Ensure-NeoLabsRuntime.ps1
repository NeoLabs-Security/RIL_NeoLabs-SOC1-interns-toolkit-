param(
    [switch]$ValidateOnly,
    [string]$ToolkitRoot = ''
)

$ErrorActionPreference = 'Stop'
if (-not $ToolkitRoot) {
    $ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
}

$TestScript = Join-Path $PSScriptRoot 'Test-NeoLabsDockerRuntime.ps1'
$RepairScript = Join-Path $PSScriptRoot 'Repair-NeoLabsRuntime.ps1'
$BackendScript = Join-Path $PSScriptRoot 'Recover-DockerDesktopBackend.ps1'

function Write-Step([string]$Message) { Write-Host "[NeoLabs Runtime] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }

foreach ($path in @($TestScript, $RepairScript, $BackendScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required Windows runtime helper is missing: $path" }
}

function Invoke-Helper([string]$Path, [string[]]$Arguments = @()) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    return $LASTEXITCODE
}

function Test-RuntimeReady {
    return ((Invoke-Helper $TestScript) -eq 0)
}

function Ensure-WslSocPrerequisites {
    Write-Step 'Verifying the small Linux prerequisite set inside the selected WSL2 distro...'
    $linuxRoot = (& wsl.exe --exec wslpath -a $ToolkitRoot 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -ne 0 -or -not $linuxRoot) { throw 'Could not translate the NeoLabs toolkit path into WSL2.' }
    $linuxRoot = $linuxRoot.Trim()

    $check = 'command -v bash >/dev/null && command -v python3 >/dev/null && command -v openssl >/dev/null && command -v curl >/dev/null && command -v git >/dev/null'
    & wsl.exe --cd $linuxRoot bash -lc $check
    if ($LASTEXITCODE -ne 0) {
        Write-Step 'Installing missing WSL2 userland prerequisites once...'
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
  echo "ERROR: unsupported WSL package manager" >&2
  exit 2
fi
'@
        & wsl.exe -u root --cd $linuxRoot bash -lc $install
        if ($LASTEXITCODE -ne 0) { throw 'Could not install the required Linux packages inside WSL2.' }
    }

    $kernel = @'
set -e
current="$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)"
if [ "${current:-0}" -lt 262144 ]; then
  sysctl -w vm.max_map_count=262144 >/dev/null
fi
'@
    & wsl.exe -u root bash -lc $kernel
    if ($LASTEXITCODE -ne 0) { throw 'Could not configure vm.max_map_count for Wazuh inside WSL2.' }

    & wsl.exe --cd $linuxRoot bash -lc 'find wazuh-stack/scripts internal/common -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod u+x {} + 2>/dev/null || true'
    Write-Ok 'WSL2 SOC prerequisites are ready.'
}

if ($ValidateOnly) {
    foreach ($path in @($TestScript, $RepairScript, $BackendScript)) {
        $code = Invoke-Helper $path @('-ValidateOnly')
        if ($code -ne 0) { throw "Runtime helper validation failed: $path" }
    }
    Write-Ok 'Single Windows runtime authority contract is valid.'
    exit 0
}

# One state machine owns all Windows runtime decisions. The root CMD and SOC
# layer never independently restart Docker or reinterpret readiness.
Write-Step 'Checking the existing Windows/WSL2/Docker runtime...'
if (Test-RuntimeReady) {
    Write-Ok 'Existing Windows runtime is healthy; no repair/restart is needed.'
    Ensure-WslSocPrerequisites
    exit 0
}

Write-Step 'Runtime is not ready. Running the primary non-destructive AutoFix once...'
$repairExit = Invoke-Helper $RepairScript @('-ToolkitRoot', $ToolkitRoot)
if ($repairExit -eq 3010) { exit 3010 }
if (Test-RuntimeReady) {
    Write-Ok 'Windows runtime is healthy after primary AutoFix.'
    Ensure-WslSocPrerequisites
    exit 0
}

Write-Warn 'Primary AutoFix did not produce a positively confirmed runtime. Running one deeper Docker Desktop backend recovery.'
$backendExit = Invoke-Helper $BackendScript
if ($backendExit -eq 0 -and (Test-RuntimeReady)) {
    Write-Ok 'Windows runtime recovered after Docker Desktop backend recovery.'
    Ensure-WslSocPrerequisites
    exit 0
}

# A backend recycle can restore the Linux engine while leaving the selected user
# distro integration stale. Give the primary integration repair exactly one final
# pass, then decide only from the positive end-to-end runtime test.
Write-Step 'Applying one final WSL integration reconciliation pass...'
$repairExit = Invoke-Helper $RepairScript @('-ToolkitRoot', $ToolkitRoot)
if ($repairExit -eq 3010) { exit 3010 }
if (Test-RuntimeReady) {
    Write-Ok 'Windows/WSL2/Docker runtime is fully reachable.'
    Ensure-WslSocPrerequisites
    exit 0
}

throw 'NeoLabs could not establish a positively verified Windows/WSL2/Docker runtime after the bounded repair sequence. Use the newest files in %LOCALAPPDATA%\NeoLabs\logs for operator review; do not factory-reset Docker or unregister WSL.'
