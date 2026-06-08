# Spark Mission Control — App Design (desktop + phone)

**Status:** design locked, **build deferred until hardware arrives** (deliberate — see Phasing).
**Date:** 2026-06-09
**Author:** Mert + Claude (brainstormed; connectivity researched + adversarially verified by an agent team).
**Relationship to repo:** this is the *front-end / operator-surface* design that pairs with the
`DGX_Spark_Infrastructure` backend. The repo's `docs/master-plan.md` defers a **custom dashboard to
Phase 2**; this document is the Phase-2 design, written ahead of the hardware so day-1 is a checklist.

> **One rule inherited from the design system:** *consistency is correctness.* Status colors have fixed
> meanings on every screen — green = healthy, amber = warn/approaching-cap/swapping, red =
> blocked/down/over-cap, steel-blue = info/idle. Break that and you've shipped a bug, not a style nit.

---

## 1. What we're building (and what we're not)

**Goal.** A single-operator "mission control" cockpit to **monitor and steer** 8 AI agents running on one
always-on home DGX Spark — usable from **both a Mac (desktop) and an iPhone (phone)**.

**The two halves that exist today, and the gap:**
- The **backend half** = this repo (`DGX_Spark_Infrastructure`): scripts, configs, agent personas,
  runbooks. It has **no app/UI code**; the dashboard at `127.0.0.1:18789` is the OpenClaw gateway, reached
  today only by an SSH tunnel from the Mac (`scripts/06-ssh-tunnel-dashboard.sh`).
- The **front-end half** = the "Spark Mission Control — Design System" export: tokens, 14 components, and 8
  designed screens. But it is a **desktop-only visual mockup** (fixed `1320×840`, `overflow:hidden`), runs
  on **fake fixture data**, and compiles JSX **in the browser with Babel** (a prototyping trick, not
  shippable).

**This design turns those two halves into one real, responsive, installable app**, wired to a clean data
seam so it runs on mock data now and on the real Spark on day-1.

**Non-goals (YAGNI):**
- No native iOS/Android build, no App Store, no Apple Developer account, no Tauri/Capacitor/React-Native
  wrapper. (The Tailscale path removes every reason to wrap — see §4.)
- No public internet exposure of anything. No port-forwarding on the home router.
- The app is **not** the authoritative kill-switch (see §6).
- Not deploying the front-end to Vercel/Netlify (see §5 — it would trip Chrome Local Network Access + add
  CORS). The Spark serves its own app.

---

## 2. Locked decisions (with the "why")

