# Security policy and threat model

## Scope

This repository contains PowerShell source and a bootstrap for installing the official Desktop Commander Remote Device on a personal Windows computer. It is not the upstream remote relay or an authentication provider.

## Privilege model

- Run the installer as the ordinary intended Windows user, not as Administrator.
- The scheduled task uses an interactive user logon and limited privileges. It starts at sign-in, not before a user session exists.
- The wrapper does not expose a local TCP/HTTP listener and does not create a passwordless remote endpoint.
- Agent commands run with the current user's normal Windows permissions. Treat authorization as potentially broad access to that user's files and commands.
- Initial device authorization requires a visible, explicit human action. Background code never approves an authorization code.

## Secrets and logs

- Never commit or share the file %USERPROFILE%\.desktop-commander-device\device.json, browser cookies, device codes, OAuth tokens, or screenshots containing them.
- Scripts write operational logs and non-secret path/version config under %LOCALAPPDATA%\DesktopCommanderRemote.
- Review logs before sharing; upstream diagnostics may include local paths or environment details.
- Uninstall preserves official authorization by default. Revoke the device from the official dashboard when you no longer trust that computer.

## Downloads and supply chain

- The bootstrap verifies the downloaded ZIP against SHA256SUMS.txt before extracting. The checksum detects corrupt or mismatched downloads; it is not a detached signature and does not protect against a malicious change to both the release and checksum.
- Node.js user-local installation uses the official nodejs.org download and checksum list. TLS and SHA-256 are used; this is not independent signature verification.
- The Desktop Commander version pin lives in AGENT_VERSION.txt. Bump it only after reviewing upstream changes, updating tests, and publishing a new kit release. Do not use unpinned latest-package resolution for unattended restarts.
- The GitHub Pages site and release assets are public. Do not place credentials or private project data here.

## Known limits

- A local supervisor can recover from exited or persistently errored processes, but cannot ensure internet, cloud service, valid authorization, Wi-Fi, or external hotspot availability.
- The supervisor detects known error text in logs; upstream message changes may require updating its markers.
- If authorization expires/revokes or browser approval is required, human intervention remains necessary.
- Power-management and Mobile Hotspot controls vary by Windows version, adapter, and driver. No unconditional hotspot uptime is promised.
- CI runs syntax/static checks, not real-world end-to-end tests on physical Windows hardware.

## Reporting

Report security issues privately to the repository owner before disclosing exploit details publicly. Never include a real device token, saved auth file, or verification code in an issue.
