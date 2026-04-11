create extension if not exists pgcrypto;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type public.user_role as enum ('citizen', 'authority', 'contractor', 'ngo');
  end if;
  if not exists (select 1 from pg_type where typname = 'issue_category') then
    create type public.issue_category as enum ('road', 'water', 'electricity', 'sanitation');
  end if;
  if not exists (select 1 from pg_type where typname = 'issue_status') then
    create type public.issue_status as enum (
      'open_for_bidding',
      'in_progress',
      'awaiting_citizen_verification',
      'resolved'
    );
  end if;
  if not exists (select 1 from pg_type where typname = 'vote_type') then
    create type public.vote_type as enum ('upvote', 'downvote');
  end if;
end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text not null,
  phone text,
  role public.user_role not null,
  state text not null,
  city text not null,
  address text not null,
  organization_name text,
  registration_id text,
  trust_code text,
  rating numeric(3,1),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.issues (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text not null,
  category public.issue_category not null,
  status public.issue_status not null default 'open_for_bidding',
  state text not null,
  city text not null,
  address text not null,
  latitude double precision,
  longitude double precision,
  before_image_url text,
  after_image_url text,
  urgency text not null default 'high',
  assigned_contractor uuid references public.profiles (id),
  assigned_ngo uuid references public.profiles (id),
  duplicate_count integer not null default 1,
  is_duplicate boolean not null default false,
  is_suspicious boolean not null default false,
  overall_rating_score numeric(3,1) not null default 0,
  contractor_rating numeric(3,1),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.issue_comments (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  content text not null,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.issue_votes (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  vote public.vote_type not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (issue_id, user_id)
);

create table if not exists public.bids (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues (id) on delete cascade,
  contractor_id uuid not null references public.profiles (id) on delete cascade,
  bid_amount numeric(12,2) not null,
  proposal_note text,
  status text not null default 'submitted',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.ngo_requests (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues (id) on delete cascade,
  ngo_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  unique (issue_id, ngo_id)
);

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  ngo_id uuid not null references public.profiles (id) on delete cascade,
  donor_user_id uuid references public.profiles (id) on delete set null,
  donor_name text not null,
  amount numeric(12,2) not null,
  message text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.issue_media (
  id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issues (id) on delete cascade,
  media_url text not null,
  media_kind text not null,
  created_at timestamptz not null default timezone('utc', now())
);

insert into storage.buckets (id, name, public)
values
  ('complaint-media', 'complaint-media', true),
  ('resolution-media', 'resolution-media', true)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public;

alter table public.profiles enable row level security;
alter table public.issues enable row level security;
alter table public.issue_comments enable row level security;
alter table public.issue_votes enable row level security;
alter table public.bids enable row level security;
alter table public.ngo_requests enable row level security;
alter table public.donations enable row level security;
alter table public.issue_media enable row level security;

drop policy if exists "profiles_select_own_or_public_ngo" on public.profiles;
create policy "profiles_select_own_or_public_ngo"
on public.profiles
for select
to authenticated
using (auth.uid() = id or role = 'ngo');

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "issues_select_authenticated" on public.issues;
create policy "issues_select_authenticated"
on public.issues
for select
to authenticated
using (true);

drop policy if exists "issues_insert_own" on public.issues;
create policy "issues_insert_own"
on public.issues
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "issues_update_creator_or_assignee" on public.issues;
create policy "issues_update_creator_or_assignee"
on public.issues
for update
to authenticated
using (
  created_by = auth.uid()
  or assigned_contractor = auth.uid()
  or assigned_ngo = auth.uid()
)
with check (
  created_by = auth.uid()
  or assigned_contractor = auth.uid()
  or assigned_ngo = auth.uid()
);

drop policy if exists "issue_comments_select_authenticated" on public.issue_comments;
create policy "issue_comments_select_authenticated"
on public.issue_comments
for select
to authenticated
using (true);

drop policy if exists "issue_comments_insert_own" on public.issue_comments;
create policy "issue_comments_insert_own"
on public.issue_comments
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "issue_votes_select_authenticated" on public.issue_votes;
create policy "issue_votes_select_authenticated"
on public.issue_votes
for select
to authenticated
using (true);

drop policy if exists "issue_votes_insert_own" on public.issue_votes;
create policy "issue_votes_insert_own"
on public.issue_votes
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "bids_select_authenticated" on public.bids;
create policy "bids_select_authenticated"
on public.bids
for select
to authenticated
using (true);

drop policy if exists "bids_insert_own" on public.bids;
create policy "bids_insert_own"
on public.bids
for insert
to authenticated
with check (contractor_id = auth.uid());

drop policy if exists "bids_update_own" on public.bids;
create policy "bids_update_own"
on public.bids
for update
to authenticated
using (contractor_id = auth.uid())
with check (contractor_id = auth.uid());

drop policy if exists "ngo_requests_select_authenticated" on public.ngo_requests;
create policy "ngo_requests_select_authenticated"
on public.ngo_requests
for select
to authenticated
using (true);

drop policy if exists "ngo_requests_insert_own" on public.ngo_requests;
create policy "ngo_requests_insert_own"
on public.ngo_requests
for insert
to authenticated
with check (ngo_id = auth.uid());

drop policy if exists "ngo_requests_update_own" on public.ngo_requests;
create policy "ngo_requests_update_own"
on public.ngo_requests
for update
to authenticated
using (ngo_id = auth.uid())
with check (ngo_id = auth.uid());

drop policy if exists "donations_select_authenticated" on public.donations;
create policy "donations_select_authenticated"
on public.donations
for select
to authenticated
using (true);

drop policy if exists "donations_insert_authenticated" on public.donations;
create policy "donations_insert_authenticated"
on public.donations
for insert
to authenticated
with check (donor_user_id is null or donor_user_id = auth.uid());

drop policy if exists "issue_media_select_authenticated" on public.issue_media;
create policy "issue_media_select_authenticated"
on public.issue_media
for select
to authenticated
using (true);

drop policy if exists "issue_media_insert_authenticated" on public.issue_media;
create policy "issue_media_insert_authenticated"
on public.issue_media
for insert
to authenticated
with check (
  exists (
    select 1
    from public.issues
    where public.issues.id = public.issue_media.issue_id
      and (
        public.issues.created_by = auth.uid()
        or public.issues.assigned_contractor = auth.uid()
        or public.issues.assigned_ngo = auth.uid()
      )
  )
);

drop policy if exists "complaint_and_resolution_media_public_select" on storage.objects;
create policy "complaint_and_resolution_media_public_select"
on storage.objects
for select
to public
using (bucket_id in ('complaint-media', 'resolution-media'));

drop policy if exists "complaint_and_resolution_media_authenticated_insert" on storage.objects;
create policy "complaint_and_resolution_media_authenticated_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id in ('complaint-media', 'resolution-media'));
