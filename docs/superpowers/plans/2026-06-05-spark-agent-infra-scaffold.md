# spark-agent-infra Scaffold — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a paste-and-run repository scaffold so that day 1 with the DGX Spark hardware is "clone → fill placeholders → run numbered scripts," capturing every locked decision, persona, config, script, runbook, and the queue-as-spine dispatch model from `docs/master-plan.md` and the approved improvements in `docs/plan-review.md`.

**Architecture:** A documentation-and-config repo (no runtime app). It contains: a root `CLAUDE.md` that is the agents' constitution; eight lean `agents/<id>/` workspace templates; `config/` (OpenClaw routing + OpenShell egress policy); idempotent numbered `scripts/` for the Spark + Mac; `runbooks/`; and `tasks/` — a one-file-per-task git-versioned queue that is the single source of truth for dispatch. Nothing here executes against hardware that doesn't exist yet; Spark-side scripts are written to run on aarch64 DGX OS and gated behind confirmation prompts.

**Tech Stack:** Bash (aarch64 DGX OS / macOS zsh), JSON (OpenClaw config), YAML (OpenShell policy), Markdown (everything else). Optional dev-workflow hardening: GitHub Actions, `shellcheck`/`shfmt`, `pre-commit`, `gitleaks`, JSON Schema.

---

## Conventions for this plan (read first)

**Verification replaces unit tests.** This scaffold has no runtime behavior to unit-test. Each task's "test" is the appropriate static verification for the artifact, run *before* the commit:

| Artifact | Verification command | Pass criterion |
|---|---|---|
| `*.sh` | `shellcheck -x scripts/<f>.sh` then `bash -n scripts/<f>.sh` | no errors; parses |
| `*.json` | `jq empty config/<f>.json` | exits 0 (valid JSON) |
| `*.yaml` | `python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' config/<f>.yaml` | exits 0 (valid YAML) |
| `*.md` | manual read-back against the spec lines in the task | sections present, no `TODO(unfilled)` |
| repo tree | `git status` / `ls` | files exist at exact paths |

