# spark-agent-infra — Agent Constitution

This repo configures an always-on multi-agent system on an NVIDIA DGX Spark
(GB10, 128GB unified, aarch64 DGX OS). It is the single source of truth for
how the agents are configured, secured, and dispatched. `docs/master-plan.md`
is the authority for every version, workaround, and security rule; this file
is the day-to-day operating contract.

## Architecture (one screen)
- **You (operator)** — MacBook + phone. Agents have NO access to your machine,
  banking, password store, or primary email. You talk to the team via Slack/Telegram.
- **DGX Spark (home, always-on)** runs an **OpenShell sandbox** with **deny-by-default
  egress**. Inside: **8 OpenClaw agents** + local models served by **vLLM**.
- **Models (three tiers):** Opus 4.8 (`claude-opus-4-8`) is the **CEO**, via Anthropic API
  (capped). **GPT-OSS-120B MXFP4** is the heavy tier (on-demand): Architect/Coder/QA/Security.
  **Qwen3.6-35B-A3B NVFP4** is the routine tier (always-resident): PA/PM/DevOps.
- **Shared git workspace** is the bridge between you and the agents and the dispatch spine.

## Conventions (binding)
1. **The task queue is the single source of truth.** `tasks/queue/` (one file per task)
   is authoritative. Slack/Telegram channels are a *human-facing projection* of queue
   items (write-through, not a second store). Sub-agents are *ephemeral workers dispatched
   FROM the queue*, never spawned ad hoc; each writes results back to the queue row that
   spawned it. (If Slack dies, dispatch continues from the queue.)
2. **Do not invent versions.** Every version/tag/digest/SKU is pinned per the master plan
   or marked `TODO(verify-on-arrival)` with the command that confirms it. Never substitute
   a guessed or "newer" value.
3. **Workspace files are lean.** SOUL/AGENTS/IDENTITY/MEMORY are prefilled into every turn —
   every line costs tokens forever. Keep them short; compact MEMORY on schedule; never let
   the cached prefix bloat.
4. **Branch model.** `main` is protected (no force-push/rebase). Agents work on per-agent
   branches; a single scribe commits shared-workspace changes. Assert a clean, `git fsck`-valid
   tree before a turn consumes the prefill.
5. **Security floor.** Deny-by-default egress (see `config/openshell-policy.yaml`); never
   connect banking/passwords/primary email; skill auto-update OFF and every skill vetted;
   require human approval for any action derived from untrusted web/email content.
6. **Budgets are hard.** Every task carries BUDGET (tokens/runtime/retries). Agents stop on
   trip. CEO honors the 3-consecutive-failure stop and 10-minute runtime cap.

## Model IDs (do not drift)
- CEO: `anthropic/claude-opus-4-8` — effort ladder low/medium/high/xhigh/max, default **high**.
  No temperature/top_p/top_k (returns 400). Use prompt caching + mid-conversation system messages.
- Heavy: `gpt-oss-120b` (MXFP4, on-demand). Routine: `Qwen3.6-35B-A3B-NVFP4` (resident).
- **Routing ids are provider-qualified** — the scaffold serves the two models on two direct ports
  (no router yet): `vllm-heavy/gpt-oss-120b` on `:8002`, `vllm-resident/Qwen3.6-35B-A3B-NVFP4` on `:8001`.
  llama-swap (+LiteLLM) is the Phase-1 upgrade path (master plan §2) to collapse both behind one endpoint.

## Where things live
- Personas/rules: `agents/<id>/`. Operator profile: `agents/_shared/USER.md`.
- Routing: `config/openclaw.json`. Egress: `config/openshell-policy.yaml`.
- Spark/Mac scripts: `scripts/` (numbered, idempotent, confirm before destructive).
- Ops: `runbooks/`. Dispatch queue + format: `tasks/`.
- Why behind every decision: `docs/master-plan.md`; verification: `docs/plan-review.md`.
- Forum-harvest evidence (E-items): `docs/research/2026-06-06-forum-harvest.md`.

