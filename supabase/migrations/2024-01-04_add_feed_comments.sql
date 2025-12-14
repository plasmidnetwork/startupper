-- Feed comments table for per-item discussions

create table if not exists public.feed_comments (
  id uuid primary key default gen_random_uuid(),
  feed_item_id uuid references public.feed_items(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz default now()
);

create index if not exists idx_feed_comments_item on public.feed_comments (feed_item_id, created_at);
create index if not exists idx_feed_comments_user on public.feed_comments (user_id);

alter table public.feed_comments enable row level security;

drop policy if exists "Feed comments readable by authenticated" on public.feed_comments;
drop policy if exists "Feed comments insert by owner" on public.feed_comments;
drop policy if exists "Feed comments delete by owner" on public.feed_comments;

create policy "Feed comments readable by authenticated" on public.feed_comments
  for select using (auth.role() = 'authenticated');

create policy "Feed comments insert by owner" on public.feed_comments
  for insert with check (auth.uid() = user_id);

create policy "Feed comments delete by owner" on public.feed_comments
  for delete using (auth.uid() = user_id);