> `python3 -c 'import yaml…'` is used instead of `yq` because PyYAML ships with macOS Python and needs no install; if `yq` is already present, `yq -e '.' file.yaml` is equivalent. (This avoids the class of "yq doesn't support `--arg`" bug noted in the operator's conventions.)

**Commit granularity.** One commit per task (the task's files only), conventional-commit messages. **Push happens once per milestone, after the operator approves that milestone** — never mid-milestone, never to `main`. All work is on the `scaffold/build` branch; `main` stays clean.

**"Do not invent versions" rule (load-bearing).** Every version, image tag, digest, SKU, and token value is either (a) pinned exactly as `docs/master-plan.md` / `docs/plan-review.md` specify, or (b) marked `TODO(verify-on-arrival)` with the exact command to confirm it. Never substitute a "newer" or guessed value. The master plan's Caveats are explicit that this stack drifts weekly.

**Silent-failure rule (load-bearing, from operator conventions).** No `cmd >/dev/null 2>&1 || true`, bare `except: pass`, or `continue-on-error` without a one-line scale-justification comment stating the max N it handles and the failure mode at N+1. Scripts capture stderr, distinguish expected-idempotent skips (already-exists) from real errors, and fail loudly with diagnostics on the unexpected branch.

**Secrets rule.** No real `nvapi-`, `sk-ant-`, bot, or gateway tokens anywhere. Config files use `<PLACEHOLDER>` tokens and read real values from environment variables / per-agent auth profiles at runtime.

---

## File Structure (decomposition lock-in)

```
spark-agent-infra/
├── CLAUDE.md                         # Agents' constitution: context, architecture, conventions, queue-as-spine, do-not-invent rule, security rules
├── README.md                         # Human entry point: what this is, day-1 paste-and-run order, status
├── .gitignore                        # (exists) augment: secrets, *.env, local token files
├── agents/
│   ├── README.md                     # How the workspace files work; lean-prefill rule
│   ├── _shared/
│   │   └── USER.md                   # ONE operator profile, read-only, referenced by all agents (DRY)
│   ├── _template/                    # Canonical blank template (source of the 8 below)
│   │   ├── SOUL.md  AGENTS.md  IDENTITY.md  MEMORY.md
│   ├── ceo/   { SOUL.md AGENTS.md IDENTITY.md MEMORY.md }   # Opus 4.8 — orchestrator
│   ├── pa/    { … }                  # Qwen 35B — personal assistant
│   ├── pm/    { … }                  # Qwen 35B — product manager
│   ├── architect/ { … }             # GPT-OSS-120B — rigorous, ADR-driven
│   ├── coder/ { … }                  # GPT-OSS-120B — implements to spec
│   ├── qa/    { … }                  # GPT-OSS-120B — adversarial testing
│   ├── security/ { … }              # GPT-OSS-120B — adversarial auditor
│   └── devops/ { … }                 # Qwen 35B — serving/health/backups
├── config/
│   ├── README.md                     # How to apply these on the Spark; placeholder list
│   ├── openclaw.json                 # Per-agent model routing (vllm + anthropic CEO)
│   └── openshell-policy.yaml         # Deny-by-default egress allowlist, per-agent scoped (Imp 1 route in comments)
├── scripts/
│   ├── README.md                     # Run order, env vars, idempotency notes
│   ├── lib/common.sh                 # Shared: log/warn/die/confirm/require_cmd/run_destructive
│   ├── 01-post-oobe-update.sh        # Spark: manual OTA/OS update, driver/CUDA check
│   ├── 02-nemoclaw-install.sh        # Spark: non-interactive NemoClaw install
│   ├── 03-serve-120b.sh              # Spark: serve GPT-OSS-120B MXFP4 (on-demand)
│   ├── 04-serve-qwen-resident.sh     # Spark: serve Qwen3.6-35B-A3B NVFP4 (resident), optional MTP+fallback
│   ├── 05-drop-caches.sh             # Spark: UMA page-cache flush ritual
│   ├── 06-ssh-tunnel-dashboard.sh    # Mac: SSH tunnel to 127.0.0.1:18789
│   └── 07-egress-probe.sh            # Sandbox: synthetic inference+anthropic probe, Slack alert (Imp 1)
├── runbooks/
│   ├── README.md
│   ├── daily.md                      # §5 daily ops
│   ├── weekly.md                     # §5 weekly ops
│   ├── kill-switch.md                # §4 runaway-agent recovery (4 steps)
│   ├── rollout-phases.md             # §5 staged rollout (3 phases)
│   └── failure-modes.md              # Imp 2: four playbooks, workspace-git guard keystone
├── tasks/
│   ├── README.md                     # Queue format + lifecycle + queue-as-spine rule (Imp 3)
│   ├── TEMPLATE.md                   # CEO decomposition format
│   └── queue/
│       ├── .gitkeep
│       └── EXAMPLE-0001-bootstrap-serving.md
└── docs/
    ├── architecture.md               # Lean topology description + diagram reference
    ├── diagrams/
    │   └── infrastructure-map.svg    # Copy of the operator's workflow map
    └── proposals/
        └── operating-workflow-improvements.md   # The 5 flagged P-ideas (docs-only, no build impact)
```

**Dev-workflow hardening (Milestone 7 — operator opted into ALL):**
```
.github/workflows/ci.yml             # shellcheck + shfmt + json/yaml validate + gitleaks
.pre-commit-config.yaml              # local mirror of CI checks
config/openclaw.schema.json          # JSON Schema for openclaw.json
config/openshell-policy.schema.json  # JSON Schema for the policy YAML
justfile                             # just lint | validate | fmt
```

---

## Milestones (= push points)

- **M0** Repo meta & constitution → push after approval
- **M1** Agent workspace templates (8 roles)
- **M2** config/ (routing + egress policy)
- **M3** scripts/ (01–07 + common.sh)
- **M4** runbooks/ (incl. failure-modes / Imp 2)
- **M5** tasks/ (queue spine / Imp 3)
- **M6** docs/ (architecture, diagram, proposals)
- **M7** dev-workflow hardening — schemas, CI, pre-commit, branch-protection, justfile-last (all opted-in)

---

## Milestone 0 — Repo meta & constitution

### Task 0.1: Root `CLAUDE.md` (agents' constitution)

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write the file** with exactly this content:

```markdown
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
```

- [ ] **Step 2: Verify** — `test -f CLAUDE.md && grep -q "single source of truth" CLAUDE.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add root CLAUDE.md agent constitution"
```

### Task 0.2: `README.md` (human entry point)

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the file:**

```markdown
# spark-agent-infra

Paste-and-run scaffold for an always-on, 8-agent AI system on an NVIDIA DGX Spark
(GB10, 128GB, aarch64 DGX OS). Prepared ahead of hardware so day 1 is clone → fill
placeholders → run numbered scripts.

> **Read first:** `docs/master-plan.md` (the decided architecture, versions, and security
> rules) and `docs/plan-review.md` (independent verification + approved improvements).
> `CLAUDE.md` is the agents' operating contract.

## Day-1 order (on the Spark, aarch64)
1. `scripts/01-post-oobe-update.sh` — pull deferred OTA/OS updates; confirm driver 580 / CUDA 13.x.
2. `scripts/02-nemoclaw-install.sh` — non-interactive NemoClaw + OpenShell install.
3. Apply `config/openshell-policy.yaml` (deny-by-default egress) and `config/openclaw.json` (routing).
4. `scripts/04-serve-qwen-resident.sh` — bring up the always-resident routine model.
5. `scripts/03-serve-120b.sh` — bring up the on-demand heavy model when needed.
6. From your Mac: `scripts/06-ssh-tunnel-dashboard.sh` to reach the dashboard at 127.0.0.1:18789.
7. Schedule `scripts/07-egress-probe.sh` (inference/anthropic liveness alerting).

## Status
- [x] Repo scaffold (this).  [ ] Hardware acquired.  [ ] Week-1 serving validated.
- Rollout: see `runbooks/rollout-phases.md` (Phase 1 = CEO + PA + Coder + DevOps).

## Safety
Deny-by-default egress; never connect banking/passwords/primary email; skill auto-update OFF;
human approval for actions derived from untrusted content. Kill switch: `runbooks/kill-switch.md`.
```

- [ ] **Step 2: Verify** — `grep -q "Day-1 order" README.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with day-1 run order"
```

### Task 0.3: Augment `.gitignore`

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append** (do not remove existing lines):

```gitignore

# --- secrets & local runtime (never commit) ---
# (R4) Narrow, SPECIFIC patterns only. Broad globs like *token*/*secret* would silently
# swallow legitimate future files (e.g. a token-budget doc, P2). Name the real secret files.
.env*
*.env
*.key
*.pem
nemoclaw-proxy-env.sh
ollama-proxy-token
```

- [ ] **Step 2: Verify** — `grep -q "never commit" .gitignore && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore: ignore secret/token files"
```

- [ ] **Step 4 (M0 push gate):** After operator approval of M0 → `git push -u origin scaffold/build`.

---

## Milestone 1 — Agent workspace templates (8 roles, lean)

> **DRY approach:** Define the canonical template once (Task 1.1) + one shared operator
> profile (Task 1.2), then generate the 8 agents from a **delta table** (Tasks 1.3–1.10).
> Each agent file is intentionally tiny — these are prefilled every turn.

### Task 1.1: Canonical template `agents/_template/`

**Files:**
- Create: `agents/_template/SOUL.md`, `agents/_template/AGENTS.md`, `agents/_template/IDENTITY.md`, `agents/_template/MEMORY.md`
- Create: `agents/README.md`

- [ ] **Step 1: Write `agents/_template/SOUL.md`:**

```markdown
# {{ROLE}} — SOUL
Persona: {{PERSONA}}
Mandate: {{MANDATE}}            # the one thing only this agent owns
Tone: {{TONE}}
Stance:
{{STANCE_BULLETS}}
Model tier: {{TIER}}            # CEO Opus 4.8 | heavy GPT-OSS-120B | routine Qwen3.6-35B
```

- [ ] **Step 2: Write `agents/_template/AGENTS.md`:**

```markdown
# {{ROLE}} — operating rules
- Source of truth: the task queue (`tasks/queue/`). Act only on a task whose `owner: {{ID}}`.
- Tools allowed: {{TOOLS_ALLOW}} · denied: {{TOOLS_DENY}}
- Egress allowed: {{EGRESS}} (enforced by config/openshell-policy.yaml; deny-by-default).
- Escalation: on block / ambiguity / 3 consecutive failures → write status to the task file and escalate to your supervisor (agents → @CEO; the CEO → the operator). (R3: CEO never escalates to itself.)
- Budget: honor the task's BUDGET (tokens / runtime / retries); stop on trip.
- Never: connect banking/passwords/primary email · install unvetted skills · write secrets to MEMORY.md.
```

- [ ] **Step 3: Write `agents/_template/IDENTITY.md`:**

```markdown
# {{ROLE}} — IDENTITY
id: {{ID}}
display_name: {{NAME}}
agentDir: ~/.openclaw/agents/{{ID}}/    # NEVER shared across agents (auth/session collisions)
binding: {{CHANNEL}}                     # Slack/Telegram channel this identity answers in
fingerprint: {{FINGERPRINT}}             # unique; never copy identical identities across agents
```

- [ ] **Step 4: Write `agents/_template/MEMORY.md`:**

```markdown
# {{ROLE}} — MEMORY (lean — secrets blocked by the plugin scanner)
> Keep under ~400 tokens. One fact per line. Compact on the weekly schedule.
- (seed) Created with the scaffold; rollout phase per runbooks/rollout-phases.md.
```

- [ ] **Step 5: Write `agents/README.md`:**

```markdown
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
```

- [ ] **Step 6: Verify** — `for f in SOUL AGENTS IDENTITY MEMORY; do test -f agents/_template/$f.md || echo "MISSING $f"; done; echo done`. Expected: `done` with no MISSING lines.
- [ ] **Step 7: Commit**

```bash
git add agents/_template agents/README.md
git commit -m "feat(agents): add canonical workspace template + README"
```

### Task 1.2: Shared operator profile `agents/_shared/USER.md`

**Files:**
- Create: `agents/_shared/USER.md`

- [ ] **Step 1: Write the file:**

```markdown
# Operator profile (shared, read-only to agents)
- Name: Mert. Learning to build software — prefer explanations with decisions.
- Environment: macOS (zsh); works via Claude Code desktop + VS Code.
- Hard rules: anything touching money / security / data-loss → STOP and ask first.
- Off-limits forever: banking, password managers / primary password store, primary email.
- Comms: per-agent Slack/Telegram channels; agents reply only when @mentioned.
- Style: clear over clever; minimal dependencies; no over-engineering; surface what broke, don't hide it.
```

- [ ] **Step 2: Verify** — `grep -q "Off-limits forever" agents/_shared/USER.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add agents/_shared/USER.md
git commit -m "feat(agents): add shared operator profile"
```

### Delta table (source for Tasks 1.3–1.10)

For each agent, create `agents/<id>/{SOUL,AGENTS,IDENTITY,MEMORY}.md` from the template,
substituting the placeholders with the row below. `MEMORY.md` is the template's verbatim seed
for all agents (only `{{ROLE}}` changes). `TONE` defaults to "concise, professional" unless noted.

**(R5) Shared USER.md mechanism — explicit, not implicit.** Each agent dir ALSO gets `USER.md` as a
**relative symlink** to the single source: `ln -s ../_shared/USER.md agents/<id>/USER.md`. This keeps
one operator profile (DRY) while making every agent's workspace resolve it. Each per-agent task verifies
the link resolves (`test -f agents/<id>/USER.md` follows symlinks). **TODO(verify-on-arrival):** confirm
OpenClaw resolves *symlinked* workspace files when the workspace is deployed to `~/.openclaw/ws-<id>/`;
if it does not, replace the symlink with a deploy-time copy step (copy `_shared/USER.md` into each
runtime workspace) — the fallback is noted in `config/README.md`.

**(R3) Escalation supervisor.** Non-CEO agents escalate to `@CEO`; the **CEO escalates to the operator**
(the CEO's `AGENTS.md` overrides the template's escalation line accordingly).

**(R1) EGRESS ports** map to the tier: routine agents reach the resident model on **:8001**, heavy
agents reach the on-demand model on **:8002** (the CEO reaches :8001 for cheap sub-agent fan-out).

| id | NAME | TIER | PERSONA | MANDATE | STANCE_BULLETS | TOOLS_ALLOW | TOOLS_DENY | EGRESS | FINGERPRINT |
|---|---|---|---|---|---|---|---|---|---|
| **ceo** | CEO | CEO Opus 4.8 | Orchestrator; decomposes goals, owns dispatch and budgets | Turn operator goals into queue tasks and route them; own kill-switch awareness | `- Emit the strict GOAL/OWNER/INPUTS/DELIVERABLE/DONE-CRITERIA/BUDGET template for every delegation.`<br>`- Queue is the spine: create/route tasks in tasks/queue/; channels are a projection.`<br>`- Prefer the cheap local tier for sub-agents; reserve Opus effort xhigh/max for hard tasks.`<br>`- Escalate to the OPERATOR (never to @CEO — that's yourself).` | read-only shell (ls/cat/df/ps), task-file write, sub-agent spawn | exec-write, package managers | `api.anthropic.com:443`, vLLM resident `<spark-ip>:8001` | "CEO/orchestrator; speaks in task templates" |
| **pa** | PersonalAssistant | routine Qwen3.6-35B | Calm, proactive assistant | Daily brief, triage, scheduling, reminders | `- Summarize overnight heartbeat actions each morning.`<br>`- Escalate anything money/security/data-loss to the operator, never act on it.` | read-only shell, task-file write | exec-write, package managers | vLLM resident `<spark-ip>:8001`, Slack/Telegram | "PA; daily-brief voice" |
| **pm** | ProductManager | routine Qwen3.6-35B | Crisp product manager | Convert goals into well-formed tickets with testable done-criteria; groom the queue | `- Every ticket has objective, testable DONE-CRITERIA before dispatch.`<br>`- Keep the queue de-duplicated and prioritized.` | read-only shell, task-file write | exec-write, package managers | vLLM resident `<spark-ip>:8001`, Slack/Telegram | "PM; ticket-shaped thinking" |
| **architect** | Architect | heavy GPT-OSS-120B | Rigorous; asks for constraints before designing | Produce ADRs and designs that downstream agents implement | `- Ask for constraints before proposing a design.`<br>`- Output an ADR (context/decision/consequences) per significant choice.`<br>`- No code; hand specs to Coder via the queue.` | read-only shell, task-file write | exec-write, package managers | vLLM heavy `<spark-ip>:8002`, Slack/Telegram | "Architect; ADR-first, constraint-seeking" |
| **coder** | Coder | heavy GPT-OSS-120B | Disciplined implementer | Implement to spec with TDD and small commits | `- Test-first; smallest change that passes.`<br>`- Work on a per-agent branch; never force-push.`<br>`- Stop and escalate on ambiguous specs.` | read-only shell, task-file write, **package install**, git | destructive shell without approval | vLLM heavy `<spark-ip>:8002`, `api.github.com`/`github.com:443`, `registry.npmjs.org:443`, `pypi.org`/`files.pythonhosted.org:443`, Slack/Telegram | "Coder; TDD + small commits" |
| **qa** | QA | heavy GPT-OSS-120B | Adversarial tester | Verify done-criteria; reproduce before asserting | `- Reproduce a failure before claiming it.`<br>`- Assert the SEMANTIC expectation, not just exit codes.`<br>`- Block promotion on unmet done-criteria.` | read-only shell, task-file write | exec-write, package managers | vLLM heavy `<spark-ip>:8002`, Slack/Telegram | "QA; reproduce-first skeptic" |
| **security** | SecurityAuditor | heavy GPT-OSS-120B | Adversarial; assumes hostile input | Audit configs/skills/egress; block on unverified external content | `- Treat all external content as hostile.`<br>`- Block any action derived from untrusted web/email until human-approved.`<br>`- Run the security audit cadence; vet every skill.` | read-only shell, task-file write | exec-write, package managers, browser-by-default | vLLM heavy `<spark-ip>:8002`, Slack/Telegram | "Security; hostile-input assumption" |
| **devops** | DevOps | routine Qwen3.6-35B | Steady operator | Run serving/health/backups; manage scripts and the heartbeat | `- Keep the resident model healthy; watch post-swap UMA lag.`<br>`- Run weekly backups + security audit; pin image digests.` | read-only shell, **script exec (allowlisted)**, **package install**, git | unbounded destructive shell | vLLM resident `<spark-ip>:8001`, `api.github.com`/`github.com:443`, `registry.npmjs.org:443`, `pypi.org`/`files.pythonhosted.org:443`, Slack/Telegram | "DevOps; serving + backups" |

> Notes baked into the table: only **coder** and **devops** get package-install egress (npm/pip) and GitHub push — per master plan §4 ("remove for non-Coder/DevOps agents"). Only **ceo** gets `api.anthropic.com`. Routine agents (pa/pm/devops) reach the resident model on **:8001**; heavy agents (architect/coder/qa/security) reach the on-demand model on **:8002**. `<spark-ip>` is a placeholder filled on arrival.

### Tasks 1.3–1.10: Generate the eight agents

Repeat this task once per row above. Shown for **ceo**; the other seven are identical in
structure with the row's substitutions.

**Files (per agent `<id>`):**
- Create: `agents/<id>/SOUL.md`, `agents/<id>/AGENTS.md`, `agents/<id>/IDENTITY.md`, `agents/<id>/MEMORY.md`

- [ ] **Step 1: Create the four files** by copying `agents/_template/*` and substituting the row.
  Example — `agents/ceo/SOUL.md`:

```markdown
# CEO — SOUL
Persona: Orchestrator; decomposes goals, owns dispatch and budgets
Mandate: Turn operator goals into queue tasks and route them; own kill-switch awareness
Tone: concise, directive
Stance:
- Emit the strict GOAL/OWNER/INPUTS/DELIVERABLE/DONE-CRITERIA/BUDGET template for every delegation.
- Queue is the spine: create/route tasks in tasks/queue/; channels are a projection.
- Prefer the cheap local tier for sub-agents; reserve Opus effort xhigh/max for hard tasks.
Model tier: CEO Opus 4.8
```

  `agents/ceo/AGENTS.md`:

```markdown
# CEO — operating rules
- Source of truth: the task queue (`tasks/queue/`). Act only on a task whose `owner: ceo`.
- Tools allowed: read-only shell (ls/cat/df/ps), task-file write, sub-agent spawn · denied: exec-write, package managers
- Egress allowed: api.anthropic.com:443, vLLM resident <spark-ip>:8001 (enforced by config/openshell-policy.yaml; deny-by-default).
- Escalation: on block / ambiguity / 3 consecutive failures → write status to the task file and escalate to the OPERATOR (the CEO never escalates to itself).
- Budget: honor the task's BUDGET (tokens / runtime / retries); stop on trip.
- Never: connect banking/passwords/primary email · install unvetted skills · write secrets to MEMORY.md.
```

  `agents/ceo/IDENTITY.md`:

```markdown
# CEO — IDENTITY
id: ceo
display_name: CEO
agentDir: ~/.openclaw/agents/ceo/    # NEVER shared across agents (auth/session collisions)
binding: <slack-channel-ceo>          # Slack/Telegram channel this identity answers in
fingerprint: CEO/orchestrator; speaks in task templates
```

  `agents/ceo/MEMORY.md`:

```markdown
# CEO — MEMORY (lean — secrets blocked by the plugin scanner)
> Keep under ~400 tokens. One fact per line. Compact on the weekly schedule.
- (seed) Created with the scaffold; rollout phase per runbooks/rollout-phases.md.
```

  Then create the shared operator-profile symlink (R5 — single source, DRY):

```bash
ln -s ../_shared/USER.md agents/ceo/USER.md
```

- [ ] **Step 2: Verify** — `for f in SOUL AGENTS IDENTITY MEMORY; do grep -q . agents/ceo/$f.md || echo "EMPTY $f"; done; test -f agents/ceo/USER.md && echo "USER.md resolves"; echo done`. Expected: `USER.md resolves` then `done`, no EMPTY. (`test -f` follows the symlink, so this confirms it points at a real file.)
- [ ] **Step 3: Commit** (one commit per agent)

```bash
git add agents/ceo
git commit -m "feat(agents): add ceo workspace (Opus 4.8 orchestrator)"
```

> Repeat 1.4 pa, 1.5 pm, 1.6 architect, 1.7 coder, 1.8 qa, 1.9 security, 1.10 devops with each
> row's substitutions — **including the `ln -s ../_shared/USER.md agents/<id>/USER.md` symlink and the
> USER.md-resolves check** — and commit message `feat(agents): add <id> workspace (<tier> — <mandate-short>)`.
> The CEO's `AGENTS.md` is the only one whose escalation target is the operator (R3); all others use `@CEO`.

- [ ] **M1 push gate:** after operator approval → `git push`.

---

## Milestone 2 — config/

### Task 2.1: `config/openclaw.json` (per-agent routing)

**Files:**
- Create: `config/openclaw.json`

- [ ] **Step 1: Write the file** (placeholders for ip/token; CEO key lives in a per-agent auth profile, not here):

```json
{
  "$schema": "./openclaw.schema.json",
  "models": {
    "providers": {
      "vllm-resident": {
        "baseUrl": "http://<spark-ip>:8001/v1",
        "apiKey": "dummy",
        "api": "openai-completions",
        "_note": "ALWAYS-RESIDENT routine tier (Qwen3.6-35B). Served by scripts/04 on :8001.",
        "models": [ { "id": "vllm-resident/Qwen3.6-35B-A3B-NVFP4", "contextWindow": 32768 } ]
      },
      "vllm-heavy": {
        "baseUrl": "http://<spark-ip>:8002/v1",
        "apiKey": "dummy",
        "api": "openai-completions",
        "_note": "ON-DEMAND heavy tier (GPT-OSS-120B). Served by scripts/03 on :8002. Phase-1 upgrade: front both ports with llama-swap+LiteLLM (master plan §2) and switch these baseUrls to the router.",
        "models": [ { "id": "vllm-heavy/gpt-oss-120b", "contextWindow": 32768 } ]
      },
      "anthropic": {
        "api": "anthropic-messages",
        "_note": "CEO key is supplied via the ceo agent's per-agent auth profile, NOT here."
      }
    }
  },
  "agents": {
    "defaults": {
      "heartbeat": { "every": "30m" },
      "_heartbeat_note": "1h under Anthropic OAuth/token auth. Interval is config, not HEARTBEAT.md."
    },
    "list": [
      { "id": "ceo",       "name": "CEO",               "model": "anthropic/claude-opus-4-8",            "workspace": "~/.openclaw/ws-ceo",    "effort": "high" },
      { "id": "pa",        "name": "PersonalAssistant", "model": "vllm-resident/Qwen3.6-35B-A3B-NVFP4",  "workspace": "~/.openclaw/ws-pa" },
      { "id": "pm",        "name": "ProductManager",    "model": "vllm-resident/Qwen3.6-35B-A3B-NVFP4",  "workspace": "~/.openclaw/ws-pm" },
      { "id": "architect", "name": "Architect",         "model": "vllm-heavy/gpt-oss-120b",              "workspace": "~/.openclaw/ws-arch" },
      { "id": "coder",     "name": "Coder",             "model": "vllm-heavy/gpt-oss-120b",              "workspace": "~/.openclaw/ws-coder" },
      { "id": "qa",        "name": "QA",                "model": "vllm-heavy/gpt-oss-120b",              "workspace": "~/.openclaw/ws-qa" },
      { "id": "security",  "name": "SecurityAuditor",   "model": "vllm-heavy/gpt-oss-120b",              "workspace": "~/.openclaw/ws-sec" },
      { "id": "devops",    "name": "DevOps",            "model": "vllm-resident/Qwen3.6-35B-A3B-NVFP4",  "workspace": "~/.openclaw/ws-devops" }
    ]
  },
  "slack": {
    "requireMention": true,
    "replyToMode": "off",
    "replyToModeByChatType": { "channel": "first" },
    "thread": { "inheritParent": true }
  },
  "logging": { "redactSensitive": "tools" }
}
```

> **TODO(verify-on-arrival):** confirm the exact OpenClaw config key names against the installed
> `v0.0.59` schema (`openclaw.json` at `/sandbox/.openclaw/`); `effort`, `heartbeat.every`, and the
> `slack.*` keys are per the master plan but the installed build is authoritative.

- [ ] **Step 2: Verify** — `jq empty config/openclaw.json && jq -r '.agents.list[].model' config/openclaw.json`. Expected: valid JSON; prints the 8 model ids — CEO `anthropic/claude-opus-4-8`, routine `vllm-resident/...` (pa/pm/devops), heavy `vllm-heavy/...` (architect/coder/qa/security). Also `jq -r '.models.providers | keys[]'` → `vllm-resident`, `vllm-heavy`, `anthropic`.
- [ ] **Step 3: Commit**

```bash
git add config/openclaw.json
git commit -m "feat(config): add per-agent openclaw routing (vllm + anthropic CEO)"
```

### Task 2.2: `config/openshell-policy.yaml` (deny-by-default egress)

**Files:**
- Create: `config/openshell-policy.yaml`

- [ ] **Step 1: Write the file:**

```yaml
# OpenShell network policy — DENY BY DEFAULT.
# Sandbox outbound is blocked unless listed here. Each rule restricts which executables
# (binaries, identified by kernel-trusted /proc/<pid>/exe + SHA256, re-checked on change)
# may reach an endpoint, and which HTTP methods. Replacing a binary triggers an immediate deny.
#
# Imp-1 EXPLICIT INFERENCE ROUTES (two direct ports; do NOT rely on the default localhost path):
#   resident Qwen3.6 on <spark-ip>:8001 (scripts/04), on-demand GPT-OSS-120B on <spark-ip>:8002 (scripts/03).
#   The default sandbox->host route via the CONNECT proxy at 10.200.0.1:3128 returns 403 for POST to
#   internal hosts, so we allowlist the explicit host:port per agent below.
#   Apply with: nemoclaw <sandbox> policy-add --from-file config/openshell-policy.yaml
#
# TODO(verify-on-arrival): confirm exact field names/format against the installed NemoClaw
# v0.0.59 blueprint policy (nemoclaw-blueprint/policies/openclaw-sandbox.yaml). The shape below
# (per-agent -> rules[] -> {endpoint, binaries[], methods[], paths[]}) follows master plan §4; the
# installed schema is authoritative. Fill node's SHA256 on the box (sha256sum /usr/local/bin/node).

version: 1
default: deny

_anchors:
  # Two inference routes — routine tier (:8001) and heavy tier (:8002). An agent gets only its tier.
  vllm_resident: &vllm_resident
    endpoint: "<spark-ip>:8001"             # routine tier (Qwen3.6); explicit host:port, NOT inference.local
    binaries: ["/usr/local/bin/node"]        # OpenClaw runs as node; missing -> 403
    methods: ["GET", "POST"]
  vllm_heavy: &vllm_heavy
    endpoint: "<spark-ip>:8002"             # heavy tier (GPT-OSS-120B, on-demand)
    binaries: ["/usr/local/bin/node"]
    methods: ["GET", "POST"]
  slack: &slack
    endpoint: "api.slack.com:443, slack.com:443, wss-*.slack.com:443"
    binaries: ["/usr/local/bin/node"]
    methods: ["GET", "POST"]
  telegram: &telegram
    endpoint: "api.telegram.org:443"        # default policy historically had NO binaries for telegram — add node
    binaries: ["/usr/local/bin/node"]
    methods: ["GET", "POST"]
  github: &github
    endpoint: "api.github.com:443, github.com:443"
    binaries: ["/usr/local/bin/node", "/usr/bin/git"]
    methods: ["GET", "POST"]
  npm: &npm
    endpoint: "registry.npmjs.org:443"
    binaries: ["/usr/local/bin/node", "/usr/local/bin/npm"]
    methods: ["GET"]
  pip: &pip
    endpoint: "pypi.org:443, files.pythonhosted.org:443"
    binaries: ["/usr/bin/python3", "/usr/local/bin/pip"]
    methods: ["GET"]

agents:
  ceo:
    rules:
      - *vllm_resident                       # CEO sub-agents fan out on the cheap resident model
      - endpoint: "api.anthropic.com:443"    # ONLY the CEO reaches Anthropic
        binaries: ["/usr/local/bin/node"]
        methods: ["POST"]
  pa:        { rules: [ *vllm_resident, *slack, *telegram ] }                 # routine tier
  pm:        { rules: [ *vllm_resident, *slack, *telegram ] }                 # routine tier
  architect: { rules: [ *vllm_heavy, *slack, *telegram ] }                    # heavy tier
  coder:     { rules: [ *vllm_heavy, *slack, *telegram, *github, *npm, *pip ] }   # heavy tier + package egress (coder only, +devops)
  qa:        { rules: [ *vllm_heavy, *slack, *telegram ] }                    # heavy tier
  security:  { rules: [ *vllm_heavy, *slack, *telegram ] }                    # heavy tier
  devops:    { rules: [ *vllm_resident, *slack, *telegram, *github, *npm, *pip ] }  # routine tier + package egress

  # (R2) Scheduled egress probe (scripts/07) is NOT an LLM agent. It runs `curl`, but every rule above
  # only allowlists `node`, so a curl probe would itself be denied (a false alarm). CHOICE made explicit:
  # grant /usr/bin/curl GET-only to the two inference ports + the Anthropic /v1/models path ONLY — the
  # tightest grant that lets a curl-based probe run.
  # TODO(verify-on-arrival): confirm the installed NemoClaw supports per-binary + per-method + per-path
  # scoping at this granularity. If it does NOT (curl would gain broader reach than intended), REPLACE
  # this block by reimplementing scripts/07 as a Node script that reuses the already-allowlisted node
  # binary, and delete this probe grant.
  probe:
    rules:
      - { endpoint: "<spark-ip>:8001",        binaries: ["/usr/bin/curl"], methods: ["GET"], paths: ["/v1/models"] }
      - { endpoint: "<spark-ip>:8002",        binaries: ["/usr/bin/curl"], methods: ["GET"], paths: ["/v1/models"] }
      - { endpoint: "api.anthropic.com:443",  binaries: ["/usr/bin/curl"], methods: ["GET"], paths: ["/v1/models"] }
# Everything not listed is denied. No Brave/web-search endpoint until the single
# sandboxed research sub-agent is introduced (Phase 2) behind human-approval gates.
```

- [ ] **Step 2: Verify** — `python3 -c 'import yaml; d=yaml.safe_load(open("config/openshell-policy.yaml")); assert d["default"]=="deny"; assert "anthropic" not in str(d["agents"]["coder"]); assert "8002" in str(d["agents"]["coder"]) and "8001" not in str(d["agents"]["coder"]); assert "8001" in str(d["agents"]["pa"]); assert d["agents"]["probe"]["rules"][0]["binaries"]==["/usr/bin/curl"]; print("OK")'`. Expected: `OK` (default deny; coder reaches only :8002 and never Anthropic; routine agents reach :8001; probe is curl GET-only).
- [ ] **Step 3: Commit**

```bash
git add config/openshell-policy.yaml
git commit -m "feat(config): add deny-by-default openshell egress policy (Imp-1 explicit route)"
```

### Task 2.3: `config/README.md`

**Files:**
- Create: `config/README.md`

- [ ] **Step 1: Write** a file listing: the two configs and what they do; the placeholder list
  (`<spark-ip>`, `<slack-channel-*>`, CEO key via per-agent auth profile); the apply commands
  (`nemoclaw <sandbox> policy-add --from-file config/openshell-policy.yaml`); and the
  `TODO(verify-on-arrival)` to confirm key schemas against the installed `v0.0.59` build.
- [ ] **Step 2: Verify** — `grep -q "spark-ip" config/README.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add config/README.md
git commit -m "docs(config): document configs, placeholders, apply commands"
```

- [ ] **M2 push gate:** after operator approval → `git push`.

---

## Milestone 3 — scripts/

### Task 3.1: `scripts/lib/common.sh` (shared helpers)

**Files:**
- Create: `scripts/lib/common.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# Shared helpers for spark-agent-infra scripts. Source me: . "$(dirname "$0")/lib/common.sh"
# Strict mode so a failed command never silently passes (operator silent-failure rule).
set -euo pipefail

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "$(date +%H:%M:%S)" "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"; }

# confirm "message" — returns 0 if the user types y/Y, else 1. ASSUME_YES=1 skips the prompt.
confirm() {
  if [ "${ASSUME_YES:-0}" = "1" ]; then log "ASSUME_YES=1, proceeding: $1"; return 0; fi
  printf '%s [y/N] ' "$1"; read -r _ans; [ "${_ans:-}" = "y" ] || [ "${_ans:-}" = "Y" ]
}

# run_destructive "description" cmd args... — echoes the exact command, confirms, then runs it.
run_destructive() {
  local desc="$1"; shift
  log "DESTRUCTIVE: $desc"
  printf '  -> %s\n' "$*"
  confirm "Run this?" || die "aborted by user"
  "$@"
}

# idempotency helper: returns 0 if a TCP port already serves on host (so we can skip re-launch).
port_open() { local host="$1" port="$2"; (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null && { exec 3>&-; return 0; } || return 1; }
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/lib/common.sh && bash -n scripts/lib/common.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/lib/common.sh
git commit -m "feat(scripts): add shared bash helpers (confirm/destructive/idempotency)"
```

### Task 3.2: `scripts/01-post-oobe-update.sh`

**Files:**
- Create: `scripts/01-post-oobe-update.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 01 — Post-OOBE system update (aarch64 DGX OS). OTA is deferred by default on the June 2026
# release, so we pull updates deliberately, then confirm the driver/CUDA baseline.
# Idempotent: re-running just re-checks; the apt step is confirmed before it runs.
. "$(dirname "$0")/lib/common.sh"

[ "$(uname -m)" = "aarch64" ] || warn "expected aarch64 DGX OS; uname -m = $(uname -m)"

log "Current driver / CUDA:"
require_cmd nvidia-smi; nvidia-smi --query-gpu=driver_version --format=csv,noheader || warn "nvidia-smi query failed"
if command -v nvcc >/dev/null 2>&1; then nvcc --version | tail -2; else warn "nvcc not on PATH yet"; fi

run_destructive "apt update + full-upgrade (pull deferred OTA/OS updates)" \
  sudo sh -c 'apt-get update && apt-get -y full-upgrade'

# Assert the expected baseline; warn (do not fail) so the operator decides.
DRV="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)"
case "$DRV" in 580.*) log "driver on 580 branch: $DRV";; *) warn "driver not on 580 branch (got '$DRV') — 570 is EOL; verify";; esac
# TODO(verify-on-arrival): confirm DGX OS build (7.5.x line) and CUDA 13.x via `nvcc --version`.
log "01 complete. Next: scripts/02-nemoclaw-install.sh"
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/01-post-oobe-update.sh && bash -n scripts/01-post-oobe-update.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/01-post-oobe-update.sh
git commit -m "feat(scripts): 01 post-OOBE system update with driver/CUDA check"
```

### Task 3.3: `scripts/02-nemoclaw-install.sh`

**Files:**
- Create: `scripts/02-nemoclaw-install.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 02 — Non-interactive NemoClaw + OpenShell install. Uses --non-interactive to avoid the
# curl|bash EOF gotcha (#362) that half-initializes the gateway (later EADDRINUSE on 8080).
# Idempotent: skips install if `nemoclaw` already present; always re-verifies the gateway.
. "$(dirname "$0")/lib/common.sh"

: "${NVAPI_KEY:?set NVAPI_KEY (nvapi- key from build.nvidia.com) before running}"

if command -v nemoclaw >/dev/null 2>&1; then
  log "nemoclaw already installed: $(nemoclaw --version 2>/dev/null || echo unknown) — skipping install"
else
  run_destructive "download + run the NemoClaw installer (network fetch, runs as bash)" \
    bash -c 'curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash -s -- --non-interactive'
fi

# Verify the dashboard gateway is reachable on the exact loopback origin (127.0.0.1, NOT localhost).
if port_open 127.0.0.1 18789; then
  log "gateway up on 127.0.0.1:18789"
else
  warn "gateway not answering on 127.0.0.1:18789 — check onboard state"
  # Not silently swallowed: surface the likely EADDRINUSE/half-init path for the operator.
  warn "if onboard skipped the sandbox-name prompt, re-run onboard non-interactively; check port 8080 for a stale gateway"
fi
# TODO(verify-on-arrival): pin NemoClaw by tag v0.0.59 or commit SHA (it is a git tag, not a Release).
log "02 complete. Apply config/openshell-policy.yaml and config/openclaw.json next."
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/02-nemoclaw-install.sh && bash -n scripts/02-nemoclaw-install.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/02-nemoclaw-install.sh
git commit -m "feat(scripts): 02 non-interactive nemoclaw install + gateway verify"
```

### Task 3.4: `scripts/05-drop-caches.sh` (written before 03/04 — they depend on it)

**Files:**
- Create: `scripts/05-drop-caches.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 05 — UMA page-cache flush ritual. On unified memory you can hit OOM within capacity;
# NVIDIA's vLLM troubleshooting directs this flush between model swaps and before loading 120B.
. "$(dirname "$0")/lib/common.sh"
run_destructive "flush page cache (sync; drop_caches=3) — affects the whole system's buffer cache" \
  sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'
log "page cache flushed."
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/05-drop-caches.sh && bash -n scripts/05-drop-caches.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/05-drop-caches.sh
git commit -m "feat(scripts): 05 UMA page-cache flush ritual"
```

### Task 3.5: `scripts/03-serve-120b.sh`

**Files:**
- Create: `scripts/03-serve-120b.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 03 — Serve GPT-OSS-120B MXFP4 (heavy, ON-DEMAND) on :8002. Flush caches first (05), then serve via
# the eugr CUTLASS MXFP4 path (avoids the sm_121 Marlin wrong-first-token bug #37030). TP MUST be 1.
# (R1) Idempotent on the HEAVY port: if :8002 already serves, do nothing. Resident Qwen lives on :8001
# (scripts/04) — one vllm process = one port, so the two models MUST use distinct ports.
# Supervision: run under tmux/systemd/a container (vllm serve blocks the foreground). Phase-1 upgrade
# path: front :8001/:8002 with llama-swap (:28080) behind LiteLLM (:14000) for on-demand swapping
# (master plan §2), then point openclaw.json's baseUrls at the router.
. "$(dirname "$0")/lib/common.sh"
require_cmd vllm

HEAVY_PORT="${HEAVY_PORT:-8002}"
if port_open 127.0.0.1 "$HEAVY_PORT"; then log "heavy tier already up on :$HEAVY_PORT — not starting 120B"; exit 0; fi

log "flushing caches before the heavy load…"; "$(dirname "$0")/05-drop-caches.sh"

# TODO(verify-on-arrival): pin the eugr image/wheel (cu132) or NGC digest; confirm flags on the build.
log "starting GPT-OSS-120B MXFP4 on :$HEAVY_PORT (TP=1, CUTLASS MXFP4 path)…"
vllm serve openai/gpt-oss-120b \
  --port "$HEAVY_PORT" \
  --tensor-parallel-size 1 \
  --max-num-seqs 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --enable-prefix-caching \
  --enable-chunked-prefill \
  --reasoning-parser gpt-oss --tool-call-parser gpt-oss
```

> Note for executor: the master plan also documents the eugr launcher form
> (`launch-cluster.sh --solo --exp-mxfp4 --mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head`).
> Keep the `vllm serve` flags above as the canonical interface; record the eugr launcher as a
> comment so the operator can swap engines without losing the flag set.

- [ ] **Step 2: Verify** — `shellcheck -x scripts/03-serve-120b.sh && bash -n scripts/03-serve-120b.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/03-serve-120b.sh
git commit -m "feat(scripts): 03 serve GPT-OSS-120B MXFP4 on-demand (TP=1, CUTLASS)"
```

### Task 3.6: `scripts/04-serve-qwen-resident.sh` (with optional MTP + fallback)

**Files:**
- Create: `scripts/04-serve-qwen-resident.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 04 — Serve Qwen3.6-35B-A3B NVFP4 (routine, ALWAYS-RESIDENT) on :8001 via the eugr/Marlin backend
# (upstream vLLM still lacks the SM12x NVFP4 fix — PR #35947 closed unmerged). Needs the
# Transformers-5.x build (eugr build-and-copy.sh --tf5).
# (R1) Resident on :8001; the on-demand 120B uses :8002 (scripts/03) — distinct ports, one process each.
# Supervision: this is ALWAYS-ON, so run it under tmux/systemd/a container — NOT a blocking foreground
# shell that dies with your SSH session. (Phase-1 upgrade: llama-swap+LiteLLM, master plan §2.)
# MTP is OPTIONAL and FALLBACK-GUARDED — never load-bearing (NVFP4 spec-decode can crash).
. "$(dirname "$0")/lib/common.sh"
require_cmd vllm

RESIDENT_PORT="${RESIDENT_PORT:-8001}"
COMMON=( nvidia/Qwen3.6-35B-A3B-NVFP4 --port "$RESIDENT_PORT"
  --tensor-parallel-size 1 --max-num-seqs 4 --max-model-len 32768
  --gpu-memory-utilization 0.45 --kv-cache-dtype fp8 --enable-prefix-caching --trust-remote-code )

start_plain() { log "starting Qwen3.6 resident (no MTP)…"; vllm serve "${COMMON[@]}"; }

if [ "${MTP:-0}" = "1" ]; then
  log "MTP=1 requested — attempting speculative-decoding variant (experimental)…"
  # Capture failure explicitly; on ANY non-zero, fall back to the plain config and alert.
  if ! vllm serve "${COMMON[@]}" --speculative-config '{"method":"mtp"}'; then
    warn "MTP variant failed — falling back to non-MTP resident config (not load-bearing)."
    [ -n "${SLACK_WEBHOOK:-}" ] && curl -fsS -X POST -H 'Content-Type: application/json' \
      -d '{"text":"spark: Qwen MTP variant crashed; fell back to non-MTP resident."}' "$SLACK_WEBHOOK" || true  # alert is best-effort; N=1 webhook, failure mode = no Slack ping (already logged above)
    start_plain
  fi
else
  start_plain
fi
# TODO(verify-on-arrival): confirm the exact eugr MTP/speculative flag for the installed build.
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/04-serve-qwen-resident.sh && bash -n scripts/04-serve-qwen-resident.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/04-serve-qwen-resident.sh
git commit -m "feat(scripts): 04 serve Qwen3.6-35B resident (eugr/Marlin) + optional MTP fallback"
```

### Task 3.7: `scripts/06-ssh-tunnel-dashboard.sh` (Mac side)

**Files:**
- Create: `scripts/06-ssh-tunnel-dashboard.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 06 — (run on your Mac) SSH tunnel to the dashboard. The gateway origin check requires the
# EXACT origin 127.0.0.1:18789 (localhost != 127.0.0.1), so we always forward to 127.0.0.1.
# Idempotent: if local :18789 already serves, the tunnel is already up.
. "$(dirname "$0")/lib/common.sh"

DGX_HOST="${DGX_HOST:?set DGX_HOST=<user>@<DGX_LAN_IP> (or a Tailscale name)}"
if port_open 127.0.0.1 18789; then log "127.0.0.1:18789 already reachable — tunnel likely up"; exit 0; fi

log "opening tunnel: 127.0.0.1:18789 -> ${DGX_HOST}:127.0.0.1:18789  (Ctrl-C to close)"
log "then open http://127.0.0.1:18789/ in your browser"
exec ssh -N -L 18789:127.0.0.1:18789 "$DGX_HOST"
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/06-ssh-tunnel-dashboard.sh && bash -n scripts/06-ssh-tunnel-dashboard.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/06-ssh-tunnel-dashboard.sh
git commit -m "feat(scripts): 06 mac-side ssh tunnel to dashboard (always 127.0.0.1)"
```

### Task 3.8: `scripts/07-egress-probe.sh` (Imp 1)

**Files:**
- Create: `scripts/07-egress-probe.sh`

- [ ] **Step 1: Write the file:**

```bash
#!/usr/bin/env bash
# 07 — Synthetic egress probe (Improvement 1). Runs FROM INSIDE the sandbox on a schedule and
# exercises every hot inference route, alerting to Slack on a policy/proxy 403 (or an unreachable
# always-on route) BEFORE a real agent turn hits it — converting a silent, global, post-update break
# into one early alert.
# (R2) curl is used WITHOUT -f so we capture the real %{http_code}: with -f, a 401/403 becomes curl
# exit 22 -> our code="000" -> a PERMANENT false alarm. The OpenShell policy must grant /usr/bin/curl
# GET-only to :8001/:8002/api.anthropic.com (see config/openshell-policy.yaml `probe:` block). If that
# per-binary/method/path scoping isn't supported on the installed build, reimplement this as a node
# script that reuses the already-allowlisted node binary (TODO(verify-on-arrival)).
# Schedule (example): */10 * * * *  /path/scripts/07-egress-probe.sh   # every 10 min
. "$(dirname "$0")/lib/common.sh"
require_cmd curl

SPARK_IP="${SPARK_IP:?set SPARK_IP=<spark-ip>}"
fail=0

probe() { # name url mode(always_up|on_demand|reachable)
  local name="$1" url="$2" mode="$3" code
  code="$(curl -sS -o /tmp/probe.out -w '%{http_code}' --max-time 8 "$url" 2>/tmp/probe.err)" || code="000"
  case "$mode:$code" in
    *:403)         warn "probe FAIL: $name -> 403 (OpenShell policy / CONNECT-proxy block)"; fail=1 ;;
    always_up:200) log  "probe OK: $name (200)" ;;
    always_up:*)   warn "probe FAIL: $name -> HTTP $code (resident endpoint should be 200)"; sed 's/^/    /' /tmp/probe.err >&2; fail=1 ;;
    on_demand:200) log  "probe OK: $name (200, loaded)" ;;
    on_demand:000) log  "probe OK: $name (000 = not loaded; route is fine, no 403)" ;;
    on_demand:*)   warn "probe FAIL: $name -> HTTP $code"; fail=1 ;;
    reachable:000) warn "probe FAIL: $name -> 000 (unreachable: route/proxy/timeout)"; fail=1 ;;
    reachable:*)   log  "probe OK: $name ($code = reachable)" ;;
  esac
}

probe "vllm-resident:8001" "http://${SPARK_IP}:8001/v1/models" always_up    # always-on routine tier
probe "vllm-heavy:8002"    "http://${SPARK_IP}:8002/v1/models" on_demand    # 000 = simply not loaded; 403 = real break
if [ -n "${OLLAMA_PROXY:-}" ]; then probe "ollama:11435" "$OLLAMA_PROXY" reachable; fi
probe "anthropic"          "https://api.anthropic.com/v1/models" reachable  # 401 = reachable (no key here); 403 = blocked

if [ "$fail" = "1" ] && [ -n "${SLACK_WEBHOOK:-}" ]; then
  # N=1 webhook; if this POST fails the only consequence is "no Slack ping" — already logged above, and
  # the nonzero exit below still trips scheduler-level alerting. Not silently swallowed.
  curl -sS -X POST -H 'Content-Type: application/json' \
    -d '{"text":"spark egress-probe FAILED — an inference route returned 403/timeout. Check OpenShell policy + node binary SHA256."}' \
    "$SLACK_WEBHOOK" >/dev/null || warn "could not post Slack alert (webhook failing)"
fi
[ "$fail" = "0" ] || die "egress probe detected a broken route"
log "all egress routes healthy."
```

- [ ] **Step 2: Verify** — `shellcheck -x scripts/07-egress-probe.sh && bash -n scripts/07-egress-probe.sh && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/07-egress-probe.sh
git commit -m "feat(scripts): 07 synthetic egress probe with Slack alert (Imp-1)"
```

### Task 3.9: `scripts/README.md`

**Files:**
- Create: `scripts/README.md`

- [ ] **Step 1: Write** a file documenting: run order (01→02→config→04→03; 06 on Mac; 07 scheduled);
  the **two serving ports** (resident Qwen `:8001` via 04, on-demand 120B `:8002` via 03 — distinct
  because one vllm process binds one port); that **04 and 03 must run under tmux/systemd/a container**
  (they block the foreground) and **llama-swap+LiteLLM** is the Phase-1 upgrade path to one endpoint
  (master plan §2); required env vars (`NVAPI_KEY`, `DGX_HOST`, `SPARK_IP`, `SLACK_WEBHOOK`, optional
  `MTP`, `RESIDENT_PORT`, `HEAVY_PORT`, `ASSUME_YES`, `OLLAMA_PROXY`); that **07's probe needs the
  `probe:` curl grant** in `config/openshell-policy.yaml` (or be rewritten as a node script); and the
  idempotency + confirm-before-destructive conventions (all scripts source `lib/common.sh`).
- [ ] **Step 2: Verify** — `grep -q "run order" scripts/README.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add scripts/README.md
git commit -m "docs(scripts): document run order, env vars, conventions"
```

- [ ] **M3 push gate:** after operator approval → `git push`.

---

## Milestone 4 — runbooks/

> These distill master-plan §4–5 and add Improvement 2. Content specs below are exact: write the
> listed sections with the listed commands verbatim. Verify each with `grep` for a key line.

### Task 4.1: `runbooks/daily.md`
**Content spec — sections + exact commands:**
- **Health:** `nemoclaw <name> status`; gateway health; review overnight Heartbeat actions.
- **GPU/memory:** `nvidia-smi` (note GB10 reports ~121.7 GiB of 128); watch post-swap UMA lag; tokens/sec via vLLM `/metrics` and LiteLLM logs.
- **Security scan:** grep logs for `denied/blocked/error` and unexpected outbound connections.
- **Cost:** check the Anthropic spend dashboard against the daily ceiling.
- Verify: `grep -q "nemoclaw <name> status" runbooks/daily.md`. Commit `docs(runbooks): add daily ops`.

### Task 4.2: `runbooks/weekly.md`
**Content spec:**
- `openclaw security audit --deep`; re-vet new/updated skills (auto-update OFF; re-scan with Clawdex/ClawNet); update vLLM/NemoClaw deliberately (pin digests; test on a non-critical agent first); back up workspaces (git commit/push) + config; review tokens/sec + per-agent cost; rebalance if a routine agent overuses the 120B.
- Verify: `grep -q "security audit --deep" runbooks/weekly.md`. Commit `docs(runbooks): add weekly ops`.

### Task 4.3: `runbooks/kill-switch.md`
**Content spec — the 4-step recovery, in order, verbatim commands:**
1. Stop session/gateway: `openclaw gateway restart` (or kill the session); sandbox: `nemoclaw <name> stop`.
2. Kill inference: `docker stop` the vLLM / llama-swap / sandbox containers.
3. Revoke the Anthropic API key in the console (+ rotate bot tokens) if compromise suspected.
4. Review logs (`logToolCalls`/`logMessages`/`logApiCalls`/`redactSecrets`) and `lsof -i -P -n | grep` for unexpected outbound before restart.
- Verify: `grep -q "nemoclaw <name> stop" runbooks/kill-switch.md`. Commit `docs(runbooks): add kill-switch`.

### Task 4.4: `runbooks/rollout-phases.md`
**Content spec — the 3 phases:**
- **Phase 1 (Weeks 1–3, 3–4 agents):** CEO + PA + Coder + DevOps; validate serving, proxy/allowlist, Slack, spend caps, fail-stops; pairing mode; no web browsing.
- **Phase 2 (Weeks 4–8, expand to 8):** add PM/Architect/QA/Security; introduce dispatcher; one tightly-sandboxed research sub-agent behind human approval. (Dashboard = Imp-3 decision, deferred; never give 3rd-party code the kill-switch.)
- **Phase 3 (Month 2–3):** add Hermes for learning loops on non-critical workflows once stability + security proven.
- Verify: `grep -q "Phase 1" runbooks/rollout-phases.md`. Commit `docs(runbooks): add staged rollout phases`.

### Task 4.5: `runbooks/failure-modes.md` (Improvement 2 — keystone)

**Files:** Create `runbooks/failure-modes.md`

- [ ] **Step 1: Write the file:**

```markdown
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
```

- [ ] **Step 2: Verify** — `grep -q "workspace-git guard" runbooks/failure-modes.md && grep -q "golden-set" runbooks/failure-modes.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit**

```bash
git add runbooks/failure-modes.md
git commit -m "docs(runbooks): add four failure-mode playbooks (Imp-2, git-guard keystone)"
```

### Task 4.6: `runbooks/README.md`
- [ ] Write an index linking the five runbooks with one-line summaries. Verify `grep -q failure-modes runbooks/README.md`. Commit `docs(runbooks): add index`.

- [ ] **M4 push gate:** after operator approval → `git push`.

---

## Milestone 5 — tasks/ (queue spine, Improvement 3)

### Task 5.1: `tasks/TEMPLATE.md` (CEO decomposition format)

**Files:** Create `tasks/TEMPLATE.md`

- [ ] **Step 1: Write the file:**

```markdown
# Task decomposition template (CEO)

Every delegation uses this. In the queue it becomes a file with YAML frontmatter + a running log.

GOAL:          <one-sentence outcome>
OWNER:         <agent id>
INPUTS:        <files/links/context refs in the shared workspace>
DELIVERABLE:   <artifact + exact location>
DONE-CRITERIA: <objective, testable checks>
BUDGET:        <max tokens / max runtime / max retries>
```

- [ ] **Step 2: Verify** — `grep -q "DONE-CRITERIA" tasks/TEMPLATE.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit** `git add tasks/TEMPLATE.md && git commit -m "feat(tasks): add CEO decomposition template"`.

### Task 5.2: `tasks/README.md` (queue format + lifecycle + spine rule)

**Files:** Create `tasks/README.md`

- [ ] **Step 1: Write the file:**

```markdown
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
```

- [ ] **Step 2: Verify** — `grep -q "single source of truth" tasks/README.md && grep -q "one file per task" tasks/README.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit** `git add tasks/README.md && git commit -m "feat(tasks): define one-file-per-task queue + spine rule (Imp-3)"`.

### Task 5.3: example task + `.gitkeep`

**Files:** Create `tasks/queue/.gitkeep`, `tasks/queue/EXAMPLE-0001-bootstrap-serving.md`

- [ ] **Step 1:** `tasks/queue/.gitkeep` empty. Write the example:

```markdown
---
id: t-0001
goal: Stand up resident Qwen3.6 and validate tokens/sec on the Spark
owner: devops
status: queued
inputs:  [scripts/04-serve-qwen-resident.sh, runbooks/daily.md]
deliverable: a healthy :8001 endpoint + a tokens/sec reading recorded in this log
done_when:
  - "curl http://<spark-ip>:8001/v1/models returns 200"
  - "tokens/sec for Qwen3.6 recorded and >= 30 under light load"
budget: { tokens: 20000, runtime_min: 30, retries: 2 }
---
# running log
- (seed) example task; replace with real Phase-1 work.
```

- [ ] **Step 2: Verify** — `test -f tasks/queue/.gitkeep && grep -q "done_when" tasks/queue/EXAMPLE-0001-bootstrap-serving.md && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit** `git add tasks/queue && git commit -m "feat(tasks): add queue dir + example task"`.

- [ ] **M5 push gate:** after operator approval → `git push`.

---

## Milestone 6 — docs/

### Task 6.1: copy the diagram into the repo
**Files:** Create `docs/diagrams/infrastructure-map.svg`
- [ ] **Step 1:** `mkdir -p docs/diagrams && cp ~/Downloads/complete_spark_agent_infrastructure_map.svg docs/diagrams/infrastructure-map.svg`
- [ ] **Step 2: Verify** — `grep -q "OpenShell sandbox" docs/diagrams/infrastructure-map.svg && echo OK`. Expected: `OK`.
- [ ] **Step 3: Commit** `git add docs/diagrams/infrastructure-map.svg && git commit -m "docs: add infrastructure topology diagram"`.

### Task 6.2: `docs/architecture.md`
**Content spec:** a one-screen description mirroring the diagram — the wall (operator/Mac/phone off-limits),
Slack/Telegram bus, Opus CEO (capped), the Spark hosting the OpenShell sandbox (8 agents, deny-by-default
egress) + local vLLM models + revocable agent email/GitHub identities, and the git workspace as the bridge.
Embed `![topology](diagrams/infrastructure-map.svg)`. Cross-link `../CLAUDE.md` and `master-plan.md`.
- [ ] Verify `grep -q "deny-by-default" docs/architecture.md`. Commit `docs: add architecture overview`.

### Task 6.3: `docs/proposals/operating-workflow-improvements.md` (the 5 flagged ideas)

**Files:** Create `docs/proposals/operating-workflow-improvements.md`

- [ ] **Step 1: Write the file** — header noting these are flagged proposals (NOT design changes; locked
  hardware + three-tier model split unchanged), then one paragraph each (idea · risk/leverage · cost):

```markdown
# Operating-workflow improvement proposals (flagged — not design changes)

Beyond approved Improvements 1–5. Locked decisions (hardware, three-tier model split,
OpenClaw/NemoClaw stack) are unchanged. Each: idea · risk-or-leverage · cost.

## P1 — CEO cache-economics report
Nightly digest of Anthropic + LiteLLM logs: cache-hit ratio per agent, cached-prefix token size
and drift, top cost-driving turns. *Risk:* silent cost creep from cache misses / prefix bloat the
plan warns about but never instruments. *Cost:* low (one cron + Slack post).

## P2 — Prefill-budget linter + scheduled MEMORY compaction
Assert each agent's prefilled file set stays under a token budget (CI/pre-turn); scheduled
compaction of stale MEMORY. *Leverage:* keeps the cost model valid over time + reduces
post-compaction derailment. *Cost:* low.

## P3 — Injection-canary regression test for the browsing sub-agent
Plant honeytokens; periodically feed the research sub-agent a local adversarial fixture and assert
it neither takes the forbidden action nor emits the canary. *Risk:* silent erosion of injection
defenses after a model/policy change — makes containment a tested boundary. *Cost:* low-med
(runs in the golden-set window).

## P4 — Positive egress audit (contacted-destinations diff vs. allowlist)
Normalize the day's actual outbound connections and diff against the policy YAML; alert on any new
destination, flag unused allowlist entries as prune candidates. *Risk:* allowlist drift / first-time
use of an over-broad entry / a swapped binary reaching an allowed host. *Cost:* low (complements Imp-1).

## P5 — Heavy-tier swap lock + CEO "heavy busy/cold" awareness  ← FIRST PROMOTION CANDIDATE (Phase 1–2)
Serialize 120B cold-loads behind a lease (four heavy agents share one on-demand model on a TP=1 box
with UMA free-lag); enforce drop_caches + lag wait; expose a status the CEO reads before dispatching.
*Leverage:* turns the heavy tier from a race into a governed resource. *Cost:* med (small lock service
+ one CEO-checked field). **First proposal to promote out of docs-only:** the two-direct-port scaffold
(8001 resident / 8002 heavy) makes concurrent 120B cold-loads a real Phase-1 hazard, so this guard
earns its place earliest.
```

- [ ] **Step 2: Verify** — `grep -c "^## P" docs/proposals/operating-workflow-improvements.md`. Expected: `5`.
- [ ] **Step 3: Commit** `git add docs/proposals && git commit -m "docs(proposals): capture 5 flagged operating-workflow ideas"`.

- [ ] **M6 push gate:** after operator approval → `git push`.

---

## Milestone 7 — Dev-workflow hardening (operator opted into ALL items)

> All five items are approved. Order: schemas → CI → pre-commit → branch-protection → **justfile last**.
> **Branch protection caveat (operator rule):** branch protection / rulesets on a **private** repo are
> often plan-tier-gated. Before assuming anything, run the actual endpoint and read the failure mode:
> `gh api repos/merttutcu-ops/DGX_Spark_Infrastructure/rulesets` (and the branch-protection
> `PUT .../branches/main/protection`). A **404 (missing feature) ≠ 403 (plan-gated)**. If it 403s for
> plan reasons, the no-cost fallback is a local **pre-push hook** + a **required CI status check on merge** —
> same protection, no purchase. Never recommend an upgrade without the probe output proving it unblocks this.

### Task 7.1: `config/openclaw.schema.json` + `config/openshell-policy.schema.json`
- [ ] JSON Schemas validating the two configs (required keys: providers/agents.list[].{id,model,workspace};
  policy `default == deny`, per-agent `rules[]`, and the `probe` curl grant). Verify each config against its
  schema with `python3 -c 'import json,jsonschema,yaml; ...'`. Commit `feat(config): add JSON schemas`.

### Task 7.2: `.github/workflows/ci.yml`
- [ ] Workflow running on PR: `shellcheck -x scripts/**/*.sh`, `shfmt -d scripts`, `jq empty config/*.json`,
  the YAML/schema validation, and `gitleaks detect`. Each job fails loudly on error (no `continue-on-error`).
  Verify with `actionlint .github/workflows/ci.yml` (or `python3 -c 'import yaml; yaml.safe_load(open(...))'`).
  Commit `ci: add lint/validate/secret-scan workflow`.

### Task 7.3: `.pre-commit-config.yaml`
- [ ] Hooks mirroring CI (shellcheck, shfmt, a JSON/YAML check, gitleaks). Verify `pre-commit run --all-files`.
  Commit `chore: add pre-commit hooks`.

### Task 7.4: branch protection (run the `gh api` probe FIRST, fallback ready)
- [ ] Run the `gh api` probe above FIRST; record the real failure mode (404 missing-feature ≠ 403 plan-gated).
  If available on the repo's plan, enable protection (no force-push/rebase, required CI check). If plan-gated,
  install the local **pre-push hook** fallback instead and document the decision in `runbooks/failure-modes.md` §1.

### Task 7.5: `justfile` (LAST)
- [ ] `lint`, `validate`, `fmt` recipes wrapping the above. Verify `just --list`. Commit `chore: add justfile`.

- [ ] **M7 push gate:** after operator approval → `git push`.

---

## Self-Review (completed by plan author; updated after riders R1–R5)

**1. Spec coverage** — every kickoff deliverable maps to a task:
- Deliverable 1 (scaffold + CLAUDE.md + "do not invent" rule) → M0 (Tasks 0.1–0.3).
- Deliverable 2 (8 agent workspaces, distinct personas) → M1 (1.1–1.10, delta table).
- Deliverable 3 (`openclaw.json` routing) → Task 2.1. Deliverable 4 (`openshell-policy.yaml`, per-agent scoped) → Task 2.2.
- Deliverable 5 (scripts 01–06 + 07 egress) → M3 (3.1–3.9). Deliverable 6 (runbooks incl. failure-modes) → M4. Deliverable 7 (`tasks/TEMPLATE.md`) → Task 5.1.
- Addendum Imp 1 (07-egress-probe + explicit host:port route in policy comments) → Tasks 3.8 + 2.2. Imp 2 (failure-modes.md) → Task 4.5. Imp 3 (queue-as-spine) → M5 + CLAUDE.md convention 1. Imp 5 (pin CUDA 13.2 / NGC 26.05 / NemoClaw v0.0.59; MTP optional+fallback) → CLAUDE.md pins + Tasks 3.5/3.6. Imp 4 (Mission Control) intentionally NOT scaffolded.
- Brainstorm outputs: 5 operating proposals → Task 6.3 (docs-only; P5 flagged first promotion candidate); dev-workflow items → M7 (ALL opted-in).

**2. Placeholder scan** — all `<...>` are intentional runtime placeholders (`<spark-ip>`, `<slack-channel-*>`, `<user>@<DGX_LAN_IP>`) or explicit `TODO(verify-on-arrival)` markers with the confirming command. No vague "add error handling"/"TBD".

**3. Name/type consistency** — agent ids (`ceo/pa/pm/architect/coder/qa/security/devops`), routing model ids (`anthropic/claude-opus-4-8`, `vllm-heavy/gpt-oss-120b`, `vllm-resident/Qwen3.6-35B-A3B-NVFP4`), ports (**:8001 resident**, **:8002 heavy**, 18789 dashboard, 8080 gateway, 11435 Ollama proxy), and queue states (`queued/in_progress/review/done/blocked`) are identical across CLAUDE.md, the delta table, `openclaw.json`, the policy YAML, the scripts, the probe, and `tasks/README.md`. The script run order (01→02→config→04→03; 06 Mac; 07 scheduled) is consistent between README, scripts/README, and the inter-script calls (03 calls 05). Routine agents (pa/pm/devops) → :8001; heavy (architect/coder/qa/security) → :8002; ceo → :8001 + anthropic.

**4. Scope** — one coherent scaffold; milestones are independent and each leaves the repo in a working, reviewable state. No subsystem needs further decomposition.

**5. Rider compliance (R1–R5):**
- **R1 (port topology):** two ports (:8001 resident / :8002 heavy) → two providers in `openclaw.json` → two policy anchors; `03` checks/serves :8002, `04` serves :8001; supervision + llama-swap upgrade-path notes added to `03`/`04`/`scripts/README`; delta-table EGRESS + ceo example + example task + CLAUDE.md pins all updated.
- **R2 (probe correctness):** `-f` removed from all probe curls; per-endpoint classification distinguishes 403 (policy block → FAIL) from on-demand 000 (not loaded → OK) and treats Anthropic 401 as route-OK; the curl-vs-node binary mismatch resolved by an explicit, narrow `probe:` curl GET-only grant in the policy with a node-script fallback + `TODO(verify-on-arrival)`.
- **R3 (CEO escalation):** template escalation generalized (agents → @CEO; CEO → operator); ceo example `AGENTS.md` and delta row set to the operator.
- **R4 (.gitignore):** broad `*token*`/`*secret*` globs replaced with specific names/extensions.
- **R5 (shared USER.md):** explicit relative symlink per agent dir + per-agent resolves-check + `TODO(verify-on-arrival)` on symlink resolution with a deploy-copy fallback.
