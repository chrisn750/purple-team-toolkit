#!/usr/bin/env bash

sim_process_listing() {
  if sim_command_exists ps; then
    sim_log_block "ps" "$(ps 2>/dev/null || true)" 4
    return 0
  fi
  sim_mark_skip "ps unavailable"
}

sim_process_security_tools() {
  local data=""
  if sim_command_exists pgrep; then
    data="$(pgrep -af 'falcon|sentinel|defender|osquery|crowdstrike|clamd|auditd' 2>/dev/null || true)"
    if [ -n "$data" ]; then
      sim_log_block "security-process" "$data" 3
    else
      sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "No known security-tool processes matched"
    fi
    return 0
  fi
  sim_mark_skip "pgrep unavailable"
}

sim_process_child_shell() {
  if [ "${SIM_SAFE_MODE:-0}" -eq 1 ] || [ "${SIM_SKIP_CHILD_PROCESS:-0}" -eq 1 ]; then
    sim_mark_skip "child shell execution simulation disabled"
    return 0
  fi
  sim_log_block "child-shell" "$(bash -lc 'printf child-shell-ok\n' 2>/dev/null || true)" 1
  return 0
}

sim_run_group_process() {
  sim_run_technique "Process" sim_process_listing \
    "Enumerating running processes" "T1057" \
    "Process listing telemetry via ps"
  sim_run_technique "Process" sim_process_security_tools \
    "Searching for common security tooling processes" "T1518.001" \
    "Process lookup telemetry for defensive tooling"
  sim_run_technique "Process" sim_process_child_shell \
    "Simulating child shell execution" "T1059.004" \
    "Child bash execution telemetry"
}
