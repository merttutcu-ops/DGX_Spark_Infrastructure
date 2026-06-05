# Cluster 3 — Models & serving (HF checkpoints, SGLang, NGC, llama-swap)

*Verified 2026-06-05. Claims sourced from `docs/master-plan.md` (§2 build sequence). Method: two-stage adversarial verification (independent research → independent re-verification of every ✓/⚠), plus lead-level `gh api`/HF spot-checks on load-bearing claims.*

**Verdict legend:** ✓ confirmed at a primary source · ⚠ partially true / caveated / stale · ✗ contradicted by the source · ? could not verify

**Tally:** 7 findings — **4 ✓ · 3 ⚠ · 0 ✗ · 0 ?**

## Summary

Cluster 3 is accurate on every load-bearing fact and, after adversarial re-verification, is MORE accurate than the teammate concluded. All four HF checkpoints exist (nvidia/Qwen3.6-35B-A3B-NVFP4, openai/gpt-oss-120b, google/gemma-4-26B-A4B + nvidia/Gemma-4-26B-A4B-NVFP4); gpt-oss-120b specifics (native MXFP4, 60.8GB per Artificial Analysis, 5.1B active, 117B/120.4B total) are verbatim-confirmed; the NVIDIA June 1 2026 blog is real with the exact title; the sglang-dgx-spark repo and dredyson.com guide exist and are credible; NGC vLLM tags 25.12.post1-py3 and 26.03-py3 are confirmed present. Most important correction: the teammate WRONGLY downgraded finding 1 architecture sub-claim. The plan Mamba/hybrid arch needing Transformers 5.x is CORRECT - config.json shows a 30x linear-attention + 10x full-attention hybrid (Gated DeltaNet/SSM), a mamba_ssm_dtype field, and transformers_version 5.7.0.dev0; the qwen3_5_moe tag the teammate relied on IS that hybrid family (HF card MoE with Hybrid Attention, vLLM recipes gated-delta-networks MoE, SGLang issue 20774 Hybrid Mamba+MoE). I upgraded finding 1 warning to confirmed. Remaining caveats unchanged: SGLang 50/70 tok/s are LMSYS single-Spark numbers (README is ~75 cluster); tool-calling instability is real but bugs 10089/12567 now closed; sglang:spark is a Docker Hub image not NGC; Gemma 4 39-155 DFlash band loosely corroborated. The teammate dredyson UMA-lag critique was slightly wrong (article says 30+ seconds, not a 30s cap), so the plan 30s-several minutes is not overstated.

## Findings

