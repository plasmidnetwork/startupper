-- Helper functions to increment/decrement engagement counters safely

create or replace function public.increment_feed_like(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update feed_items
    set like_count = coalesce(like_count, 0) + 1
  where id = p_id;
$$;

create or replace function public.decrement_feed_like(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update feed_items
    set like_count = greatest(coalesce(like_count, 0) - 1, 0)
  where id = p_id;
$$;

create or replace function public.increment_feed_repost(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update feed_items
    set repost_count = coalesce(repost_count, 0) + 1
  where id = p_id;
$$;
