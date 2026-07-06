## 2026-07-06 — Session 21

### PDF filename convention — complete

All generated PDFs now follow a structured naming convention.
Implemented in `cosmos-api/main.py` only — no changes to any
`forms/*.py` or `database.py`.

**Convention:**

```
Per-visit documents:   patid_doa_dos_type.pdf
Patient-level docs:    patid_doa_type.pdf
Dates:                 YYYYMMDD (sorts lexicographically = chronologically)
Type tokens:           all lowercase
```

**Full type token map:**

| Document | Token |
|---|---|
| NF-2 | `nf2` |
| NF-3 | `nf3` |
| AOB | `aob` |
| PCE | `init_rpt` |
| ICD-10 Diagnosis PDF | `icd` |
| MRI | `mri` |
| Rx | `rx` |
| DME | `dme` |
| Sono | `sono` |
| ANS | `ans` |
| VNG | `vng` |
| PT | `pt` |
| Ortho | `ortho` |
| Pain Mgmt | `pm` |

**Changes in `main.py`:**

- `_fmt_date(raw) -> str` helper added (line 16) — strips dashes from
  any ISO/DB date string (`YYYY-MM-DD`) to produce `YYYYMMDD`; returns
  `"00000000"` as a safe fallback for null/missing values.
- NF-2 filename: `{patient_id}_{doi}_nf2.pdf`
- AOB filename: `{patient_id}_{doi}_aob.pdf`
- NF-3 filename: `{patient_id}_{doi}_{visit_date}_nf3.pdf`
  (old: `{patient_id}_NF3_{visit_id[:8]}_{timestamp}.pdf`)
- PCE filename: `{patient_id}_{doi}_{visit_date}_init_rpt.pdf`
  (old: `{patient_id}_PCE_{visit_id[:8]}_{timestamp}.pdf`)
- All referrals: `{patient_id}_{doi}_{visit_date}_{fn_type}.pdf`
  (old: `{patient_id}_{TAG}_{timestamp}.pdf`)
- `REFERRAL_FORM_CONFIG` entries: `fn_type` key added to each entry
  (lowercase filename token, separate from `tag` which is the DB
  `form_type` value stored in `patient_forms` — kept unchanged to
  avoid breaking `ReferralGrid.tsx` completion checks).

**Existing test data wiped via Dev Tools before convention applied.**
New convention applies to all generations going forward.

---

## 2026-07-06 — Session 20

### PatientChart.tsx refactor

`app/md/[patientId]/PatientChart.tsx` (1328 lines) split into 6 files.
New `components/` directory created under `app/md/[patientId]/`.

- `PatientChart.tsx` — shell: tab router, header, visits/tx state (~120 lines)
- `chart-shared.tsx` — shared types, `getAuthToken`, `getTx`, `CustomCombo`, `CodeMultiPicker`, `QuickNotePicker`, style constants
- `components/VisitTab.tsx` — visit/PCE/CPT/ICD-10/flag/billing logic
- `components/ReferralGrid.tsx` — referral type cards + psych referral
- `components/VisitHistoryTab.tsx` — history list + visit sheet drawer
- `components/PatientInfoTab.tsx` — DOA/insurance/pain scores

**Bug fixes in VisitTab:**
- `pceData` now hydrates from existing `v.pce_data` when `visit_id` in URL
- `visitDate` hydrates from existing visit record
- Patient status normalized on init (`'Active Treatment'` → `'Active'`)
- All native `<select>` dropdowns replaced with `QuickNotePicker`
- Update Status replaced with styled button group
- ICD-10 description lookup fixed (case-insensitive trim)
- DEV fill-all PCE test button added (remove before go-live)

### ReferralGrid completion indicators

`ReferralGrid.tsx` queries `patient_forms` on mount filtered by `visit_id`.
Cards highlight cyan with `✓` when `form_type` matched. ICD-10 checks
`icd10_codes` presence on visit record. Psych checks `patient_visits.psych_referral`.
Psych state updates optimistically on toggle.

### Admin CPT/ICD-10 data quality

Warning badges (`⚠️ No description`, `⚠️ No fee`) added to both sections.
Section-level banner shows count of affected codes.

### CSV import Replace mode

`＋ Append` / `⟳ Replace All` toggle added to both import preview cards.
Red warning banner and red confirm button when Replace mode selected.

