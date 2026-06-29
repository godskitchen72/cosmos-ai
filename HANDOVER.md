# Cosmos Medical Technologies — HANDOVER (June 29, 2026, session 4)

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

### Scheduling Phase 3 Option A — live

Location-driven schedule fully implemented. The `doctor_locations` table
already had `days_of_week`, `start_time`, `end_time`, `slot_minutes`,
`capacity` from migration 011 — no new migration was needed (the HANDOVER
proposed adding duplicate columns; live repo superseded this).

**Changes to `app/calendar/page.tsx`:**

- `DoctorLocation` interface added; `doctor_locations` fetched in `load()`
  alongside existing queries.
- `getActiveDoctorLoc(doctorId, locationId)` — returns matching
  `doctor_locations` row or null.
- `getAvailDays(doctorId, locationId)` — returns `days_of_week` from
  `doctor_locations` row, falls back to `doctors.available_days`.
- `getCapacity(doctorId, locationId)` — returns `capacity` from
  `doctor_locations` row, falls back to `doctors.max_patients_per_day`.
- `getLocationsForDoctor(doctorId)` — filters location picker to only
  locations assigned to the selected doctor.
- Location picker moved **above** Time Slot in booking form (Doctor →
  Location → Patient → Time Slot → Type → Notes).
- Each location card shows its schedule inline: days · start–end · capacity.
- Selecting a location calls `jumpToDoctorAvailability(..., force=true)` —
  always jumps to the next valid day for that location regardless of
  current selection.
- `jumpToDoctorAvailability` gained `force` param (default false).
- Quick-pick chips and grid capacity both driven by `filterDocId` +
  `bookForm.location_id` — kept in sync.
- Slot generation reads `activeDl.start_time`, `activeDl.slot_minutes`,
  `activeDl.capacity` when a location is selected.
- `localDateStr(d)` helper introduced — all date math uses local
  year/month/day instead of `toISOString()` (fixes UTC/EDT offset bug
  that caused dates to show one day off).
- `load()` fetches ±2 week window (`weekOffset-2` to `weekOffset+2`) so
  appointments remain visible after location-driven week jumps.
- Locked doctor (`?doctor_id=` param) now writes into `bookForm.doctor_id`
  on mount so the insert guard passes.
- Grid cell onClick: only closes booking form when deselecting the same
  date (tapping it again) — form stays open when navigating to a new date.
- `handleBook`: insert is before state reset; `await load()` after insert
  (not `window.location.reload()`).

### RLS — authenticated policies added to `appointments` table

Root cause of appointments not appearing after booking: `appointments` had
RLS enabled with `anon`-only policies; authenticated users got zero rows.
Fixed by adding 4 policies in Supabase SQL Editor:

```sql
CREATE POLICY "authenticated read appointments" ON appointments
  FOR SELECT TO authenticated USING (true);
CREATE POLICY "authenticated insert appointments" ON appointments
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "authenticated update appointments" ON appointments
  FOR UPDATE TO authenticated USING (true);
CREATE POLICY "authenticated delete appointments" ON appointments
  FOR DELETE TO authenticated USING (true);
```

---

## Open Items, Priority Order

1. **Scheduling Phase 4** — MD login location pre-filters calendar. The
   login screen shows the location picker for MDs with multiple locations.
   Phase 4: selected location from login pre-selects the booking form's
   location chip AND drives the quick-pick chips and grid availability on
   calendar open (not just pre-fills `sessionStorage`). Depends on Phase
   3A ✓.

2. **NF-3 PC-payee mapping** — verify in a real generated PDF. Never
   confirmed across any session.

3. **Step 10 — Admin Users tab** — create/manage Cosmos users (email,
   role, linked doctor) from within the Admin dashboard. Currently users
   are created via Supabase dashboard + manual SQL insert.

4. **Appointment → Visit conversion** — "Checked In" status should enable
   pre-populated visit creation. Currently manual.

5. **NF-3 Pay-To: supervisor PC logic** — `forms/nf3.py` should fall
   through to supervisor's PC when `supervising_provider_id` is set.
   Deliberately deferred multiple sessions.

6. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.

7. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 4+ sessions, never fixed.

8. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 3 sessions, never removed.

9. **RLS hardening** — `patient_forms` RLS disabled entirely;
   `storage.objects` has one fully-open policy on `patient-forms` bucket.

10. **`patient_visits` doctor linkage gap** — `doctor_id` not reliably
    written at save time.

11. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
    uppercase convention for the other 7.

12. **MRI Extremity Studies + insurance fields** — backend ready, pure
    frontend work, never started.

13. **`cpt_codes.provider_type` backend wiring** — column exists, unused
    on both frontend and backend.

14. **Regenerate W-9s for existing doctors** — no bulk path. Low urgency.

15. **Desktop sidebar nav** — mockup confirmed target. Mobile-first
    remains immediate priority.

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` installed
version does not export `createServerComponentClient` (TS2724). Server-side
session reads in server components are deferred. The `?doctor_id=` URL param
from the login screen is the reliable doctor-scoping path. Do not attempt to
use `createServerComponentClient` until confirmed exportable via:
`grep -r "createServerClient" node_modules/@supabase/auth-helpers-nextjs/dist/`

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (this session — Phase 3A full rebuild + multiple patches) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (prior session — full login screen) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session — cookie-based route guard) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (prior session — auth helpers) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session — simplified, no server auth read) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (prior session — test dropdown removed) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session — signOut added) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session — signOut added) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (prior session — signOut added; full rebuild) |
| `cosmos-dashboard/app/dev/page.tsx` | Obtained-current (prior session — no changes) |
| `cosmos-dashboard/app/layout.tsx` | Obtained-current (prior session — default scaffold) |
| `cosmos-dashboard/app/billing/page.tsx` | Obtained-current (prior session — server wrapper) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/main.py`, `pdf_engine.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed — rest never seen in full |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained, any session |

---

## Lessons Learned This Session

- **Chrome duplicate filename mitigation** — before downloading any file
  from Claude, always `rm -f ~/storage/downloads/<filename>*` first to
  prevent Chrome appending `-1`, `-2` suffixes causing silent stale-copy
  deploys. This was the single biggest time drain this session (affected
  every file transfer attempt).
- **`doctor_locations` already had schedule columns** — `days_of_week`,
  `capacity`, `start_time`, `end_time`, `slot_minutes` from migration 011
  were fully wired in Admin UI. HANDOVER proposed adding duplicate columns
  under different names. Live repo is always the source of truth — grep
  the file before planning migrations.
- **RLS `authenticated` policies must be added to every table** — not just
  the tables actively touched in a session. `appointments` was missed in
  the prior session's RLS audit, causing the booking display bug. After
  any schema or auth change, run the full audit:
  `SELECT tablename, rowsecurity FROM pg_tables WHERE schemaname='public';`
  and `SELECT tablename, policyname, roles FROM pg_policies;`
- **`toISOString()` is always UTC** — any date string built from
  `new Date().toISOString()` will be off by the local timezone offset
  (EDT = UTC-4). Use local year/month/day components directly. The
  `localDateStr(d)` helper is now the standard for all date math in the
  calendar.
- **React state closure in async functions** — `load()` defined inside
  the component captures `weekOffset` at render time. When called after
  an async insert, the captured value may be stale. Widening the fetch
  window (±2 weeks) is the practical mitigation until `load` is refactored
  to accept an explicit date range param.
- **Node one-liner patching breaks on complex string escaping** — backtick
  and quote combinations in inline `-e` scripts cause `SyntaxError`.
  Always use `python3 - << 'PYEOF' ... PYEOF` for multi-line string
  replacements in Termux.
