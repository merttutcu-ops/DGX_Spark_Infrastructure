#!/usr/bin/env bash
# 05 — UMA page-cache flush ritual. On unified memory you can hit OOM within capacity;
# NVIDIA's vLLM troubleshooting directs this flush between model swaps and before loading 120B.
. "$(dirname "$0")/lib/common.sh"
run_destructive "flush page cache (sync; drop_caches=3) — affects the whole system's buffer cache" \
  sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
log "page cache flushed."
