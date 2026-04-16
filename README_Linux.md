# Invoke-BenignExploitSim for Linux

`Invoke-BenignExploitSim_Linux_v1.sh` is a Bash-first benign telemetry simulation tool for Linux-focused SIEM and EDR validation.

It is designed for authorized testing on Ubuntu/RHEL-family servers, VMs, and container-aware environments. The script favors explainable, read-only, non-persistent behaviors that generate useful Linux-native telemetry while avoiding privilege escalation, daemon mutation, secret collection, or routable command-and-control traffic.

## Design Goals

- Safe for non-root execution by default
- Linux-native technique groupings instead of a literal Windows port
- Strong `.invalid` enforcement for simulated network egress
- Environment-aware behavior for bare hosts, VMs, and containerized contexts
- Modular Bash layout with one operator-facing entrypoint

## Entry Point

Run the Linux variant with:

```bash
./Invoke-BenignExploitSim_Linux_v1.sh
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

Example runs:

```bash
./Invoke-BenignExploitSim_Linux_v1.sh --groups identity,process,network
./Invoke-BenignExploitSim_Linux_v1.sh --safe-mode --skip-child-process
./Invoke-BenignExploitSim_Linux_v1.sh --groups containers --root-extras
./Invoke-BenignExploitSim_Linux_v1.sh --log-path ./linux-validation.log --keep-log
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

## Implementation Layout

- `Invoke-BenignExploitSim_Linux_v1.sh` - CLI entrypoint
- `linux/lib/common.sh` - logging, cleanup, status tracking, and validation helpers
- `linux/lib/detect.sh` - distro, privilege, container, runtime, and orchestrator detection
- `linux/lib/groups/` - group-specific technique functions
- `tests/test_linux_sim.sh` - Bash test harness for CLI and environment-aware behavior

## Notes

- The Linux version is intentionally Linux-native and not an exact one-to-one parity port of the Windows script.
- Missing commands are treated as `SKIPPED`, not fatal failures.
- Each technique runs independently so one failing probe does not stop the entire simulation run.
