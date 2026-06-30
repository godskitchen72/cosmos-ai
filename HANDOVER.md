# Cosmos Medical Technologies — HANDOVER (June 29, 2026, session 7)

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

### Doctor Location Assignment — Edit button — live

Admin → Providers → Schedule → Location Assignments cards now have an
**Edit** button alongside Remove. Edit reuses the existing Add Location
form (`addingLoc`/`locForm`) and `handleAddLocation`'s upsert — no new
backend path. New `editingLocId` state tracks edit-mode; the location
dropdown locks (read-only) while editing so only the schedule fields
(days/hours/capacity/slot length) can change. Save button reads "Save
Changes" in edit mode. Resolves Open Item #1 (was: "must delete and
re-add to change hours").

Also fixed in the same pass: location card hours display changed from
24-hour to 12-hour with AM/PM (`toLocaleTimeString`) — display-only,
underlying columns unchanged.

### Admin Users Tab — live

Full user management from within Admin dashboard. No more Supabase
dashboard or manual SQL required for day-to-day user administration.

- **API route:** `app/api/admin/users/route.ts` — GET/POST/PATCH/DELETE
  using Supabase Admin client (`SUPABASE_SERVICE_KEY`).
- **`user_profiles.active`** column added (boolean, NOT NULL DEFAULT true)
  via `ALTER TABLE` migration.
- **`user_profiles` CHECK constraint** updated to include `superadmin`:
  `CHECK (role IN ('frontdesk','md','billing','admin','superadmin'))`.
- **PIN padding:** `padPin()` helper in `lib/supabase.ts` pads PINs to 6
  chars (Supabase Auth minimum). Applied on `signIn()`, POST (create),
  and PATCH (reset PIN). Existing test users reset via direct SQL.
  All test users now use PIN `999999` (6 digits).
- **Auth token forwarded:** all `UsersSection` fetch calls include
  `Authorization: Bearer <token>` header via `getToken()` helper.

### Superadmin Role — live

New `superadmin` role gives practice owner access to all four dashboards
from a single login.

- **Login screen** (`app/page.tsx`) fully rewritten in shadcn/ui +
  Oxanium font (replaces all inline styles). Three stages:
  `login` → `location` (MD multi-location picker) → `dashboard`
  (superadmin picker).
- **Superadmin dashboard picker:** 2×2 grid of dashboard tiles
  (Front Desk, MD, Billing, Admin). Gold crown badge. Sign out link.
- **Role guard on API route:** non-superadmin callers cannot create,
  assign, modify, or delete superadmin accounts. Enforced server-side
  via `getCallerRole()` reading the Bearer token.

### Superadmin Provisioning Procedure

First superadmin per client must be bootstrapped via Supabase SQL:
```sql
UPDATE user_profiles SET role = 'superadmin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'owner@practice.com');
```
Subsequent superadmins can be created in-app by an existing superadmin.

### Active Users KPI Card — live

Overview KPI card now shows real count from `user_profiles WHERE active = true`.

### Admin UI Fixes — live

- Quick Access Users button wired to `admin-tab` event handler
- Practice Info card font sizes and spacing tightened

### RLS Full Audit — live

Full audit of all public tables. Added `authenticated` role policies to:
`cpt_codes`, `doctor_locations`, `doctors`, `office_locations`,
`practice_settings`, `user_profiles`, `patient_pain_chart`,
`patient_procedures`, `patients`, `patient_visits`, `visit_line_items`.

**Pattern confirmed:** `allow_all_<table>` policy `FOR ALL TO anon,
authenticated USING (true) WITH CHECK (true)` is the standard fix.
RLS silent-failure (returns zero rows, no error) is caused by missing
`authenticated` role coverage even when `anon` policies exist.

### Appointment → Visit Conversion — live

Full FD → MD workflow implemented:

**FD role (calendar):** `View Chart` · `Confirm →` · `Check In →` ·
`No-Show` · `Cancel` · `Delete`

**MD role (calendar):** `Start Visit` (Checked In only) · `No-Show`
(Confirmed/Checked In only) · `Cancel` (Confirmed/Checked In only) ·
`Awaiting confirmation` text for Scheduled

**`handleStartVisit`:** Creates `patient_visits` row → marks appointment
`Checked In` → navigates to `/md/${patientId}?visit_id=${newId}`.

**`handleSave` dual-mode:** If `savedVisitId` exists (pre-created via
Start Visit) → UPDATE. If not → INSERT. Both paths call
`generateIcd10Pdf` + `finalizeBilling` + auto-complete appointment.

**`visitDirty` flag:** Detects whether a pre-created visit has clinical
data. Starts `true` for empty pre-created visits (shows SAVE MD VISIT),
`false` for visits with existing `pce_data` or `cpt_codes` (shows
✅ Visit Saved). CPT/ICD-10 pickers show when `visitDirty`, read-only
chips when `!visitDirty`.

