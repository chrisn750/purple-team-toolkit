# Invoke-BenignExploitSim for Linux

`Invoke-BenignExploitSim.sh` is a Bash-first benign telemetry simulation tool for Linux-focused SIEM and EDR validation.

It is designed for authorized testing on Ubuntu/RHEL-family servers, VMs, and container-aware environments. The script favors explainable, read-only, non-persistent behaviors that generate useful Linux-native telemetry while avoiding privilege escalation, daemon mutation, secret collection, or routable command-and-control traffic.

## Design Goals

- Safe for non-root execution by default
- Linux-native technique groupings instead of a literal Windows port
- Strong `.invalid` enforcement for simulated network egress
- Environment-aware behavior for bare hosts, VMs, and containerized contexts
- Modular Bash layout with one operator-facing entrypoint

## Current Version

- Script version: `1.0.0`
- State: runtime-tested Linux implementation with container-aware detection, root-extra gating, and optional unverified Perl execution
- Technique groups: `7`
- Executable technique functions: `25`
- Distinct MITRE ATT&CK IDs covered: `21`

## Entry Point

From the `linux/` directory, run:

```bash
./Invoke-BenignExploitSim.sh
```

## CLI Options

```text
--groups <csv>
--safe-mode
--skip-child-process
--include-unverified
--log-path <path>
--keep-log
--c2-endpoint <url>
--root-extras
--help
```

## Parameters

| Parameter | Type | Purpose |
| --- | --- | --- |
| `--groups` | `csv` | Runs only selected Linux groups. Valid values: `identity`, `host`, `process`, `network`, `services`, `interpreters`, `containers`. |
| `--safe-mode` | `flag` | Suppresses noisier child-process, network, and runtime-probing activity. |
| `--skip-child-process` | `flag` | Suppresses the child shell execution simulation. |
| `--include-unverified` | `flag` | Enables the optional unverified Perl inline execution path when `perl` is available. |
| `--log-path` | `path` | Writes console output to the specified path during execution. |
| `--keep-log` | `flag` | Retains the log file specified by `--log-path`. |
| `--c2-endpoint` | `url` | Overrides the simulated beacon URI. The host must end in `.invalid`. |
| `--root-extras` | `flag` | Enables extra root-only discovery paths when the current user is already root. |

Example runs:

```bash
./Invoke-BenignExploitSim.sh --groups identity,process,network
./Invoke-BenignExploitSim.sh --safe-mode --skip-child-process
./Invoke-BenignExploitSim.sh --groups containers --root-extras
./Invoke-BenignExploitSim.sh --log-path ./linux-validation.log --keep-log
```

## Linux Technique Groups

| Group | Intent | Typical commands or surfaces |
| --- | --- | --- |
| `identity` | User, group, and capability-oriented discovery | `whoami`, `id`, `groups`, procfs capability reads |
| `host` | OS, kernel, hostname, mount, and storage discovery | `/etc/os-release`, `uname`, `hostnamectl`, `findmnt`, `lsblk` |
| `process` | Process discovery and child-shell simulation | `ps`, `pgrep`, `bash -lc` |
| `network` | Interface, route, DNS, socket, and HTTP beacon simulation | `ip`, `ss`, `getent`, `curl`, `wget` |
| `services` | Service, timer, and cron recon-style reads | `systemctl`, `crontab` |
| `interpreters` | Bash/Python/Perl discovery and benign inline execution | `bash`, `python3`, `perl`, `base64` |
| `containers` | Container-context, runtime-marker, and orchestrator-marker discovery | `/.dockerenv`, `/proc/1/cgroup`, runtime sockets, Kubernetes markers |

## Safety Model

The Linux variant follows these constraints:

- No persistence beyond optional retained logs from `--log-path` with `--keep-log`
- No `sudo`, no privilege escalation, and no namespace escape behavior
- No credential or secret collection
- No service modification, no image pulls, no `docker exec`, no `kubectl apply`, and no daemon state mutation
- No routable network activity for the simulated beacon path

Any `--c2-endpoint` value must be an absolute `http` or `https` URI whose host ends in `.invalid`.

## Privilege Model

The script is useful as a normal user.

- Default mode: non-root-safe techniques only
- `--root-extras`: enables a small set of additional discovery paths, but only if the current user is already root
- If root-only behavior is requested while running unprivileged, the script records `SKIPPED` instead of failing

