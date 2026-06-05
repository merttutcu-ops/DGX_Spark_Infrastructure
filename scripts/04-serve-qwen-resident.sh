#!/usr/bin/env bash
# 04 — Serve Qwen3.6-35B-A3B NVFP4 (routine, ALWAYS-RESIDENT) on :8001 via the eugr/Marlin backend
# (upstream vLLM still lacks the SM12x NVFP4 fix — PR #35947 closed unmerged). Needs the
# Transformers-5.x build (eugr build-and-copy.sh --tf5).
# (R1) Resident on :8001; the on-demand 120B uses :8002 (scripts/03) — distinct ports, one process each.
# Supervision: this is ALWAYS-ON, so run it under tmux/systemd/a container — NOT a blocking foreground
# shell that dies with your SSH session. (Phase-1 upgrade: llama-swap+LiteLLM, master plan §2.)
# MTP is OPTIONAL and FALLBACK-GUARDED — never load-bearing (NVFP4 spec-decode can crash).
. "$(dirname "$0")/lib/common.sh"
require_cmd vllm

RESIDENT_PORT="${RESIDENT_PORT:-8001}"
COMMON=( nvidia/Qwen3.6-35B-A3B-NVFP4 --port "$RESIDENT_PORT"
  --tensor-parallel-size 1 --max-num-seqs 4 --max-model-len 32768
  --gpu-memory-utilization 0.45 --kv-cache-dtype fp8 --enable-prefix-caching --trust-remote-code )

start_plain() { log "starting Qwen3.6 resident (no MTP)…"; vllm serve "${COMMON[@]}"; }

if [ "${MTP:-0}" = "1" ]; then
  log "MTP=1 requested — attempting speculative-decoding variant (experimental)…"
  # Capture failure explicitly; on ANY non-zero, fall back to the plain config and alert.
  if ! vllm serve "${COMMON[@]}" --speculative-config '{"method":"mtp"}'; then
    warn "MTP variant failed — falling back to non-MTP resident config (not load-bearing)."
    [ -n "${SLACK_WEBHOOK:-}" ] && curl -fsS -X POST -H 'Content-Type: application/json' \
      -d '{"text":"spark: Qwen MTP variant crashed; fell back to non-MTP resident."}' "$SLACK_WEBHOOK" || true  # alert is best-effort; N=1 webhook, failure mode = no Slack ping (already logged above)
    start_plain
  fi
else
  start_plain
fi
# TODO(verify-on-arrival): confirm the exact eugr MTP/speculative flag for the installed build.
