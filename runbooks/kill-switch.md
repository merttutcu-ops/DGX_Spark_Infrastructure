# Kill-switch runbook — runaway-agent recovery

Use this when an agent is behaving unexpectedly, spending uncontrollably, taking unauthorized
actions, or you suspect a security compromise. Run the four steps **in order**.

## Step 1 — Stop the session and gateway

Restart the OpenClaw gateway to terminate all active agent sessions:

```bash
openclaw gateway restart
```

If the gateway is unresponsive, stop the specific sandbox directly:

```bash
nemoclaw <name> stop
```

Replace `<name>` with the sandbox name shown in `nemoclaw list`. Stopping the sandbox
terminates all agent processes inside it.

## Step 2 — Kill inference containers

Stop the vLLM serving containers to cut off model access:

```bash
docker stop $(docker ps -q --filter "name=vllm")
docker stop $(docker ps -q --filter "name=llama-swap")
docker stop $(docker ps -q --filter "name=sandbox")
```

Adjust the filter names to match how you launched them (tmux session names, systemd units,
or container names from `docker ps`). This ensures no queued inference requests can complete
while you investigate.

## Step 3 — Revoke credentials (if compromise suspected)

If you suspect the agent exfiltrated keys or received hostile instructions:

1. **Revoke the Anthropic API key** in the Anthropic console immediately.
   Then generate a new key and store it in the CEO's per-agent auth profile only.
2. **Rotate bot tokens** (Slack bot token, Telegram bot token) in their respective dashboards.
3. **Rotate any other secrets** the agents had access to (GitHub tokens, webhook URLs).

Do not re-issue the same credentials. Treat the old values as compromised.

## Step 4 — Review logs before restart

Before bringing anything back up, audit what happened:

```bash
# Review tool calls and API calls for the time window of the incident
grep -iE "logToolCalls|logMessages|logApiCalls|redactSecrets" ~/.openclaw/logs/*.log | tail -200

# Check for unexpected outbound connections
lsof -i -P -n | grep -v LISTEN
```

Also run:

```bash
lsof -i -P -n | grep -v "127.0.0.1\|<spark-ip>:8001\|<spark-ip>:8002\|api.anthropic.com\|api.slack.com\|api.telegram.org"
```

Any destination not in `config/openshell-policy.yaml` is a policy violation — document it
before restarting. Only resume dispatch once you have a clear picture of what happened and
have addressed the root cause.

> See also `runbooks/failure-modes.md` for playbooks on workspace-git corruption, model
> regression, and recursive sub-agent fan-out, which may accompany a runaway-agent event.