## Container-Aware Behavior

The Linux variant treats container-awareness as a first-class concern.

It inspects:

- `/.dockerenv`
- `/run/.containerenv`
- `/proc/1/cgroup`
- `systemd-detect-virt --container`
- runtime sockets and binaries such as Docker, Podman, containerd, and CRI-O
- orchestrator markers such as Kubernetes environment variables, serviceaccount paths, and `k3s` configuration

Behavior changes based on context:

- Inside a container: host-only probes are skipped and container-safe metadata discovery is favored
- On a host with runtimes: safe runtime and orchestrator marker discovery is reported without modifying runtime state
- In `--safe-mode`: noisier runtime probing and beacon simulation are suppressed and reported as `SKIPPED`

## Expected Telemetry Surfaces

The Linux variant is meant to drive useful signal through:

- Process execution telemetry from native command invocations
- Audit and shell-history-adjacent process visibility where those controls exist
- journald and service-manager command activity in systemd environments
- DNS client lookups for `.invalid`
- HTTP client activity against `.invalid`
- procfs and filesystem access patterns tied to discovery activity
- container/runtime marker inspection on hosts and in containers

## Verification Status

Verified default Linux paths include:

- identity, host, process, network, services, and container discovery groups
- child shell execution output formatting
- `.invalid` DNS and HTTP simulation
- root-extra service discovery when `--root-extras` is provided

Optional unverified path:

- Perl inline execution behind `--include-unverified`

That path is dependency-gated. When `perl` is unavailable, the script records `SKIPPED` rather than treating the run as an error.

## Known Environmental Behavior

- `--root-extras` does not auto-enable just because the script is run as `root`; the flag must still be supplied explicitly.
- Container runtime and Kubernetes marker detection can legitimately report `none` on hosts without exposed runtime sockets, binaries, or cluster markers.
- Running inside a container causes host-only probes such as block device enumeration to be skipped intentionally.
- Missing tools such as `perl`, `curl`, `wget`, `ip`, `ss`, or `systemctl` are treated as `SKIPPED`, not fatal failures.
- `--safe-mode` intentionally suppresses the noisiest Linux paths and records them as skipped.

## Operational Behavior

The implementation is structured to stay resilient and explainable during validation runs:

- Environment detection happens first so the script can branch safely for host versus container contexts.
- Each technique runs independently and records `OK`, `SKIPPED`, or `ERROR` without terminating the entire run.
- Root-only paths are gated behind `--root-extras` and current privilege checks.
- Simulated network activity is restricted to `.invalid` endpoints only.
- Linux modules are split by responsibility under `linux/lib/` so platform behavior is easier to reason about and extend.

## ATT&CK Coverage

The current Linux script covers these ATT&CK IDs:

`T1007, T1016, T1018, T1033, T1049, T1053.003, T1053.006, T1057, T1059, T1059.004, T1059.006, T1059.007, T1068, T1071.001, T1082, T1120, T1140, T1518.001, T1580, T1610, T1611`

## Implementation Layout

- `Invoke-BenignExploitSim.sh` - CLI entrypoint
- `lib/common.sh` - logging, cleanup, status tracking, and validation helpers
- `lib/detect.sh` - distro, privilege, container, runtime, and orchestrator detection
- `lib/groups/` - group-specific technique functions
- `linux/tests/test_linux_sim.sh` - Bash test harness for CLI and environment-aware behavior

## Notes

- The Linux version is intentionally Linux-native and not an exact one-to-one parity port of the Windows script.
- Missing commands are treated as `SKIPPED`, not fatal failures.
- Each technique runs independently so one failing probe does not stop the entire simulation run.

## Recommended Validation Workflow

1. Run the script first as a normal user to validate the non-root-safe baseline.
2. Add `--safe-mode` for a softer first pass in monitored environments.
3. Add `--root-extras` only when you intentionally want the additional root-gated discovery paths.
4. Use `--include-unverified` only when you want to exercise the optional Perl path and understand that it depends on `perl` being installed.
5. Validate that DNS and HTTP simulations remain pointed at `.invalid` destinations.
6. On containerized hosts or in containers, confirm host-only probes are skipped intentionally rather than treated as failures.
7. Re-run focused groups to validate detection changes, runtime visibility, or telemetry enrichment updates.
