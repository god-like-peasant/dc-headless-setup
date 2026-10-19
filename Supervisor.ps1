# Hidden per-user supervisor: bounded restart and stuck-channel detection.
$ErrorActionPreference = 'Continue'
$Root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$Log = Join-Path $Root 'agent.log'
$PreviousLog = Join-Path $Root 'agent.previous.log'
$SupervisorLog = Join-Path $Root 'supervisor.log'
$Runner = Join-Path $PSScriptRoot 'Run-Agent.ps1'
$ConfigPath = Join-Path $Root 'agent-config.json'
$Delays = @(15, 30, 60, 120, 300, 600)
$Attempt = 0
$OfflineGraceMinutes = 15
$AuthGraceMinutes = 4
$StartupGraceMinutes = 10
$LogLimitBytes = 8388608
New-Item -ItemType Directory -Force -Path $Root | Out-Null
Set-Content -LiteralPath (Join-Path $Root 'supervisor.pid') -Value $PID -Encoding ASCII

function Write-SupervisorLog([string]$Message) { Add-Content -LiteralPath $SupervisorLog -Value "$(Get-Date -Format o) $Message" }
function Stop-ProcessTree([int]$ProcessId) {
  if ($ProcessId -gt 0) { & "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>$null | Out-Null }
}
function Get-TailLines {
  if (Test-Path -LiteralPath $Log) { return @(Get-Content -LiteralPath $Log -Tail 300 -ErrorAction SilentlyContinue) }
  return @()
}
function Get-MarkerIndexes([string[]]$Lines) {
  $good = -1; $bad = -1; $auth = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '(?i)Channel subscribed|Device ready|Device marked as online|Authorization successful') { $good = $i }
    if ($Lines[$i] -match '(?i)Channel error:|Realtime channel is not open|Device marked as offline|Device registered, but NOT reachable|IncreaseConnectionPool|connection pool') { $bad = $i }
    if ($Lines[$i] -match '(?i)Starting device authorization flow|Requesting device code|Device code has expired|Invalid Refresh Token|Authorization required') { $auth = $i }
  }
  return @{ Good = $good; Bad = $bad; Auth = $auth }
}

while ($true) {
  if (-not (Test-Path -LiteralPath $Runner) -or -not (Test-Path -LiteralPath $ConfigPath)) {
    Write-SupervisorLog 'Required runner/config missing; retrying in 10 minutes.'
    Start-Sleep -Seconds 600
    continue
  }
  if (Test-Path -LiteralPath $Log) { try { Move-Item -LiteralPath $Log -Destination $PreviousLog -Force -ErrorAction Stop } catch {} }
  Set-Content -LiteralPath $Log -Value "$(Get-Date -Format o) New supervised agent session"
  $agentProcess = $null
  $restartReason = 'agent process exited'
  $sessionStart = Get-Date
  $offlineSince = $null
  $authSince = $null
  $healthySeen = $false
  try {
    $powerShell = Join-Path $PSHOME 'powershell.exe'
    $runnerArgs = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $Runner + '"'
    Write-SupervisorLog 'Launching Run-Agent.ps1 hidden.'
    $agentProcess = Start-Process -FilePath $powerShell -ArgumentList $runnerArgs -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath (Join-Path $Root 'agent.pid') -Value $agentProcess.Id -Encoding ASCII
    while (-not $agentProcess.HasExited) {
      Start-Sleep -Seconds 15
      try { $agentProcess.Refresh() } catch {}
      if ($agentProcess.HasExited) { break }
      if ((Test-Path -LiteralPath $Log) -and (Get-Item -LiteralPath $Log).Length -gt $LogLimitBytes) {
        $restartReason = 'agent log reached the 8 MiB safety limit'
        Write-SupervisorLog $restartReason
        Stop-ProcessTree $agentProcess.Id
        break
      }
      $markers = Get-MarkerIndexes (Get-TailLines)
      if ($markers.Good -gt $markers.Bad) {
        $healthySeen = $true; $offlineSince = $null; $authSince = $null; $Attempt = 0
      } elseif ($markers.Bad -gt $markers.Good) {
        if (-not $offlineSince) { $offlineSince = Get-Date }
        if (((Get-Date) - $offlineSince).TotalMinutes -ge $OfflineGraceMinutes) {
          $restartReason = "remote channel error persisted without a later recovery marker for $OfflineGraceMinutes minutes"
          Write-SupervisorLog $restartReason
          Stop-ProcessTree $agentProcess.Id
          break
        }
      }
      if ($markers.Auth -gt $markers.Good) {
        if (-not $authSince) { $authSince = Get-Date }
        if (((Get-Date) - $authSince).TotalMinutes -ge $AuthGraceMinutes) {
          $restartReason = 'interactive re-authorization appears required; the hidden supervisor cannot approve OAuth'
          Write-SupervisorLog $restartReason
          Stop-ProcessTree $agentProcess.Id
          break
        }
      } else { $authSince = $null }
      if (-not $healthySeen -and (((Get-Date) - $sessionStart).TotalMinutes -ge $StartupGraceMinutes)) {
        $restartReason = "no connection-ready marker appeared within $StartupGraceMinutes minutes"
        Write-SupervisorLog $restartReason
        Stop-ProcessTree $agentProcess.Id
        break
      }
    }
    if ($agentProcess.HasExited) { Write-SupervisorLog "Agent runner exited with code $($agentProcess.ExitCode)." }
  } catch {
    $restartReason = "Supervisor start/monitor error: $($_.Exception.Message)"
    Write-SupervisorLog $restartReason
    if ($agentProcess) { Stop-ProcessTree $agentProcess.Id }
  }
  $delay = $Delays[[Math]::Min($Attempt, $Delays.Length - 1)]
  Write-SupervisorLog "Restarting in $delay seconds; reason: $restartReason"
  Start-Sleep -Seconds $delay
  if ($Attempt -lt ($Delays.Length - 1)) { $Attempt++ }
}
