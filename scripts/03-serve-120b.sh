#!/usr/bin/env bash
# 03 — Serve GPT-OSS-120B MXFP4 (heavy, ON-DEMAND) on :8002. Flush caches first (05), then serve via
# the eugr CUTLASS MXFP4 path (avoids the sm_121 Marlin wrong-first-token bug #37030). TP MUST be 1.
# (R1) Idempotent on the HEAVY port: if :8002 already serves, do nothing. Resident Qwen lives on :8001
# (scripts/04) — one vllm process = one port, so the two models MUST use distinct ports.
# Supervision: run under tmux/systemd/a container (vllm serve blocks the foreground). Phase-1 upgrade
# path: front :8001/:8002 with llama-swap (:28080) behind LiteLLM (:14000) for on-demand swapping
# (master plan §2), then point openclaw.json's baseUrls at the router.
. "$(dirname "$0")/lib/common.sh"
require_cmd vllm

HEAVY_PORT="${HEAVY_PORT:-8002}"
if port_open 127.0.0.1 "$HEAVY_PORT"; then
  log "heavy tier already up on :$HEAVY_PORT — not starting 120B"
  exit 0
fi

log "flushing caches before the heavy load…"
"$(dirname "$0")/05-drop-caches.sh"

# TODO(verify-on-arrival): pin the eugr image/wheel (cu132) or NGC digest; confirm flags on the build.
#
# Engine alternative — the eugr build's launcher serves the same model; recorded here so the operator can
# swap engines without re-deriving the MXFP4 flag set (keep the `vllm serve` below as the canonical interface):
#   ./launch-cluster.sh --solo --exp-mxfp4 --mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head
log "starting GPT-OSS-120B MXFP4 on :$HEAVY_PORT (TP=1, CUTLASS MXFP4 path)…"
vllm serve openai/gpt-oss-120b \
  --port "$HEAVY_PORT" \
  --tensor-parallel-size 1 \
  --max-num-seqs 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --enable-prefix-caching \
  --enable-chunked-prefill \
  --reasoning-parser gpt-oss --tool-call-parser gpt-oss
