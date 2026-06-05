#!/usr/bin/env bash
# 06 — (run on your Mac) SSH tunnel to the dashboard. The gateway origin check requires the
# EXACT origin 127.0.0.1:18789 (localhost != 127.0.0.1), so we always forward to 127.0.0.1.
# Idempotent: if local :18789 already serves, the tunnel is already up.
. "$(dirname "$0")/lib/common.sh"

DGX_HOST="${DGX_HOST:?set DGX_HOST=<user>@<DGX_LAN_IP> (or a Tailscale name)}"
if port_open 127.0.0.1 18789; then
  log "127.0.0.1:18789 already reachable — tunnel likely up"
  exit 0
fi

log "opening tunnel: 127.0.0.1:18789 -> ${DGX_HOST}:127.0.0.1:18789  (Ctrl-C to close)"
log "then open http://127.0.0.1:18789/ in your browser"
exec ssh -N -L 18789:127.0.0.1:18789 "$DGX_HOST"
