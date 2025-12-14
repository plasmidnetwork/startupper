-- Contact requests between users
create table if not exists public.contact_requests (
  id uuid primary key default gen_random_uuid(),
  requester uuid references public.profiles(id) on delete cascade,
  target uuid references public.profiles(id) on delete cascade,
  feed_item_id uuid references public.feed_items(id),
  message text,
  status text default 'pending',
  created_at timestamptz default now()
);

create index if not exists idx_contact_requests_requester on public.contact_requests (requester);
create index if not exists idx_contact_requests_target on public.contact_requests (target);

alter table public.contact_requests enable row level security;

drop policy if exists "Contact requests readable by participant" on public.contact_requests;
drop policy if exists "Contact requests write by requester" on public.contact_requests;

create policy "Contact requests readable by participant" on public.contact_requests
  for select using (auth.role() = 'authenticated' and (auth.uid() = requester or auth.uid() = target));

create policy "Contact requests write by requester" on public.contact_requests
  for insert with check (auth.uid() = requester);
