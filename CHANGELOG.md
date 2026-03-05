# Changelog

All notable user-facing changes to this project will be documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) —
internal refactors, style fixes, and maintenance commits are omitted.

---

## [Unreleased]

### Added
- `r` key in qnap-monitor: re-display last stress-test analysis report without re-running the test
- EC hardware override detection: dashboard shows `[↑EC override↑]` when IT8528 chip
  overrides software PWM (RPM significantly exceeds the fancontrol setpoint)
- Stress-test analysis report now includes total duration, sample counts per phase (IDLE/LOAD/COOLDOWN),
  and clearer Verdict messages with actionable recommendations

### Fixed
- Ghost characters in PWM curve display when percentage/temperature values change width
- Dashboard artifacts remaining on screen after analysis report overlay

## [v1.0.0] — 2026-03-05

Initial release. Full working setup for QNAP TVS-h1288X on Proxmox VE.

### Added
- `qnap-ec` kernel module (IT8528 hwmon driver) with DKMS auto-rebuild on kernel updates
- `fancontrol` configuration with temp→PWM curves for chassis and CPU fans
- `qnap-monitor`: live terminal dashboard — CPU temps, EC temps, fan RPMs, PWM bars, fan curves
- `qnap-monitor --analyze <file.csv>`: offline stress-test analysis
- `l` key: toggle CSV logging; `s` key: toggle stress-ng load; automatic IDLE/LOAD/COOLDOWN phases
- `qnap-watchdog`: systemd timer running every 5 min — alerts on high temps, fan stalls, fancontrol down
- `install.sh`: one-shot full install (driver + DKMS + fancontrol + qnap-monitor + watchdog)
- `uninstall.sh`: complete removal of all components
- Version string embedded at install time via `@VERSION@` placeholder
