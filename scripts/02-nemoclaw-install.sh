#!/usr/bin/env bash
# 02 — Non-interactive NemoClaw + OpenShell install. Uses --non-interactive to avoid the
# curl|bash EOF gotcha (#362) that half-initializes the gateway (later EADDRINUSE on 8080).
# Idempotent: skips install if `nemoclaw` already present; always re-verifies the gateway.
. "$(dirname "$0")/lib/common.sh"

: "${NVAPI_KEY:?set NVAPI_KEY (nvapi- key from build.nvidia.com) before running}"

if command -v nemoclaw >/dev/null 2>&1; then
  log "nemoclaw already installed: $(nemoclaw --version 2>/dev/null || echo unknown) — skipping install"
else
  run_destructive "download + run the NemoClaw installer (network fetch, runs as bash)" \
    bash -c 'curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash -s -- --non-interactive'
fi

# Verify the dashboard gateway is reachable on the exact loopback origin (127.0.0.1, NOT localhost).
if port_open 127.0.0.1 18789; then
  log "gateway up on 127.0.0.1:18789"
else
  warn "gateway not answering on 127.0.0.1:18789 — check onboard state"
  # Not silently swallowed: surface the likely EADDRINUSE/half-init path for the operator.
  warn "if onboard skipped the sandbox-name prompt, re-run onboard non-interactively; check port 8080 for a stale gateway"
fi
# TODO(verify-on-arrival): pin NemoClaw by tag v0.0.59 or commit SHA (it is a git tag, not a Release).
log "02 complete. Apply config/openshell-policy.yaml and config/openclaw.json next."
