$ErrorActionPreference = 'Continue'
$taskName = 'Desktop Commander Remote Device'
$root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$kitRoot = Join-Path $env:LOCALAPPDATA 'DesktopCommanderSetup\kit'
Write-Host 'Removing Desktop Commander background startup. This does not revoke cloud authorization.'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
  Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 2
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host 'Removed the per-user scheduled task.'
} else { Write-Host 'Scheduled task was not installed.' }
foreach ($pidFile in @('agent.pid', 'supervisor.pid')) {
  $path = Join-Path $root $pidFile
  if (Test-Path -LiteralPath $path) {
    $parsedPid = 0
    if ([int]::TryParse((Get-Content -LiteralPath $path -Raw).Trim(), [ref]$parsedPid) -and $parsedPid -gt 0) {
      $process = Get-CimInstance Win32_Process -Filter "ProcessId = $parsedPid" -ErrorAction SilentlyContinue
      if ($process -and $process.CommandLine -and $process.CommandLine.IndexOf($kitRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $parsedPid /T /F 2>$null | Out-Null
      }
    }
  }
}
if (Test-Path -LiteralPath $root) {
  $answer = Read-Host "Remove setup logs/config at $root? Enter YES to delete them; anything else preserves them"
  if ($answer -ceq 'YES') { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}
$removeKit = Read-Host "Remove copied scripts at $kitRoot? Enter YES to delete them; anything else preserves them"
if ($removeKit -ceq 'YES' -and (Test-Path -LiteralPath $kitRoot)) { Remove-Item -LiteralPath $kitRoot -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'Saved Desktop Commander authorization was preserved.'
Write-Host 'To remove local authorization separately, use the official remote --logout command from the pinned package.'
Write-Host 'Node.js and power settings were not removed or changed by uninstall.'
