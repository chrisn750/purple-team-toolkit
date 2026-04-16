#!/usr/bin/env bash

sim_network_interfaces() {
  if sim_command_exists ip; then
    sim_log_block "ip addr" "$(ip addr 2>/dev/null || true)" 3
    sim_log_block "ip route" "$(ip route 2>/dev/null || true)" 2
    return 0
  fi
  sim_mark_skip "ip command unavailable"
  return 0
}

sim_network_sockets_and_neighbors() {
  if [ "${SIM_SAFE_MODE:-0}" -eq 1 ]; then
    sim_mark_skip "extended socket and neighbor enumeration suppressed by safe mode"
    return 0
  fi
  if sim_command_exists ss; then
    sim_log_block "ss" "$(ss -tulpn 2>/dev/null || true)" 2
  fi
  if sim_command_exists ip; then
    sim_log_block "ip neigh" "$(ip neigh 2>/dev/null || true)" 2
  fi
  return 0
}

sim_network_dns_lookup() {
  if sim_command_exists getent; then
    getent ahostsv4 sim-c2.invalid >/dev/null 2>&1 || true
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Performed .invalid DNS lookup for sim-c2.invalid"
    return 0
  fi
  if sim_command_exists nslookup; then
    nslookup sim-c2.invalid >/dev/null 2>&1 || true
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "Performed .invalid DNS lookup for sim-c2.invalid"
    return 0
  fi
  sim_mark_skip "DNS lookup tooling unavailable"
  return 0
}

sim_network_http_beacon() {
  if [ "${SIM_SAFE_MODE:-0}" -eq 1 ]; then
    sim_mark_skip "HTTP beacon simulation suppressed by safe mode"
    return 0
  fi
  if sim_command_exists curl; then
    curl -fsS --max-time 2 "$SIM_C2_ENDPOINT" >/dev/null 2>&1 || true
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "HTTP beacon attempted to $SIM_C2_ENDPOINT"
    return 0
  fi
  if sim_command_exists wget; then
    wget -qO- --timeout=2 "$SIM_C2_ENDPOINT" >/dev/null 2>&1 || true
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "HTTP beacon attempted to $SIM_C2_ENDPOINT"
    return 0
  fi
  sim_mark_skip "HTTP client unavailable"
  return 0
}

sim_run_group_network() {
  sim_run_technique "Network" sim_network_interfaces \
    "Enumerating interfaces and routes" "T1016" \
    "ip addr and ip route telemetry"
  sim_run_technique "Network" sim_network_sockets_and_neighbors \
    "Enumerating listening sockets and neighbors" "T1049" \
    "Socket and neighbor discovery telemetry"
  sim_run_technique "Network" sim_network_dns_lookup \
    "Triggering benign DNS lookup to .invalid" "T1018" \
    "DNS client telemetry against .invalid"
  sim_run_technique "Network" sim_network_http_beacon \
    "Triggering benign HTTP beacon to .invalid" "T1071.001" \
    "HTTP client telemetry against .invalid"
}
