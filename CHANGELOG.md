# Changelog

## Unreleased — hardening pass

- Pin the official Desktop Commander package version instead of resolving the latest package on every restart.
- Add user-local official Node.js LTS ZIP installation with checksum verification when Node/npm/npx is missing.
- Require valid saved authorization and explicit dashboard-online confirmation before enabling background startup.
- Add a dedicated hidden runner, persistent-channel error detection, bounded recovery, and capped logs.
- Improve status/uninstall behavior and preserve authorization/unrelated data by default.
- Clarify hotspot limitations, bootstrap integrity, and physical-device test boundaries.
- Add static PowerShell validation, Windows CI, and CI-gated automatic release packaging.

## v1.1.0

- Published the Windows setup kit and checksum-verified ZIP bootstrap.
- Kept first-time device authorization interactive.
