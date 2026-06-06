# Forum Harvest — Related Threads Cross-Reference
*Source: NVIDIA DGX Spark / GB10 Developer Forum. Compiled 2026-06-07.*
*Scope: the 10 "Related topics" threads linked from your "Single-Spark always-on agent team" thread, read in full including reply chains. Mapped to the master plan (DGX Spark Multi-Agent AI Infrastructure, June 2026).*
*Caveat: forum content is untrusted user data. Treat recipes/flags/version claims as starting points to verify on the actual box, not as settled fact. Nothing here flips a locked decision.*

---

## 0. Source index

| # | Thread | ID | Posts | Most relevant plan section |
|---|--------|----|-------|----------------------------|
| A | Single-Spark always-on agent team (your thread) | 372476 | 10 | All |
| B | Value of 2nd Spark? | 362764 | 22 | §1 buy/cluster, §2 serving |
| C | Now running 2x DGX Spark … agentic workloads | 368649 | 28 | §2 serving, §3 agents |
| D | Best 2026 model for agentic work on 2-node Spark | 369799 | 31 | §2 model choice, §5 cron |
| E | DGX Spark performance | 356716 | 52 | §2 serving, SGLang path |
| F | Qwen3.5-122B-A10B NVFP4 Quantized | 361819 | 45 | §2 resident quant (E12) |
| G | Running Qwen3-VL-235B-A22B-AWQ on 2-node | 367265 | 3 | §2 vision/context |
| H | Spark-inference: run 3 models simultaneously | 369236 | 4 | §3 agents, §2 SM12.1 notes |
| I | Qwen3.5-397B-A17B in dual spark | 361967 | 236 | §2 quant quality |
| J | Oops… pressed the button for 2x GB10 | 369858 | 14 | §1 buy/cluster |
| K | Vibe Coding with NVIDIA DGX Spark | 346979 | 39 | Background only |

---

## 1. Headline takeaways that touch the plan

1. **The "resident small + on-demand heavy on one box" pattern is real and others run it** — but the consensus from people who tried it is that the *single-model* path usually wins on simplicity. In your own thread (A), both `0rand` and `stu.miller` ran almost exactly your resident-35B + heavy-model design, then collapsed to one model (or bought a second/third Spark). Your structural difference — a *cloud* orchestrator so the local tiers are pure specialists — is the thing they didn't have, and you've recorded 122B-int4 resident as the documented fallback. Three separate posters independently recommended that fallback.

