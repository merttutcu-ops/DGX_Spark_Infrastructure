# Cluster 4 — OpenClaw & skill (ClawHub) security

*Verified 2026-06-05. Claims sourced from `docs/master-plan.md` (§3 agent config / §4 security). Method: two-stage adversarial verification (independent research → independent re-verification of every ✓/⚠), plus lead-level `gh api`/HF spot-checks on load-bearing claims.*

**Verdict legend:** ✓ confirmed at a primary source · ⚠ partially true / caveated / stale · ✗ contradicted by the source · ? could not verify

**Tally:** 9 findings — **3 ✓ · 6 ⚠ · 0 ✗ · 0 ?**

## Summary

The OpenClaw/ClawHub stack is real despite the fictional-sounding names: docs.openclaw.ai resolves (HTTP 200, Cloudflare R2), the GitHub repo openclaw/openclaw has 377,072 stars with active releases (latest v2026.6.2-beta.1), and issue 49950 is genuine. The docs-level findings (1-4) are solid and largely verbatim, with heartbeat correctly flagged as set via heartbeat.every not HEARTBEAT.md. The GitHub finding (5+6) is accurate but issue 49950 is CLOSED, and the named security issues are real with mixed open/closed states. The external-research findings are mostly accurate but two were over-marked: the Koi finding bundles an Antiy 1,184 figure that is real but NOT on the cited Koi URL, and the Silverfort finding bundles 'Clawdex' which is a real Koi tool but NOT on the cited Silverfort page. Both downgraded ✓→⚠ for citation/attribution gaps, not factual error. Additionally, the VirusTotal finding's '1-week age' and 'auto-hide after 3 reports' sub-claims are absent from the cited TheHackerNews article (contrary to the reviewer's note), and the '40+ vulns' framing for v2026.2.12 is unsupported by the actual GitHub release notes.

## Findings

