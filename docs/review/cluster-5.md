# Cluster 5 — Anthropic / Claude Opus 4.8

*Verified 2026-06-05. Claims sourced from `docs/master-plan.md` (§3 agent config). Method: two-stage adversarial verification (independent research → independent re-verification of every ✓/⚠), plus lead-level `gh api`/HF spot-checks on load-bearing claims.*

**Verdict legend:** ✓ confirmed at a primary source · ⚠ partially true / caveated / stale · ✗ contradicted by the source · ? could not verify

**Tally:** 8 findings — **6 ✓ · 2 ⚠ · 0 ✗ · 0 ?**

## Summary

All 8 findings independently re-verified by fetching the cited URLs (six Anthropic platform.claude.com / anthropic.com primary pages plus one CloudZero blog), with a raw-curl cross-check on the news post to rule out WebFetch hallucination. Every ✓ holds against a primary source: pricing 5/25, fast 10/50, batch 2.50/12.50 (50% off); cache 0.1x read, 1,024-token Opus-4.8 minimum, Feb-5-2026 workspace isolation; mid-conversation system cache preservation; the claude-opus-4-8 id and 'fewer derailments after compaction' line; and the 84% Online-Mind2Web browser score. The two ⚠ verdicts (effort level is 'xhigh' not 'extra'; the 50-agent cost line is CloudZero-only and confirmed absent from Anthropic's post) are accurate and stand. No claim was contradicted. Two notes-level corrections: the '2.5x' throughput in finding 1 actually lives on the fast-mode page (not the cited pricing page, though still first-party Anthropic), and finding 3's 'older models reject with a 400' note is an unsupported embellishment — the only documented 400 is for message misplacement, not for older models — so that note was corrected while the verdict stays ✓. No verdicts changed.

## Findings

| # | Verdict | Claim | Evidence (URL · date) |
|---|---|---|---|
| 5.1 | ✓ | Standard 5/25; fast 10/50 ~2.5x throughput; Batch 50% off. | [link](https://platform.claude.com/docs/en/about-claude/pricing) · 2026-06-05 |
| 5.2 | ✓ | Cache read 0.1x input; 1024-token cache minimum; workspace-isolated caches as of Feb 5 2026. | [link](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) · 2026-06-05 |
| 5.3 | ✓ | Mid-conversation role:"system" message preserves the prompt cache. | [link](https://platform.claude.com/docs/en/build-with-claude/mid-conversation-system-messages) · 2026-06-05 |
| 5.4 | ⚠ | Effort default 'high'; adaptive thinking is the only thinking mode; temperature/top_p/top_k return 400; the higher effort level is 'xhigh' (plan's 'extra' is wrong). | [link](https://platform.claude.com/docs/en/build-with-claude/effort) · 2026-06-05 |
| 5.5 | ✓ | Model API id is claude-opus-4-8; fewer derailments after compaction. | [link](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8) · 2026-06-05 |
| 5.6 | ✓ | 84% on Online-Mind2Web; strongest browser/computer-use Opus. | [link](https://www.anthropic.com/news/claude-opus-4-8) · 2026-06-05 |
| 5.7 | ⚠ | A 50-agent session costs $25/MTok output across 50 simultaneous token streams (Dynamic Workflows cost scaling). | [link](https://www.cloudzero.com/blog/claude-opus-4-8-pricing/) · 2026-06-05 |
| 5.8 | ✓ | anthropic.com/news has an Opus 4.8 announcement, 2026. | [link](https://www.anthropic.com/news/claude-opus-4-8) · 2026-06-05 |

## Finding detail

### 5.1 · ✓ — Standard 5/25; fast 10/50 ~2.5x throughput; Batch 50% off.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://platform.claude.com/docs/en/about-claude/pricing (2026-06-05)
- **Notes:** Re-verified by fetching the page. Opus 4.8 row: Base Input $5/MTok, Output $25/MTok. Fast mode table: Opus 4.8 $10 input / $50 output. Batch table: Opus 4.8 $2.50/$12.50 ('50% discount on both input and output tokens'). One sourcing nuance the report glosses: the '~2.5x' throughput number is NOT on the pricing page — it lives on the fast-mode page (https://platform.claude.com/docs/en/build-with-claude/fast-mode), which I also fetched: 'Fast mode delivers up to 2.5x higher output tokens per second from the same model' and 'Speed benefits are focused on output tokens per second (OTPS), not time to first token (TTFT).' All four numbers confirmed across the two Anthropic docs pages. Verdict stands.

### 5.2 · ✓ — Cache read 0.1x input; 1024-token cache minimum; workspace-isolated caches as of Feb 5 2026.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://platform.claude.com/docs/en/build-with-claude/prompt-caching (2026-06-05)
- **Notes:** Re-verified. Cache read 'Cache read (hit) 0.1x base input price' (pricing page table) and prompt-caching page 'A cache hit costs 10% of the standard input price.' Minimum: '1,024 tokens for Claude Opus 4.8, ...' — but note this 1,024 figure is SPECIFIC to Opus 4.8; the same page lists '4,096 tokens for Claude Opus 4.7, Claude Opus 4.6, and Claude Opus 4.5.' Since the plan targets Opus 4.8, 1,024 is correct. Workspace isolation: 'As of February 5, 2026, prompt caching uses workspace-level isolation instead of organization-level isolation.' All three verbatim-confirmed.

### 5.3 · ✓ — Mid-conversation role:"system" message preserves the prompt cache.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://platform.claude.com/docs/en/build-with-claude/mid-conversation-system-messages (2026-06-05)
- **Notes:** Core plan claim CONFIRMED. Mid-conversation page: appending a {"role":"system"} message 'keeps earlier turns byte-identical, so the prefix cached by the previous request is still read from cache.' whats-new-4-8 page: 'preserves prompt cache hits on the earlier turns.' CORRECTION to the original report's notes: it added 'older models reject with a 400' — that embellishment is NOT supported. The pages say the feature 'is available on Claude Opus 4.8 only,' and the ONLY documented 400 is for MISPLACEMENT ('Placing it elsewhere returns a 400 error'), not for older models rejecting the feature. The plan itself does not make the 400 claim, so the verdict on the plan claim stays ✓; the report's note was corrected.

### 5.4 · ⚠ — Effort default 'high'; adaptive thinking is the only thinking mode; temperature/top_p/top_k return 400; the higher effort level is 'xhigh' (plan's 'extra' is wrong).
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://platform.claude.com/docs/en/build-with-claude/effort (2026-06-05)
- **Notes:** Re-verified; report's ⚠ is accurate. Effort levels are exactly low/medium/high/xhigh/max — there is NO 'extra' level. Plan line 176 says 'reserve extra/max for hard tasks', which is wrong: the level is 'xhigh'. Default: 'The default is high on all surfaces, including the Claude API and Claude Code' (effort page) and whats-new page 'effort parameter default on Claude Opus 4.8 is high.' Adaptive-only + sampling 400 confirmed on whats-new page: 'Setting temperature, top_p, or top_k to a non-default value returns a 400 error' and 'does not support extended thinking budgets ... returns a 400 error.' Caveat is the only defect, so ⚠ stands.

### 5.5 · ✓ — Model API id is claude-opus-4-8; fewer derailments after compaction.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-8 (2026-06-05)
- **Notes:** Re-verified verbatim. Model table: 'Claude Opus 4.8 | claude-opus-4-8'. Compaction: 'Better compaction handling and long-context quality. Long agentic traces stay on task with fewer derailments after compaction.' Also independently confirmed 'claude-opus-4-8' appears in the news post raw HTML. Both verbatim.

### 5.6 · ✓ — 84% on Online-Mind2Web; strongest browser/computer-use Opus.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://www.anthropic.com/news/claude-opus-4-8 (2026-06-05)
- **Notes:** Re-verified via WebFetch AND independent raw-HTML grep (curl found '84%', 'Online-Mind2Web', 'strongest computer-use' all present, so not a WebFetch hallucination). News post: 'scoring 84% on Online-Mind2Web' and 'the strongest computer-use and browser-agent model we've tested.' Minor: source phrasing is 'strongest ... model we've tested' (broader than the plan's 'strongest Opus'), but consistent with the plan's intent. ✓ holds.

### 5.7 · ⚠ — A 50-agent session costs $25/MTok output across 50 simultaneous token streams (Dynamic Workflows cost scaling).
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://www.cloudzero.com/blog/claude-opus-4-8-pricing/ (2026-06-05)
- **Notes:** Re-verified; report's ⚠ is accurate and well-justified. CloudZero blog (published June 2, 2026, updated June 3) contains the near-verbatim line: 'A 50-agent session does not cost $25 per million output tokens. It costs $25 per million output tokens across 50 simultaneous token streams.' Adversarial cross-check: this 50-agent cost framing is CONFIRMED ABSENT from Anthropic's own news post (the post only says Dynamic Workflows 'run hundreds of parallel subagents in a single session' with no per-stream pricing). So the quote is genuinely third-party (CloudZero), not first-party Anthropic — exactly as the report flags. ⚠ stands.

### 5.8 · ✓ — anthropic.com/news has an Opus 4.8 announcement, 2026.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://www.anthropic.com/news/claude-opus-4-8 (2026-06-05)
- **Notes:** Re-verified. Page resolves (HTTP 200) and is the genuine Opus 4.8 announcement dated 'May 28, 2026' (confirmed in both WebFetch and raw-HTML grep). No formal policy change asserted in the plan, and none needed for this claim. ✓ holds.

## Method notes

Tools: Bash curl for HTTP-status and raw-HTML grep cross-checks; WebFetch for full-content semantic verification of all 6 cited Anthropic/CloudZero URLs plus 2 supporting Anthropic pages (fast-mode, mid-conversation-system-messages) that back claims the report attributed to other URLs. Read the local master-plan.md to recover the exact plan claims (lines 176, 179-180, 197). All 6 cited URLs returned HTTP 200; content fetched and matched against claims. Independently grepped the news post raw HTML to confirm '84%', 'Online-Mind2Web', 'strongest computer-use', 'May 28, 2026', 'claude-opus-4-8' are really present (defends against doc-site SPA-shell false positives). Nothing was behind a login or unreachable. verifier: 2 findings adjusted (notes-level corrections on findings 1 and 3; no verdict changes).
