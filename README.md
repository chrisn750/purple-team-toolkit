# SIEM / EDR Validation Script

A benign PowerShell validation script for exercising SIEM and EDR detections with realistic, non-destructive telemetry.

This project is designed for detection engineering, lab validation, tabletop exercises, and controlled purple-team style testing. It simulates common attacker behaviors while intentionally avoiding malware, persistence, destructive actions, and routable command-and-control traffic.

## What It Does

`Invoke-BenignExploitSim_v4.3.3.ps1` generates security-relevant telemetry across multiple ATT&CK-aligned technique groups, including:

- Discovery
- Execution
- Collection
- C2
- LOLBin
- Scripting
- Enumeration

The script is built to create the kinds of logs defenders care about, such as:

- PowerShell script block logging
- AMSI inspection events
- Process creation telemetry
- Native command execution traces
- DNS and HTTP activity for a non-routable simulated beacon

## Design Goals

- Safe by default for standard, non-admin execution
- No malicious payloads or destructive actions
- No intended persistent disk artifacts
- Useful for validating logging, alerting, enrichment, and analyst workflows
- Flexible enough for both broad coverage runs and targeted technique testing

## Safety Notes

This is a benign simulation tool, but it is intentionally noisy from a telemetry perspective.

- It is expected to trigger PowerShell, process, DNS, and web telemetry.
- It should be used only in environments where validation activity is authorized.
- The default C2 endpoint uses the `.invalid` top-level domain to prevent routable egress.
- Some noisier actions can be reduced with `-SafeMode`.
- One technique path, Add-Type inline C# (`T1129`), remains opt-in behind `-IncludeUnverified`.

## Quick Start

Run the full validated simulation set:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1
```

Run a smaller subset of technique groups:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -Techniques Discovery,LOLBin,Scripting
```

Run in a more conservative mode:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -SafeMode -SkipChildProcess
```

Write output to a log file and keep it:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -LogPath .\validation.log -KeepLog
```

Enable the unverified Add-Type path:

```powershell
.\Invoke-BenignExploitSim_v4.3.3.ps1 -IncludeUnverified
```

## Parameters

| Parameter | Type | Purpose |
| --- | --- | --- |
| `-LogPath` | `string` | Writes script output to a file. |
| `-KeepLog` | `switch` | Keeps the log file after execution when used with `-LogPath`. |
| `-SkipChildProcess` | `switch` | Skips the encoded-command test that launches a child `powershell.exe`. |
| `-SafeMode` | `switch` | Suppresses the noisiest account, group, and share enumeration paths. |
| `-Techniques` | `string[]` | Runs only the specified technique groups. |
| `-C2Endpoint` | `string` | Overrides the simulated beacon URI. Host must end with `.invalid`. |
| `-IncludeUnverified` | `switch` | Enables the opt-in Add-Type inline C# path. |

Valid values for `-Techniques`:

- `Discovery`
- `Execution`
- `Collection`
- `C2`
- `LOLBin`
- `Scripting`
- `Enumeration`

## Operational Behavior

The script is intentionally opinionated about safety:

- It validates the C2 endpoint and rejects hosts that do not end in `.invalid`.
- It prefers read-only, in-memory, or ephemeral activity where possible.
- It supports fallback log cleanup when `-LogPath` is used without `-KeepLog`.
- It separates high-noise or less-certain behaviors behind explicit switches.

`-SafeMode` reduces actions most likely to cause unnecessary escalation in production-like environments, while still preserving useful discovery and telemetry coverage.

## Example Use Cases

- Validate SIEM correlation rules for PowerShell and LOLBin activity
- Test EDR visibility into encoded command execution and script behaviors
- Confirm alert routing, enrichment, and case creation for suspicious-but-benign activity
- Exercise analyst workflows during tabletop or detection tuning sessions
- Compare telemetry coverage across server builds or security tooling baselines

## ATT&CK Coverage

The script header documents coverage across a wide set of ATT&CK techniques, including examples such as:

- `T1033` System Owner/User Discovery
- `T1059.001` PowerShell
- `T1071.001` Web Protocols
- `T1087.001` Local Account Discovery
- `T1105` Ingress Tool Transfer simulation patterns
- `T1197` BITS Jobs
- `T1218` Signed Binary Proxy Execution variants
- `T1490` Inhibit System Recovery related enumeration patterns

Use the script output and your environment telemetry together to confirm which controls, detections, and playbooks activate in your environment.

## Repository Contents

- `Invoke-BenignExploitSim_v4.3.3.ps1` - the validation script

## Recommended Workflow

1. Run the script in a lab or otherwise authorized environment.
2. Start with default settings or `-SafeMode` if you want a softer first pass.
3. Review SIEM, EDR, PowerShell, DNS, and proxy telemetry generated during execution.
4. Tune detections or enrichments based on gaps, false negatives, or noisy outcomes.
5. Re-run focused technique groups to validate improvements.

## Disclaimer

This repository is intended for defensive validation and authorized testing only. Operators are responsible for ensuring use complies with internal policy, change control, and monitoring expectations.
