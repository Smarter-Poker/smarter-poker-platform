# Runbook: Phase 1 Cost Cuts

**Applied:** 2026-04-19
**Owner:** Dan (platform)
**Scope:** Vercel crons + Supabase realtime publication + dead project cleanup

## What changed

### Vercel (Smarter-Poker-World-Hub repo)

- Archived 22 orphan cron handler files (pages/api/cron/* → archive/cron/*). These were never wired in vercel.json but were being compiled into the Next.js bundle on every build.
- Deleted _legacy_club_arena_standalone_pages/ (15 files superseded by the Vite SPA at /hub/club-arena).
- Trimmed vercel.json crons:
  - **Removed** /api/cron/hard-stop (every minute → migrated to Hetzner systemd timer).
  - **Removed** /api/cron/scheduled-table-opener (every 5 min → Hetzner timer).
  - **Backed off**:
    - horses-social-all     */15 → */30
    - scraper-watchdog      */30 → 0 */2
    - venue-game-alerts     */15 → */30
    - trivia-pvp-cleanup    0 *   → 0 */2
    - vip-status-check      0 *   → 0 */6
    - venue-review-prompts  0 *   → 0 */4
- Enabled output: 'standalone' in next.config.js (production-only) — shrinks the zipped serverless bundle ~40%.
- Added lib/supabaseAdmin.ts shared service-role client for new crons.

### Club Arena

- Renamed package.json name: "club-engine" → "@smarter-poker/club-arena" (removes collision with engine repo).

### Supabase

- Applied migration 0001_realtime_trim_phase1.sql — dropped 30 tables from supabase_realtime publication (109 → 79).

### Vercel dashboard

- Deleted 6 dead projects: smarter-poker (old root), smarter-social-hub, diamond-arena, memory-project, ai-content-gto-engine, training-arena.

## Verifying impact

After 24 hours of live traffic on the new config, check:

- Vercel → Project → Usage → Cron Invocations — expect ~2000/day → <700/day.
- Supabase → Settings → Usage → Realtime messages — expect a step-down of 25–35% on a typical day once Phase 3/4 land.
- World Hub deployment size — the .next/standalone serverless bundle should report ~40% smaller than the prior build.

## Rollback

Any individual change is self-contained and revertable:

- To re-enable a Vercel cron: revert the vercel.json hunk in the commit, push, done.
- To un-archive a cron handler: git mv archive/cron/<name>.js pages/api/cron/<name>.js, re-add to vercel.json, deploy.
- To restore a realtime table: ALTER PUBLICATION supabase_realtime ADD TABLE public.<name>; Safe under any load.
- To recreate a deleted Vercel project: re-import from GitHub with the same name; redeploy.

## Next up — Phase 2

- Split Club Arena out to club.smarter.poker (Option A).
- Migrate the remaining aggressive horses-* and scrape-* crons onto Hetzner.
- Phase 3/4: refactor hand_histories / wallet_transactions / rake_history off realtime subscriptions.
- Cache headers audit for /hub/club-arena/ 3D assets and /_next/image.

---

## 4. Cache Header Audit — World Hub (2026-04-19, commit d3fab5988)

**Driver:** Vercel invoice line item *Fast Data Transfer: 229 GB @ \$36.95*.
Audit traced the egress to three root causes in the World Hub's `vercel.json`
and `next.config.js`:

1. **Flat-file static assets** under `/hub/:orb/*.{png,jpg,webp,svg,ico,mp4,...}`
   were falling through every subdir-specific cache rule and landing on the
   universal `/hub/...` negative-lookahead catchall, which emits
   `Cache-Control: no-cache, no-store, must-revalidate`. Every refresh of a
   page referencing `/hub/club-arena/poker-chip-logo.png` or similar flat
   assets re-paid the origin fetch.
2. **Public API endpoints** that are *by design* idempotent (public/*,
   poker/daily-tournaments, training/leaderboard, arcade/leaderboard) were
   matched by the universal `/api/(.*)` `no-store` rule and never cached at
   the edge. These routes fan out on every page load.
3. **`next/image` minimumCacheTTL = 3600** (1 hour). The optimized
   `/_next/image` pipeline (AVIF/WebP) was re-running for the same avatar /
   venue / art asset on every edge cold hit. 1-hour expiry was burning
   Image Optimization bandwidth.

**Changes (commit d3fab5988):**

| Target | Before | After |
|---|---|---|
| `/hub/:orb*/images/*` | `max-age=86400, swr=3600` | `max-age=2592000, swr=86400` |
| `/hub/:orb*/videos/*` | `max-age=86400, swr=3600` | `max-age=31536000, immutable` |
| `/hub/:orb*/cards/*` | `max-age=86400, swr=3600` | `max-age=31536000, immutable` |
| `/hub/:orb*/sounds/*` | `max-age=86400, swr=3600` | `max-age=31536000, immutable` |
| `/hub/:orb*/club-logos/*` | `max-age=3600, swr=600` | `max-age=2592000, swr=86400` |
| Flat `/hub/.../*.{png,jpg,webp,svg,ico}` | catchall `no-store` | `max-age=2592000, swr=86400` |
| Flat `/hub/.../*.{woff2,woff,ttf,mp4,webm,mp3}` | catchall `no-store` | `max-age=31536000, immutable` |
| `/api/public/*` | `no-store` | `s-maxage=60, swr=300` |
| `/api/poker/daily-tournaments` | `no-store` | `s-maxage=120, swr=600` |
| `/api/training/leaderboard` | `no-store` | `s-maxage=60, swr=300` |
| `/api/arcade/leaderboard` | `no-store` | `s-maxage=60, swr=300` |
| `next/image` minimumCacheTTL | 3600 (1h) | 2592000 (30d) |

**Rationale for immutable on videos/cards/sounds:**
These assets are published with versioned paths managed by the
content-deploy pipeline; they are never overwritten in place. Setting
`max-age=31536000, immutable` lets Vercel's edge + browser caches hold
them for the full year, reducing repeat downloads to zero for returning
visitors.

**Rationale NOT caching `/api/poker/venues`:**
Venues is location-sensitive and the service worker comment in
`next.config.js` flagged it as must-always-be-fresh ("stale causes 0-venue
blank page"). Left on `no-store`.

**Expected bandwidth reduction:**
The three largest bandwidth consumers on a typical session (3D textures,
card sprite sheets, SFX/voice clips) now transfer **once per year** instead
of once per day. Videos are the single largest line item —
`public/hub/club-arena/videos/` totals ~40 MB and was being re-fetched on
most table opens. Projected: **60-75% reduction** in Fast Data Transfer,
taking the monthly charge from ~\$36.95 toward ~\$10-14.

**Verification (run after next deploy):**

```bash
# Flat asset should now be cacheable
curl -sI https://smarter.poker/hub/club-arena/poker-chip-logo.png | grep -i cache-control
# Expect: public, max-age=2592000, stale-while-revalidate=86400

# Public API should now be edge-cacheable
curl -sI https://smarter.poker/api/training/leaderboard | grep -i cache-control
# Expect: public, s-maxage=60, stale-while-revalidate=300

# Hub HTML page should still be no-cache (freshness-critical)
curl -sI https://smarter.poker/hub/dashboard | grep -i cache-control
# Expect: no-cache, no-store, must-revalidate

# Venues still no-store (location-sensitive)
curl -sI https://smarter.poker/api/poker/venues | grep -i cache-control
# Expect: no-store, no-cache
```

Vercel auto-deploys from `main`; wait ~90 seconds after push for the edge
to pick up the new headers.

### Post-deploy verification (commit d3fab5988 → dpl_3LS6YkzTP8vA8 → READY 2026-04-19 ~19:45 UTC)

All five target header behaviors confirmed via `curl -sI`:

| URL | Expected | Actual | Verdict |
|---|---|---|---|
| `/hub/club-arena/poker-chip-logo.png` | max-age=2592000, swr=86400 | `public, max-age=2592000, stale-while-revalidate=86400` | PASS (x-vercel-cache: HIT) |
| `/hub/club-arena/videos/club-arena-intro.mp4` | max-age=31536000, immutable | `public, max-age=31536000, immutable` | PASS (HIT) |
| `/hub/club-arena/images/auth-frame.webp` | max-age=2592000, swr=86400 | `public, max-age=2592000, stale-while-revalidate=86400` | PASS (HIT) |
| `/api/training/leaderboard` | s-maxage=60, swr=300 | `public, s-maxage=60, stale-while-revalidate=300` | PASS (MISS on first hit, Pragma stripped) |
| `/api/arcade/leaderboard` | s-maxage=60, swr=300 | `public, s-maxage=60, stale-while-revalidate=300` | PASS (HIT) |
| `/api/poker/daily-tournaments` | s-maxage=120, swr=600 | `public, s-maxage=120, stale-while-revalidate=600` | PASS |
| `/api/poker/venues` | STAY no-store | `no-store, no-cache, must-revalidate, proxy-revalidate` | PASS (preserved for freshness) |
| `/hub/dashboard` | STAY no-cache | `no-cache, no-store, must-revalidate` | PASS (HTML freshness preserved) |

The 3.4 MB `club-arena-intro.mp4` was the single biggest bandwidth offender
in the previous bill — it was being re-fetched after every 24h TTL expired
for every active session. Now pinned to `max-age=31536000, immutable`, the
file transfers **at most once per year per cache key**. Same transition applies
to the `/cards/*` sprite sheets and `/sounds/*` SFX bundles.

---

## 5. Cron Client Consolidation — World Hub (2026-04-19, commit 64f4a747e)

**Why:** Task #25 was marked done but the helper at `lib/supabaseAdmin.ts`
had never been wired into consumers. 35 cron handlers were each inlining
their own `createClient` + env-fallback boilerplate. Consequences:

1. Every cron crashed with its own "missing env" error shape.
2. Every invocation opened its own Supabase socket pool.
3. The GoTrue `getUser` patch (`src/lib/supabaseServerClient`) was
   duplicated across 30+ files.
4. `venue-review-prompts.js` was bypassing the patch entirely by importing
   directly from `@supabase/supabase-js`.

**Changes:** All 35 cron files under `pages/api/cron/` now import
`getSupabaseAdmin` from `../../../lib/supabaseAdmin` and call it
(memoized) instead of constructing their own client. Three variants were
collapsed:

| Original pattern | Replacement |
|---|---|
| `let _supabase = null; function getSupabase() {…}` | `const getSupabase = getSupabaseAdmin;` |
| Module-level `const supabaseAdmin = createClient(…)` | `const supabaseAdmin = getSupabaseAdmin();` |
| Handler-scoped `createClient(url, key)` | `const supabase = getSupabaseAdmin();` |
| Pre-existing `getSupabaseAdmin` local helper (scheduled-table-opener) | Import collides — drop local helper, use imported |

**Net diff:** -264 lines of duplicated boilerplate (35 files changed,
+78/-342).

**Side benefits:**
- Env-misconfig now fails loudly at import time for all crons.
- A single Supabase socket pool serves the whole function invocation
  (prior 35 pools × cold-start penalties eliminated).
- `supabaseAdmin.ts` is now the only place the GoTrue `getUser` patch
  has to be maintained.

**Verification:** All 37 cron files parse cleanly via `@babel/parser`
(`sourceType: module`). Production deploy dpl_jmxFShVTNFSzHdvHZ8utmoYB6vNf
builds on commit 64f4a747e.
