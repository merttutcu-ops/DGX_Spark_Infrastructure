# OpenShell network-policy reference (from operator playbook, topic 364781)

> **Source-stack caveat:** these blocks were captured from an operator's live playbook whose serving stack is
> **SGLang + Mistral + ComfyUI** (ports 30000/8188, `openai`-style parsers). For *our* stack the **ports and
> parsers are TEMPLATES** — remap them to our vLLM ports (`:8001` resident, `:8002` heavy). What is
> **load-bearing and portable** is the **policy STRUCTURE** (per-rule endpoints + a binary allowlist keyed on
> `/proc/<pid>/exe` + SHA256) and the **failure classes** in the Known-Issues table.
>
> Paths the operator flagged as `[TOK]`-redacted / reconstructed carry `TODO(verify-against-live-playbook-364781)`.
> The node binary path is **measured at setup** (E23): `readlink /proc/$(pgrep -fn openclaw)/exe` — `/usr/bin/node`
> below is the playbook's value; confirm yours. Evidence: `docs/research/2026-06-06-forum-harvest.md` (E22–E24).

## (a) Network-policy YAML — TEMPLATE

Operator-supplied, annotated. **Remap:** the playbook's single `:30000` SGLang endpoint → our **two** vLLM ports
(`:8001` resident, `:8002` heavy). `<HOST_IP>` and `<SANDBOX>` stay as placeholders.

```yaml
version: 1
filesystem_policy:
  include_workdir: true
  read_only: [/usr, /lib, /proc, /dev/urandom, /app, /etc, /var/log]
  read_write: [/sandbox, /tmp, /dev/null]
landlock:
  compatibility: best_effort
process:
  run_as_user: sandbox
  run_as_group: sandbox
network_policies:
  # --- REMAP: playbook :30000 SGLang -> our two vLLM ports ---
  allow_vllm_resident:                    # was allow_sglang_inference :30000
    endpoints: [{ host: <HOST_IP>, port: 8001, allowed_ips: [<HOST_IP>] }]
    binaries: [{ path: /usr/bin/node }]   # E23: path is MEASURED at setup, not assumed
  allow_vllm_heavy:
    endpoints: [{ host: <HOST_IP>, port: 8002, allowed_ips: [<HOST_IP>] }]
    binaries: [{ path: /usr/bin/node }]
  # --- (b) CEO -> Anthropic. TEMPLATE(operator-verifies); modeled on the telegram block, NODE BINARY ONLY ---
  allow_api_anthropic_com_443:
    endpoints: [{ host: api.anthropic.com, port: 443 }]
    binaries: [{ path: /usr/bin/node }]
  allow_ollama_fallback:
    endpoints: [{ host: <HOST_IP>, port: 11434, allowed_ips: [<HOST_IP>] }]
    binaries: [{ path: /usr/bin/node }, { path: /usr/bin/python3 }, { path: /usr/bin/curl }]
  allow_api_telegram_org_443:
    endpoints: [{ host: api.telegram.org, port: 443 }]
    binaries: [{ path: /usr/bin/node }, { path: /usr/bin/curl }]
  comfyui:                                # TEMPLATE — operator stack only; not in our plan
    endpoints: [{ host: host.openshell.internal, port: 8188, allowed_ips: [172.17.0.1] }]
    binaries: [{ path: /usr/bin/curl }, { path: /usr/bin/python3 }]
  allow_github_clone:
    endpoints:
      - host: github.com
        port: 443
        protocol: rest
        tls: terminate
        enforcement: enforce
        rules:
          - allow: { method: GET,  path: "/**/info/refs*" }
          - allow: { method: POST, path: "/**/git-upload-pack" }
    binaries: [{ path: /usr/bin/git }]
```

> The `172.17.0.1` in the comfyui block is the **Docker bridge IP** (E22) — the same bypass our inference route
> needs when `inference.local` hits its 60s timeout.

## (c) Known issues (verbatim)

| Symptom | Cause | Fix |
|---|---|---|
| `apply_patch` tool absent | tool not registered, silent failure | add to `denyList` in `openclaw.json` |
| `urllib.request` blocked | 403 from OpenShell proxy for `/usr/bin/python3` | use `subprocess.run(["curl", ...])` |
| Telegram media `EAI_AGAIN` | `fetchWithSsrFGuard` `dns.lookup` blocked | apply JS patch (playbook ch.9 phase 5) |
| Session corruption | consecutive user messages → LLM 400 | run session watchdog (failure-modes #12) |
| `TOOLS.md` write fails silently | exact-match failure → cascade HTTP 400 | write via `python3 open().write()` only |
| `"proxy"` in `channels.telegram` | `deleteWebhook`/`getUpdates` 403 | never add this field |
| `--light-context` on cron | skills not visible, agent replies in text | never use with skill-calling jobs |
| `reasoning_effort "low"` | HTTP 400 from SGLang | use `"high"` or `"none"` only |
| ComfyUI 403 from sandbox | Docker bridge IP not whitelisted | `allowed_ips: [172.17.0.1]` in policy |
| Variable scope in exec bash | `$VAR` empty in second exec call | read inline `$(cat file)` in same call |

## (d) Backup model

**Backed up host-side** (the sandbox is ephemeral by design — E24; this set **IS** the persistence model):
`openclaw.json`, `models.json`, `cron/jobs.json`, `devices/`, `credentials/`, `identity/`, `memory/main.sqlite`,
`workspace/` (SOUL/USER/IDENTITY/AGENTS + skills + memory files), `.bashrc`, `.gitconfig`, and an active-policy
snapshot via `openshell policy get <SANDBOX> --full > policy_active.yaml`.

**NOT backed up (intentional):** session history, inbound media, `__pycache__`.

**If `openshell sandbox download <SANDBOX>` fails** (SSH `tar` exit 255 bug): use the `kubectl` stdin-pipe method.

> `TODO(verify-against-live-playbook-364781)`: a config-dir path, the memory-DB path (`memory/main.sqlite`), and the
> policy filename were reconstructed from context — confirm against the live playbook.

## (e) Diagnostics

```sh
curl -s http://127.0.0.1:18789/health
openshell logs <SANDBOX> --tail
curl http://<HOST_IP>:<PORT>/v1/chat/completions -d '{"model":"...","messages":[{"role":"user","content":"ping"}],"max_tokens":10}'
```