| # | Decision | Why |
|---|----------|-----|
| D1 | **Pure installable PWA**, responsive desktop+phone | One codebase, minimal tooling, no App Store/Xcode/$99 acct. A browser **cannot open an SSH/TCP socket**, so "the app SSHes in" was never possible; wrapping only buys raw-sockets/CORS-bypass that the Tailscale path makes unnecessary. |
| D2 | **Tailscale** (WireGuard mesh) + `tailscale serve`, **not SSH**, for both devices | iPhones kill background SSH tunnels; SSH could never be reliable on the phone. Tailscale = private mesh, **no router ports opened, nothing public** — matches the repo's deny-by-default / never-expose stance. `tailscale serve` provides a real browser-trusted `*.ts.net` HTTPS cert (required for PWA installability — see §5). **Already the repo's stated preference:** `master-plan.md:188` — *"Keep gateway on 127.0.0.1:18789. Never bind 0.0.0.0 on an untrusted network. **Prefer Tailscale Serve.**"* This design operationalizes that and extends it to the phone via the thin API + PWA. |
| D3 | Tailscale points at a **thin operator-owned API on its own loopback port**, **never the gateway `:18789` directly** | The OpenClaw gateway enforces an **exact-origin** allow-list and **re-normalizes it back to `http://127.0.0.1:18789` on every config reload** (`master-plan.md:59`) — a recurring landmine that would silently break the phone. Fronting it with our own server sidesteps the trap permanently. |
| D4 | **Served by the Spark** (same origin as API) | Zero CORS, automatic secure context, no mixed-content. A Vercel-hosted page → `100.x` Spark would trip Chrome **Local Network Access** and add a CORS surface (so "flip to Vercel later" is **not** a free swap). |
| D5 | **3-layer auth**: tailnet ACL + Tailnet Lock → bearer token → WebAuthn step-up | Network gate is the real protection (only your enrolled devices can reach the port). Bearer token is low-value (a PWA has no secure element to store it). **WebAuthn/Face ID** gates every *steer* action. |
| D6 | **One-tap HALT from phone, reversible, Face-ID gated**; irreversible teardown stays Mac/SSH-only | Emergencies happen when you're away (phone-only). But the phone is the most-lost/stolen device, and `rollout-phases.md` says never hand the kill-switch to remote surfaces. So: phone can *pause* (reversible); revoke-keys/teardown stays host-side. |
| D7 | **SSE** for live telemetry + a **mandatory iOS background-freeze watchdog** | SSE is simpler than WebSocket (one-way). But on iOS 18 a backgrounded PWA's `EventSource` **dies silently** (no error event, `readyState` lies `OPEN`), so the dashboard would show **stale data that looks live** — dangerous when steering. Mitigation is not optional (see §7). |
| D8 | **Web push** for approvals/warnings | Always-on system you're not staring at; push tells you when an agent is blocked on your approval or a cap is breached. iOS 16.4+ but only after Add-to-Home-Screen + permission grant. |
| D9 | **Mock → Real adapter seam** | Pre-hardware we can't touch the Spark, so build against `MockSparkAdapter`; day-1 swap to `RealSparkAdapter` (one config line). Mirrors the repo's "build ahead of hardware" philosophy. |

---

## 3. Architecture (one screen)

```
  YOUR DEVICES            TAILSCALE  (private WireGuard mesh — only your enrolled devices)     YOUR HOME
 ┌────────────┐                                                                    ┌──────────────────────────┐
 │  Mac (PWA) │──┐                                                                 │        DGX Spark         │
 └────────────┘  │     https://spark.<tailnet>.ts.net   ← one real HTTPS URL       │                          │
 ┌────────────┐  ├──────────────────────────────────────  (Let's Encrypt cert) ─► │  `tailscale serve`       │
 │ iPhone(PWA)│──┘            ACL: only Mert's devices may reach the port          │       │                  │
 └────────────┘                                                                    │       ▼  127.0.0.1:9000  │
                                                                                   │  THIN read/steer API     │ ← we build this
                                                                                   │   • serves the PWA static│   (one small server,
                                                                                   │     files (same origin)  │    loopback-only)
                                                                                   │   • GET  read endpoints  │
                                                                                   │   • POST steer (WebAuthn)│
                                                                                   │   • SSE  telemetry stream│
                                                                                   │       │ (talks server-   │
                                                                                   │       ▼  side as 127.x)  │
                                                                                   │  OpenClaw gateway :18789 │
                                                                                   │  vLLM :8001 / :8002      │ ← NEVER exposed to phone
                                                                                   │  logs / queue / cost     │
                                                                                   └──────────────────────────┘
```

**Why the thin API exists** (it's the keystone): it (a) sidesteps the gateway's exact-origin landmine
[D3], (b) gives the PWA a single same-origin HTTPS host [D4], (c) is the **only** thing the phone can
reach — the raw model ports `:8001/:8002` and the gateway stay invisible, (d) binds **loopback-only**,
which is load-bearing for audit-log integrity (Tailscale identity headers are only trustworthy on a
loopback listener; a future "bind `0.0.0.0` for convenience" would silently make the audit log forgeable).

---

## 4. Components

### 4.1 PWA front-end (`web/`)
- **Stack:** Vite + React + TypeScript (strict mode; prefer `unknown` over `any`). Replaces the
  CDN/Babel prototype with a real build.
- **Design system:** copy `tokens/*.css` + `styles.css` verbatim (they're CSS-variable based and already
  theme-aware), and **port** the published primitives into typed `.tsx` (Button, IconButton, Input,
  StatusPill, TierBadge, AgentCard, SwapStateMachine, MetricStat, Sparkline, Gauge, MemoryBar, DataTable,
  LogRow, ApprovalGateItem). *Compose* these — don't re-implement (per the design system's SKILL.md).
