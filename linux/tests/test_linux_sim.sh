#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/Invoke-BenignExploitSim.sh"
TEST_TMP="${TMPDIR:-/tmp}/linux-sim-tests-$$"
PASS_COUNT=0
FAIL_COUNT=0

mkdir -p "$TEST_TMP"
trap 'rm -rf "$TEST_TMP"' EXIT

fail() {
  echo "not ok - $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  echo "ok - $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    return 1
  fi
}

make_stub_env() {
  local stub_dir="$1"
  mkdir -p "$stub_dir"

  cat >"$stub_dir/whoami" <<'EOF'
#!/usr/bin/env bash
echo "simuser"
EOF

  cat >"$stub_dir/id" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  -u)
    echo "${SIM_TEST_UID:-1000}"
    ;;
  *)
    echo "uid=${SIM_TEST_UID:-1000}(simuser) gid=1000(simuser) groups=1000(simuser),27(sudo)"
    ;;
esac
EOF

  cat >"$stub_dir/groups" <<'EOF'
#!/usr/bin/env bash
echo "simuser sudo docker"
EOF

  cat >"$stub_dir/uname" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-sr" ]; then
  echo "Linux 6.8.0-sim"
else
  echo "Linux"
fi
EOF

  cat >"$stub_dir/hostnamectl" <<'EOF'
#!/usr/bin/env bash
echo " Static hostname: sim-host"
echo " Operating System: SimLinux 1.0"
EOF

  cat >"$stub_dir/hostname" <<'EOF'
#!/usr/bin/env bash
echo "sim-host"
EOF

  cat >"$stub_dir/ps" <<'EOF'
#!/usr/bin/env bash
cat <<OUT
  PID COMMAND
    1 systemd
   42 sshd
   99 falcon-sensor
OUT
EOF

  cat >"$stub_dir/pgrep" <<'EOF'
#!/usr/bin/env bash
echo "99 falcon-sensor"
EOF

  cat >"$stub_dir/ip" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  addr)
    echo "2: eth0    inet 10.0.0.5/24"
    ;;
  route)
    echo "default via 10.0.0.1 dev eth0"
    ;;
  neigh)
    echo "10.0.0.1 dev eth0 lladdr aa:bb:cc:dd:ee:ff REACHABLE"
    ;;
  *)
    exit 1
    ;;
esac
EOF

  cat >"$stub_dir/ss" <<'EOF'
#!/usr/bin/env bash
echo "Netid State Recv-Q Send-Q Local Address:Port Peer Address:Port"
EOF

  cat >"$stub_dir/findmnt" <<'EOF'
#!/usr/bin/env bash
echo "TARGET SOURCE FSTYPE"
echo "/ overlay overlay"
EOF

  cat >"$stub_dir/lsblk" <<'EOF'
#!/usr/bin/env bash
echo "NAME TYPE SIZE"
echo "sda disk 80G"
EOF

  cat >"$stub_dir/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  list-units)
    echo "sshd.service loaded active running OpenSSH Daemon"
    ;;
  list-timers)
    echo "logrotate.timer loaded active waiting Daily rotation"
    ;;
  *)
    exit 1
    ;;
esac
EOF

  cat >"$stub_dir/crontab" <<'EOF'
#!/usr/bin/env bash
echo "no crontab for simuser" >&2
exit 1
EOF

  cat >"$stub_dir/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF

  cat >"$stub_dir/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl: (6) Could not resolve host: sim-c2.invalid" >&2
exit 6
EOF

  cat >"$stub_dir/base64" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-d" ]; then
  python3 - <<'PY'
import base64, sys
data = sys.stdin.read()
sys.stdout.write(base64.b64decode(data).decode("utf-8"))
PY
else
  python3 - <<'PY'
import base64, sys
data = sys.stdin.read()
sys.stdout.write(base64.b64encode(data.encode("utf-8")).decode("utf-8"))
PY
fi
EOF

  cat >"$stub_dir/python3" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-c" ]; then
  echo "python-inline-ok"
else
  echo "Python 3.12.0"
fi
EOF

  cat >"$stub_dir/perl" <<'EOF'
#!/usr/bin/env bash
echo "perl-inline-ok"
EOF

  cat >"$stub_dir/docker" <<'EOF'
#!/usr/bin/env bash
echo "Docker stub"
EOF

  cat >"$stub_dir/podman" <<'EOF'
#!/usr/bin/env bash
echo "Podman stub"
EOF

  cat >"$stub_dir/systemd-detect-virt" <<'EOF'
#!/usr/bin/env bash
if [ "${SIM_TEST_VIRT:-none}" = "container" ]; then
  echo "docker"
  exit 0
