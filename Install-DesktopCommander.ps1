#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$TaskName = 'Desktop Commander Remote Device'
$Root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'DesktopCommanderSetup\kit'
$Log = Join-Path $Root 'setup.log'

function Write-SetupLog([string]$Message) {
  New-Item -ItemType Directory -Force -Path $Root | Out-Null
  Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) $Message"
}
function Is-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Find-NodePath {
  $command = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $candidateRoots = @((Join-Path $env:LOCALAPPDATA 'Programs\DesktopCommanderNode'), (Join-Path $env:LOCALAPPDATA 'Programs\nodejs'), (Join-Path $env:ProgramFiles 'nodejs'))
  foreach ($candidateRoot in $candidateRoots) {
    if (Test-Path -LiteralPath $candidateRoot) {
      $found = Get-ChildItem -LiteralPath $candidateRoot -Filter 'node.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($found) { return $found.FullName }
    }
  }
  return $null
}
function Find-NpxPath([string]$NodePath) {
  if ($NodePath) {
    $candidate = Join-Path (Split-Path -Parent $NodePath) 'npx.cmd'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  $command = Get-Command npx.cmd -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  return $null
}
function Install-UserLocalNode {
  $processor = $env:PROCESSOR_ARCHITECTURE
  if ($env:PROCESSOR_ARCHITEW6432) { $processor = $env:PROCESSOR_ARCHITEW6432 }
  if (-not [Environment]::Is64BitOperatingSystem) { $arch = 'x86' }
  elseif ($processor -match '(?i)ARM64') { $arch = 'arm64' }
  else { $arch = 'x64' }
  $tempRoot = Join-Path $env:TEMP ('desktop-commander-node-' + [guid]::NewGuid().ToString('N'))
  $nodeRoot = Join-Path $env:LOCALAPPDATA 'Programs\DesktopCommanderNode'
  New-Item -ItemType Directory -Force -Path $tempRoot, $nodeRoot | Out-Null
  try {
    Write-Host 'Node.js 18+ with npm/npx is missing. Downloading the current official Node.js LTS ZIP for this user...' -ForegroundColor Yellow
    $indexResponse = Invoke-WebRequest -UseBasicParsing -Uri 'https://nodejs.org/dist/index.json' -TimeoutSec 30
    $releaseList = @($indexResponse.Content | ConvertFrom-Json)
    $release = $releaseList | Where-Object { $_.lts -and ($_.files -contains "win-$arch") } | Select-Object -First 1
    if (-not $release) { throw "The official Node.js index did not list a supported LTS build for win-$arch." }
    $version = [string]$release.version
    if ($version -notmatch '^v\d+\.\d+\.\d+$') { throw 'The official Node.js index returned an unexpected version.' }
    $zipName = "node-$version-win-$arch.zip"
    $baseUrl = "https://nodejs.org/dist/$version"
    $zipPath = Join-Path $tempRoot $zipName
    $sumsPath = Join-Path $tempRoot 'SHASUMS256.txt'
    Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/$zipName" -OutFile $zipPath -TimeoutSec 120
    Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/SHASUMS256.txt" -OutFile $sumsPath -TimeoutSec 30
    $pattern = '(?m)^([0-9a-fA-F]{64})\s+\*?' + [regex]::Escape($zipName) + '\s*$'
    $sumMatch = [regex]::Match((Get-Content -LiteralPath $sumsPath -Raw), $pattern)
    if (-not $sumMatch.Success) { throw 'Could not find the exact Node.js ZIP checksum in the official checksum file.' }
    $expectedHash = $sumMatch.Groups[1].Value.ToUpperInvariant()
    $actualHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actualHash -ne $expectedHash) { throw 'The Node.js ZIP checksum did not match. It will not be extracted.' }
    $nodeFolder = Join-Path $nodeRoot "node-$version-win-$arch"
    if (-not (Test-Path -LiteralPath (Join-Path $nodeFolder 'node.exe'))) {
      if (Test-Path -LiteralPath $nodeFolder) { Remove-Item -LiteralPath $nodeFolder -Recurse -Force }
      Expand-Archive -LiteralPath $zipPath -DestinationPath $nodeRoot -Force
    }
    foreach ($required in @('node.exe', 'npm.cmd', 'npx.cmd')) {
      if (-not (Test-Path -LiteralPath (Join-Path $nodeFolder $required))) { throw "The verified Node.js archive did not contain $required where expected." }
    }
    return (Join-Path $nodeFolder 'node.exe')
  } finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host 'Desktop Commander Remote Device setup' -ForegroundColor Cyan
Write-Host 'Installs the official remote agent for the current Windows user.'
if (Is-Administrator) { throw 'Close this elevated window and rerun as your ordinary Windows user.' }
New-Item -ItemType Directory -Force -Path $InstallRoot, $Root | Out-Null

$sourceRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$targetRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$kitFiles = @('Install-DesktopCommander.ps1','Run-Agent.ps1','Supervisor.ps1','Status-DesktopCommander.ps1','Uninstall-DesktopCommander.ps1','Power-Settings.ps1','README.md','LICENSE','AGENT_VERSION.txt','Bootstrap-DesktopCommander.ps1')
if ($sourceRoot -ne $targetRoot) {
  foreach ($fileName in $kitFiles) {
    $from = Join-Path $sourceRoot $fileName
    if (Test-Path -LiteralPath $from -PathType Leaf) { Copy-Item -LiteralPath $from -Destination (Join-Path $InstallRoot $fileName) -Force }
  }
}
foreach ($requiredFile in @('Run-Agent.ps1','Supervisor.ps1','AGENT_VERSION.txt')) {
  if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot $requiredFile) -PathType Leaf)) { throw "Required kit file is missing: $requiredFile. Re-download the complete package." }
}
$packageVersion = (Get-Content -LiteralPath (Join-Path $InstallRoot 'AGENT_VERSION.txt') -Raw).Trim()
if ($packageVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'AGENT_VERSION.txt must contain a pinned semantic version such as 0.3.0.' }
$packageSpec = "@wonderwhy-er/desktop-commander@$packageVersion"