**CPT import parser fix:** `icdKey`/`diagKey` no longer fall back to
positional columns — Supabase backup exports were misread (fee values
treated as ICD-10 codes). Fix: only auto-import ICD-10 if explicit
`icd10_code` header present.

**`null` fee_varies fix:** Supabase exports use literal `"null"` string —
parser now treats `"null"` as `fee_varies = true`.

### Admin action confirmations

`toastSuccess`/`toastError` added to all save, delete, and import actions
in `CptCodesSection.tsx` and `Icd10Section.tsx`.

### DashboardClient.tsx CosmosUI migration

Two bare `alert()` calls replaced with `toastError()`. `<AlertModal />` and
`<ConfirmModal />` mounted. FD dashboard previously had no CosmosUI modals.

### NF-2 signature injection fix

`cosmos-api/forms/nf2.py`: Fixed key from `signature_url` →
`patient_signature_url`. Patient signature was always in `patient_data`
but never injected due to wrong key.

`app/patients/[patientId]/PatientProfile.tsx`: `canGenerateNF2` now requires
`patient_signature_url`. NF-2 blocked with `"Missing: Signature"` when
no signature on file.

### Documentation updates

- `ARCHITECTURE.md §3`: Migrations 020–023 added; note on-disk files only
  exist for 001–019
- `AI_STYLE_GUIDE.md §2`: CosmosUI notification standard documented
- `HANDOVER.md`: Session 20 lessons learned added

---

## 2026-07-05 — Session 19 (final)


### FD submit button fix

`app/patients/[patientId]/PatientProfile.tsx`: After successful billing
submission, `setLocalVisits` now stamps submitted visits with
`submitted_to_billing_at` in local state immediately. `readyVisits`
filters them out — button disappears without waiting for `router.refresh()`.
Success toast added confirming visit count submitted.

### Login performance optimization

`app/page.tsx` — two changes:

**Merged duplicate `practice_settings` fetch:** `checkAndHandleMfa`
previously fetched `mfa_required`, then `handlePostLogin` fetched
`session_timeout_minutes` — two sequential round-trips to the same table
for admin/billing logins. Now a single query fetches both columns.
`handlePostLogin` accepts optional `sessionTimeoutMinutes` parameter;
when pre-fetched it skips the DB call. MD/PA/NP path unchanged.

**Parallelized lockout pre-check:** Two sequential `login_attempts` queries
replaced with `Promise.all`. Saves one round-trip on every login attempt.

**Infrastructure analysis:** Supabase `us-east-2` (Ohio), Vercel Hobby
`us-east-1` (Virginia) — ~50ms gap, not a meaningful bottleneck. Render
confirmed on $7 always-on plan.

---

## 2026-07-05 — Session 19 (continued)

### CPT and ICD-10 admin section fixes

**Edit form visibility** (`CptCodesSection.tsx`, `Icd10Section.tsx`):
Edit form moved from bottom to top of section. `useRef` +
`scrollIntoView({ behavior: 'smooth', block: 'start' })` fires on
`editing` state change. Root cause: sidebar layout introduced an
independent scroll context — bottom-rendered form appeared below
the mobile viewport, making Edit appear to do nothing.

**CPT price layout** (`CptCodesSection.tsx`):
Price moved inline after CPT code badge — `[98940] $68.15` on one row,
description below. Eliminates one row per card.

**Active/Inactive toggle** (both sections):
`<input type="checkbox">` replaced with a styled pill button.
`● Active` (green `#19a866`) / `○ Inactive` (red `#e74c3c`).
Checkbox was visually ambiguous on dark theme.

**ICD-10 download template** (`Icd10Section.tsx`):
`⬇ Download Import Template` link added matching the CPT section pattern.
Template columns: `code, description, category`. Two format example rows
(one Cervical, one Lumbar). Added via line-number Python insert at line 264
after anchor-based patches failed due to file state mismatch.

**CPT download template updated** (`CptCodesSection.tsx`):
Hardcoded blob updated from placeholder data to real NY No-Fault codes
with accurate fee schedule amounts and linked ICD-10s.

---

## 2026-07-05 — Session 19

### Admin sidebar nav — complete

`app/admin/page.tsx` updated to replace the horizontal tab strip with a
collapsible left sidebar. Single file change — all 8 section components
and `shared.tsx` are unchanged.

