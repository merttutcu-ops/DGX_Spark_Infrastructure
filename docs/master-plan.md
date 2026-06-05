# DGX Spark Multi-Agent AI Infrastructure: Build & Operating Plan (June 2026)

*Single master document for building and operating the decided GB10 home-server agent stack. Current as of June 5, 2026. Prioritizes 2026 sources; older sources flagged inline.* *Amended 2026-06-05 with Part 1 verification corrections — see `docs/plan-review.md` and `docs/review/`.*

## TL;DR
- **Build it, but stage it.** A DGX Spark Founders Edition (GB10, 128GB) runs your decided stack — GPT-OSS-120B MXFP4 (~61GB weights, on-demand) + Qwen3.6-35B-A3B NVFP4 (~17-23GB, always-resident) via vLLM/SGLang, orchestrated by OpenClaw with Claude Opus 4.8 (`claude-opus-4-8`) as CEO — but the software ecosystem is alpha/unstable as of June 2026, so roll out 3-4 agents first, validate, then expand to 8, and add Hermes only in Phase 2/3.
- **The hardware/serving layer works; the agent-security layer is the real risk.** sm_121 vLLM is now serviceable (eugr build, ~60 tok/s on GPT-OSS-120B with the CUTLASS MXFP4 path per the eugr README; ~40 tok/s on the standard path), but the OpenShell-sandbox-to-inference 403 proxy bug, the ClawHub malicious-skills epidemic (1,184+ catalogued bad skills), and unsolvable prompt injection mean security hardening is non-negotiable before any agent touches a channel.
- **Budget ≈CA$7,200 street for the Spark today** (verified 2026-06-05: Canada Computers CA$7,199.99, Newegg.ca CA$7,199) (MSRP rose to US$4,699 in Feb 2026 due to a structural DRAM shortage forecast to run past 2027), keep Opus 4.8 spend behind hard caps (effort=high default, fail-stop on 3 failures / 10-min runtime), and never connect banking, primary email, or password stores.

## Key Findings

1. **DGX Spark is decode-bandwidth-limited but ideal for low-active-parameter MoE.** Per NVIDIA's DGX Spark User Guide hardware spec, the GB10 has "Memory Bandwidth: 273 GB/s · 16 channels (256 bit) LPDDR5X 8533"; Tom's Hardware frames the constraint plainly: "the DGX Spark's 128GB of LPDDR5X offers just 273 GB/s of raw memory bandwidth to the entire SoC." Dense models are starved (~9-11 tok/s on a 32B dense), but GPT-OSS-120B runs far faster because, per OpenAI's official release, "gpt-oss-120b activates 5.1B parameters per token ... The models have 117b and 21b total parameters respectively" — hitting ~50-60 tok/s on optimized engines. Your model choices are correct for this box.
2. **vLLM on sm_121 is usable but not turnkey.** It requires Spark-specific builds; the official NVIDIA vLLM path and community builds (eugr/spark-vllm-docker) both work, while NVFP4 hybrid-Mamba models (Nemotron-3-Super) still crash — confirming your decision to defer Nemotron.
3. **NemoClaw + OpenShell add real security but introduce a documented inference 403 proxy bug.** The deny-by-default CONNECT proxy at 10.200.0.1:3128 blocks sandbox→host inference unless policy binaries/endpoints are exactly right. Serve models to the sandbox via an explicit OpenShell network policy, not the default localhost path.
4. **ClawHub is actively hostile.** As of Feb-March 2026, researchers found 341 → 1,184+ malicious skills. Treat skill installation as the single highest-risk action and vet every skill.
5. **Claude Opus 4.8 is the right CEO model** with effort control, cache-preserving mid-conversation system messages, and a 1,024-token cache minimum — all directly useful for a cost-controlled orchestrator.

## Details

### 1. Pre-Purchase & Day-0 Checklist

**Canadian availability & pricing.** The DGX Spark Founders Edition (SKU 940-54242-0000-000 / the 4TB-variant SKU is uncertain — the live Newegg.ca 4TB unit carries -0000-000, not the previously-cited 940-54242-0006-000, so verify with the retailer) is stocked in Canada at Canada Computers, Memory Express, CDW.ca, Newegg.ca, and Amazon.ca. NVIDIA raised the Founders Edition MSRP from US$3,999 to US$4,699 on Feb 23, 2026; per NVIDIA's developer-forum statement (reported by Tom's Hardware): "We have adjusted the MSRP of DGX Spark (Founders Edition) due to worldwide constraints in memory supply." NVIDIA added that existing orders "will be honored at the pricing at the time of ordering" and "No hardware changes have been made." In Canada the verified street price is ≈CA$7,200 before tax (2026-06-05: Canada Computers lists part 940-54242-0000-000 at CA$7,199.99 — sold out online, 1 unit at London Masonville ON, Flexiti $600×12 financing; Newegg.ca CA$7,199 In Stock). That sits ~CA$400-900 above an MSRP+FX estimate (US$4,699 × ~1.36-1.40 ≈ CA$6,390-6,580), the gap being retailer markup.

**ASUS GX10 fallback.** The ASUS Ascent GX10 is the same GB10 platform, DGX OS, agentic-AI-ready (supports OpenClaw/NemoClaw). Per Tom's Hardware: "the Asus Ascent GX10 is a solid alternative to the DGX Spark as it is cheaper, selling "for as little as $3,000 with a 1TB SSD" (the earlier "$3,266.53 / only difference being a smaller 1TB SSD" wording was NOT supported by the live page; corrected 2026-06-05), and you can drop your own 4TB M.2 2230 SSD in and keep ~$700 versus the Founders Edition." It's a valid fallback but you lose NVMe headroom for a multi-model library (your library will likely exceed 600GB), so prefer a 2TB+ GX10 variant if you go this route.

