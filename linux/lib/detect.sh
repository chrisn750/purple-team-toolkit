#!/usr/bin/env bash

SIM_DISTRO_ID="unknown"
SIM_DISTRO_VERSION="unknown"
SIM_DISTRO_PRETTY="unknown"
SIM_INIT_SYSTEM="unknown"
SIM_IS_ROOT=0
SIM_IN_CONTAINER=0
SIM_CONTEXT_LABEL="host"
SIM_RUNTIME_MARKERS=""
SIM_ORCHESTRATOR_MARKERS=""
SIM_CONTAINER_HINT="none"

sim_detect_os_release() {
  local os_release
  os_release="$(sim_file_path "/etc/os-release")"
  if [ -r "$os_release" ]; then
    SIM_DISTRO_ID="$(grep '^ID=' "$os_release" | head -n 1 | cut -d= -f2 | tr -d '"')"
    SIM_DISTRO_VERSION="$(grep '^VERSION_ID=' "$os_release" | head -n 1 | cut -d= -f2 | tr -d '"')"
    SIM_DISTRO_PRETTY="$(grep '^PRETTY_NAME=' "$os_release" | head -n 1 | cut -d= -f2- | tr -d '"')"
  fi
}

sim_detect_root() {
  if [ "$(id -u 2>/dev/null || echo 1)" = "0" ]; then
    SIM_IS_ROOT=1
  else
    SIM_IS_ROOT=0
  fi
}

sim_detect_container_context() {
  local cgroup_path=""
  local cgroup_data=""
  if sim_file_exists "/.dockerenv" || sim_file_exists "/run/.containerenv"; then
    SIM_IN_CONTAINER=1
    SIM_CONTAINER_HINT="filesystem-marker"
  fi

  cgroup_path="$(sim_file_path "/proc/1/cgroup")"
  if [ -r "$cgroup_path" ]; then
    cgroup_data="$(cat "$cgroup_path")"
    if printf '%s' "$cgroup_data" | grep -Eiq '(docker|containerd|kubepods|podman|libpod|lxc)'; then
      SIM_IN_CONTAINER=1
      SIM_CONTAINER_HINT="cgroup-marker"
    fi
  fi

  if sim_command_exists systemd-detect-virt && systemd-detect-virt --container >/dev/null 2>&1; then
    SIM_IN_CONTAINER=1
    SIM_CONTAINER_HINT="$(systemd-detect-virt --container 2>/dev/null | head -n 1)"
  fi

  if [ "$SIM_IN_CONTAINER" -eq 1 ]; then
    SIM_CONTEXT_LABEL="inside-container"
  else
    SIM_CONTEXT_LABEL="host"
  fi
}

sim_detect_runtimes() {
  SIM_RUNTIME_MARKERS=""
  if sim_command_exists docker || sim_file_exists "/var/run/docker.sock"; then
    SIM_RUNTIME_MARKERS="$(sim_append_csv_unique "$SIM_RUNTIME_MARKERS" "docker")"
  fi
  if sim_command_exists podman || sim_file_exists "/run/podman/podman.sock"; then
    SIM_RUNTIME_MARKERS="$(sim_append_csv_unique "$SIM_RUNTIME_MARKERS" "podman")"
  fi
  if sim_command_exists containerd || sim_file_exists "/run/containerd/containerd.sock"; then
    SIM_RUNTIME_MARKERS="$(sim_append_csv_unique "$SIM_RUNTIME_MARKERS" "containerd")"
  fi
  if sim_command_exists crio || sim_file_exists "/var/run/crio/crio.sock"; then
    SIM_RUNTIME_MARKERS="$(sim_append_csv_unique "$SIM_RUNTIME_MARKERS" "cri-o")"
  fi
}

sim_detect_orchestrators() {
  SIM_ORCHESTRATOR_MARKERS=""
  if [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
    SIM_ORCHESTRATOR_MARKERS="$(sim_append_csv_unique "$SIM_ORCHESTRATOR_MARKERS" "kubernetes-env")"
  fi
  if sim_file_exists "/var/run/secrets/kubernetes.io/serviceaccount/token"; then
    SIM_ORCHESTRATOR_MARKERS="$(sim_append_csv_unique "$SIM_ORCHESTRATOR_MARKERS" "serviceaccount-token")"
  fi
  if sim_file_exists "/etc/rancher/k3s/k3s.yaml"; then
    SIM_ORCHESTRATOR_MARKERS="$(sim_append_csv_unique "$SIM_ORCHESTRATOR_MARKERS" "k3s-config")"
  fi
  if sim_file_exists "/var/lib/kubelet" || sim_command_exists kubelet; then
    SIM_ORCHESTRATOR_MARKERS="$(sim_append_csv_unique "$SIM_ORCHESTRATOR_MARKERS" "kubelet")"
  fi
}

sim_detect_init_system() {
  if sim_command_exists systemctl; then
    SIM_INIT_SYSTEM="systemd"
  elif sim_file_exists "/sbin/openrc"; then
    SIM_INIT_SYSTEM="openrc"
  else
    SIM_INIT_SYSTEM="unknown"
  fi
}

sim_detect_environment() {
  sim_detect_os_release
  sim_detect_root
  sim_detect_container_context
  sim_detect_runtimes
  sim_detect_orchestrators
  sim_detect_init_system
}