| # | Verdict | Claim | Evidence (URL · date) |
|---|---|---|---|
| 4.1 | ✓ | Per-agent workspace+stateDir ~/.openclaw/agents/ID/ (auth,models,sessions); bindings map channel to agent; never reuse agentDir. | [link](https://docs.openclaw.ai/concepts/multi-agent) · 2026-06-05 |
| 4.2 | ✓ | Config: agents.list[].model + models.providers map. | [link](https://docs.openclaw.ai/gateway/config-agents) · 2026-06-05 |
| 4.3 | ✓ | security page: no perfectly secure setup; audit --deep/--fix/--json; Tailscale Serve over LAN; 127.0.0.1:18789. | [link](https://docs.openclaw.ai/gateway/security) · 2026-06-05 |
| 4.4 | ⚠ | Heartbeat default ~30m, configurable via HEARTBEAT.md. | [link](https://docs.openclaw.ai/gateway/heartbeat) · 2026-06-05 |
| 4.5 | ⚠ | [5+6] repo+releases; issue 49950 resets controlUi.allowedOrigins on reload; recent security issues. | [link](https://github.com/openclaw/openclaw/issues/49950) · 2026-06-05 |
| 4.6 | ⚠ | [7+8] Koi Feb1: 341/2857(11.9%),335 ClawHavoc/AMOS; Feb16 824; Antiy 1184. | [link](https://www.koi.ai/blog/clawhavoc-341-malicious-clawedbot-skills-found-by-the-bot-they-were-targeting) · 2026-06-05 |
| 4.7 | ⚠ | Snyk: 13.4% of ~4000 critical; 36% prompt injection. | [link](https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/) · 2026-06-05 |
| 4.8 | ⚠ | VirusTotal Feb7+daily; v2026.2.12 40+ vulns; 1-week age; auto-hide after 3 reports. | [link](https://thehackernews.com/2026/02/openclaw-integrates-virustotal-scanning.html) · 2026-06-05 |
| 4.9 | ⚠ | Silverfort skill to #1: 3900 execs/6d/50+ cities. Koi Clawdex; Silverfort ClawNet. | [link](https://www.silverfort.com/blog/clawhub-vulnerability-enables-attackers-to-manipulate-rankings-to-become-the-number-one-skill/) · 2026-06-05 |

## Finding detail

### 4.1 · ✓ — Per-agent workspace+stateDir ~/.openclaw/agents/ID/ (auth,models,sessions); bindings map channel to agent; never reuse agentDir.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.openclaw.ai/concepts/multi-agent (2026-06-05)
- **Notes:** Re-fetched live (HTTP 200). Confirms `~/.openclaw/agents/<agentId>/agent` (auth profiles + model registry) and `~/.openclaw/agents/<agentId>/sessions`. Verbatim warning present: "Never reuse `agentDir` across agents (it causes auth/session collisions)." Bindings described as channel-account-to-agent deterministic routing. All sub-claims supported.

### 4.2 · ✓ — Config: agents.list[].model + models.providers map.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.openclaw.ai/gateway/config-agents (2026-06-05)
- **Notes:** Re-fetched live. Both keys present: `agents.list[].model` (per-agent override; string=strict primary, object={primary} with optional fallbacks) and `models.providers` (provider map merged by onboarding flows). Confirmed.

### 4.3 · ✓ — security page: no perfectly secure setup; audit --deep/--fix/--json; Tailscale Serve over LAN; 127.0.0.1:18789.
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.openclaw.ai/gateway/security (2026-06-05)
- **Notes:** Re-fetched live. "There is no 'perfectly secure' setup." present. `openclaw security audit` with --deep, --fix, AND --json all confirmed (I explicitly re-verified --json in a second fetch; it appears in the 'Quick check' section). "Prefer Tailscale Serve over LAN binds for remote access." Default bind `127.0.0.1:18789`. All four verbatim.

### 4.4 · ⚠ — Heartbeat default ~30m, configurable via HEARTBEAT.md.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://docs.openclaw.ai/gateway/heartbeat (2026-06-05)
- **Notes:** Re-fetched live. Default interval = `30m` (or `1h` under Anthropic OAuth/token auth). Set via `agents.defaults.heartbeat.every` or per-agent `agents.list[].heartbeat.every` — NOT via HEARTBEAT.md. HEARTBEAT.md is an optional checklist the agent reads during runs, not the interval config. Reviewer's caveat is correct; keeping ⚠.

### 4.5 · ⚠ — [5+6] repo+releases; issue 49950 resets controlUi.allowedOrigins on reload; recent security issues.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://github.com/openclaw/openclaw/issues/49950 (2026-06-05)
- **Notes:** gh api confirms repo openclaw/openclaw exists (stars=377072). Issue 49950 is REAL, state=CLOSED (created 2026-03-18, closed 2026-03-20), title "Gateway resets controlUi.allowedOrigins on every config reload, blocking external dashboards" — matches claim but is closed, not open. Releases active (latest v2026.6.2-beta.1). Security issues plentiful and verified via gh api: 89233 OPEN (plaintext lmstudio apiKey placeholder), 87758 OPEN (web gateway injection hardening), 85240 CLOSED (P0 cross-user privacy leak), 87137 CLOSED (hook context boundary markers). ⚠ because the issue title says resets-blocks-dashboards (consistent) but it is CLOSED.

### 4.6 · ⚠ — [7+8] Koi Feb1: 341/2857(11.9%),335 ClawHavoc/AMOS; Feb16 824; Antiy 1184.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://www.koi.ai/blog/clawhavoc-341-malicious-clawedbot-skills-found-by-the-bot-they-were-targeting (2026-06-05)
- **Notes:** DOWNGRADED ✓→⚠. Koi URL re-fetched: confirms 341 of 2,857 (~11.9%), 335 single campaign named "ClawHavoc", AMOS = 521KB universal Mach-O matching Atomic macOS Stealer, and Feb 16 update to 824 (marketplace grew 2,857→10,700). BUT the Antiy 1,184 figure is NOT on this cited Koi URL. The 1,184 is real — corroborated by separate sources (cyberpress.org/clawhavoc-poisons-openclaws-clawhub-with-1184-malicious-skills/ [200], GBHackers, CybersecurityNews, and Antiy's own PDF filename) — but the bundled citation does not cover that sub-claim, so the finding as cited is only partially supported. Reviewer's "Antiy secondary" note flags this; verdict adjusted to reflect the citation gap.

### 4.7 · ⚠ — Snyk: 13.4% of ~4000 critical; 36% prompt injection.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/ (2026-06-05)
- **Notes:** Re-fetched live. "13.4% of all skills, or 534 in total ... contain at least one critical-level security issue" (≈534/3,984) — 13.4% confirmed. The 36% is misread in the plan: "36.82% (1,467 skills) have at least one security flaw" of ANY severity, NOT prompt injection. (Separate 91% figure applies to prompt-injection overlap within confirmed malicious payloads, not the general 36%.) Reviewer's caveat is accurate; keeping ⚠.

### 4.8 · ⚠ — VirusTotal Feb7+daily; v2026.2.12 40+ vulns; 1-week age; auto-hide after 3 reports.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://thehackernews.com/2026/02/openclaw-integrates-virustotal-scanning.html (2026-06-05)
- **Notes:** Re-fetched live. Confirms VirusTotal scanning of all published skills + daily re-scans, and a reporting option for signed-in users. HOWEVER this article does NOT state a 1-week age requirement, does NOT state auto-hide-after-3-reports, and does NOT mention v2026.2.12 or any '40+ vulnerabilities' figure — contrary to reviewer's note that age/auto-hide were 'ok' on this URL (they are absent here). Separately, gh api on release v2026.2.12 (published 2026-02-13) confirms it adds SSRF-deny policy for OpenResponses URL inputs + browser-control auth requirement + many security fixes, but NO '40+ vulns' headline. Net: VirusTotal+daily supported; '40+ vulns', '1-week age', 'auto-hide after 3' are NOT supported by the cited URL. ⚠ retained but note the age/auto-hide items also lack support in this source.

### 4.9 · ⚠ — Silverfort skill to #1: 3900 execs/6d/50+ cities. Koi Clawdex; Silverfort ClawNet.
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://www.silverfort.com/blog/clawhub-vulnerability-enables-attackers-to-manipulate-rankings-to-become-the-number-one-skill/ (2026-06-05)
- **Notes:** DOWNGRADED ✓→⚠. Silverfort URL re-fetched: confirms a planted skill pushed to top of category search results, "About 3,900 skill executions within 6 days over 50 different cities ... including several public companies", and ClawNet as Silverfort's OpenClaw security plugin — all verbatim. BUT "Clawdex" is NOT on the Silverfort page; reviewer's "ClawNet+Clawdex ok" misattributes both to this URL. Clawdex IS real and IS a Koi tool — verified separately at clawdex.koi.security/ [200] and clawhub.ai/wearekoi/clawdex. So the tool-attribution sub-claim (Koi=Clawdex) is true but unsupported by this citation; ⚠ for the citation/attribution gap.

## Method notes

GitHub claims verified with authenticated gh api (repo existence/stars, issues 49950/89233/87758/85240/87137 with real state+title, releases list, and full v2026.2.12 release body). Docs verified via WebFetch against live docs.openclaw.ai pages (multi-agent, config-agents, security incl. a second targeted --json fetch, heartbeat). Security blogs verified via WebFetch (Koi ClawHavoc, Snyk ToxicSkills, TheHackerNews VirusTotal, Silverfort ranking). Cross-checks via WebSearch surfaced independent corroboration for Antiy 1,184 (CyberPress/GBHackers/CybersecurityNews + Antiy PDF) and for Koi's Clawdex tool; both confirmed-resolving via curl -sI (200). Antiy PDF itself could not be text-extracted (Chinese-language binary PDF) but its URL/filename and multiple secondary outlets corroborate 1,184. verifier: 2 findings adjusted (7+8 ✓→⚠, 9 ✓→⚠); 7 others re-verified and retained.
