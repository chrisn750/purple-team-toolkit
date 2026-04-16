#!/usr/bin/env bash

sim_containers_context() {
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Context: $SIM_CONTEXT_LABEL"
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Context hint: $SIM_CONTAINER_HINT"
  return 0
}

sim_containers_runtime_markers() {
  if [ "${SIM_SAFE_MODE:-0}" -eq 1 ]; then
    sim_mark_skip "runtime probing suppressed by safe mode"
    return 0
  fi
  if [ -n "$SIM_RUNTIME_MARKERS" ]; then
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Container runtimes detected: $(printf '%s' "$SIM_RUNTIME_MARKERS" | sed 's/,/, /g')"
    return 0
  fi
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Container runtimes detected: none"
  return 0
}

sim_containers_orchestrator_markers() {
  if [ -n "$SIM_ORCHESTRATOR_MARKERS" ]; then
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Kubernetes markers detected: $(printf '%s' "$SIM_ORCHESTRATOR_MARKERS" | sed 's/,/, /g')"
    return 0
  fi
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Kubernetes markers detected: none"
  return 0
}

sim_containers_cgroup_metadata() {
  local cgroup_path=""
  cgroup_path="$(sim_file_path "/proc/1/cgroup")"
  if [ -r "$cgroup_path" ]; then
    sim_log_block "proc1-cgroup" "$(cat "$cgroup_path")" 3
    return 0
  fi
  sim_mark_skip "container cgroup metadata unavailable"
  return 0
}

sim_run_group_containers() {
  sim_run_technique "Containers" sim_containers_context \
    "Assessing container execution context" "T1610" \
    "Container-environment context telemetry"
  sim_run_technique "Containers" sim_containers_runtime_markers \
    "Enumerating container runtime markers" "T1611" \
    "Runtime marker discovery without daemon mutation"
  sim_run_technique "Containers" sim_containers_orchestrator_markers \
    "Enumerating orchestration markers" "T1580" \
    "Orchestrator marker discovery without cluster interaction"
  sim_run_technique "Containers" sim_containers_cgroup_metadata \
    "Reading procfs container metadata" "T1082" \
    "Procfs-based container metadata discovery"
}
