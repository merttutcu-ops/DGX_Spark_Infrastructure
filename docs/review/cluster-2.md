# Cluster 2 — NemoClaw + OpenShell

*Verified 2026-06-05. Claims sourced from `docs/master-plan.md` (§2 build sequence). Method: two-stage adversarial verification (independent research → independent re-verification of every ✓/⚠), plus lead-level `gh api`/HF spot-checks on load-bearing claims.*

**Verdict legend:** ✓ confirmed at a primary source · ⚠ partially true / caveated / stale · ✗ contradicted by the source · ? could not verify

**Tally:** 17 findings — **13 ✓ · 4 ⚠ · 0 ✗ · 0 ?**

## Summary

This cluster is solid and well-researched; the teammate underlying judgments hold up on independent re-verification. The NVIDIA/NemoClaw repo (20,978 stars) is real, and all 10 cited issues exist and are CLOSED with titles/bodies that match the claims. PR 4733 (detect stale or unrefreshed NVIDIA CDI specs) merged 2026-06-04 and IS contained in git tag v0.0.59 (compare API behind_by 0, ahead_by 30); one nuance: there is no GitHub Release OBJECT for v0.0.59 (releases list empty), only a git tag. Docs claims (balanced tier, nvapi key, .env credentials, 18789 Control UI port, 11435 token-gated Ollama proxy, DGX OS 7.5 / driver 580.159.03 / CUDA 13.0.2, OTA-off, 18W) all verify against live primary sources. The 5 PARTIALs are genuine over-generalizations rather than contradictions; the weakest is Computex Qwen35B, where the Qwen3.6-35B-A3B-NVFP4 model is real but Spark-scoped and the word Computex appears nowhere in the cited docs.

## Findings

