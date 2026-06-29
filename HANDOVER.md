# Cosmos Medical Technologies — HANDOVER (June 28, 2026, session 3)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed via `tsc --noEmit` +
full deploy chain. Live app confirmed healthy at session close.

---

## Completed This Session

### Authentication foundation — live

Full Supabase Auth implementation replacing the stop-gap role selector:

- **Migration 012**: `user_profiles` table (`id` FK to `auth.users`,
  `role` CHECK constraint, `doctor_id` nullable FK to `doctors`,
  `full_name`, `pin_hint`). RLS: SELECT for own row only
  (`auth.uid() = id`).
- **4 test users created** in Supabase Auth (PIN `9999` for all):
  - `fd@cosmos.local` → frontdesk
  - `admin@cosmos.local` → admin
  - `billing@cosmos.local` → billing
  - `md@cosmos.local` → md (linked to Dr. Yury Gottesman,
    `doctor_id = ccfeb4b0-e61e-48f0-b4fa-bd15c155f6d0`)
- **`lib/supabase.ts`** extended with `signIn()`, `signOut()`,
  `getSession()`, `getUserProfile()` auth helpers.
- **`app/page.tsx`** replaced: login screen (email + PIN), post-login
  profile fetch, location picker for MD with multiple locations (auto-
  skip if 0 or 1 location assigned), session-based role routing.
- **`middleware.ts`** (new): cookie-based session guard on all routes;
  unauthenticated requests redirect to `/`. Public paths: `/`, `/_next`,
  `/favicon`, `/cosmos_`, `/dev`.
- **Sign Out** added to all four dashboards (`DashboardClient.tsx`,
  `MDClient.tsx`, `BillerDashboard.tsx`, `admin/page.tsx`) — calls
  `signOut()` then redirects to `/`.
- **`app/md/page.tsx`** simplified: reads `doctor_id` from `?doctor_id=`
  URL param (set by login screen on navigate). `createServerComponentClient`
  removed — caused TS2724 error (not exported by installed version of
  `@supabase/auth-helpers-nextjs`). URL param is the reliable path;
  session-server-read deferred until auth-helpers API is stable.
- **`app/md/MDClient.tsx`** cleaned: "⚠ Test Only — Simulate MD Login"
  dropdown removed entirely.

### RLS: authenticated role added to all tables

Supabase Auth changes the request role from `anon` to `authenticated`
for logged-in users. All existing RLS policies were `anon`-only, causing
silent empty reads for authenticated sessions. Fixed by adding
`authenticated` to all policies:

Tables patched: `office_locations`, `practice_settings`, `doctor_locations`,
`cpt_codes`, `icd10_codes`.

Pattern used:
```sql
DROP POLICY IF EXISTS anon_select_<table> ON <table>;
CREATE POLICY anon_select_<table> ON <table>
  FOR SELECT TO anon, authenticated USING (true);
-- (repeat for INSERT, UPDATE, DELETE)
```

### Scheduling Phase 3 (Option B) — live

Calendar booking form now includes an Office Location picker:

- `office_locations` fetched in `load()` alongside doctors/patients.
- `location_id` added to `bookForm` state (and reset after booking).
- Location picker renders as tappable button-chip cards below Notes field
  (only appears when `locations.length > 0` — invisible until locations
  exist).
- "No location / unassigned" fallback option always present.
- `sessionStorage.getItem('cosmos_location_id')` pre-selects the MD's
  login-time location on calendar open.
- `appointments` insert includes `location_id` (nullable).

**Phase 3 Option A (location-driven schedule) approved but NOT YET BUILT.**
Product decision confirmed this session: the correct flow is
Location → Schedule → Availability → Slots. This requires:
1. `doctor_locations` table gains `available_days` + `max_patients_per_day`
   columns (per-location schedule, overriding `doctors` fallback).
