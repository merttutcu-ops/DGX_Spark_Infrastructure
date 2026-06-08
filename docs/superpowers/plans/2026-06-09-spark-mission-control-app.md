# Spark Mission Control App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the responsive, installable PWA + thin read/steer API that turns the "Spark Mission Control" design system into a real desktop+phone operator dashboard for the 8-agent DGX Spark.

**Architecture:** One Vite+React+TS PWA (served by the Spark, same-origin) talks to a thin FastAPI read/steer server bound to loopback; the phone and Mac reach it over a Tailscale `*.ts.net` HTTPS origin. All UI data flows through a `SparkDataSource` interface with a `MockSparkAdapter` (build now) and `RealSparkAdapter` (day-1 swap).

**Tech Stack:** Vite · React 18 · TypeScript (strict) · Vitest + Testing Library · vite-plugin-pwa (Workbox) · FastAPI (Python 3.11) · @simplewebauthn (WebAuthn) · Web Push (VAPID) · Tailscale Serve.

**Companion spec:** `docs/superpowers/specs/2026-06-09-spark-mission-control-app-design.md` (read it first — this plan implements it).

---

## How to read this plan (scope + conventions)

- **Build is deferred until hardware** (Mert's call). This is the plan you execute when the Spark lands — or earlier for the mock-data milestones (M0–M7), which need **no Spark**.
- **Two kinds of task:** (a) *buildable now on mock data* — real code, TDD, exact commands; (b) *day-1 on hardware* — an ops runbook with **verification gates** (not placeholders: each gate has a concrete command and an expected result). The unknown Spark API shapes are deliberately contracts-to-verify, not invented code.
- **Milestones are ordered and each is a working, testable increment.** M1 (vertical slice: shell + Flight Deck on mock data, installable) is the first thing you'll see running on a real phone.
- **Two locked-at-build-time choices** (recorded, low-stakes — confirm before M0):
  - **App location:** new `app/` dir in this repo (recommended — cohesion, day-1 `cd app`; scope new CI to `app/**`). Alt: separate `spark-mission-control` repo.
  - **Server language:** FastAPI/Python (this plan's concrete code — matches the Spark's Python side + your skills). Alt: Hono/TS for single-language; if chosen, M7 ports the same routes.
- **TDD throughout** for logic (adapters, the SSE watchdog, idempotency, server routes). For mechanical UI porting (screens already exist as JSX in the design export), tasks specify *what to compose + responsive changes + a render smoke test* and reference the existing source — that's concrete, not a placeholder.

---

## File structure (what gets created, and each file's one responsibility)

```
app/
  web/                                  # the PWA (Vite + React + TS)
    index.html                          # app entry; links manifest
    vite.config.ts                      # Vite + vite-plugin-pwa config
    tsconfig.json                       # strict TS
    package.json
    public/
      manifest.webmanifest              # installability
      icons/                            # PWA icons (from assets/logo-mark.svg)
    src/
      main.tsx                          # React root + adapter wiring
      App.tsx                           # router/view switch
      config.ts                         # ONE source of truth: base URL + which adapter + staleness N
      ds/                               # the design system, ported from the export
        tokens/                         # colors.css fonts.css typography.css spacing.css base.css (copied verbatim)
        styles.css                      # copied verbatim
        components/                     # Button, IconButton, Input, StatusPill, TierBadge, AgentCard,
                                        #   SwapStateMachine, MetricStat, Sparkline, Gauge, MemoryBar,
                                        #   DataTable, LogRow, ApprovalGateItem  (ported .tsx, typed)
      data/
        types.ts                        # Agent, Telemetry, SparkEvent, LogRow, CostSummary, NewTask...
        SparkDataSource.ts              # the interface (the seam)
        MockSparkAdapter.ts             # fixtures + scripted event stream (build-now)
        RealSparkAdapter.ts             # hits the thin API (day-1)
        sse.ts                          # EventSource client + iOS background-freeze watchdog
        steer.ts                        # idempotency keys + WebAuthn step-up wrapper
        useSparkData.tsx                # React context/hook exposing the active adapter
      shell/
        AppShell.tsx                    # chrome; desktop 3-pane vs phone layout
        Rail.tsx                        # desktop icon rail
        BottomNav.tsx                   # phone bottom tab bar
        Sidebar.tsx                     # agent roster (desktop static / phone drawer)
        TopBar.tsx                      # title, online pill, theme toggle, staleness indicator
      screens/
        FlightDeck.tsx Agents.tsx Comms.tsx Tasks.tsx Serving.tsx Cost.tsx Approvals.tsx Logs.tsx
      pwa/
        push.ts                         # subscribe to web-push, permission flow
    test/                               # Vitest setup + cross-cutting tests
  server/                               # the thin read/steer API (FastAPI)
    main.py                             # app, static-serve, route includes
    deps.py                             # auth (bearer + tailscale identity header), idempotency store
    routes_read.py                      # GET agents/telemetry/logs/cost
    routes_stream.py                    # SSE /stream
    routes_steer.py                     # POST approve/dispatch/halt (WebAuthn-gated, idempotent)
    webauthn.py                         # passkey register/verify
    push.py                             # VAPID web-push sender
    gateway_client.py                   # talks to OpenClaw gateway :18789 server-side (day-1)
    audit.py                            # append-only steer audit log
    fixtures.py                         # mock data for local dev (mirrors MockSparkAdapter)
    pyproject.toml / requirements.txt
    tests/                              # pytest
  README.md                             # how to run web + server locally, and the day-1 swap
```

---

## Milestone M0 — Scaffold the PWA (runs on mock data, no Spark)

### Task 1: Initialize the web app

**Files:** Create `app/web/` (Vite scaffold), `app/web/vite.config.ts`, `app/web/tsconfig.json`

- [ ] **Step 1: Scaffold**

```bash
cd app && npm create vite@latest web -- --template react-ts && cd web && npm i
npm i -D vitest @testing-library/react @testing-library/jest-dom jsdom
npm i -D vite-plugin-pwa
```

- [ ] **Step 2: Enable strict TS** — in `tsconfig.json` ensure `"strict": true`, `"noUncheckedIndexedAccess": true`.

- [ ] **Step 3: Configure Vitest** — add to `vite.config.ts`:

```ts
/// <reference types="vitest" />
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      manifest: false, // we ship our own public/manifest.webmanifest
      workbox: { navigateFallback: '/index.html' },
    }),
  ],
  test: { environment: 'jsdom', globals: true, setupFiles: './test/setup.ts' },
})
```

- [ ] **Step 4: Test setup** — Create `app/web/test/setup.ts`: `import '@testing-library/jest-dom'`

- [ ] **Step 5: Smoke test** — Create `app/web/src/App.test.tsx`:

```tsx
import { render, screen } from '@testing-library/react'
import App from './App'
test('app renders', () => { render(<App />); expect(screen.getByTestId('app-root')).toBeInTheDocument() })
```
Give `App.tsx`'s root a `data-testid="app-root"`.

- [ ] **Step 6: Run** — `npm test` → PASS. `npm run dev` → opens on `http://localhost:5173` (a secure context, so the service worker registers).

- [ ] **Step 7: Commit** — `git add app/web && git commit -m "feat(app): scaffold mission-control PWA (vite+react+ts+pwa)"`

### Task 2: Port the design system (tokens + components)

**Files:** Create `app/web/src/ds/tokens/*.css`, `app/web/src/ds/styles.css`, `app/web/src/ds/components/*.tsx`

- [ ] **Step 1: Copy tokens + styles verbatim** from the design export (`tokens/{colors,fonts,typography,spacing,base}.css`, `styles.css`) into `src/ds/`. Import them once in `main.tsx`.
- [ ] **Step 2: Load fonts** — add Inter + JetBrains Mono (self-host in `public/fonts/` or `@fontsource/inter` + `@fontsource/jetbrains-mono` to avoid a CDN dependency).
- [ ] **Step 3: Port one component as the pattern (StatusPill)** — convert `components/status/StatusPill.jsx` to typed `src/ds/components/StatusPill.tsx`. Render test:

```tsx
import { render, screen } from '@testing-library/react'
import { StatusPill } from './StatusPill'
test('StatusPill shows label + fixed-semantic color', () => {
  render(<StatusPill status="warn" label="Swapping" />)
  expect(screen.getByText('Swapping')).toBeInTheDocument()
})
```

- [ ] **Step 4: Port the rest** — repeat the JSX→TSX port for Button, IconButton, Input, TierBadge, AgentCard, SwapStateMachine, MetricStat, Sparkline, Gauge, MemoryBar, DataTable, LogRow, ApprovalGateItem (sources in the design export's `components/`). Each: add prop types, keep CSS-var styling, add a render smoke test. **Do not re-implement — port and type.**
- [ ] **Step 5: Run** — `npm test` → all PASS.
- [ ] **Step 6: Commit** — `git commit -am "feat(app): port design-system tokens + components to typed tsx"`

---

## Milestone M1 — The data seam + the first vertical slice (installable, on mock data)

### Task 3: Define the data contract (types + interface)

**Files:** Create `app/web/src/data/types.ts`, `app/web/src/data/SparkDataSource.ts`

- [ ] **Step 1: Types** — model the domain from the design fixtures (`AppShell.jsx` `AGENTS`):

```ts
export type Tier = 'cloud' | 'resident' | 'heavy'
export type Status = 'healthy' | 'warn' | 'blocked' | 'idle'
export interface Agent {
  id: string; name: string; role: string; tier: Tier; model: string; port: string
  status: Status; statusLabel: string; tps: number; spend: number
  ctx: number; ctxMax: number; task: string | null; spark: number[]
}
export interface Telemetry { memUsedGiB: number; memTotalGiB: number; fleetTps: number; spendToday: number; spendCap: number }
export type SparkEvent =
  | { kind: 'log'; row: LogRow }
  | { kind: 'agent'; agent: Agent }
  | { kind: 'telemetry'; telemetry: Telemetry }
  | { kind: 'heartbeat'; ts: number }
export interface LogRow { ts: number; tag: 'INF'|'WRN'|'ERR'|'DNY'|'OK'; agent: string; text: string }
export interface CostSummary { spendToday: number; cap: number; perAgent: { id: string; spend: number }[] }
export interface NewTask { title: string; agent: string; budgetTok: number }
```

- [ ] **Step 2: The interface (the seam)**:

```ts
import type { Agent, Telemetry, SparkEvent, LogRow, CostSummary, NewTask } from './types'
export interface SparkDataSource {
  getAgents(): Promise<Agent[]>
  getTelemetry(): Promise<Telemetry>
  getLogs(filter: 'all'|'warn'|'error'|'denied'): Promise<LogRow[]>
  getCost(): Promise<CostSummary>
  streamEvents(onEvent: (e: SparkEvent) => void): () => void  // returns unsubscribe
  approve(id: string, decision: 'approve'|'deny', idemKey: string): Promise<void>
  dispatch(task: NewTask, idemKey: string): Promise<void>
  halt(idemKey: string): Promise<void>  // reversible pause only
}
```

- [ ] **Step 3: Commit** — `git commit -am "feat(app): SparkDataSource contract + domain types"`

### Task 4: MockSparkAdapter (TDD)

**Files:** Create `app/web/src/data/MockSparkAdapter.ts`, `app/web/src/data/MockSparkAdapter.test.ts`

- [ ] **Step 1: Failing test**

```ts
import { MockSparkAdapter } from './MockSparkAdapter'
test('mock returns 8 agents across 3 tiers', async () => {
  const a = await new MockSparkAdapter().getAgents()
  expect(a).toHaveLength(8)
  expect(new Set(a.map(x => x.tier))).toEqual(new Set(['cloud','resident','heavy']))
})
test('streamEvents emits then unsubscribes cleanly', () => {
  const m = new MockSparkAdapter(); const seen: string[] = []
  const off = m.streamEvents(e => seen.push(e.kind)); off()
  expect(typeof off).toBe('function')
})
```

- [ ] **Step 2: Run → FAIL** (`MockSparkAdapter` not found).
- [ ] **Step 3: Implement** — port the 8-agent fixture from the design export's `AppShell.jsx`; `streamEvents` drives a `setInterval` emitting heartbeat+telemetry+occasional log events; `halt/approve/dispatch` resolve after a short delay and mutate in-memory state. Return an unsubscribe that clears the interval.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(app): MockSparkAdapter with scripted event stream (TDD)"`

### Task 5: useSparkData hook + config

**Files:** Create `app/web/src/config.ts`, `app/web/src/data/useSparkData.tsx`

- [ ] **Step 1: config** — the single source of truth:

```ts
export const CONFIG = {
  // Day-1: set to the frozen https://<machine>.<tailnet>.ts.net origin. Never a bare 100.x IP or http.
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? '',     // '' = same-origin (real), unused by mock
  useMock: import.meta.env.VITE_USE_MOCK !== 'false',       // default mock until day-1
  stalenessMs: 8000,                                        // SSE heartbeat staleness threshold (the "N")
} as const
```

- [ ] **Step 2: hook** — a React context that constructs `useMock ? new MockSparkAdapter() : new RealSparkAdapter(CONFIG.apiBaseUrl)` once and exposes it + a `stale` flag (wired in M2). Provide `useSpark()`.
- [ ] **Step 3: Render test** that a component under the provider can read `getAgents()`.
- [ ] **Step 4: Commit** — `git commit -am "feat(app): adapter provider + config seam (mock default)"`

### Task 6: App shell + responsive nav + Flight Deck (the vertical slice)

**Files:** Create `app/web/src/shell/{AppShell,Rail,BottomNav,Sidebar,TopBar}.tsx`, `app/web/src/screens/FlightDeck.tsx`

- [ ] **Step 1:** Port `AppShell.jsx`'s Rail/Sidebar/TopBar to TSX, reading nav from a typed `NAV` array. Keep the 8 nav items.
- [ ] **Step 2: Responsive** — add a `useMediaQuery('(max-width: 767px)')` hook. When phone: hide `Rail`, render `BottomNav` (same nav items, fixed bottom, `--rail`-style active state); render `Sidebar` as a drawer toggled from `TopBar`. When desktop: the designed 3-pane layout. Container uses CSS grid driven by `--rail-w`/`--sidebar-w` tokens.
- [ ] **Step 3:** Port `OverviewScreen.jsx` → `FlightDeck.tsx`: fleet MetricStat strip · 8 `AgentCard`s · resource `Gauge`s + `MemoryBar` · live `LogRow` tail. Data via `useSpark()`. On phone: metric strip → 2-up, agent cards → 1-column.
- [ ] **Step 4: Render smoke test** — Flight Deck under the provider shows 8 agent names + the fleet tok/s stat.
- [ ] **Step 5: Run** — `npm test` PASS; `npm run dev`, resize to phone width → bottom nav appears, cards stack.
- [ ] **Step 6: Commit** — `git commit -am "feat(app): responsive app shell + Flight Deck on mock data"`

### Task 7: Make it installable (manifest + icons)

**Files:** Create `app/web/public/manifest.webmanifest`, `app/web/public/icons/*`, edit `index.html`

- [ ] **Step 1: Icons** — render `assets/logo-mark.svg` to 192/512 PNG (maskable + any). Place in `public/icons/`.
- [ ] **Step 2: Manifest**

```json
{ "name": "Spark Mission Control", "short_name": "Mission Control",
  "start_url": "/", "display": "standalone", "background_color": "#0a0b0d", "theme_color": "#0a0b0d",
  "icons": [
    { "src": "/icons/icon-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any maskable" },
    { "src": "/icons/icon-512.png", "sizes": "512x512", "type": "image/png", "purpose": "any maskable" } ] }
```
Link it in `index.html`: `<link rel="manifest" href="/manifest.webmanifest">` + `<meta name="theme-color" content="#0a0b0d">` + iOS `apple-mobile-web-app-capable`.

- [ ] **Step 3: Build + verify** — `npm run build && npm run preview`; in Chrome DevTools → Application → Manifest shows installable; "Install" works on desktop.
- [ ] **Step 4: Commit** — `git commit -am "feat(app): PWA manifest + icons (installable)"`

> ✅ **End of M1 = a vertical slice you can install on your Mac now**, and on a phone once it's served over HTTPS (M8). Everything else is additive.

---

## Milestone M2 — The iOS SSE watchdog (load-bearing guard, TDD)

### Task 8: SSE client with background-freeze detection

**Files:** Create `app/web/src/data/sse.ts`, `app/web/src/data/sse.test.ts`

- [ ] **Step 1: Failing tests** (drive the state machine, not the network):

```ts
import { createSseClient } from './sse'
test('marks stale when no heartbeat within N ms', () => {
  let now = 0; const clock = () => now
  const c = createSseClient({ url: '/stream', stalenessMs: 1000, clock, connect: () => ({ close(){} , onMessage(){} }) })
  c.start(); now = 1500; expect(c.isStale()).toBe(true)
})
test('visibility regain forces reconnect', () => {
  let opens = 0
  const c = createSseClient({ url: '/stream', stalenessMs: 1000, clock: () => 0,
    connect: () => { opens++; return { close(){}, onMessage(){} } } })
  c.start(); c.onVisible(); expect(opens).toBe(2) // initial + forced reconnect
})
```

- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** — `createSseClient` wraps an injectable `connect` (real impl = `new EventSource(url)`). It: tracks last-event time; `isStale()` = `clock() - last > stalenessMs`; `onVisible()`/`onFocus()` **always close + reopen** (never trust `readyState`); exposes `onStale(cb)`. The real wiring in `useSparkData` registers `document.addEventListener('visibilitychange'...)` and `window.addEventListener('focus'...)`, and surfaces `stale` to `TopBar` (a visible "DATA STALE — reconnecting" indicator).
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Wire** — `RealSparkAdapter.streamEvents` uses `createSseClient`; `MockSparkAdapter` keeps its interval. `TopBar` shows the staleness indicator when `stale`.
- [ ] **Step 6: Commit** — `git commit -am "feat(app): SSE client + iOS background-freeze watchdog (TDD)"`

---

## Milestone M3 — Steer safety: idempotency + WebAuthn step-up (TDD)

### Task 9: Idempotency keys

**Files:** Create `app/web/src/data/steer.ts`, `app/web/src/data/steer.test.ts`

- [ ] **Step 1: Failing test**

```ts
import { newIdemKey } from './steer'
test('idem keys are unique per call', () => { expect(newIdemKey()).not.toBe(newIdemKey()) })
```

- [ ] **Step 2 → 4:** Implement `newIdemKey = () => crypto.randomUUID()`; run → PASS. Every steer call in the adapters generates one key and passes it through; the server dedupes (M7).
- [ ] **Step 5: Commit** — `git commit -am "feat(app): client idempotency keys for steer actions"`

### Task 10: WebAuthn step-up wrapper

**Files:** Edit `app/web/src/data/steer.ts`; Create `app/web/src/data/steer.webauthn.test.ts`

- [ ] **Step 1: Test** (mock `navigator.credentials.get`) that `withStepUp(fn)` calls WebAuthn then `fn`, and throws if assertion is cancelled.
- [ ] **Step 2 → 4:** Implement `withStepUp`: request a fresh assertion via `@simplewebauthn/browser` `startAuthentication()` against the server's challenge, attach the assertion to the steer request; on cancel/timeout, throw (UI shows "authentication required"). Wrap `approve/dispatch/halt` in `RealSparkAdapter` with `withStepUp`.
- [ ] **Step 5: Commit** — `git commit -am "feat(app): WebAuthn step-up wrapper for steer actions (TDD)"`

---

## Milestone M4 — The remaining 7 screens (port from the design export)

> Each screen already exists as JSX in the design export — these tasks port it to TSX, wire it to `useSpark()`, and add the phone layout. Each ends with a render smoke test + commit. Compose published components; don't re-implement.

### Task 11–17 (one per screen)

For **Agents** (`OpsScreens.jsx`→`Agents.tsx`), **Comms** (`CommsScreen.jsx`), **Tasks** (`TasksScreen.jsx`), **Serving** (`ServingScreen.jsx`), **Cost** (`CostScreen.jsx`), **Approvals** (`OpsScreens.jsx`→Approvals), **Logs** (`OpsScreens.jsx`→Logs):

- [ ] **Step 1:** Port the screen's layout, composing the relevant ported components (e.g. Agents = `SwapStateMachine` + sortable `DataTable`; Approvals = `ApprovalGateItem` queue; Logs = filterable `LogRow` list; Cost = spend-vs-cap + per-agent table; Serving = `MemoryBar` split + tier panels + swap lifecycle; Tasks = kanban; Comms = per-agent DM + all-hands).
- [ ] **Step 2:** Replace fixture reads with `useSpark()`; steer actions (approve/deny on Approvals, New Task on Tasks, budget-stop on Cost) call the adapter with `newIdemKey()` (and `withStepUp` is already wrapping them).
- [ ] **Step 3: Phone layout** — tables → stacked cards; multi-pane → single column with the agent drawer; kanban → horizontally scrollable columns.
- [ ] **Step 4:** Render smoke test (key element present) → PASS.
- [ ] **Step 5:** Commit `feat(app): <screen> screen (responsive, on mock data)`.

> ✅ **End of M4 = the full 8-screen app, responsive + installable, on mock data.** This is the complete front-end; only real data + network remain.

---

## Milestone M5 — Web push (front-end side)

### Task 18: Push subscription flow

**Files:** Create `app/web/src/pwa/push.ts`

- [ ] **Step 1:** `subscribeToPush()` — checks `Notification.permission`, on user gesture calls `registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: <VAPID public> })`, POSTs the subscription to `POST /push/subscribe`. (iOS: only works after Add-to-Home-Screen.)
- [ ] **Step 2:** A "Enable alerts" toggle in settings/topbar that calls it; handle denied permission with a clear message.
- [ ] **Step 3:** SW push handler (in the vite-plugin-pwa custom SW): `self.addEventListener('push', e => self.registration.showNotification(...))` + `notificationclick` → focus the app.
- [ ] **Step 4: Commit** — `git commit -am "feat(app): web-push subscription + SW notification handler"`

---

## Milestone M6 — The thin API server (FastAPI, mock-backed first)

> Build + test this **locally against fixtures** (no Spark). It serves the built PWA, so the whole app runs same-origin on `http://localhost:9000` in dev.

### Task 19: Server skeleton + static serve

**Files:** Create `app/server/main.py`, `app/server/pyproject.toml`, `app/server/tests/test_health.py`

- [ ] **Step 1: Failing test**

```python
from fastapi.testclient import TestClient
from main import app
def test_health():
    assert TestClient(app).get("/api/health").json() == {"ok": True}
```

- [ ] **Step 2: Implement** — FastAPI app; `GET /api/health`; mount the built PWA (`app/web/dist`) at `/` with `StaticFiles(html=True)`; bind **127.0.0.1 only** (`uvicorn main:app --host 127.0.0.1 --port 9000`).
- [ ] **Step 3 → 4:** `pip install fastapi uvicorn`; run pytest → PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(server): thin FastAPI skeleton, loopback bind, serves PWA"`

### Task 20: Read routes (fixture-backed)

**Files:** Create `app/server/routes_read.py`, `app/server/fixtures.py`, `app/server/tests/test_read.py`

- [ ] **Step 1: Tests** assert `GET /api/agents` returns 8 agents, `/api/telemetry`, `/api/logs?filter=warn`, `/api/cost` return the documented shapes (mirror `types.ts`).
- [ ] **Step 2: Implement** routes returning `fixtures.py` data (same 8 agents as the web mock — keep them identical so the contract is proven before real data).
- [ ] **Step 3:** Point the web app at it: `VITE_USE_MOCK=false VITE_API_BASE_URL=http://localhost:9000`, rebuild, confirm the UI renders from the server. (Same-origin in real deploy; localhost in dev.)
- [ ] **Step 4: Commit** — `git commit -am "feat(server): fixture-backed read routes matching the web contract"`

### Task 21: SSE stream

**Files:** Create `app/server/routes_stream.py`, `app/server/tests/test_stream.py`

- [ ] **Step 1: Test** that `GET /api/stream` returns `text/event-stream` and emits a heartbeat within N ms.
- [ ] **Step 2: Implement** a `StreamingResponse` emitting `heartbeat` + periodic `telemetry`/`log` events (fixture-driven now). Format: `data: {json}\n\n`.
- [ ] **Step 3: Commit** — `git commit -am "feat(server): SSE telemetry stream (fixture-driven)"`

### Task 22: Steer routes — WebAuthn-gated + idempotent + audited

**Files:** Create `app/server/routes_steer.py`, `app/server/webauthn.py`, `app/server/deps.py`, `app/server/audit.py`, `app/server/tests/test_steer.py`

- [ ] **Step 1: Tests**
  - `POST /api/halt` without a valid WebAuthn assertion → 401.
  - Same `Idempotency-Key` twice → single effect (second returns the cached result, no double-action).
  - A successful steer appends one line to the audit log with the identity + action + key.
- [ ] **Step 2: Implement**
  - `deps.py`: `require_bearer` (token from `OPENCLAW_GATEWAY_TOKEN`/config), `require_identity` (read `Tailscale-User-Login` header — **trustworthy only because we bind loopback**), an in-memory+disk idempotency store keyed by `Idempotency-Key`.
  - `webauthn.py`: `/api/webauthn/challenge` + `/api/webauthn/verify` using `@simplewebauthn`-equivalent (`webauthn` PyPI lib); register passkeys; verify assertion per steer.
  - `routes_steer.py`: `approve`, `dispatch`, `halt` — each requires bearer + identity + a fresh verified assertion + an idempotency key; performs the (mock now) action; appends to `audit.py`.
  - **`halt` is reversible** (pause flag) — it MUST NOT call any teardown/revoke path. Add a test asserting `halt` only toggles a pause flag.
- [ ] **Step 3 → 4:** pytest → PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat(server): steer routes — webauthn step-up, idempotent, audited, reversible halt"`

### Task 23: Web-push sender

**Files:** Create `app/server/push.py`, `app/server/tests/test_push.py`

- [ ] **Step 1:** `POST /api/push/subscribe` stores subscriptions; a `notify(event)` helper sends a VAPID web-push (`pywebpush`). Test the subscribe round-trip + that an `approval-needed` event triggers a send (mock the transport).
- [ ] **Step 2: Commit** — `git commit -am "feat(server): web-push subscribe + VAPID sender"`

---

## Milestone M7 — RealSparkAdapter (web side, against the real server contract)

### Task 24: Implement RealSparkAdapter

**Files:** Create `app/web/src/data/RealSparkAdapter.ts`, `app/web/src/data/RealSparkAdapter.test.ts`

- [ ] **Step 1: Tests** (mock `fetch`/`EventSource`) that each method hits the right path with the bearer header; steer methods send `Idempotency-Key` + the WebAuthn assertion; `streamEvents` uses `createSseClient`.
- [ ] **Step 2: Implement** against the M6 routes. Base URL from `CONFIG.apiBaseUrl` (same-origin in prod).
- [ ] **Step 3:** Full local end-to-end: `npm run build`, run the server on `:9000` serving `dist`, open `http://localhost:9000` → the real adapter drives the whole app from the server. Background a tab, confirm the staleness indicator + reconnect.
- [ ] **Step 4: Commit** — `git commit -am "feat(app): RealSparkAdapter wired to the thin API (local e2e green)"`

> ✅ **End of M7 = the entire app works end-to-end on your Mac against the thin server with fixtures.** Only the real Spark data sources + the network path remain — and those need the hardware.

---

## Milestone M8 — DAY-1 ON THE SPARK (ops runbook + verification gates)

> Do these **on the real hardware**. Each gate has a concrete command + expected result — none are placeholders. Do **not** hardcode topology before these confirm it.

### Task 25: Wire the server to real Spark data (verify-on-arrival)

**Files:** Edit `app/server/routes_read.py`, `app/server/gateway_client.py`, `app/server/routes_stream.py`

- [ ] **Gate A — gateway origin behavior** (spec §8): on the Spark, run `jq '.gateway.controlUi.allowedOrigins' /sandbox/.openclaw/openclaw.json`. If it still resets on reload (master-plan.md:59), confirm our thin-API design is unaffected (we never set a custom gateway origin). Expected: our server talks to the gateway as `http://127.0.0.1:18789` server-side; no custom origin needed.
- [ ] **Gate B — telemetry source:** `curl -s http://127.0.0.1:8001/metrics | head` and `:8002` — confirm the vLLM Prometheus shape; map the real fields (`vllm:...` gauges) to `Telemetry` in `gateway_client.py`. **These ports are proxied server-side only — never exposed to the phone.**
- [ ] **Gate C — agents/tasks/logs/cost:** confirm the real sources (`tasks/` queue files, `~/.openclaw/logs`, per-agent JSONL, Anthropic/LiteLLM usage). Implement `gateway_client.py` to read them; swap `fixtures.py` → real in the read routes behind a `USE_FIXTURES` flag.
- [ ] **Gate D — halt action:** confirm the reversible pause mechanism (e.g., `openclaw agent pause <id>` or the gateway's pause API) — and that it is distinct from `runbooks/kill-switch.md`'s teardown. Wire `halt` to the reversible path only. Re-run `test_steer.py`'s "halt only pauses" assertion against the real call (mocked).
- [ ] **Commit** per gate.

### Task 26: Stand up the network path

- [ ] **Step 1:** Install Tailscale on Mac, iPhone, Spark; enrol all three to your tailnet.
- [ ] **Step 2:** **Save the Tailnet Lock disablement secret to your password manager**, then enable Tailnet Lock.
- [ ] **Step 3:** ACL — restrict the thin-API port to only your two devices.
- [ ] **Step 4:** Run the server: `uvicorn main:app --host 127.0.0.1 --port 9000`. Then `tailscale serve --bg https / http://127.0.0.1:9000`. Verify: `tailscale serve status` shows `https://<machine>.<tailnet>.ts.net → 127.0.0.1:9000`. **`serve`, never `funnel`.**
- [ ] **Gate E — HTTPS + cert:** from the Mac browser open `https://<machine>.<tailnet>.ts.net` → padlock valid (real Let's Encrypt cert), app loads. From the iPhone (Tailscale **Always-On**) open the same URL → loads.

### Task 27: Lock the origin, swap the adapter, register passkeys, install

- [ ] **Step 1:** Set `CONFIG`/env: `VITE_USE_MOCK=false`, `VITE_API_BASE_URL=''` (same-origin). **Freeze** the `*.ts.net` origin as the one constant (rpId + base URL). Rebuild; redeploy `dist` (the server serves it).
- [ ] **Step 2:** Register a WebAuthn passkey on the Mac and iPhone against the `*.ts.net` rpId (Apple-ID synced; register once).
- [ ] **Gate F — steer step-up:** on the phone, tap Approve on a pending item → Face ID prompt appears → action succeeds → one audit-log line. Tap HALT → Face ID → agents pause (reversible); confirm it does **not** trigger teardown.
- [ ] **Step 3:** iPhone: Add-to-Home-Screen; grant push permission; confirm an `approval-needed` event delivers a push.
- [ ] **Gate G — the freeze guard, on real hardware:** open the installed PWA, send it to background 30s, return → telemetry shows "stale" then reconnects within N s. **This is the §7 guard proving itself on the device it was written for.**
- [ ] **Step 4:** Keep `scripts/06-ssh-tunnel-dashboard.sh` as the Mac-side fallback for the kill-switch path.
- [ ] **Commit** — `git commit -am "feat: day-1 Spark wiring — tailscale serve, real adapter, passkeys, push, verified on device"`

---

## Self-review (spec coverage)

- D1 PWA → M0–M1, M7. ✓  D2 Tailscale → M8/Task26. ✓  D3 thin-API-not-gateway → server is the only reachable surface; Gate A. ✓  D4 same-origin served by Spark → Task19 static-serve + Task27. ✓  D5 3-layer auth → Task22 (bearer+identity) + M3/Task27 (WebAuthn). ✓  D6 reversible HALT, Face-ID, teardown host-side → Task22 + Gate D + Gate F. ✓  D7 SSE + iOS watchdog → M2 + Gate G. ✓  D8 push → M5 + Task23 + Task27. ✓  D9 Mock→Real seam → Task3–5 + Task24. ✓
- §7 guards all have a task: watchdog (M2/Gate G), idempotency (Task9/Task22), thin-API (Gate A), serve-not-funnel (Task26), loopback bind (Task19), Tailnet-Lock secret (Task26), frozen origin (Task27). ✓
- Verify-on-arrival items → Gates A–G. ✓
- No fabricated Spark API code — real data wiring is gated behind concrete `curl`/`jq` confirmations. ✓

---

## Execution handoff

**Build is deferred until hardware** (your call), so there's nothing to dispatch now. When you're ready:

- **M0–M7 can be built any time** (no Spark needed) — start here for a head-start; you'll have the full app running on mock data on your Mac.
- **M8 happens on day-1** with the Spark.

When we start, two ways to run it (I'll re-surface this then):
1. **Subagent-driven (recommended)** — a fresh subagent per task, I review between tasks.
2. **Inline** — execute in-session with checkpoints.
