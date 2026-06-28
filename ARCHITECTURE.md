# Cosmos Medical Technologies — ARCHITECTURE

Technical architecture reference. Stable until the architecture itself
changes. Does not contain process rules (`SYSTEM_PROMPT.md`), business/
medical rules (`PRODUCT_SPEC.md`), or current session status
(`HANDOVER.md`).

---

## 1. Stack

| Layer | Technology | Host | Repo |
|---|---|---|---|
| Frontend | Next.js | Vercel | `cosmos-dashboard` |
| Backend | FastAPI (Python) | Render | `cosmos-api` |
| Database | Supabase (PostgreSQL + Storage) | Supabase | — |
| PDF generation | PyMuPDF (`fitz`), `pypdf`, ReportLab | — | `cosmos-api` |

GitHub: `github.com/godskitchen72/cosmos-api`,
`github.com/godskitchen72/cosmos-dashboard`. Both public, but **not
reliably fetchable via web tools** — `robots.txt` blocks direct fetch of
repo pages even with a user-pasted URL, and the repos are too small to
reliably surface in web search results. File transfer is direct
upload/paste from the product owner's device (`cp ~/cosmos-dashboard/app/
<path> ~/storage/downloads/<name>` then attach is the standing preferred
method — `SYSTEM_PROMPT.md` §3).

On-device paths (Termux, Android-only — no desktop access exists or
will exist): `~/cosmos-dashboard` (confirmed), `~/cosmos-api` (confirmed).

Supabase project URL: `https://ttudxnzmybcwrtqlbtta.supabase.co` — never
change without explicit instruction (`SYSTEM_PROMPT.md` §3).

**Styling note**: Tailwind CSS is present in `package.json` but was
unused until the Biller dashboard. Two deliberate, scoped exceptions
now exist — both approved explicitly after the tradeoff was presented:
1. **Biller dashboard** (`/billing`, §8) — the first exception.
2. **Admin page** (`/admin`, `app/admin/page.tsx`) — full shadcn/ui
   rebuild; same CSS-variable bridge and Oxanium font as the Biller
   dashboard. Every other screen remains hand-rolled inline `style={{...}}`.

---

## 2. Deployment Pipeline

**`cosmos-dashboard` (Vercel)** — intentional double-deploy:
1. `git push` triggers Vercel's GitHub integration auto-deploy.
2. An explicit `vercel --prod --yes` CLI call is also run in the same
   chain, every time, as a deliberate safety net (not a bug to flag).

**`cosmos-api` (Render)** — auto-deploys from `git push` alone. No
CLI-equivalent manual deploy step exists for this repo.

Standard validation before any commit: `tsc --noEmit`
(`cosmos-dashboard`) / `python3 -m py_compile` (`cosmos-api`) — see
`SYSTEM_PROMPT.md` §6 for the full validation workflow.

---

## 3. Database (Supabase)

RLS (Row-Level Security) is enabled per-table. **Known failure pattern**:
a table can have RLS enabled with an incomplete policy set, and the
missing command (UPDATE/DELETE/etc.) will silently match zero rows — no
error, `{ error: null }`. Confirmed causes of real bugs in the past
(`visit_line_items` missing DELETE policy, `patient_visits` missing
UPDATE policy — both fixed; `cpt_codes` missing all 4 anon policies —
fixed this session, root cause of CPT tab showing empty). A related but
distinct pattern: a table can have RLS **disabled entirely**
(`patient_forms` — confirmed via `pg_class.relrowsecurity = false`),
which means nothing is restricted at all; and a table can have RLS
enabled with exactly one fully-open policy (`storage.objects` — one
`ALL`-command policy scoped only to `bucket_id = 'patient-forms'`,
otherwise unrestricted). Neither currently causing a bug, both tracked
in `HANDOVER.md` Open Items. `sql/003_rls_audit_query.sql` is the
standing tool for checking a table's actual policy set.

`sql/` migration history (numbered, sequential, already run against the
live database unless noted otherwise in `HANDOVER.md`):
- `001_rls_policy_fixes.sql`
- `002_cleanup_duplicate_line_items.sql`
- `003_rls_audit_query.sql` — verification query, safe to re-run anytime
- `004_add_psych_referral_column.sql`
- `005_add_nf2_mailed_columns.sql`
- `006_add_submitted_to_billing_column.sql`
- `007_add_doctor_pc_and_tax_columns.sql`
- `008_verify_session_columns.sql` — verification query
- `009_add_doctor_license_type_and_supervising.sql`
- `010_add_practice_settings_and_office_locations.sql`
- `011_add_doctor_locations_and_appointment_location.sql`

Key tables:

