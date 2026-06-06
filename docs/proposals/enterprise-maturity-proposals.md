# Enterprise-maturity proposals (flagged — not design changes)

Operator-captured ideas for maturing the system to enterprise grade, numbered
P6–P14 (continuing from `operating-workflow-improvements.md`). As with P1–P5,
these are **flagged proposals, NOT design changes**: locked decisions (hardware,
three-tier model split, OpenClaw/NemoClaw stack, queue-as-spine) stay locked, and
nothing here is built before Phase 1 runs. Each entry:
idea · risk-or-leverage · cost · **DEPENDS ON** · **PROMOTION CRITERIA** (the
evidence that would justify actually building it).

## P6 — Neural operator (learned meta-controller, advisory-only)
A routing layer that learns the operator's dispatch decisions from queue telemetry.
Every task file already records owner, tier, budget, duration, retries, outcome — a
labeled dataset accumulating for free because of queue-as-spine. Stage 1: a weekly
stats job surfacing patterns ("qa tasks exceed budget 40% of the time"; "architect
at effort=high matches xhigh at half the cost"). Stage 2: resident Qwen with the
stats in context SUGGESTS owner/tier/effort/budget per new task; the CEO decides.
**HARD RULE — advisory only:** a learned component never holds dispatch authority or
the kill-switch (same trust principle as the Mission Control decision).
*Cost:* low (stage 1) / med (stage 2). · **DEPENDS ON:** months of accumulated task
outcomes; P8. · **PROMOTION CRITERIA:** ≥200 completed tasks in the queue + P8 live.

## P7 — Neural memory brain (tiered memory + consolidation)
Three tiers: working = `MEMORY.md` (exists), episodic = task logs (exists), semantic
= NEW: a local embedding model + vector store on the Spark (LanceDB or Qdrant),
exposed to agents as a retrieval tool. A nightly consolidation job (a Qwen queue
task) distills the day's episodic logs into semantic entries and compacts
`MEMORY.md` under its token budget — P2 grown into a sleep cycle. **HARD RULE —
memory provenance:** every entry carries its source; content originating from
untrusted web/email CANNOT write to memory without human review (memory poisoning is
the prompt-injection attack that survives the session).
*Cost:* med. · **DEPENDS ON:** accumulated episodic data; P2.
**PROMOTION CRITERIA:** agents repeatedly asking for context that exists in past task logs.

## P8 — Traces, not logs (observability stack)
Every task = a trace: dispatch → model calls → tool calls → result. Prometheus +
Grafana on the Spark (vLLM already exposes `/metrics`), one dashboard: queue depth,
p95 task latency, tokens/sec, cost per task, cache-hit ratio. P1 is the seed.
Highest-leverage enterprise upgrade: every other proposal here consumes this
telemetry.
*Cost:* med. · **DEPENDS ON:** Phase 1 running. · **PROMOTION CRITERIA:** first week
of Phase 1 complete — build this FIRST among P6–P14.

## P9 — Evals as CI (promotion gates)
Grow the failure-modes golden-set into per-agent eval suites (tool-calling
reliability, persona adherence, task-template compliance) run on EVERY
model/prompt/config change; scorecards committed to the repo; promotion gated on
passing. The QA agent owns and maintains the suite — agents gating agents, operator
approves the gates.
*Cost:* med. · **DEPENDS ON:** P8 (scorecard storage + metrics).
**PROMOTION CRITERIA:** the first model or prompt change that regresses behavior —
build it before the second one.

## P10 — Staging lane (blue-green for agents)
Staging agent ids (e.g., `coder-staging`) bound to a test Slack channel — or a
second sandbox — where any change (new model build, edited `SOUL.md`, policy tweak)
runs against synthetic tasks before touching production agents. Maps onto real
hardware when a second Spark arrives.
*Cost:* low-med. · **DEPENDS ON:** P9 (synthetic tasks = the eval set). ·
**PROMOTION CRITERIA:** 8 agents live in production.

## P11 — Policy drift detection
A daily job diffs the RUNNING sandbox policy against the repo's policy YAML and
alerts on drift; pairs with P4's contacted-destinations audit. Terraform-style "repo
says X, reality says Y" for the security boundary.
*Cost:* low. · **DEPENDS ON:** Imp-1 probe live. · **PROMOTION CRITERIA:** the first
NemoClaw update that resets or mutates policy state.

## P12 — Incident loop (postmortems as queue tasks)
A tripped fail-stop or kill-switch auto-creates an incident task in the queue with
the trace attached; the Security agent drafts the postmortem (timeline, root cause,
action items) for operator review; accepted action items become queue tasks. The
system learns from its failures through the same spine it works through.
*Cost:* low-med. · **DEPENDS ON:** P8 traces. · **PROMOTION CRITERIA:** the second
real incident.

## P13 — FinOps per project
Tag every task with a project; weekly rollup of tokens + dollars per project with
budget envelopes. Becomes billable-cost accounting the moment agents do client work.
*Cost:* low (rides on P1/P8 data). · **DEPENDS ON:** P1. · **PROMOTION CRITERIA:**
first client-attributable agent work.
**Cost-signal note (finops):** the **primary** runaway-fan-out signal is **endpoint-based** — any
sub-agent session reaching `api.anthropic.com` (correct count ≈ **0**: fan-out routes to `:8001` by
design). Dollar thresholds ($5/hr, $10/day) are the **secondary** signal. Cross-ref **P4**, whose egress
audit already builds this sensor. Model: `docs/finops/opus-cost-model.md`.

## P14 — Bootstrap-from-zero drill
The repo claims paste-and-run; test the claim. Quarterly: restore the full system
from repo + backups onto a clean VM/box, measure time-to-restore, fix what broke.
That number is the real RTO.
*Cost:* low (time, not code). · **DEPENDS ON:** scaffold complete + first backups. ·
**PROMOTION CRITERIA:** calendar — first drill within a month of the Spark going live.

## Sequencing note (build order)
None of these before Phase 1 runs. Build order when promoted:
**P8 → P9 → P7 → P6** (observability feeds evals; memory needs episodic data; the
operator needs months of outcomes). P11/P12/P13 slot in opportunistically; P14 is
calendar-driven.
