# Runbooks index

Operational procedures for the spark-agent-infra multi-agent system.

| Runbook | Summary |
|---|---|
| [daily.md](daily.md) | Daily health checks: agent status, GPU/memory, security log scan, Anthropic cost review. |
| [weekly.md](weekly.md) | Weekly maintenance: deep security audit, deliberate updates with digest pinning, workspace backups, performance review, MEMORY compaction. |
| [kill-switch.md](kill-switch.md) | 4-step runaway-agent recovery: stop gateway/sandbox, kill inference containers, revoke credentials, review logs before restart. |
| [rollout-phases.md](rollout-phases.md) | Staged rollout: Phase 1 (CEO+PA+Coder+DevOps, weeks 1–3), Phase 2 (all 8 agents, weeks 4–8), Phase 3 (Hermes learning loops, month 2–3). |
| [failure-modes.md](failure-modes.md) | Four SPOF playbooks: workspace-git corruption (keystone guard), Slack outage, model regression, runaway recursive fan-out. |

> **Quick reference:** For an immediate emergency, go to `kill-switch.md`. For the highest-value
> ongoing guard, see `failure-modes.md` §1 (workspace-git guard). For when to bring each agent
> online, see `rollout-phases.md`.