- **Screens (8):** Flight Deck (overview), Agents, Comms, Tasks, Serving, Cost, Approvals, Logs.
- **Responsive strategy (the bulk of the "phone app" work):**
  - Desktop (≥1024px): the designed 3-pane layout (icon rail · agent sidebar · content).
  - Phone (<768px): icon rail → **bottom tab bar**; agent sidebar → **slide-over drawer**; dense
    `DataTable` rows → **stacked cards**; multi-column metric strips → 2-up / 1-up; topbar collapses.
  - Use CSS media/container queries over the existing tokens (rail/sidebar widths are already vars:
    `--rail-w`, `--sidebar-w`). Numerics keep the mono/tabular treatment at every size.
- **Installability:** `manifest.webmanifest` (name, icons from `assets/logo-mark.svg`, `display:
  standalone`, theme color = `--gray-0`) + a service worker (via `vite-plugin-pwa`/Workbox or a minimal
  hand-rolled SW). App shell cached for offline-open; data always live.
- **Data access:** everything goes through a `SparkDataSource` interface (see §4.4). No screen talks to
  `fetch` directly.

### 4.2 Thin read/steer API (`server/`)
- **One small server, loopback-bound.** Recommended: **FastAPI (Python)** — matches the Spark's
  Python/infra side, the vLLM `/metrics` and OpenClaw log ecosystem, and your existing Python skills
  (heimdall). Single-language alternative: **Hono/Express (Node/TS)** to share the language with the
  front-end. *(Low-stakes; finalize at build time. Marked as an open choice below.)*
- **READ (GET):** agent/task status (from `tasks/` queue), telemetry (proxy vLLM `:8001/:8002` Prometheus
  `/metrics` **server-side only**), recent logs (`~/.openclaw/logs` + per-agent JSONL), cost
  (Anthropic/LiteLLM usage).
- **STEER (POST, behind WebAuthn step-up):** approve/deny an approval-gate item, dispatch a task,
  budget-stop, and **HALT** (reversible pause). All steer POSTs are **idempotent** (client-generated
  idempotency key) because iOS can cut a POST mid-flight when the PWA backgrounds.
- **SSE (`GET /stream`):** one-way telemetry/log/agent-status events.
- **Also serves the PWA's static build** (same origin → D4).
- **Audit log:** every steer action recorded with the Tailscale identity header (trustworthy only because
  the listener is loopback-only).
- **Does NOT own the authoritative kill-switch** (`plan-review.md:127–136`, Improvement 3: *"Build a thin
  dispatcher you fully control for the high-trust path only… Never let third-party code own the
  kill-switch"* — and it's *"a Phase-2 decision"*; plus `rollout-phases.md:38`). The HALT endpoint performs
  a *reversible* pause; it cannot revoke keys or tear down.

### 4.3 Network + auth
- **Tailscale** on Mac, iPhone, Spark. `tailscale serve https / http://127.0.0.1:9000` (the thin API).
  **`serve`, never `funnel`** (funnel is public). Phone: prefer **Always-On** Tailscale over the fragile
  on-demand "detect MagicDNS hostnames" mode; add a first-load retry for the tunnel cold-start race.
- **ACL:** only Mert's enrolled devices may reach the thin-API port.
- **Tailnet Lock: ON** — but **store the disablement secret off-device (password manager) BEFORE
  enabling** (losing it + both devices = locked out of your own tailnet → "access you can lose").
- **WebAuthn passkey** step-up on every steer action. Pin **one canonical `*.ts.net` rpId** on both
  devices; on Apple devices the passkey iCloud-syncs (register once). Binding is to the Apple-ID keychain,
  not one physical phone's secure element.
- **CSP / no-`eval` / trusted-types** XSS posture on the dashboard (same origin serves static files *and*
  the steer API, so XSS hygiene is load-bearing).

### 4.4 The data seam (`SparkDataSource`)
```ts
interface SparkDataSource {
  getAgents(): Promise<Agent[]>;
  getTelemetry(): Promise<Telemetry>;
  streamEvents(onEvent: (e: SparkEvent) => void): () => void; // returns unsubscribe
  getLogs(filter: LogFilter): Promise<LogRow[]>;
  getCost(): Promise<CostSummary>;
  // steer (each requires a fresh WebAuthn assertion + idempotency key):
  approve(id: string, decision: 'approve' | 'deny', key: string): Promise<void>;
  dispatch(task: NewTask, key: string): Promise<void>;
  halt(key: string): Promise<void>; // reversible pause only
}
```
- `MockSparkAdapter` — drives the UI from the design system's existing fixtures (the 8 agents, fake
  telemetry, a scripted event stream). **All work pre-hardware uses this.**
