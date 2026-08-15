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
if (-not $ToolkitRoot) { $ToolkitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

function Step([string]$m){ Write-Host "[NeoLabs AutoFix] $m" -ForegroundColor Cyan }
function Ok([string]$m){ Write-Host "[OK] $m" -ForegroundColor Green }
function Warn([string]$m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }

function Elevate([string]$cmd) {
  $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
  (Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded)).ExitCode
}

function Assert-PhysicalWindows {
  $os=$null;$cs=$null
  try{$os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop}catch{}
  try{$cs=Get-CimInstance Win32_ComputerSystem -ErrorAction Stop}catch{}
  $caption=if($os){[string]$os.Caption}else{''}
  $product=if($os){[int]$os.ProductType}else{0}
  $id="$(if($cs){$cs.Manufacturer}) $(if($cs){$cs.Model})".ToLowerInvariant()
  $vm=$false
  foreach($p in @('virtual machine','vmware','virtualbox','qemu','kvm','xen','amazon ec2','google compute engine','digitalocean','openstack','parallels','nutanix')){
    if($id.Contains($p)){$vm=$true;break}
  }
  if((($product-ne 0)-and($product-ne 1))-or($caption-match'Windows Server')-or$vm){
    throw 'NeoLabs Windows SOC requires a physical Windows 10/11 workstation. Use Ubuntu/Debian directly for VPS/VM deployments.'
  }
  Ok 'Supported physical Windows workstation detected.'
}

function Wsl-Version {
  try{
    $t=(& wsl.exe --version 2>$null|Out-String)-replace"`0",''
    if($LASTEXITCODE-eq 0 -and $t-match'(?im)^\s*WSL\s+version:\s*([0-9]+(?:\.[0-9]+){1,3})'){return[version]$Matches[1]}
  }catch{}
  $null
}
function Wsl-Healthy {
  try{& wsl.exe --status *> $null;if($LASTEXITCODE-ne 0){return$false};& wsl.exe -l -v *> $null;return($LASTEXITCODE-eq 0)}catch{return$false}
}
function Wsl-Distro {
  try{
    $raw=(& wsl.exe -l -v 2>$null|Out-String)-replace"`0",''
    $all=@()
    foreach($line in($raw-split"`r?`n")){
      if($line-match'^\s*(\*)?\s*(.+?)\s+(Running|Stopped)\s+([12])\s*$'){
        $n=$Matches[2].Trim()
        if($n-and$n-notmatch'^docker-desktop(?:-data)?$'){
          $all+=[pscustomobject]@{Name=$n;Version=[int]$Matches[4];Default=[bool]$Matches[1]}
        }
      }
    }
    $d=$all|Where-Object Default|Select-Object -First 1
    if(-not$d){$d=$all|Where-Object{$_.Version-eq 2}|Select-Object -First 1}
    if(-not$d){$d=$all|Select-Object -First 1}
    return$d
  }catch{return$null}
}
function Wsl-Update {
  Step 'Updating WSL...'
  $ok=$false
  try{& wsl.exe --update;$ok=($LASTEXITCODE-eq 0)}catch{}
  if(-not$ok){try{& wsl.exe --update --web-download;$ok=($LASTEXITCODE-eq 0)}catch{}}
  if(-not$ok){$ok=((Elevate 'wsl.exe --update; if ($LASTEXITCODE -ne 0) { wsl.exe --update --web-download; exit $LASTEXITCODE }')-eq 0)}
  if(-not$ok){throw 'WSL could not be updated automatically.'}
  & wsl.exe --shutdown *> $null
  Ok 'WSL update completed.'
}
function Ensure-Wsl {
  if(-not(Get-Command wsl.exe -ErrorAction SilentlyContinue)){
    Step 'Enabling WSL and VirtualMachinePlatform...'
    $c=@'
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
wsl.exe --install --no-distribution
exit $LASTEXITCODE
'@
    if((Elevate $c)-ne 0){throw 'Windows could not enable WSL automatically.'}
    Warn 'WSL was enabled. Restart Windows once, then rerun START-NEOLABS-SOC.cmd.'
    exit 3010
  }
  try{& wsl.exe --set-default-version 2 *> $null}catch{}
  $v=Wsl-Version
  if(-not$v-or$v-lt$MinimumWslVersion-or-not(Wsl-Healthy)){Wsl-Update;$v=Wsl-Version}
  if($v){Ok "WSL runtime: $v"}
  $d=Wsl-Distro
  if(-not$d){
    Step 'Installing Ubuntu WSL2...'
    if((Elevate 'wsl.exe --install -d Ubuntu')-ne 0){throw 'Ubuntu WSL2 could not be installed automatically.'}
    Warn 'Ubuntu was installed. Restart if requested, launch Ubuntu once to create its user, then rerun NeoLabs.'
    exit 3010
  }
  if($d.Version-ne 2){& wsl.exe --set-version $d.Name 2;if($LASTEXITCODE-ne 0){throw "Could not convert '$($d.Name)' to WSL2."};$d=Wsl-Distro}
  & wsl.exe --set-default $d.Name *> $null
  Ok "Default WSL distro: $($d.Name) (WSL2)"
  $d
}

