#!/usr/bin/env bash

sim_interpreters_presence() {
  local found=""
  sim_command_exists bash && found="$(sim_append_csv_unique "$found" "bash")"
  sim_command_exists sh && found="$(sim_append_csv_unique "$found" "sh")"
  sim_command_exists python3 && found="$(sim_append_csv_unique "$found" "python3")"
  sim_command_exists perl && found="$(sim_append_csv_unique "$found" "perl")"
  if [ -n "$found" ]; then
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Interpreters detected: $found"
    return 0
  fi
  sim_mark_skip "no supported interpreters detected"
}

sim_interpreters_shell_inline() {
  sim_log_block "shell-inline" "$(bash -lc 'printf inline-shell-ok\n' 2>/dev/null || true)" 1
  return 0
}

sim_interpreters_python_inline() {
  if sim_command_exists python3; then
    sim_log_block "python-inline" "$(python3 -c 'print("python-inline-ok")' 2>/dev/null || true)" 1
    return 0
  fi
  sim_mark_skip "python3 unavailable"
}

sim_interpreters_base64() {
  local encoded=""
  local decoded=""
  if ! sim_command_exists base64; then
    sim_mark_skip "base64 unavailable"
    return 0
  fi
  encoded="$(printf 'linux-sim' | base64 2>/dev/null | tr -d '\n' || true)"
  if [ -n "$encoded" ]; then
    decoded="$(printf '%s' "$encoded" | base64 -d 2>/dev/null || true)"
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Base64 round-trip produced: ${decoded:-decode-failed}"
    return 0
  fi
  sim_mark_skip "base64 encoding failed"
}

sim_interpreters_unverified_perl() {
  if [ "${SIM_INCLUDE_UNVERIFIED:-0}" -ne 1 ]; then
    sim_mark_skip "unverified Perl inline path disabled"
    return 0
  fi
  if sim_command_exists perl; then
    sim_log_block "perl-inline" "$(perl -e 'print "perl-inline-ok\n"' 2>/dev/null || true)" 1
    return 0
  fi
  sim_mark_skip "perl unavailable"
}

sim_run_group_interpreters() {
  sim_run_technique "Interpreters" sim_interpreters_presence \
    "Discovering available scripting interpreters" "T1059" \
    "Interpreter discovery telemetry"
  sim_run_technique "Interpreters" sim_interpreters_shell_inline \
    "Running a benign inline shell command" "T1059.004" \
    "Shell command execution telemetry"
  sim_run_technique "Interpreters" sim_interpreters_python_inline \
    "Running a benign inline Python command" "T1059.006" \
    "Python inline execution telemetry"
  sim_run_technique "Interpreters" sim_interpreters_base64 \
    "Simulating a benign base64 decode pattern" "T1140" \
    "Base64 decode telemetry"
  sim_run_technique "Interpreters" sim_interpreters_unverified_perl \
    "Running the optional unverified Perl path" "T1059.007" \
    "Optional Perl inline execution telemetry"
}
