# Invoke-BenignExploitSim

A set of benign exploit simulation tools for SIEM, EDR, and native OS telemetry validation across Windows and Linux environments.

This project is built for authorized detection engineering, lab validation, tabletop exercises, and controlled purple-team style testing. It generates telemetry consistent with real adversary TTPs mapped to MITRE ATT&CK while avoiding destructive behavior, persistence, privilege escalation, credential access, and routable command-and-control traffic.

Its primary use case is log-centric validation on Windows and Linux systems, especially where defenders want to maximize signal in native telemetry sources and controlled command execution without introducing destructive or persistent behavior.

## Platform Variants

- Windows: [`Invoke-BenignExploitSim_v4.3.3.ps1`](./Invoke-BenignExploitSim_v4.3.3.ps1)
- Linux: [`Invoke-BenignExploitSim_Linux_v1.sh`](./Invoke-BenignExploitSim_Linux_v1.sh)

The Windows variant remains PowerShell-first and focused on Windows-native telemetry such as Security `4688`, PowerShell `4103` and `4104`, WMI-Activity Operational, DNS Client Operational, AMSI, and BITS.

The Linux variant is Bash-first, optimized for Ubuntu/RHEL-family servers and VMs, auto-detects container context and runtime markers, and stays non-root by default with optional root-only enrichments behind an explicit flag. Its Linux-specific usage and safety model are documented in [`README_Linux.md`](./README_Linux.md).

## Current Version

- Script version: `4.3.3`
- State: runtime-tested revision with non-domain skip fixes and safer backup software discovery invocation
- Technique groups: `7`
- Executable technique functions: `51`
- Distinct MITRE ATT&CK IDs covered: `35`

## What This Tool Does

`Invoke-BenignExploitSim_v4.3.3.ps1` generates defender-relevant telemetry across seven ATT&CK-aligned technique groups:

- `Discovery`
- `Execution`
- `Collection`
- `C2`
- `LOLBin`
- `Scripting`
- `Enumeration`

The script is designed to simulate suspicious-looking but non-malicious behavior that security teams can use to validate:

- Logging pipelines
- SIEM detection coverage
- EDR visibility
- Alert routing and enrichment
- Analyst triage workflows
- Detection tuning in regulated or change-controlled environments

## Core Design Constraints

The project is intentionally opinionated about safety and auditability:

1. Zero persistent disk artifacts in default execution. No files are intentionally retained, no registry is modified, no scheduled tasks are created, and no services are installed. The only intentional persistent artifact path is `-KeepLog` used with `-LogPath`.
2. No routable network activity for simulated beaconing or download-style techniques. Configurable C2 targets must use `.invalid`.
3. No privilege escalation. The script is intended to run as a standard non-admin user.
4. No credential access. LSASS is identified by process name only, `cmdkey /list` exposes target metadata only, and clipboard content is never logged.
5. Every technique maps to a MITRE ATT&CK ID.
6. Every technique remains controllable through grouping or switches such as `-Techniques`, `-SafeMode`, `-SkipChildProcess`, and `-IncludeUnverified`.

## Quick Start

Run all validated default techniques:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1
```

Run only selected technique groups:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -Techniques Discovery,LOLBin,Scripting
```

Run a more conservative pass:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -SafeMode -SkipChildProcess
```

Write output to a log file and retain it:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -LogPath .\validation.log -KeepLog
```

