# Desktop Commander Remote Device setup. Run in the intended Windows user's session.
$ErrorActionPreference = 'Stop'
$TaskName = 'Desktop Commander Remote Device'
$Root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$Supervisor = Join-Path $PSScriptRoot 'Supervisor.ps1'
$Log = Join-Path $Root 'setup.log'

function Log([string]$Text) {
  New-Item -ItemType Directory -Force -Path $Root | Out-Null
  Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) $Text"
}
function Find-Node {
  $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $candidates = @("$env:ProgramFiles\nodejs\node.exe", "${env:ProgramFiles(x86)}\nodejs\node.exe", "$env:LOCALAPPDATA\Programs\nodejs\node.exe")
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  return $null
}

Write-Host 'Desktop Commander Remote Device setup' -ForegroundColor Cyan
Write-Host 'This installs the official remote agent for the current Windows user only.'
$node = Find-Node
if (-not $node) {
  Write-Host 'Node.js 18 or newer is required. I will try the Windows package manager (winget).' -ForegroundColor Yellow
  $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
  if (-not $winget) { throw 'Node.js is missing and winget is unavailable. Install Node.js 18+ from https://nodejs.org/ and rerun this installer.' }
  & $winget.Source install --id OpenJS.NodeJS.LTS --exact --scope user --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { throw "winget did not install Node.js (exit $LASTEXITCODE). Install Node.js 18+ manually and rerun." }
  $node = Find-Node
  if (-not $node) { throw 'Node.js installation was not found. Sign out/in or install Node.js 18+ and rerun.' }
}
$version = (& $node --version).Trim()
if ($version -notmatch '^v?(\d+)\.' -or [int]$Matches[1] -lt 18) { throw "Node.js 18+ is required; found $version." }
Write-Host "Using Node.js $version at $node"

# Confirm the official package can be resolved from npm before first execution.
Write-Host 'Checking the official npm package @wonderwhy-er/desktop-commander ...'
$npm = Get-Command npm.cmd -ErrorAction Stop
& $npm.Source view '@wonderwhy-er/desktop-commander' version | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not verify the official npm package. Check internet connectivity and rerun.' }

New-Item -ItemType Directory -Force -Path $Root | Out-Null
Log "Setup started; Node=$node; Version=$version"
Write-Host ''
Write-Host 'FIRST-TIME DEVICE AUTHORIZATION' -ForegroundColor Yellow
Write-Host 'The official agent will show a URL and one-time code. Open the URL and compare the code character-for-character before approving. Do not share the code.'
Write-Host 'The agent is from the official npm package: @wonderwhy-er/desktop-commander.'
Write-Host 'Press Enter to launch its interactive authorization now. After it reports a successful connection, press Ctrl+C once to return here and finish background setup.'
[void](Read-Host)
& $npm.Source exec --yes --package '@wonderwhy-er/desktop-commander@latest' -- desktop-commander remote
if ($LASTEXITCODE -ne 0) {
  Write-Host "The initial agent command exited with code $LASTEXITCODE. If authentication completed and the device is visible in the official dashboard, continue; otherwise rerun this installer to retry." -ForegroundColor Yellow
  Log "Initial remote command exit=$LASTEXITCODE"
}

# Use a per-user scheduled task, no elevation, no highest privileges.
$taskScript = (Resolve-Path $Supervisor).Path
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskScript`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 2) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'Runs the official Desktop Commander Remote Device for this Windows user.' -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Log 'Per-user scheduled task registered and started with limited privileges.'
Write-Host "Setup complete. Status: .\Status-DesktopCommander.ps1" -ForegroundColor Green
Write-Host "Logs: $Root\agent.log"
Write-Host 'The initial pairing is explicit; subsequent starts reuse the official saved session when still valid.'
