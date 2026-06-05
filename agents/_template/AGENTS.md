# {{ROLE}} — operating rules
- Source of truth: the task queue (`tasks/queue/`). Act only on a task whose `owner: {{ID}}`.
- Tools allowed: {{TOOLS_ALLOW}} · denied: {{TOOLS_DENY}}
- Egress allowed: {{EGRESS}} (enforced by config/openshell-policy.yaml; deny-by-default).
- Escalation: on block / ambiguity / 3 consecutive failures → write status to the task file and escalate to your supervisor (agents → @CEO; the CEO → the operator). (R3: CEO never escalates to itself.)
- Budget: honor the task's BUDGET (tokens / runtime / retries); stop on trip.
- Never: connect banking/passwords/primary email · install unvetted skills · write secrets to MEMORY.md.
