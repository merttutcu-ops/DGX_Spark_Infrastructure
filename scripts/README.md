# scripts/ — run order, env vars, conventions

All scripts source `scripts/lib/common.sh` for shared helpers (`log`, `warn`, `die`, `confirm`,
`run_destructive`, `port_open`). Every destructive action prompts for confirmation before
running; set `ASSUME_YES=1` to skip (CI/non-interactive use only). Scripts are idempotent:
re-running re-checks state and skips work that is already done.

## run order

Scripts are numbered as a catalog, not a strict sequence. The intended bring-up order is:

1. **`01-post-oobe-update.sh`** (on the Spark) — pull deferred OTA/OS updates; confirm driver
   580 branch / CUDA 13.x baseline.
2. **`02-nemoclaw-install.sh`** (on the Spark) — non-interactive NemoClaw + OpenShell install;
   verifies gateway on `127.0.0.1:18789`.
3. **Apply config** — `config/openshell-policy.yaml` (deny-by-default egress) and
   `config/openclaw.json` (per-agent routing). See `config/README.md` for apply commands.
4. **`04-serve-qwen-resident.sh`** (on the Spark) — bring up the always-resident routine model
   (Qwen3.6-35B-A3B NVFP4) on **`:8001`**. Start this BEFORE the 120B.
5. **`03-serve-120b.sh`** (on the Spark) — bring up the on-demand heavy model (GPT-OSS-120B
   MXFP4) on **`:8002`** when needed. Automatically calls `05-drop-caches.sh` first.
6. **`06-ssh-tunnel-dashboard.sh`** (on your Mac) — open an SSH tunnel so
   `http://127.0.0.1:18789/` is reachable in your browser.
7. **`07-egress-probe.sh`** (scheduled, from inside the sandbox) — synthetic liveness probe for
   all inference and egress routes; Slack alert on failure. Example cron:
   `*/10 * * * *  /path/scripts/07-egress-probe.sh`

> `05-drop-caches.sh` is invoked automatically by `03-serve-120b.sh`; run it manually between
> model swaps on unified memory (UMA page-cache flush ritual).

## serving ports

| Script | Model | Port | Tier |
|---|---|---|---|
| `04-serve-qwen-resident.sh` | Qwen3.6-35B-A3B NVFP4 | **:8001** | routine / always-resident |
| `03-serve-120b.sh` | GPT-OSS-120B MXFP4 | **:8002** | heavy / on-demand |

One vLLM process binds one port — the two models **must** use distinct ports. Scripts `03` and
`04` are idempotent on their respective ports (no-op if already serving).

**`04` and `03` must run under tmux, systemd, or a container** — `vllm serve` blocks the
foreground and dies with your SSH session if run bare.

**Phase-1 upgrade path:** front both ports with `llama-swap` (`:28080`) behind `LiteLLM`
(`:14000`) for on-demand model swapping (master plan §2), then point `openclaw.json`'s
`baseUrls` at the router endpoint instead of the two direct ports.

## required env vars

| Var | Used by | Description |
|---|---|---|
| `NVAPI_KEY` | `02` | nvapi- key from build.nvidia.com (NemoClaw install) |
| `DGX_HOST` | `06` | SSH target, e.g. `user@192.168.1.x` or a Tailscale name |
| `SPARK_IP` | `07` | LAN IP of the Spark (used for probe URLs) |
| `SLACK_WEBHOOK` | `04`, `07` | Incoming webhook URL for Slack alerts (optional but recommended) |

## optional env vars

| Var | Default | Used by | Description |
|---|---|---|---|
| `MTP` | `0` | `04` | Set to `1` to attempt speculative-decoding (MTP) variant with automatic fallback |
| `RESIDENT_PORT` | `8001` | `04` | Override the resident model port |
| `HEAVY_PORT` | `8002` | `03` | Override the heavy model port |
| `ASSUME_YES` | `0` | all | Set to `1` to skip confirmation prompts (non-interactive/CI) |
| `OLLAMA_PROXY` | (unset) | `07` | If set, probe the Ollama proxy endpoint (`:11435`) for reachability |

## egress probe curl grant

`07-egress-probe.sh` runs `curl` (not `node`) to probe inference routes. The OpenShell deny-by-default
policy must include the `probe:` block from `config/openshell-policy.yaml` granting `/usr/bin/curl`
GET-only access to `:8001`, `:8002`, and `api.anthropic.com`. If the installed NemoClaw build does not
support per-binary/method/path scoping at that granularity, reimplement `07` as a Node script that
reuses the already-allowlisted `node` binary and delete the `probe:` curl grant.
See `config/openshell-policy.yaml` → `probe:` block and `TODO(verify-on-arrival)` there.

## idempotency + confirm-before-destructive

Every script:
- Sources `lib/common.sh` (strict mode: `set -euo pipefail`; no silent failures).
- Wraps destructive system calls in `run_destructive` — prints the exact command, confirms, then runs.
- Checks pre-conditions (port open, binary present) before acting, so re-runs are safe.
- Uses `warn` (not `die`) for expected but recoverable situations (driver branch mismatch, gateway not yet
  up); uses `die` for unrecoverable errors.
