-- Add like/repost counters to feed_items for basic engagement display

alter table public.feed_items
  add column if not exists like_count integer default 0,
  add column if not exists repost_count integer default 0;
