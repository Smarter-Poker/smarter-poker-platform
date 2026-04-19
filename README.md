# smarter-poker-platform

Meta-repo for smarter.poker infrastructure. Home for everything that **isn't** a Vercel app:

- Hetzner systemd units and timers (migrated crons, game engine workers, scrapers)
- Cron runner scripts invoked by those timers
- SQL migrations applied directly to the Supabase Postgres (audit record of what ran when)
- Deployment scripts for pushing to Hetzner
- Runbooks and docs for on-call and platform work

## Layout

```
scripts/            # Bash runners invoked by systemd timers on Hetzner
systemd/            # .service and .timer units copied to /etc/systemd/system/
sql-migrations/     # Numbered Postgres migrations — applied via Supabase MCP or psql
runbooks/           # Step-by-step ops runbooks (Phase cut-overs, incident response)
docs/               # Architecture docs, operating model, decision log
```

## Why this repo exists

Smarter.poker is split across three runtimes:

1. **Vercel** hosts the World Hub (Next.js 14 Pages Router) and the Club Arena SPA.
2. **Hetzner** (4× CAX nodes) runs the authoritative poker engine, long-running jobs, and the scrapers that don't belong on serverless.
3. **Supabase** (Pro tier) is the system-of-record for state, realtime, auth, storage.

The Vercel repos (Smarter-Poker-World-Hub, club-arena) each hold app code plus vercel.json. But the Hetzner side had no home — systemd units lived in SSH-only scratch files, SQL migrations were pasted into the Supabase dashboard with no history, and runbooks lived in Notion. **That's what this repo fixes.**

## Bootstrap on a fresh Hetzner node

```bash
cd /opt
sudo git clone https://github.com/Smarter-Poker/smarter-poker-platform.git
cd smarter-poker-platform
sudo ./scripts/install-systemd-units.sh
```

See `runbooks/HETZNER-BOOTSTRAP.md` for the full sequence.

## Applying SQL migrations

sql-migrations/ is append-only. Every file is idempotent when safely re-runnable (guarded with IF NOT EXISTS / IF EXISTS) and annotated with the date it was applied in prod. Apply with either:

- The Supabase MCP apply_migration tool (preferred — records in Supabase migration log).
- Direct psql from a Hetzner node using the pooler connection string.

Never rewrite a committed migration file after it has been applied. Add a new numbered migration to reverse or amend.