**On arrival, verify:**
- **DGX OS version** — confirm the June 2026 release (DGX OS 7.5.x line; built on the Ubuntu 6.14 HWE kernel). Check via DGX Dashboard.
- **June 2026 release-note highlights:** OOBE enhancements; **OTA updates are NOT installed by default during initial setup** (changed behavior — you start using the system sooner, then pull OTA updates afterward); the NemoClaw playbook auto-opens after first boot; improved unified-memory reporting in DGX Dashboard; release highlights now shown so you can judge update urgency.
- **Firmware/OTA strategy:** Because OTA is deferred, run a deliberate first-boot → update cycle: complete OOBE, confirm network, then pull OTA updates manually before installing anything. Driver should be on the **580 branch** (570 is EOL). These versions apply to Founders Edition; partner GB10 systems may lag.

**Home-network prerequisites (Canada, 24/7):**
- **Static IP / DHCP reservation** for the Spark so SSH/Tailscale targets are stable.
- **Tailscale mesh** across Mac + phone + Spark. Per OpenClaw's own guidance, **prefer Tailscale Serve over LAN binds** — it keeps the gateway on loopback (127.0.0.1) while Tailscale handles access. Do NOT bind the gateway to 0.0.0.0.
- **SSH hardening:** key-only auth, disable password login, firewall (ufw) allowing only required ports. If you ever bind LAN, firewall to a tight source-IP allowlist; never broadly port-forward 18789.
- **Wi-Fi vs Ethernet:** Use wired 10GbE for the always-on server; the ConnectX-7 200GbE ports are for Spark-to-Spark interconnect only.

**Power/UPS/thermal:** The Spark is highly efficient — independent testing (ProX PC) had it completing LLM benchmarks "drawing under 100W," and the June OS added ConnectX-7 hot-plug power savings (~18W when the adapter is unused). A small consumer UPS (600-1000VA) comfortably covers the Spark plus router for clean shutdown during outages. Place it with clear airflow; the 1.1-liter chassis runs near-silent but must not be boxed in. It cannot run Windows — DGX OS (ARM Ubuntu) only.

### 2. Exact Build Sequence (Week 1)

**Step 1 — OOBE.** Boot, select keyboard layout, accept terms, create username/password, configure analytics (skippable), join Wi-Fi or (preferred) plug in Ethernet (the Wi-Fi step auto-skips when wired). Do not reboot during the final setup write. The DGX Spark playbook site opens with the NemoClaw playbook prominently displayed.

**Step 2 — System update.** Since OTA is deferred by default, manually pull OTA/OS updates now. Confirm driver 580 branch, CUDA 13.0.x (`nvcc --version`).

