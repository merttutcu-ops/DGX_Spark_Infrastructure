# Plan Review — DGX Spark Multi-Agent Infrastructure

*Synthesis of six independent cluster reviews of `docs/master-plan.md`. Verified 2026-06-05.*
*Method: 6 research teammates → independent adversarial re-verification of every ✓/⚠ → lead-level `gh api`/Hugging-Face spot-checks on load-bearing claims. 64 findings, all cited to a live source.*

---

## Bottom line

**The plan is substantially reliable — build on it, but patch the runbook first.** Its core is confirmed at primary sources: every vLLM sm_121 issue is real, the NemoClaw/OpenShell security mechanics are accurate, the Opus 4.8 pricing/caching/effort facts are verbatim-correct, all the model checkpoints exist, and the macro "buy now" thesis (MSRP hike + structural DRAM shortage) is solid.

The defects cluster into four buckets, **none of which changes the decision to build**:
1. **One materially wrong technical claim** — the NVFP4 crash is *not* "fixed by PR #35947" (the PR was never merged).
2. **Stale version/number specifics** in a fast-moving stack (CUDA 13.0/13.1 → now 13.2; eugr perf 35→57 vs the README's 40→60). The plan itself warns of this in its Caveats.
3. **Citation-hygiene gaps in the security-stats section** — the *facts* are mostly real, but several are attributed to the wrong source, and one statistic ("36% prompt injection") is a misread.
4. **Commerce is the weakest cluster** — the only ✗ and the only ? both live here; live CAD prices run above the plan's estimate, and 3 of 5 retailers are bot-walled.

### Scoreboard

| Cluster | Findings | ✓ | ⚠ | ✗ | ? | Health |
|---|---|---|---|---|---|---|
| 1 — vLLM on sm_121 | 16 | 9 | 7 | 0 | 0 | Strong; version drift + one non-merged-fix error |
| 2 — NemoClaw + OpenShell | 17 | 13 | 4 | 0 | 0 | **Strongest cluster**; mechanics all verbatim |
| 3 — Models & serving | 7 | 4 | 3 | 0 | 0 | Solid; checkpoints all real |
| 4 — OpenClaw & ClawHub security | 9 | 3 | 6 | 0 | 0 | Facts real, **citations sloppy** |
| 5 — Anthropic / Opus 4.8 | 8 | 6 | 2 | 0 | 0 | Strong; pricing/caching verbatim |
| 6 — Commerce (Canada) | 7 | 2 | 3 | 1 | 1 | **Weakest**; live prices above estimate |
| **Total** | **64** | **37** | **25** | **1** | **2** | Substantially reliable |

No claim was fabricated-and-confirmed: nothing came back ✓ on a made-up source. The "Claw" stack sounds fictional but is real — `openclaw/openclaw` (377k stars), `NVIDIA/NemoClaw` (21k stars), and `docs.openclaw.ai` all resolve.

---

## Corrections to apply before Week 1 (ranked by build impact)

### A. Technical — these affect whether serving works

1. **The NVFP4 "illegal-instruction" fix never landed (C1.5).** PR #35947 ("Software E2M1 conversion for SM12x NVFP4") is `merged: false, state: closed (2026-03-25)` — I re-confirmed this directly. SM12x/GB10 lacks the hardware `cvt.rn.satfinite.e2m1x2.f32` PTX instruction, and the upstream software workaround was *proposed and rejected*. **Action:** do not assume mainline vLLM serves NVFP4 cleanly on GB10. The working path is the **eugr build + Marlin backend** (the PR body itself notes "the Marlin backend already works on SM12x; the CUTLASS path was broken"). This makes the always-resident **Qwen3.6-35B-A3B-NVFP4** path build-dependent, and reinforces deferring Nemotron-3-Super.

2. **CUDA version has moved past the plan (C1.7, C1.12, C3.5).** The eugr prebuilt wheel is now **cu132 (CUDA 13.2)**, not 13.1; NVIDIA's current validated NGC tag is **`nvcr.io/nvidia/vllm:26.03-py3` (vLLM 0.17.1, CUDA 13.2)** — confirmed present on NGC (tags run through `26.05.post1-py3`). DGX OS itself ships CUDA 13.0.2 / driver 580.159.03. **Action:** pin the actual current cu132 wheel and a specific NGC image digest; delete the hardcoded 13.0/13.1 references.

3. **`#37854` resolved — and it's another reason the Nemotron NVFP4 path is blocked (C1.6).** The plan flagged this as unconfirmed; it's **open** and concrete: *"NGC vLLM 26.02 rejects Nemotron-3-Super-120B-A12B-NVFP4 — quant_algo MIXED_PRECISION not in whitelist."* `#31128` (the "native support" request) is **closed** (2025-12-23) — don't track it as live; `#36821` is the live umbrella issue.

4. **NemoClaw `v0.0.59` is a git tag, not a GitHub Release (C2.1).** The fix (PR #4733, stale-CDI host preflight) *is* in tag `v0.0.59` (I confirmed: merged 2026-06-04; `compare` shows behind_by 0). But the Releases list is empty. **Action:** pin by tag or commit SHA, not by "release vX.Y.Z."

5. **eugr perf/build numbers are off (C1.9, C1.10).** README says standard **~40 tok/s → MXFP4 60 tok/s** (plan: 35 → 56-57); build is **2-3 min (prebuilt) / 20-40 min (source)** (plan: ~15 min / ~1 hr); `--tf5` is documented for "models requiring Transformers 5.0" (GLM 4.6V, Qwen3.6 chat templates), **not** specifically "Mamba-hybrid." Directionally right, figures wrong — fix the runbook.

6. **Two factual nits (C1.13, C1.14):** "sm_121 binary-compatible with sm_120" is **overstated** — the shipped sm_120 kernels don't run on sm_121 and need a rebuild (that's the whole point of #36821). And "117B/21B total params" **conflates two models** — gpt-oss-120b is 117B total / 5.1B active; the 21B is the separate gpt-oss-20b. (The 273 GB/s, 16-channel 256-bit LPDDR5X-8533 hardware facts *are* verbatim-correct.)

### B. Config / operations

7. **Effort level is `xhigh`, not "extra" (C5.4).** Plan line 176 ("reserve extra/max for hard tasks") names a level that doesn't exist. The ladder is **low / medium / high / xhigh / max**, default **high**. (I can personally vouch — this very session is running `xhigh`.)

8. **Heartbeat interval is config, not a file (C4.4).** Set via `agents.defaults.heartbeat.every` (or per-agent `agents.list[].heartbeat.every`); default 30m, and **1h under Anthropic OAuth/token auth**. `HEARTBEAT.md` is a runtime checklist the agent reads, *not* the interval setting.

9. **Attribute the 50-agent cost line correctly (C5.7).** *"A 50-agent session … costs $25/M output tokens across 50 simultaneous streams"* is from **CloudZero**, not Anthropic. Anthropic's own post makes no per-stream pricing claim. Fine to use — just cite it right.

### C. Security stats — facts mostly real, sourcing sloppy (Cluster 4)

10. **Koi numbers are verbatim-correct; the Antiy 1,184 is real but mis-cited (C4.6).** Koi (Feb 1): 341/2,857 (11.9%), 335 from "ClawHavoc" delivering AMOS; Feb 16 → 824 (marketplace grew to 10,700) — all confirmed on the Koi post. The **Antiy 1,184** figure is real (corroborated by cyberpress / GBHackers / Antiy's own PDF) but is **not on the cited Koi URL** — add the right citation.

11. **"36% prompt injection" is a misread (C4.7).** Snyk's real figures: **13.4% (534 skills) have a *critical* issue**; **36.82% (1,467) have *any* security flaw** — the 36% is not "prompt injection." (A separate 91% figure is prompt-injection overlap *within* confirmed-malicious payloads.)

12. **VirusTotal claim is half-sourced (C4.8).** VirusTotal scanning + daily re-scans: confirmed. But **"1-week publisher age," "auto-hide after 3 reports," and "40+ vulns in v2026.2.12"** are **not** in the cited TheHackerNews article. v2026.2.12 (2026-02-13) does add SSRF-deny + mandatory browser-control auth, but there's no "40+" headline. Re-source or drop those three sub-claims.

13. **Tool attribution (C4.9):** the Silverfort #1-ranking PoC (**3,900 executions / 6 days / 50+ cities**) and **ClawNet** are verbatim on Silverfort. **Clawdex** is a real **Koi** tool — *not* on the Silverfort page. Attribute Clawdex→Koi, ClawNet→Silverfort.

14. **`openclaw#49950` is closed (C4.5).** The `allowedOrigins`-reset-on-reload bug was real but **fixed 2026-03-20** — treat it as a known-and-patched gotcha, not an open risk. (Still-open security issues worth tracking: `#89233` plaintext apiKey, `#87758` gateway injection hardening.)

### D. Commerce — verify live before ordering (Cluster 6)

15. **The Tom's "$3,266.53" quote is contradicted (C6.6, ✗).** The live review page says the GX10 *"sells for as little as $3,000 with a 1TB SSD."* The substance (GX10 is the cheaper GB10 box, 1TB) holds; the exact figure and "the only difference being a smaller 1TB SSD" wording do not.

16. **The 4TB SKU may be wrong (C6.2, ?).** The one reachable priced CA listing (Newegg.ca's 4TB unit) carries **-0000-000**, not the plan's **-0006-000**. No live CA listing for -0006-000 was found. Verify the SKU with the retailer before ordering.

17. **Live CAD prices run *above* the plan's estimate (C6.1, C6.4).** Only two public CAD prices were observable: **Newegg.ca DGX Spark CA$7,199** (In Stock) and **ASUS GX10 1TB CA$7,499** (In Stock) — both ~CA$400-900 over the plan's **CA$6,300-6,800**. That band is an MSRP-derived estimate (US$4,699 × ~1.36-1.40 FX ≈ CA$6,390-6,580, internally consistent) but it isn't matched to a real listing, and Newegg ships from the US with markup. **3 of 5 retailers (Canada Computers, Memory Express, Amazon.ca) are bot-walled** — their live prices are unverified. The macro thesis is sound (see below); just don't treat CA$6,300-6,800 as a quote.

---

## Confirmed strong — build on these with confidence

- **vLLM sm_121 reality (C1):** `#37030` (GPT-OSS Marlin wrong-token), `#37431` (Mamba-2 illegal instruction, Nemotron), `#36821` (sm_121 aarch64 umbrella), `#35519` (Qwen3.5 NVFP4 crash), `#37854` (NGC MIXED_PRECISION reject) — **all real and open**, bodies matching the plan. `eugr/spark-vllm-docker` is real (1,530 ★, active 2026-06-03) with **every flag confirmed**: `--solo`, `--apply-mod`, `gpu-mem-util-gb`, `--tf5`, `--exp-mxfp4`, `--mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head`.
- **NemoClaw + OpenShell mechanics (C2):** all 10 cited issues real & closed; the **403 / `10.200.0.1:3128` proxy**, the **binary-path (`/usr/local/bin/node`) + SHA256 allowlist**, the **8080 EADDRINUSE** `curl|bash` gotcha, the **`:11435` token-gated Ollama proxy**, the **Balanced** default tier, the **`nvapi-` key**, and the **`127.0.0.1:18789` exact-origin** check — all verbatim in official docs. DGX OS 7.5.0 / driver 580.159.03 / CUDA 13.0.2 / OTA-off-by-default / 18W ConnectX-7 saving — verbatim in the release notes.
- **Opus 4.8 (C5):** pricing **$5/$25**, fast **$10/$50** (~2.5× OTPS), batch **$2.50/$12.50**; cache **0.1× read**, **1,024-token** Opus-4.8 minimum, **workspace isolation since Feb 5 2026**; mid-conversation `role:"system"` preserves cache; model id **`claude-opus-4-8`**; adaptive-thinking-only + `temperature/top_p/top_k → 400`; **84% Online-Mind2Web**. Every figure verbatim, and consistent with this runtime.
- **Models (C3):** all checkpoints exist — `nvidia/Qwen3.6-35B-A3B-NVFP4` (genuinely a **Gated-DeltaNet/SSM + MoE hybrid** needing Transformers 5.x, confirmed from `config.json`), `openai/gpt-oss-120b` (60.8 GB, 117B/5.1B-active), `nvidia/Gemma-4-26B-A4B-NVFP4`. The NVIDIA **June-1-2026 blog** is real (2.6× faster Qwen3.6 via NVFP4+MTP; NVIDIA Sync multi-node). The **dredyson** llama-swap/LiteLLM stack is real (ports 14000/28080, `--network container:llama-swap`, UMA free-lag).
- **Macro / commerce (C6):** the **MSRP hike US$3,999 → US$4,699 (Feb 23 2026)** is verbatim on NVIDIA's forum (all four sub-claims: memory-supply cause, existing orders honored, no hardware changes). The **DRAM +58-63% QoQ for Q2 2026** and **no meaningful expansion until late-2027/2028** are verbatim on TrendForce (2026-03-31). The "buy now" thesis rests on solid ground.

## Still genuinely uncertain (?)

- The **4TB SKU mapping** (-0006-000 vs the live -0000-000) — C6.2.
- **Live prices at the 3 bot-walled retailers** (Canada Computers, Memory Express, Amazon.ca) — C6.1.
- An **in-window (May 6 – Jun 5) NVIDIA *forum* thread** — the category is live and full of sm_121 vLLM work, but the date-pinned threads I could verify are April; the in-window primary source is the vLLM blog — C1.16.
- The exact **Gemma "39-155 tok/s DFlash"** band — model exists, range loosely corroborated, not verbatim — C3.7.

---

## Source files

Full per-claim detail (claim · verdict · evidence URL + date · notes) lives in:
`docs/review/cluster-1.md` … `cluster-6.md`.