fi
exit 1
EOF

  chmod +x "$stub_dir"/*
}

make_fake_root() {
  local fake_root="$1"
  mkdir -p "$fake_root/etc" "$fake_root/proc/1" "$fake_root/run" "$fake_root/var/run" "$fake_root/run/containerd"
  cat >"$fake_root/etc/os-release" <<'EOF'
ID=ubuntu
VERSION_ID="24.04"
PRETTY_NAME="Ubuntu 24.04 LTS"
EOF
  cat >"$fake_root/proc/1/cgroup" <<'EOF'
0::/
EOF
}

run_script() {
  local fake_root="$1"
  local stub_dir="$2"
  shift 2
  PATH="$stub_dir:$PATH" SIM_TEST_ROOT="$fake_root" "$SCRIPT_PATH" "$@" 2>&1
}

test_help_lists_linux_groups() {
  local output
  output="$("$SCRIPT_PATH" --help 2>&1)"
  assert_contains "$output" "--groups" &&
    assert_contains "$output" "identity,host,process,network,services,interpreters,containers"
}

test_rejects_invalid_group() {
  local fake_root="$TEST_TMP/invalid-group-root"
  local stub_dir="$TEST_TMP/invalid-group-bin"
  local output
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  if output="$(run_script "$fake_root" "$stub_dir" --groups nope 2>&1)"; then
    return 1
  fi
  assert_contains "$output" "Invalid group"
}

test_rejects_routable_endpoint() {
  local fake_root="$TEST_TMP/bad-endpoint-root"
  local stub_dir="$TEST_TMP/bad-endpoint-bin"
  local output
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  if output="$(run_script "$fake_root" "$stub_dir" --groups network --c2-endpoint https://example.com/beacon 2>&1)"; then
    return 1
  fi
  assert_contains "$output" ".invalid"
}

test_log_cleanup_happens_without_keep_log() {
  local fake_root="$TEST_TMP/log-root"
  local stub_dir="$TEST_TMP/log-bin"
  local log_path="$TEST_TMP/run.log"
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  run_script "$fake_root" "$stub_dir" --groups identity --log-path "$log_path" >/dev/null || return 1
  [ ! -e "$log_path" ]
}

test_container_context_skips_host_only_probe() {
  local fake_root="$TEST_TMP/container-root"
  local stub_dir="$TEST_TMP/container-bin"
  local output
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  : >"$fake_root/.dockerenv"
  cat >"$fake_root/proc/1/cgroup" <<'EOF'
12:pids:/docker/abc123
EOF
  output="$(SIM_TEST_VIRT=container run_script "$fake_root" "$stub_dir" --groups host,containers)"
  assert_contains "$output" "Context: inside-container" &&
    assert_contains "$output" "SKIPPED: block device enumeration inside container"
}

test_runtime_markers_are_reported_on_host() {
  local fake_root="$TEST_TMP/runtime-root"
  local stub_dir="$TEST_TMP/runtime-bin"
  local output
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  : >"$fake_root/var/run/docker.sock"
  : >"$fake_root/run/containerd/containerd.sock"
  mkdir -p "$fake_root/etc/rancher/k3s"
  : >"$fake_root/etc/rancher/k3s/k3s.yaml"
  output="$(run_script "$fake_root" "$stub_dir" --groups containers)"
  assert_contains "$output" "Container runtimes detected: docker, podman, containerd" &&
    assert_contains "$output" "Kubernetes markers detected: k3s-config"
}

test_safe_mode_skips_noisy_process_and_network_activity() {
  local fake_root="$TEST_TMP/safe-root"
  local stub_dir="$TEST_TMP/safe-bin"
  local output
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  output="$(run_script "$fake_root" "$stub_dir" --groups process,network --safe-mode --skip-child-process)"
  assert_contains "$output" "SKIPPED: child shell execution simulation disabled" &&
    assert_contains "$output" "SKIPPED: HTTP beacon simulation suppressed by safe mode"
}

test_inline_shell_output_is_clean() {
  local fake_root="$TEST_TMP/inline-root"
  local stub_dir="$TEST_TMP/inline-bin"
  local output
  make_fake_root "$fake_root"
  make_stub_env "$stub_dir"
  output="$(run_script "$fake_root" "$stub_dir" --groups process,interpreters)"
  assert_contains "$output" "child-shell: child-shell-ok" &&
    assert_contains "$output" "shell-inline: inline-shell-ok" &&
    [[ "$output" != *"child-shell: child-shell-okn"* ]] &&
    [[ "$output" != *"shell-inline: inline-shell-okn"* ]]
}

run_test() {
  local name="$1"
  shift
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

run_test "help lists linux groups" test_help_lists_linux_groups
run_test "invalid group is rejected" test_rejects_invalid_group
run_test "routable endpoint is rejected" test_rejects_routable_endpoint
run_test "log cleanup happens without keep-log" test_log_cleanup_happens_without_keep_log
run_test "container context skips host-only probe" test_container_context_skips_host_only_probe
run_test "runtime markers are reported on host" test_runtime_markers_are_reported_on_host
run_test "safe mode skips noisy process and network activity" test_safe_mode_skips_noisy_process_and_network_activity
run_test "inline shell output is clean" test_inline_shell_output_is_clean

echo "$PASS_COUNT passing"
if [ "$FAIL_COUNT" -ne 0 ]; then
  echo "$FAIL_COUNT failing"
  exit 1
fi
