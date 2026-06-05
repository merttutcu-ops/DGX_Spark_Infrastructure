# Agent workspaces

Each `agents/<id>/` holds four files prefilled into that agent's every turn, so they are
kept deliberately short:
- `SOUL.md` — persona, mandate, tone, behavioral stance, model tier.
- `AGENTS.md` — operating rules, tool/egress policy, escalation, budget discipline.
- `IDENTITY.md` — id/name/agentDir/channel/fingerprint. `agentDir` is NEVER shared.
- `MEMORY.md` — lean persistent notes; compacted weekly; secrets blocked by the scanner.

`_shared/USER.md` is the single operator profile, referenced by all agents (not copied).
`_template/` is the canonical source; the 8 role folders are filled from the delta table in
the implementation plan. Editing rule: keep every file lean — bloat inflates prompt-cache cost
for the life of the system.