function Docker-Cli {
  $c=Get-Command docker.exe -ErrorAction SilentlyContinue;if($c-and$c.Source){return$c.Source}
  foreach($p in @("$env:LOCALAPPDATA\Programs\DockerDesktop\resources\bin\docker.exe","$env:LOCALAPPDATA\Programs\Docker\Docker\resources\bin\docker.exe","$env:ProgramFiles\Docker\Docker\resources\bin\docker.exe")){
    if(Test-Path -LiteralPath $p -PathType Leaf){return$p}
  }
  $null
}
function Docker-Exe {
  foreach($p in @("$env:LOCALAPPDATA\Programs\DockerDesktop\Docker Desktop.exe","$env:LOCALAPPDATA\Programs\Docker\Docker\Docker Desktop.exe","$env:ProgramFiles\Docker\Docker\Docker Desktop.exe")){
    if(Test-Path -LiteralPath $p -PathType Leaf){return$p}
  }
  $null
}
function To-Version([string]$s){if($s-and$s-match'([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)'){try{return[version]$Matches[1]}catch{}};$null}
function Docker-AppVersion {
  $e=Docker-Exe
  if($e){try{$i=[Diagnostics.FileVersionInfo]::GetVersionInfo($e);foreach($s in @($i.ProductVersion,$i.FileVersion)){$v=To-Version $s;if($v){return$v}}}catch{}}
  foreach($r in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')){
    try{$x=Get-ItemProperty $r -ErrorAction SilentlyContinue|Where-Object{$_.DisplayName-eq'Docker Desktop'}|Select-Object -First 1;if($x){$v=To-Version([string]$x.DisplayVersion);if($v){return$v}}}catch{}
  }
  $null
}
function Desktop-Cli {
  if(-not$script:DockerCli){return$false}
  try{& $script:DockerCli desktop version *> $null;return($LASTEXITCODE-eq 0)}catch{return$false}
}
function Context([string]$n){try{& $script:DockerCli context inspect $n *> $null;return($LASTEXITCODE-eq 0)}catch{return$false}}
function Resolve-Context {
  if($script:DockerCli-and(Context'desktop-linux')){$script:DockerContext='desktop-linux';$env:DOCKER_CONTEXT='desktop-linux'}
  else{$script:DockerContext=$null;Remove-Item Env:DOCKER_CONTEXT -ErrorAction SilentlyContinue}
}
function Docker-Type {
  if(-not$script:DockerCli){return$null}
  try{$a=@();if($script:DockerContext){$a+=@('--context',$script:DockerContext)};$a+=@('info','--format','{{.OSType}}');$v=(&$script:DockerCli @a 2>$null|Select-Object -First 1);if($LASTEXITCODE-eq 0-and$v){return$v.Trim().ToLowerInvariant()}}catch{}
  $null
}
function Wait-Docker([int]$s){$d=(Get-Date).AddSeconds($s);do{$v=Docker-Type;if($v){return$v};Start-Sleep 2}while((Get-Date)-lt$d);$null}
function Desktop-Start([int]$t=120){
  if(Desktop-Cli){try{& $script:DockerCli desktop start --timeout $t *> $null;if($LASTEXITCODE-eq 0){return$true}}catch{}}
  $e=Docker-Exe;if($e){Start-Process -FilePath $e|Out-Null;return$true};$false
}
function Desktop-Stop {
  if(Desktop-Cli){try{& $script:DockerCli desktop stop --timeout 90 *> $null}catch{}}
}
function Desktop-Restart {
  Desktop-Stop;Start-Sleep 2;try{& wsl.exe --shutdown *> $null}catch{};Desktop-Start 150|Out-Null
}

