# Operating Model

**Status:** draft, 2026-04-19

## Runtime topology

```
┌─────────────────────────────────────────────────────────────┐
│                       smarter.poker                         │
│                                                             │
│  Browser → Vercel Edge → {World Hub (Next.js) | CA SPA}    │
│                              │                              │
│                              ▼                              │
│                    Supabase (Postgres + Realtime + Auth)    │
│                              ▲                              │
│                              │                              │
│     Hetzner (game engine, scrapers, migrated crons) ◄──────┘
│                              │                              │
│                    Cloudflare R2 (assets, solver data)      │
└─────────────────────────────────────────────────────────────┘
```

## Repos and their roles

| Repo                         | Runtime  | Purpose                                       |
|------------------------------|----------|-----------------------------------------------|
| Smarter-Poker-World-Hub      | Vercel   | Next.js 14 Pages Router. Hub UI.              |
| Smarter-Poker-Club-Arena     | Vercel   | Vite + React SPA. Served at /hub/club-arena.  |
| smarter-poker-platform       | Hetzner  | Systemd units, runners, SQL, runbooks.        |

## Ownership rules

- Any SQL change is a numbered, committed migration in this repo BEFORE it is applied to prod.
- Any cron that runs more than once every 10 minutes belongs on Hetzner, not Vercel.
- Any persistent background worker (game engine, scrapers, solver) is a systemd service.
- Any endpoint that is user-facing is a Vercel route — this repo does not host HTTP.

## Where to find things

- Deployment credentials and env: 1Password vault smarter-poker-ops.
- Incident-time escalation: runbooks/INCIDENT-RESPONSE.md (to be written).
- Build/deploy pipelines: each app repo's .github/workflows/.