2. Calendar flow changes to: FD selects doctor → location picker appears
   (filtered to that doctor's `doctor_locations`) → capacity/available
   days read from `doctor_locations` → slots generate.
3. Admin doctor Schedule tab already has Location Assignments UI — needs
   those two new columns exposed for editing.

### 3 office locations confirmed in database

- Main Office — 123 Medical Plaza, Brooklyn, NY 11201, (718) 555-0100
- Bronx location — 45 Knox Ave, Bronx
- Queens Location — 76 Queens Blvd, Rego Park

---

## Open Items, Priority Order

1. **Scheduling Phase 3 Option A** — location-driven schedule. Requires:
   - Migration: add `available_days text[]` + `max_patients_per_day int`
     to `doctor_locations`
   - Admin UI: expose both columns in the Location Assignment edit form
     (Schedule tab → Location Assignments sub-section)
   - Calendar: FD selects doctor → location picker → calendar reads
     `doctor_locations.available_days` + `max_patients_per_day` instead
     of `doctors` fallback
   - This is the approved next session's primary task.

2. **NF-3 PC-payee mapping** — verify in a real generated PDF. Never
   confirmed across all sessions.

3. **Step 10 — Admin Users tab** — create/manage Cosmos users (email,
   role, linked doctor) from within the Admin dashboard. Currently users
   are created via Supabase dashboard + manual SQL insert.

4. **Scheduling Phase 4** — MD login location picker fully wired. The
   login screen already shows the picker for MDs with multiple locations.
   Once Phase 3A is done (location-specific schedules), Phase 4 becomes:
   the selected location from login pre-filters the calendar's location
   chip selection, not just pre-selects the booking form field.

5. **Appointment → Visit conversion** — "Checked In" status should enable
   pre-populated visit creation. Currently manual.

6. **NF-3 Pay-To: supervisor PC logic** — `forms/nf3.py` should fall
   through to supervisor's PC when `supervising_provider_id` is set.
   Deliberately deferred multiple sessions.

7. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.

8. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 4+ sessions, never fixed.

9. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 3 sessions, never removed.

10. **RLS hardening** — `patient_forms` RLS disabled entirely;
    `storage.objects` has one fully-open policy on `patient-forms` bucket.

11. **`patient_visits` doctor linkage gap** — `doctor_id` not reliably
    written at save time.

12. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
    uppercase convention for the other 7.

13. **MRI Extremity Studies + insurance fields** — backend ready, pure
    frontend work, never started.

14. **`cpt_codes.provider_type` backend wiring** — column exists, unused
    on both frontend and backend.

15. **Regenerate W-9s for existing doctors** — no bulk path. Low urgency.

16. **Desktop sidebar nav** — mockup confirmed target. Mobile-first
    remains immediate priority.

---

## Known Auth Architecture Gap

`@supabase/auth-helpers-nextjs` installed version does not export
`createServerComponentClient` (TS2724 — did you mean `createServerClient`?).
Server-side session reads in server components are currently deferred.
The `?doctor_id=` URL param from the login screen is the reliable
doctor-scoping path until this is resolved. Do not attempt to use
`createServerComponentClient` in any server component until the package
is confirmed to export it (check with `grep -r "createServerClient"
node_modules/@supabase/auth-helpers-nextjs/dist/`).

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (this session — full login screen replacement) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (this session — new file, cookie-based route guard) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (this session — auth helpers added) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (this session — simplified, no server auth read) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (this session — test dropdown removed, signOut added) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (this session — signOut added) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (this session — signOut added) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — signOut added; prior session full rebuild) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (this session — Phase 3 Option B patch applied) |
| `cosmos-dashboard/app/dev/page.tsx` | Obtained-current (prior session — no changes this session) |
| `cosmos-dashboard/app/layout.tsx` | Obtained-current (this session — default scaffold, no changes needed) |
| `cosmos-dashboard/app/billing/page.tsx` | Obtained-current (this session — server wrapper, no changes needed) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/main.py`, `pdf_engine.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed — rest never seen in full |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained, any session |

---

## Lessons Learned This Session

- **`@supabase/auth-helpers-nextjs` API mismatch** — the installed version
  exports `createServerClient` not `createServerComponentClient`. Before
  using any named export from this package in a server component, verify
  with `grep -r "export" node_modules/@supabase/auth-helpers-nextjs/dist/`
  that the export actually exists.
- **Supabase Auth changes request role from `anon` to `authenticated`** —
  existing RLS policies scoped to `anon` only will silently return empty
  results for logged-in users. After implementing auth, audit all RLS
  policies and add `authenticated` to every `TO` clause. Run the RLS
  audit query immediately after login is live.
- **Service role key in Termux** — writing a long JWT to a shell variable
  inline is unreliable (paste corruption, placeholder not replaced). Use
  `echo -n 'key' > ~/file.txt && SK=$(cat ~/file.txt)` pattern, or use
  the Supabase dashboard UI directly for one-off user creation.
- **`cat > file << 'ENDOFFILE'`** is the reliable large-file write method
  in Termux — confirmed working for files up to ~170 lines. Faster and
  more reliable than downloading from Claude artifacts for files this size.
- **File retrieval standard confirmed** — always provide
  `git show HEAD:<path> > ~/storage/downloads/<filename>` with every file
  request. Never use grep as a substitute for reading the actual file.
  Added to `AI_STYLE_GUIDE.md` §3.