function Docker-Update {
  $attempt=$false
  if(Desktop-Cli){try{$attempt=$true;& $script:DockerCli desktop update --quiet;Start-Sleep 5}catch{}}
  $v=Docker-AppVersion;if($v-and$v-ge$MinimumDockerDesktopVersion){return$true}
  if(Get-Command winget.exe -ErrorAction SilentlyContinue){try{$attempt=$true;& winget.exe upgrade --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent;Start-Sleep 7}catch{}}
  $script:DockerCli=Docker-Cli
  $attempt
}
function Ensure-DockerInstalled {
  $script:DockerCli=Docker-Cli
  if($script:DockerCli-or(Docker-Exe)){return}
  if(-not(Get-Command winget.exe -ErrorAction SilentlyContinue)){throw 'Docker Desktop is missing and winget is unavailable.'}
  Step 'Installing Docker Desktop...'
  & winget.exe install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements --silent
  if($LASTEXITCODE-ne 0){throw 'Docker Desktop automatic installation failed.'}
  Start-Sleep 5;$script:DockerCli=Docker-Cli
  if(-not$script:DockerCli){throw 'Docker Desktop installed but docker.exe is not available yet. Restart/sign out if requested, then rerun NeoLabs.'}
}
function Ensure-DockerVersion {
  Ensure-DockerInstalled;$script:DockerCli=Docker-Cli
  $v=Docker-AppVersion
  if($v-and$v-ge$MinimumDockerDesktopVersion){Ok "Docker Desktop version: $v";return}
  Warn "Docker Desktop must be $MinimumDockerDesktopVersion or newer for current WSL integration."
  Docker-Update|Out-Null;$v=Docker-AppVersion
  if($v-and$v-lt$MinimumDockerDesktopVersion){throw "Docker Desktop is still $v; update to $MinimumDockerDesktopVersion or newer."}
  if($v){Ok "Docker Desktop version: $v"}else{Warn 'Docker Desktop version could not be read; health checks will decide readiness.'}
}

function Settings-Path {if($env:APPDATA){Join-Path $env:APPDATA 'Docker\settings-store.json'}}
function Prop($o,[string]$n){$o.PSObject.Properties|Where-Object{$_.Name-ieq$n}|Select-Object -First 1}
function Set-Prop($o,[string]$n,$v){$p=Prop $o $n;if($p){$p.Value=$v}else{$o|Add-Member -NotePropertyName $n -NotePropertyValue $v}}
function Utf8([string]$p,[string]$s){[IO.File]::WriteAllText($p,$s,(New-Object Text.UTF8Encoding($false)))}
function Set-Integration {
  param([string]$Distro,[string]$Path='',[switch]$NoBackup)
  if(-not$Path){$Path=Settings-Path};if(-not$Path-or-not(Test-Path -LiteralPath $Path)){return$false}
  $j=(Get-Content -LiteralPath $Path -Raw)|ConvertFrom-Json;if(-not$j){throw 'Docker settings-store.json is invalid JSON.'}
  if(-not$NoBackup){$b=Join-Path $env:LOCALAPPDATA 'NeoLabs\backups';New-Item -ItemType Directory -Force $b|Out-Null;Copy-Item $Path (Join-Path $b ("docker-settings-{0}.json"-f(Get-Date -Format'yyyyMMdd-HHmmss'))) -Force}
  Set-Prop $j 'wslEngineEnabled' $true
  Set-Prop $j 'enableIntegrationWithDefaultWslDistro' $true
  $p=Prop $j 'integratedWslDistros';$old=@();if($p-and$null-ne$p.Value){$old=@($p.Value|ForEach-Object{[string]$_})}
  $list=@((@($old)+@($Distro))|Where-Object{$_-and$_-notmatch'^docker-desktop(?:-data)?$'}|Select-Object -Unique)
  Set-Prop $j 'integratedWslDistros' $list
  Utf8 $Path ($j|ConvertTo-Json -Depth 100)
  $v=(Get-Content -LiteralPath $Path -Raw)|ConvertFrom-Json
  if(-not(Prop $v 'wslEngineEnabled').Value-or-not(Prop $v 'enableIntegrationWithDefaultWslDistro').Value-or@((Prop $v 'integratedWslDistros').Value)-notcontains$Distro){throw 'Docker WSL integration settings did not persist.'}
  $true
}