### Booking Form Improvements — live

- **Free-form time entry** replaces slot system (NY No-Fault workflow —
  walk-in/queue model, not strict time slots)
- **Double-booking guard:** blocks same doctor + date + time
- **Dark doctor selector:** locked MD shows as text, FD gets dropdown
- **Hours hint:** shows location service hours below time input
- **MD calendar buttons:** Scheduled → "Awaiting confirmation" text only

### `generateSlots` — retained but unused

Function kept in codebase for potential future use by practices that
need strict time slot scheduling. Not called by any UI.

---

## Open Items, Priority Order

1. **NF-3 PC-payee mapping** — verify in a real generated PDF. Never
   confirmed across any session.

2. **NF-3 Pay-To: supervisor PC logic** — `forms/nf3.py` should fall
   through to supervisor's PC when `supervising_provider_id` is set.
   Deliberately deferred multiple sessions.

3. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.

4. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 5+ sessions, never fixed.

5. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 4 sessions, never removed.

6. **`patient_visits.doctor_id` column** — does not exist. `handleStartVisit`
   was patched to omit it. If doctor linkage on visits is needed, add
   migration first.

7. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
   uppercase convention for the other 7.

8. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend work, never started.

9. **`cpt_codes.provider_type` backend wiring** — column exists, unused.

10. **Regenerate W-9s for existing doctors** — no bulk path. Low urgency.

11. **Desktop sidebar nav** — mockup confirmed target. Mobile-first
    remains immediate priority.

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` installed
version does not export `createServerComponentClient` (TS2724). Server-side
session reads in server components are deferred. The `?doctor_id=` URL param
from the login screen is the reliable doctor-scoping path.

**`patient_visits.doctor_id` missing:** Column does not exist in schema.
`handleStartVisit` omits it. Visit-to-doctor linkage currently relies on
`patients.doctor_id` (one-doctor-per-patient assumption).

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (this session — shadcn rewrite, superadmin picker) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — Edit button for location assignments, 12h time display) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (this session — full CRUD + superadmin guard) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (this session — role buttons, free-form time, double-booking guard) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (this session — dual-mode save, visitDirty, CPT picker fix) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (this session — padPin helper) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/main.py`, `pdf_engine.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **Termux home path is not `/root`** — a patch script hardcoded
  `/root/cosmos-dashboard` and failed with `FileNotFoundError`. Termux
  home is `/data/data/com.termux/files/home/` (`~` or `$HOME`). Patch
  scripts must use `$HOME`/`~`, never assume a standard Linux `/root`
  path, even when written/tested conceptually against a normal Linux
  environment.
- **Edit-in-place via existing upsert, no new backend path** — when a
  table already has a `upsert(..., { onConflict: '<unique_cols>' })`
  write path (here: `doctor_locations` on `doctor_id,location_id`), an
  "Edit" feature can reuse the existing Add form and handler entirely —
  populate the form state from the row being edited, track an
  `editing<X>Id` to switch the form's title/button label, no separate
  UPDATE-specific code or endpoint needed.
- **Supabase Auth min password length** — default is 6 chars. PINs shorter
  than 6 are silently rejected. Fix: `padPin()` pads to 6 with trailing
  zeros. All test users now use `999999`.
- **`user_profiles` CHECK constraint** — adding a new role requires
  `DROP CONSTRAINT` + `ADD CONSTRAINT`. No `ALTER CONSTRAINT` in Postgres.
- **Service-role API guard pattern** — read `Authorization: Bearer` header,
  call `supabase.auth.getUser(token)`, look up `user_profiles.role`.
  Frontend must forward session token on every mutating call.
- **Superadmin bootstrap** — first superadmin per deployment requires
  direct SQL. Document in client onboarding checklist.
- **`/tmp` not writable in Termux** — use `~/` for patch scripts. Termux
  home: `/data/data/com.termux/files/home/`.
- **RLS silent failure** — `anon`-only policies block `authenticated` users
  silently (zero rows, no error). Always add both roles. Standard fix:
  `FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)`.
- **`patient_visits.doctor_id`** — column does not exist. Do not reference
  it in any insert/update without adding a migration first.
- **NY No-Fault slot system** — fixed time slots are wrong for NY No-Fault
  walk-in/queue model. Replaced with free-form time entry. Capacity =
  daily patient limit, not slot count.
- **`visitDirty` pattern** — when a visit row is pre-created (Start Visit),
  `savedVisitId` is set but clinical data is empty. Use `visitDirty` to
  distinguish "needs saving" from "already saved". Initialize from visit
  data, not from whether `savedVisitId` exists.
- **CPT/ICD-10 picker gating** — gate on `(!visitDirty && savedVisitId)`,
  not just `savedVisitId`. Otherwise pickers disappear on pre-created visits.
