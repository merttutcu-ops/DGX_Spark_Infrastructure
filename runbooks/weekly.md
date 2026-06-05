# Weekly operations runbook

Run these on a fixed day each week (e.g. Sunday evening) before the next working week starts.

## Security audit

Run the deep security audit across all agents:

```bash
openclaw security audit --deep
```

Re-vet any new or updated skills. **Skill auto-update is OFF** — do not enable it. For any skill
that was updated or installed this week, re-scan with Clawdex/ClawNet before allowing it to run.

## Updates (deliberate, tested)

Update vLLM, NemoClaw, and model images **deliberately**:
- Pull new images/wheels only after reading the release notes.
- **Pin digests immediately** after pulling: record the new `nvcr.io/nvidia/vllm:<tag>@sha256:<digest>`
  in `CLAUDE.md` (Pinned versions section) and in `scripts/03-serve-120b.sh` / `scripts/04-serve-qwen-resident.sh`.
- **Test on a non-critical agent first** (e.g. the DevOps agent) and run the golden-set eval
  (see `runbooks/failure-modes.md` §3) before promoting the new image to all agents.
- If any regression is detected, auto-rollback to the prior pinned image digest.

NemoClaw update:
```bash
# TODO(verify-on-arrival): confirm the correct update/pin command for v0.0.59 and any newer tag.
nemoclaw --version
```

## Backups

Back up all agent workspaces and config:

```bash
# Commit any uncommitted workspace changes
git -C ~/.openclaw/shared-workspace add -A && git -C ~/.openclaw/shared-workspace commit -m "chore: weekly workspace backup $(date +%F)"
git -C ~/.openclaw/shared-workspace push

# Back up openclaw.json and policy YAML (already in this repo)
git add config/openclaw.json config/openshell-policy.yaml
git diff --staged --quiet || git commit -m "chore: weekly config backup $(date +%F)"
```

Verify `git fsck --full` on the shared workspace is clean before and after.

## Performance review

Review tokens/sec and per-agent cost for the week:
- Check LiteLLM logs and the Anthropic usage dashboard.
- If a routine agent (PA/PM/DevOps) is overusing the heavy 120B tier (:8002), investigate
  why calls are being routed there — the routing in `config/openclaw.json` should keep routine
  agents on `:8001`. Rebalance if needed.
- Review CEO cache-hit ratio (Anthropic API logs); if the cached-prefix is bloating, compact
  the relevant `MEMORY.md` files.

## MEMORY compaction

For any agent whose `MEMORY.md` is approaching 400 tokens, compact it:
- Remove stale or redundant entries.
- Commit the compacted file on the agent's branch and merge via the scribe.

> Short MEMORY files keep the prefill cost flat over the lifetime of the system — this is a
> load-bearing maintenance step, not optional housekeeping.
