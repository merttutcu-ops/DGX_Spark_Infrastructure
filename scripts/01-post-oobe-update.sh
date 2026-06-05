#!/usr/bin/env bash
# 01 — Post-OOBE system update (aarch64 DGX OS). OTA is deferred by default on the June 2026
# release, so we pull updates deliberately, then confirm the driver/CUDA baseline.
# Idempotent: re-running just re-checks; the apt step is confirmed before it runs.
. "$(dirname "$0")/lib/common.sh"

[ "$(uname -m)" = "aarch64" ] || warn "expected aarch64 DGX OS; uname -m = $(uname -m)"

log "Current driver / CUDA:"
require_cmd nvidia-smi; nvidia-smi --query-gpu=driver_version --format=csv,noheader || warn "nvidia-smi query failed"
if command -v nvcc >/dev/null 2>&1; then nvcc --version | tail -2; else warn "nvcc not on PATH yet"; fi

run_destructive "apt update + full-upgrade (pull deferred OTA/OS updates)" \
  sudo sh -c 'apt-get update && apt-get -y full-upgrade'

# Assert the expected baseline; warn (do not fail) so the operator decides.
DRV="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)"
case "$DRV" in 580.*) log "driver on 580 branch: $DRV";; *) warn "driver not on 580 branch (got '$DRV') — 570 is EOL; verify";; esac
# TODO(verify-on-arrival): confirm DGX OS build (7.5.x line) and CUDA 13.x via `nvcc --version`.
log "01 complete. Next: scripts/02-nemoclaw-install.sh"