function Docker-InWsl([string]$d,[string]$root){
  try{$v=(& wsl.exe --distribution $d --cd $root --exec sh -lc 'docker info --format "{{.OSType}}" 2>/dev/null' 2>$null|Select-Object -First 1);return($LASTEXITCODE-eq 0-and$v-and$v.Trim()-eq'linux')}catch{return$false}
}
function Wait-WslDocker([string]$d,[string]$r,[int]$s){$x=(Get-Date).AddSeconds($s);do{if(Docker-InWsl $d $r){return$true};Start-Sleep 2}while((Get-Date)-lt$x);$false}

function Diagnostics([string]$reason,[string]$d=''){
  $dir=Join-Path $env:LOCALAPPDATA 'NeoLabs\logs';New-Item -ItemType Directory -Force $dir|Out-Null;$p=Join-Path $dir ("runtime-{0}.txt"-f(Get-Date -Format'yyyyMMdd-HHmmss'))
  "NeoLabs runtime diagnostics`nReason: $reason`nDocker Desktop: $(Docker-AppVersion)"|Out-File $p -Encoding utf8
  foreach($pair in @(@('WSL VERSION','wsl.exe --version'),@('WSL DISTROS','wsl.exe -l -v'))){("`n=== "+$pair[0]+" ===")|Out-File $p -Append;try{Invoke-Expression $pair[1] 2>&1|Out-String|Out-File $p -Append}catch{}}
  if(Desktop-Cli){"`n=== DOCKER STATUS/LOGS ==="|Out-File $p -Append;try{& $script:DockerCli desktop status 2>&1|Out-String|Out-File $p -Append}catch{};try{& $script:DockerCli desktop logs --priority 2 --since '10m' 2>&1|Out-String|Out-File $p -Append}catch{}}
  $sp=Settings-Path;if($sp-and(Test-Path $sp)){try{$j=(Get-Content $sp -Raw)|ConvertFrom-Json;"`nWSL settings: default=$((Prop $j 'enableIntegrationWithDefaultWslDistro').Value) distros=$(@((Prop $j 'integratedWslDistros').Value)-join',')"|Out-File $p -Append}catch{}}
  if($d){try{& wsl.exe -d $d --exec sh -lc 'command -v docker; ls -l /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker 2>&1; stat -c "%n size=%s mode=%a" /mnt/wsl/docker-desktop/cli-tools/usr/bin/docker 2>&1' 2>&1|Out-String|Out-File $p -Append}catch{}}
  Warn "Diagnostic log saved to: $p";$p
}

function Ensure-Engine {
  Ensure-DockerVersion;Resolve-Context
  $t=Docker-Type;if($t-eq'linux'){Ok 'Docker Linux engine is healthy.';return}
  if($t-eq'windows'){Step 'Switching Docker to Linux containers...';if(-not(Desktop-Cli)){throw 'Docker Desktop CLI cannot switch engines.'};& $script:DockerCli desktop engine use linux *> $null;Resolve-Context;if((Wait-Docker $DaemonTimeoutSeconds)-eq'linux'){Ok 'Docker Linux engine is healthy.';return}}
  Step 'Starting/recovering Docker Linux engine...';Desktop-Start $DaemonTimeoutSeconds|Out-Null;Resolve-Context
  if((Wait-Docker $DaemonTimeoutSeconds)-eq'linux'){Ok 'Docker Linux engine is healthy.';return}
  Warn 'Docker daemon is not answering; performing one clean Desktop/WSL restart.';Desktop-Restart;Resolve-Context
  if((Wait-Docker 120)-eq'linux'){Ok 'Docker recovered after restart.';return}
  if(-not(Wsl-Healthy)){Wsl-Update;Desktop-Restart;Resolve-Context;if((Wait-Docker 120)-eq'linux'){Ok 'Docker recovered after WSL repair.';return}}
  Warn 'Applying one Docker Desktop update/recovery attempt.';Docker-Update|Out-Null;Desktop-Restart;Resolve-Context
  if((Wait-Docker 150)-eq'linux'){Ok 'Docker recovered after update.';return}
  $p=Diagnostics 'Docker Linux daemon did not recover.';throw "Docker Desktop needs attention. Diagnostic log: $p"
}

