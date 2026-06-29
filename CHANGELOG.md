# Changelog

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
- `isDayAvailable` guards on `doctorLocations.length === 0` to prevent
  false availability during initial render
- Result: unassigned days (Tue/Thu for Dr. Gottesman) correctly greyed out

### Admin — blocked days in location assignment form

- Location Assignment day chips: days taken by other locations shown in
  amber with 🔒 and tooltip naming the owning location
- Default Schedule day chips: days assigned to any location shown in amber
  with 🔒; message explains location assignments override default schedule
- Location dropdown: removed filter that was hiding already-assigned
  locations, which caused shadcn Select to display blank after selection

---

## 2026-06-29 — Scheduling Phase 3A, timezone fix, appointments RLS

### Scheduling Phase 3A — location-driven schedule (live)

Full implementation of Doctor → Location → Available Days → Time Slots flow.
No migration required — `doctor_locations` already had `days_of_week`,
`start_time`, `end_time`, `slot_minutes`, `capacity` from migration 011.

**`app/calendar/page.tsx` — full rebuild:**

- `DoctorLocation` interface; `doctor_locations` fetched in `load()`
- `getActiveDoctorLoc()`, `getAvailDays()`, `getCapacity()`,
  `getLocationsForDoctor()` helpers — all with `doctors` table fallback
- Location picker moved above Time Slot (Doctor → Location → Patient →
  Time Slot order)
- Each location card shows schedule inline: days · hours · capacity
- Location selection forces calendar jump to next valid day (`force=true`)
- `jumpToDoctorAvailability` gained optional `force` param
- Quick-pick chips and grid capacity synced via `filterDocId`
- Slot generation reads `start_time`, `slot_minutes`, `capacity` from
  active `doctor_locations` row
- Locked doctor (`?doctor_id=` param) writes into `bookForm.doctor_id`
  on mount
- Grid cell onClick: form stays open when changing date, only closes on
  deselect (tapping same date again)
- `handleBook`: insert before state reset; `await load()` replaces
  `window.location.reload()`
- `load()` fetches ±2 week window to survive weekOffset drift

### Timezone fix — `localDateStr()` helper

All `toISOString()` date-building calls replaced with `localDateStr(d)`
which reads local year/month/day. Fixes UTC/EDT offset causing dates to
display one day off.

### RLS — authenticated policies added to `appointments`

`appointments` table had RLS enabled with `anon`-only policies; logged-in
users got zero rows silently. Fixed with 4 authenticated policies (SELECT,
INSERT, UPDATE, DELETE).

---

## 2026-06-28 — Auth foundation, Phase 3 location picker, RLS authenticated fix

### Authentication — full implementation (replaces stop-gap role selector)

- `user_profiles` table (migration 012): links `auth.users` → role +
  `doctor_id` + `full_name` + `pin_hint`. RLS: own-row SELECT only.
- 4 test users in Supabase Auth (PIN `9999`): `fd@cosmos.local` (frontdesk),
  `admin@cosmos.local` (admin), `billing@cosmos.local` (billing),
  `md@cosmos.local` (md → Dr. Yury Gottesman)
- `lib/supabase.ts`: `signIn()`, `signOut()`, `getSession()`,
  `getUserProfile()` helpers added alongside existing anon client
- `app/page.tsx`: full replacement — email + PIN login form, post-login
  profile fetch, location picker for MD with multiple locations (auto-skip
  when 0 or 1 location), session-based role routing
- `middleware.ts` (new): cookie-based route protection
- Sign Out button added to all 4 dashboards
- `app/md/page.tsx`: simplified — `?doctor_id=` URL param is reliable path
- `app/md/MDClient.tsx`: test dropdown removed

### RLS — authenticated role added to all tables

`office_locations`, `practice_settings`, `doctor_locations`, `cpt_codes`,
`icd10_codes` updated to `TO anon, authenticated`.

### Scheduling Phase 3 Option B — live

Location picker added to booking form; `location_id` saved with appointments.

---

## 2026-06-28 — Admin dashboard expansion: Overview, CPT/ICD-10 tables, Locations, Scheduling Phase 1+2

### Admin — Overview tab (new)
- 6 KPI cards, Practice Info, Office Locations manage UI, Recent Providers

### Admin — CPT Codes + ICD-10 tabs (new)
- Full CRUD, CSV import, filter by provider type

### Admin — Providers tab improvements
- Location Assignments sub-section with per-location schedule

### Database migrations
- `010`: `practice_settings` + `office_locations` with full anon RLS
- `011`: `doctor_locations` junction table; `appointments.location_id` FK
