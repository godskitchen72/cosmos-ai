# Cosmos Medical Technologies — HANDOVER (June 29, 2026, session 5)

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

### Scheduling Phase 4 — live

MD login location pre-filters calendar on open.

- Phase 4 `useEffect` added to `app/calendar/page.tsx`: after
  `doctorLocations` loads, if `lockedDoctorId` + `bookForm.location_id`
  are both set, calls `jumpToDoctorAvailability` to jump to first available
  day for that doctor+location combo. Dependency array:
  `[doctorLocations, lockedDoctorId, bookForm.location_id]`.
- `app/page.tsx` (login): `navigate()` now accepts `locName` param and
  stores `cosmos_location_name` in `sessionStorage` alongside
  `cosmos_location_id`. Both the auto-skip path (0/1 location) and the
  manual Continue path pass the location name.
- `app/md/MDClient.tsx`: reads `cosmos_location_name` from sessionStorage
  on mount; displays `📍 {locationName}` in green under "MD Dashboard"
  heading.
- `app/calendar/page.tsx`: reads `cosmos_location_name` from sessionStorage;
  displays `📍 {locationName}` in green under "Showing your schedule only".

### Union-of-locations availability — live

Calendar availability now reflects all assigned locations for a doctor,
not just the selected one.

- `getDoctorLocs(doctorId)` — returns all `doctor_locations` rows for a doctor.
- `getAvailDaysForDoctor(doctorId)` — union of all assigned location
  `days_of_week`. Falls back to `doctors.available_days` only when zero
  location assignments exist.
- `getAvailDays(doctorId, locationId)` — when a specific location is
  selected (booking form context), returns that location's days. When no
  location selected (grid/chips), returns union.
- `getCapacity(doctorId, locationId)` — specific location capacity when
  selected; max across all assigned locations otherwise.
- `isDayAvailable`: guards against `doctorLocations.length === 0` (data
  not yet loaded) before applying availability filter.
- Result: Tue/Thu greyed out for Dr. Gottesman (Main Office Mon/Wed +
  Queens Fri = union Mon/Wed/Fri; Tue/Thu have no location assignment).

### Admin — blocked days in location assignment form — live

- **Location Assignment day chips**: days assigned to OTHER locations for
  the same doctor are rendered in amber with 🔒 and `cursor-not-allowed`.
  Tooltip shows which location owns the day.
- **Default Schedule day chips**: days assigned to ANY location are
  rendered in amber with 🔒. Message: "🔒 Days assigned to a location
  override the default schedule."
- Location dropdown bug fixed: was filtering out already-assigned locations
  from `SelectItems`, causing selected value to disappear (shadcn Select
  can't display a value with no matching SelectItem). Fix: show all
  locations in dropdown; day blocking prevents double-booking.

---

## Open Items, Priority Order

1. **Admin Users tab** — create/manage Cosmos users (email, role, linked
   doctor) from within the Admin dashboard. Currently requires Supabase
   dashboard + manual SQL insert. This is the next session's primary task.

2. **NF-3 PC-payee mapping** — verify in a real generated PDF. Never
   confirmed across any session.

3. **Appointment → Visit conversion** — "Checked In" status should enable
   pre-populated visit creation. Currently manual.

4. **NF-3 Pay-To: supervisor PC logic** — `forms/nf3.py` should fall
   through to supervisor's PC when `supervising_provider_id` is set.
   Deliberately deferred multiple sessions.

5. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.

6. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 5+ sessions, never fixed.

7. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 4 sessions, never removed.

8. **RLS hardening** — `patient_forms` RLS disabled entirely;
   `storage.objects` has one fully-open policy on `patient-forms` bucket.

9. **`patient_visits` doctor linkage gap** — `doctor_id` not reliably
   written at save time.

10. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
    uppercase convention for the other 7.

11. **MRI Extremity Studies + insurance fields** — backend ready, pure
    frontend work, never started.

12. **`cpt_codes.provider_type` backend wiring** — column exists, unused
    on both frontend and backend.

13. **Regenerate W-9s for existing doctors** — no bulk path. Low urgency.

14. **Desktop sidebar nav** — mockup confirmed target. Mobile-first
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
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (this session — Phase 4, union availability, location badge) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (this session — cosmos_location_name stored in sessionStorage) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (this session — location badge added) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — blocked day chips, dropdown fix) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session — cookie-based route guard) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (prior session — auth helpers) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session — simplified, no server auth read) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session — signOut added) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session — signOut added) |
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

- **shadcn Select + filtered SelectItems** — if `SelectContent` filters
  out the currently-selected item, the trigger displays blank. Always
  include all valid options in `SelectItems`; use disabled state or
  separate UI to prevent invalid selections rather than filtering the list.
- **sessionStorage for cross-screen state** — storing `cosmos_location_name`
  alongside `cosmos_location_id` at login time avoids extra DB calls on
  every screen. Pattern: store display name + ID together at the source
  (login), read on any downstream screen.
- **Union availability pattern** — when a doctor has multiple location
  assignments, the calendar grid should reflect the union of all assigned
  days, not just the selected booking location. Use `getAvailDaysForDoctor`
  for grid/chips context; use `getActiveDoctorLoc` for booking form context.
- **`isDayAvailable` must guard on data load** — checking
  `doctorLocations.length === 0` before applying availability prevents
  all days appearing available during the initial render before data loads.
