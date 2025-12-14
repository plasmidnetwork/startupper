-- Supabase schema for Startupper core data
-- Run with: supabase db push (or psql) before wiring the app

create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text not null unique,
  full_name text,
  headline text,
  location text,
  role text,
  avatar_url text,
  available_for_freelancing boolean default false,
  created_at timestamptz default now()
);

create table if not exists public.founder_details (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  startup_name text,
  pitch text,
  stage text,
  looking_for text[],
  website text,
  demo_video text,
  app_store_id text,
  play_store_id text,
  created_at timestamptz default now()
);

create table if not exists public.investor_details (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  investor_type text,
  ticket_size text,
  stages text[],
  created_at timestamptz default now()
);

create table if not exists public.enduser_details (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  main_role text,
  experience_level text,
  interests text[],
  created_at timestamptz default now()
);

create table if not exists public.feed_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  type text check (type in ('update','highlight','mission','investor')),
  content jsonb not null,
  like_count integer default 0,
  repost_count integer default 0,
  created_at timestamptz default now()
);

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  feed_item_id uuid references public.feed_items(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

-- Indexes
create index if not exists idx_feed_items_created_at on public.feed_items (created_at desc);
create index if not exists idx_feed_items_type on public.feed_items (type);
create index if not exists idx_feed_items_user on public.feed_items (user_id);
create index if not exists feed_items_featured_idx on public.feed_items ((content->>'featured')) where (content->>'featured')::boolean = true;
create index if not exists idx_feed_comments_item on public.feed_comments (feed_item_id, created_at);
create index if not exists idx_feed_comments_user on public.feed_comments (user_id);

-- Enable RLS
alter table public.profiles enable row level security;
alter table public.founder_details enable row level security;
alter table public.investor_details enable row level security;
alter table public.enduser_details enable row level security;
alter table public.feed_items enable row level security;
alter table public.feed_comments enable row level security;

-- RLS policies (drop existing first to avoid conflicts)
drop policy if exists "Profiles are viewable by authenticated" on public.profiles;
drop policy if exists "Users manage their own profile" on public.profiles;
drop policy if exists "Founders manage their details" on public.founder_details;
drop policy if exists "Investors manage their details" on public.investor_details;
drop policy if exists "End-users manage their details" on public.enduser_details;
drop policy if exists "Feed readable by authenticated" on public.feed_items;
drop policy if exists "Feed writes by owner" on public.feed_items;
drop policy if exists "Feed updates by owner" on public.feed_items;
drop policy if exists "Feed deletes by owner" on public.feed_items;
drop policy if exists "Feed comments readable by authenticated" on public.feed_comments;
drop policy if exists "Feed comments insert by owner" on public.feed_comments;
drop policy if exists "Feed comments delete by owner" on public.feed_comments;

create policy "Profiles are viewable by authenticated" on public.profiles
  for select using (auth.role() = 'authenticated');
create policy "Users manage their own profile" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

create policy "Founders manage their details" on public.founder_details
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Investors manage their details" on public.investor_details
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "End-users manage their details" on public.enduser_details
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Feed readable by authenticated" on public.feed_items
  for select using (auth.role() = 'authenticated');
create policy "Feed writes by owner" on public.feed_items
  for insert with check (auth.uid() = user_id);
create policy "Feed updates by owner" on public.feed_items
  for update using (auth.uid() = user_id);
create policy "Feed deletes by owner" on public.feed_items
  for delete using (auth.uid() = user_id);
create policy "Feed comments readable by authenticated" on public.feed_comments
  for select using (auth.role() = 'authenticated');
create policy "Feed comments insert by owner" on public.feed_comments
  for insert with check (auth.uid() = user_id);
create policy "Feed comments delete by owner" on public.feed_comments
  for delete using (auth.uid() = user_id);

-- Storage policies for avatars bucket (create the bucket named 'avatars' in Storage UI)
drop policy if exists "Avatar upload" on storage.objects;
drop policy if exists "Avatar read" on storage.objects;
drop policy if exists "Avatar update own" on storage.objects;
drop policy if exists "Avatar delete own" on storage.objects;

create policy "Avatar upload" on storage.objects
  for insert
  with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

-- Allow reads from avatars bucket (public). Tighten to authenticated if preferred.
create policy "Avatar read" on storage.objects
  for select
  using (bucket_id = 'avatars');

create policy "Avatar update own" on storage.objects
  for update
  using (bucket_id = 'avatars' and owner = auth.uid())
  with check (bucket_id = 'avatars' and owner = auth.uid());

create policy "Avatar delete own" on storage.objects
  for delete
  using (bucket_id = 'avatars' and owner = auth.uid());

-- Suggested content shape (for reference)
-- common: title text, subtitle text, ask text?, tags text[]?, metrics jsonb? [{label,value,color?}], featured bool?
-- mission: reward text?, effort text?
-- investor: thesis text?, office_hours text?
-- highlight/update: role text?, cta_label text?
