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
