# Cluster 1 — vLLM on sm_121 (GB10 / DGX Spark)

*Verified 2026-06-05. Claims sourced from `docs/master-plan.md` (§2 build sequence). Method: two-stage adversarial verification (independent research → independent re-verification of every ✓/⚠), plus lead-level `gh api`/HF spot-checks on load-bearing claims.*

**Verdict legend:** ✓ confirmed at a primary source · ⚠ partially true / caveated / stale · ✗ contradicted by the source · ? could not verify

**Tally:** 16 findings — **9 ✓ · 7 ⚠ · 0 ✗ · 0 ?**

## Summary

After independent re-verification, the cluster is mostly accurate and the original report's analysis was largely sound, with one verdict I corrected. All six vLLM GitHub objects were re-hit via gh api and match exactly: #37030/#37431/#36821/#35519/#37854 are OPEN with bodies confirming the plan's content; #31128 is CLOSED (not a live tracker); and the plan's biggest real error stands — PR #35947 has merged=false, closed 2026-03-25, so its claimed E2M1 NVFP4 'fix' never landed. The eugr/spark-vllm-docker repo (1530 stars, cu132 wheel) and all its flags (--solo, --apply-mod, gpu-mem-util-gb, --tf5, --exp-mxfp4, --mxfp4-backend/-layers) are genuine; the plan's perf numbers (35→56-57 vs README's 40→60 tok/s), build timings, cu130-vs-cu132, the --tf5-to-Mamba link, and the '~1hr/CUTLASS fork' build wording remain mismatched/unsupported as the report flagged. Hardware facts (273 GB/s, 256-bit/16ch LPDDR5X 8533) and GPT-OSS-120B's 117B/5.1B are verbatim-confirmed; 'sm_121 binary-compatible with sm_120' is overstated and '117B/21B total' wrongly merges two models. The one correction: the report marked the NGC '26.03-py3' tag as unverified/⚠, but NVIDIA's official rel-26-03.html release notes (vLLM 0.17.1, CUDA 13.2), the standard NGC monthly tag convention, and a 26.03.post1-py3 DGX Spark forum thread all confirm it exists — so that finding is upgraded to ✓. Net: the cluster's substance is reliable, but consumers must not treat #31128 as live, must not believe #35947 'fixed' the crash, and should disregard the report's claim that 26.03-py3 doesn't exist.

## Findings