**Step 3 — NemoClaw one-command install.** Run:
```
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash
```
The script installs Node.js (if absent), OpenShell, and the NemoClaw CLI, then runs `nemoclaw onboard`. **Critical gotcha (issue #362):** piping `curl | bash` makes the wizard's stdin the pipe, so the sandbox-name prompt can read EOF and silently skip, leaving a half-initialized gateway on port 8080 (later fails with EADDRINUSE). For unattended installs use the non-interactive form:
```
curl -fsSL https://www.nvidia.com/nemoclaw.sh | bash -s -- --non-interactive
```
You need an `nvapi-` key from build.nvidia.com (free 30-day tier) for `nemoclaw setup-spark`/`onboard`.

**Step 4 — What the wizard configures (in order, per official Quickstart):** preflight checks → starts/reuses the OpenShell gateway → asks inference provider + model → collects credentials → asks sandbox name (lowercase/numbers/hyphens, default `my-assistant`) → prints a review summary → registers inference with OpenShell → prompts for optional Brave web search + messaging channels (Telegram/Discord/Slack/WhatsApp/WeChat) → builds and starts the sandbox → sets up OpenClaw → applies the network-policy tier (default "Balanced" includes npm, PyPI, Hugging Face, Homebrew, Brave presets). As of Computex 2026, the streamlined installer defaults the model to **Qwen3.6-35B**.

**Step 5 — Gateway token handling.** The entrypoint reads the gateway auth token from OpenClaw config, exports it as `OPENCLAW_GATEWAY_TOKEN`, and writes it to `/tmp/nemoclaw-proxy-env.sh` for interactive sandbox sessions. The OpenClaw config lives at `/sandbox/.openclaw/openclaw.json` (token at `.gateway.auth.token`). The install transcript does NOT print the token. Get the tokenized dashboard URL with `nemoclaw <name> dashboard-url --quiet`, or via SSH: `ssh openshell-nemoclaw "openclaw dashboard --no-open"` prints `http://127.0.0.1:18789/#token=<token>`. Inside the sandbox the token is redacted; to retrieve it (issue #938 workaround): `openshell sandbox download <name> /sandbox/.openclaw/openclaw.json ./ && jq -r '.gateway.auth.token' openclaw.json`.

**Step 6 — WebUI access (origin-check gotcha).** The dashboard is at **127.0.0.1:18789** (onboard auto-scans 18789-18799 if taken; gateway uses 8080). **You must use `127.0.0.1`, not `localhost` — the gateway origin check requires an exact match** (localhost ≠ 127.0.0.1; build.nvidia.com states this verbatim). Worse, the gateway normalizes `gateway.controlUi.allowedOrigins` on every config reload, resetting it to `["http://127.0.0.1:18789"]` and wiping custom origins (NemoClaw #328 and OpenClaw #49950 — both **closed/fixed** by 2026-03-20, so confirm your version still exhibits this before working around it) — so any `openclaw models set` etc. can break a custom origin. For Mac access, use an SSH tunnel:
```
ssh -N -L 18789:127.0.0.1:18789 <user>@<DGX_LAN_IP>
```
then open `http://127.0.0.1:18789/`. Alternatives: `openshell forward start -d 18789 my-assistant`; `--control-ui-port <N>`; set `CHAT_UI_URL` with the desired port; or `NEMOCLAW_DASHBOARD_BIND=0.0.0.0` (set before onboard — when remote bind is opted in, the dashboard auth flow accepts non-loopback origins; only `0.0.0.0` works, other values ignored).

**Step 7 — Replace the default Ollama path with vLLM/SGLang (the 403 proxy bug).** The default local-inference path routes the sandbox to Ollama via `inference.local`, but the OpenShell CONNECT proxy at 10.200.0.1:3128 returns **HTTP 403 Forbidden** for sandbox→host inference traffic (NemoClaw issues #314, #385, #417, #1786, #3390). Root cause: OpenShell allowlists outbound traffic **by binary path** (via `/proc/<pid>/exe` + SHA256, re-checked on change), and the default policy was missing `/usr/local/bin/node` (OpenClaw runs as node), plus the proxy blocks plain-HTTP POST to internal hosts (GET returns 200, POST returns 403). **Resolution path:** Serve your vLLM/SGLang endpoint and expose it to the sandbox through a custom OpenShell network policy (`nemoclaw <sandbox> policy-add --from-file`) with the host IP+port and the correct `binaries` entries — do NOT rely on the default localhost route. Newer NemoClaw (v0.0.55+) improved local-inference reliability and now keeps Ollama bound to 127.0.0.1:11434 with a token-gated reverse proxy on 0.0.0.0:11435.

**Step 8 — vLLM serving configs for GB10/sm_121.**

*The sm_121 reality (verify before trusting any single recipe):* sm_121 is closely related to sm_120 but **not** drop-in — the shipped sm_120 kernels do not run on sm_121 and require a rebuild — so you need a Spark-specific build (vLLM issue #36821; #31128 was closed 2025-12-23 and is not a live tracker). Stock PyPI vLLM also ships CPU-only torch on aarch64 with kernels only through sm_120. Two known-good paths as of June 2026:

- **Community build (your decided path): eugr/spark-vllm-docker.** Uses pre-built vLLM + FlashInfer wheels compiled for GB10 (CUDA 13.2 — the current prebuilt wheel is tagged cu132 as of 2026-06-03; the earlier "13.1" is stale — SM12.1a, ARM64). The launch script (`launch-cluster.sh --solo`) supports `--apply-mod` patches and a `gpu-mem-util-gb` mod for absolute memory caps. Build with `bash build-and-copy.sh` (~2-3 min with prebuilt wheels; 20-40 min for a source rebuild — not "~15 min"); `--tf5` installs Transformers 5.x for models that need it (e.g. GLM 4.6V, Qwen3.6 chat-template recipes — the README does not tie `--tf5` specifically to "Mamba-hybrid"); the experimental MXFP4 build (`--exp-mxfp4`) is what pushes GPT-OSS-120B from ~40 to ~60 tok/s (eugr README figures; the earlier "35→56-57" and "~1 hr / compiles a CUTLASS fork" specifics are not in the README) via `--mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head`.
- **Official NVIDIA path:** `vllm/vllm-openai:cu130-nightly` (or `nvcr.io/nvidia/vllm:25.12.post1` / `26.03-py3` — 26.03 is vLLM 0.17.1 / CUDA 13.2, confirmed live on NGC, with newer tags through `26.05.post1-py3`). vLLM's own June 2026 blog warns to treat `cu130-nightly` as "a compatibility track rather than a reproducible pin" — pin a specific image digest in your runbook.

**GPT-OSS-120B MXFP4 — key flags** (on-demand heavy tier; ~61GB native MXFP4 weights — Artificial Analysis: "gpt-oss-120b comes in at just 60.8GB"; fits in ~115-120GB unified with KV cache):
```
vllm serve openai/gpt-oss-120b \
  --tensor-parallel-size 1 \
  --max-num-seqs 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.85 \
  --enable-prefix-caching \
  --enable-chunked-prefill \
  --reasoning-parser gpt-oss --tool-call-parser gpt-oss
```
TP **must** be 1 (single chip; TP=4 fails to launch). Known bug **#37030**: on sm_121 the Marlin MXFP4 fallback can emit a wrong first Harmony token producing null content/reasoning — use the FlashInfer/CUTLASS MXFP4 path (eugr build) rather than the Marlin fallback to avoid this.

**Qwen3.6-35B-A3B NVFP4 — always-resident routine tier** (~17-23GB):
```
vllm serve nvidia/Qwen3.6-35B-A3B-NVFP4 \
  --tensor-parallel-size 1 \
  --max-num-seqs 4 \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.45 \
  --kv-cache-dtype fp8 \
  --enable-prefix-caching \
  --trust-remote-code
```
Qwen3.6/3.5 use a newer Mamba/hybrid (Gated-DeltaNet/SSM + MoE) architecture needing the Transformers-5.x build (`build-and-copy.sh --tf5`). **NVFP4 caveat:** upstream vLLM still lacks a merged SM12x NVFP4 software-E2M1 fix (PR #35947 was closed **unmerged** on 2026-03-25), so serve this NVFP4 model via the eugr build's **Marlin** backend (which works on SM12x), not stock upstream vLLM. Keep `--max-num-seqs` low (vLLM's Spark guidance: "should stay low because DGX Spark is better suited to small-batch inference"), and `--gpu-memory-utilization` must "leave headroom in the unified memory pool for the operating system, container runtime, and KV cache growth." Gemma 4 26B-A4B NVFP4 is a viable alternative small model (community images report 39-155 tok/s with DFlash).

**Page-cache flush ritual.** Because of unified memory (UMA), you can hit OOM even within capacity. NVIDIA's own vLLM troubleshooting page directs you to manually flush the buffer cache:
```
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
```
Run this between model swaps and before loading the 120B.

**MTP/speculative decoding.** Speculative decoding (e.g., DFlash) appears in some community NVFP4 images and can roughly double single-stream throughput, but it's model/image-specific; the eugr maintainer warns NVFP4 models "are not fully supported on vLLM (any build) yet" and are "known to crash sometimes." Treat as experimental; don't depend on it for routine agents.

**Model downloads:** NVFP4 checkpoints from NGC and Hugging Face (NVIDIA org for Qwen3.6 NVFP4); GPT-OSS-120B MXFP4 from `openai/gpt-oss-120b`. Pre-stage weights to NVMe.

**Model switching (on-demand 120B).** Use **llama-swap** as the VRAM orchestrator behind a LiteLLM gateway: client → LiteLLM (:14000) → llama-swap (:28080) → ephemeral vLLM containers, evicted after idle timeout. Two critical gotchas (Dre Dyson's GB10 series): (1) every model container's `docker run` must include `--network container:llama-swap` or llama-swap can't see it (binds in the wrong network namespace); (2) on UMA, CUDA doesn't immediately return freed memory after a container exits (lag of 30s-several minutes), so a hardcoded `--gpu-memory-utilization` can fail right after a swap — use the `gpu-mem-util-gb` absolute-cap mod and stagger swaps after the drop_caches flush. NemoClaw can also manage model-switching natively; llama-swap is the more flexible choice for a 10+ model library.

**Latest known-good status (June 2026):**
- **vLLM sm_121:** #36821 (no sm_121 on aarch64) is the live umbrella issue (#31128, the native-support request, was closed 2025-12-23 and is not a live tracker); **#37030** (GPT-OSS Marlin wrong-token) open; **#37431** (Mamba-2 Triton "illegal instruction" — needs `CUDA_LAUNCH_BLOCKING=1`; affects Nemotron-3-Super) open; **#35519** (Qwen3.5 NVFP4 illegal instruction) is **open** — the proposed software-E2M1 fix **PR #35947 was closed without merging (2026-03-25)**, so upstream still lacks the SM12x NVFP4 workaround (use the eugr/Marlin path); Mamba ops remain broken. **This is exactly why you defer Nemotron-3-Super.** (Note: issues #37854 and #37431 were specifically called out in your brief — #37431 is the open Mamba-2 crash above; **#37854 is now resolved** — it is a live **open** bug, "NGC vLLM 26.02 rejects Nemotron-3-Super-120B-A12B-NVFP4 — quant_algo MIXED_PRECISION not in whitelist", another reason the Nemotron NVFP4 path is blocked today.)
- **NemoClaw:** **#4658** (vLLM/NVFP4 container "CUDA unknown error" on GB10, caused by the image's `NVIDIA_REQUIRE_CUDA` capping at driver <576 while Spark ships 580, and `TORCH_CUDA_ARCH_LIST` lacking explicit sm_121) is **CLOSED, fixed by PR #4733 (merged 2026-06-04), contained in git tag v0.0.59** (note: v0.0.59 is a git **tag**, not a GitHub Release object — pin by tag/commit SHA, not "release"); **#385** (local Ollama routing) addressed in later releases.
- **SGLang on GB10:** `lmsysorg/sglang:spark` / `v0.5.10.post1-cu130` works; ~50 tok/s on GPT-OSS-120B, ~70 on 20B (LMSYS); the harmless "sm_121 > max 12.0" PyTorch warning is expected. SGLang tool-calling was reported unstable for GPT-OSS-120B; vLLM is the better choice when coding agents need reliable tool/function calling.

**Engine recommendation:** Start with the **eugr vLLM MXFP4 build** for GPT-OSS-120B (best tool-calling reliability + ~60 tok/s per the eugr README) and vLLM NVFP4 for Qwen3.6-35B-A3B resident (served via the eugr/Marlin path — see the NVFP4 caveat above). Keep SGLang as a benchmark comparison, not your primary.

### 3. Agent Team Configuration

**OpenClaw multi-agent model.** Each agent is a fully-scoped "brain": its own workspace, state dir (`~/.openclaw/agents/<agentId>/`), auth profiles, model registry, and session store. Bindings map a channel account to an agent. **Never reuse `agentDir` across agents** (causes auth/session collisions).

**Per-agent model assignment** via `agents.list[].model`:
```json
{
  "models": {
    "providers": {
      "vllm": { "baseUrl": "http://<spark-ip>:8000/v1", "apiKey": "dummy", "api": "openai-completions",
        "models": [ {"id": "vllm/Qwen3.6-35B-A3B-NVFP4", "contextWindow": 32768},
                    {"id": "vllm/gpt-oss-120b", "contextWindow": 32768} ] }
    }
  },
  "agents": {
    "list": [
      { "id": "ceo",       "name": "CEO",               "model": "anthropic/claude-opus-4-8",   "workspace": "~/.openclaw/ws-ceo" },
      { "id": "pa",        "name": "PersonalAssistant", "model": "vllm/Qwen3.6-35B-A3B-NVFP4",   "workspace": "~/.openclaw/ws-pa" },
      { "id": "pm",        "name": "ProductManager",    "model": "vllm/Qwen3.6-35B-A3B-NVFP4",   "workspace": "~/.openclaw/ws-pm" },
      { "id": "architect", "name": "Architect",         "model": "vllm/gpt-oss-120b",            "workspace": "~/.openclaw/ws-arch" },
      { "id": "coder",     "name": "Coder",             "model": "vllm/gpt-oss-120b",            "workspace": "~/.openclaw/ws-coder" },
      { "id": "qa",        "name": "QA",                "model": "vllm/gpt-oss-120b",            "workspace": "~/.openclaw/ws-qa" },
      { "id": "security",  "name": "SecurityAuditor",   "model": "vllm/gpt-oss-120b",            "workspace": "~/.openclaw/ws-sec" },
      { "id": "devops",    "name": "DevOps",            "model": "vllm/Qwen3.6-35B-A3B-NVFP4",   "workspace": "~/.openclaw/ws-devops" }
    ]
  }
}
```
This maps your decided tiers: Opus 4.8 CEO; GPT-OSS-120B for Architect/Coder/QA/Security (heavy, on-demand via llama-swap); Qwen3.6-35B-A3B for PA/PM/DevOps (always-resident). Configure sub-agents to default to the cheaper local model for cost control.

**Per-agent Slack bots.** Create one Slack app per agent (or use per-channel routing). Required bot scopes: `chat:write`, `chat:write.public`, `channels:read`, `groups:read`, `users:read`, `app_mentions:read`; event subscriptions `app_mention`, `message.channels`, `message.groups`. Key config to avoid chaos: `requireMention: true` (bot replies only when @mentioned), `replyToMode: "off"` (prevents bots replying to each other), `replyToModeByChatType.channel: "first"` (replies in-thread), `thread.inheritParent: true` (threads keep parent context). Start in **pairing mode** during pilot (users run `openclaw pairing approve slack <code>`), then move to allowlist. **Telegram alternative:** simpler single-token setup, uses long-polling (no public URL), and the NemoClaw Telegram bridge runs *outside* the sandbox, bypassing the proxy-403 issues that affect in-sandbox Discord/Telegram (#391, #685).

**Workspace file architecture (per agent):**
- `SOUL.md` — persona/role/tone. Distinct per agent (e.g., Architect = "rigorous; asks for constraints before designing; outputs ADRs"; Security = "adversarial; assumes hostile input; blocks on unverified external content").
- `AGENTS.md` — operating rules, tool-policy reminders, escalation paths.
- `USER.md` — profile of you (the operator) and preferences.
- `MEMORY.md` — persistent notes, kept lean (the NemoClaw plugin scanner blocks secrets from being written here).
- `IDENTITY.md` — display name / behavioral fingerprint; never copy identical identities across agents.
- **Shared project workspace** as single source of truth (your design): a git-versioned directory all agents read, holding the task board/tickets and project state. Keep workspaces lean — they're prefilled on every turn, so bloat directly inflates prompt-cache write cost.

**CEO orchestrator system-prompt design.** Have the CEO emit a strict task-decomposition template for every delegation:
```
GOAL:          <one-sentence outcome>
OWNER:         <agent id>
INPUTS:        <files/links/context refs in shared workspace>
DELIVERABLE:   <artifact + location>
DONE-CRITERIA: <objective, testable checks>
BUDGET:        <max tokens / max runtime / max retries>
```
**Dispatch patterns:** (1) **sub-agent spawning** (`sessions_spawn` / `/subagents spawn`) for parallel research and slow tool tasks — sub-agents run in their own session, post back results, and should use the cheap local model; (2) **channel tickets** — CEO posts a structured ticket into the owning agent's Slack channel (human-visible work); (3) **task queue** in the shared workspace, dispatched by your custom dashboard layer (scheduled/batch). Use sub-agents for fan-out, channel tickets for visible deliverables, the queue for cron/batch.

**Session management & memory.** Sessions persist as JSONL under `~/.openclaw/agents/<id>/sessions/`. Enable compaction so long agentic traces stay on task (Opus 4.8 has "better compaction handling … fewer derailments after compaction"). Compact/flush memory on a schedule; keep MEMORY.md curated to control prefill cost.

**Heartbeat vs cron (2026 guidance).** OpenClaw's **Heartbeat** wakes the agent on a schedule (default 30m, or **1h under Anthropic OAuth/token auth**; set via `agents.defaults.heartbeat.every` or per-agent `agents.list[].heartbeat.every` — **not** via HEARTBEAT.md, which is a runtime checklist the agent reads, not the interval setting) to check a task queue and act only if needed — clean and predictable for daily digests, monitoring, and proactive alerts. Use Heartbeat for routine recurring checks (DevOps health, PA daily brief). The built-in cron/heartbeat was noted as weak on multi-agent dispatch and reliable Telegram delivery (a key reason to build the custom dashboard dispatcher). Hermes' natural-language cron + durable Kanban board is the upgrade path in Phase 3.

**Sub-agent limits.** Sub-agents are excellent for cost control (expensive main model, cheap sub-agents) and parallel work, but each adds latency and token cost; cap concurrent sub-agents and give each a hard budget via the BUDGET field.

**Anthropic API wiring for the CEO.** Place credentials in the CEO agent's per-agent auth profile (do not auto-share the main agent's credentials). **OpenShell allowlist must include `api.anthropic.com:443`** with `/usr/local/bin/node` in the policy `binaries` list — otherwise the gateway's node process is blocked with 403 (same root cause as the Ollama/Telegram bugs). Use **prompt caching** (cache the system + tools + stable workspace prefix up to a cache breakpoint; cache reads are 0.1× input price ≈ 90% savings; 1,024-token minimum on Opus 4.8). Use **mid-conversation system messages** (`role:"system"` after a user turn) to update instructions without breaking the cache. Set **effort** explicitly (default `high`; reserve `xhigh`/`max` for hard tasks (levels are low/medium/high/xhigh/max — there is **no** `extra` level) — they multiply token spend). Consider **fast mode** (`speed:"fast"`, 2.5× throughput at $10/$50 per MTok) only for latency-critical CEO turns. Note Opus 4.8 does not support temperature/top_p/top_k (returns 400) and adaptive thinking is the only thinking mode.

**Spend caps (both layers):**
- **Anthropic console:** set workspace-level monthly spend limits and usage alerts; isolate the agent system in its own workspace (caches are workspace-isolated as of Feb 5, 2026).
- **OpenClaw-side fail-stop rules:** enforce your **3-failure stop** (agent halts after 3 consecutive tool/LLM failures) and **10-minute runtime cap** per task in the dispatcher; on trip, kill the session and alert you. Opus 4.8 standard pricing is $5/$25 per MTok input/output — model your monthly ceiling from expected CEO turns × cached-prefix size, and remember Dynamic Workflows cost scales with sub-agent count (per a **CloudZero** cost analysis, June 2026: "a 50-agent session … costs $25 per million output tokens across 50 simultaneous token streams" — this framing is CloudZero's, not in Anthropic's own announcement).

### 4. Security Hardening Runbook

**Official OpenClaw security checklist (run first):** `openclaw security audit` (plus `--deep`, `--fix`, `--json`). `--fix` flips open group policies to allowlists, restores `logging.redactSensitive: "tools"`, tightens state/config/include-file permissions, and flags gateway-auth exposure, browser-control exposure, elevated allowlists, permissive exec approvals, and open-channel tool exposure. OpenClaw's docs are explicit there is "no 'perfectly secure' setup."

**Gateway exposure:** Keep gateway on 127.0.0.1:18789. Never bind 0.0.0.0 on an untrusted network. Prefer Tailscale Serve. If using Docker, enforce egress rules in the `DOCKER-USER` iptables chain (published container ports bypass host INPUT rules).

**OpenShell network policy (deny-by-default).** The sandbox blocks all outbound connections unless explicitly listed in `nemoclaw-blueprint/policies/openclaw-sandbox.yaml`. Each entry restricts which executables (`binaries`, identified by kernel-trusted `/proc/<pid>/exe` + SHA256, re-checked on change — replacing a binary triggers an immediate deny) can reach an endpoint, and which HTTP methods/paths. **Exact allowlist entries for your build:**
- `api.anthropic.com:443` (CEO) — with `/usr/local/bin/node` in `binaries`.
- `<spark-ip>:8000` / `:30000` (vLLM/SGLang inference) — or the token-gated Ollama proxy on `:11435`.
- `slack.com` / `api.slack.com` / `wss-*.slack.com:443` (Slack); `api.telegram.org:443` (Telegram — the default policy historically had NO `binaries` section for telegram; add `/usr/local/bin/node`).
- `api.github.com` / `github.com:443` (only if agents push code).
- `registry.npmjs.org:443` and `pypi.org` / `files.pythonhosted.org:443` (only if agents install packages — present in the "Balanced" tier; **remove for non-Coder/DevOps agents**).
- Brave Search endpoint (only if web search enabled).
Deny everything else. Per-agent: untrusted agents get `agents.list[].tools` deny lists (deny `exec`); only Coder/DevOps need package-install egress.

**Prompt-injection defenses for web-browsing agents.** This is unsolved — OpenAI ("unlikely to ever be fully 'solved'"), Anthropic, and Google all concede it. Real 2026 incidents: the Brave→Perplexity Comet indirect injection (hidden Reddit spoiler-tag instructions exfiltrated an email + OTP); Google found a "32% relative increase in the malicious category between November 2025 and February 2026"; injections hide in white-on-white text, zero-height divs, images (OCR-readable), and URL params. **Defenses (layered, environment-level):** treat all external content as hostile; limit browser agents to allowlisted domains; use read-only browser sessions not logged into anything sensitive; require human approval before any action derived from untrusted web/email content; isolate the browsing agent with the tightest tool policy and its own sandbox; assume the model can be manipulated and minimize blast radius. Claude Opus 4.8 is the strongest/most-robust browser-agent Opus tested (84% on Online-Mind2Web) but injection is "far from solved" — keep browsing on a single, heavily-restricted research sub-agent only.

**ClawHub skill vetting.** Koi Security (Feb 1, 2026) found **341 malicious skills of 2,857 (11.9%)**, 335 from the coordinated "ClawHavoc" campaign delivering Atomic macOS Stealer (AMOS); by Feb 16 it was 824, and Antiy separately catalogued **1,184 historically** (the 1,184 is Antiy's figure, corroborated by cyberpress/GBHackers — it is not on the cited Koi post). Snyk's ToxicSkills audit found 13.4% (534) of ~4,000 skills had a *critical* issue and 36.82% (1,467) had **any** security flaw — the "36%" is NOT "prompt injection" (a separate ~91% figure is prompt-injection overlap within confirmed-malicious payloads). Attack vector: a malicious SKILL.md instructs the user/agent to run a staged loader ("pastebin piping"); comment-based pivots bypass SKILL.md scanning. **Platform controls now in place:** **VirusTotal scanning of every published skill, with daily re-scans** (confirmed); v2026.2.12 (2026-02-13) added mandatory browser-control auth + an SSRF-deny policy. *Not in the cited reporting (verify before relying):* a "1-week-minimum publisher account age", "auto-hide after 3 reports", and the "40+ vulns / since Feb 7" specifics. **Your policy:** disable automatic skill updates; treat skill folders as trusted code; manually vet every skill (read SKILL.md for download/exec instructions); scan with Koi's **Clawdex** or Silverfort's **ClawNet** plugin before install; never install based on popularity (Silverfort gamed a skill to #1 → 3,900 executions in 6 days across 50+ cities).

**Secrets management.** Gateway token in `OPENCLAW_GATEWAY_TOKEN` / `/tmp/nemoclaw-proxy-env.sh` (0600); the Ollama proxy token in `~/.nemoclaw/ollama-proxy-token` (0600); the NemoClaw plugin blocks the agent from writing API keys/tokens/private keys into memory files, and the CLI redacts secrets in logs. Don't store keys in plaintext workspace files; use per-agent auth profiles and strict OS file permissions. Rotate bot tokens and API keys regularly. Use the reviewed host-side immutability workflow to lock config/secret dirs for sensitive workloads.

**Approval gates.** Configure `tools.exec` with `ask` + an allowlist (start read-only: ls, cat, df, ps, top; add write paths deliberately; never grant package managers or destructive commands broadly). The shell approval path now parses inside `bash -c` wrappers (Tree-sitter) so a wrapper can't smuggle a disallowed binary, and fails closed on forms it can't parse. Note YOLO (`security=full`, `ask=off`) is the *default* host behavior — explicitly tighten `tools.exec.security`/`ask` to allowlist/deny. Require approval for high-impact actions.

**What NOT to connect:** No banking, no password managers / primary password store, no primary email. Follow the "treat it like a new employee" model (Brian Casel): dedicated agent email, a separate GitHub username invited only to specific repos, a separate Dropbox/file account with only needed folders synced, and granular revocable permissions.

**Backup/snapshot strategy:** Git-version the shared workspace and all agent workspaces (SOUL/AGENTS/USER/MEMORY/IDENTITY). Back up `openclaw.json`, the OpenShell network-policy YAML, and `~/.openclaw/agents/*` config. Snapshot the NVMe model library separately (large but reconstructable from NGC/HF).

**Recovery — runaway agent kill switch (in order):**
1. Stop the agent session / gateway: `openclaw gateway restart` or kill the session; for the sandbox, `nemoclaw <name> stop`.
2. Kill inference: `docker stop` the vLLM / llama-swap / sandbox containers.
3. Revoke the Anthropic API key in the console (and rotate bot tokens) if compromise is suspected.
4. Review logs (`logToolCalls`, `logMessages`, `logApiCalls`, `redactSecrets`) and `lsof -i -P -n | grep` for unexpected outbound connections before restarting.

### 5. Operating Playbook (Day 2 → Month 3)

**Daily:**
- `nemoclaw <name> status` + gateway health; review overnight Heartbeat actions.
- GPU/memory: `nvidia-smi` (GB10 reports unified memory; CUDA sees ~121.7 GiB of 128); watch for post-swap memory lag; tokens/sec via vLLM `/metrics` (Prometheus) and LiteLLM logs.
- Scan logs for `denied/blocked/error` and any unexpected outbound connections.
- Check the Anthropic spend dashboard against your daily ceiling.

**Weekly:**
- `openclaw security audit --deep`.
- Re-vet any new/updated skills (auto-update stays OFF); re-scan with Clawdex/ClawNet.
- Update vLLM/NemoClaw deliberately (pin digests; the ecosystem moves fast and breaks — test on a non-critical agent first). Track NemoClaw release notes (currently following the "lkg" tag) and the vLLM sm_121 issues.
- Back up workspaces (git commit/push) and config.
- Review tokens/sec trends and per-agent cost; rebalance if a routine agent is overusing the 120B.

**Staged rollout plan (your decided approach):**
- **Phase 1 (Weeks 1-3): 3-4 agents.** CEO (Opus 4.8) + PA + Coder + DevOps. Validate serving stability, the proxy/allowlist path, Slack wiring, spend caps, fail-stops. Pairing mode, no web browsing.
- **Phase 2 (Weeks 4-8): expand to 8 agents.** Add PM, Architect, QA, Security Auditor. Introduce the custom dashboard/dispatch layer — Brian Casel "Builder Methods" style (his is Rails + Inertia + React, deployed locally with Cloudflare Tunnel + Zero Trust; he runs a 4-agent team in Slack on a Mac Mini), or adopt the open-source **Mission Control** (builderz-labs: SQLite-backed, task dispatch, cost tracking, RBAC, built-in Aegis review gate, OpenClaw adapter). Enable web browsing only for one tightly-sandboxed research sub-agent.
- **Phase 3 (Month 2-3): add Hermes Agent for learning loops.** Hermes (Nous Research, released Feb 2026) adds a do→learn→improve loop, durable Kanban board, and autonomous skill creation. Layer it as the *execution/learning* layer while OpenClaw stays *orchestration* (they're complementary, per multiple 2026 comparisons). Add Hermes only once the 8-agent system is stable and security is validated — its self-evaluation is reportedly unreliable and manual edits can be overwritten, so introduce it on non-critical workflows first. NemoClaw v0.0.52+ bundles a working Hermes sandbox entrypoint.

**Benchmarks/thresholds that change the plan:**
- If GPT-OSS-120B tool-calling is unreliable on vLLM for coding agents → test SGLang or wait for a vLLM point release; don't ship Coder/QA to production until tool calls are reliable.
- If Opus 4.8 monthly spend approaches your ceiling → push more work to the local routine tier, drop effort to default/low, and batch non-interactive jobs (Batch API = 50% off).
- If vLLM #37431 (Mamba) clears and Nemotron-3-Super NVFP4 stops crashing → re-evaluate Nemotron-3-Super as a heavy-tier alternative.
- If any agent trips fail-stops repeatedly → tighten its DONE-CRITERIA and tool policy before re-enabling.
- If decode throughput on the resident Qwen3.6 drops below ~30 tok/s under load → reduce `--max-num-seqs`, shrink context, or move a routine agent off the 120B.

## Recommendations

1. **Buy now if you need it.** The DRAM shortage is structural (SK hynix/Samsung warn it runs past 2027; DRAM contract prices forecast +58-63% this quarter), so prices are likelier to rise than fall. Get the **4TB Founders Edition** (you need NVMe for a 600GB+ model library). Budget ≈CA$7,200 street (verified 2026-06-05; Canada Computers/Newegg.ca CA$7,199).
2. **Week 1 — hardware + serving only.** OOBE → manual OTA → NemoClaw install (use the `--non-interactive` flag) → solve the proxy/allowlist path → stand up vLLM GPT-OSS-120B (eugr MXFP4 build) + Qwen3.6-35B-A3B resident → validate tokens/sec and the `drop_caches` ritual. Connect no channels yet.
3. **Week 2 — security baseline, then 3-4 agents.** Run `openclaw security audit --fix`; lock the OpenShell allowlist to exactly the endpoints above; Tailscale Serve; SSH tunnel for the dashboard (always `127.0.0.1`). Bring up CEO + PA + Coder + DevOps in pairing mode with spend caps and fail-stops live.
4. **Weeks 4-8 — scale to 8 + build the dashboard.** Adopt Mission Control or build the Casel-style dispatcher; add PM/Architect/QA/Security; enable one sandboxed browsing sub-agent behind human approval gates.
5. **Month 2-3 — add Hermes** for learning loops on non-critical workflows once stability and security are proven.
6. **Standing rules:** skill auto-update OFF; vet every skill (Clawdex/ClawNet); pin inference image digests; never connect banking/passwords/primary email; weekly audits and backups; one deliberate update window per week.

## Caveats
- **Fast-moving, alpha ecosystem — verify versions on arrival.** Many specifics (NemoClaw v0.0.5x → v0.0.59, vLLM nightly tags, default model now Qwen3.6-35B) will have moved by the time you build. Pin digests and re-read the NemoClaw release notes and vLLM sm_121 issues. NemoClaw is early-preview (announced March 16, 2026); OpenShell, Mission Control, and the eugr/community builds are community/alpha — expect breakage and keep rollback paths.
- **Performance numbers are single-stream and workload-dependent.** ~60 tok/s on GPT-OSS-120B (eugr README) assumes the CUTLASS MXFP4 path; out-of-the-box flags can be far slower (one reviewer measured ~11.66 tok/s at batch 1 on stock settings, another ~26 tok/s via Ollama). NVFP4 speculative decoding is experimental and crash-prone.
- **Prompt injection is not solvable, only mitigatable** — accept residual risk on any web-browsing agent and keep blast radius minimal.
- **Resolved since the first draft:** vLLM issue **#37854** is a live **open** bug — "NGC vLLM 26.02 rejects Nemotron-3-Super-120B-A12B-NVFP4 — quant_algo MIXED_PRECISION not in whitelist" (re-verified via gh api 2026-06-05) — another reason the Nemotron NVFP4 path is blocked today.
- **Third-party setup blogs vary in reliability.** Where I relied on community guides (Medium, personal blogs, dredyson.com), treat exact file paths/flags as starting points to verify against official NVIDIA/OpenClaw docs and the actual GitHub issues. One third-party guide cited a gateway-token path (`/root/.config/openclaw/gateway.yaml`) that contradicts official docs (`/sandbox/.openclaw/openclaw.json`) — trust the official path.
- **DGX OS version specifics:** I infer the June 2026 release sits on the DGX OS 7.5.x line; confirm the exact build number on your unit. The operationally important facts (OTA-not-installed-by-default, NemoClaw playbook auto-open) are confirmed in the official release notes.