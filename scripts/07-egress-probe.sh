#!/usr/bin/env bash
# 07 — Synthetic egress probe (Improvement 1). Runs FROM INSIDE the sandbox on a schedule and
# exercises every hot inference route, alerting to Slack on a policy/proxy 403 (or an unreachable
# always-on route) BEFORE a real agent turn hits it — converting a silent, global, post-update break
# into one early alert.
# (R2) curl is used WITHOUT -f so we capture the real %{http_code}: with -f, a 401/403 becomes curl
# exit 22 -> our code="000" -> a PERMANENT false alarm. The OpenShell policy must grant /usr/bin/curl
# GET-only to :8001/:8002/api.anthropic.com (see config/openshell-policy.yaml `probe:` block). If that
# per-binary/method/path scoping isn't supported on the installed build, reimplement this as a node
# script that reuses the already-allowlisted node binary (TODO(verify-on-arrival)).
# Schedule (example): */10 * * * *  /path/scripts/07-egress-probe.sh   # every 10 min
. "$(dirname "$0")/lib/common.sh"
require_cmd curl

SPARK_IP="${SPARK_IP:?set SPARK_IP=<spark-ip>}"
fail=0

probe() { # name url mode(always_up|on_demand|reachable)
  local name="$1" url="$2" mode="$3" code
  code="$(curl -sS -o /tmp/probe.out -w '%{http_code}' --max-time 8 "$url" 2>/tmp/probe.err)" || code="000"
  case "$mode:$code" in
  *:403)
    warn "probe FAIL: $name -> 403 (OpenShell policy / CONNECT-proxy block)"
    fail=1
    ;;
  always_up:200) log "probe OK: $name (200)" ;;
  always_up:*)
    warn "probe FAIL: $name -> HTTP $code (resident endpoint should be 200)"
    sed 's/^/    /' /tmp/probe.err >&2
    fail=1
    ;;
  on_demand:200) log "probe OK: $name (200, loaded)" ;;
  on_demand:000) log "probe OK: $name (000 = not loaded; route is fine, no 403)" ;;
  on_demand:*)
    warn "probe FAIL: $name -> HTTP $code"
    fail=1
    ;;
  reachable:000)
    warn "probe FAIL: $name -> 000 (unreachable: route/proxy/timeout)"
    fail=1
    ;;
  reachable:*) log "probe OK: $name ($code = reachable)" ;;
  esac
}

probe "vllm-resident:8001" "http://${SPARK_IP}:8001/v1/models" always_up # always-on routine tier
probe "vllm-heavy:8002" "http://${SPARK_IP}:8002/v1/models" on_demand    # 000 = simply not loaded; 403 = real break
if [ -n "${OLLAMA_PROXY:-}" ]; then probe "ollama:11435" "$OLLAMA_PROXY" reachable; fi
probe "anthropic" "https://api.anthropic.com/v1/models" reachable # 401 = reachable (no key here); 403 = blocked

if [ "$fail" = "1" ] && [ -n "${SLACK_WEBHOOK:-}" ]; then
  # N=1 webhook; if this POST fails the only consequence is "no Slack ping" — already logged above, and
  # the nonzero exit below still trips scheduler-level alerting. Not silently swallowed.
  curl -sS -X POST -H 'Content-Type: application/json' \
    -d '{"text":"spark egress-probe FAILED — an inference route returned 403/timeout. Check OpenShell policy + node binary SHA256."}' \
    "$SLACK_WEBHOOK" >/dev/null || warn "could not post Slack alert (webhook failing)"
fi
[ "$fail" = "0" ] || die "egress probe detected a broken route"
log "all egress routes healthy."
