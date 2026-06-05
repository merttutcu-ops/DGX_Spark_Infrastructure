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
