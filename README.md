# Desktop Commander Headless Setup Kit for Windows

A small Windows kit for running the **official** Desktop Commander Remote Device under the signed-in user's account. It does not expose a local unauthenticated command port and does not disable Windows security features.

## Quick installation

1. Download `dc-headless-setup-windows.zip` from the [latest release](https://github.com/god-like-peasant/dc-headless-setup/releases/latest) and extract the ZIP.
2. In File Explorer, right-click `Install-DesktopCommander.ps1` and choose **Run with PowerShell**. If Windows blocks the script, do not disable security. Open PowerShell in the extracted folder and run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-DesktopCommander.ps1`; this bypass applies to that process only.
3. If Node.js 18+ is not found, the installer offers to use `winget` to install the official Node.js LTS package scoped to the user. If unavailable, install Node.js 18+ from [nodejs.org](https://nodejs.org/), then rerun. Review any Windows package-manager prompt; the installer does not silently elevate.
4. On first authorization, the official package prints a verification URL and one-time code. Open the URL, compare the code exactly, then explicitly approve the device in the official authorization page. Never share the code. When the agent reports that it connected, return to the PowerShell window and press **Ctrl+C** once to return to the installer. If the initial command reports an exit after you interrupt it, continue only if authorization succeeded and the device appears in the official dashboard; otherwise rerun the installer.
5. The installer creates and starts a per-user Scheduled Task with **limited privileges**, set to run at sign-in. It never asks for administrator rights. Open `Status-DesktopCommander.ps1` from PowerShell to check task and connectivity status.

Only authorize a device you control. Remote tool calls execute locally with the permissions of the signed-in Windows user, so files and actions accessible to that account may be reachable through the authorized remote service.

## What is installed and how recovery works

The kit runs `npx --yes --package @wonderwhy-er/desktop-commander@latest -- desktop-commander remote`, which obtains the official package from npm. It deliberately uses the official package's latest release at startup rather than bundling an unreviewed binary; this means first start and updates require internet access and the npm package registry.

A per-user Task Scheduler task starts a hidden PowerShell supervisor at sign-in. The supervisor checks connectivity to the npm registry, starts the official agent, writes logs to `%LOCALAPPDATA%\DesktopCommanderRemote\agent.log`, and retries exited processes with increasing delays capped at ten minutes. Task Scheduler also has restart settings. This is process recovery, not a guarantee of network recovery, account validity, service availability, or continuous online status. If OAuth authorization expires or is revoked, inspect logs and rerun the installer to authorize again. Use the official `remote --logout` command only if you intentionally want to remove saved local authorization, and revoke the device separately in the official dashboard if needed.

The first authorization session is foreground and explicitly user-approved. Later launches run in the background and normally reuse the official saved session in `%USERPROFILE%\.desktop-commander-device\device.json`. Windows permissions govern access to that file; this kit does not change its ACL. Do not copy or share it.

## Connectivity and power

`Power-Settings.ps1 -Mode Status` reports guidance. The optional `-Mode Apply` saves current sleep timeout values, asks for explicit confirmation, and changes the AC sleep timeout only; `-Mode Restore` restores the saved AC and battery timeout values. Do not use if a managed device policy forbids it. The kit does not alter Wi-Fi adapter power settings because Windows driver and device controls differ.

Windows Mobile Hotspot may expose a power-saving option in **Settings > Network & internet > Mobile hotspot**. When present, review it there; Windows may turn the hotspot off to save power. The option and behavior vary by Windows version, adapter, driver, and power state. No script here changes that toggle. The agent cannot guarantee the hotspot remains active: sleep, battery depletion, Wi-Fi/hotspot hardware or driver limits, internet-provider problems, and external hotspot timeouts can all interrupt service.

## Check status, logs, and troubleshoot

Run these from PowerShell in the extracted kit folder:

```powershell
.\Status-DesktopCommander.ps1
Get-Content "$env:LOCALAPPDATA\DesktopCommanderRemote\agent.log" -Tail 80
.\Power-Settings.ps1 -Mode Status
```

If the task is not running, use Task Scheduler to inspect **Desktop Commander Remote Device**, or rerun the installer. If connectivity is unavailable, restore internet access and allow the supervisor's bounded retry to proceed. For OAuth failures, confirm the device remains authorized in the official Remote MCP dashboard; rerun the installer to pair again when requested. For more diagnostics, test the official command interactively with `npx @wonderwhy-er/desktop-commander@latest remote --debug`. Never share verification codes, logs containing sensitive data, or `device.json`.

## Uninstall

Run `Uninstall-DesktopCommander.ps1`. It removes the named per-user task and offers to delete only this kit's logs. It preserves the Desktop Commander authorization file, Node.js, and power settings. Use the official `npx @wonderwhy-er/desktop-commander@latest remote --logout` command to remove local auth, and `Power-Settings.ps1 -Mode Restore` to restore this kit's optional power change.

## Contents

- `Install-DesktopCommander.ps1` — prerequisite check, interactive authorization, and task setup.
- `Supervisor.ps1` — hidden background launch, bounded retry, and logging.
- `Status-DesktopCommander.ps1` — local task, Node, session-file-presence, and connectivity report.
- `Power-Settings.ps1` — status and reversible optional AC sleep-timeout adjustment.
- `Uninstall-DesktopCommander.ps1` — remove the task and optionally kit logs.

## Verification and limitations

The ZIP is a PowerShell source kit, not a Windows-tested executable. This build is inspected for package identity, paths, and command safety, and its archive/files can be verified on the publishing host. Windows execution, Node installation, scheduled-task behavior on a target Windows build, interactive OAuth pairing, real reconnection, and hotspot/power effects have **not** been tested on a physical Windows computer. The agent depends on the official Desktop Commander Remote MCP service and the authorized AI client.

## Sources

- Official setup documentation: https://github.com/wonderwhy-er/DesktopCommanderMCP/blob/main/src/remote-device/README.md
- Official project: https://github.com/wonderwhy-er/DesktopCommanderMCP
- Official npm package: https://www.npmjs.com/package/@wonderwhy-er/desktop-commander