| # | Verdict | Claim | Evidence (URL · date) |
|---|---|---|---|
| 3.1 | ✓ | nvidia/Qwen3.6-35B-A3B-NVFP4 exists; ~17-23GB; A3B (~3B active); Mamba/hybrid arch needing Transformers 5.x | [link](https://huggingface.co/nvidia/Qwen3.6-35B-A3B-NVFP4/raw/main/config.json) · 2026-06-05 |
| 3.2 | ✓ | openai/gpt-oss-120b exists; native MXFP4; ~60.8GB (Artificial Analysis); 117B total / 5.1B active | [link](https://artificialanalysis.ai/articles/analysis-openai-gpt-oss-models) · 2026-06-05 |
| 3.3 | ✓ | developer.nvidia.com/blog has a June 1 2026 post about faster models and multi-node clustering for DGX Spark | [link](https://developer.nvidia.com/blog/run-local-ai-agents-with-faster-models-and-multi-node-clustering-on-nvidia-dgx-spark/) · 2026-06-05 |
| 3.4 | ⚠ | mark-ramsey-ri/sglang-dgx-spark exists; image lmsysorg/sglang:spark / tag v0.5.10.post1-cu130; ~50 tok/s 120B, ~70 20B; benign sm_121 warning; tool-calling unstable for 120B | [link](https://raw.githubusercontent.com/mark-ramsey-ri/sglang-dgx-spark/main/README.md) · 2026-06-05 |
| 3.5 | ⚠ | NGC catalog has tags nvcr.io/nvidia/vllm:25.12.post1 and 26.03-py3, and sglang:spark | [link](https://catalog.ngc.nvidia.com/api/containers/images?orgName=nvidia&name=vllm&isPublic=true) · 2026-06-05 |
| 3.6 | ✓ | Dre Dyson GB10 stack: client to LiteLLM(:14000) to llama-swap(:28080) to ephemeral vLLM; needs --network container:llama-swap; UMA CUDA doesn't immediately free memory after exit (30s-several min lag) | [link](https://dredyson.com/how-i-mastered-running-a-full-multi-model-llm-stack-on-dgx-spark-gb10-advanced-litellm-llama-swap-vllm-llama-cpp-ollama-configuration-guide-with-dynamic-vram-orchestration-for-10-models/) · 2026-06-05 |
| 3.7 | ⚠ | Gemma 4 26B-A4B NVFP4 as alternative; community images report 39-155 tok/s with DFlash speculative decoding; does Gemma 4 26B-A4B exist? | [link](https://huggingface.co/api/models/nvidia/Gemma-4-26B-A4B-NVFP4) · 2026-06-05 |

## Finding detail

### 3.1 · ✓ — nvidia/Qwen3.6-35B-A3B-NVFP4 exists; ~17-23GB; A3B (~3B active); Mamba/hybrid arch needing Transformers 5.x
- **Verdict:** ✓ Confirmed
- **Evidence:** https://huggingface.co/nvidia/Qwen3.6-35B-A3B-NVFP4/raw/main/config.json (2026-06-05)
- **Notes:** VERIFIER CORRECTION: teammate marked warning, claiming the Mamba/hybrid+Transformers-5.x portion was contradicted (reasoning: tag qwen3_5_moe = standard MoE transformer). That misreads a surface signal. I fetched config.json and it CONFIRMS the plan: text_config.layer_types is a 40-layer pattern of 3x linear_attention then 1x full_attention repeating (full_attention_interval=4) = 30 linear-attention + 10 full-attention layers; config has mamba_ssm_dtype, linear_conv_kernel_dim, linear_num_value_heads = an SSM/linear-attention (Gated DeltaNet) + MoE hybrid. transformers_version=5.7.0.dev0 (Transformers 5.x). HF card says Mixture-of-Experts with Hybrid Attention. Corroboration: vLLM recipes calls it gated-delta-networks MoE; SGLang issue 20774 titles family Qwen3.5-35B-A3B (Hybrid Mamba+MoE). The qwen3_5_moe model_type IS that hybrid family. EXISTS (HF API 200, lastModified 2026-05-29). SIZE: safetensors total=18,683,860,336, dominant U8=16,423,321,600 (NVFP4-packed) so ~17-23GB band reasonable. A3B/~3B active confirmed. Upgraded warning to confirmed.

### 3.2 · ✓ — openai/gpt-oss-120b exists; native MXFP4; ~60.8GB (Artificial Analysis); 117B total / 5.1B active
- **Verdict:** ✓ Confirmed
- **Evidence:** https://artificialanalysis.ai/articles/analysis-openai-gpt-oss-models (2026-06-05)
- **Notes:** Re-verified. HF API 200; tags include mxfp4, gpt_oss, vllm. safetensors total=120,412,337,472 (~120.4B; U8=118.24B MXFP4-packed). Artificial Analysis states verbatim gpt-oss-120b comes in at just 60.8GB (20b 12.8GB), 5.1B active parameters, 4.4% of total per forward pass, lists 117B total. All confirmed. Confirmed stands.

### 3.3 · ✓ — developer.nvidia.com/blog has a June 1 2026 post about faster models and multi-node clustering for DGX Spark
- **Verdict:** ✓ Confirmed
- **Evidence:** https://developer.nvidia.com/blog/run-local-ai-agents-with-faster-models-and-multi-node-clustering-on-nvidia-dgx-spark/ (2026-06-05)
- **Notes:** Re-verified by fetch. Exact title: Run Local AI Agents with Faster Models and Multi-Node Clustering on NVIDIA DGX Spark. Date June 1 2026. Covers faster models (up to 2.6x faster Qwen 3.6 35B on vLLM via NVFP4+MTP) and multi-node clustering (NVIDIA Sync, 2-4 units; 2 nodes=256GB, 4 nodes=512GB; ConnectX-7 200Gbps RoCE). All match. Confirmed stands.

### 3.4 · ⚠ — mark-ramsey-ri/sglang-dgx-spark exists; image lmsysorg/sglang:spark / tag v0.5.10.post1-cu130; ~50 tok/s 120B, ~70 20B; benign sm_121 warning; tool-calling unstable for 120B
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://raw.githubusercontent.com/mark-ramsey-ri/sglang-dgx-spark/main/README.md (2026-06-05)
- **Notes:** Re-verified. Repo EXISTS (17 stars, pushed 2026-05-01). README confirms BOTH images: lmsysorg/sglang:v0.5.10.post1-cu130 and lmsysorg/sglang:spark. Benign warning verbatim: Found GPU0 NVIDIA GB10 which is of cuda capability 12.1. Minimum and Maximum cuda capability supported by this version of PyTorch is (8.0)-(12.0), marked benign. TOK/S: README own number is ~75 tok/s output for 120B on dual-Spark on the older spark container; plan 50/70 come from LMSYS Nov-2025 blog (around 70 tokens/s on 20B and 50 tokens/s on 120B, single Spark) - both verbatim, different setups. TOOL-CALLING: README does NOT mention it, but real per SGLang issues: 10089 (CLOSED 2025-11-18) and 12567 (CLOSED 2026-01-14). Unstable historically accurate but bugs now closed. Warning stands.

### 3.5 · ⚠ — NGC catalog has tags nvcr.io/nvidia/vllm:25.12.post1 and 26.03-py3, and sglang:spark
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://catalog.ngc.nvidia.com/api/containers/images?orgName=nvidia&name=vllm&isPublic=true (2026-06-05)
- **Notes:** Re-verified via NGC public images API (200). nvidia/vllm tags 25.09-py3 through 26.05.post1-py3 including 25.12-py3, 25.12.post1-py3, 26.03-py3. So 25.12.post1 and 26.03-py3 BOTH EXIST. nvidia/sglang container also exists (API 200) with date-style tags only (25.10-py3 through 26.05-py3) - NO spark tag. The sglang:spark in the plan is the lmsysorg Docker Hub image, NOT an nvcr.io/NGC tag. vLLM tags fully confirmed; sglang-on-NGC exists but not under a spark tag. Warning stands.

### 3.6 · ✓ — Dre Dyson GB10 stack: client to LiteLLM(:14000) to llama-swap(:28080) to ephemeral vLLM; needs --network container:llama-swap; UMA CUDA doesn't immediately free memory after exit (30s-several min lag)
- **Verdict:** ✓ Confirmed
- **Evidence:** https://dredyson.com/how-i-mastered-running-a-full-multi-model-llm-stack-on-dgx-spark-gb10-advanced-litellm-llama-swap-vllm-llama-cpp-ollama-configuration-guide-with-dynamic-vram-orchestration-for-10-models/ (2026-06-05)
- **Notes:** Re-verified by fetch. Ports confirmed: LiteLLM on port 14000 and llama-swap on port 28080. Network: the model container must be inside llama-swap network namespace so that when it binds to 0.0.0.0:PORT, llama-swap can proxy at 127.0.0.1:PORT; --network container:llama-swap called the linchpin. UMA lag: After a previous model container exits, the CUDA memory allocator on the unified-memory GB10 doesn't immediately return all memory; vLLM startup check fails even though the previous container has been stopped for 30+ seconds. VERIFIER NOTE: teammate claimed the article caps at ~30s and the plan overstates with 30s-several minutes - that critique was itself slightly wrong. The article says 30+ seconds (open-ended, NOT a cap), so the plan upper bound is NOT contradicted. Confirmed stands.

### 3.7 · ⚠ — Gemma 4 26B-A4B NVFP4 as alternative; community images report 39-155 tok/s with DFlash speculative decoding; does Gemma 4 26B-A4B exist?
- **Verdict:** ⚠ Partial / caveated
- **Evidence:** https://huggingface.co/api/models/nvidia/Gemma-4-26B-A4B-NVFP4 (2026-06-05)
- **Notes:** Re-verified. Model EXISTS: nvidia/Gemma-4-26B-A4B-NVFP4 (HF API 200, tags gemma4/NVFP4, base_model google/gemma-4-26B-A4B-it, lastModified 2026-05-11) and base google/gemma-4-26B-A4B (HF API 200). THROUGHPUT: NO single authoritative source states 39-155 tok/s with DFlash verbatim. WebSearch surfaced community figures bracketing it: ai-muninn.com 52 tok/s NVFP4 baseline and 108 single-stream / 670 aggregate with MTP; sonusahani.com DFlash 40 tok/s; NVIDIA dev-forum 45 tok/s; H100 DFlash 306.4 tok/s. Heterogeneous, did not pin the exact range. Existence + NVFP4 CONFIRMED; 39-155 DFlash band loosely corroborated, not verbatim-verified. Warning stands.

## Method notes

curl HF model API (200=exists) and HF raw config.json for arch ground-truth (parsed text_config.layer_types, mamba_ssm_dtype, transformers_version=5.7.0.dev0); HF expand=safetensors for param totals (gpt-oss-120b=120,412,337,472; Qwen3.6 NVFP4=18,683,860,336 U8=16.4B). gh CLI for repo (sglang-dgx-spark 17 stars) and SGLang issue states (10089 closed 2025-11-18; 12567 closed 2026-01-14; 20774 = Hybrid Mamba+MoE). WebFetch: NVIDIA blog, sglang README (image tags, benign sm_121 warning, ~75 dual-Spark tok/s), LMSYS Nov-2025 blog (50/70 verbatim), Artificial Analysis (60.8GB/MXFP4/5.1B/117B verbatim), dredyson.com (ports 14000/28080, --network container:llama-swap, 30+ seconds UMA lag), HF Qwen3.6 card, vLLM recipes (gated-delta-networks MoE). NGC public images API enumerated nvidia/vllm and nvidia/sglang tags. WebSearch for Gemma 4 DFlash throughput. Could NOT verbatim-confirm the Gemma 4 39-155 tok/s DFlash band. verifier: 1 findings adjusted (finding 1 warning to confirmed; corrected dredyson UMA-lag note; others re-verified unchanged).