| Table | Key columns | Notes |
|---|---|---|
| `patients` | `patient_id`, `doctor_id`, `status`, `aob_url` | One doctor per patient |
| `patient_visits` | `visit_id`, `patient_id`, `submitted_to_billing_at`, `received_amount`, `claim_status`, `payment_status` | `doctor_name` unreliable — use `patients.doctor_id` |
| `visit_line_items` | `visit_id`, `cpt_code`, `fee` | Billing line items |
| `patient_forms` | `patient_id`, `visit_id`, `form_type`, `filename` | All generated + uploaded docs |
| `doctors` | `doctor_id`, `license_type` (DEFAULT 'MD'), `supervising_provider_id` (FK self-ref), `available_days` (text[]), `max_patients_per_day` (int DEFAULT 25), `w9_url`, `signature_url`, PC/tax fields | Migration 009 added license_type + supervising_provider_id |
| `cpt_codes` | `id`, `cpt_code` (UNIQUE), `description`, `fee`, `fee_varies`, `provider_type`, `supported_icd10`, `active` | Fee schedule; unique constraint added migration 011 |
| `icd10_codes` | `id`, `code` (UNIQUE), `description`, `category`, `active`, `clinical_note_template` | Unique constraint added migration 011 |
| `appointments` | `id`, `patient_id`, `doctor_id`, `location_id` (FK → office_locations), `appointment_date`, `appointment_time`, `appointment_type`, `status`, `notes` | `location_id` added migration 011 |
| `office_locations` | `id`, `name`, `street`, `city`, `state`, `zip`, `phone` | Physical office locations; migration 010 |
| `doctor_locations` | `id`, `doctor_id` (FK), `location_id` (FK), `days_of_week` (text[]), `start_time`, `end_time`, `slot_minutes` (DEFAULT 20), `capacity` (DEFAULT 25), UNIQUE(doctor_id, location_id) | Per-location schedule; migration 011 |
| `practice_settings` | `id` (=1, CHECK constraint), `practice_name`, `corp_name`, `tax_id`, `tax_classification`, `street`, `city`, `state`, `zip`, `phone`, `fax` | Single-row; pre-seeded with id=1; NF-3 ready; migration 010 |

**Doctor-to-visit linkage gap:** `patient_visits.doctor_name` is a
free-text column that only gets populated by `app/dev/page.tsx`'s
synthetic test-data generator — never by real saves. Don't use it for
any real lookups. The reliable link is `patients.doctor_id`, captured
on intake. This assumes one doctor per patient.

**Scheduling capacity fallback logic** (not yet implemented in calendar):
- If a doctor has `doctor_locations` rows: use per-location `capacity`
  and `days_of_week` for that location
- If not: fall back to `doctors.available_days` and
  `doctors.max_patients_per_day` (the current calendar behavior)
- This means single-location practices need no `doctor_locations` setup

---

## 4. API Routing & PDF Dispatch Chain

Live base URL: `https://cosmos-api-789w.onrender.com`

**Referral-type documents** (MRI, Rx, DME, ANS, VNG, PT, ICD-10, Ortho,
Pain Mgmt — 9 types) share one generic dispatch path in `main.py`:

```
POST /generate-{type}
  → ReferralRequest { patient_id, visit_id, referral_data }
  → _generate_referral_pdf(req, type)
      - looks up REFERRAL_FORM_CONFIG[type] for pdf_fn name + tag + labels
      - fetches patient row, merges visit row, merges doctor data into
        one patient_data dict (referral_data nested inside it)
      - calls getattr(pdf_engine, cfg["pdf_fn"])(patient_data)
      - pdf_engine.py re-exports each forms/*.py module's generate_*_pdf()
      - deletes any existing patient_forms row for (patient_id, form_type=tag,
        visit_id), inserts a new row with status "generated"
      - uploads the PDF to the "patient-forms" Supabase Storage bucket
      - returns { success, filename, url (signed), message }
```

Adding a new referral type requires touching all of: the new
`forms/<type>.py`, `pdf_engine.py` (re-export), `main.py`
(`REFERRAL_FORM_CONFIG` entry + import), and the frontend screen.

---

## 5. PDF Templates

All templates are AcroForm PDFs. Two generation libraries in use:

- **PyMuPDF (`fitz`)** — fills AcroForm fields by name. Used for all
  referral types and PCE. Fields must match the PDF's internal field names
  exactly (verified with `pypdf.get_fields()`).
- **ReportLab** — used for NF-2 only. Required because NF-2 uses
  `fitz` widget enumeration in the same pipeline (`fitz` widget
  enumeration dependency). **NF2.pdf must always remain ReportLab-produced.**

All PDFs remain **unflattened** (staff-editable post-generation).

Template short filenames (all in `cosmos-api` repo root):
`ANS.pdf`, `DME.pdf`, `ICD10.pdf`, `MRI.pdf`, `ortho.pdf`,
`pain_mgmt.pdf`, `PCE.pdf`, `PT.pdf`, `RX.pdf`, `VNG.pdf`