## Pinned versions (mirror of master plan; verify on arrival)
- CUDA: DGX OS baseline **13.0.x** (the OOBE `nvcc`/driver check); eugr wheel + NGC images target **13.2 (cu132)**. NGC vLLM image **`nvcr.io/nvidia/vllm:26.05.post1-py3`** (pin a digest on arrival). **The exact CUDA / driver / vLLM / FlashInfer tuple is pinned FROM the actual build image at install time — these prose versions are superseded by the image (E18/E12).**
- NemoClaw **tag `v0.0.59`** (a git tag, not a Release — pin by tag/commit SHA).
- eugr build wheel **cu132**. **MXFP4 backend is build-scoped (E18):** on the **eugr `--exp-mxfp4` fork**, CUTLASS is the decided fast path (`--mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head`, ~57–59 t/s); on **stock vLLM 0.17.x** the documented known-good fallback is `VLLM_MXFP4_BACKEND=marlin` (and `VLLM_NVFP4_GEMM_BACKEND` does **not** exist in 0.17.1 — silently ignored; **the var's very *existence* is build-scoped (E18/E34/E35):** absent in 0.17.1, yet *used* by working newer-build recipes — thread-H multi-model and the thread-F 122B-NVFP4 Marlin gate-fix both set `VLLM_NVFP4_GEMM_BACKEND=marlin` — a **second exhibit** that backend env vars carry build provenance in their existence, not only their values). **Doctrine:** backend claims carry build provenance; the **active backend is verified from the startup log** ("Using backend: marlin" / "Auto-selected: CUTLASS_FP4"), never inferred from flags.
- **OpenShell node-binary path is measured, not hardcoded (E23):** the policy allowlist keys on the exact `/proc/<pid>/exe` + SHA256, so the wrong path is itself the 403 mode (playbooks use `/usr/bin/node`; our draft used `/usr/local/bin/node`). At setup time write the policy from the **measured** path — `readlink /proc/$(pgrep -fn openclaw)/exe` — and treat the `/usr/local/bin/node` in `config/openshell-policy.yaml` as a placeholder superseded by it.
- Driver **580 branch**. Dashboard origin **`127.0.0.1:18789`** (exact match; not `localhost`).
- MTP/speculative decoding is **optional with automatic fallback — never load-bearing**.
- Serving ports: resident Qwen **:8001**, on-demand 120B **:8002**, dashboard **127.0.0.1:18789**, gateway 8080, Ollama proxy 11435.
- **Resident KV cache: BF16, never `fp8` KV** — until a P9 golden-set eval explicitly passes FP8-KV. Basis: E1. **(Known future challenger: TurboQuant KV-quant — data-free ~3.5-bit KV claiming the quality neutrality FP8-KV lacked; see E39 watch-item `docs/research/2026-06-07-turboquant-kv-watch.md` — pin stands until its G1/G2/G3 gates pass.)** **(E40 guard: the PrismaQuant sweep entrant ships a recipe recommending `--kv-cache-dtype fp8`; it enters the E12 sweep with KV FORCED to BF16 — the sweep tests weights only, fp8-KV stays a P9-golden-set-only question. Never adopt PrismaQuant's serve recipe verbatim.)** **Scope: RESIDENT TIER ONLY** (E1 evidence is Qwen3.6). The **heavy tier** follows the **E19 community-validated recipe including `--kv-cache-dtype fp8`**, gated by its own day-1 quality checks (garbage canary + golden-set). Two models, two evidence bases, two decisions — do not unify them.
- **Resident quant (annotation, not a flip):** default candidate stays **Qwen3.6-35B-A3B NVFP4**; spring-2026 fixes (E12) made *both* kernel paths functional — the Marlin-only / #35947 rationale is **superseded**. Final resident quant is decided by the day-1 three-way sweep (master plan). Verify on arrival: **PR #38126**, **FlashInfer ≥0.6.8.post1**, **CUTLASS 4.5.0 (b12x)**.
- **vLLM build pin is safety-critical:** tool-calling reliability is version-dependent (E14) — never bump vLLM without re-running the tool-eval gate.

## CEO cost & caching pins
*Full model: `docs/finops/opus-cost-model.md` (rates verified 2026-06-06).*
- **Heartbeats are UNCACHED — do not mark their prefix cacheable.** Caching pays only if something *reads* the cache; at 30–60 min heartbeat cadence the 5-min window is always cold, so a cacheable prefix pays the **1.25× write premium ($6.25/MTok) for zero reads**. Plain input ($5/MTok) beats cold writes. *(`max_tokens:0` pre-warming is the latency tool if TTFT ever matters — not a cost tool.)*
- **The CEO's tool list is IMMUTABLE within a session.** Tool-definition changes invalidate the **entire** cache (tools sit at the top of the prefix hierarchy) — the dispatcher must never mutate the CEO's tools per task.
- **Fast mode default OFF.** It is 2× input/output rates, AND toggling speed fast↔standard invalidates the system+message caches — a "fast urgent turn" costs 2× rates **plus** a full cold cache-write on each toggle.
- **Token estimates from raw text carry a +35% allowance.** The Opus 4.7+ tokenizer may use up to **35% more tokens** for the same text — all char-based budget math predating it is optimistic.
