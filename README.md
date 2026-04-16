# Invoke-BenignExploitSim

A cross-platform benign exploit simulation project for SIEM, EDR, and native OS telemetry validation on Windows and Linux.

This repository is built for authorized detection engineering, lab validation, tabletop exercises, and controlled purple-team style testing. Both platform implementations generate telemetry aligned with real adversary behaviors while intentionally avoiding destructive actions, persistence, privilege escalation, credential access, and routable command-and-control traffic.

## Platform Layout

- [`windows/`](./windows/) - PowerShell implementation for Windows telemetry validation
- [`linux/`](./linux/) - Bash implementation for Linux telemetry validation

Each platform is a first-class implementation with its own entrypoint, documentation, and platform-specific internals.

## Shared Design Principles

- Benign, explainable, and auditable behavior
- No persistence by default outside optional retained logs
- No privilege escalation or secret collection
- No routable network egress for simulated beaconing; `.invalid` is enforced
- Per-technique or per-group controls for safer validation runs
- Independent technique execution so one failure does not stop the full simulation

## Quick Start

Windows:

```powershell
.\windows\Invoke-BenignExploitSim.ps1
```

Linux:

```bash
./linux/Invoke-BenignExploitSim.sh
```

## Platform Guides

- Windows guide: [`windows/README.md`](./windows/README.md)
- Linux guide: [`linux/README.md`](./linux/README.md)

## Repository Structure

- `windows/Invoke-BenignExploitSim.ps1` - Windows entrypoint
- `windows/README.md` - Windows usage, safety, and ATT&CK guidance
- `linux/Invoke-BenignExploitSim.sh` - Linux entrypoint
- `linux/lib/` - Linux helper modules and technique groups
- `linux/tests/` - Linux Bash test harness
- `linux/README.md` - Linux usage, safety, and telemetry guidance

## Disclaimer

This repository is intended for defensive validation and authorized testing only. Operators are responsible for ensuring use complies with internal policy, monitoring expectations, and change-control requirements.
