#!/usr/bin/env bash

SIM_OK_COUNT=0
SIM_SKIPPED_COUNT=0
SIM_ERROR_COUNT=0
SIM_CURRENT_GROUP=""
SIM_CURRENT_TTP=""
SIM_CURRENT_STATE="OK"

sim_init_common() {
  SIM_OK_COUNT=0
  SIM_SKIPPED_COUNT=0
  SIM_ERROR_COUNT=0
}

sim_stderr() {
  printf '%s\n' "$*" >&2
}

sim_now() {
  date '+%H:%M:%S'
}

sim_write_line() {
  local line="$1"
  printf '%s\n' "$line"
  if [ -n "${SIM_LOG_PATH:-}" ]; then
    printf '%s\n' "$line" >>"$SIM_LOG_PATH"
  fi
}

sim_note() {
  local group="$1"
  local ttp="$2"
  local message="$3"
  sim_write_line "[$(sim_now)] [$group] [$ttp] $message"
}

sim_setup_logging() {
  SIM_LOG_PATH="${1:-}"
  SIM_KEEP_LOG="${2:-0}"
  if [ -n "$SIM_LOG_PATH" ]; then
    : >"$SIM_LOG_PATH"
  fi
  trap sim_cleanup EXIT
}

sim_cleanup() {
  if [ -n "${SIM_LOG_PATH:-}" ] && [ "${SIM_KEEP_LOG:-0}" -ne 1 ]; then
    rm -f "$SIM_LOG_PATH"
  fi
}

sim_join_by() {
  local sep="$1"
  shift
  local out=""
  local item=""
  for item in "$@"; do
    if [ -z "$out" ]; then
      out="$item"
    else
      out="$out$sep$item"
    fi
  done
  printf '%s' "$out"
}

sim_append_csv_unique() {
  local current="$1"
  local item="$2"
  case ",$current," in
    *,"$item",*)
      printf '%s' "$current"
      ;;
    ,,)
      printf '%s' "$item"
      ;;
    *)
      printf '%s,%s' "$current" "$item"
      ;;
  esac
}

sim_file_path() {
  local path="$1"
  if [ -n "${SIM_TEST_ROOT:-}" ]; then
    printf '%s%s' "$SIM_TEST_ROOT" "$path"
  else
    printf '%s' "$path"
  fi
}

sim_file_exists() {
  [ -e "$(sim_file_path "$1")" ]
}

sim_read_file() {
  local path
  path="$(sim_file_path "$1")"
  if [ -r "$path" ]; then
    cat "$path"
  else
    return 1
  fi
}

sim_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

sim_validate_c2_endpoint() {
  local uri="$1"
  local rest=""
  local hostport=""
  local host=""
  case "$uri" in
    http://*|https://*)
      ;;
    *)
      sim_stderr "C2 endpoint must be an absolute http(s) URI ending in .invalid"
      return 1
      ;;
  esac
  rest="${uri#*://}"
  hostport="${rest%%/*}"
  host="${hostport%%:*}"
  case "$host" in
    *.invalid)
      return 0
      ;;
    *)
      sim_stderr "C2 endpoint host must end with .invalid"
      return 1
      ;;
  esac
}

sim_log_block() {
  local label="$1"
  local data="$2"
  local max_lines="${3:-3}"
  local count=0
  local line=""
  [ -z "$data" ] && return 0
  while IFS= read -r line; do
    count=$((count + 1))
    [ "$count" -le "$max_lines" ] || break
    sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "$label: $line"
  done <<EOF
$data
EOF
}

sim_mark_skip() {
  SIM_CURRENT_STATE="SKIPPED"
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "SKIPPED: $1"
  return 0
}

sim_mark_error() {
  SIM_CURRENT_STATE="ERROR"
  sim_note "$SIM_CURRENT_GROUP" "$SIM_CURRENT_TTP" "ERROR: $1"
  return 1
}

sim_require_root_extra() {
  if [ "${SIM_ROOT_EXTRAS:-0}" -ne 1 ]; then
    sim_mark_skip "root extras not requested"
    return 1
  fi
  if [ "${SIM_IS_ROOT:-0}" -ne 1 ]; then
    sim_mark_skip "root extras requested but current user is not root"
    return 1
  fi
  return 0
}

sim_run_technique() {
  local group="$1"
  local func="$2"
  local title="$3"
  local ttp="$4"
  local expected="$5"
  local rc=0

  SIM_CURRENT_GROUP="$group"
  SIM_CURRENT_TTP="$ttp"
  SIM_CURRENT_STATE="OK"

  sim_note "$group" "$ttp" "$title"
  [ -n "$expected" ] && sim_note "$group" "$ttp" "EXPECTED: $expected"

  "$func"
  rc=$?

  if [ "$rc" -ne 0 ]; then
    SIM_CURRENT_STATE="ERROR"
  fi

  case "$SIM_CURRENT_STATE" in
    OK)
      SIM_OK_COUNT=$((SIM_OK_COUNT + 1))
      ;;
    SKIPPED)
      SIM_SKIPPED_COUNT=$((SIM_SKIPPED_COUNT + 1))
      ;;
    ERROR)
      SIM_ERROR_COUNT=$((SIM_ERROR_COUNT + 1))
      ;;
  esac

  sim_note "$group" "$ttp" "STATUS: $SIM_CURRENT_STATE"
  return 0
}
