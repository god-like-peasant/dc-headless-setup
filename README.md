# Desktop Commander Headless Setup Kit for Windows

A free, source-included Windows kit for running the **official** Desktop Commander Remote Device under the signed-in user's account. It does not expose an unauthenticated local command port, request administrator privileges, or disable Windows security features.

## Setup

1. On the target Windows computer, open the [setup page](https://god-like-peasant.github.io/dc-headless-setup/).
2. Download the setup ZIP and extract it using Windows File Explorer.
3. In the extracted folder, right-click Install-DesktopCommander.ps1 and choose **Run with PowerShell**. Do not run the setup elevated as Administrator.
4. The installer checks for Node.js 18+. If Node and npm/npx are missing, it downloads the current official Node.js LTS Windows ZIP into the current user's profile, verifies its SHA-256 against the official SHASUMS256.txt, and checks that node.exe, npm.cmd, and npx.cmd exist. It does not require a machine-wide install or elevation for this fallback.
5. It verifies a pinned official Desktop Commander package version in npm. The version is pinned in AGENT_VERSION.txt; do not change that pin without reviewing upstream changes, running tests, and issuing a new kit release.
6. On first pairing, the official agent shows a verification URL and one-time code. Open the URL, compare the code character-for-character, and approve only if it matches. Never share the code. After the agent reports successful connection, press **Ctrl+C once** to return to the installer. Confirm the device shows **Online** in the official Remote MCP dashboard, then type ONLINE in the installer.
7. The installer copies required scripts to %LOCALAPPDATA%\DesktopCommanderSetup\kit, writes non-secret configuration under %LOCALAPPDATA%\DesktopCommanderRemote, and creates a per-user Scheduled Task with **limited privileges** to start the hidden supervisor at Windows sign-in.

The first authorization is intentionally interactive. If saved authorization expires or is revoked, a background process cannot approve OAuth for you. Rerun the installer and complete authorization again.

## What is installed

- Install-DesktopCommander.ps1: checks prerequisites and package version, performs interactive pairing, saves non-secret configuration, and registers the per-user startup task.
- Run-Agent.ps1: launches the pinned official remote agent and captures output locally.
- Supervisor.ps1: runs hidden, detects agent exits, uses bounded exponential process restart, detects persistent known channel-error markers without a later recovery marker, and restarts an agent after a 15-minute failure window. It also bounds the log and recognizes cases likely to require interactive authorization.
- Status-DesktopCommander.ps1: reports local task, binary/config/session presence, recent log markers and connectivity prerequisites. It does not claim that an old success marker proves current cloud reachability.
- Power-Settings.ps1: reports power settings by default; optionally applies a reversible AC sleep-timeout change.
- Uninstall-DesktopCommander.ps1: removes the scheduled task and offers to remove kit logs/config and copied scripts, while preserving authorization and unrelated data by default.
- Bootstrap-DesktopCommander.ps1: optional helper that downloads the latest release ZIP, verifies SHA-256 before extraction, then starts the installer.

## Recovery model and limitations

The official remote agent has its own connection recovery logic. The local supervisor adds:
1. Automatic startup at Windows sign-in.
2. Bounded restart delays if the agent process exits.
3. Detection of known remote channel error markers that persist for 15 minutes without a subsequent healthy marker.
4. Detection of apparent interactive authorization prompts that cannot be completed safely by a hidden task.
5. Local logs and status information.

This is best-effort recovery, **not a guarantee of always-online operation**. Internet outages, expired/revoked authorization, service incidents, sleep, Windows updates, and device/driver issues cannot all be fixed automatically. The supervisor does not bypass OAuth or approve a device unattended.

Logs and non-secret configuration live in %LOCALAPPDATA%\DesktopCommanderRemote. The saved authorization file is maintained by the official agent under %USERPROFILE%\.desktop-commander-device\device.json. Do not share or copy it. Remote tool calls run locally with the current Windows user's permissions, so files and actions available to that user may be reachable through the authorized service.

## Wi-Fi, sleep, and hotspots

Run these commands in PowerShell from the extracted kit folder:

    .\Status-DesktopCommander.ps1
    .\Power-Settings.ps1 -Mode Status
    .\Power-Settings.ps1 -Mode Apply
    .\Power-Settings.ps1 -Mode Restore

Apply requests explicit confirmation before setting **AC sleep timeout** to Never; the battery timeout remains unchanged and original AC/battery values are saved first. Restore restores the saved values. Staying awake increases power use and heat.

The kit does not change Wi-Fi adapter driver settings or automatically manipulate Windows Mobile Hotspot's platform-specific power toggle. Review **Settings > Network & internet > Mobile hotspot** and turn off Power saving if your Windows version exposes it and you accept the battery trade-off. Windows, a Wi-Fi driver, a depleted battery, sleep, an Internet provider, or an external hotspot can still interrupt connectivity. No tool can guarantee an always-on hotspot in every environment.

## Diagnostics

- Run .\Status-DesktopCommander.ps1.
- Read agent output with Get-Content "$env:LOCALAPPDATA\DesktopCommanderRemote\agent.log" -Tail 80.
- Read supervisor decisions with Get-Content "$env:LOCALAPPDATA\DesktopCommanderRemote\supervisor.log" -Tail 80.
- Verify device status in the [official Remote MCP dashboard](https://mcp.desktopcommander.app/).
- If re-authorization is required, rerun the installer and complete browser pairing; do not share device.json.

## Uninstall and rollback

Run .\Uninstall-DesktopCommander.ps1. It removes the per-user Scheduled Task and offers separate choices for deleting kit logs/config and copied installer scripts. Saved authorization, Node.js, and power settings are preserved. If you applied the optional AC sleep-timeout change, run .\Power-Settings.ps1 -Mode Restore before removing the scripts. Use the official remote --logout command from the pinned package only if you intentionally want to remove local authorization; revoke the device separately in the official dashboard if appropriate.

## Free/public links

- Website: https://god-like-peasant.github.io/dc-headless-setup/
- Latest release: https://github.com/god-like-peasant/dc-headless-setup/releases/latest
- Direct ZIP: https://github.com/god-like-peasant/dc-headless-setup/releases/latest/download/dc-headless-setup-windows.zip
- Source: https://github.com/god-like-peasant/dc-headless-setup
- Official upstream source: https://github.com/wonderwhy-er/DesktopCommanderMCP
- Official npm package: https://www.npmjs.com/package/@wonderwhy-er/desktop-commander

## Validation boundaries

The Windows CI workflow checks PowerShell syntax, static safety/recovery invariants, package version pinning, and landing-page links. After successful CI on main, a release workflow archives the tested source and calculates a checksum. Static CI **does not** establish that authorization, Task Scheduler behavior, process-tree termination, real remote reconnection, or hotspot behavior passed an end-to-end test on physical Windows hardware.
