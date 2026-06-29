# Changelog

## 2026-06-29 — Admin Users, Superadmin role, Visit conversion, RLS audit

### Admin Users Tab (new)

- `app/api/admin/users/route.ts` — new API route, full CRUD via Supabase
  Admin client. GET lists all users (auth.users + user_profiles join).
  POST creates auth user + profile row with rollback on failure. PATCH
  handles profile edits, PIN reset, and active toggle. DELETE removes
  auth user (cascades to profile).
- `user_profiles.active` column added: `ALTER TABLE user_profiles ADD
  COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true`
- `user_profiles` CHECK constraint updated to include `superadmin` role
- `lib/supabase.ts`: `padPin()` helper — pads PIN to 6 chars for Supabase
  Auth minimum password length requirement
- All test users reset to PIN `999999` via direct SQL on `auth.users`
- `UsersSection` fetch calls forward `Authorization: Bearer <token>`

### Superadmin Role (new)

- `app/page.tsx`: full rewrite in shadcn/ui + Oxanium. Three stages:
  `login` → `location` (MD) → `dashboard` (superadmin 2×2 picker)
- `ROLE_META` updated with `superadmin` entry (gold crown, dashboard picker)
- API route guard: non-superadmin cannot create/assign/modify/delete
  superadmin accounts. `getCallerRole()` reads Bearer token server-side.
- `user_profiles` CHECK constraint: added `superadmin` to allowed values
- Admin Users dropdown: `superadmin` added as selectable role

### Active Users KPI Card

- `OverviewSection`: `activeUserCount` state + fetch from `user_profiles
  WHERE active = true`. Replaces `—` placeholder.

### RLS Full Audit

Added `authenticated` role policies to all tables that had `anon`-only
coverage: `cpt_codes`, `doctor_locations`, `doctors`, `office_locations`,
`practice_settings`, `user_profiles`, `patient_pain_chart`,
`patient_procedures`, `patients`. Consolidated `patient_visits` and
`visit_line_items` to single `allow_all` policies covering both roles.

### Appointment → Visit Conversion

- `app/calendar/page.tsx`: `handleStartVisit()` — creates `patient_visits`
  row, marks appointment `Checked In`, navigates to chart with `?visit_id=`
- Role-based calendar buttons:
  - FD: View Chart · Confirm → · Check In → · No-Show · Cancel · Delete
  - MD: Start Visit (Checked In only) · No-Show/Cancel (Confirmed/Checked
    In only) · "Awaiting confirmation" text for Scheduled
- `app/md/[patientId]/PatientChart.tsx`:
  - `handleSave` dual-mode: UPDATE if `savedVisitId` exists, INSERT if not
  - `visitDirty` flag: detects empty pre-created visits vs saved visits.
    Initialized from visit data (`pce_data`/`cpt_codes` presence).
  - CPT/ICD-10 pickers gated on `(!visitDirty && savedVisitId)` — show
    pickers when dirty, read-only chips when already saved
  - Auto-complete: saves appointment as `Completed` when visit is saved
  - `canSave` simplified to `!tx.expired` (removed `!savedVisitId` gate)

### Booking Form Improvements

- Free-form time entry (`<input type="time">`) replaces slot system.
  NY No-Fault walk-in/queue model — exact time is administrative only.
- Double-booking guard in `handleBook`: blocks same doctor + date + time
- Dark doctor selector: locked MD shows as text, FD gets dropdown
- Hours hint below time input shows location service hours
- `generateSlots` retained but unused (available for future strict-slot
  practices)

---

## 2026-06-29 — Phase 4, union availability, location badge, Admin day blocking

### Scheduling Phase 4 — MD login location pre-filters calendar

- `app/calendar/page.tsx`: Phase 4 `useEffect` — after `doctorLocations`
  loads, jumps calendar to first available day for locked doctor+location
- `app/page.tsx`: `navigate()` stores `cosmos_location_name` in
  sessionStorage alongside `cosmos_location_id`
- `app/md/MDClient.tsx`: `📍 {locationName}` badge in green under heading
- `app/calendar/page.tsx`: `📍 {locationName}` badge under "Showing your
  schedule only"

### Union-of-locations availability

- `getDoctorLocs()`, `getAvailDaysForDoctor()` helpers added
- Grid/chips use union of all assigned location days (not just selected one)
- Capacity uses max across assigned locations when no location selected
- `isDayAvailable` guards on `doctorLocations.length === 0`

### Admin — blocked days in location assignment form

- Location Assignment day chips: days taken by other locations shown in
  amber with 🔒 and tooltip
- Default Schedule day chips: days assigned to any location shown in amber
- Location dropdown: removed filter hiding already-assigned locations

---

## 2026-06-29 — Scheduling Phase 3A, timezone fix, appointments RLS

### Scheduling Phase 3A — location-driven schedule (live)

Full implementation of Doctor → Location → Available Days → Time Slots flow.

**`app/calendar/page.tsx` — full rebuild:**

- `DoctorLocation` interface; `doctor_locations` fetched in `load()`
- `getActiveDoctorLoc()`, `getAvailDays()`, `getCapacity()`,
  `getLocationsForDoctor()` helpers
- Location picker above Time Slot
- Slot generation reads `start_time`, `slot_minutes`, `capacity`

### Timezone fix — `localDateStr()` helper

All `toISOString()` date-building calls replaced with `localDateStr(d)`.

### RLS — authenticated policies added to `appointments`

---

## 2026-06-28 — Auth foundation, Phase 3 location picker, RLS authenticated fix

### Authentication — full implementation

- `user_profiles` table (migration 012)
- 4 test users (PIN `9999` → now `999999`): fd, admin, billing, md
- `lib/supabase.ts`: auth helpers
- `app/page.tsx`: email + PIN login, location picker for MD
- `middleware.ts`: cookie-based route protection
- Sign Out on all dashboards

### RLS — authenticated role added to all tables

### Scheduling Phase 3 Option B — live

---

## 2026-06-28 — Admin dashboard expansion: Overview, CPT/ICD-10, Locations, Scheduling Phase 1+2

### Admin — Overview tab, CPT Codes + ICD-10 tabs, Providers improvements

### Database migrations

- `010`: `practice_settings` + `office_locations`
- `011`: `doctor_locations`; `appointments.location_id` FK
