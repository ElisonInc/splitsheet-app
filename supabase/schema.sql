-- SplitSheet Database Schema
-- Run this in your Supabase SQL Editor

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Drop existing tables if you want a fresh start (optional - remove these lines if you want to keep existing data)
-- DROP TABLE IF EXISTS public.collaborators CASCADE;
-- DROP TABLE IF EXISTS public.sessions CASCADE;

-- Sessions table: Stores the main split sheet sessions
create table if not exists public.sessions (
  id text primary key,
  song_title text default '',
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  finalized boolean default false not null,
  finalized_at timestamp with time zone,
  hash text,
  created_by uuid references auth.users(id) on delete set null
);

-- Collaborators table: Stores writer information and splits
create table if not exists public.collaborators (
  id uuid default gen_random_uuid() primary key,
  session_id text references public.sessions(id) on delete cascade not null,
  legal_name text,
  email text,
  pro_affiliation text default 'ASCAP',
  ipi_number text,
  contribution text default 'Both',
  percentage integer default 0 check (percentage >= 0 and percentage <= 100),
  signature_data text,
  signed_at timestamp with time zone,
  is_creator boolean default false not null,
  device_id text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique(session_id, device_id)
);

-- Indexes for performance
create index if not exists idx_collaborators_session on public.collaborators(session_id);
create index if not exists idx_collaborators_device on public.collaborators(device_id);
create index if not exists idx_sessions_finalized on public.sessions(finalized);

-- Enable Realtime for live collaboration (safe version)
do $$
begin
  -- Try to add sessions table to realtime
  begin
    alter publication supabase_realtime add table public.sessions;
  exception when duplicate_object then
    -- Table already in publication, ignore
    null;
  end;
  
  -- Try to add collaborators table to realtime
  begin
    alter publication supabase_realtime add table public.collaborators;
  exception when duplicate_object then
    -- Table already in publication, ignore
    null;
  end;
end $$;

-- Row Level Security (RLS) Policies
-- These are basic policies - customize for your security needs

alter table public.sessions enable row level security;
alter table public.collaborators enable row level security;

-- Drop existing policies if they exist (to avoid conflicts)
drop policy if exists "Allow public read access to sessions" on public.sessions;
drop policy if exists "Allow public insert to sessions" on public.sessions;
drop policy if exists "Allow public update to sessions" on public.sessions;
drop policy if exists "Allow all" on public.sessions;
drop policy if exists "Allow public read access to collaborators" on public.collaborators;
drop policy if exists "Allow public insert to collaborators" on public.collaborators;
drop policy if exists "Allow public update to collaborators" on public.collaborators;
drop policy if exists "Allow public delete from collaborators" on public.collaborators;
drop policy if exists "Allow all" on public.collaborators;

-- Sessions policies
create policy "Allow public read access to sessions"
  on public.sessions for select
  using (true);

create policy "Allow public insert to sessions"
  on public.sessions for insert
  with check (true);

create policy "Allow public update to sessions"
  on public.sessions for update
  using (true);

-- Collaborators policies
create policy "Allow public read access to collaborators"
  on public.collaborators for select
  using (true);

create policy "Allow public insert to collaborators"
  on public.collaborators for insert
  with check (true);

create policy "Allow public update to collaborators"
  on public.collaborators for update
  using (true);

create policy "Allow public delete from collaborators"
  on public.collaborators for delete
  using (true);

-- Function to update the updated_at timestamp
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql security definer;

-- Drop existing trigger if exists
drop trigger if exists on_collaborator_updated on public.collaborators;

-- Trigger to auto-update updated_at
create trigger on_collaborator_updated
  before update on public.collaborators
  for each row
  execute procedure public.handle_updated_at();

-- View to get session summary with collaborator count
drop view if exists public.session_summary;
create or replace view public.session_summary as
select 
  s.id,
  s.song_title,
  s.created_at,
  s.finalized,
  s.finalized_at,
  s.hash,
  count(c.id) as collaborator_count,
  sum(c.percentage) as total_percentage,
  bool_and(c.signature_data is not null) as all_signed
from public.sessions s
left join public.collaborators c on s.id = c.session_id
group by s.id, s.song_title, s.created_at, s.finalized, s.finalized_at, s.hash;

-- Comment on tables
comment on table public.sessions is 'Split sheet sessions for music collaboration';
comment on table public.collaborators is 'Writers and their splits for each session';
