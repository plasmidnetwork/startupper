-- Add status change tracking and allow participants to update status

alter table public.contact_requests
  add column if not exists status_changed_at timestamptz default now();

drop policy if exists "Contact requests update by participant" on public.contact_requests;

create policy "Contact requests update by participant" on public.contact_requests
  for update
  using (
    auth.role() = 'authenticated'
    and (auth.uid() = requester or auth.uid() = target)
  )
  with check (
    auth.uid() = requester or auth.uid() = target
  );