- `RealSparkAdapter` — same interface, hits the thin API over the `*.ts.net` origin. **Day-1 swap.**

---

## 5. The iOS/PWA reality (verified, do-not-skip)

1. **A PWA cannot SSH or open raw sockets** — it speaks HTTPS + SSE/WebSocket to a hostname. The Spark
   *must* expose an HTTP(S) endpoint; this is why the thin API exists, not an SSH client in the app.
2. **Installed PWAs require a secure context (HTTPS)** except `http://localhost`. So a phone hitting a bare
   `http://100.x` Spark would **fail to register the service worker** → not installable. `tailscale serve`'s
   real `*.ts.net` cert is what makes it work. **The PWA must ONLY ever load over the `https://…ts.net`
   origin — never a bare `100.x` IP or plain `http`.** Freeze that origin as one config constant.
3. **Same-origin (D4)** avoids Chrome Local Network Access prompts (no public→private hop) and CORS. iOS
   Safari doesn't implement Chrome LNA, so it's moot there — but Android/desktop Chrome users would hit it
   with a cross-origin host.
4. **Pre-hardware dev** serves the identical build from `http://localhost` (a secure context, so the SW
   registers) against `MockSparkAdapter`.

---

## 6. Security model (deny-by-default, matching the repo)

- **Layer 1 — network gate (primary):** tailnet + ACL → only your devices can reach the port. Tailnet
  Lock prevents a stolen Tailscale account from enrolling a rogue device.
- **Layer 2 — app token (secondary, low-value):** the gateway bearer token for read. Treated as low-value
  (no secure element in a PWA); the tailnet gate is the real guard.
- **Layer 3 — steer step-up:** WebAuthn/Face ID on every steer action.
- **Kill-switch [D6]:** phone HALT = reversible pause, Face-ID gated. The authoritative kill
  (`openclaw gateway restart` / `nemoclaw stop` / `docker stop` / revoke keys — `runbooks/kill-switch.md`)
  stays host-side. The phone can at most enqueue a fail-safe stop task.
- **Never exposed to the phone:** raw model ports `:8001/:8002`, the gateway `:18789`, the authoritative
  kill-switch.
- **Lost/stolen phone:** revoke the Tailscale device + rotate the bearer token; passkeys are Apple-ID
  bound, not device-bound, so a wiped phone loses nothing the attacker can use over a revoked tailnet.

---

## 7. Mandatory implementation guards (the adversarial pass caught these)

These are **requirements, not nice-to-haves** — each is a silent-failure trap:

- **iOS SSE freeze watchdog.** On `visibilitychange`/`focus`, force-close and reopen the `EventSource`;
  run an app-level heartbeat-staleness check (no event in N seconds ⇒ treat as dead, reconnect, **visibly
  mark data stale**). Never trust `readyState` on iOS. *Without this, the phone shows frozen telemetry that
  looks live.*
- **Idempotent steer POSTs.** Client-generated idempotency key on every POST; server dedupes. *iOS can cut
  a POST mid-action on backgrounding → without this, a double-tap or auto-retry double-approves.*
