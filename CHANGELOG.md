# Changelog

## 2026-07-03 — Session 10: FK audit, base.py fix, Admin polish, carrier import, provider display

### `forms/base.py` — all `except Exception: pass` removed

- `requests` import failure: now logs `WARNING: requests not available: {e}`
- `fitz` import failure: now logs `WARNING: fitz (PyMuPDF) not available: {e}`
- `render_visible_text_in_rect`: `except Exception: pass` → logs error
- `format_date` inner loop and outer catch: both now log parse errors

### `w9_filler.py` deleted from `cosmos-api` root

120-line legacy duplicate of `forms/w9.py`. Nothing imported it.

### PDF template filenames normalized to uppercase

`ortho.pdf` → `ORTHO.pdf`, `pain_mgmt.pdf` → `PAIN_MGMT.pdf`.
Updated `forms/ortho.py` line 44 and `forms/pain_mgmt.py` line 42.

### `insurance_carriers` — new columns + RLS fix

```sql
ALTER TABLE insurance_carriers
  ADD COLUMN IF NOT EXISTS claims_department text,
  ADD COLUMN IF NOT EXISTS street2 text,
  ADD COLUMN IF NOT EXISTS claims_email text;

CREATE POLICY "authenticated all insurance_carriers"
ON public.insurance_carriers FOR ALL TO authenticated
USING (true) WITH CHECK (true);
```

### `app/admin/page.tsx` — inline save error feedback

All Admin save handlers now surface backend errors as red inline messages
below the Save button. Previously all were silent on failure. Sections
updated: Carriers, Lawyers, CPT Codes, ICD-10, Practice Info, Office
Locations, Doctor Location Assignments.

### `app/admin/page.tsx` — carrier CSV batch import

CSV import added to Carriers section (same pattern as CPT/ICD-10):
upload → preview → confirm, skips duplicates by `carrier_name`. Parses
flexible column headers. Accepts `.csv` files. Three new fields added to
Add/Edit form and cards: Claims Department, Street Address Line 2, Claims
Email. Carrier name now cyan on cards, `m-0` on all text.

### `app/admin/page.tsx` — Edit Provider / Edit Carrier green name headers

Provider edit form: `Edit Provider: Dr. {first} {last}` with name in green.
Carrier edit form: `Edit Carrier: {carrier_name}` with name in green.

### `app/md/MDClient.tsx` — logged-in doctor name in header

Header now shows `👤 Dr. {name}` (cyan) above `📍 {location}` (green).
`Dr.` prefix only for MD/DO license types.

### `app/dashboard/DashboardClient.tsx` — assigned provider on patient cards

Patient cards show: `PT336816 · Progressive · Dr. Yury Gottesman (MD)`.
Implemented via PostgREST join `doctors(first_name, last_name, license_type)`
in client `loadAll`. Handles PostgREST array join shape. `Dr.` prefix only
for `['MD', 'DO']`. Red `⚠ No provider` when `doctor_id` is null.

### FK constraint audit — Stage 1 complete

Added missing FK constraints:

```sql
-- appointments
ALTER TABLE appointments
  ADD CONSTRAINT appointments_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;

-- patient_visits
ALTER TABLE patient_visits
  ADD CONSTRAINT patient_visits_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;

-- visit_line_items
ALTER TABLE visit_line_items
  ADD CONSTRAINT visit_line_items_visit_id_fkey
  FOREIGN KEY (visit_id) REFERENCES patient_visits(id) ON DELETE CASCADE;

ALTER TABLE visit_line_items
  ADD CONSTRAINT visit_line_items_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE;
```

All other FK relationships (`patients.doctor_id`, `appointments.doctor_id`,
`appointments.location_id`, `patient_visits.location_id`,
`doctor_locations.*`, `user_profiles.doctor_id`) were already in place.



## 2026-07-03 — NF-3 full wiring, office location Main Office, PA/NP roles, Admin polish

### Migration 015 — `office_locations.is_main_office`

```sql
ALTER TABLE office_locations
  ADD COLUMN IF NOT EXISTS is_main_office boolean NOT NULL DEFAULT false;
```

Main office sorts first in all queries. Only one location can be main at a
time — enforced on save by clearing all others before setting the new one.

### Migration 016 — `patient_visits.location_id`

```sql
ALTER TABLE patient_visits
  ADD COLUMN IF NOT EXISTS location_id uuid REFERENCES office_locations(id);
```

Written by `handleStartVisit` (`calendar/page.tsx`) using
`apt.location_id || sessionStorage.getItem('cosmos_location_id')`, and by
`PatientChart.tsx` manual visit INSERT using `sessionStorage.getItem('cosmos_location_id')`.
Used by `main.py` to fetch place of service for NF-3 Section 15.

