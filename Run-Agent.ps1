# Child process for the supervisor; all output is captured locally.
$ErrorActionPreference = 'Continue'
$Root = Join-Path $env:LOCALAPPDATA 'DesktopCommanderRemote'
$Log = Join-Path $Root 'agent.log'
$ConfigPath = Join-Path $Root 'agent-config.json'
New-Item -ItemType Directory -Force -Path $Root | Out-Null
try {
  $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
  $nodeDir = Split-Path -Parent ([string]$config.NodePath)
  if (-not (Test-Path -LiteralPath ([string]$config.NpxPath))) { throw 'Configured npx.cmd path no longer exists.' }
  if (-not (Test-Path -LiteralPath ([string]$config.NodePath))) { throw 'Configured node.exe path no longer exists.' }
  $env:Path = "$nodeDir;$env:Path"
  Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) Starting pinned official package $($config.PackageSpec)"
  & ([string]$config.NpxPath) --yes ([string]$config.PackageSpec) remote *>> $Log
  $code = $LASTEXITCODE
  Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) Official remote agent exited with code $code"
  exit $code
} catch {
  Add-Content -LiteralPath $Log -Value "$(Get-Date -Format o) Agent launch failure: $($_.Exception.Message)"
  exit 1
}
