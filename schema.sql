-- ============================================================================
-- Hillbilly Monotub Grow Tracker — Supabase Schema
-- ============================================================================
-- Run this entire file in Supabase Dashboard -> SQL Editor -> New query.
-- Safe to re-run: uses IF NOT EXISTS / DROP POLICY IF EXISTS guards.
-- ============================================================================

-- Required for uuid_generate_v4()
create extension if not exists "uuid-ossp";

-- ----------------------------------------------------------------------------
-- TABLES
-- ----------------------------------------------------------------------------

create table if not exists public.tubs (
    id uuid primary key default uuid_generate_v4(),
    tub_number int not null check (tub_number between 1 and 3),
    strain text not null default 'Hillbilly',
    inoculation_date timestamptz,
    current_phase int not null default 1 check (current_phase between 1 and 6),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create unique index if not exists tubs_tub_number_unique on public.tubs(tub_number);

create table if not exists public.phase_log (
    id uuid primary key default uuid_generate_v4(),
    tub_id uuid not null references public.tubs(id) on delete cascade,
    phase_number int not null,
    entered_at timestamptz not null default now(),
    notes text
);

create table if not exists public.observations (
    id uuid primary key default uuid_generate_v4(),
    tub_id uuid not null references public.tubs(id) on delete cascade,
    timestamp timestamptz not null default now(),
    note text,
    photo_url text
);

create table if not exists public.harvests (
    id uuid primary key default uuid_generate_v4(),
    tub_id uuid not null references public.tubs(id) on delete cascade,
    flush_number int not null,
    harvest_date timestamptz not null default now(),
    wet_weight_g numeric,
    dry_weight_g numeric,
    notes text,
    photo_url text
);

create table if not exists public.contamination_events (
    id uuid primary key default uuid_generate_v4(),
    tub_id uuid not null references public.tubs(id) on delete cascade,
    detected_at timestamptz not null default now(),
    type text check (type in ('green','black','pink','other')),
    action_taken text,
    photo_url text,
    notes text
);

-- Auto-bump updated_at on tubs row writes
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end$$;

drop trigger if exists tubs_touch_updated_at on public.tubs;
create trigger tubs_touch_updated_at
    before update on public.tubs
    for each row execute function public.touch_updated_at();

-- ----------------------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ----------------------------------------------------------------------------
-- This is a personal tool. We enable RLS on every table and grant the anon
-- role full CRUD. Net effect: anyone hitting the REST endpoint must present
-- the project's anon API key (the apikey header). Requests without that key
-- are rejected by PostgREST before policies are even evaluated.
--
-- Treat the anon key as semi-private. If it leaks, rotate it from
-- Supabase Dashboard -> Project Settings -> API.
-- ----------------------------------------------------------------------------

alter table public.tubs                  enable row level security;
alter table public.phase_log             enable row level security;
alter table public.observations          enable row level security;
alter table public.harvests              enable row level security;
alter table public.contamination_events  enable row level security;

-- tubs ---------------------------------------------------------------
drop policy if exists "Allow anon read access"   on public.tubs;
drop policy if exists "Allow anon write access"  on public.tubs;
drop policy if exists "Allow anon update access" on public.tubs;
drop policy if exists "Allow anon delete access" on public.tubs;

-- SELECT: lets the app fetch all tubs and subscribe to changes
create policy "Allow anon read access"   on public.tubs for select to anon using (true);
-- INSERT: lets the app create new tub rows (one per monotub)
create policy "Allow anon write access"  on public.tubs for insert to anon with check (true);
-- UPDATE: lets the app advance phases / edit metadata
create policy "Allow anon update access" on public.tubs for update to anon using (true) with check (true);
-- DELETE: lets the app remove a tub when a grow ends
create policy "Allow anon delete access" on public.tubs for delete to anon using (true);

-- phase_log ----------------------------------------------------------
drop policy if exists "Allow anon read access"   on public.phase_log;
drop policy if exists "Allow anon write access"  on public.phase_log;
drop policy if exists "Allow anon update access" on public.phase_log;
drop policy if exists "Allow anon delete access" on public.phase_log;

create policy "Allow anon read access"   on public.phase_log for select to anon using (true);
create policy "Allow anon write access"  on public.phase_log for insert to anon with check (true);
create policy "Allow anon update access" on public.phase_log for update to anon using (true) with check (true);
create policy "Allow anon delete access" on public.phase_log for delete to anon using (true);

-- observations -------------------------------------------------------
drop policy if exists "Allow anon read access"   on public.observations;
drop policy if exists "Allow anon write access"  on public.observations;
drop policy if exists "Allow anon update access" on public.observations;
drop policy if exists "Allow anon delete access" on public.observations;

create policy "Allow anon read access"   on public.observations for select to anon using (true);
create policy "Allow anon write access"  on public.observations for insert to anon with check (true);
create policy "Allow anon update access" on public.observations for update to anon using (true) with check (true);
create policy "Allow anon delete access" on public.observations for delete to anon using (true);

-- harvests -----------------------------------------------------------
drop policy if exists "Allow anon read access"   on public.harvests;
drop policy if exists "Allow anon write access"  on public.harvests;
drop policy if exists "Allow anon update access" on public.harvests;
drop policy if exists "Allow anon delete access" on public.harvests;

create policy "Allow anon read access"   on public.harvests for select to anon using (true);
create policy "Allow anon write access"  on public.harvests for insert to anon with check (true);
create policy "Allow anon update access" on public.harvests for update to anon using (true) with check (true);
create policy "Allow anon delete access" on public.harvests for delete to anon using (true);

-- contamination_events ----------------------------------------------
drop policy if exists "Allow anon read access"   on public.contamination_events;
drop policy if exists "Allow anon write access"  on public.contamination_events;
drop policy if exists "Allow anon update access" on public.contamination_events;
drop policy if exists "Allow anon delete access" on public.contamination_events;

create policy "Allow anon read access"   on public.contamination_events for select to anon using (true);
create policy "Allow anon write access"  on public.contamination_events for insert to anon with check (true);
create policy "Allow anon update access" on public.contamination_events for update to anon using (true) with check (true);
create policy "Allow anon delete access" on public.contamination_events for delete to anon using (true);

-- ----------------------------------------------------------------------------
-- REALTIME PUBLICATION
-- ----------------------------------------------------------------------------
-- Tables added to supabase_realtime broadcast change events. The app
-- subscribes to all of these so multiple devices stay in sync.
-- ----------------------------------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
        create publication supabase_realtime;
    end if;
end$$;

alter publication supabase_realtime add table public.tubs;
alter publication supabase_realtime add table public.phase_log;
alter publication supabase_realtime add table public.observations;
alter publication supabase_realtime add table public.harvests;
alter publication supabase_realtime add table public.contamination_events;

-- ----------------------------------------------------------------------------
-- STORAGE BUCKET: grow-photos
-- ----------------------------------------------------------------------------
-- Public-read bucket for photo uploads. Anyone can fetch image URLs;
-- only requests with the anon key can upload.
-- ----------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('grow-photos', 'grow-photos', true)
on conflict (id) do update set public = excluded.public;

-- Storage RLS policies on storage.objects, scoped to the grow-photos bucket
drop policy if exists "grow-photos public read"   on storage.objects;
drop policy if exists "grow-photos anon insert"   on storage.objects;
drop policy if exists "grow-photos anon update"   on storage.objects;
drop policy if exists "grow-photos anon delete"   on storage.objects;

-- Public can view photos (img tags work without auth headers)
create policy "grow-photos public read" on storage.objects
    for select to anon, authenticated
    using (bucket_id = 'grow-photos');

-- Anon (anyone with project anon key) can upload photos to this bucket
create policy "grow-photos anon insert" on storage.objects
    for insert to anon
    with check (bucket_id = 'grow-photos');

-- Anon can overwrite (e.g., replace a photo on a tub)
create policy "grow-photos anon update" on storage.objects
    for update to anon
    using (bucket_id = 'grow-photos')
    with check (bucket_id = 'grow-photos');

-- Anon can delete photos
create policy "grow-photos anon delete" on storage.objects
    for delete to anon
    using (bucket_id = 'grow-photos');

-- ----------------------------------------------------------------------------
-- SEED: three tub rows so the dashboard renders out of the box
-- ----------------------------------------------------------------------------
insert into public.tubs (tub_number, strain, current_phase)
values (1, 'Hillbilly', 1), (2, 'Hillbilly', 1), (3, 'Hillbilly', 1)
on conflict (tub_number) do nothing;
