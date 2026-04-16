#!/usr/bin/env bash

sim_services_units() {
  if sim_command_exists systemctl; then
    sim_log_block "services" "$(systemctl list-units --type=service --no-pager 2>/dev/null || true)" 3
    return 0
  fi
  sim_mark_skip "systemctl unavailable"
}

sim_services_timers() {
  if [ "${SIM_SAFE_MODE:-0}" -eq 1 ]; then
    sim_mark_skip "timer enumeration suppressed by safe mode"
    return 0
  fi
  if sim_command_exists systemctl; then
    sim_log_block "timers" "$(systemctl list-timers --no-pager 2>/dev/null || true)" 2
    return 0
  fi
  sim_mark_skip "systemctl unavailable"
}

sim_services_cron() {
  local data=""
  data="$(crontab -l 2>/dev/null || true)"
  if [ -n "$data" ]; then
    sim_log_block "crontab" "$data" 3
  else
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "No user crontab entries returned"
  fi
  return 0
}

sim_services_root_extras() {
  sim_require_root_extra || return 0
  if [ -d "/etc/cron.d" ]; then
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Root extra: /etc/cron.d present"
    return 0
  fi
  sim_mark_skip "root cron directories unavailable"
}

sim_run_group_services() {
  sim_run_technique "Services" sim_services_units \
    "Enumerating service units" "T1007" \
    "systemctl service listing telemetry"
  sim_run_technique "Services" sim_services_timers \
    "Enumerating timers" "T1053.006" \
    "systemctl timer listing telemetry"
  sim_run_technique "Services" sim_services_cron \
    "Reading user crontab state" "T1053.003" \
    "User cron enumeration telemetry"
  sim_run_technique "Services" sim_services_root_extras \
    "Checking root-only scheduled task locations" "T1053.003" \
    "Optional root-only filesystem discovery"
}
