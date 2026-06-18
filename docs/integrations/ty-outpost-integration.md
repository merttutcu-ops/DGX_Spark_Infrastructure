# Ty's Outpost ↔ Spark integration plan

> Cross-system note from Ty's side (added via PR for Mert's review). How Ty's always-on mini-PC **"Outposts"** connect to and borrow this DGX Spark. **Status: proposal — confirm the open questions before wiring.**

## TL;DR
Ty runs cheap, always-on mini-PC **Outposts** (headless agent runners) at his location. They have **no GPU** — instead they **borrow this Spark's local models** (the vLLM ports) for free heavy inference over a private **Tailscale** link, with the Anthropic API as a premium fallback. The Spark stays the shared GPU brain; the Outposts are cheap distributed workers.

## Topology
- **Ty's M5 Mac** (coming fall) — Ty's personal dev + control machine, *outside* the agents (mirrors Mert's Mac).
- **Ty's Outposts (1–3)** — mini PCs (BOSGAME / GMKtec, 16GB) running **Hermes** agents, headless, Telegram-controlled. First one (**"Outpost 1"**) is already live.
- **This DGX Spark** — Qwen3.6-35B-A3B resident (`:8001`) + GPT-OSS-120B on-demand (`:8002`) via vLLM; Mert's 8-agent studio.
- **Link** — a **Tailscale** tailnet between the Outposts and the Spark. The Spark exposes its vLLM endpoint (OpenAI-compatible) **on the tailnet only** — public egress stays deny-by-default; this is a tailnet-scoped ingress, locked by Tailscale ACLs. Each Outpost's Hermes model provider points at the Spark's vLLM endpoint; Anthropic = premium fallback.

## Framework alignment — DECISION NEEDED
Ty is standardizing his Outposts on **Hermes** (multi-agent verified; he's deploying first). This repo's scaffold is currently **OpenClaw** (Hermes is Phase 3 here). Options:
1. **Migrate the Spark scaffold to Hermes** — aligns both sides; Hermes imports OpenClaw configs and this repo already targets Hermes in Phase 3. *(Ty's lean.)*
2. **Keep OpenClaw on the Spark, Hermes on the Outposts, bridge via ACP** (OpenClaw↔Hermes Agent Communication Protocol).

Either way the **model-serving layer (vLLM) is framework-agnostic**, so Hermes Outposts can use this Spark's models regardless. Alignment matters for sharing agent workspaces / the task board — not for borrowing compute. **→ Mert to confirm the standard.**

## Capacity / contention
The forum-harvest in this repo flags that the 120B is slow to swap (~10 min) and a single Spark bottlenecks under heavy multi-user load. Ty + Mert are going **dual Spark** (2-pack + QSFP interconnect, ~$13.8k CAD) — clustering the two adds memory/throughput headroom to serve **both** Mert's studio **and** Ty's Outposts without the swap bottleneck. Still: agree a capacity split and **batch heavy 120B passes** (don't run the 120B per-task).

## Security (unchanged principles, both sides)
- Outposts stay credential-clean + isolated; human-gated for consequential actions; never connect banking / passwords / personal email — same safety model as this repo.
- The tailnet link exposes **only** the Spark's model ports, **only** to authorized devices (Tailscale ACLs). Deny-by-default egress on the Spark is unchanged.
- Worker identities scoped/disposable; no master secrets cross machines.

## Open questions for Mert
1. **Framework standard:** Hermes everywhere, or OpenClaw-on-Spark + Hermes-on-Outposts via ACP?
2. **Spark location + tailnet ACLs:** who/what may reach `:8001` / `:8002`?
3. **Capacity allocation:** how to split model serving between the studio and Ty's Outposts (especially the on-demand 120B)?
4. **Shared task board / agent-workspace conventions** if the Outposts ever join the same dispatch workflow.

---
*Authored from Ty's side. Ty's worker repo: `online-football-directory/openclaw-worker` (Outpost 1 / content-worker setup).*
