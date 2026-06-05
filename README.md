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

> Scripts are numbered as a catalog, not a strict sequence: the order above runs the resident model (04) before the on-demand 120B (03) on purpose, and `05-drop-caches.sh` is invoked automatically by `03`.

## Status
- [x] Repo scaffold (this).  [ ] Hardware acquired.  [ ] Week-1 serving validated.
- Rollout: see `runbooks/rollout-phases.md` (Phase 1 = CEO + PA + Coder + DevOps).

## Safety
Deny-by-default egress; never connect banking/passwords/primary email; skill auto-update OFF;
human approval for actions derived from untrusted content. Kill switch: `runbooks/kill-switch.md`.