### `database.py` — refactored to shared `_build_doctor_fields()` helper

- New `_build_doctor_fields(d, client)` helper used by both
  `get_doctor_for_patient()` and `get_doctor_by_id()` — no duplicate logic.
- Reads `mailing_street/city/state/zip` (migration 014) for Pay-To address.
- Supervisor fallback: when `supervising_provider_id` is set, fetches
  supervisor row and uses their mailing address + `pc_corp_name` for Pay-To.
- Exports new fields: `doctor_mailing_address`, `doctor_mailing_street/city/
  state/zip`, `doctor_license_type`, `supervisor_npi`, `supervisor_tax_id`,
  `supervisor_specialty`, `supervisor_signature_url`, `supervisor_name`.

### `forms/nf3.py` — full Pay-To / signature / place-of-service wiring

- **Page 1 Pay-To** (`provider.name_address`): PC corp name + mailing address ✅
- **Page 2 Section 15** (place of service): two-line format from
  `place_of_service_address` — `street\ncity, state zip`.
- **Page 2 Section 16**: treating provider title uses `doctor_license_type`
  (PA/NP/MD); license/cert no. uses treating provider's own NPI.
- **Page 3 assignee**: `assignment.provider_assignee_print_name` → PC corp
  name; `assignment.provider_assignee_signature` → supervisor signature image.
- **Page 3 bottom row**: `provider.signature` → supervisor signature;
  `provider.irs_tin` → supervisor name; `provider.wcb_rating_code` →
  supervisor NPI; `provider.specialty_if_none` → supervisor specialty.
- Billing fields (`billing_npi`, `billing_tax_id`, `billing_specialty`) use
  supervisor values when PC corp exists, treating provider's own otherwise.
- `_p2_vals()` signature extended with `billing_npi` parameter (fixes
  `NameError: name 'billing_npi' is not defined` on NF-3 generation).
- Signature injection: both `provider_assignee_signature` and
  `provider.signature` now inject supervisor/billing MD signature.

### `main.py` — office location lookup for place of service

After merging visit row, fetches `office_locations` via `visit.location_id`
and adds `place_of_service_address` (`street\ncity, state zip` two-line
format) to `patient_data`.

### `calendar/page.tsx` — location_id on Start Visit

`handleStartVisit` now writes `location_id: apt.location_id ||
sessionStorage.getItem('cosmos_location_id') || null` into
`patient_visits` INSERT. `Appointment` interface extended with
`location_id?: string`.

### `PatientChart.tsx` — session location on manual visit INSERT

Manual visit INSERT now includes `location_id:
sessionStorage.getItem('cosmos_location_id') || null`.

### `app/admin/page.tsx` — office location Edit + Main Office flag

- Location cards in manage mode now have **Edit** button alongside Del.
- Edit populates form, shows "Edit Location" title, "Save Changes" button.
- Add/Edit form includes custom Main Office toggle (cyan checkbox, explicit
  18×18 px, `accentColor` not used — custom styled for dark background).
- Main office card: cyan border `border-[#00cfff]`, sorted first.
- Other location cards: purple border `border-[#a855f7]`.

### `app/admin/page.tsx` — Admin UI polish

- Practice Info card: `gap-0.5` → `gap-0`, `m-0` on all `<p>` elements.
- Office Location cards: `m-0` on all `<p>` elements.
- Supervisor billing card: `gap-1.5` → `gap-0`, `m-0` on all `<p>` elements.
- Location assignment cards: `m-0` on all `<p>` elements.
- User cards: `gap-3` → `gap-1.5`, font sizes reduced (14px/12px), `m-0`
  on text elements.
- All `SelectTrigger` elements: `style={{color:'#f0f4f8'}}` added explicitly
  — fixes selected-value invisible on dark background (preflight gap).
- Supervised provider border: `border-[#ffffff18]` → `border-[#a855f7]`
  (purple, matching corp name color).

### `app/admin/page.tsx` — PA and NP user roles

- `ROLES` array extended: `['frontdesk', 'md', 'pa', 'np', 'billing', 'admin', 'superadmin']`
- `ROLE_LABELS` map added: human-readable labels for all roles.
- `ROLE_COLORS` extended: PA = `#3b82f6` (blue), NP = `#8b5cf6` (purple),
  Superadmin = `#e74c3c` (red).
- "Linked Doctor" field now shown for MD, PA, and NP roles.
- `doctor_id` not cleared when switching between md/pa/np roles.
- `user_profiles_role_check` constraint updated:
  `CHECK (role IN ('frontdesk', 'md', 'pa', 'np', 'billing', 'admin', 'superadmin'))`

