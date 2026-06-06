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
# Resident KV cache is pinned BF16, NOT fp8. Basis: E1 (forum-reported FP8-KV instability —
# 4/8 failed runs vs 1/8 with BF16 KV; see docs/research/2026-06-06-forum-harvest.md).
# FP8-KV is allowed ONLY behind a passing P9 golden-set eval. BF16 KV = OMIT --kv-cache-dtype
# (vLLM default `auto` resolves to native/bf16 KV; vLLM has no literal `bf16` value for the flag).
# TODO(verify-on-arrival): apply the whpthomas chat-template patch on Qwen3.6 (E2).
# TODO(verify-on-arrival): export HF_HUB_OFFLINE=1 once weights are cached (E3; fits deny-by-default egress).
COMMON=(nvidia/Qwen3.6-35B-A3B-NVFP4 --port "$RESIDENT_PORT"
  --tensor-parallel-size 1 --max-num-seqs 4 --max-model-len 32768
  --gpu-memory-utilization 0.45 --enable-prefix-caching --trust-remote-code)

start_plain() {
  log "starting Qwen3.6 resident (no MTP)…"
  vllm serve "${COMMON[@]}"
}

if [ "${MTP:-0}" = "1" ]; then
  log "MTP=1 requested — attempting speculative-decoding variant (experimental)…"
  # Capture failure explicitly; on ANY non-zero, fall back to the plain config and alert.
  # TODO(verify-on-arrival): num_speculative_tokens=3 is the community-tested MTP value (E4);
  # set it in --speculative-config once confirmed on the installed build.
  if ! vllm serve "${COMMON[@]}" --speculative-config '{"method":"mtp"}'; then
    warn "MTP variant failed — falling back to non-MTP resident config (not load-bearing)."
    if [ -n "${SLACK_WEBHOOK:-}" ]; then
      # best-effort alert; on failure we warn (not silent) and still fall back below
      curl -fsS -X POST -H 'Content-Type: application/json' \
        -d '{"text":"spark: Qwen MTP variant crashed; fell back to non-MTP resident."}' \
        "$SLACK_WEBHOOK" || warn "Slack MTP-fallback alert failed to post"
    fi
    start_plain
  fi
else
  start_plain
fi
# TODO(verify-on-arrival): confirm the exact eugr MTP/speculative flag for the installed build.
