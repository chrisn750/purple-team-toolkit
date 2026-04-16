#!/usr/bin/env bash

sim_identity_user_context() {
  local who=""
  local ident=""
  local grp=""

  who="$(whoami 2>/dev/null || true)"
  ident="$(id 2>/dev/null || true)"
  grp="$(groups 2>/dev/null || true)"

  [ -n "$who" ] && sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Current user: $who"
  [ -n "$ident" ] && sim_log_block "id" "$ident" 1
  [ -n "$grp" ] && sim_log_block "groups" "$grp" 1
  return 0
}

sim_identity_capabilities() {
  local proc_status=""
  proc_status="$(sim_file_path "/proc/self/status")"
  if [ -r "$proc_status" ]; then
    sim_log_block "capabilities" "$(grep '^CapEff:' "$proc_status" 2>/dev/null || true)" 1
    return 0
  fi
  if sim_command_exists capsh; then
    sim_log_block "capsh" "$(capsh --print 2>/dev/null || true)" 2
    return 0
  fi
  sim_mark_skip "capability discovery unavailable"
  return 0
}

sim_run_group_identity() {
  sim_run_technique "Identity" sim_identity_user_context \
    "Enumerating user and group context" "T1033" \
    "Identity and group telemetry from whoami, id, and groups"
  sim_run_technique "Identity" sim_identity_capabilities \
    "Inspecting capability-related context" "T1068" \
    "Capability-oriented telemetry without privilege escalation"
}
