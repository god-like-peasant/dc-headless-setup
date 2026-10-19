param([ValidateSet('Apply','Restore','Status')][string]$Mode = 'Status')
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$backup = Join-Path $root 'power-settings-backup.json'
$subSleep = 'SUB_SLEEP'
$setting = 'STANDBYIDLE'

$activeOutput = (& powercfg /getactivescheme 2>&1 | Out-String)
$scheme = [regex]::Match($activeOutput, '[0-9a-fA-F-]{36}').Value
if (-not $scheme) { throw 'Could not identify the active power plan.' }

function Read-SleepTimeouts([string]$Plan) {
  $output = (& powercfg /query $Plan $subSleep $setting 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { throw 'Could not safely query sleep timeout values; no change was made.' }
  $acMatch = [regex]::Match($output, '(?im)Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)')
  $dcMatch = [regex]::Match($output, '(?im)Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)')
  if (-not $acMatch.Success -or -not $dcMatch.Success) { throw 'Could not parse both AC and battery timeout values; no change was made.' }
  return @{ AC = [Convert]::ToInt32($acMatch.Groups[1].Value, 16); DC = [Convert]::ToInt32($dcMatch.Groups[1].Value, 16) }
}

if ($Mode -eq 'Status') {
  Write-Host "Active power plan: $scheme"
  $values = Read-SleepTimeouts $scheme
  Write-Host "Sleep timeout (AC): $($values.AC) seconds (0 means Never)"
  Write-Host "Sleep timeout (battery): $($values.DC) seconds (0 means Never)"
  Write-Host "Backup exists: $(Test-Path -LiteralPath $backup)"
  Write-Host 'This script does not change Wi-Fi adapter power settings or the Mobile Hotspot toggle.'
  Write-Host 'Review Settings > Network & internet > Mobile hotspot. If a Power saving switch is present, turn it off manually only if you accept the battery trade-off.'
  Write-Host 'Hotspot uptime cannot be guaranteed across sleep, battery depletion, driver failures, internet loss, or external hotspot timeouts.'
  return
}

if ($Mode -eq 'Apply') {
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  if (Test-Path -LiteralPath $backup) {
    $saved = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
    if ($saved.Scheme -notmatch '^[0-9a-fA-F-]{36}$' -or $null -eq $saved.AC -or $null -eq $saved.DC) {
      throw 'The existing power backup did not pass validation; no change was made.'
    }
    if ($saved.Scheme -ne $scheme) {
      throw "A backup exists for power plan $($saved.Scheme), but $scheme is active now. Run -Mode Restore first before applying the change to another plan."
    }
  } else {
    $values = Read-SleepTimeouts $scheme
    @{ Scheme = $scheme; AC = $values.AC; DC = $values.DC; SavedAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8
  }
  Write-Host 'Optional change: prevent Windows sleep on AC. This increases power use and heat.'
  $confirm = Read-Host 'Type APPLY to set the AC sleep timeout to Never. Anything else cancels.'
  if ($confirm -cne 'APPLY') { Write-Host 'No change made.'; return }
  & powercfg /change standby-timeout-ac 0
  if ($LASTEXITCODE -ne 0) { throw 'Windows rejected the AC sleep-timeout change. Use -Mode Restore if a backup was created.' }
  Write-Host "AC sleep timeout changed. Original settings saved at $backup. Restore with Power-Settings.ps1 -Mode Restore."
  return
}

if ($Mode -eq 'Restore') {
  if (-not (Test-Path -LiteralPath $backup)) { throw 'No saved power-settings backup exists; nothing was restored.' }
  $old = Get-Content -LiteralPath $backup -Raw | ConvertFrom-Json
  if ($old.Scheme -notmatch '^[0-9a-fA-F-]{36}$' -or $null -eq $old.AC -or $null -eq $old.DC) {
    throw 'The power backup did not pass validation; no change was made.'
  }
  & powercfg /setacvalueindex $old.Scheme $subSleep $setting ([int]$old.AC)
  if ($LASTEXITCODE -ne 0) { throw 'Failed restoring the saved AC timeout.' }
  & powercfg /setdcvalueindex $old.Scheme $subSleep $setting ([int]$old.DC)
  if ($LASTEXITCODE -ne 0) { throw 'Failed restoring the saved battery timeout.' }
  $currentOutput = (& powercfg /getactivescheme 2>&1 | Out-String)
  $currentScheme = [regex]::Match($currentOutput, '[0-9a-fA-F-]{36}').Value
  if ($currentScheme -eq $old.Scheme) {
    & powercfg /setactive $old.Scheme
    if ($LASTEXITCODE -ne 0) { throw 'Restored saved values but Windows did not reactivate the saved plan.' }
  } else {
    Write-Host "Restored values on saved plan $($old.Scheme) without changing the currently active plan $currentScheme."
  }
  Write-Host 'Restored saved AC and battery sleep timeout values.'
}
