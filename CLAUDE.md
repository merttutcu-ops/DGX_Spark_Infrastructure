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

## Pinned versions (mirror of master plan; verify on arrival)
- CUDA **13.2**; NGC vLLM image **`nvcr.io/nvidia/vllm:26.05.post1-py3`** (pin a digest on arrival).
- NemoClaw **tag `v0.0.59`** (a git tag, not a Release — pin by tag/commit SHA).
- eugr build wheel **cu132**; MXFP4 path `--exp-mxfp4 --mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head`.
- Driver **580 branch**. Dashboard origin **`127.0.0.1:18789`** (exact match; not `localhost`).
- MTP/speculative decoding is **optional with automatic fallback — never load-bearing**.
- Serving ports: resident Qwen **:8001**, on-demand 120B **:8002**, dashboard **127.0.0.1:18789**, gateway 8080, Ollama proxy 11435.