### `app/admin/page.tsx` — supervised provider validation fix

- Mailing address + tax classification fields now optional for supervised
  providers (any provider with `supervising_provider_id` set).
- Form auto-switches to the tab containing the first validation error
  (Billing tab if billing fields fail, Credentials otherwise).

### `app/page.tsx` — PA and NP login routing + location picker

- `ROLE_META` extended with `pa` (blue `#3b82f6`, path `/md`) and
  `np` (purple `#8b5cf6`, path `/md`).
- `navigate()` and `handlePostLogin()`: location picker and
  `cosmos_location_id` sessionStorage storage now applies to
  `['md', 'pa', 'np']` instead of `md` only.

---

## 2026-06-30 — Mailing address, tab merge, PA/NP, grouped provider cards, dev tools fixes

### Migration 014 — mailing address replaces PC/personal address

Dropped from `doctors`: `street`, `city`, `state`, `zip`, `pc_street`,
`pc_city`, `pc_state`, `pc_zip`. Added: `mailing_street`, `mailing_city`,
`mailing_state` (DEFAULT `'NY'`), `mailing_zip`. Mailing address is required
for all providers regardless of tax classification — it is where insurance
companies send payments, denials, and correspondence.

### `forms/w9.py` — reads `mailing_*` columns

Dropped old fallback chain (`pc_street → street`). W-9 address lines now
read `mailing_street`, `mailing_city`, `mailing_state`, `mailing_zip` directly.

### Provider form — General + Credentials tab merge

`General` tab removed. Fields merged into `Credentials` tab:
First/Last Name, License Type, Specialty, Supervising Provider, Email,
Phone, Fax, NPI, License #, Signature. Provider form now has three tabs:
**Credentials** · **Billing** · **Schedule**.

### Billing tab — Mailing Address replaces Registered PC Address

`Registered PC Address` block removed from Billing tab. New **Mailing Address**
block (Street/City/State/Zip) added — always visible regardless of tax
classification. PC Corp Name remains, still conditionally shown for non-individual
tax classifications. Validation: all four mailing address fields are required.

### PA and NP license types

`LICENSE_TYPE_OPTIONS` extended: `NP — Nurse Practitioner`,
`PA — Physician Assistant`. Validation: `license_type === 'NP'` requires
`supervising_provider_id` (NPs must work under a supervising MD). PAs can
have their own PC with no supervisor.

### Provider cards — grouped hierarchy + visual tiers

Doctor list now groups by billing hierarchy: independent/supervising MDs
first (full cyan border), supervised providers indented under their
supervisor (dim border, `ml-4`). Card content: name + inline license
abbreviation, specialty, NPI, corp name (purple), supervisor line (green),
signature status. Short labels for license types: PSY, ACU, POD. No empty
line gaps between card fields (`gap-[3px]` + `m-0`).

### Dev test-data generator — real doctors/carriers/attorneys

`app/dev/page.tsx` `generate()` fetches real records from `doctors`,
`insurance_carriers`, and `lawyers` before generating patients. Falls
back to hardcoded fictional data only if a table returns empty rows.
No more "Yuri Goddesman" or fictional carriers/law firms in generated
test data.

### Wipe-patients endpoint — appointments cascade

`app/api/wipe-patients/route.ts`: `appointments` table now deleted before
`patients` in the cascade chain. Previous gap left orphaned appointment
rows pointing at deleted patients after a data wipe, causing broken
patient-name lookups on the Today Schedule.

---

## 2026-06-29 — Doctor location assignment Edit button, 12h time display

### Location Assignments — Edit capability (new)

- `app/admin/page.tsx` (`DoctorsSection`): added `editingLocId` state and
  `handleEditLocation(dl)` helper. Reuses the existing Add Location form
  and `handleAddLocation`'s upsert (`onConflict: 'doctor_id,location_id'`)
  — no new backend path needed.
- Each Location Assignment card now shows **Edit** alongside **Remove**.
  Edit populates the form with the assignment's existing values and
  opens it in edit mode.
- Location dropdown is locked (read-only display) while editing — only
  the schedule (days/hours/capacity/slot length) can change, not which
  location the assignment points to.
- Save button reads "Save Changes" in edit mode vs. "Assign Location" in
  add mode. Cancel resets `editingLocId` and the form back to blank.

### Location hours — 12-hour display format

- Location Assignment card time display (`{start_time} – {end_time}`)
  changed from 24-hour (`09:00 – 17:00`) to 12-hour with AM/PM
  (`9:00 AM – 5:00 PM`) via `toLocaleTimeString`. Display-only change —
  underlying `start_time`/`end_time` columns remain unchanged (still
  24-hour `time` type in Postgres).

---

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