Note: `ortho.pdf`/`pain_mgmt.pdf` are lowercase while others are
uppercase — cosmetic inconsistency, tracked in `HANDOVER.md` Open Items.

---

## 6. Frontend Architecture

**Route structure** (`app/`):
```
page.tsx                    — role selector landing page
dashboard/                  — FD dashboard (DashboardClient.tsx)
md/                         — MD dashboard (MDClient.tsx)
md/[patientId]/             — MD patient chart (PatientChart.tsx)
patients/[patientId]/       — Patient profile, intake, edit
billing/                    — Biller dashboard (BillerDashboard.tsx)
admin/                      — Admin dashboard (page.tsx — all sections)
calendar/                   — FD scheduling calendar (page.tsx)
dev/                        — Dev tools (page.tsx)
```

**Shared modules**:
- `lib/supabase.ts` — Supabase anon client (top-level `lib/`, NOT `app/lib/`)
- `lib/supabaseServer.ts` — server-side client (top-level `lib/`)
- `app/lib/fonts.ts` — shared Oxanium font object (weights 300–800)
- `lib/utils.ts` — shadcn `cn()` helper

**shadcn/ui components** (`app/components/ui/`):
`card`, `table`, `badge`, `button`, `select`, `dropdown-menu`,
`input`, `tabs` — used by Biller and Admin only.

**Key architectural constraints**:
- No Tailwind preflight reset — every bare `<button>` needs explicit
  `border-0 bg-transparent p-0` (and color/font/size)
- `patient_visits.doctor_name` is unreliable — use `patients.doctor_id`
- Never `git push --force` (prior incident destroyed 102 commits)
- No `/tmp` in Termux — use `~/`
- All PDFs unflattened (staff editable post-generation)

---

## 7. Scheduling Architecture

**Existing** (`app/calendar/page.tsx`):
- Week view + month view
- Doctor selector (all doctors or specific doctor)
- `lockedDoctorId` URL param scopes view to one doctor (MD self-view)
- Quick-pick chips: next N available dates for selected doctor
- Availability determined by `doctors.available_days` (text array)
- Capacity determined by `doctors.max_patients_per_day` (integer)
- Full appointment lifecycle: Scheduled → Confirmed → Checked In →
  Completed | Cancelled | No-Show
- FD "Needs Appointment" queue queue in `app/dashboard/` with `Book →`
  deep link to calendar with `?patient=<id>`

**Phase 3 (not yet built)** — location-aware calendar:
- Location selector appears when a doctor is selected
- Capacity + available days read from `doctor_locations` (with
  `doctors.*` fallback when no location rows exist)
- Booking form adds Location field → `appointments.location_id` written
- `generateSlots()` uses `doctor_locations.start_time`, `end_time`,
  `slot_minutes` when location is selected

**Phase 4 (not yet built)** — MD login location picker:
- After role select → "Which office today?" modal
- Selection stored in `sessionStorage`
- Passed as URL param to `/calendar` → calendar pre-filters to location

---

## 8. Biller Dashboard (`/billing`)

See prior sessions' ARCHITECTURE.md for full detail. Summary of stable
facts:

- TanStack Table with sorting, filtering, pagination, bulk actions,
  column visibility, CSV export
- `claim_status` and `payment_status` are two separate fields
- "Received" = real `patient_visits.received_amount` column
- "Billed" = `sum(visit_line_items.fee)` per visit
- Denial Docs: `patient_forms` with `form_type = 'DENIAL_DOC'`
- Charts: raw Recharts (not shadcn chart wrapper — upstream issue
  `shadcn-ui/ui#9892`)
- shadcn/ui exception #1 (see §1 Styling note)

---

## 9. Admin Dashboard (`/admin`)

Single `'use client'` page component with 6 scrollable tabs:
Overview · Carriers · Providers · Lawyers · CPT Codes · ICD-10

Key sections:
- **Overview**: KPI cards, Quick Access, Office Locations manage UI,
  Practice Info (inline edit → `practice_settings`), Recent Providers
- **Providers (DoctorsSection)**: full CRUD with 4-tab edit form
  (General / Credentials / Billing / Schedule). Schedule tab has
  Default Schedule + Location Assignments (→ `doctor_locations`)
- **CPT Codes (CptCodesSection)**: CRUD + CSV import with ICD-10 co-import
- **ICD-10 (Icd10Section)**: CRUD + CSV import + search

Tab navigation uses `window.CustomEvent('admin-tab', { detail: tabId })`
dispatched from Quick Access buttons, caught by a `useEffect` listener
in the root `AdminPage` component. Allowed tab IDs: `'overview'`,
`'carriers'`, `'doctors'`, `'lawyers'`, `'cpt'`, `'icd10'`.

shadcn/ui exception #2 (see §1 Styling note).
