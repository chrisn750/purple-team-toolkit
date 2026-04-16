#!/usr/bin/env bash

sim_host_os_info() {
  local kernel=""
  kernel="$(uname -sr 2>/dev/null || true)"
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "OS: $SIM_DISTRO_PRETTY"
  [ -n "$kernel" ] && sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Kernel: $kernel"
  return 0
}

sim_host_hostname_info() {
  local data=""
  if sim_command_exists hostnamectl; then
    data="$(hostnamectl 2>/dev/null || true)"
    [ -n "$data" ] && sim_log_block "hostnamectl" "$data" 2
    return 0
  fi
  if sim_command_exists hostname; then
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Hostname: $(hostname 2>/dev/null || true)"
    return 0
  fi
  sim_mark_skip "hostname tooling unavailable"
}

sim_host_storage_info() {
  if [ "$SIM_IN_CONTAINER" -eq 1 ]; then
    sim_mark_skip "block device enumeration inside container"
    return 0
  fi
  if sim_command_exists lsblk; then
    sim_log_block "lsblk" "$(lsblk 2>/dev/null || true)" 3
  else
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "lsblk unavailable"
  fi
  if sim_command_exists findmnt; then
    sim_log_block "findmnt" "$(findmnt 2>/dev/null || true)" 3
  fi
  return 0
}

sim_run_group_host() {
  sim_run_technique "Host" sim_host_os_info \
    "Collecting Linux OS and kernel details" "T1082" \
    "OS release and kernel discovery telemetry"
  sim_run_technique "Host" sim_host_hostname_info \
    "Collecting hostname and host metadata" "T1082" \
    "hostnamectl or hostname invocation telemetry"
  sim_run_technique "Host" sim_host_storage_info \
    "Enumerating mounts and block devices" "T1120" \
    "Storage and mount enumeration telemetry"
}
