# Cosmos Medical Technologies — CHANGELOG

Append-only. Entries in reverse chronological order. Never renumber,
never delete. Each entry records only what actually shipped — not what
was planned or considered.

---

## 2026-07-04 — Session 11

### NF-3 — Patient signature gate

NF-3 generate locked until `patient_signature_url` is on file.

**`PatientProfile.tsx`:**
- `canGenerateNF3 = has(patient, 'patient_signature_url')`
- NF-3 card `blocked` state: `!selectedVisit ? 'Select a visit' : !canGenerateNF3 ? 'No signature' : null`
- Tapping a locked card triggers `setNf3Msg(blocked)` with 3-second auto-clear
- Message strip renders below the forms grid (outside the 4-column grid)
- NF-3 error handlers converted from `alert()` to inline `nf3Msg` state

**`main.py`:**
- `/generate/nf3` returns HTTP 400 `"Patient signature required to generate NF-3"` if `patient_signature_url` missing

### Admin — dropdown contrast fixed globally

All `SelectContent` in `admin/page.tsx`:
- Changed from `bg-card` to `bg-[#1a2235] border-[#2a3a5a] text-[#e2e8f0]`

All `SelectItem` in `admin/page.tsx`:
- Changed from `text-foreground focus:bg-muted` to `text-[#e2e8f0] focus:bg-[#00cfff20] focus:text-white`
- 12 SelectContent and 14 SelectItem instances fixed

### Admin — Save Provider gated on location assignment

- `Save Provider` disabled when `docLocations.length === 0` for existing providers
- Button label changes to `"Assign a location first"`
- Warning prompt added in Schedule tab when no locations assigned

### Admin — New provider two-step flow

- New provider (`editing === 'new'`) exempt from location gate
- Button label: `"Save & Continue"` for new providers
- After successful insert: `setEditing(id); setDocTab('schedule')` — reopens on Schedule tab
- "LOCATION ASSIGNMENTS (SAVE PROVIDER FIRST)" hint shown on Schedule tab for new providers

### W9 — entity-based scoping rule

Business rule established and implemented:
- W9 applies only to: `!supervising_provider_id AND (!!pc_corp_name OR tax_classification === 'individual')`
- Supervised providers → no W9 regardless of license type

**`admin/page.tsx`:**
- Auto-W9 on creation gated by `needsW9` const
- W9 View and Regenerate buttons hidden for non-billing-entity providers

**`main.py` `/generate-w9`:**
- Returns HTTP 400 for supervised providers or providers without billing entity status

### NF-3 — supervisor W9 routing for supervised providers

**`main.py` `generate_pdf`:**
- After doctor merge, if `supervising_provider_id` set, fetches supervisor's W9
- Injects supervisor's `w9_url`, `billing_entity_name`, `billing_tax_id` into `patient_data`

### W9 cleanup and regeneration

- All 7 existing W9 PDFs deleted from `patient-forms` storage bucket via Storage REST API
- `w9_url` nulled on all doctor records: `UPDATE doctors SET w9_url = NULL`
- W9 regenerated for 3 eligible providers: Carrey, Gottesman, Kramer
- 4 supervised providers (NPian, Orthobot, PAian, Pearlman) confirmed with no W9

### NF-3 Section 16 — license number replaces NPI

**`forms/nf3.py`:**
- Added `license_number` parameter to `_p2_vals()` signature
- `treating_provider.1.license_or_certification_number` now uses `license_number`
- NPI fallback removed entirely
- Correct key: `patient_data.get("doctor_license_number")` (prefixed by `database.py`)

### Admin — license number required field

**`admin/page.tsx` `validate()`:**
```
if (!form.license_number) e.license_number = 'Required'
else if (form.license_number.length < 6) e.license_number = 'Minimum 6 characters'
```

### AOB — always uses billing entity

**`forms/aob.py`:**
- Provider name: `doctor_pc_corp_name` → `supervisor_name` → `doctor_name` (priority order)
- Provider address: `doctor_mailing_address` (resolves to supervisor's when supervised)
- Provider signature: `supervisor_signature_url` → `doctor_signature_url` fallback
- Treating provider name/address/signature never used for supervised providers

---

## 2026-07-03 — Session 10

### `forms/base.py` — removed all `except Exception: pass`

All silent exception swallowing eliminated from `forms/base.py`.

### `w9_filler.py` removed

Legacy 120-line duplicate of `forms/w9.py` deleted from `cosmos-api` root.

### PDF filename casing normalized

`ortho.pdf` → `ORTHO.pdf`, `pain_mgmt.pdf` → `PAIN_MGMT.pdf`.
All 15 PDF templates now use uppercase filenames consistently.

### Admin — Edit Provider/Carrier header shows name in green

Provider edit form: `Edit Provider: Dr. {first} {last}` with name in green.
Carrier edit form: `Edit Carrier: {carrier_name}` with name in green.

### Admin — backend save errors surfaced inline (all sections)

Silent Supabase failures now show red inline error messages on all Admin
save handlers. Side effect: exposed missing RLS policy on `insurance_carriers`.

### Admin — Insurance Carriers expanded

Three new columns: `claims_department`, `street2`, `claims_email`.
CSV batch import added. Top 20 NY No-Fault carriers imported.

### MD Dashboard — logged-in doctor name in header

`MDClient.tsx` header: `👤 Dr. [Name]` (cyan) above `📍 [Location]`.

### FD Dashboard — assigned provider on patient cards

Patient cards show provider name in cyan with license type.

### FK constraint audit — Stage 1 complete

Added FK constraints on `appointments`, `patient_visits`, `visit_line_items`.

### NF-3 — Section 16 title fix

`_p2_vals()` was hardcoding `"treating_provider.1.title": "MD"`. Fixed to
use `license_type` parameter from `patient_data.get('doctor_license_type')`.

### `database.py` — independent provider supervisor fallback fix

Supervisor fields now default to doctor's own values for independent MDs.

### `patients.signature_url` column removed

Data migrated to `patient_signature_url`. All consumers updated.

### Dev generator — `doctor_id` assigned to generated patients

Fixed `app/dev/page.tsx` to write both `doctor_name` and `doctor_id` on INSERT.

### NF-3 full regression — all scenarios passed

Three provider scenarios verified: independent MD, supervised PA, independent
MD with own PC corp.

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