Enable the only remaining unverified technique:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -IncludeUnverified
```

## Parameters

| Parameter | Type | Purpose |
| --- | --- | --- |
| `-Techniques` | `string[]` | Runs only selected technique groups. Valid values: `Discovery`, `Execution`, `Collection`, `C2`, `LOLBin`, `Scripting`, `Enumeration`. |
| `-SafeMode` | `switch` | Suppresses the noisiest discovery activity, including `whoami /all`, `net localgroup administrators`, `net user`, `net share`, and domain-focused `net.exe` discovery commands. |
| `-SkipChildProcess` | `switch` | Suppresses the encoded-command execution test that launches a child `powershell.exe`. |
| `-IncludeUnverified` | `switch` | Enables the remaining unverified `Add-Type` inline C# compilation path, which may invoke `csc.exe` and create temporary compilation artifacts on some systems. |
| `-LogPath` | `string` | Writes console output to the specified path during execution. |
| `-KeepLog` | `switch` | Retains the log file specified by `-LogPath`. This is the only intentional persistent artifact path. |
| `-C2Endpoint` | `string` | Overrides the simulated beacon URI. The host must end in `.invalid` to prevent routable egress. |

## Expected Telemetry Surfaces

The script is meant to create useful defensive signal across common Windows-native telemetry sources:

- Security `4688` for native process creation events
- PowerShell Operational `4103` for module and command invocation logging
- PowerShell Operational `4104` for script block logging
- WMI-Activity Operational for CIM and WMIC-backed discovery
- DNS Client Operational for `.invalid` lookups and DNS-related techniques
- AMSI for PowerShell content inspection
- BITS Operational for create/resume/cancel job lifecycle telemetry

## Technique Groups

| Group | Functions | Primary telemetry |
| --- | ---: | --- |
| `Discovery` | 5 | `4688`, `4104`, WMI Operational |
| `Execution` | 1 | `4688`, `4104` |
| `Collection` | 1 | `4104` |
| `C2` | 1 | `4104`, DNS Client, firewall |
| `LOLBin` | 23 | `4688`, DNS Client, BITS |
| `Scripting` | 10 | `4103`, `4104`, AMSI |
| `Enumeration` | 10 | WMI Operational, `4103`, `4104`, DNS Client |

## Verification Status

Verified default techniques promoted from earlier unverified status:

- `certutil -urlcache`
- `bitsadmin /create + /resume + /cancel`
- `rundll32 javascript:close()`

Remaining unverified technique:

- `Add-Type` inline C# compilation behind `-IncludeUnverified`

That path remains opt-in because `csc.exe` may be absent on some systems and may create temporary compiler artifacts on others.

## Known Environmental Behavior

- `SecurityCenter2` antivirus queries commonly fail on Windows Server SKUs and should be treated as expected behavior.
- Domain-specific `net.exe` commands and `nltest /dclist` are designed to skip on non-domain systems instead of treating `WORKGROUP` or the local host name as an AD domain.
- `nltest /domain_trusts` and `net time /domain` may still fail on non-domain systems, but those failures are acceptable because the intended native process telemetry is still generated.
- `-SkipChildProcess` is useful in hardened environments where ASR or policy controls may terminate child PowerShell.

## Operational Behavior

The implementation is structured to stay resilient and explainable during validation runs:

- Functions are grouped in an ordered technique map and executed with per-function `try/catch`, so one failure does not terminate the full run.
- Native commands are funneled through `Invoke-Native` so normal native stderr behavior does not become a terminating PowerShell error under strict settings.
- Domain-only techniques use domain-awareness checks and skip cleanly on standalone hosts.
- `-C2Endpoint` is validated as an absolute URI whose host ends in `.invalid`.
- Log cleanup is automatic unless `-KeepLog` is explicitly requested.

## ATT&CK Coverage

The current script covers these ATT&CK IDs:

`T1007, T1012, T1016, T1018, T1033, T1047, T1049, T1053, T1057, T1059.001, T1069.001, T1069.002, T1071.001, T1082, T1083, T1087.001, T1087.002, T1105, T1115, T1124, T1129, T1135, T1140, T1197, T1201, T1218.005, T1218.011, T1482, T1490, T1518, T1518.001, T1518.002, T1555, T1560, T1615`

## Recommended Validation Workflow

1. Run as a standard non-admin user for representative validation.
2. Start with default settings or use `-SafeMode` for a softer first pass.
3. Use `-SkipChildProcess` when child PowerShell is likely to be blocked or aggressively flagged.
4. On standalone hosts, confirm domain-only techniques are reported as `SKIPPED` rather than treated as hard failures.
5. After execution, confirm no residual BITS jobs remain and no log file persists unless `-KeepLog` was intentionally used.
6. Validate coverage across `4688`, `4103`, `4104`, WMI, DNS, AMSI, and BITS telemetry.
7. Re-run focused technique groups to confirm fixes, enrichment changes, or new detections.

## Repository Contents

- `Invoke-BenignExploitSim_v4.3.3.ps1` - Windows simulation script
- `Invoke-BenignExploitSim_Linux_v1.sh` - Linux simulation entrypoint
- `linux/lib/` - Linux Bash modules for common helpers, detection, and technique groups
- `README.md` - repo overview and Windows-first documentation
- `README_Linux.md` - Linux-specific usage, safety, and telemetry guidance
- `.gitignore` - local/editor artifact exclusions

## Disclaimer

This repository is intended for defensive validation and authorized testing only. Operators are responsible for ensuring use complies with internal policy, monitoring expectations, and change-control requirements.
