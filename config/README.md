# config/

Configuration files for OpenClaw agent routing and OpenShell egress policy.
Apply these on the DGX Spark after running `scripts/02-nemoclaw-install.sh`.

## Files

### `openclaw.json` — per-agent model routing
Maps each of the 8 agents to a provider-qualified model id. Two local vLLM providers
plus Anthropic for the CEO:

- **`vllm-resident`** — always-resident routine tier (Qwen3.6-35B-A3B-NVFP4) on `<spark-ip>:8001`,
  served by `scripts/04-serve-qwen-resident.sh`. Agents: pa, pm, devops (and CEO sub-agent fan-out).
- **`vllm-heavy`** — on-demand heavy tier (GPT-OSS-120B MXFP4) on `<spark-ip>:8002`,
  served by `scripts/03-serve-120b.sh`. Agents: architect, coder, qa, security.
- **`anthropic`** — CEO only (`anthropic/claude-opus-4-8`). Key supplied via the CEO's
  per-agent auth profile, not stored in this file.

Phase-1 upgrade path: front both vLLM ports with llama-swap + LiteLLM (master plan §2) and
change the two `baseUrl` values to the router endpoint — no agent-level config changes needed.

### `openshell-policy.yaml` — deny-by-default egress
OpenShell network policy. Sandbox outbound is **blocked by default**; only the endpoints listed
here are reachable, and only by the named binaries using the named HTTP methods.

Key design choices (Imp-1 riders R1/R2):
- Routine agents (pa, pm, devops, CEO) reach only `:8001`; heavy agents (architect, coder, qa,
  security) reach only `:8002`. No agent crosses tiers.
- Only the CEO can reach `api.anthropic.com:443`.
- Only coder and devops get npm/pip/GitHub egress (master plan §4).
- `probe:` block grants `/usr/bin/curl` GET-only to `/v1/models` on both inference ports and
  Anthropic — the tightest grant that lets `scripts/07-egress-probe.sh` run.

## Placeholders — fill before applying

| Placeholder | Where used | How to fill |
|---|---|---|
| `<spark-ip>` | `openclaw.json` (both `baseUrl` values), `openshell-policy.yaml` (all inference endpoints) | The DGX Spark's LAN IP (e.g. `192.168.1.x`); run `hostname -I` on the Spark |
| `<slack-channel-ceo>` | `agents/ceo/IDENTITY.md` (and other per-agent IDENTITY files) | Slack channel ID for each agent's binding |
| CEO Anthropic key | **Not in any file** — supplied via the ceo agent's per-agent auth profile (`~/.openclaw/agents/ceo/`) | Set at runtime; never commit |

> **Symlink note (TODO verify-on-arrival):** Each `agents/<id>/USER.md` is a relative symlink to
> `agents/_shared/USER.md`. Confirm that OpenClaw resolves symlinked workspace files when the
> workspace is deployed to `~/.openclaw/ws-<id>/`. If it does not, replace with a deploy-time copy:
> `cp agents/_shared/USER.md ~/.openclaw/ws-<id>/USER.md` for each agent.

## Apply commands (on the Spark)

```bash
# 1. Fill placeholders first (sed in-place or edit manually):
sed -i 's/<spark-ip>/192.168.1.X/g' config/openclaw.json config/openshell-policy.yaml

# 2. Apply the egress policy to the OpenShell sandbox:
nemoclaw <sandbox> policy-add --from-file config/openshell-policy.yaml

# 3. Apply the OpenClaw routing config:
nemoclaw <sandbox> config-apply --from-file config/openclaw.json

# 4. Verify the policy loaded (should show default: deny):
nemoclaw <sandbox> policy-show
```

## TODO(verify-on-arrival)

- Confirm exact OpenClaw config key names against the installed `v0.0.59` schema
  (`openclaw.json` at `/sandbox/.openclaw/`). Keys to verify: `effort`, `heartbeat.every`,
  `slack.*`, `agents.defaults`. Run: `nemoclaw --version && cat /sandbox/.openclaw/openclaw.json`
- Confirm openshell-policy field names against the NemoClaw blueprint:
  `cat nemoclaw-blueprint/policies/openclaw-sandbox.yaml`
- Confirm NemoClaw supports per-binary + per-method + per-path scoping at the granularity
  used in the `probe:` block. If not, reimplement `scripts/07` as a Node script and delete
  the `probe:` grant (see comment in the policy file).
- Pin the NGC vLLM image digest after first pull:
  `docker inspect nvcr.io/nvidia/vllm:26.05.post1-py3 --format '{{index .RepoDigests 0}}'`
