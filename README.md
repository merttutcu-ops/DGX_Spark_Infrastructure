# spark-agent-infra

Paste-and-run scaffold for an always-on, **8-agent AI system** on an NVIDIA DGX Spark
(GB10, 128 GB unified, aarch64 DGX OS). Built ahead of the hardware so day 1 is
**clone → fill placeholders → run numbered scripts**.

**Status:** scaffold complete, CI-green, and tagged **`v0.2.0-pre-hardware`** — *"everything knowable
without the box is known."* Every version, quantization, KV-dtype, backend, egress path, failure mode, and
dollar figure that can be pinned without the Spark is pinned and sourced; the rest is marked
`TODO(verify-on-arrival)` for first boot.

> **Read first:** `docs/master-plan.md` (the decided architecture, versions, security rules) and
> `docs/plan-review.md` (independent verification). `CLAUDE.md` is the agents' operating contract.

## Architecture (one screen)
- **You** (MacBook + phone) — walled off from the agents; you talk to the team via Slack/Telegram.
- **DGX Spark** (home, always-on) runs an **OpenShell sandbox** (deny-by-default egress) with **8 OpenClaw
  agents** + local **vLLM** models.
- **Models:** Opus 4.8 CEO via the Anthropic API (capped); GPT-OSS-120B MXFP4 heavy / on-demand (`:8002`);
  Qwen3.6-35B-A3B routine / always-resident (`:8001`).
- Full topology + diagram: `docs/architecture.md`.

## Day-1 order (on the Spark, aarch64)
1. `scripts/01-post-oobe-update.sh` — pull deferred OTA/OS updates; confirm driver 580 / CUDA 13.x.
2. `scripts/02-nemoclaw-install.sh` — non-interactive NemoClaw + OpenShell install.
3. Apply `config/openshell-policy.yaml` (deny-by-default egress) and `config/openclaw.json` (routing).
4. `scripts/04-serve-qwen-resident.sh` — bring up the always-resident routine model (`:8001`).
5. `scripts/03-serve-120b.sh` — bring up the on-demand heavy model when needed (`:8002`).
6. From your Mac: `scripts/06-ssh-tunnel-dashboard.sh` → dashboard at `127.0.0.1:18789`.
7. Schedule `scripts/07-egress-probe.sh` (inference / Anthropic liveness alerting).

> Scripts are numbered as a catalog, not a strict sequence: the order above runs the resident model (04)
> before the on-demand 120B (03) on purpose, and `05-drop-caches.sh` is invoked automatically by `03`.

**Before trusting any tier, run the day-1 gates** in `docs/master-plan.md` → *"Forum-harvest addenda"* and
*"Plan cross-check addenda"*: the resident quant sweep, the tool-eval gate, the heavy-tier backend +
`!!!`/garbage canary, the memory-split math, and the persistence/PVC + session-watchdog checks. The serving
engine itself is decided in `docs/adr/0001-serving-engine-atlas-evaluation.md` (vLLM baseline; Atlas a
resident-only challenger via a gated bake-off).

## Repo map
| Path | What |
|---|---|
| `CLAUDE.md` | agents' constitution: conventions, model IDs, version pins, cost/caching pins |
| `agents/<id>/` | 8 lean workspaces (SOUL/AGENTS/IDENTITY/MEMORY) + a shared `USER.md` |
| `config/` | `openclaw.json` routing · `openshell-policy.yaml` deny-by-default egress · JSON schemas |
| `scripts/` | numbered, idempotent serve / probe / tunnel scripts + `lib/common.sh` |
| `runbooks/` | daily · weekly · kill-switch · rollout · `failure-modes.md` (13) · `openshell-policy-reference.md` |
| `tasks/` | one-file-per-task dispatch queue (the source of truth) + `TEMPLATE.md` |
| `docs/master-plan.md` · `docs/plan-review.md` | source of truth + independent verification |
| `docs/adr/0001-…` | serving-engine decision + day-1 bake-off |
| `docs/finops/opus-cost-model.md` | verified Opus 4.8 CEO cost model + spend limits |
| `docs/proposals/` | flagged ideas P1–P14 (docs-only, not built) |
| `docs/research/2026-06-06-forum-harvest.md` | evidence registry E1–E27 — provenance for every pin |

Dev-workflow hardening (CI: shellcheck / shfmt / schema-validate / gitleaks; pre-commit; `justfile`) is live
in `.github/` + repo root.

## Rollout
`runbooks/rollout-phases.md` — **Phase 1** (CEO + PA + Coder + DevOps, direct tmux/systemd serve) →
**Phase 2** (expand to 8 + dispatcher) → **Phase 3** (Hermes learning loop).

- [x] Scaffold + docs complete · CI-green · tagged `v0.2.0-pre-hardware`
- [ ] Hardware acquired   [ ] Week-1 serving validated   [ ] Phase-1 agents live
  - ↳ once the Spark is in and stable, revisit **PR #7** (Ty's Outpost ↔ Spark integration — `parked: pre-hardware`; `docs/integrations/ty-outpost-integration.md`)

## Safety
Deny-by-default egress; never connect banking / passwords / primary email; skill auto-update OFF; human
approval for any action derived from untrusted content. Kill switch: `runbooks/kill-switch.md`.
