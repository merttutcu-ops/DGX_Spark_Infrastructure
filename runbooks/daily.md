# Daily operations runbook

Run through these checks each morning (or have the PA agent summarize them in the overnight brief).

## Health

Check each agent's session and gateway state:

```bash
nemoclaw <name> status
```

Verify the dashboard gateway is reachable on the exact loopback origin:

```bash
curl -s http://127.0.0.1:18789/ | head -5
```

Review overnight Heartbeat actions: scan the PA's morning brief in Slack for any actions taken,
task transitions, or escalations that happened while you were away.

## GPU / memory

Query GPU and memory usage:

```bash
nvidia-smi
```

Note: the GB10 reports approximately 121.7 GiB of 128 GiB total unified memory — this is normal;
the remainder is reserved by firmware/OS.

Watch for post-swap UMA lag: after a model swap (e.g. loading the 120B on-demand), page-cache
eviction can cause elevated latency for the first few requests. Run `scripts/05-drop-caches.sh`
before loading the heavy model if memory pressure is high.

Check tokens/sec via vLLM `/metrics` endpoint and LiteLLM logs:

```bash
curl -s http://<spark-ip>:8001/metrics | grep -E "^vllm:avg_generation_throughput"
curl -s http://<spark-ip>:8002/metrics | grep -E "^vllm:avg_generation_throughput"
```

## Security scan

Grep logs for denied, blocked, or unexpected outbound connections:

```bash
grep -iE "denied|blocked|error" ~/.openclaw/logs/*.log | tail -50
```

Check for unexpected outbound connections from within the sandbox:

```bash
lsof -i -P -n | grep -v LISTEN | grep -v ESTABLISHED.*127.0.0
```

Any destination not in `config/openshell-policy.yaml` should be treated as a policy violation.

## Cost

Check the Anthropic spend dashboard against the daily ceiling. The CEO is the only agent that
calls `api.anthropic.com`; unexpectedly high spend indicates either a cost-intensive task or a
runaway loop. Compare current spend vs. the daily cap you set in the Anthropic console.

If spend is approaching the ceiling: review `logApiCalls` logs, check for recursive sub-agent
fan-out, and pause the CEO if needed (`openclaw gateway restart` or `nemoclaw <name> stop`).
