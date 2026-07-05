## 2026-07-05 — Session 17

### NF-3 workflow redesign — full implementation

**Product decision:** NF-3 generation moves from FD to Biller. FD becomes
validation-only via a preflight check.

**Migrations:**
- `020`: `patient_visits.nf3_preflight_passed boolean DEFAULT false` +
  `biller_md_flags` table (visit_id, patient_id, flagged_by, flag_reason,
  flag_note, resolved_at) + RLS
- `021`: `biller_md_flags.suggested_cpt_codes text[]`,
  `suggested_icd10_codes text[]`
- `022`: `biller_md_flags.resolution text`, `rejection_note text`,
  `biller_dismissed_at timestamptz`

**`PatientProfile.tsx`** — NF-3 card replaced with preflight modal. Checks
8 required fields (signature, carrier, claim #, policy #, DOI, attorney, CPT,
ICD-10). "Confirm Ready" writes `nf3_preflight_passed = true`. Submission
gate updated: `hasNf3` → `nf3_preflight_passed`. NF-3 generation handlers
removed.

**`BillerDashboard.tsx`** — `+ NF-3` badge generates NF-3 per visit; flips
to tappable `NF-3` when generated. `⚑ Flag MD` button opens `FlagMdModal`
with simplified reasons (Missing/Incorrect CPT, Missing/Incorrect ICD-10)
and full code library pickers. Suggested codes shown in amber (⏳) in CPT
and ICD-10 columns. Rejected flags show `↩ MD Rejected` with Dismiss ×
button. `dismissFlag` callback writes `biller_dismissed_at`.

**`billing/page.tsx`** — Added `cpt_codes` and `icd10_codes` fetches.
`biller_md_flags` query updated to fetch pending + rejected-undismissed
flags. Added `resolution`, `rejection_note`, `biller_dismissed_at` to select.

**`MDClient.tsx`** — Persistent amber flag alert card at top of dashboard.
Shows patient, visit date, reason, note, suggested CPT and ICD-10 codes.
Navigation URL includes `?visit_id=` so PatientChart loads in UPDATE mode
for the flagged visit.

**`PatientChart.tsx`** — Biller flag strip rendered when `visit_id` URL
param matches an open flag. Shows suggested codes. Accept & Apply pre-fills
code pickers (additive). Reject writes `resolved_at + resolution: rejected +
rejection_note`. Auto-resolves as `accepted` when visit saves after accept.

### IcdReferral.tsx — Authorization header fix

`app/md/[patientId]/icd10/IcdReferral.tsx` was missing `getAuthToken()` and
`Authorization: Bearer` header. Both added. All other referral screens
confirmed correct.

### Biller docs column layout

Docs column badges (NF-3, AOB, PCE, W9, Flag MD) now render in a single
horizontal `nowrap` row. Final fix uses inline `style={{ flexWrap:'nowrap' }}`
after Tailwind `flex-col`/`flex-row` classes were pruned by the build.

---

## 2026-07-05 — Session 16

### Documentation update only

No code written or deployed this session.

Updated documents:
- `CHANGELOG.md` — Session 15 entries added (dev tools rebuild + W9 supervisor-chain fix)
- `ARCHITECTURE.md` — Migrations 017–019 added to §3 migration list; §10 login flow updated to reflect Session 14 fix (location picker now always shown for MD/PA/NP regardless of location count)
- `HANDOVER.md` — Session 15 → Session 16

---

## 2026-07-04 — Session 15

### Dev Tools — full rebuild (`app/dev/page.tsx`)

Complete rewrite of the dev data generator. All features confirmed
working in production:

- **Real doctors, carriers, lawyers** from live database tables
- **Visit count selector** — None / 1 / 2 / 3 / 5 visits per patient;
  each visit dated randomly across recent weeks
- **DOI guard** — visit dates clamped to always be after the patient's DOI
- **Live CPT codes** — fetched from `cpt_codes` table, random-sampled per
  visit; fallback to hardcoded sets if table is empty
- **Max MD mode** — samples up to 8 codes from the live pool instead of 3–6
- **Individual referral selector** — None / All 9 shortcut chips plus
  individual toggles for each of the 9 referral types (MRI, VNG, Rx, DME,
  ANS, ICD-10, PT, Ortho, Pain Mgmt)
- **Per-patient Render warm-up** — `/health` ping before each patient's
  referral batch eliminates cold-start fetch failures between patients
- **1.2s delay between referral calls** — prevents Render from dropping
  sequential connections
- **Chip component** — extracted as a proper React component with explicit
  color/border/background on both active and inactive states (fixes
  preflight-gap dark text bug)