| # | Verdict | Claim | Evidence (URL · date) |
|---|---|---|---|
| 2.1 | ✓ | Issue 4658 CUDA crash CLOSED, fixed by PR 4733 (stale-CDI preflight), in tag v0.0.59 | [link](https://github.com/NVIDIA/NemoClaw/issues/4658) · 2026-06-05 |
| 2.2 | ✓ | Issue 385 local Ollama inference routing fails from sandbox, CLOSED | [link](https://github.com/NVIDIA/NemoClaw/issues/385) · 2026-06-05 |
| 2.3 | ⚠ | Issue 391 = 403 proxy block for Telegram (node missing from policy binaries), CLOSED | [link](https://github.com/NVIDIA/NemoClaw/issues/391) · 2026-06-05 |
| 2.4 | ⚠ | Issues 314, 417, 1786, 3390 are all 403 proxy issues | [link](https://github.com/NVIDIA/NemoClaw/issues/417) · 2026-06-05 |
| 2.5 | ✓ | Issue 362 curl-bash stdin EOF onboarding break + port 8080 EADDRINUSE, CLOSED | [link](https://github.com/NVIDIA/NemoClaw/issues/362) · 2026-06-05 |
| 2.6 | ✓ | Issue 938 requests CLI command to retrieve gateway token (current jq workaround), CLOSED | [link](https://github.com/NVIDIA/NemoClaw/issues/938) · 2026-06-05 |
| 2.7 | ✓ | Issue 328 allowedOrigins resets to http://127.0.0.1:18789, CLOSED | [link](https://github.com/NVIDIA/NemoClaw/issues/328) · 2026-06-05 |
| 2.8 | ✓ | New issues opened in last 30 days; examples 3836 and 4304 | [link](https://github.com/NVIDIA/NemoClaw/issues/4304) · 2026-06-05 |
| 2.9 | ✓ | Onboard wizard applies balanced policy tier by default | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |
| 2.10 | ✓ | Install/onboard uses nvapi- prefixed NVIDIA_API_KEY | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |
| 2.11 | ✓ | Credentials via .env file / NVIDIA_API_KEY=nvapi-... command prefix | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |
| 2.12 | ⚠ | Web UI / Control UI default port 18789 (build.nvidia.com Brev launch path) | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |
| 2.13 | ⚠ | Computex announcement of Qwen 35B model | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |
| 2.14 | ✓ | DGX Spark release: DGX OS 7.5, driver 580, CUDA 13 | [link](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html) · 2026-06-05 |
| 2.15 | ✓ | OTA updates off by default; 18W power saving | [link](https://docs.nvidia.com/dgx/dgx-spark/release-notes.html) · 2026-06-05 |
| 2.16 | ✓ | OpenShell proxy denies non-allowlisted binaries (3128); node must be allowlisted; sha256 config hashing | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |
| 2.17 | ✓ | v0.0.55 release; Ollama on token-gated reverse proxy at port 11435 | [link](https://docs.nvidia.com/nemoclaw/llms-full.txt) · 2026-06-05 |

## Finding detail

### 2.1 · ✓ — Issue 4658 CUDA crash CLOSED, fixed by PR 4733 (stale-CDI preflight), in tag v0.0.59
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/4658 (2026-06-05)
- **Notes:** issue 4658 state=closed (2026-06-04), title cites PR 4619 vLLM/NVFP4 CUDA unknown error. PR 4733 merged 2026-06-04T17:45:58Z, title fix(onboard): detect stale or unrefreshed NVIDIA CDI specs in host preflight = stale-CDI. Correction: no GitHub Release for v0.0.59 (releases list empty), but git TAG v0.0.59 exists and compare merge-sha...v0.0.59 = ahead_by 30 behind_by 0, so the tag contains the PR4733 merge. Claim confirmed.

### 2.2 · ✓ — Issue 385 local Ollama inference routing fails from sandbox, CLOSED
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/385 (2026-06-05)
- **Notes:** state=closed (2026-03-26), title Local Ollama inference routing fails from sandbox. Matches ollama routing.

### 2.3 · ⚠ — Issue 391 = 403 proxy block for Telegram (node missing from policy binaries), CLOSED
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/391 (2026-06-05)
- **Notes:** state=closed, title NemoClaw + Telegram: multiple 403 proxy blocks due to missing node in policy binaries. CAVEAT: 403 is NOT Telegram-only, body says the NVIDIA inference policy also only listed openclaw/claude, so inference.local was also 403-blocked. Report PARTIAL Telegram-only correctly flagged.

### 2.4 · ⚠ — Issues 314, 417, 1786, 3390 are all 403 proxy issues
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/417 (2026-06-05)
- **Notes:** All four closed. 314 and 417 ARE 403 issues (417 body shows proxy 10.200.0.1:3128, 403 Forbidden). 1786 (cannot reach Ollama at host.openshell.internal or 172.18.0.1) and 3390 (inference.local unreachable after Ollama restart, DNS auto-repair) are NOT 403. Report PARTIAL 1786 3390 not403 accurate.

### 2.5 · ✓ — Issue 362 curl-bash stdin EOF onboarding break + port 8080 EADDRINUSE, CLOSED
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/362 (2026-06-05)
- **Notes:** state=closed, title curl | bash install breaks nemoclaw onboard at sandbox name prompt (stdin EOF). Body confirms Port 8080 is not available, Detail: port 8080 is in use (EADDRINUSE). Matches note EADDRINUSE.

### 2.6 · ✓ — Issue 938 requests CLI command to retrieve gateway token (current jq workaround), CLOSED
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/938 (2026-06-05)
- **Notes:** state=closed, title Add CLI command to retrieve gateway auth token. Body shows jq -r .gateway.auth.token workaround and asks to avoid needing jq. Matches token jq.

### 2.7 · ✓ — Issue 328 allowedOrigins resets to http://127.0.0.1:18789, CLOSED
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/328 (2026-06-05)
- **Notes:** state=closed. Body: config reload strips gateway.controlUi.allowedOrigins, resetting to http://127.0.0.1:18789. Matches allowedOrigins and 18789.

### 2.8 · ✓ — New issues opened in last 30 days; examples 3836 and 4304
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/NVIDIA/NemoClaw/issues/4304 (2026-06-05)
- **Notes:** 3836 created 2026-05-19 (open, ERR_PROXY_TUNNEL 403 proxy-test); 4304 created 2026-05-27 (open, v0.0.52 onboard ignores HTTP_PROXY). Both within window since ~2026-05-06. gh search returned 0 = index lag; used direct API dates.

### 2.9 · ✓ — Onboard wizard applies balanced policy tier by default
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** llms-full.txt HTTP 200, 1.23MB. Line 927 verbatim: Unless NEMOCLAW_POLICY_TIER is set, it applies sandbox policy in suggested mode with the balanced tier by default. Matches wizard Balanced.

### 2.10 · ✓ — Install/onboard uses nvapi- prefixed NVIDIA_API_KEY
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** Line 1293 The nvapi- prefix check applies only to NVIDIA_API_KEY; line 4162 Copy the key. It starts with nvapi-; export NVIDIA_API_KEY=nvapi-... shape. Matches install nvapi.

### 2.11 · ✓ — Credentials via .env file / NVIDIA_API_KEY=nvapi-... command prefix
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** Lines 3312/4041 show cd ~/nemoclaw && . .env && openshell term; lines 4967-5024 read process.env first and NVIDIA_API_KEY=nvapi-... nemoclaw onboard. Matches token env file.

### 2.12 · ⚠ — Web UI / Control UI default port 18789 (build.nvidia.com Brev launch path)
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** 18789 confirmed (lines 1057/1087 default host port is 18789, 2324 scans 18789-18799, 4055 allowlist). build = build.nvidia.com Brev Web UI; that page returns HTTP 200 but is JS-rendered Next.js so content unverifiable via fetch. Report PARTIAL build-unverif fair.

### 2.13 · ⚠ — Computex announcement of Qwen 35B model
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** Model nvidia/Qwen3.6-35B-A3B-NVFP4 confirmed (lines 346/366/436) but ONLY as managed-vLLM default on DGX Spark/Station, 128K context. Computex appears nowhere in this source (grep count 0) so that framing is unverified. Report PARTIAL Spark-only captures scoping; Computex is the weak part.

### 2.14 · ✓ — DGX Spark release: DGX OS 7.5, driver 580, CUDA 13
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/dgx/dgx-spark/release-notes.html (2026-06-05)
- **Notes:** Page HTTP 200 (last-modified 2026-06-01). WebFetch: NVIDIA DGX OS 7.5.0, NVIDIA GPU Driver 580.159.03, NVIDIA CUDA Toolkit 13.0.2. Matches 7.5 580 CUDA13. Note 570EOL-unstated confirmed: no 570 EOL statement.

### 2.15 · ✓ — OTA updates off by default; 18W power saving
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/dgx/dgx-spark/release-notes.html (2026-06-05)
- **Notes:** WebFetch quotes OTA updates are not installed by default during initial setup and ConnectX-7 network adapter, saving up to 18W of power when the adapter is not in use. Both confirmed; page resolves (site-opens).

### 2.16 · ✓ — OpenShell proxy denies non-allowlisted binaries (3128); node must be allowlisted; sha256 config hashing
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** Line 2204: the OpenClaw gateway runs as /usr/local/bin/node, so the NVIDIA endpoint policy must allow that binary; sha256 hashing at 2178/485. Literal 10.200.0.1:3128 403 is in issues 417/391 (not docs), matches method note. Underlying facts confirmed.

### 2.17 · ✓ — v0.0.55 release; Ollama on token-gated reverse proxy at port 11435
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/nemoclaw/llms-full.txt (2026-06-05)
- **Notes:** Line 384 v0.0.55 header. Line 1659: keeps Ollama bound to 127.0.0.1:11434 and starts a token-gated reverse proxy on 0.0.0.0:11435; line 1688 use proxy port 11435 with the generated token as its OPENAI_API_KEY. Matches Ollama 11435, note token-gated. Tag v0.0.55 present.

## Method notes

verifier: 17 findings adjusted. Re-verified every finding live. gh api per issue confirmed state/title/dates for 4658, 385, 391, 417, 314, 1786, 3390, 362, 938, 328 (all closed) and read bodies for specifics (403/3128 proxy, node binary, 8080 EADDRINUSE, jq token, allowedOrigins 18789). PR 4733 merge confirmed via gh api pulls; v0.0.59 containment confirmed via gh api compare merge-sha...tag (behind_by 0). Corrected the report: v0.0.59 is a git tag only, no GitHub Release object exists (releases endpoint returns empty array). new30d examples 3836/4304 confirmed by direct API dates (gh search returned 0 = index lag, not evidence). curl+grep on llms-full.txt (HTTP 200, 1.23MB) for balanced/nvapi/.env/18789/11435/v0.0.55/node/sha256; Computex grep count 0. WebFetch on DGX Spark release-notes.html (HTTP 200) for 7.5.0/580.159.03/CUDA 13.0.2/OTA-off/18W. build.nvidia.com/spark/nemoclaw returns 200 but is JS-rendered, content unverifiable via fetch. Re-encoded the report ASCII key (OK to check, PARTIAL to warn) into glyphs: 12 confirmed, 5 partial, 0 contradicted, no fabricated evidence found.