**Design:**
- Collapsible toggle (☰ expand / ✕ collapse), button in header left
- Collapsed: sidebar fully hidden, content takes full width
- Expanded: 200px left rail, labels only (emoji stripped via `stripEmoji()`)
- Active tab: `2px solid #00cfff` left border + cyan text
- Preference persisted in `localStorage` key `cosmos_admin_sidebar_open`
- Defaults to expanded on first load

**Scope:** Admin only this session. FD, MD, Biller sidebar rollout deferred —
template is proven, rollout is mechanical repetition.

**Header correction:** ← Back button moved before ⇄ Sign Out (order was
reversed in prior version).

---

## 2026-07-05 — Session 18

### Admin page refactor — complete

Pure structural refactor of `app/admin/page.tsx` (2,761 lines → 114-line
shell). Zero behavioral changes. All 8 tabs confirmed working in production.

**New file structure:**

```
app/admin/
  page.tsx                    ← shell only, 114 lines
  shared.tsx                  ← shared helpers, components, constants (264 lines)
  components/
    OverviewSection.tsx        (543 lines)
    CarriersSection.tsx        (320 lines)
    DoctorsSection.tsx         (803 lines)
    LawyersSection.tsx         (186 lines)
    CptCodesSection.tsx        (424 lines)
    Icd10Section.tsx           (310 lines)
    UsersSection.tsx           (306 lines)
    AuditLogSection.tsx        (257 lines)
```

**`shared.tsx`** exports all cross-section utilities: `getAuthToken`,
`PDF_API_URL`, `formatPhone`, `Field`, `SectionHeading`, `STATES`,
`StateSelectField`, `SignaturePad`, `TAX_CLASS_OPTIONS`, `LLC_CLASS_OPTIONS`,
`SPECIALTY_OPTIONS`, `LICENSE_TYPE_OPTIONS`, `BLANK_DOCTOR`, `PROVIDER_TYPES`.

**Preserved intact:** `useMemo` on `filtered` in `AuditLogSection` (prevents
TanStack Table infinite re-render freeze). `admin-tab` custom event listener
in shell `page.tsx`. All handler logic byte-for-byte identical to original.

---

## 2026-07-05 — Session 18 prep / Session 17 final

### Audit Log — full implementation (Enterprise Hardening Stage 2 complete)

**Migration 023:** `audit_logs` table with indexes and RLS (authenticated
SELECT + INSERT).

**DB triggers** — `log_audit_event()` PLPGSQL function on 7 tables:
`patients`, `patient_visits`, `visit_line_items`, `doctors`,
`insurance_carriers`, `user_profiles`, `practice_settings`. Captures
old/new data as jsonb. User attribution shows "System" — no PostgreSQL
session context available in trigger functions.

**`app/lib/auditLogger.ts`** — new shared helper. `writeAuditLog()` reads
current session user + role from `user_profiles`, inserts attributed entry
into `audit_logs`. Never throws — audit failures must not break main flow.

**Frontend audit calls added to:**
- `app/page.tsx` — login success, login failed (with attempts remaining),
  MFA verified
- `app/patients/[patientId]/PatientProfile.tsx` — NF-2/AOB generated,
  NF-3 preflight confirmed, submitted to billing
- `app/billing/BillerDashboard.tsx` — NF-3 generated, claim status changed,
  received amount updated, MD flagged
- `app/md/[patientId]/PatientChart.tsx` — visit created/updated, flag
  accepted/rejected

---

## 2026-07-04 — Session 14 (concluded)

### CPT importer — many-to-many ICD-10 mapping

CPT CSV importer now handles multi-ICD-10 rows per CPT code correctly:

- Deduplicates CPT rows by `cpt_code` before upsert (fixes
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
## 2026-07-06 — Session 20

### PatientChart.tsx refactor

`app/md/[patientId]/PatientChart.tsx` (1328 lines) split into 6 files.
New `components/` directory created under `app/md/[patientId]/`.

- `PatientChart.tsx` — shell: tab router, header, visits/tx state (~120 lines)
- `chart-shared.tsx` — shared types, `getAuthToken`, `getTx`, `CustomCombo`, `CodeMultiPicker`, `QuickNotePicker`, style constants
- `components/VisitTab.tsx` — visit/PCE/CPT/ICD-10/flag/billing logic
- `components/ReferralGrid.tsx` — referral type cards + psych referral
- `components/VisitHistoryTab.tsx` — history list + visit sheet drawer
- `components/PatientInfoTab.tsx` — DOA/insurance/pain scores

**Bug fixes in VisitTab:**
- `pceData` now hydrates from existing `v.pce_data` when `visit_id` in URL
- `visitDate` hydrates from existing visit record
- Patient status normalized on init (`'Active Treatment'` → `'Active'`)
- All native `<select>` dropdowns replaced with `QuickNotePicker`
- Update Status replaced with styled button group
- ICD-10 description lookup fixed (case-insensitive trim)
- DEV fill-all PCE test button added (remove before go-live)

### ReferralGrid completion indicators

`ReferralGrid.tsx` queries `patient_forms` on mount filtered by `visit_id`.
Cards highlight cyan with `✓` when `form_type` matched. ICD-10 checks
`icd10_codes` presence on visit record. Psych checks `patient_visits.psych_referral`.
Psych state updates optimistically on toggle.

### Admin CPT/ICD-10 data quality

Warning badges (`⚠️ No description`, `⚠️ No fee`) added to both sections.
Section-level banner shows count of affected codes.

### CSV import Replace mode

`＋ Append` / `⟳ Replace All` toggle added to both import preview cards.
Red warning banner and red confirm button when Replace mode selected.

**CPT import parser fix:** `icdKey`/`diagKey` no longer fall back to
positional columns — Supabase backup exports were misread (fee values
treated as ICD-10 codes). Fix: only auto-import ICD-10 if explicit
`icd10_code` header present.

**`null` fee_varies fix:** Supabase exports use literal `"null"` string —
parser now treats `"null"` as `fee_varies = true`.

### Admin action confirmations

`toastSuccess`/`toastError` added to all save, delete, and import actions
in `CptCodesSection.tsx` and `Icd10Section.tsx`.

### DashboardClient.tsx CosmosUI migration

Two bare `alert()` calls replaced with `toastError()`. `<AlertModal />` and
`<ConfirmModal />` mounted. FD dashboard previously had no CosmosUI modals.

### NF-2 signature injection fix

`cosmos-api/forms/nf2.py`: Fixed key from `signature_url` →
`patient_signature_url`. Patient signature was always in `patient_data`
but never injected due to wrong key.

`app/patients/[patientId]/PatientProfile.tsx`: `canGenerateNF2` now requires
`patient_signature_url`. NF-2 blocked with `"Missing: Signature"` when
no signature on file.

### Documentation updates

- `ARCHITECTURE.md §3`: Migrations 020–023 added; note on-disk files only
  exist for 001–019
- `AI_STYLE_GUIDE.md §2`: CosmosUI notification standard documented
- `HANDOVER.md`: Session 20 lessons learned added

---

## 2026-07-05 — Session 19 (final)


### FD submit button fix

`app/patients/[patientId]/PatientProfile.tsx`: After successful billing
submission, `setLocalVisits` now stamps submitted visits with
`submitted_to_billing_at` in local state immediately. `readyVisits`
filters them out — button disappears without waiting for `router.refresh()`.
Success toast added confirming visit count submitted.

### Login performance optimization

`app/page.tsx` — two changes:

**Merged duplicate `practice_settings` fetch:** `checkAndHandleMfa`
previously fetched `mfa_required`, then `handlePostLogin` fetched
`session_timeout_minutes` — two sequential round-trips to the same table
for admin/billing logins. Now a single query fetches both columns.
`handlePostLogin` accepts optional `sessionTimeoutMinutes` parameter;
when pre-fetched it skips the DB call. MD/PA/NP path unchanged.

**Parallelized lockout pre-check:** Two sequential `login_attempts` queries
replaced with `Promise.all`. Saves one round-trip on every login attempt.

**Infrastructure analysis:** Supabase `us-east-2` (Ohio), Vercel Hobby
`us-east-1` (Virginia) — ~50ms gap, not a meaningful bottleneck. Render
confirmed on $7 always-on plan.

---

## 2026-07-05 — Session 19 (continued)

### CPT and ICD-10 admin section fixes

**Edit form visibility** (`CptCodesSection.tsx`, `Icd10Section.tsx`):
Edit form moved from bottom to top of section. `useRef` +
`scrollIntoView({ behavior: 'smooth', block: 'start' })` fires on
`editing` state change. Root cause: sidebar layout introduced an
independent scroll context — bottom-rendered form appeared below
the mobile viewport, making Edit appear to do nothing.

**CPT price layout** (`CptCodesSection.tsx`):
Price moved inline after CPT code badge — `[98940] $68.15` on one row,
description below. Eliminates one row per card.

**Active/Inactive toggle** (both sections):
`<input type="checkbox">` replaced with a styled pill button.
`● Active` (green `#19a866`) / `○ Inactive` (red `#e74c3c`).
Checkbox was visually ambiguous on dark theme.

**ICD-10 download template** (`Icd10Section.tsx`):
`⬇ Download Import Template` link added matching the CPT section pattern.
Template columns: `code, description, category`. Two format example rows
(one Cervical, one Lumbar). Added via line-number Python insert at line 264
after anchor-based patches failed due to file state mismatch.

**CPT download template updated** (`CptCodesSection.tsx`):
Hardcoded blob updated from placeholder data to real NY No-Fault codes
with accurate fee schedule amounts and linked ICD-10s.

---

## 2026-07-05 — Session 19

### Admin sidebar nav — complete

`app/admin/page.tsx` updated to replace the horizontal tab strip with a
collapsible left sidebar. Single file change — all 8 section components
and `shared.tsx` are unchanged.

**Design:**
- Collapsible toggle (☰ expand / ✕ collapse), button in header left
- Collapsed: sidebar fully hidden, content takes full width
- Expanded: 200px left rail, labels only (emoji stripped via `stripEmoji()`)
- Active tab: `2px solid #00cfff` left border + cyan text
- Preference persisted in `localStorage` key `cosmos_admin_sidebar_open`
- Defaults to expanded on first load

**Scope:** Admin only this session. FD, MD, Biller sidebar rollout deferred —
template is proven, rollout is mechanical repetition.

**Header correction:** ← Back button moved before ⇄ Sign Out (order was
reversed in prior version).

---

## 2026-07-05 — Session 18

### Admin page refactor — complete

Pure structural refactor of `app/admin/page.tsx` (2,761 lines → 114-line
shell). Zero behavioral changes. All 8 tabs confirmed working in production.

**New file structure:**

```
app/admin/
  page.tsx                    ← shell only, 114 lines
  shared.tsx                  ← shared helpers, components, constants (264 lines)
  components/
    OverviewSection.tsx        (543 lines)
    CarriersSection.tsx        (320 lines)
    DoctorsSection.tsx         (803 lines)
    LawyersSection.tsx         (186 lines)
    CptCodesSection.tsx        (424 lines)
    Icd10Section.tsx           (310 lines)
    UsersSection.tsx           (306 lines)
    AuditLogSection.tsx        (257 lines)
```

**`shared.tsx`** exports all cross-section utilities: `getAuthToken`,
`PDF_API_URL`, `formatPhone`, `Field`, `SectionHeading`, `STATES`,
`StateSelectField`, `SignaturePad`, `TAX_CLASS_OPTIONS`, `LLC_CLASS_OPTIONS`,
`SPECIALTY_OPTIONS`, `LICENSE_TYPE_OPTIONS`, `BLANK_DOCTOR`, `PROVIDER_TYPES`.

**Preserved intact:** `useMemo` on `filtered` in `AuditLogSection` (prevents
TanStack Table infinite re-render freeze). `admin-tab` custom event listener
in shell `page.tsx`. All handler logic byte-for-byte identical to original.

---

## 2026-07-05 — Session 18 prep / Session 17 final

### Audit Log — full implementation (Enterprise Hardening Stage 2 complete)

**Migration 023:** `audit_logs` table with indexes and RLS (authenticated
SELECT + INSERT).

**DB triggers** — `log_audit_event()` PLPGSQL function on 7 tables:
`patients`, `patient_visits`, `visit_line_items`, `doctors`,
`insurance_carriers`, `user_profiles`, `practice_settings`. Captures
old/new data as jsonb. User attribution shows "System" — no PostgreSQL
session context available in trigger functions.

**`app/lib/auditLogger.ts`** — new shared helper. `writeAuditLog()` reads
current session user + role from `user_profiles`, inserts attributed entry
into `audit_logs`. Never throws — audit failures must not break main flow.

**Frontend audit calls added to:**
- `app/page.tsx` — login success, login failed (with attempts remaining),
  MFA verified
- `app/patients/[patientId]/PatientProfile.tsx` — NF-2/AOB generated,
  NF-3 preflight confirmed, submitted to billing
- `app/billing/BillerDashboard.tsx` — NF-3 generated, claim status changed,
  received amount updated, MD flagged
- `app/md/[patientId]/PatientChart.tsx` — visit created/updated, flag
  accepted, flag rejected

**Admin Audit Log tab** — new tab in Admin panel. shadcn/TanStack Table,
last 500 entries newest-first, category filter chips, search, pagination.
Fixed freeze: `useMemo` on filtered data (non-memoized array passed to
`useReactTable` caused infinite re-render on filter chip tap).

---

## 2026-07-05 — Session 17 (final)

### MFA for admin/billing/superadmin

TOTP-based MFA via Supabase Auth for `admin`, `billing`, `superadmin` roles.

**Migration:** `practice_settings.mfa_required boolean DEFAULT false`.

**`app/page.tsx`** — After PIN login, checks `mfa_required` setting. If enabled and device not trusted: checks TOTP enrollment → shows setup screen (QR code + manual key entry) or challenge screen (6-digit code). On successful verify, stores 30-day device trust token in `localStorage`. Trusted devices skip MFA for 30 days.

**`app/admin/page.tsx`** — New **Security & Access** section on Overview tab, separated from Practice Info. Contains MFA toggle and Session Timeout selector with dedicated "Save Security Settings" button. Toast confirmation on save. "Reset MFA" button added to admin/billing/superadmin user cards in Users tab.

**`app/api/admin/users/route.ts`** — Added `reset_mfa: true` PATCH handler — unenrolls all TOTP factors for the user via Supabase Admin API.

### FD dashboard queue subtitle updates

- "All Missing Forms": "NF-2 or AOB missing; or NF-3 preflight not completed"
- "NF-3 — 45 Day Deadline": "Biller must generate NF-3 within 45 days of service date"

### Security & Access section — admin Overview tab

MFA toggle and Session Timeout moved from Practice Info form into dedicated Security & Access card. Each section now saves independently with appropriate confirmation feedback.

---

## 2026-07-05 — Session 17 (continued)

### PIN attempt lockout (`app/page.tsx`)

Failed PIN attempt lockout implemented. Enterprise Hardening Stage 2 item complete.

**Migration:** `login_attempts` table (`id`, `email`, `attempted_at`, `success`).
Index on `email`. RLS: `authenticated` + `anon` full access (anon required —
lockout check runs before the user is authenticated).

**Logic:** On each login attempt, queries failures since the last success for
that email within a 15-minute window. 5+ failures → account locked, shows
minutes remaining. Each failed attempt inserts a row and re-fetches the count
to show accurate "X attempts remaining" message. Successful login inserts a
success row, resetting the effective failure count. Lockout auto-expires after
15 minutes — no admin action needed.

**Known issue during development:** Initial deploy used `authenticated`-only
RLS, causing all anon inserts/selects to silently fail (RLS returns empty with
no error), making counter always show MAX_ATTEMPTS. Fixed by adding `anon`
full-access policy.

### FD dashboard queue subtitle updates (`DashboardClient.tsx`)

- "All Missing Forms" subtitle: "NF-2 or AOB missing; or NF-3 preflight not completed"
- "NF-3 — 45 Day Deadline" subtitle: "Biller must generate NF-3 within 45 days of service date"
- NF-3 queue empty state: "All NF-3s generated by biller on time"

---

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
- **Render warm-up ping** — fires before each patient's referral batch to
  reduce cold-start PDF latency

### W9 supervisor-chain fix (`app/billing/BillerDashboard.tsx`, `app/billing/page.tsx`)

Supervised providers (PA, NP) must display their supervising MD's W9.
`supervising_provider_id` added to billing query. `doctorWithW9` resolver
added to `BillerDashboard.tsx` to walk the chain.

---

## 2026-07-04 — Session 14 (concluded)

### CPT importer — many-to-many ICD-10 mapping

CPT CSV importer now handles multi-ICD-10 rows per CPT code correctly:

- Deduplicates CPT rows by `cpt_code` before upsert (fixes
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
