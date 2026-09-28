# Guest Request Portal

A single-file web app for taking live song requests at DJ gigs. Guests scan a QR
code and request songs from their phones; the DJ works a live queue on a booth
screen — marking requests played or declined and seeing at a glance whether each
song is already in the library.

No framework, no build step. Everything is in `request-portal.html`.

## What it does

- **Guest form** — scan the QR, submit a song (artist, name, and a note optional).
- **Booth dashboard** (`#booth`, sign-in required) — live queue with New / Played /
  Declined / All tabs, plus a **Top requests** view ranked by demand.
- **Library check** — matches each request against your track library and flags
  it *In library* (even if you only own a remix or extended mix) or links you to
  **Grab on Tidal** if you don't have it.
- **Demand meter** — when several guests ask for the same track, it lights up.
- **CSV export** — song tally and full request log, for building data over time.
- **Live sync** — requests appear on the booth the instant a guest hits send.
- **Built for an iPad on the shelf** — keeps the screen awake, runs full-screen,
  reconnects after sleep, and can chime / pulse / notify on new requests.

## Quick start

1. **Set up the database** (Supabase → SQL editor):

   ```sql
   create table public.requests (
     id uuid primary key default gen_random_uuid(),
     created_at timestamptz default now(),
     song text not null, artist text, guest text, note text,
     status text default 'new', gig text
   );
   alter table public.requests enable row level security;
   create policy "read"   on public.requests for select using (true);
   create policy "insert" on public.requests for insert with check (true);
   create policy "update" on public.requests for update using (true);
   alter publication supabase_realtime add table public.requests;
   ```

   Then **lock it down**: create the booth user (Authentication → Users → Add
   user, auto-confirm), put its email into `supabase/booth-auth.sql`, and run
   that file. Guests can then only *add* requests; only the booth account can
   read the queue or change a status.

2. **Add your keys** to the `CONFIG` block at the top of `request-portal.html`
   (project URL + publishable key, and optionally the booth email).

3. **Deploy** — link the repo in Netlify; every push deploys. `netlify.toml`
   serves the app at the site root. HTTPS is required. That's it.

Leave the keys blank to run in local **demo mode** (same-browser only) while testing.

## At the gig

- iPad → `your-site/#booth`, sign in with the booth account (it stays signed
  in), Add to Home Screen, turn alerts on.
- Set the gig name, then tap **QR code** — it bakes the gig name into the guest
  link so every request is tagged to that event.
- Guests scan → requests land on the booth.

## Configuration

Everything lives in one `CONFIG` object at the top of the HTML file:

| Key | What it does |
| --- | --- |
| `SUPABASE_URL` | Supabase project URL (blank = demo mode) |
| `SUPABASE_ANON_KEY` | Supabase publishable key — safe in client code |
| `BOOTH_EMAIL` | Optional — pre-fills the booth sign-in email |
| `BOOTH_PIN` | Demo mode only — the live booth uses Supabase Auth |
| `GIG_NAME` | Default event label |

## Development

- Single self-contained HTML file: HTML + CSS + vanilla JS, no build tooling.
- External libraries load from CDN only (QR code from cdnjs; Supabase client
  injected at runtime when keys exist).
- The library matcher normalizes titles (strips version tags, apostrophes,
  "feat.") and matches on token overlap, so it's tolerant of remixes and of
  guests typing the artist and title together.

## License

Private project. Not for redistribution.