$nodePath = Find-NodePath
$npxPath = Find-NpxPath $nodePath
if (-not $nodePath -or -not $npxPath) { $nodePath = Install-UserLocalNode; $npxPath = Find-NpxPath $nodePath }
if (-not $nodePath -or -not $npxPath) { throw 'Could not find working Node.js and npx. Install Node.js 18+ from https://nodejs.org/ and rerun.' }
$nodeVersion = (& $nodePath --version).Trim()
if ($nodeVersion -notmatch '^v?(\d+)\.' -or [int]$Matches[1] -lt 18) { throw "Node.js 18+ is required; found $nodeVersion." }
$npmPath = Join-Path (Split-Path -Parent $nodePath) 'npm.cmd'
if (-not (Test-Path -LiteralPath $npmPath)) { throw "npm.cmd was not found next to $nodePath. Install Node.js 18+ and rerun." }
$env:Path = "$(Split-Path -Parent $nodePath);$env:Path"
Write-Host "Using Node.js $nodeVersion"
Write-Host "Pinned official Desktop Commander package: $packageSpec"
$publishedVersion = (& $npmPath view $packageSpec version).Trim()
if ($LASTEXITCODE -ne 0 -or $publishedVersion -ne $packageVersion) { throw "Could not verify $packageSpec from npm. No background task was registered." }

$configPath = Join-Path $Root 'agent-config.json'
$config = [ordered]@{ NodePath = $nodePath; NpxPath = $npxPath; PackageVersion = $packageVersion; PackageSpec = $packageSpec; Updated = (Get-Date).ToString('o') }
$config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
Write-SetupLog "Setup started; Node=$nodeVersion; package=$packageSpec"
Write-Host ''
Write-Host 'FIRST-TIME / RECOVERY AUTHORIZATION' -ForegroundColor Yellow
Write-Host 'The official agent will open a separate console and show a verification URL and one-time code.'
Write-Host 'Open the URL, compare the code character-for-character, and approve only if it matches. Never share the code.'
Write-Host 'When the agent reports successful connection, press Ctrl+C in its console window. This installer will resume.'
[void](Read-Host)
$cmdExe = Join-Path $env:SystemRoot 'System32\cmd.exe'
$cmdArgs = '/d /s /c "' + '"' + $npxPath + '" --yes ' + $packageSpec + ' remote"'
$remoteProcess = Start-Process -FilePath $cmdExe -ArgumentList $cmdArgs -WindowStyle Normal -PassThru -Wait
$agentExit = $remoteProcess.ExitCode
if ($agentExit -ne 0) { Write-SetupLog "Interactive remote command exited with code $agentExit after returning to the installer." }

$sessionPath = Join-Path $HOME '.desktop-commander-device\device.json'
if (-not (Test-Path -LiteralPath $sessionPath -PathType Leaf)) { throw "No saved device authorization found at $sessionPath. No background task was created." }
try { $null = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json } catch { throw 'Saved device authorization is not valid JSON. Do not edit or share it; rerun authorization.' }
$onlineConfirmation = Read-Host 'After verifying this device is ONLINE in the official Remote MCP dashboard, type ONLINE to enable background startup'
if ($onlineConfirmation -cne 'ONLINE') { throw 'Background startup was not enabled because online status was not confirmed.' }

$supervisorPath = Join-Path $InstallRoot 'Supervisor.ps1'
$powerShellExe = Join-Path $PSHOME 'powershell.exe'
$actionArgs = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $supervisorPath + '"'
$action = New-ScheduledTaskAction -Execute $powerShellExe -Argument $actionArgs
$userName = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $userName
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $userName -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Runs the official Desktop Commander Remote Device with bounded recovery.' -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Write-SetupLog 'Per-user scheduled task registered and started with limited privileges.'
Write-Host 'Setup complete. The agent runs hidden when you sign in to Windows.' -ForegroundColor Green
Write-Host "Status script: $InstallRoot\Status-DesktopCommander.ps1"
Write-Host "Logs: $Root"
Write-Host 'If authorization is later revoked or expires, rerun this installer and approve the official flow again.'