function Apply-Integration([string]$d){
  Step "Enabling Docker WSL integration for '$d'..."
  & wsl.exe --set-default $d *> $null
  Desktop-Stop;try{& wsl.exe --shutdown *> $null}catch{}
  $changed=$false;try{$changed=Set-Integration -Distro $d}catch{Warn $_.Exception.Message}
  if($changed){Ok "Docker settings explicitly include '$d'."}else{Warn 'Docker settings-store.json is not available yet; retrying with default-distro integration.'}
  Desktop-Start 150|Out-Null;Resolve-Context
  if((Wait-Docker 150)-ne'linux'){Ensure-Engine}
}
function Ensure-WslDocker($d){
  $root=(& wsl.exe --distribution $d.Name --exec wslpath -a $ToolkitRoot 2>$null|Select-Object -First 1);if(-not$root){throw 'Could not translate toolkit path into WSL2.'};$root=$root.Trim()
  if(Docker-InWsl $d.Name $root){Ok "Docker is available inside '$($d.Name)'.";return}
  Warn "Docker is healthy on Windows but '$($d.Name)' is not integrated. Repairing automatically."
  Apply-Integration $d.Name
  if(Wait-WslDocker $d.Name $root 90){Ok "Docker WSL integration is healthy for '$($d.Name)'.";return}
  Warn 'Integration still failed; applying one final Docker update + settings reassertion.'
  Docker-Update|Out-Null;$script:DockerCli=Docker-Cli;Apply-Integration $d.Name
  if(Wait-WslDocker $d.Name $root 120){Ok "Docker WSL integration recovered for '$($d.Name)'.";return}
  $p=Diagnostics "Docker healthy on Windows but unavailable inside '$($d.Name)'." $d.Name
  throw "Docker WSL integration is still blocked after automatic repair. Diagnostic log: $p"
}

function SelfTest {
  if($MinimumDockerDesktopVersion-lt[version]'4.83.0'){throw 'Minimum Docker Desktop version regressed below the WSL proxy fix.'}
  $p=Join-Path([IO.Path]::GetTempPath())("neolabs-settings-"+[guid]::NewGuid().ToString('N')+".json")
  try{
    Utf8 $p ((@{wslEngineEnabled=$false;enableIntegrationWithDefaultWslDistro=$false;integratedWslDistros=@('Debian');keep=7})|ConvertTo-Json)
    Set-Integration -Distro Ubuntu -Path $p -NoBackup|Out-Null
    $j=(Get-Content $p -Raw)|ConvertFrom-Json
    if(-not$j.wslEngineEnabled-or-not$j.enableIntegrationWithDefaultWslDistro-or@($j.integratedWslDistros)-notcontains'Ubuntu'-or@($j.integratedWslDistros)-notcontains'Debian'-or$j.keep-ne 7){throw 'Docker settings self-test failed.'}
  }finally{Remove-Item $p -Force -ErrorAction SilentlyContinue}
}

if($ValidateOnly){SelfTest;Ok 'Windows AutoFix contract/self-test passed.';Ok "Minimums: WSL $MinimumWslVersion, Docker Desktop $MinimumDockerDesktopVersion.";exit 0}
if($DaemonTimeoutSeconds-lt 20-or$DaemonTimeoutSeconds-gt 300){throw 'DaemonTimeoutSeconds must be 20..300 seconds.'}

Write-Host "`n=============================================="
Write-Host '      NeoLabs Windows Runtime AutoFix' -ForegroundColor Cyan
Write-Host "==============================================`n"
Assert-PhysicalWindows
$d=Ensure-Wsl
Ensure-Engine
Ensure-WslDocker $d
Ok 'Windows/WSL2/Docker runtime is ready for the SOC launcher.'
