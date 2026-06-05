# Task queue — the dispatch spine (Improvement 3)

**`tasks/queue/` is the single source of truth for dispatch.** Slack/Telegram channels are a
human-facing *projection* of queue items (write-through, not a second store). Sub-agents are
*ephemeral workers dispatched FROM the queue*, never spawned ad hoc; each writes results back to
the queue file that spawned it. If Slack dies, dispatch continues from the queue; if a sub-agent
dies, its queue file is still authoritative.

## Format: one file per task
`tasks/queue/<YYYY-MM-DD>-<slug>.md`. One file per task so two agents editing two tasks touch two
different files — git never conflicts (this is the guard against the Imp-2 prefill-corruption risk).

```yaml
---
id: t-0001                      # stable id
goal: <one sentence>            # = TEMPLATE GOAL
owner: <agent id>               # = OWNER
status: queued                  # queued | in_progress | review | done | blocked
inputs:  [<refs>]               # = INPUTS
deliverable: <artifact + path>  # = DELIVERABLE
done_when:                      # = DONE-CRITERIA (objective, testable)
  - <check>
budget: { tokens: <n>, runtime_min: <n>, retries: <n> }   # = BUDGET
---
# running log (owning agent appends; keep concise)
- <timestamp> <what happened>
```

## Lifecycle
`queued` → an agent claims it (sets `owner`, `status: in_progress`) → `review` (QA/Security check
done_when) → `done`. `blocked` carries a one-line reason and an @CEO escalation. Only the owning
agent edits its file's body; status transitions are recorded in the log.

## Rules
- The CEO creates tasks from operator goals using `TEMPLATE.md`.
- Never spawn a sub-agent without a queue file to write back to.
- A task is not `done` until every `done_when` check is objectively met.
