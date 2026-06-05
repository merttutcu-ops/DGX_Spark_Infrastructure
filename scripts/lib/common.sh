#!/usr/bin/env bash
# Shared helpers for spark-agent-infra scripts. Source me: . "$(dirname "$0")/lib/common.sh"
# Strict mode so a failed command never silently passes (operator silent-failure rule).
set -euo pipefail

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# confirm "message" — returns 0 if the user types y/Y, else 1. ASSUME_YES=1 skips the prompt.
confirm() {
  if [ "${ASSUME_YES:-0}" = "1" ]; then log "ASSUME_YES=1, proceeding: $1"; return 0; fi
  printf '%s [y/N] ' "$1"; read -r _ans; [ "${_ans:-}" = "y" ] || [ "${_ans:-}" = "Y" ]
}

# run_destructive "description" cmd args... — echoes the exact command, confirms, then runs it.
run_destructive() {
  local desc="$1"; shift
  log "DESTRUCTIVE: $desc"
  printf '  -> %s\n' "$*"
  confirm "Run this?" || die "aborted by user"
  "$@"
}

# idempotency helper: returns 0 if a TCP port already serves on host (so we can skip re-launch).
port_open() { local host="$1" port="$2"; (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null && { exec 3>&-; return 0; } || return 1; }
