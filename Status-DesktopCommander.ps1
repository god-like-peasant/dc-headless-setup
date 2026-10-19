$taskName = 'Desktop Commander Remote Device'
$root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
Write-Host 'Desktop Commander Remote Device status'
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
  $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
  Write-Host "Task: $($task.State); last run: $($info.LastRunTime); last result: $($info.LastTaskResult)"
} else { Write-Host 'Task: not installed' }
$node = Get-Command node.exe -ErrorAction SilentlyContinue
if ($node) { Write-Host "Node: $((& $node.Source --version).Trim())" } else { Write-Host 'Node: not found on PATH' }
$session = Join-Path $HOME '.desktop-commander-device\device.json'
Write-Host "Saved device session file present: $(Test-Path $session) (do not share it)"
$internet = Test-NetConnection 'registry.npmjs.org' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
Write-Host "Internet to npm registry: $internet"
Write-Host "Logs folder: $root"
Write-Host 'This checks local task/process prerequisites only; confirm online status in the official Remote MCP dashboard.'
