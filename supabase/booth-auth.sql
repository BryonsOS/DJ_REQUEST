-- =====================================================================
--  Lock down public.requests: guests insert only, the booth reads/updates.
--
--  BEFORE RUNNING:
--    1. Deploy the updated request-portal.html first (the old page reads
--       the queue anonymously and will show an empty booth after this).
--    2. Create the booth user: Supabase dashboard → Authentication → Users →
--       Add user → email + password (tick "Auto confirm").
--    3. Replace BOOTH_EMAIL_HERE below with that email (it appears once).
--
--  Safe to re-run.
-- =====================================================================

-- Who counts as "the booth". This project has other apps and auth users,
-- so "any signed-in user" isn't enough — pin it to one email.
create or replace function public.is_booth()
returns boolean
language sql stable
as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'BOOTH_EMAIL_HERE'
$$;

-- Keep status to the three values the app knows.
alter table public.requests drop constraint if exists requests_status_check;
alter table public.requests
  add constraint requests_status_check check (status in ('new','played','declined'));

-- Replace the open policies (names from both the README and the HTML header).
drop policy if exists "read"              on public.requests;
drop policy if exists "insert"            on public.requests;
drop policy if exists "update"            on public.requests;
drop policy if exists "anyone can read"   on public.requests;
drop policy if exists "anyone can insert" on public.requests;
drop policy if exists "anyone can update" on public.requests;
drop policy if exists "guests insert new" on public.requests;
drop policy if exists "booth reads"       on public.requests;
drop policy if exists "booth updates"     on public.requests;

-- Guests: add a request, nothing else. Must arrive as 'new', sane lengths.
create policy "guests insert new" on public.requests
  for insert to anon, authenticated
  with check (
    status = 'new'
    and char_length(song) between 1 and 200
    and coalesce(char_length(artist), 0) <= 200
    and coalesce(char_length(guest),  0) <= 100
    and coalesce(char_length(note),   0) <= 300
    and coalesce(char_length(gig),    0) <= 100
  );

-- Booth: read the queue (this also gates Realtime) and change status.
create policy "booth reads" on public.requests
  for select to authenticated
  using (public.is_booth());

create policy "booth updates" on public.requests
  for update to authenticated
  using (public.is_booth())
  with check (public.is_booth());

-- Only the status column is editable, and never by anon.
revoke update on public.requests from anon, authenticated;
grant  update (status) on public.requests to authenticated;

-- No deletes from the client (unchanged by design, made explicit).
revoke delete on public.requests from anon, authenticated;

-- Realtime publication stays as-is; re-add only if the table was recreated:
-- alter publication supabase_realtime add table public.requests;