- **Results panel** — color-coded by indent level: patient (green), visit
  (orange), referral OK (bright green), error (red), done (cyan)

### Billing — W9 supervisor-chain fix (`BillerDashboard.tsx`, `billing/page.tsx`)

**Root cause:** W9 badge used `patient.doctor_id → doctor.w9_url` join.
Supervised providers (PA, NP) have no `w9_url` — their billing entity
is the supervising MD. Join returned null, showing grey W9 badge even
when the supervisor's W9 existed.

**Fix:**
- `billing/page.tsx` — `supervising_provider_id` added to doctors select
- `BillerDashboard.tsx` — `Doctor` interface updated; `rows` useMemo
  computes `resolvedW9` (`own w9_url → supervisor's w9_url` fallback),
  exposes it as `doctorWithW9` on each `RowData` row; W9 `DocBadge`
  reads `doctorWithW9?.w9_url`

**Status:** Patch confirmed applied (all node script checks OK).
`tsc --noEmit` + deploy chain pending — first task of Session 16.

---

## 2026-07-04 — Session 14

### CosmosUI standard — PatientProfile.tsx complete

All `alert()` and `confirm()` calls converted. `ConfirmModal` mounted
(was missing). `cosmosConfirm` gates all regenerate/undo actions (NF-2,
AOB, NF-3, PCE). Dead `nf3Msg` state and `setTimeout` no-op removed.
Amber NF-3 warning strip removed — locked card tap fires `toastError`.

### Session 13 regression fixes

**NF-2/AOB generation restored** — `generateForm()` helper was missing
`Authorization: Bearer` header from Session 13 JWT sweep. Added `token`
parameter; `await getAuthToken()` passed from both call sites.

**MD/PA/NP location picker always shown** — `locs.length > 1` bypass
removed from `app/page.tsx`. Picker always shown for MD/PA/NP roles
regardless of location count.

### Blank signature guard — all SignaturePad components

`isCanvasBlank()` pixel check added to `save()` in `PatientProfile.tsx`
and `admin/page.tsx`. Blank canvas fires `toastError` instead of saving
empty PNG.

### NP/PA CPT code mapping

`PatientChart.tsx`: `effectiveLicenseType` maps NP and PA to MD at the
filter level. No data duplication. Debug `console.log` removed.

### CPT import — Option A architecture + error handling

`handleCptImportConfirm` rebuilt:
- Deduplicates CPT rows by `cpt_code` before upsert (was root cause of
  silent batch failure with multi-ICD-10 CSVs)
- Upserts ICD-10 codes to `icd10_codes` (deduplicated by `code`)
- Upserts mappings to `cpt_icd10_map` on `(cpt_code, icd10_code)` —
  idempotent, re-import safe
- Full `toastError` on all three upsert operations
- Success toast confirms CPT, ICD-10, and mapping counts

**RLS fix:** `icd10_codes` missing `authenticated` INSERT/UPDATE policy —
discovered via new error surfacing. Fixed with full `ALL` policy.

### CPT import — Download Template link

"⬇ Download Import Template" link added below Import CSV button in
`CptCodesSection`. Client-side blob URL, no server dependency.

---

## 2026-07-04 — Session 13

### `forms/mri.py` — full backend audit

Obtained and audited for the first time. All Session 12 frontend keys
confirmed correctly wired. No backend changes required.

### MRI Spine order fix

`MRI_SPINE` array reordered to clinical standard:
Cervical → Thoracic → Lumbar (was Cervical → Lumbar → Thoracic).

### CosmosUI standard — fully adopted app-wide

All remaining referral screens migrated:
- `DmeReferral.tsx` — `cosmosConfirm`, `AlertModal`/`ConfirmModal` mounted
- `OrthoReferral.tsx`, `PainMgmtReferral.tsx`, `VngReferral.tsx`,
  `RxReferral.tsx`, `PtReferral.tsx`, `AnsReferral.tsx` — `cosmosConfirm`,
  `AlertModal`/`ConfirmModal` mounted, `toastError` replacing inline error divs
- `app/calendar/page.tsx` — `cosmosConfirm`, `AlertModal`/`ConfirmModal` mounted

`SessionTimeoutModal` added to `CosmosUI.tsx`.

Native `alert()`/`confirm()` now eliminated app-wide.

### Enterprise Hardening Stage 2 — API JWT authentication

All 15 `cosmos-api` POST endpoints protected with `verify_jwt` FastAPI
dependency. Calls Supabase `/auth/v1/user` to verify Bearer token.
Returns HTTP 401 for unauthenticated requests.

