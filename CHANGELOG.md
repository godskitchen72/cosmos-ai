# Cosmos Medical Technologies — CHANGELOG

Append-only. Entries in reverse chronological order. Never renumber,
never delete. Each entry records only what actually shipped — not what
was planned or considered.

---

## 2026-07-04 — Session 12

### Enterprise Hardening — RLS full audit and hardening

Full audit of all RLS policies. All `anon` and `public` policies removed
from every table. Every table now locked to `authenticated` only.

Tables hardened: `patients`, `patient_forms`, `patient_visits`,
`visit_line_items`, `appointments`, `doctors`, `insurance_carriers`,
`lawyers`, `cpt_codes`, `icd10_codes`, `office_locations`,
`doctor_locations`, `practice_settings`, `user_profiles`, `cpt_icd10_map`,
`_deprecated_cpt_templates`, `_deprecated_icd10_templates`.

Verified: 0 rows returned by anon/public policy query post-migration.

### Enterprise Hardening — NOT NULL constraints (migration 018)

Full null audit before constraining. Four columns constrained:
- `doctors.license_number NOT NULL`
- `doctors.npi NOT NULL`
- `doctors.mailing_state NOT NULL`
- `patient_forms.form_type NOT NULL`

### NF-3 regression fix — place of service + description of treatment

**Root cause:** Dead doctor address columns (`street/city/zip` dropped in
migration 014) silently returned empty strings. `main.py` had no fallback
when `visit.location_id` was null.

**`main.py`:** Place of service now falls back to MD's assigned
`doctor_locations` when `visit.location_id` is null. Prefers
`is_main_office = true`, else first assigned location.

**`database.py`:** Dead doctor address column references removed.

### MRI Referral — extremity studies, contrast, metal implant gate

Full rebuild of `app/md/[patientId]/mri/MriReferral.tsx`:
- Metal implant contraindication toggle (YES/NO) at top of form
- YES collapses and disables MRI Spine, MRI Extremities, Contrast, MRA
- CT section always active; labeled "← Required (metal implant)" when YES
- Extremity Studies table: Left/Right per body part (Shoulder, Elbow,
  Wrist, Hip, Knee, Ankle) — maps to `mri.left_*`/`mri.right_*`
- Contrast: Without / With & Without — maps to `contrast.type`
- Insurance (carrier, policy_num) auto-read from patient, passed to PDF
  silently — not shown in UI per product decision

### CPT codes filtered by provider license type

**`app/page.tsx`:** `fetchLicenseType(doctorId)` added — reads
`license_type` from `doctors` at login, stored as `cosmos_license_type`
in sessionStorage.

**`app/md/[patientId]/PatientChart.tsx`:** `useEffect` reads
`cosmos_license_type` post-hydration. `filteredCptCodes` filters by
`provider_type === licenseType`. Falls back to all codes if unset.

Result: MD sees only MD-tagged CPT codes; PT sees only PT-tagged codes.
Zero unassigned CPT codes — hard filter has no edge cases.

### CosmosUI — universal notification standard

New file: `app/components/ui/CosmosUI.tsx`

Exports: `toastSuccess()`, `toastError()`, `toastInfo()`,
`cosmosConfirm()`, `ToastContainer`, `AlertModal`, `ConfirmModal`

Standard adopted:
- All notifications (success + error) → `AlertModal` — dark background,
  cyan border (`#00cfff60`), cyan message text, single OK button
- Destructive confirmations → `ConfirmModal` — cyan border, Cancel (cyan)
  + Delete (red) buttons
- Native `alert()` and `confirm()` eliminated app-wide

Adopted in: `admin/page.tsx` (15 instances), `BillerDashboard.tsx`
(8 instances), `PatientProfile.tsx` (2 instances), `MriReferral.tsx`
(1 instance), `dev/page.tsx` (1 instance).

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

- All 7 existing W9 PDFs deleted from `patient-forms` storage bucket
- `w9_url` nulled on all doctor records
- W9 regenerated for 3 eligible providers: Carrey, Gottesman, Kramer
- 4 supervised providers confirmed with no W9

### NF-3 Section 16 — license number replaces NPI

**`forms/nf3.py`:**
- `license_number` parameter added to `_p2_vals()` signature
- `treating_provider.1.license_or_certification_number` now uses `license_number`
- NPI fallback removed entirely
- Correct key: `patient_data.get("doctor_license_number")`

### Admin — license number required field

**`admin/page.tsx` `validate()`:**
- `if (!form.license_number) e.license_number = 'Required'`
- `else if (form.license_number.length < 6) e.license_number = 'Minimum 6 characters'`

### AOB — always uses billing entity

**`forms/aob.py`:**
- Provider name: `doctor_pc_corp_name` → `supervisor_name` → `doctor_name`
- Provider address: `doctor_mailing_address` (resolves to supervisor's when supervised)
- Provider signature: `supervisor_signature_url` → `doctor_signature_url` fallback

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
save handlers.

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
use `license_type` parameter.

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
- `app/page.tsx`: `navigate()` stores `cosmos_location_name` in sessionStorage
- `app/md/MDClient.tsx`: `📍 {locationName}` badge in green under heading
- `app/calendar/page.tsx`: `📍 {locationName}` badge under "Showing your schedule only"

### Union-of-locations availability

- `getDoctorLocs()`, `getAvailDaysForDoctor()` helpers added
- Grid/chips use union of all assigned location days

### Admin — blocked days in location assignment form

- Location Assignment day chips: days taken by other locations shown in amber with 🔒
- Default Schedule day chips: days assigned to any location shown in amber

---

## 2026-06-29 — Scheduling Phase 3A, timezone fix, appointments RLS

### Scheduling Phase 3A — location-driven schedule (live)

Full implementation of Doctor → Location → Available Days → Time Slots flow.

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