- **Thin API, not the gateway.** `tailscale serve` → `127.0.0.1:9000` (thin API), which calls the gateway
  server-side. *Pointing at `:18789` directly re-trips the exact-origin reset every config reload.*
- **`serve`, not `funnel`.** Funnel is public exposure — forbidden.
- **Loopback-only bind** for the thin API (audit-log integrity).
- **Tailnet Lock secret saved off-device before enabling.**
- **One frozen `*.ts.net` origin constant** for rpId + base URL (changing it later re-breaks passkeys +
  installability).

---

## 8. Phasing — what happens, and when

**Now (pre-hardware): nothing is built/run.** This document + the day-1 plan are the deliverable. (Building
the app now is possible on mock data, but Mert chose to hold until hardware — safer, and the "zero-code Mac
shortcut" below needs the Spark running anyway.)

**Optional head-start (only if desired later, on mock data):** scaffold `web/` + `server/` against
`MockSparkAdapter`; build the responsive PWA + WebAuthn + SSE-with-watchdog; everything behind the adapter
seam. No Spark required.

**Day-1 on the real Spark (≈ an afternoon):**
1. Install Tailscale on Mac, iPhone, Spark; enrol all three.
2. Set the ACL (only your devices → thin-API port); **save the Tailnet Lock disablement secret**, then
   enable Tailnet Lock.
3. Stand up the thin API on `127.0.0.1:9000`; `tailscale serve https / http://127.0.0.1:9000`.
4. Swap `MockSparkAdapter` → `RealSparkAdapter`; set the one `*.ts.net` base-URL constant.
5. Register passkeys on both devices against the `*.ts.net` rpId.
6. Add-to-Home-Screen on the phone; grant push permission.
7. Keep `scripts/06-ssh-tunnel-dashboard.sh` as the Mac-side manual fallback for the kill-switch path.

**Verify-on-arrival (TODO — don't assume):**
- Confirm the installed OpenClaw build still has the exact-origin / `allowedOrigins`-reset behavior
  (`master-plan.md:59` says closed by 2026-03-20 — our thin-API design sidesteps it regardless, but
  confirm).
- Check OpenClaw #30990 (Control-UI hardcoded to `127.0.0.1` in some versions).
- One reviewer claimed OpenClaw can natively "serve over Tailscale with identity-header auth" in ~3 config
  lines (zero custom code). **Could NOT be verified** — the repo's gateway uses a **bearer token +
  exact-origin check**, not tailnet-identity-header auth. If your installed version has it, the Mac path
  could be even simpler; **verify before relying on it** (per your CLAUDE.md: don't trust unverified
  external claims).
- Do **not** hardcode any Spark topology now — every address stays a `TODO(verify-on-arrival)` placeholder.

---

## 9. Open decisions to finalize at build time
- **Thin-API language:** FastAPI (Python, recommended — matches the Spark side & your skills) vs Hono/Express
  (Node/TS, single-language with the front-end). Low stakes.
- **Service worker tooling:** `vite-plugin-pwa` (Workbox, batteries-included) vs a minimal hand-rolled SW
  (fewer deps, more control). Lean `vite-plugin-pwa` unless dependency-minimalism wins.
- **Push backend:** Web Push + VAPID keys live in the thin API; confirm which events warrant a push
  (approval-needed, over-cap, agent-blocked) to avoid notification fatigue.

## 10. Testing approach (for the build phase)
- Unit-test the `MockSparkAdapter` and the SSE watchdog state machine (simulate background→foreground).
- Test idempotency: replay a steer POST with the same key ⇒ single effect.
- Responsive snapshot checks at desktop / tablet / phone widths.
- Real-device smoke: install on an actual iPhone, background the app, confirm telemetry reconnects and
  marks staleness; confirm a steer action demands Face ID.

---

*Provenance: connectivity + packaging researched by a 4-angle agent team (repo security model · network
paths · PWA/browser limits · threat model), synthesized, and pressure-tested by a 3-lens adversarial pass
(technical feasibility · security soundness · learnability). Confidence: high. The §7 guards and the D3
thin-API correction are direct results of that adversarial pass.*
