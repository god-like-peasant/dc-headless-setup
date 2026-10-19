param([ValidateSet('Apply','Restore','Status')][string]$Mode = 'Status')
$ErrorActionPreference = 'Stop'
$backup = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote\power-settings-backup.json'
$subSleep = 'SUB_SLEEP'
$setting = 'STANDBYIDLE'
$plans = @(& powercfg /getactivescheme)
$guid = [regex]::Match(($plans -join ' '), '[0-9a-fA-F-]{36}').Value
if (-not $guid) { throw 'Could not identify the active power plan.' }
if ($Mode -eq 'Status') {
  Write-Host 'Desktop Commander does not guarantee that Windows or any hotspot stays awake.'
  Write-Host "Active plan: $guid"
  Write-Host 'Inspect current sleep values with: powercfg /query'
  Write-Host 'Mobile Hotspot power saving is controlled by Windows and hardware; review Settings > Network & internet > Mobile hotspot. If a power-saving toggle is shown, Windows may turn the hotspot off to save power. Availability and behavior vary by Windows build, adapter, battery state, and external hotspot.'
  Write-Host "Backup exists: $(Test-Path $backup)"
  return
}
if ($Mode -eq 'Apply') {
  New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
  if (-not (Test-Path $backup)) {
    $ac = (& powercfg /query $guid $subSleep $setting 2>&1 | Out-String)
    $dc = $ac
    $vals = [regex]::Matches($ac, 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)|Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)')
    $nums = @([regex]::Matches($ac, 'Current (?:AC|DC) Power Setting Index:\s*0x([0-9a-fA-F]+)') | ForEach-Object { [Convert]::ToInt32($_.Groups[1].Value,16) })
    if ($nums.Count -lt 2) { throw 'Could not safely read both AC and battery sleep timeout values; no change made.' }
    @{ Scheme=$guid; AC=$nums[0]; DC=$nums[1] } | ConvertTo-Json | Set-Content -Encoding UTF8 $backup
  }
  Write-Host 'Optional action: set sleep timeout to Never on AC only; current battery timeout is left unchanged.'
  $confirm = Read-Host 'Type APPLY to apply this AC-only sleep change (requires no elevation in typical configurations)'
  if ($confirm -cne 'APPLY') { Write-Host 'No change made.'; return }
  & powercfg /change standby-timeout-ac 0
  if ($LASTEXITCODE -ne 0) { throw 'Windows rejected the power change. Restore the saved values if needed.' }
  Write-Host "Applied AC sleep timeout change. Previous values saved at $backup. Restore with -Mode Restore."
  Write-Host 'This does not disable Wi-Fi adapter power management or guarantee hotspot uptime; those controls vary by device. Change them manually only if appropriate.'
  return
}
if ($Mode -eq 'Restore') {
  if (-not (Test-Path $backup)) { throw 'No saved power settings backup exists; nothing restored.' }
  $old = Get-Content -Raw $backup | ConvertFrom-Json
  & powercfg /setacvalueindex $old.Scheme $subSleep $setting ([int]$old.AC)
  if ($LASTEXITCODE -ne 0) { throw 'Failed restoring AC timeout.' }
  & powercfg /setdcvalueindex $old.Scheme $subSleep $setting ([int]$old.DC)
  if ($LASTEXITCODE -ne 0) { throw 'Failed restoring battery timeout.' }
  & powercfg /setactive $old.Scheme
  Write-Host 'Restored the saved AC and battery sleep timeout values.'
}
