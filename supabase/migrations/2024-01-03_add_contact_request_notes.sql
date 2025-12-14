-- Add notes field for contact requests (visible/editable by participants)

alter table public.contact_requests
  add column if not exists notes text;
