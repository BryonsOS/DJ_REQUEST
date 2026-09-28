# Guest Request Portal

A single-file web app for taking live song requests at DJ gigs. Guests scan a QR
code and submit requests from their phones; the DJ sees them live on a booth
screen (an iPad on the shelf), marks them played/declined, and sees whether each
song is already in the library.

Built and maintained by Bryon (Pro DJ Services / Directmix / YourWeddingsDJ).

## Stack & conventions

- **One file, no build step.** Everything — HTML, CSS, vanilla JS — lives in
  `request-portal.html`. No framework, no bundler, no npm. Keep it that way.
- **Backend:** Supabase (Postgres + Realtime).
- **Deploy:** drag `request-portal.html` onto https://app.netlify.com/drop, or
  connect the Netlify MCP. No CI. HTTPS is required (wake lock + PWA features).
- **External libs** load from CDN only: `qrcode-generator` from cdnjs;
  `@supabase/supabase-js` is injected dynamically at runtime, only when keys are
  present. Don't vendor or bundle them.

## Configuration

All config is a single `CONFIG` object at the top of `request-portal.html`:

- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — the publishable key (safe in client code).
  If both are blank the app runs in local **demo mode** (same-browser only).
- `BOOTH_EMAIL` — optional; pre-fills the booth sign-in.
- `BOOTH_PIN` — demo mode only. The live booth signs in with Supabase Auth.
- `GIG_NAME` — default event label.

## Backend (Supabase)

- Project ref: `mhktyejanikvdnjbndgi` (Bryon's general project, shared org).
- Table: `public.requests` (id, created_at, song, artist, guest, note, status,
  gig). `status` is `new` | `played` | `declined`.
- RLS is ON, set by `supabase/booth-auth.sql`: anon/guests may only INSERT
  (status must be `new`, lengths capped). SELECT and UPDATE (status column only)
  are limited to the booth's Supabase Auth user via `public.is_booth()`, which
  pins one email — the project is shared, so "any authenticated user" is not
  enough. No deletes. Realtime respects RLS, so only the signed-in booth gets
  live events.
- Realtime: the table is in the `supabase_realtime` publication. That's what
  pushes new requests to the booth live. If you recreate the table, re-run
  `alter publication supabase_realtime add table public.requests;`.

## Live deploy

- https://verdant-medovik-096c8b.netlify.app/  (guest form)
- https://verdant-medovik-096c8b.netlify.app/#booth  (booth, PIN-gated)

## App structure (all inside request-portal.html)

- **Two views**, switched by URL hash: `#booth` (dashboard; Supabase Auth
  email/password sign-in, session persists; demo mode uses the PIN); any other
  URL shows the guest form.
- **Guests never read.** The queue is fetched and the realtime channel opened
  only after the booth signs in (`startBooth` / `stopBooth`).
- **Backend layer** is pluggable: Supabase when keys exist, else an in-memory +
  BroadcastChannel demo store. `addRequest` / `setStatus` / `refetch` wrap both.
- **Gig tagging:** the booth's QR bakes the current gig name into the guest link
  as `?gig=`, so each guest submission is tagged to the right event.
- **Library match** (`norm` / `toks` / `matchTrack`): token-overlap matcher that
  ignores version tags (extended, remix, edit, clean, remaster, etc.) and
  apostrophes, so "Usher Yeah" matches "Yeah (Extended Mix)". A request counts as
  in-library when the track's title words are ~all present in what the guest
  typed. Leans slightly toward recall (a DJ would rather see "you have it").
  Library is loaded from a CSV on the booth and cached in localStorage.
- **Not-in-library** requests render a "Grab on Tidal" link
  (`listen.tidal.com/search?q=`).
- **Top requests tab:** aggregates all requests by song, ranks by count, flags
  the shopping-list (not-in-library) items, and exports CSV (song tally + full log).
- **iPad booth features:** screen wake lock (re-acquired on visibility), full-
  screen home-screen meta tags, reconnect/refetch on wake, glanceable "waiting"
  glow on the New tab.
- **Alerts:** bell toggle → Web Audio chime, card pulse, tab-title count,
  vibration, and OS notification when backgrounded. A Test button fires one.

## Working style

- Preserve the single-file, no-build, self-contained architecture.
- Syntax-check the inline script after edits.
- Don't add real secret keys to the repo — only the publishable key belongs
  client-side. Access control lives in RLS (`supabase/booth-auth.sql`), not in
  the page; keep it that way.

## Ideas not yet built

- Move the music library into Supabase (a `tracks` table) so the booth never has
  to re-load a CSV and matching is device-independent.
- "Requests open/closed" toggle controlled from the booth.
- iPad burn-in guard for long lit sessions.
- Guest-side autocomplete from the library.
