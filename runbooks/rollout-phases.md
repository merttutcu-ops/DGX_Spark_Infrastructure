# Staged rollout phases

Bring agents online incrementally — validate each phase before expanding. The goal is to catch
serving, policy, spend, and behavioral issues at small scale before they affect all 8 agents.

## Phase 1 — Weeks 1–3: 3–4 agents (CEO + PA + Coder + DevOps)

Bring up the minimum viable team: the orchestrator (CEO), a personal assistant (PA), an
implementer (Coder), and the infrastructure operator (DevOps).

**During Phase 1:**
- Validate end-to-end serving: resident Qwen (:8001) and on-demand 120B (:8002) are healthy
  and the gateway correctly routes each agent to its tier.
- Validate the proxy / allowlist: run `scripts/07-egress-probe.sh` and confirm no unexpected
  403s; verify no agent can reach a destination outside its `config/openshell-policy.yaml` rules.
- Validate Slack integration: agents reply only when @mentioned; `requireMention: true` is live.
- Validate spend caps: the CEO's daily Anthropic ceiling is set and trips correctly; the CEO
  does not exceed it even under load.
- Validate fail-stops: trigger the 3-consecutive-failure stop deliberately on a test task and
  confirm the CEO escalates to the operator rather than retrying indefinitely.
- **Pairing mode:** review every agent action during this phase. Do not let agents act
  autonomously on anything that touches money, security, or data until you have observed
  correct behavior across at least one full work week.
- **No web browsing:** the research sub-agent and any browser egress are not active in Phase 1.

**Exit criteria:** one full week of stable operation with no policy violations, no overspend,
and no runaway sessions.

## Phase 2 — Weeks 4–8: expand to all 8 agents

Add PM, Architect, QA, and Security to the running team.

**During Phase 2:**
- Introduce the CEO dispatcher: the CEO creates and routes tasks via `tasks/queue/` without
  manual intervention for routine work.
- Introduce one tightly-sandboxed research sub-agent, gated behind **human approval** for
  every browsing action. This sub-agent has no kill-switch access.
  > Rule: **never give a 3rd-party code or a browsing sub-agent the kill-switch**. Human
  > approval is required for any action derived from untrusted web or email content.
- Dashboard decision point: the Mission Control / web dashboard (Improvement 4) was
  intentionally not scaffolded in Phase 1. If you decide to add it now, treat it as an
  external integration requiring its own security review before hooking it to the kill-switch.
- Validate the Architect/QA/Security agents produce well-formed ADRs, test results, and audit
  reports, and that their output reaches the task queue, not just Slack.

**Exit criteria:** all 8 agents operating stably; QA blocking at least one promotion on a
real found regression; Security surfacing at least one policy observation in a weekly audit.

## Phase 3 — Month 2–3: learning loops (Hermes)

Add Hermes for autonomous learning loops on non-critical workflows.

**Gate:** only after Phase 1 + Phase 2 stability and security are demonstrated — not before.
Hermes should not be introduced while any Phase 2 fail-stop or policy issue remains open.

**Scope for Phase 3:**
- Non-critical workflows only: summarization, code generation on sandboxed tasks, routine
  research. Not: anything touching money, production deployments, or access credentials.
- Monitor for drift: compare Hermes-improved workflows against the golden-set eval
  (see `runbooks/failure-modes.md` §3) each week; auto-rollback if a metric regresses.
- Review the P5 proposal (`docs/proposals/operating-workflow-improvements.md`) before this
  phase — the heavy-tier swap lock is the first improvement to promote out of docs-only status
  once four heavy agents are sharing the on-demand 120B.
