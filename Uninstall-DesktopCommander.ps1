$ErrorActionPreference = 'Stop'
$name = 'Desktop Commander Remote Device'
$task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
if ($task) {
  Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $name -Confirm:$false
  Write-Host 'Removed the per-user scheduled task.'
} else { Write-Host 'Scheduled task was not installed.' }
$root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
if (Test-Path $root) {
  $answer = Read-Host "Remove kit logs at $root? Enter YES to delete logs; anything else preserves them"
  if ($answer -ceq 'YES') { Remove-Item -LiteralPath $root -Recurse -Force }
}
Write-Host 'Saved Desktop Commander device authorization in your profile was preserved.'
Write-Host 'To remove authorization separately, use the official command: npx @wonderwhy-er/desktop-commander@latest remote --logout'
Write-Host 'Node.js, Windows power settings, and any other user data were not removed.'