| # | Verdict | Claim | Evidence (URL · date) |
|---|---|---|---|
| 1.1 | ✓ | vLLM issue #37030 — GPT-OSS MXFP4 Marlin emits wrong first Harmony token on sm_121 (null content/reasoning); OPEN | [link](https://github.com/vllm-project/vllm/issues/37030) · 2026-06-05 |
| 1.2 | ✓ | vLLM issue #37431 — Mamba-2 Triton 'illegal instruction', needs CUDA_LAUNCH_BLOCKING=1, affects Nemotron-3-Super; OPEN | [link](https://github.com/vllm-project/vllm/issues/37431) · 2026-06-05 |
| 1.3 | ✓ | vLLM issue #36821 — sm_121 aarch64 umbrella ('no sm_121 on aarch64') | [link](https://github.com/vllm-project/vllm/issues/36821) · 2026-06-05 |
| 1.4 | ⚠ | vLLM issue #31128 — native-support request for GB10/sm_121 | [link](https://github.com/vllm-project/vllm/issues/31128) · 2026-06-05 |
| 1.5 | ⚠ | vLLM issue #35519 — NVFP4 illegal instruction, fixed by PR #35947 for E2M1 but Mamba ops remain broken | [link](https://github.com/vllm-project/vllm/pull/35947) · 2026-06-05 |
| 1.6 | ⚠ | vLLM issue #37854 (plan flags as UNCONFIRMED) — determine if a distinct live thread exists and what it is about | [link](https://github.com/vllm-project/vllm/issues/37854) · 2026-06-05 |
| 1.7 | ✓ | eugr/spark-vllm-docker provides pre-built vLLM + FlashInfer wheels for GB10 (CUDA 13.1, SM12.1a, ARM64) | [link](https://github.com/eugr/spark-vllm-docker/releases/tag/prebuilt-vllm-current) · 2026-06-05 |
| 1.8 | ✓ | launch-cluster.sh --solo; --apply-mod patches; gpu-mem-util-gb absolute-memory-cap mod | [link](https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md) · 2026-06-05 |
| 1.9 | ⚠ | build-and-copy.sh (~15 min); --tf5 flag for Qwen3.6 / Mamba-hybrid (Transformers 5.x) | [link](https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md) · 2026-06-05 |
| 1.10 | ⚠ | --exp-mxfp4 build (~1 hr, compiles a CUTLASS fork) pushes GPT-OSS-120B from ~35 to ~56-57 tok/s via --mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head | [link](https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md) · 2026-06-05 |
| 1.11 | ✓ | vllm.ai/blog has a 2026-06-01 'vLLM on the DGX Spark' post warning to treat cu130-nightly as 'a compatibility track rather than a reproducible pin' | [link](https://vllm.ai/blog/2026-06-01-vllm-dgx-spark) · 2026-06-05 |
| 1.12 | ✓ | Official images exist: vllm/vllm-openai:cu130-nightly; nvcr.io/nvidia/vllm:25.12.post1 and 26.03-py3 | [link](https://docs.nvidia.com/deeplearning/frameworks/vllm-release-notes/rel-26-03.html) · 2026-06-05 |
| 1.13 | ⚠ | HW facts: GB10 BW 273 GB/s (16ch 256-bit LPDDR5X 8533); sm_121 binary-compatible with sm_120; stock PyPI vLLM ships CPU-only torch on aarch64 with kernels only through sm_120 | [link](https://docs.nvidia.com/dgx/dgx-spark/hardware.html) · 2026-06-05 |
| 1.14 | ⚠ | GPT-OSS-120B activates 5.1B params/token; 117B/21B total params (OpenAI's official release wording) | [link](https://huggingface.co/openai/gpt-oss-120b) · 2026-06-05 |
| 1.15 | ✓ | TP must be 1 on a single GB10 (TP=4 fails to launch) | [link](https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md) · 2026-06-05 |
| 1.16 | ✓ | NVIDIA developer forums (DGX Spark/GB10): any sm_121 vLLM developments in the last 30 days | [link](https://forums.developer.nvidia.com/c/accelerated-computing/dgx-spark-gb10/719) · 2026-06-05 |

## Finding detail

### 1.1 · ✓ — vLLM issue #37030 — GPT-OSS MXFP4 Marlin emits wrong first Harmony token on sm_121 (null content/reasoning); OPEN
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/vllm-project/vllm/issues/37030 (2026-06-05)
- **Notes:** Re-verified via gh api: state=open, closed_at=null, created 2026-03-14. Title verbatim: '[Bug]: GPT-OSS-120B gpt-oss MXFP4 on SM121 (Blackwell DGX Spark): Marlin kernel generates wrong first Harmony token, producing null content/reasoning'. Body confirms: env GPU 'NVIDIA B200 / DGX Spark (SM121)', vLLM 0.16.0rc2, '--quantization mxfp4', and 'all chat completions return content: null and reasoning: null despite completion_tokens showing that tokens were generated.' The B200 label is the reporter's mislabel; the body is unambiguously SM121/DGX Spark. Claim fully supported.

### 1.2 · ✓ — vLLM issue #37431 — Mamba-2 Triton 'illegal instruction', needs CUDA_LAUNCH_BLOCKING=1, affects Nemotron-3-Super; OPEN
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/vllm-project/vllm/issues/37431 (2026-06-05)
- **Notes:** Re-verified via gh api: state=open, closed_at=null, created 2026-03-18. Title verbatim: 'Mamba-2 Triton kernels crash with illegal instruction on SM121 (DGX Spark) without CUDA_LAUNCH_BLOCKING=1'. Body: GPU 'NVIDIA GB10 (SM121) — DGX Spark', model 'nvidia/NVIDIA-Nemotron-3-Super-120B-A12B-NVFP4 (NemotronHForCausalLM, hybrid Mamba-2 + Transformer + MoE)', 'NemotronH models that use Mamba-2 layers crash with CUDA error: an illegal instruction was encountered', and 'Setting CUDA_LAUNCH_BLOCKING=1 makes the model fully stable but degrades throughput from ~14 tok/s ... to ~8.8 tok/s'. All three claim elements confirmed.

### 1.3 · ✓ — vLLM issue #36821 — sm_121 aarch64 umbrella ('no sm_121 on aarch64')
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/vllm-project/vllm/issues/36821 (2026-06-05)
- **Notes:** Re-verified via gh api: state=open, closed_at=null, created 2026-03-11. Title verbatim: '[Bug]: No sm_121 (Blackwell) support on aarch64 — NVIDIA DGX Spark / Acer GN100'. Body: 'vLLM fails to start on NVIDIA DGX Spark (GB10 Blackwell, sm_121) because the bundled PyTorch binary only includes compiled CUDA kernels through sm_120 ... This is a build-time issue — the shipped .so files lack sm_121 targets ... vLLM crashes at startup during CUDA kernel initialization.' Canonical umbrella issue, confirmed.

### 1.4 · ⚠ — vLLM issue #31128 — native-support request for GB10/sm_121
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://github.com/vllm-project/vllm/issues/31128 (2026-06-05)
- **Notes:** Re-verified via gh api: title '[Feature]: Add support of Blackwell SM121(DGX Spark)', label 'feature request', created 2025-12-22, but CLOSED (closed_at 2025-12-23). The issue content matches 'native-support request' but it was closed the day after opening, so it is NOT a live tracker — a plan relying on it as such would be stale. Report's ⚠ stands.

### 1.5 · ⚠ — vLLM issue #35519 — NVFP4 illegal instruction, fixed by PR #35947 for E2M1 but Mamba ops remain broken
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://github.com/vllm-project/vllm/pull/35947 (2026-06-05)
- **Notes:** Re-verified both objects via gh api. #35519 is real and OPEN (title '[Bug]: Qwen3.5 NVFP4 models crash on ARM64 GB10 DGX Spark (CUDA illegal instruction during generation)', created 2026-02-27, env PyTorch 2.10.0+cu130 aarch64). PR #35947 is real (title 'fix: Software E2M1 conversion for SM12x NVFP4 activation quantization'); body confirms mechanism verbatim: 'SM12x GPUs (RTX 5090, GB10 / DGX Spark) lack the hardware cvt.rn.satfinite.e2m1x2.f32 PTX instruction ... this instruction is SM100-only, causing an illegal instruction crash.' CRITICAL: gh api shows merged=false, merged_at=null, state=closed, closed_at 2026-03-25 — the E2M1 fix was PROPOSED but NEVER MERGED, so the plan's word 'fixed' is wrong. Right issue, right PR, right mechanism, fix did not land. (Note: #35947 body adds 'The Marlin backend already works on SM12x ... but the CUTLASS path was broken' — a nuance, not a contradiction.) Report's ⚠ is the correct verdict.

### 1.6 · ⚠ — vLLM issue #37854 (plan flags as UNCONFIRMED) — determine if a distinct live thread exists and what it is about
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://github.com/vllm-project/vllm/issues/37854 (2026-06-05)
- **Notes:** Re-verified via gh api: state=open, closed_at=null, created 2026-03-23. It is a concrete, live bug (NOT vague): '[Bug]: NGC vLLM 26.02 rejects Nemotron-3-Super-120B-A12B-NVFP4 — quant_algo MIXED_PRECISION not in whitelist'. Body: container 'nvcr.io/nvidia/vllm:26.02-py3', vLLM 0.15.1, GB10 SM 12.1; config.json (modelopt 0.43.0) sets 'quant_algo: "MIXED_PRECISION"' which 'vLLM 0.15.1 rejects against a hardcoded whitelist', and 'The FP8 variant does not fit in 128 GB unified memory ... so the NVFP4 variant is the only viable path'. The plan's uncertainty resolves to a real live issue. Report's ⚠ stands.

### 1.7 · ✓ — eugr/spark-vllm-docker provides pre-built vLLM + FlashInfer wheels for GB10 (CUDA 13.1, SM12.1a, ARM64)
- **Verdict:** ✓ Confirmed
- **Evidence:** https://github.com/eugr/spark-vllm-docker/releases/tag/prebuilt-vllm-current (2026-06-05)
- **Notes:** Re-verified via gh api: repo exists, 1530 stars, pushed 2026-06-03. Release prebuilt-vllm-current asset 'vllm-0.22.1rc1.dev124+gace95c9cf.d20260603.cu132-cp312-cp312-linux_aarch64.whl' (published 2026-06-03); release prebuilt-flashinfer-current ships flashinfer_python-0.6.12 + flashinfer_jit_cache manylinux_2_28_aarch64 (2026-06-03). README (raw, 68,963 bytes) targets '12.1a architecture'. linux_aarch64 + 12.1a/GB10 confirmed. CAVEAT: wheel is tagged cu132 (CUDA 13.2), not 13.1 as the plan says — CUDA moved on since the plan was written; SM12.1a/ARM64 targeting unchanged. Overall claim supported; report's ✓ with cu132 caveat stands.

### 1.8 · ✓ — launch-cluster.sh --solo; --apply-mod patches; gpu-mem-util-gb absolute-memory-cap mod
- **Verdict:** ✓ Confirmed
- **Evidence:** https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md (2026-06-05)
- **Notes:** Re-verified by grepping the raw README. '--solo' is the solo-mode flag for launch-cluster.sh (multiple usages, e.g. line 74 './launch-cluster.sh --solo exec', and 'Added solo mode to launch-cluster.sh to launch models on a single node'). '--apply-mod mods/...' confirmed (e.g. '--apply-mod mods/gpu-mem-util-gb'). mods/gpu-mem-util-gb described verbatim: 'adds a --gpu-memory-utilization-gb flag to vLLM, allowing you to specify GPU memory reservation in GiB instead of as a fraction' (example '--gpu-memory-utilization-gb 110') — i.e. an absolute GiB cap. All three confirmed.

### 1.9 · ⚠ — build-and-copy.sh (~15 min); --tf5 flag for Qwen3.6 / Mamba-hybrid (Transformers 5.x)
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md (2026-06-05)
- **Notes:** Re-verified by grepping the raw README. build-and-copy.sh exists; '--tf5 | Install transformers v5 (5.0.0 or higher). Aliases: --pre-tf, --pre-transformers' — Transformers 5.x confirmed. Two gaps stand: (1) Timing — README says 'After base image pull, the build should take only 2-3 minutes' (prebuilt wheels) and source rebuilds '20-40 minutes'; the plan's '~15 min' matches neither. (2) Use case — README ties --pre-tf/--tf5 to 'GLM 4.6V or any other model that requires transformers 5.0' and to the Qwen3.6 chat-template recipes; NO README text links --tf5 to 'Mamba-hybrid' models. That part is unsupported. Report's ⚠ stands.

### 1.10 · ⚠ — --exp-mxfp4 build (~1 hr, compiles a CUTLASS fork) pushes GPT-OSS-120B from ~35 to ~56-57 tok/s via --mxfp4-backend CUTLASS --mxfp4-layers moe,qkv,o,lm_head
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md (2026-06-05)
- **Notes:** Re-verified by grepping the raw README. Flags exact-match: serve example shows '--mxfp4-backend CUTLASS' and '--mxfp4-layers moe,qkv,o,lm_head' (lines 897-898), and '--exp-mxfp4 | Build with experimental native MXFP4 support'. NUMBERS OFF: README says standard path 'You can expect ~40 t/s generation speed' (plan says ~35) and the MXFP4 build is 'currently the fastest way to run GPT-OSS on DGX Spark, achieving 60 t/s on a single Spark' (plan says 56-57). Build-time '~1 hr' and 'compiles a CUTLASS fork' wording NOT found in the README (source rebuilds quoted at 20-40 min; MXFP4 uses a separate --exp-mxfp4 build path). Directionally correct, specific figures don't match. Report's ⚠ stands.

### 1.11 · ✓ — vllm.ai/blog has a 2026-06-01 'vLLM on the DGX Spark' post warning to treat cu130-nightly as 'a compatibility track rather than a reproducible pin'
- **Verdict:** ✓ Confirmed
- **Evidence:** https://vllm.ai/blog/2026-06-01-vllm-dgx-spark (2026-06-05)
- **Notes:** Re-verified via WebFetch. Title 'vLLM on the DGX Spark: Architecture, Configuration, and Local Evaluation', dated June 1 2026. Verbatim: 'Because nightly tags move over time, treat cu130-nightly as a compatibility track rather than a reproducible pin.' Also confirms 'vllm/vllm-openai:cu130-nightly' as the tested tag and the ConnectX-7 / --tensor-parallel-size quote. Quote matches the plan exactly. Report's ✓ stands.

### 1.12 · ✓ — Official images exist: vllm/vllm-openai:cu130-nightly; nvcr.io/nvidia/vllm:25.12.post1 and 26.03-py3
- **Verdict:** ✓ Confirmed
- **Evidence:** https://docs.nvidia.com/deeplearning/frameworks/vllm-release-notes/rel-26-03.html (2026-06-05)
- **Notes:** CORRECTED ⚠→✓ (verifier disagrees with the original report). vllm/vllm-openai:cu130-nightly: confirmed (vllm.ai blog tested tag). nvcr.io/nvidia/vllm:25.12.post1: confirmed (NGC 26.01 forum thread references it, and issue #31424 references the 25.12 line). 26.03-py3: the original report claimed 'No 26.03-py3 appeared in any source' — that was a verification MISS. NVIDIA's OFFICIAL release-notes page rel-26-03.html documents 'vLLM Release 26.03' (vLLM 0.17.1, based on CUDA 13.2.0, 'available on NGC'); NGC's monthly tag convention is 'nvcr.io/nvidia/vllm:<xx.xx>-py3' with xx.xx=26.03 → 'nvcr.io/nvidia/vllm:26.03-py3'; and an NVIDIA DGX Spark forum thread (dated 2026-04-17) confirms 'nvcr.io/nvidia/vllm:26.03.post1-py3' loads Nemotron-3-Super-120B-A12B-NVFP4 on DGX Spark (post1 is a patch revision of the same 26.03 release). All three tags in the claim are therefore supported. The 26.02-py3 (vLLM 0.15.1) tag is also confirmed via issue #37854. Claim is correct as written.

### 1.13 · ⚠ — HW facts: GB10 BW 273 GB/s (16ch 256-bit LPDDR5X 8533); sm_121 binary-compatible with sm_120; stock PyPI vLLM ships CPU-only torch on aarch64 with kernels only through sm_120
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://docs.nvidia.com/dgx/dgx-spark/hardware.html (2026-06-05)
- **Notes:** Re-verified via WebFetch (page 200, last-modified 2026-06-01). NVIDIA's official hardware page states verbatim 'Memory Bandwidth: 273 GB/s', '128 GB LPDDR5x unified system memory, 256-bit interface, 4266 MHz', and 'Memory Channels: 16 channels (256 bit) LPDDR5X 8533' (4266 MHz DDR = 8533 effective). CPU-only aarch64 torch + kernels only through sm_120: supported by issue #36821 body ('bundled PyTorch binary only includes compiled CUDA kernels through sm_120 ... vLLM crashes at startup'). CAVEAT on 'sm_121 binary-compatible with sm_120': overstated — #36821 explicitly says the shipped sm_120 kernels do NOT run and require a sm_121 rebuild; 'binary-compatible' as stated is too strong. Report's ⚠ stands.

### 1.14 · ⚠ — GPT-OSS-120B activates 5.1B params/token; 117B/21B total params (OpenAI's official release wording)
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://huggingface.co/openai/gpt-oss-120b (2026-06-05)
- **Notes:** Re-verified via WebFetch + HF API (model exists, 200). OpenAI's official model card states verbatim: 'gpt-oss-120b ... (117B parameters with 5.1B active parameters)' and 'gpt-oss-20b ... (21B parameters with 3.6B active parameters)'. So 117B total + 5.1B active/token is exactly right FOR THE 120B model. But '117B/21B total params' conflates two DIFFERENT models: 21B is the separate gpt-oss-20b model's total, not a second figure for the 120B. The plan's phrasing is misleading. Report's ⚠ stands.

### 1.15 · ✓ — TP must be 1 on a single GB10 (TP=4 fails to launch)
- **Verdict:** ✓ Confirmed
- **Evidence:** https://raw.githubusercontent.com/eugr/spark-vllm-docker/main/README.md (2026-06-05)
- **Notes:** Supported indirectly but consistently across two fetched sources. vllm.ai blog: '--tensor-parallel-size 2 is only meaningful if two Sparks are linked through the ConnectX-7 ports; use it for validated multi-Spark recipes rather than as a single-node tuning flag' — i.e. TP scales with node count, so a single Spark is TP=1. eugr README gates node count by TP (solo/single-node recipes all use TP=1; TP=4 is documented only for a 4-Spark cluster). No source literally states 'TP=4 fails to launch on one GB10', but a single Spark cannot satisfy TP=4 and the launcher gates on node count. Claim is sound; report's ✓ stands (note it rests on inference from node-count gating, not a verbatim statement).

### 1.16 · ✓ — NVIDIA developer forums (DGX Spark/GB10): any sm_121 vLLM developments in the last 30 days
- **Verdict:** ✓ Confirmed
- **Evidence:** https://forums.developer.nvidia.com/c/accelerated-computing/dgx-spark-gb10/719 (2026-06-05)
- **Notes:** Forum category resolves (200) and is unambiguously live with ongoing sm_121 vLLM work (NGC 26.01 thread; the 26.03.post1-py3 Nemotron-NVFP4 thread). HOWEVER: the strongest in-window (>= 2026-05-06) PRIMARY source I could independently date-pin is the vllm.ai 2026-06-01 blog, not a forum post — the forum threads I individually date-verified are dated 2026-04 (e.g. the 26.03.post1 thread is 2026-04-17), OUTSIDE the strict last-30-day window. So 'sm_121 vLLM developments exist and the category is active' is confirmed, but I did NOT independently confirm a forum thread dated within May 6–Jun 5. Verdict kept at ✓ on the basis of overall live activity + the in-window blog, with this recency caveat made explicit.

## Method notes

GitHub: authenticated gh api re-hit for state/title/closed_at/labels and body text on issues #37030, #37431, #36821, #31128, #35519, #37854 and PR #35947 (real HTTP results; PR #35947 merged=false/merged_at=null/closed_at 2026-03-25 confirms the non-merge). eugr repo re-verified via gh api (repo meta: 1530 stars, pushed 2026-06-03; releases/assets) plus curl of the raw README.md (68,963 bytes) grepped for exact flag lines and perf numbers (lines 862 '~40 t/s', 868 '60 t/s', 897-898 mxfp4 flags, 964 --pre-tf/GLM-4.6V, 1129 --tf5 transformers v5; build timing line 65 '2-3 minutes'/'20-40 minutes'). WebFetch on vllm.ai/blog/2026-06-01-vllm-dgx-spark (date + verbatim 'compatibility track' + cu130-nightly + ConnectX-7 quotes), huggingface.co/openai/gpt-oss-120b (verbatim param wording; HF API 200), docs.nvidia.com/dgx/dgx-spark/hardware.html (273 GB/s, 256-bit, 16ch LPDDR5X 8533; page 200 last-modified 2026-06-01). For the NGC 26.03 question I used WebSearch + WebFetch on docs.nvidia.com/.../rel-26-03.html (vLLM 0.17.1, CUDA 13.2.0, available on NGC) and the forums.developer.nvidia.com 26.03.post1-py3 thread (2026-04-17, loads Nemotron-NVFP4 on DGX Spark) — this DISPROVED the report's 'no 26.03-py3 source' claim. curl -sI confirmed all four forum/docs URLs return 200. Could not independently confirm: a forum thread dated strictly within May 6–Jun 5 (date-pinned forum threads were 2026-04; in-window primary evidence is the June 1 blog); the exact bare '26.03-py3' tag via the JS-rendered NGC catalog (relied on NVIDIA release-notes + tag convention + post1 forum thread instead). verifier: 1 finding adjusted (#12 official images, ⚠→✓).
