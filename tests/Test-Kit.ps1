# Static repository tests; does not execute installation or change the host machine.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptFiles = @(Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1' -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
if ($scriptFiles.Count -lt 7) { throw "Expected installer, bootstrap, runner, supervisor, status, power, and uninstall scripts; found $($scriptFiles.Count)." }
foreach ($scriptFile in $scriptFiles) {
  $tokens = $null; $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    $messages = ($parseErrors | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }) -join [Environment]::NewLine
    throw "PowerShell syntax errors in $($scriptFile.FullName):$([Environment]::NewLine)$messages"
  }
}
$installer = Get-Content -LiteralPath (Join-Path $repoRoot 'Install-DesktopCommander.ps1') -Raw
$runner = Get-Content -LiteralPath (Join-Path $repoRoot 'Run-Agent.ps1') -Raw
$supervisor = Get-Content -LiteralPath (Join-Path $repoRoot 'Supervisor.ps1') -Raw
$bootstrap = Get-Content -LiteralPath (Join-Path $repoRoot 'Bootstrap-DesktopCommander.ps1') -Raw
$uninstall = Get-Content -LiteralPath (Join-Path $repoRoot 'Uninstall-DesktopCommander.ps1') -Raw
$readme = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
$page = Get-Content -LiteralPath (Join-Path $repoRoot 'index.html') -Raw
$version = (Get-Content -LiteralPath (Join-Path $repoRoot 'AGENT_VERSION.txt') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid pinned package version: $version" }
if ($installer -notmatch 'AGENT_VERSION\.txt') { throw 'Installer does not read the single source-of-truth package pin.' }
if ($installer -notmatch 'Get-FileHash' -or $installer -notmatch 'SHASUMS256\.txt') { throw 'Node.js fallback must verify the official ZIP checksum before extraction.' }
if ($installer -notmatch 'desktop-commander-device\\device\.json' -or $installer -notmatch "Read-Host 'After verifying this device is ONLINE") { throw 'Installer must require saved authorization and explicit online confirmation before scheduling.' }
if ($installer -notmatch 'RunLevel Limited' -or $installer -notmatch 'AtLogOn') { throw 'Task must be per-user and limited-privilege at logon.' }
if ($runner -notmatch '\$config\.PackageSpec' -or $runner -notmatch 'remote \*>> \$Log') { throw 'Run-Agent must use the pinned package and log output.' }
if ($supervisor -notmatch 'OfflineGraceMinutes' -or $supervisor -notmatch 'Stop-ProcessTree' -or $supervisor -notmatch 'Start-Sleep -Seconds \$delay') { throw 'Supervisor is missing bounded recovery behavior.' }
if ($supervisor -notmatch 'Channel error|Realtime channel is not open|Device marked as offline' -or $supervisor -notmatch 'Starting device authorization flow') { throw 'Supervisor needs channel-health and interactive-auth detection.' }
if ($bootstrap -notmatch 'Get-FileHash' -or $bootstrap -notmatch 'Expand-Archive' -or $bootstrap -notmatch '\$actual -ne \$expected') { throw 'Bootstrap must verify the published checksum before extraction.' }
if ($bootstrap.IndexOf('$actual -ne $expected') -gt $bootstrap.IndexOf('Expand-Archive')) { throw 'Bootstrap extraction occurs before checksum validation.' }
if ($uninstall -notmatch 'Get-CimInstance Win32_Process' -or $uninstall -notmatch 'authorization was preserved') { throw 'Uninstall must constrain process-tree termination and preserve authorization by default.' }
if ($readme -notmatch 'Extract it' -or $readme -notmatch 'first authorization is intentionally interactive') { throw 'README is missing setup and pairing explanations.' }
if ($page -notmatch 'releases/latest/download/dc-headless-setup-windows\.zip' -or $page -notmatch 'Extract All') { throw 'Landing page must point to the release ZIP and explain extraction.' }
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $repoRoot '.github\workflows\release.yml') -Raw
if ($releaseWorkflow -notmatch "workflow_run\.conclusion == 'success'" -or $releaseWorkflow -notmatch "workflow_run\.event == 'push'") { throw 'Release must require successful push CI and exclude PR CI.' }
if ($releaseWorkflow -notmatch 'workflow_run\.head_sha' -or $releaseWorkflow -notmatch '\$env:SOURCE_SHA') { throw 'Release must tag and describe the exact commit that passed CI.' }

$unsafePatterns = @('(?i)\bInvoke-Expression\b','(?i)\bEncodedCommand\b','(?i)Set-ExecutionPolicy\s+Unrestricted','(?i)New-Object\s+System\.Net\.(HttpListener|Sockets\.TcpListener)')
$productionScripts = @($scriptFiles | Where-Object { $_.Name -ne 'Test-Kit.ps1' })
foreach ($pattern in $unsafePatterns) {
  foreach ($scriptFile in $productionScripts) {
    $text = Get-Content -LiteralPath $scriptFile.FullName -Raw
    if ($text -match $pattern) { throw "Potentially unsafe pattern '$pattern' found in $($scriptFile.Name)." }
  }
}
Write-Host "PASS: parsed $($scriptFiles.Count) PowerShell files; package pin $version; checked checksum, least privilege, authorization gate, bounded recovery, uninstall and landing-page invariants."
Write-Host 'NOTE: static checks do not run Windows installation, OAuth, Task Scheduler or actual reconnection.'
