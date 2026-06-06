# ADR 0001 — Serving engine: evaluate Atlas on the resident tier only; keep vLLM as the baseline

- **Status:** Accepted — the serving-engine decision for *both* tiers stays **vLLM** until the day-1 bake-off below promotes Atlas on the resident tier.
- **Date:** 2026-06-06
- **Deciders:** Operator (Mert)
- **Relates to:** `docs/master-plan.md` §2 (vLLM engine — a locked, adversarially-verified decision), `docs/proposals/operating-workflow-improvements.md` (P1–P5), `docs/proposals/enterprise-maturity-proposals.md` (P6–P14)
- **Tags:** `flagged-evaluation` · does **not** change any locked decision (hardware, three-tier model split, GPT-OSS-120B heavy model).

## Context

[Atlas](https://atlasinference.io/) (`Avarok-Cybersecurity/atlas`, pure-Rust, AGPL-3.0) is a DGX-Spark-specific LLM inference engine — a direct competitor to **vLLM**, which our serving layer is locked on. It markets a single ~2.5 GB binary, <2-min cold start, native NVFP4/FP8 SM120/121 kernels, working MTP, and "3× faster than vLLM."

Two questions had to be answered before treating it as an improvement: (1) does it serve **our** models, and (2) our system is **8 concurrent agents**, but Atlas's benchmarks are all batch=1 single-stream — does it collapse under concurrency? A 5-agent research sweep (Spark Arena leaderboard, the Atlas Rust source + issues, vLLM Spark benchmarks, and our own repo) was run on 2026-06-06 to answer these on evidence, not marketing.

## Decision

1. **Heavy tier (`:8002`, GPT-OSS-120B MXFP4) → vLLM, permanently.** Atlas cannot serve it (model *and* quant unsupported — see Evidence). No Atlas work here.
2. **Resident tier (`:8001`, Qwen3.6-35B-A3B) → ship on vLLM (eugr Marlin NVFP4); evaluate Atlas as a challenger via the day-1 bake-off.** Promote Atlas to resident production **only if it clears every gate** below.
3. **Locked decisions unchanged.** This ADR is a flagged evaluation; it re-litigates nothing.

## Evidence (2026-06-06)

Legend: **[V]** independently verified (live site / source / our repo) · **[C]** vendor or community claim (unreproduced).

- **[V] On the only apples-to-apples *independent* data point, vLLM is ahead.** Spark Arena, Qwen3.6-35B-A3B-**NVFP4**, single node, Decode: **vLLM 111.92 t/s vs Atlas 102.95 t/s**. Atlas's "3×" is vs *stock* vLLM, not the eugr build we use. (`https://spark-arena.com/leaderboard`)
- **[C] Atlas's headline 157 tok/s** (Qwen3.6-35B-A3B-NVFP4) is a vendor catalogue figure with **MTP K=2**, batch=1 — not reproduced on the leaderboard. (`Avarok-Cybersecurity/atlas-recipes`)
- **[V] Atlas cannot serve the heavy tier — on both axes.** `gpt_oss` is absent from the entire Atlas model matrix / kernel tree / `atlasinference.io` (the only org-wide `gpt-oss` string is a tool-calling test fixture), **and** MXFP4 is not a supported quant — Atlas serves NVFP4/FP8 only, and its own docs cite MXFP4 as the canonical *not-yet-implemented* example. (`atlas/README.md` model matrix; `book/src/crates/atlas-quant.md`)
- **[V] Atlas is NOT batch=1-only.** Its source has a real continuous-batching scheduler (phase-based prefill admission, chunked prefill, fused mixed prefill+decode), paged KV (vLLM-style), RadixAttention prefix caching, and FIFO + SLO-aware (SLAI) policies; `--max-batch-size` default 8, `--max-num-seqs` default 128; the README tunes explicitly for concurrent coding agents. The genuine "force batch=1" clamp existed **only** under multi-node EP=2 (v1 wire protocol) and is fixed behind `ATLAS_EP_PROTOCOL=v2` (PR #101) — irrelevant to our single-Spark case. (`crates/spark-server/src/scheduler/`, issue #99, PR #101)
- **[V] vLLM aggregate throughput scales on Spark:** FP8 ~21→156 t/s and NVFP4 ~57→433 t/s across concurrency 1→32 (sublinear; ~42 % efficiency at c=8); plain NVFP4 single-stream ~50–57 t/s. (rikkarth, stevescargall, vLLM Spark blog)
- **[C/V] The decisive comparison does not exist.** No independent same-model/quant Atlas-vs-vLLM 1→4→8 sweep was found. Atlas's 131→620 t/s sweep is **[C]** vendor-claim; an NVIDIA-forum report **contradicts** it (98.9 t/s aggregate at c=4, *below* single-stream). Only the bake-off resolves this.
- **[V] OPEN crash bug #110 hits exactly our scenario:** hybrid-SSM models (incl. Qwen3.6-35B-A3B-**FP8**) with **MTP active at concurrency ≥4 and ~8K-token context** → CUDA-700 illegal access / SSM slot-leak → **server bricked until restart**. NVFP4-without-MTP handled conc-2/3 deep cleanly per the maintainer. Sibling OPEN #85 affects Mistral MoE. (`Avarok-Cybersecurity/atlas` issues #110, #85)

### The concurrency question, resolved
**Refuted as a design claim, and moot for us either way.** Our system is **not** high-QPS: reading the repo (`--max-num-seqs 4` on both ports, `requireMention:true`, 30 m/1 h heartbeats, pull-based queue, review-stage serialization) the realistic load is **0–2 concurrent streams per tier**, with one capped, async exception — the CEO sub-agent fan-out on the resident model (~3–5 in-flight). So **single-stream tok/s is the dominant metric**; aggregate concurrency scaling is nearly irrelevant here. The concurrency-*correlated crash* (#110), not concurrency *throughput*, is the real gate.

### Condensed decision matrix

| Dimension | Atlas | vLLM | Edge |
|---|---|---|---|
| Single-stream tok/s (resident NVFP4 — our dominant metric) | 102.95 **[V]** / 157 MTP **[C]** | 111.92 **[V]** / ~50–57 plain **[V]** | **Leans vLLM** (measure on-rig) |
| Aggregate @1→8 (low relevance for us) | continuous batching **[V]**; 131→620 **[C]** | 57→433 across c=1→32 **[V]** | vLLM on evidence quality |
| Cold start | ~2 min **[C]** | 5–8 min CUDA-graph **[V]** | Atlas (claimed) |
| Serves GPT-OSS-120B (locked heavy) | **No [V]** | **Yes [V]** | **vLLM, decisively** |
| NVFP4 / SM12x kernels | purpose-built per-model **[V]** | Marlin/cutlass; PR #35947 unmerged **[V]** | Atlas (slight) |
| Tool-calling reliability | claimed **[C]** | mature, wired in scripts/03 **[V]** | vLLM on track record |
| Maturity / trust | ~1–2 mo, single-vendor | mature, multi-vendor | **vLLM** |

## Day-1 bake-off (verify-on-arrival checklist)

Run on the actual rig with `eugr/llama-benchy` (the same harness Spark Arena uses, so results are leaderboard-comparable). Heavy tier is excluded (Atlas can't serve GPT-OSS-120B/MXFP4).

- [ ] **Gate 0 — Pin versions.** vLLM = eugr Marlin NVFP4 on `RedHatAI/Qwen3.6-35B-A3B-NVFP4`, `--tensor-parallel-size 1 --max-num-seqs 4 --max-model-len 32768` (mirror `scripts/04`). Atlas = `sparkrun run @atlas/qwen3.6-35b-a3b-nvfp4` (NVFP4, **MTP off**) *and* `@atlas/qwen3.6-35b-a3b-fp8-mtp` (to trigger #110 deliberately). Same harness on both; engine is the only variable.
- [ ] **Gate 1 — Single-stream tok/s (run first; most likely to fail).** `tg128` at depth 0 / 8192 / 32768, 3 runs, median + variance. **PROMOTE only if Atlas beats the vLLM-Marlin baseline by ≥15 % at ~8K depth.** (Leaderboard suggests Atlas may *lose* single-stream — be ready to stop here.)
- [ ] **Gate 2 — Concurrency sweep 1→4→8** at depth ~8192: aggregate tok/s, per-request tok/s, p95 latency, TTFT p95. **At N=4** Atlas aggregate ≥ vLLM and p95 ≤ vLLM ×1.25; **at N=8** neither hangs. **ABSOLUTE BLOCKER:** repeat N=4/N=8 deep on the **FP8+MTP** config to trigger #110 — any crash/brick disqualifies that config.
- [ ] **Gate 3 — Tool-calling reliability:** ≥200 real agent tool-call turns through each engine; **Atlas malformed-call rate ≤1 % and not worse than vLLM.** Hard blocker regardless of throughput.
- [ ] **Gate 4 — Cold start:** end-to-end `serve` → first-token-ready, cold and warm. **Atlas ≤ vLLM.** (Lower weight — resident is always-on.)
- [ ] **Gate 5 — Soak (30–60 min):** replay Phase-2 resident traffic (1–2 steady + periodic ~4-wide bursts). **No latency creep, no memory growth to OOM, no restart** (probes #110 slot-leak).

**Promotion rule:** adopt Atlas on the resident tier **only if Gates 1–5 all pass**. Any crash (G2/G5), tool-call regression (G3), or single-stream loss (G1) → **stay on vLLM, re-test in ~1 month.** If Atlas wins while #110 is still open, deploy **NVFP4-without-MTP only** and cap resident fan-out width <4.

## Consequences

- **Positive:** decision is evidence-gated, not hype-driven; vLLM (proven for both our models) ships day-1; the OpenAI-compatible interface makes a later resident-tier flip a small change (`scripts/04` + the `openclaw.json` baseUrl); Atlas's purpose-built SM12x NVFP4 kernels are a real potential edge over vLLM's rough sm_121 path (the master plan's #1 serving risk, PR #35947).
- **Negative / watch:** if Atlas is promoted, we maintain *two* engines (vLLM heavy + Atlas resident) and inherit a ~1–2-month-old single-vendor dependency; re-evaluate on each Atlas release. Atlas's native Mamba-2 kernels could unblock **Nemotron-3** as a heavy model — noted only for if the locked heavy-model decision is ever revisited; it is **not** reopened here.

## Sources

`https://atlasinference.io/` · `https://spark-arena.com/leaderboard` · `github.com/Avarok-Cybersecurity/atlas` (README, `scheduler/`, `atlas-quant.md`, issues #99/#101/#110/#85) · `github.com/Avarok-Cybersecurity/atlas-recipes` · `github.com/eugr/llama-benchy` · `github.com/spark-arena/recipe-registry` · rikkarth / stevescargall vLLM-Spark NVFP4 benchmarks · `vllm.ai/blog/2026-06-01-vllm-dgx-spark`.
