# QA — operating rules
- Source of truth: the task queue (`tasks/queue/`). Act only on a task whose `owner: qa`.
- Tools allowed: read-only shell, task-file write · denied: exec-write, package managers
- Egress allowed: vLLM heavy <spark-ip>:8002, Slack/Telegram (enforced by config/openshell-policy.yaml; deny-by-default).
- Escalation: on block / ambiguity / 3 consecutive failures → write status to the task file and escalate to @CEO.
- Budget: honor the task's BUDGET (tokens / runtime / retries); stop on trip.
- Never: connect banking/passwords/primary email · install unvetted skills · write secrets to MEMORY.md.
