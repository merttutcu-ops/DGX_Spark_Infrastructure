# Forum-research harvest — 2026-06-06

Evidence registry from end-to-end reads of NVIDIA Developer Forum **DGX Spark / GB10** threads
(Qwen3.6-35B mega-thread, 122B-A10B v2.1 thread, NVFP4 PSA + "bought 9" threads, tool-calling
thread, GPT-OSS mxfp4 build thread, harness threads, NemoClaw regression thread; Apr 2025 – Jun 2026).

**Status:** every item is **community-reported** unless explicitly marked otherwise. This file is
**provenance only** — the *actionable* landing of each item is in the "Landed in" column; nothing here
changes a decision by itself, and no locked decision is flipped anywhere in this harvest.

| ID | Finding | Status | Landed in |
|---|---|---|---|
| **E1** | FP8 KV cache ≈2× decode but unstable (4/8 failed runs vs 1/8 BF16 KV; paxren2020). On the 122B, FP8-KV gained only +0.2 tok/s (noise — see E13). Atlas research separately flagged FP8+MTP unsafe. Three sources → **BF16 KV for agents.** | community-reported (3 sources converge) | CLAUDE.md pin (T1a); `scripts/04` (T3) |
| **E2** | whpthomas chat-template patch still recommended on Qwen3.6. | community-reported | master-plan VOA (T2c); `scripts/04` comment (T3) |
| **E3** | `HF_HUB_OFFLINE=1` once weights are cached — also fits deny-by-default egress. | community-reported | master-plan VOA (T2c); `scripts/04` comment (T3) |
| **E4** | MTP sweet spot `num_speculative_tokens` = 2–3; community favors **3**. | community-reported | master-plan VOA (T2c); `scripts/04` comment (T3) |
| **E5** | DFlash (z-lab draft model, ~15 speculative tokens; 65→80 t/s reports) — 2nd spec-decode option; requires vLLM **PR #40898** (sliding-window attn for the drafter); optional-with-fallback, never load-bearing. | community-reported | master-plan VOA (T2c); ADR-0001 bake-off variant (T6) |
| **E6** | llama-benchy **under-reports** throughput when MTP/spec-decode is active (eugr + joshua.dale.warner) — any spec-decode benchmark needs a 2nd measurement method. | community-reported | ADR-0001 measurement amendment (T6) |
| **E7** | Realistic single-stream baseline **75–95 t/s**, Qwen3.6-35B-A3B, one Spark. | community-reported | master-plan VOA (T2c) |
| **E8a** | Resident-model **thinking loops** under agentic load — sampling helps; endpoint-switch helped some BUT Claude Code ≥2.1.154 is reported broken vs vLLM's Anthropic-compat endpoint (trapdoor); cross-harness (Hermes same mid-task stall; `/goal` partial nudge) → model/serving-layer, not harness-specific. | community-reported | failure-modes #5 (T4a) |
| **E8b** | **Malformed tool calls** (HTML junk in tool args) under agentic load. | community-reported | failure-modes #6 (T4b) |
| **E9** | apt/kernel/driver upgrades **repeatedly brick** the NVIDIA driver stack on Spark (multiple threads incl. kernel 6.17.0-1021 warning). | community-reported | failure-modes #7 (T4c); devops prohibition (T5) |
| **E12** | NVFP4 on GB10 went broken→functional spring 2026 (PR **#38126** "Fix DGX Spark logic"; FlashInfer **0.6.8.post1**; CUTLASS **4.5.0** Block-Scaled MMA "b12x"). Functional ≠ fastest: SM121 is bandwidth-bound (273 GB/s); AWQ/AutoRound-INT4 often outruns NVFP4; FP8 wins quality vs AWQ; NVFP4 wins footprint → **three-axis tradeoff, sweep-decided.** | community-reported (PR #38126 noted) | CLAUDE.md annotation (T1b); master-plan sweep (T2a) + bandwidth note (T2d) |
| **E13** | 122B-A10B v2.1 thread (Albond, 413 posts) = canonical single-box heavy build: 28→51 tok/s via hybrid INT4+FP8 + INT8 LM head + MTP-2 (~95% accept), 256K ctx, one-command `install.sh` (post #104). "Didn't help": FP8-KV noise; NVFP4 < INT4 (then); Marlin rewrite pointless (bandwidth-bound); EAGLE-3 < built-in MTP. TurboQuant-KV: −22% speed for 4× context/concurrency. | community-reported | master-plan heavy-tier Plan-B (T2f) |
| **E14** | paxren2020 controlled tests: **no** template/parser/endpoint combo fully stabilized agentic tool use; recent vLLM changes **alone** reached 100% tool-eval on 3.5-122B and 3.6-35B → **upstream vLLM version is the controlling variable.** Parsers: `qwen3xml` works-for-some / errors-for-others ("Expected function.name to be a string"); `qwen3coder` + enhanced jinja template is the viable alternative. | community-reported | CLAUDE.md pin (T1c); master-plan tool-eval gate (T2b) |
| **E15** | GPT-OSS mxfp4 build failure ladder: CUTLASS SHA mismatch (edit `Dockerfile.mxfp4` ~L101 / alt SHA); "Failed to download cubins" (comment out flashinfer-cubin / jit-cache `RUN` steps, or `docker builder prune -f` + rebuild); clear `~/.triton` `~/.cache/vllm` `~/.cache/flashinfer`; eugr `--clean`; raphael.amorim prebuilt Docker Hub image "just works" for GPT-OSS-20B/120B (digest-pin if used as fallback). | community-reported | failure-modes #8 (T4d) |
| **E16** | Claim that NVIDIA's roadmap drops OpenClaw support, Hermes favored (karol.spark). | **single-source, UNVERIFIED** | master-plan harness watch (T7) |
| **E17** | OS release **2026.05.31 (v1.135.34)** implicated in NemoClaw agents breaking (`tool_search_code` error) and cron jobs unscheduleable. | community-reported, **unresolved upstream** | master-plan scheduling test (T2e); failure-modes #9 (T4e) |

> E10/E11 are intentionally absent — source triage consolidated them out; numbering is preserved from the harvest.
