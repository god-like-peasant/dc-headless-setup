# Downloads/checksum-verifies the latest kit, then launches the interactive installer.
# Run in a normal, non-administrator Windows PowerShell session.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Close this elevated window and rerun as your ordinary Windows user.' }
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$release = 'https://github.com/god-like-peasant/dc-headless-setup/releases/latest/download'
$zipName = 'dc-headless-setup-windows.zip'
$tempDir = Join-Path $env:TEMP ('dc-setup-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $tempDir $zipName
$sumPath = Join-Path $tempDir 'SHA256SUMS.txt'
$kitDir = Join-Path $env:LOCALAPPDATA 'DesktopCommanderSetup\kit'
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
try {
  Write-Host 'Downloading the latest setup package and checksum...'
  Invoke-WebRequest -UseBasicParsing -Uri "$release/$zipName" -OutFile $zipPath -TimeoutSec 120
  Invoke-WebRequest -UseBasicParsing -Uri "$release/SHA256SUMS.txt" -OutFile $sumPath -TimeoutSec 30
  $sumText = Get-Content -LiteralPath $sumPath -Raw
  $match = [regex]::Match($sumText, '(?im)^([0-9a-f]{64})\s+\*?' + [regex]::Escape($zipName) + '\s*$')
  if (-not $match.Success) { throw 'The release checksum file did not contain the expected ZIP entry. Nothing was extracted.' }
  $expected = $match.Groups[1].Value.ToUpperInvariant()
  $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToUpperInvariant()
  if ($actual -ne $expected) { throw 'The downloaded ZIP checksum does not match. Nothing was extracted.' }
  Write-Host 'ZIP checksum verified. Extracting the kit...'
  New-Item -ItemType Directory -Force -Path $kitDir | Out-Null
  Expand-Archive -LiteralPath $zipPath -DestinationPath $kitDir -Force
  $installer = Join-Path $kitDir 'Install-DesktopCommander.ps1'
  if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw 'The verified archive is missing Install-DesktopCommander.ps1.' }
  Write-Host 'Launching the installer. First device authorization requires your approval.'
  & (Join-Path $PSHOME 'powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $installer
  if ($LASTEXITCODE -ne 0) { throw "Installer child process exited with code $LASTEXITCODE. Review its output and logs." }
  Write-Host 'Bootstrap finished.'
} finally {
  Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
