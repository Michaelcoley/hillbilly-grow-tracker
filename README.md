# Hillbilly Monotub Grow Tracker

A single-file, dark-tactical web app for tracking three Hillbilly cubensis monotubs end-to-end — colonization through reflush — with cross-device sync via Supabase.

**Live demo:** https://michaelcoley.github.io/hillbilly-grow-tracker/

No build step. One `index.html`. Open it in a browser. State syncs through Supabase Realtime so the dashboard stays current across phone, tablet, and desktop.

---

## Features

- **Dashboard** — three live tub status cards, master phase timeline, running totals (flushes / wet / dry / contam), and active alerts driven by phase + age heuristics.
- **Tub Management** — per-tub detail with phase tracker, advance/back buttons, observations log, photo uploads to Supabase Storage, flush history with moisture-loss calc, and an Inkbird settings reference card (TS=77F, HD=1F, CD=1F, AH=85F, AL=70F).
- **Phase Guide** — six collapsible phases with step-by-step instructions, sandwich tek diagram (1 lb bottom buffer / mixed middle / 1 lb top cap), inventory snapshot (3 grain bags · 8 Boomr Bags · Myco Coco · 2 reserve), Boomr Bin automation hookup diagram (FAE Fan · Myco-Mister · Mycontroller probe), and a fruiting conditions card (74–76°F, 90–95% RH, 12 hr light).
- **Harvest Log** — log per-flush wet & dry weights and notes, auto-calculated moisture loss %, running totals per tub, and a yield bar chart per flush across all tubs.
- **Contamination Checker** — quick color reference (green/black/pink = bad, white/blue bruising = normal), 4-question decision tree (isolate vs continue vs terminate vs spot-treat), and a photo-backed event log.
- **Calendar View** — visual 6-phase timeline per tub with current-position marker and projected pin / harvest / reflush dates based on each tub's spawn-to-bulk date.
- **Real-time sync** — Supabase Realtime subscriptions on all five tables; another device's update reflects on yours instantly.
- **Offline support** — writes queue to `localStorage` when offline and flush automatically on reconnect; optimistic UI with rollback on error.
- **Photos** — uploaded to a public-read Supabase Storage bucket (`grow-photos`); URLs persist in the row.

---

## Setup

### 1. Create or reuse a Supabase project

1. Go to <https://supabase.com> and create a project (or use an existing one).
2. Wait for it to provision.

### 2. Run the schema

1. Open the project's **SQL Editor** → **New query**.
2. Paste the entire contents of [`schema.sql`](./schema.sql) and **Run**.
3. The script is idempotent — safe to re-run if you make changes.

`schema.sql` provisions:

- five tables: `tubs`, `phase_log`, `observations`, `harvests`, `contamination_events`
- a `touch_updated_at` trigger on `tubs`
- **RLS enabled** on every table, with four policies per table granting the `anon` role full read / insert / update / delete (the project anon key is required to reach any of them — public requests without the key are rejected by PostgREST)
- the `supabase_realtime` publication, with all five tables added so Realtime broadcasts changes
- a public-read `grow-photos` Storage bucket plus four `storage.objects` policies (public read, anon insert/update/delete scoped to that bucket)
- a seed insert of three tub rows so the dashboard renders on first load

### 3. Wire credentials into `index.html`

1. In Supabase: **Project Settings → API** → copy the **Project URL** and **anon public** key.
2. Open `index.html` and edit the constants near the top of the `<script>` block:

   ```js
   const SUPABASE_URL      = "https://YOUR-PROJECT.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...";
   const STORAGE_BUCKET    = "grow-photos";
   ```

3. Save. Reload the page. The sync pill in the top-right should turn green and read **Synced**.

---

## Deploying

Already deployed via GitHub Pages from the `main` branch root → <https://michaelcoley.github.io/hillbilly-grow-tracker/>.

To deploy your own fork: **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main` / root → Save.**

Because `index.html` is a single static file with no build step, that's the entire deploy.

---

## Security notes

This app uses **basic RLS** — every table grants the `anon` role full CRUD. Net effect:

- Anyone with the project's anon key can read and write all rows.
- Requests without the anon key (e.g., curl against the REST endpoint with no `apikey` header) are rejected by PostgREST.
- This is appropriate for a personal grow tracker. **Do not use this schema for multi-user data, anything sensitive, or anything you'd be unhappy seeing public if the URL leaks.**
- Treat the anon key as semi-private. If it leaks, rotate it from **Project Settings → API → Reset anon key**, then update `index.html`.
- Photos go into a public-read bucket — anyone with a URL can view them. Don't upload anything you wouldn't want public.

If you fork this repo: **never commit a populated `index.html` containing your URL + anon key to a public repo for a project you don't want random scraper traffic against.** A safer pattern is to keep credentials in a separate file ignored by git and read them at startup.

---

## File layout

```
hillbilly-grow-tracker/
├── index.html      # the entire app — HTML, CSS, JS, Supabase client via CDN
├── schema.sql      # tables + RLS + Realtime publication + storage bucket + storage policies
├── README.md       # this file
└── .gitignore      # excludes .env and other secrets
```

## Reference data hardcoded in the app

| Setting | Value |
| --- | --- |
| Strain | Hillbilly (P. cubensis) |
| Colonization temp | 77°F |
| Fruiting temp | 74–76°F |
| Humidity target | 90–95% |
| Expected colonization | 7–14 days |
| Expected pinning after flip | 5–14 days |
| Expected flushes | 3–5 |
| Spawn ratio | 1:2 (sandwich tek) |
| Inkbird | TS=77, HD=1, CD=1, AH=85, AL=70 |

## Phases tracked

1. Prep & Spawn to Bulk
2. Colonization
3. Casing & Fruiting Flip
4. Pinning & Fruiting
5. Harvest
6. Reflush
