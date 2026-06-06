# Failure-mode playbooks (Improvement 2)

Four single-points-of-failure not covered by the kill-switch/spend-cap/backup runbooks.
The **workspace-git guard** is the keystone: the shared workspace is both the source of truth
and the prefill for every turn, so one bad write can poison all 8 agents at once.

## 1. Corrupted / diverged workspace git state  ← highest value
**Why it bites:** concurrent writes, a force-push, or a bad rebase corrupt the prefill that every
agent consumes each turn — degrading all eight simultaneously and silently.
**Guard:**
- Serialize writes: a single "scribe" commits shared-workspace changes on behalf of agents (or a write-lock).
- Protect `main`: no force-push, no rebase (branch protection / pre-push hook).
- Per-agent work branches; merge via the scribe only.
- **Pre-turn assertion:** `git fsck --full` clean AND working tree clean BEFORE a turn consumes the prefill; abort the turn otherwise.
- Scheduled `git fsck` + off-box backup of all workspaces and `openclaw.json` / policy YAML.
**Recovery:** stop dispatch → `git fsck` → reset the shared branch to the last good commit → restore from backup → resume.

## 2. Slack / Telegram outage
**Why it bites:** channels are the human bus AND part of dispatch; if Slack stalls, channel-ticket dispatch silently halts.
**Guard:** the **task queue is authoritative** (Imp-3) — dispatch continues from `tasks/queue/` even if Slack is down. Detect channel-delivery failure; fall back to queue + an out-of-band alert (email/SMS).

## 3. Model regression after an update
**Why it bites:** "test on a non-critical agent first" defines no automated gate.
**Guard:** a tiny **golden-set eval** (a few tool-calling + reasoning probes) auto-run after any
vLLM / NemoClaw / model / MTP change; gate promotion on it; **auto-rollback** to the pinned prior
image on regression. Keep the prior image digest pinned so rollback is one command.

## 4. Runaway recursive sub-agent fan-out
**Why it bites:** caps on *concurrent* sub-agents + a BUDGET don't bound *recursion depth* or *spawn rate*
(a sub-agent spawning sub-agents). CloudZero's "$25/M across 50 streams" is this cost shape.
**Guard:** global spawn **semaphore** + **max recursion depth** + a rate limiter in the dispatcher;
wire the kill-switch to "total active sessions > N".

---

*Entries 5–9 are operational failure modes from the 2026-06-06 forum harvest (evidence registry: `docs/research/2026-06-06-forum-harvest.md`).*

## 5. Resident model thinking loops (E8a)
**Symptoms:** the resident model (Qwen3.6-35B) loops on "thinking" / repetitive reasoning mid-task under agentic load and never emits a final answer.
**Mitigations (in order):** adjust sampling (raise temperature / add repetition penalty / cap the thinking budget); switching the agent to vLLM's Anthropic-compatible endpoint helped some — **trapdoor: Claude Code ≥2.1.154 is reported broken against vLLM's Anthropic-compat endpoint**, so verify your harness version before relying on it. The pathology is **cross-harness** (Hermes shows the same mid-task stall; `/goal` is a partial nudge) → treat it as a **model / serving-layer** issue, not harness-specific.
**Escalation:** PA detects the stalled turn → escalate to the operator; do **not** silently retry into more loops.

## 6. Malformed tool calls (E8b)
**Symptoms:** tool-call arguments contain junk (e.g. HTML fragments) → the tool layer rejects or mis-executes the call. Critical for **Coder/QA**, whose loops depend on clean tool calls.
**Guard / acceptance test:** the **day-1 tool-eval gate** (master-plan addenda / E14) is the acceptance test — no agent depends on tool calls until it passes on the pinned vLLM build. **Follow-up:** a recurring **nightly tool-call canary** (the P3-era proposal) catches regressions after the gate.

## 7. OS/driver update bricks the GPU stack (E9)
**Why it bites:** apt / kernel / driver upgrades on Spark repeatedly brick the NVIDIA driver stack (multiple threads, incl. a kernel 6.17.0-1021 warning) — one bad upgrade takes the whole serving layer down.
**Rule:** the **DevOps agent NEVER runs OS / kernel / driver upgrades autonomously** (enforced in `agents/devops/AGENTS.md`). Such upgrades are **human-triggered, snapshot-first**, and gated on `nvidia-smi` + a serving probe (`scripts/07`) passing **before agents resume**.

## 8. GPT-OSS mxfp4 build failures (E15)
**Fix ladder (heavy-tier build):** CUTLASS SHA mismatch → edit `Dockerfile.mxfp4` (~L101) to the alternate SHA. "Failed to download cubins" → comment out the flashinfer-cubin / jit-cache `RUN` steps, or `docker builder prune -f` and rebuild. On any failure, clear `~/.triton`, `~/.cache/vllm`, `~/.cache/flashinfer` (or use eugr's `--clean`). **Fallback:** raphael.amorim maintains a prebuilt Docker Hub image that "just works" for GPT-OSS-20B/120B — **digest-pin it** if you use it.

## 9. NemoClaw agent/cron regression on OS v1.135.34 (E17)
**Symptoms:** on OS 2026.05.31 (v1.135.34), NemoClaw agents break (`tool_search_code` error) and cron jobs become unscheduleable. **Status: open upstream, unresolved.**
**Fallback:** schedule the heartbeat / egress-probe jobs via **systemd timers** instead of NemoClaw cron until it is fixed (see master-plan addenda / E17).
