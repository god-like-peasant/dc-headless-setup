# Per-user supervisor. No elevated privileges; never opens a listener or remote command endpoint.
$ErrorActionPreference = 'Continue'
$Root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$Log = Join-Path $Root 'agent.log'
New-Item -ItemType Directory -Force -Path $Root | Out-Null
function Write-Log([string]$Message) {
  if ((Test-Path $Log) -and (Get-Item $Log).Length -gt 2MB) {
    Move-Item -Force $Log ($Log + '.1')
  }
  Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) $Message"
}
function Find-Node {
  $c = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  foreach ($p in @("$env:ProgramFiles\nodejs\node.exe", "${env:ProgramFiles(x86)}\nodejs\node.exe", "$env:LOCALAPPDATA\Programs\nodejs\node.exe")) { if (Test-Path $p) { return $p } }
  return $null
}
$delays = @(15, 30, 60, 120, 300, 600)
$attempt = 0
while ($true) {
  $node = Find-Node
  if (-not $node) {
    Write-Log 'Node.js unavailable; retrying in 10 minutes.'
    Start-Sleep -Seconds 600
    continue
  }
  try {
    $net = Test-NetConnection 'registry.npmjs.org' -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if (-not $net) { Write-Log 'Internet/npm registry connectivity unavailable; retrying with bounded backoff.' }
    $npm = Join-Path (Split-Path $node) 'npm.cmd'
    if (-not (Test-Path $npm)) { $npm = (Get-Command npm.cmd -ErrorAction Stop).Source }
    Write-Log 'Starting official @wonderwhy-er/desktop-commander remote agent.'
    & $npm exec --yes --package '@wonderwhy-er/desktop-commander@latest' -- desktop-commander remote *>> $Log
    $code = $LASTEXITCODE
    Write-Log "Agent process exited with code $code."
  } catch {
    Write-Log "Start failure: $($_.Exception.Message)"
  }
  $wait = $delays[[Math]::Min($attempt, $delays.Length - 1)]
  Write-Log "Restarting after $wait seconds."
  Start-Sleep -Seconds $wait
  if ($attempt -lt ($delays.Length - 1)) { $attempt++ }
}
