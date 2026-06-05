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
