# Opus 4.8 CEO cost model (verified)

> **Provenance:** operator browsing-session research, **verified against the live `platform.claude.com`
> docs on 2026-06-06**. Local serving (heavy/resident) is free after hardware; this model covers ONLY
> the Anthropic API spend for the **CEO** (`claude-opus-4-8`).
>
> **Assumption flags:** the per-turn **suffix size**, **output size**, and **turn-count** parameters
> below are estimates — replace them with **measured** values once **P8** telemetry exists (vLLM/LiteLLM
> + Anthropic usage). Treat the dollar figures as a planning envelope, not a forecast.

## Verified rates (per MTok, Opus 4.8, 2026-06-06)

| Lever | Rate |
|---|---|
| Input (fresh) | **$5** |
| Output | **$25** |
| Cache **write**, 5-min TTL | **$6.25** (1.25× input) |
| Cache **write**, 1-hour TTL | **$10** (2× input) |
| Cache **read** (hit) | **$0.50** (0.1× input) |
| Cache minimum (Opus 4.8) | **1,024 tokens** |
| Cache-hit TTL refresh | **free** — a hit resets the window at no cost |
| Batch API | **50% off**, and **stacks with caching** |
| Fast mode | **$10 / $50** (2× in / out) |

## Per-turn cost

```
turn = prefix( READ @ $0.50/MTok if cache hit | WRITE @ $6.25/MTok (5-min) if miss )
     + fresh suffix input @ $5/MTok
     + output @ $25/MTok
```

A warm interactive burst (system + tools + stable workspace prefix already cached) reads the prefix at
$0.50/MTok and pays full rate only on the fresh suffix + output. A cold turn writes the prefix at
$6.25/MTok instead of reading it.

## Day / month model (CEO-only)

Workload assumption: **6 × 10-turn interactive bursts/day + 16 overnight heartbeats**.

- **Interactive bursts:** warm prefix reads dominate; the fresh suffix + output per turn drive cost.
- **Heartbeats:** uncached by nature — at 30–60 min cadence the 5-min cache window is always cold (see
  CLAUDE.md cost pin a), so each pays plain input + output.
  *(Correction: the source's bloated-heartbeat line had an arithmetic slip; corrected to ~**$0.158/turn**
  → ~**$176/mo** upper bound.)*
- **Envelope: ~$100–175/mo** CEO-only (upper bound ~$176/mo under bloated heartbeats).

## Recommended limits

| Control | Value |
|---|---|
| **Hard cap** (Anthropic workspace monthly) | **$250 / mo** |
| **Daily alert** | **$10 / day** |
| **Hourly alert** | **$5 / hr** |

These pair with the OpenClaw-side fail-stops (3 consecutive failures / 10-min runtime) and the **P1**
nightly digest, which reports spend against the $10/day and $250/mo lines. The primary runaway-fan-out
signal is **endpoint-based** (sub-agent sessions reaching `api.anthropic.com`; see **P13**), with these
dollar thresholds as the secondary signal.
