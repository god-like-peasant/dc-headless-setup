$ErrorActionPreference = 'Continue'
$taskName = 'Desktop Commander Remote Device'
$root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$log = Join-Path $root 'agent.log'
$supervisorLog = Join-Path $root 'supervisor.log'
Write-Host 'Desktop Commander Remote Device — local status' -ForegroundColor Cyan
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
  $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
  Write-Host "Scheduled task: $($task.State); last run: $($info.LastRunTime); last result: $($info.LastTaskResult)"
} else { Write-Host 'Scheduled task: NOT INSTALLED' -ForegroundColor Red }
$configPath = Join-Path $root 'agent-config.json'
if (Test-Path -LiteralPath $configPath) {
  try {
    $cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    Write-Host "Node: $(& ([string]$cfg.NodePath) --version 2>$null)"
    Write-Host "Pinned agent package: $($cfg.PackageSpec)"
    Write-Host "npx exists: $(Test-Path -LiteralPath ([string]$cfg.NpxPath))"
  } catch { Write-Host 'Agent configuration: invalid or unreadable' -ForegroundColor Red }
} else { Write-Host 'Agent configuration: missing' -ForegroundColor Red }
$sessionPath = Join-Path $HOME '.desktop-commander-device\device.json'
Write-Host "Saved device session present: $(Test-Path -LiteralPath $sessionPath) (never share this file)"
if (Test-Path -LiteralPath $log) {
  $item = Get-Item -LiteralPath $log
  Write-Host "Latest agent log: $($item.LastWriteTime); size $([Math]::Round($item.Length / 1KB,1)) KiB"
  $lines = @(Get-Content -LiteralPath $log -Tail 30)
  $lastGood = -1; $lastBad = -1; $lastAuth = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '(?i)Channel subscribed|Device ready|Device marked as online|Authorization successful') { $lastGood = $i }
    if ($lines[$i] -match '(?i)Channel error:|Realtime channel is not open|Device marked as offline|Device registered, but NOT reachable|IncreaseConnectionPool|connection pool') { $lastBad = $i }
    if ($lines[$i] -match '(?i)Starting device authorization flow|Requesting device code|Device code has expired|Invalid Refresh Token|Authorization required') { $lastAuth = $i }
  }
  if ($lastAuth -gt $lastGood) { Write-Host 'ATTENTION: logs suggest interactive re-authorization may be required.' -ForegroundColor Yellow }
  elseif ($lastBad -gt $lastGood) { Write-Host 'ATTENTION: the most recent channel marker is an error; inspect logs and the official dashboard.' -ForegroundColor Yellow }
  elseif ($lastGood -ge 0) { Write-Host 'Recent log tail contains a connection-ready marker. This does not prove current cloud reachability.' -ForegroundColor Green }
  else { Write-Host 'No connection-ready marker in the recent log tail; startup may still be underway.' -ForegroundColor Yellow }
} else { Write-Host 'Agent log not found yet.' }
if (Test-Path -LiteralPath $supervisorLog) { Write-Host "Supervisor log: $supervisorLog" }
Write-Host 'This checks local evidence only. Confirm Online status in the official Remote MCP dashboard.'
