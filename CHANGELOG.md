# Changelog

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
  when 0 or 1 location), session-based role routing with `sessionStorage`
  for `cosmos_doctor_id` + `cosmos_location_id`
- `middleware.ts` (new): cookie-based route protection, redirects
  unauthenticated requests to `/`; public paths: `/`, `/_next`, `/favicon`,
  `/cosmos_`, `/dev`
- Sign Out button added to all 4 dashboards: `DashboardClient.tsx`,
  `MDClient.tsx`, `BillerDashboard.tsx`, `admin/page.tsx` — all call
  `signOut()` before redirect
- `app/md/page.tsx`: simplified — removed `createServerComponentClient`
  (not exported by installed `@supabase/auth-helpers-nextjs` version);
  `?doctor_id=` URL param from login screen is the reliable scoping path
- `app/md/MDClient.tsx`: "⚠ Test Only — Simulate MD Login" dropdown
  removed; `signOut` import added

### RLS — authenticated role added to all tables

Supabase Auth changes request role to `authenticated` for logged-in users;
prior `anon`-only policies caused silent empty reads. All policies on
`office_locations`, `practice_settings`, `doctor_locations`, `cpt_codes`,
`icd10_codes` updated to `TO anon, authenticated`.

### Scheduling Phase 3 Option B — live

- `office_locations` fetched in calendar `load()` alongside doctors/patients
- `location_id` added to `bookForm` state + `appointments` insert
- Location picker (button-chip cards) added to booking form below Notes
- `sessionStorage` pre-select for MD login-time location
- "No location / unassigned" fallback option
- Phase 3 Option A (location-driven schedule) approved for next session:
  `doctor_locations` needs `available_days` + `max_patients_per_day` columns;
  calendar flow becomes Location → Schedule → Availability → Slots

### `@supabase/auth-helpers-nextjs` installed (2 packages)

Required for middleware cookie-based session read. Version installed does
not export `createServerComponentClient` — use `createServerClient` if
server-component session reads are needed in future.

---

## 2026-06-28 — Admin dashboard expansion: Overview, CPT/ICD-10 tables, Locations, Scheduling Phase 1+2

### Admin — Overview tab (new)
- 6 KPI cards (2×3): Total Providers, Documents, Total Patients, Total Visits,
  Office Locations (all real/live), Active Users (placeholder)
- Quick Access shortcuts (Providers, Carriers, Lawyers, CPT Codes, Dev Tools)
  moved to top of Overview — action-first layout
- Practice Info card: inline edit, saves to new `practice_settings` table
  (NF-3-ready fields: practice name, corp name, TIN, tax classification,
  address, phone, fax)
- Office Locations manage UI: add/delete locations inline, saved to
  `office_locations` table, displayed as list with full address
- Recent Providers list: last 5 by date added, license_type badge
  (color-coded per discipline), specialty, supervisor name

### Admin — CPT Codes tab (new)
- Full CRUD for `cpt_codes` table
- Filter by provider type (All / General / MD / DC / PT / Acupuncturist /
  Psychologist / Podiatrist)
- Grouped display by `provider_type`
- CSV import: client-side parse, preview modal with provider type selector,
  upserts into `cpt_codes` + simultaneously imports paired ICD-10 codes

### Admin — ICD-10 tab (new)
- Full CRUD for `icd10_codes` table
- Search across code, description, category
- Grouped by `category`, CSV import (ICD-10-only variant)

### Admin — Providers tab improvements
- Add Provider moved to top
- Edit form auto-scrolls into view; renders above provider list
- Schedule tab: "Default Schedule" label added; new Location Assignments
  sub-section — assign doctor to office locations with per-location
  days/hours/capacity (writes to `doctor_locations` table)

### Admin — Carriers/Lawyers tab improvements
- Add Carrier / Add Lawyer buttons moved to top of each section

### Admin — visual polish
- Scrollable tab strip (6 tabs: Overview, Carriers, Providers, Lawyers,
  CPT Codes, ICD-10)
- Header subtitle: "Manage Lookup Tables" → "Table Management"
- Cyan borders (`border-[#00cfff30]`) on all list item cards
- Cyan-tinted Edit buttons, red-tinted Del buttons throughout

### Database migrations
- `010`: `practice_settings` (single-row, id=1 constraint) + `office_locations`
  tables, both with full anon RLS (4 policies each)
- `011`: `doctor_locations` junction table (doctor_id + location_id +
  per-location schedule fields); `appointments.location_id` FK column added;
  unique constraints on `cpt_codes(cpt_code)` and `icd10_codes(code)`
- RLS added to `cpt_codes` (was missing all 4 anon policies — root cause of
  CPT tab showing empty) and `icd10_codes` (4 granular policies added
  alongside pre-existing "Allow all" policy)

### Scheduling — Phase 1+2
- Schema: `doctor_locations`, `appointments.location_id` (Phase 1 complete)
- Admin UI: Doctor Schedule tab now has Location Assignments section (Phase 2 complete)
- Phase 3 (calendar location selector) and Phase 4 (MD login location picker):
  deferred to next session
