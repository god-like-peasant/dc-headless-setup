# Downloads, verifies, extracts, and starts the Desktop Commander setup kit.
# Run as the intended Windows user in a normal (non-elevated) PowerShell session.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'For least privilege, close this elevated PowerShell and rerun the bootstrap as your ordinary Windows user.'
}

# Windows PowerShell 5.1 may need TLS 1.2 explicitly for current HTTPS services.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$release = 'https://github.com/god-like-peasant/dc-headless-setup/releases/latest/download'
$zipName = 'dc-headless-setup-windows.zip'
$zipUrl = "$release/$zipName"
$sumUrl = "$release/SHA256SUMS.txt"
$kitDir = Join-Path $env:LOCALAPPDATA 'DesktopCommanderSetup\kit'
$tempDir = Join-Path $env:TEMP ('dc-setup-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempDir $zipName
$sumPath = Join-Path $tempDir 'SHA256SUMS.txt'

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
try {
  Write-Host 'Downloading the latest setup kit and checksum...'
  Invoke-WebRequest -UseBasicParsing -Uri $zipUrl -OutFile $zipPath
  Invoke-WebRequest -UseBasicParsing -Uri $sumUrl -OutFile $sumPath

  $sumText = Get-Content -LiteralPath $sumPath -Raw
  $match = [regex]::Match($sumText, '(?im)^([0-9a-f]{64})\s+\*?' + [regex]::Escape($zipName) + '\s*$')
  if (-not $match.Success) { throw 'The release checksum file did not contain the expected ZIP entry. No files were extracted.' }
  $expected = $match.Groups[1].Value.ToUpperInvariant()
  $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToUpperInvariant()
  if ($actual -ne $expected) { throw 'The downloaded ZIP checksum did not match the release checksum. No files were extracted.' }

  Write-Host 'Checksum verified. Extracting the kit...'
  New-Item -ItemType Directory -Force -Path $kitDir | Out-Null
  Expand-Archive -LiteralPath $zipPath -DestinationPath $kitDir -Force
  $installer = Join-Path $kitDir 'Install-DesktopCommander.ps1'
  if (-not (Test-Path -LiteralPath $installer)) { throw 'The archive is missing Install-DesktopCommander.ps1.' }

  Write-Host 'Launching the installer. The first authorization is intentionally interactive.'
  Write-Host 'Compare the one-time code on this computer with the official browser page before approving.'
  $powerShellExe = (Get-Process -Id $PID).Path
  & $powerShellExe -NoProfile -ExecutionPolicy Bypass -File $installer
  if ($LASTEXITCODE -ne 0) { throw "Installer process exited with code $LASTEXITCODE." }
  Write-Host 'Bootstrap finished. The per-user task is configured to start the agent at Windows sign-in.' -ForegroundColor Green
}
finally {
  Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