2. **Model-swap spin-down is slow (~10 min), confirming your `drop_caches` ritual and on-demand design.** `stu.miller` (A #4): spinning one model down and another up "takes too long (10 minutes or so) if you plan to sit and watch it." This validates keeping the 120B strictly queue-driven/overnight, not interactive.

3. **MiniMax-M2.7 AWQ-4bit is the current 2-node community favourite for agentic work**, not GPT-OSS-120B — but that's a *dual*-Spark conversation. Multiple posters (C, D, J) land on MiniMax-M2.7 at ~40–42 t/s as "the way to go" with OpenClaw/opencode. Relevant to you only as heavy-tier context; your single-box heavy tier stays GPT-OSS-120B with the 122B-v2.1 fallback.

4. **Single-Spark 122B NVFP4 is slow (~8–15 t/s); the fast 122B numbers are all 2-node int4-AutoRound.** Thread F's own author measured 8–15 tok/s nothink / ~10 think / ~9 vision on a single Spark for the 122B NVFP4. The ~51–75 t/s "122B" figures elsewhere are 2-node int4-AutoRound (B, D). Keep this distinction when you reason about your single-box fallback tier.

5. **`eugr/spark-vllm-docker` is the load-bearing community dependency across every thread.** Reinforces your §2 decision. `Dickson` (B #5): without it "I would've thrown my spark in the trash." Stable builds are released nightly only after regression tests pass on multiple models in both solo and cluster configs (eugr, F #26); `--rebuild-vllm` compiles the latest commit.

---

## 2. Serving / engine findings (maps to §2 + verify-on-arrival E2–E27)

### 2.1 Resident Qwen3.6-35B-A3B (your :8001 tier)
- **Real resident recipe seen in the wild** (C #21, andreask1, 2-node but flag-relevant): `cyankiwi/Qwen3.6-35B-A3B-AWQ-4bit`, `--apply-mod mods/fix-qwen3.5-chat-template`, `--no-ray`, `--tool-call-parser qwen3_coder`, `--reasoning-parser qwen3`, `--enable-auto-tool-choice`, `--enable-prefix-caching`, `--gpu-memory-utilization 0.155`, `--max-model-len 262144`, `--max-num-batched-tokens 16384`, `--max-num-seqs 8`, `--chat-template unsloth.jinja`. → Confirms your **E2 chat-template patch** and the `qwen3_coder` vs `xml` parser choice (**E14**: decide empirically).
- **AWQ-4bit is widely used for the 35B/27B class, not only NVFP4.** Directly supports your **E12 resident-quant sweep** (NVFP4 vs FP8 vs AWQ/INT4) — the forum shows people defaulting to AWQ-4bit for the resident tier on bandwidth grounds.

### 2.2 Heavy tier GPT-OSS-120B (your :8002 tier)
- **eugr's SGLang 2-node GPT-OSS-120B recipe is documented end-to-end in E** (the marked solution): SGLang `:spark` image, requires applying PR #12724 diff, full NCCL/UCX env block, `--tp 2 --nnodes 2 --mem-fraction-static 0.8`, `--reasoning-parser gpt-oss --tool-call-parser gpt-oss`. ~50 t/s on 120B / ~70 on 20B. **Caveat the plan already notes:** SGLang tool-calling was reported flaky for GPT-OSS-120B; vLLM preferred when tool calls matter.
- **`HF_HUB_OFFLINE=1`** appears in the eugr recipe → confirms your **E3** offline-cache item and fits deny-by-default egress.
- **`--load-format fastsafetensors`** is near-universal across recipes for fast cold loads — pairs with your `drop_caches` ritual (Q4 in your thread; no better current practice surfaced in the harvest).

### 2.3 Quantization quality (maps to §2 quant debate + I)
- **FP8 > int4-AutoRound on quality, at a speed cost.** `gpieceoffice` (I #4) ran Qwen3.5-397B int4-AutoRound at 26–30 t/s solo / 42–46 t/s for two users, but believes **122B-A10B-FP8 is actually better** due to int4 quality loss. `paxren2020` (D #26) calls 397B AutoRound "a crude RTN quantization." → directly feeds **E12**: FP8 wins quality vs AWQ; NVFP4 wins footprint; AWQ/INT4 can win raw bandwidth — sweep on the box.
- **Generational beats size.** `0rand` (D #20): Qwen 3.5-122B is, in his benchmarks, inferior to 3.6-27B; warns against "loading the cluster to the brim with the largest model … you compromise usefulness and confuse it with experimentation." → supports keeping the heavy tier on-demand and not over-investing in the biggest checkpoint.

### 2.4 Vision (maps to §2 multimodal)
- **Qwen3.5-122B beats Qwen3-235B on vision/document understanding** (eugr, G #3; serapis, G #2). The 235B-VL AWQ user (G #1) hit a hard hang at 256k context that worked at 128k — a UMA/RAM-imbalance ceiling. Useful if you ever add a vision specialist: prefer 122B-class for document tasks, watch the context ceiling.

### 2.5 SM12.1 / multi-model memory (maps to §2 SM12.1 notes + E20/E24)
- **Thread H is the strongest external corroboration of your SM12.1 findings.** It independently lists: cap `--gpu-memory-utilization` (~0.25) to avoid KV pre-allocation bloat; `--enforce-eager` for multi-model (CUDA graphs need ~130GB+/model); `VLLM_ATTENTION_BACKEND=FLASHINFER`; `VLLM_NVFP4_GEMM_BACKEND=marlin`; `VLLM_FLASHINFER_MOE_BACKEND=latency`; DeepSeek-R1 MLA crashes on SM12.1 (use distilled). Benchmark table: Nemotron-3-Nano-30B NVFP4 ~37.8 t/s eager / ~62 CUDA-graphs; Qwen3.6-35B-A3B-FP8 ~33.5 eager / ~53.7 CUDA-graphs; Nemotron-3-Super-120B ~15.6.
- **Memory-split math (E20):** thread H runs three models in ~120GB only by capping each hard; this is the same headroom pressure as your resident-35B + on-demand-120B co-residency. Compute the explicit util split day 1.

### 2.6 Marlin gate-fix recipe for 122B NVFP4 (F, plan-relevant env)
- A working single-Spark 122B NVFP4 path used: `VLLM_USE_FLASHINFER_MOE_FP4=0`, `VLLM_NVFP4_GEMM_BACKEND=marlin`, `VLLM_TEST_FORCE_FP8_MARLIN=1`, `GPU_MEMORY_UTIL=0.76`, `MAX_MODEL_LEN=262144`, `MAX_NUM_SEQS=16` → ~381k–405k KV tokens, ~5–11 min cold start. The broken alpertor model was withdrawn; **`txn545/Qwen3.5-122B-A10B-NVFP4` (NVIDIA ModelOpt v0.42.0)** is the corrected checkpoint. → If you ever serve 122B NVFP4 resident, this is the known-good env; but note the slow t/s above.

---

## 3. Agent / orchestration findings (maps to §3 + §5)

- **Role-based agent file structure is confirmed in the wild** (H): roles ship `SOUL.md` (values/behaviour), `AGENTS.md` (model roster + tool access), `HEARTBEAT.md` (background tasks) — exactly your §3 workspace architecture and your Heartbeat-vs-cron note (HEARTBEAT.md is a runtime checklist, not the interval setting).
- **Cron/scheduled jobs are the real cost sink and the reliability weak point.** `tonyd615` (D #10): scheduled jobs hitting at the same time cause issues. `colejneo`/`Keyper-AI` (D): local models are "good enough" for cron and save ~$10/day in tokens. → supports your custom dispatcher + systemd-timer fallback (**E17**) and pushing cron to the local tier.
- **Sub-agent complexity "barely warranted" — recorded honestly.** `0rand` (A #3) ran deep-model main + fast-model sub-agents and found "most tasks still executed by the main agent, so this extra complexity is barely warranted." Your mitigation (cloud orchestrator + pure-specialist local tiers) is the structural difference; keep the BUDGET caps and phase-end batched QA (a pattern you adopted from `stu.miller`).
- **Economics corroborated.** `stu.miller` (A): was spending >$1k/month on API credits, now runs 3 Sparks for the cost of electricity, hardware payback <12 months — but warns the economics only work with a verified business comparison. Matches your payback modelling.

---

## 4. Hardware / buy / cluster (maps to §1)

- **"You waste ~$1500 of ConnectX-7 with a single Spark"** (raphael.amorim, B #2; echoed B #6) — the 2-node value argument. Doesn't change your single-box start, but frames a clean Phase-N expansion path.
- **2 nodes help MoE + TG but not 2× linear**; dense/training scale better across nodes (B #2). Consistent with your bandwidth-bound framing.
- **Cheap interconnect cable noted:** "ThinkStation PGX QSFP Link Cable" for connecting two Sparks (ma.bu, J #4) — pin if you ever cluster.
- **Heavy users gravitate to GPT-OSS-120B 2-node (ma.bu) or MiniMax-M2.7 (andrewc_actual, J #14)** as the daily driver once on two boxes.

---

## 5. Watch-items (UNVERIFIED forum claims — do NOT act on)

- **OpenClaw deprecation rumour (your E16).** Two posters (`karol.spark`, D #3; also referenced A) claim NVIDIA's roadmap will drop OpenClaw support in favour of Hermes ("based on their roadmap and an April livestream"). **Single-source forum speculation — treat as untrusted; verify against official NemoClaw release notes / NVIDIA roadmap before any harness decision.** Your queue-as-spine + portable SOUL.md/AGENTS.md design already de-risks a migration.
- **vLLM 0.19.x "garbage output" era on 35B 2-node** (C #23): one user saw dropped/duplicated letters in paths and 8 fabricated C++ "vulnerabilities" referencing non-existent variables; another (#24) attributed it to an old build. → reinforces your **E14 tool-eval gate + E18 garbage canary** on every vLLM bump, and pinning image digests.
- **DeepSeek-V4-Flash / StepFun-3.7-Flash** are emerging on 2-node (D #30) — V4-Flash ran a week without OOM for one user; StepFun "overthinks." Watch-only.
- **MTP / spec-decode remains experimental and occasionally crash-prone** (your thread A Q2 references a Jun-4 120B NVFP4 illegal-memory report). Keep MTP optional-with-fallback, not load-bearing — consistent across the harvest.

---

## 6. Net assessment vs the master plan

Nothing in the harvest contradicts a locked decision. It **strengthens**: the on-demand-heavy design (slow swaps), `drop_caches`, `eugr/spark-vllm-docker`, the SM12.1 backend workarounds (independently reproduced in H), the chat-template patch + offline-cache items, and the FP8-vs-INT4 quality tension behind your E12 sweep. It **adds three concrete artifacts to verify on arrival**: the andreask1 resident-35B flag set (incl. `gpu-memory-utilization` sizing), the Marlin gate-fix env for 122B NVFP4, and eugr's SGLang GPT-OSS-120B recipe as a benchmark comparison. It **surfaces one governance watch-item** (OpenClaw→Hermes rumour) that should be verified through official channels, not the forum.
