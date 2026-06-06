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
**Promotion note (E25):** the OpenClaw workspace-injection bug (~26k chars of system context **every turn** →
23–60s latency on trivial prompts) makes lean context **usability-critical**, not just cost-critical. **Day-1 floor:**
set `bootstrapMaxChars` / `contextWindow` *before sealing* the sandbox (Landlock then makes `/sandbox/.openclaw`
read-only). **Ongoing guard:** the P2 prefill-budget linter. Promote P2 earlier accordingly.

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