- `cosmos-api/main.py`: `verify_jwt` function, `Depends` on all 15 routes
- `cosmos-api/requirements.txt`: `httpx` added
- Render env: `SUPABASE_ANON_KEY` added
- All frontend `cosmos-api` fetch calls: `Authorization: Bearer` header added
  via `getAuthToken()` helper injected into every calling file

### Enterprise Hardening Stage 2 — Session timeout

Inactivity-based auto sign-out implemented.

- `app/hooks/useSessionTimeout.ts`: new hook
- Migration 019: `practice_settings.session_timeout_minutes int NOT NULL DEFAULT 15`
- Admin panel: Session Timeout selector added to Practice Settings
- Superadmin exempt: `'0'` written at login, hook disabled for that session
- Mounted on: `DashboardClient.tsx`, `MDClient.tsx`, `admin/page.tsx`,
  `BillerDashboard.tsx`

### `forms/dme.py` — backend audit

Obtained and audited. All frontend keys confirmed correctly wired.

### Patch script cleanup

All accumulated `~/patch_*.py`, `~/remove_*.py`, `~/wire_*.py`,
`~/write_*.py` scripts from previous sessions deleted.

---

# Cosmos Medical Technologies — CHANGELOG

Append-only. Entries in reverse chronological order. Never renumber,
never delete. Each entry records only what actually shipped — not what
was planned or considered.

---

## 2026-07-04 — Session 12

### Enterprise Hardening — RLS full audit and hardening

Full audit of all RLS policies. All `anon` and `public` policies removed
from every table. Every table now locked to `authenticated` only.

Verified: 0 rows returned by anon/public policy query post-migration.

### Enterprise Hardening — NOT NULL constraints (migration 018)

- `doctors.license_number NOT NULL`
- `doctors.npi NOT NULL`
- `doctors.mailing_state NOT NULL`
- `patient_forms.form_type NOT NULL`

### NF-3 regression fix — place of service + description of treatment

`main.py`: Place of service falls back to MD's assigned `doctor_locations`
when `visit.location_id` is null. `database.py`: Dead doctor address column
references removed.

### MRI Referral — extremity studies, contrast, metal implant gate

Full rebuild of `MriReferral.tsx`: metal implant toggle, extremity studies
table, contrast selector, insurance auto-read.

### CPT codes filtered by provider license type

`fetchLicenseType()` at login; `filteredCptCodes` in `PatientChart.tsx`.

### CosmosUI — universal notification standard

New file: `app/components/ui/CosmosUI.tsx`. Exports: `toastSuccess()`,
`toastError()`, `toastInfo()`, `cosmosConfirm()`, `ToastContainer`,
`AlertModal`, `ConfirmModal`.

---

## 2026-07-04 — Session 11

### NF-3 — Patient signature gate

NF-3 generate locked until `patient_signature_url` is on file.

### W9 — entity-based scoping rule

W9 applies only to: `!supervising_provider_id AND (!!pc_corp_name OR tax_classification === 'individual')`.

### NF-3 — supervisor W9 routing for supervised providers

After doctor merge, supervisor's W9 injected into `patient_data` when
`supervising_provider_id` is set.

### NF-3 Section 16 — license number replaces NPI

`treating_provider.1.license_or_certification_number` now uses
`doctor_license_number`, not NPI.

### AOB — always uses billing entity

Provider name/address/signature all resolve to billing entity per priority
chain.

---

## 2026-07-03 — Session 10

### `forms/base.py` — removed all `except Exception: pass`

### `w9_filler.py` removed

### PDF filename casing normalized

All 15 PDF templates now use uppercase filenames consistently.

### FK constraint audit — Stage 1 complete

Added FK constraints on `appointments`, `patient_visits`, `visit_line_items`.

### NF-3 full regression — all scenarios passed

---

## 2026-06-29 — Phase 4, union availability, location badge, Admin day blocking

### Scheduling Phase 4 — MD login location pre-filters calendar

### Union-of-locations availability

### Admin — blocked days in location assignment form

---

## 2026-06-29 — Scheduling Phase 3A, timezone fix, appointments RLS

### Scheduling Phase 3A — location-driven schedule (live)

### Timezone fix — `localDateStr()` helper

### RLS — authenticated policies added to `appointments`

---

## 2026-06-28 — Auth foundation, Phase 3 location picker, RLS authenticated fix

### Authentication — full implementation

### RLS — authenticated role added to all tables

### Scheduling Phase 3 Option B — live

---

## 2026-06-28 — Admin dashboard expansion: Overview, CPT/ICD-10, Locations, Scheduling Phase 1+2

### Admin — Overview tab, CPT Codes + ICD-10 tabs, Providers improvements

### Database migrations

- `010`: `practice_settings` + `office_locations`
- `011`: `doctor_locations`; `appointments.location_id` FK
