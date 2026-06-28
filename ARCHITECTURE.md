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
method — `SYSTEM_PROMPT.md` §3), or "Copy raw contents" from GitHub's
mobile web UI.

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
distinct pattern: a table can have RLS **disabled entirely** (`patient_forms`
— confirmed via `pg_class.relrowsecurity = false`), which means nothing
is restricted at all rather than partially restricted; and a table can
have RLS enabled with exactly one fully-open policy (`storage.objects`
— one `ALL`-command policy scoped only to `bucket_id = 'patient-forms'`,
otherwise unrestricted). Neither currently causing a bug, both tracked
in `HANDOVER.md` Open Items. `sql/003_rls_audit_query.sql` is the
standing tool for checking a table's actual policy set; run it before
trusting any read/write path "just works," especially for newly-added
columns.

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

Key tables referenced throughout the codebase: `patients`,
`patient_visits` (visit-scoped data, including `cpt_codes`/`icd10_codes`,
`received_amount`, `claim_status`, `payment_status` — see §8 for how the
last three are used on the Biller dashboard), `visit_line_items`
(billing), `patient_forms` (generated-document tracking — `form_type`,
`visit_id`, `filename`, used to find/replace a patient's generated PDFs
per visit, and now also Denial Docs uploads/deletes — see §8), `cpt_codes`
(fee schedule — the *only* source of fee data; there is no separate "fee
schedule" concept anywhere in the codebase; unique constraint on `cpt_code`
added migration 011), `doctors` (PC/tax fields per §5 of `PRODUCT_SPEC.md`,
`w9_url`, signature; `doctor_id` is its primary key; also `license_type`
text DEFAULT 'MD', `supervising_provider_id` uuid FK self-referencing,
`available_days` text[], `max_patients_per_day` int DEFAULT 25 —
migration `009_add_doctor_license_type_and_supervising.sql`).

**New tables added this session:**
- `practice_settings` (migration 010) — single-row (id=1, CHECK constraint),
  pre-seeded; fields: `practice_name`, `corp_name`, `tax_id`,
  `tax_classification`, `street`, `city`, `state`, `zip`, `phone`, `fax`.
  NF-3 ready. Full anon RLS (4 policies).
- `office_locations` (migration 010) — `id`, `name`, `street`, `city`,
  `state`, `zip`, `phone`. Full anon RLS (4 policies).
- `doctor_locations` (migration 011) — `id`, `doctor_id` FK, `location_id`
  FK, `days_of_week` text[], `start_time`, `end_time`, `slot_minutes`
  DEFAULT 20, `capacity` DEFAULT 25, UNIQUE(doctor_id, location_id).
  Full anon RLS (4 policies). Per-location schedule source of truth;
  `doctors.available_days`/`max_patients_per_day` remain as fallback.
- `appointments.location_id` (migration 011) — uuid FK → office_locations,
  nullable (existing appointments unaffected).
- `icd10_codes` — unique constraint on `code` added migration 011.

**Doctor-to-visit linkage gap:** `patient_visits` does not reliably
record which doctor performed the visit. A `doctor_name` free-text
column exists, but the real production save path (`PatientChart.tsx` →
`handleSave()`) never writes it — the *only* place that column gets
populated is `app/dev/page.tsx`'s synthetic test-data generator. Don't
trust `patient_visits.doctor_name` for anything real. The reliable link
is `patients.doctor_id`, captured through an actual dropdown on
`PatientForm.tsx` (new-patient/edit) and genuinely written on intake —
use that for any "which doctor" lookup (e.g. the Biller dashboard's W9
join, §8). This still assumes one doctor per patient; if the practice
ever has multiple treating doctors per patient, this assumption breaks
and `patient_visits` would need its own real `doctor_id` column,
populated at save time — not built, not currently needed (`HANDOVER.md`
Open Items).

---

## 4. API Routing & PDF Dispatch Chain

Live base URL: `https://cosmos-api-789w.onrender.com`

**Referral-type documents** (MRI, Rx, DME, ANS, VNG, PT, ICD-10, Ortho,
Pain Mgmt — 9 types as of this session) share one generic dispatch path
in `main.py`:

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
`forms/<type>.py` module, a `REFERRAL_FORM_CONFIG` entry + `/generate-
<type>` route in `main.py`, an import + `__all__` entry in
`pdf_engine.py`, and the actual PDF template placed at the `cosmos-api`
repo root.

**Pain Mgmt is the one exception to type-key/route/module-name
consistency**: the route is `/generate-pain-mgmt` (hyphenated, explicit
product decision) but the module is `forms/pain_mgmt.py` (underscore —
Python module names can't contain hyphens). The `REFERRAL_FORM_CONFIG`
key is `"pain-mgmt"` (matches the route, since a dict key is just a
string, not an identifier). Every other type keeps the route/module/key
identical.

**Non-referral documents** (NF-2, NF-3, AOB, W-9, PCE) are routed
individually in `main.py`, most importing directly from their
`forms/*.py` module (not all go through `pdf_engine.py` — `/generate-w9`
specifically imports `forms.w9` directly).

---

## 5. PDF Engine

- `forms/base.py` — shared helpers only: `s()` (safe-stringify), `format_date()`,
  `fill_pdf_fields(doc, field_map)` (iterates real widgets on the doc,
  sets value if the widget's name is a key in `field_map` — silently
  skips any `field_map` key with no matching widget, which is forgiving
  but not a substitute for verifying the real field list),
  `fetch_signature_bytes()`, `inject_signature_image()` (deletes the
  widget and draws the image directly onto the page, since `fitz` text
  fields can't hold an image). **Known issue**: pre-existing
  `except Exception: pass` in `render_visible_text_in_rect` — prohibited
  by `SYSTEM_PROMPT.md` §1/§8, flagged 3+ sessions, not yet fixed.
- `forms/*.py` — one module per document type, each exposing a single
  `generate_<type>_pdf(patient_data) -> (pdf_bytes, error)` function.
  Field-name verification convention: every field confirmed against the
  real PDF's `pypdf.get_fields()` output before any filler code is
  written (`SYSTEM_PROMPT.md` §8).
- `pdf_engine.py` — pure router, ~15 lines: imports each `forms/*.py`
  module's generator and re-exports it via `__all__` for `main.py` to
  call by name.
- **`NF2.pdf` must always remain ReportLab-produced**, not PyMuPDF-edited
  — this was a deliberate rebuild specifically to preserve `fitz` widget
  enumeration needed for signature injection elsewhere in the pipeline.
  Don't regenerate or re-author this one template via a different tool.
- All PDFs stay unflattened (editable AcroForm) — no exceptions recorded.

Referral PDF templates currently known to exist (filenames as of this
session — confirm the live filename via the repo before assuming):
`ANS.pdf`, `DME.pdf`, `ICD10.pdf`, `MRI.pdf`, `PT.pdf`, `RX.pdf`,
`VNG.pdf`, `PCE.pdf` (all uppercase short form), plus `ortho.pdf`,
`pain_mgmt.pdf` (**lowercase** — unresolved naming-convention split
flagged in `HANDOVER.md` Open Items). Also: `AOB.pdf`, `NF2.pdf`
(ReportLab), `NF3.pdf` (+ a standalone Page-2 overflow variant for
visits with more than 3 CPT codes), `W9_fillable.pdf`.

---

## 6. Directory Structure

```
cosmos-api/
  main.py                  routes + REFERRAL_FORM_CONFIG + shared dispatcher
  pdf_engine.py             pure router -> forms/*.py
  database.py               builds doctor_*/patient_data dicts for PDF generators
  models.py                 CPT/ICD-10 catalogs, pain tools, MD status logic
  forms/
    base.py                 shared PDF helpers (no DB logic)
    nf2.py  nf3.py  aob.py  pce.py
    mri.py  rx.py  dme.py  ans.py  vng.py  pt.py  icd10.py
    ortho.py  pain_mgmt.py   pain_mgmt.py's route is hyphenated
                              (/generate-pain-mgmt) despite the
                              underscore filename — see §4
    w9.py
  <PDF template files>.pdf  one per document type, repo root
  requirements.txt
  render.yaml
  .gitignore                NOTE: do not add a blanket *.pdf rule — every
                             PDF here is a tracked template, not generated
                             output

cosmos-dashboard/
  app/
    page.tsx                  role-select landing screen (Front Desk / MD /
                              Billing / Admin); "Remember my role" device
                              storage; each role's path/soon flag lives
                              here — flip soon:false once a role's
                              dashboard is actually built
    globals.css               theme tokens (:root CSS vars) + the
                              shadcn/Tailwind v4 bridge (§8) appended
                              additively at the end; also carries the
                              global text-size-adjust: 100% rule (§8)
    lib/
      fonts.ts                shared Oxanium font object (weights 300–800)
                              — imported by BillerDashboard.tsx AND by
                              select.tsx/dropdown-menu.tsx (Radix Portal
                              content can't inherit from parent DOM)
    components/
      DropdownSelect.tsx     generic dark-themed dropdown (use for any
                              select-like control, never a native <select>)
      StateSelect.tsx         same pattern, US states specifically
      PatientForm.tsx         new-patient/edit form; the actual place
                              patients.doctor_id gets captured
      ui/                     shadcn primitives — Card, Table, Badge,
                              Button, Select, Dropdown Menu, Input, Tabs
    admin/page.tsx            Admin dashboard — 6 tabs: Overview, Carriers,
                              Providers, Lawyers, CPT Codes, ICD-10.
                              Full CRUD for all tables. Overview has KPI
                              cards, Quick Access, Practice Info, Office
                              Locations manage UI, Recent Providers.
                              Schedule tab has Location Assignments section
                              (doctor_locations junction table).
    calendar/page.tsx         FD scheduling calendar (week/month views,
                              doctor-locking via ?doctor_id=, full
                              appointment lifecycle). Location-aware
                              scheduling (Phase 3) not yet built.
    dashboard/
      DashboardClient.tsx     FD dashboard (queues: Psych Referral, NF-2
                              mailing, Needs Appointment, etc.)
    billing/
      page.tsx                 server wrapper
      BillerDashboard.tsx      Biller role queue (§8)
    dev/page.tsx               synthetic test-data generator; the only
                              place patient_visits.doctor_name ever gets
                              written — not representative of any real
                              save path
    md/
      MDClient.tsx             doctor-scoped via ?doctor_id=
      page.tsx                 passes doctorId down to MDClient
      [patientId]/
        page.tsx               does not accept or forward doctor_id
        PatientChart.tsx       MD-facing chart; PCE wizard; referral grid;
                              handleSave() does not write any doctor field
        mri/page.tsx + MriReferral.tsx
        rx/page.tsx + RxReferral.tsx
        ans/page.tsx + AnsReferral.tsx
        icd10/                 excluded from Save→View pattern
        dme/page.tsx + DmeReferral.tsx
        vng/page.tsx + VngReferral.tsx
        pt/page.tsx + PtReferral.tsx
        ortho/page.tsx + OrthoReferral.tsx
        pain-mgmt/page.tsx + PainMgmtReferral.tsx
    patients/
      [patientId]/
        page.tsx
        PatientProfile.tsx     FD-facing profile: NF-2 mailing UI,
                              submit-to-billing, fee estimates, Referrals
                              & Orders grid (9 types, no reserved slots)
  lib/
    supabase.ts               browser-side client (anon key) — top-level
                              lib/, NOT app/lib/
    supabaseServer.ts          server-side client (service key) — top-level
                              lib/, NOT app/lib/
    utils.ts                  shadcn cn() helper
  components.json              shadcn/ui config — ui alias points at
                              app/components/ui
  public/
    cosmos_icon_mark.jpg       product-owner-supplied icon mark
```

---

## 7. Frontend ↔ Backend Integration Flow (referral generation)

1. A referral screen (e.g. `PtReferral.tsx`) collects clinical input into
   a `referral_data` object whose keys match the live PDF's own AcroForm
   field names directly (no translation layer) for any field with no
   legacy contract to preserve.
2. `POST https://cosmos-api-789w.onrender.com/generate-<type>` with
   `{ patient_id, visit_id, referral_data }`.
3. **Save→View is the standing pattern** (replacing the prior
   Generate→View pattern) **for every type except ICD-10**, which
   auto-fires on visit save and was deliberately excluded
   (`PRODUCT_SPEC.md` §3). On success, the button morphs from "Save" to
   "View" **without** auto-opening the PDF. Tapping "View" fetches a
   fresh signed URL client-side
   (`supabase.storage.from('patient-forms').createSignedUrl(filename, 1800)`).
   A "Regenerate" text link appears once saved, gated behind `confirm()`.
3a. **Check-on-load**: each referral type's `page.tsx` server wrapper
   queries `patient_forms` for an existing row matching this `visit_id`
   + the type's tag before rendering, and passes `existingFilename` (or
   `null`) down as a prop. Revisiting an already-saved referral shows
   "View" immediately, preventing accidental overwrite.
4. The FD-facing `PatientProfile.tsx` grid independently queries
   `patient_forms` (filtered by `form_type` + `visit_id`) to show
   View/"Not yet ordered" per type — it does not call the generation
   endpoints itself.
5. Header/administrative fields (patient name, DOB, insurance, claim
   number, ICD-10 codes, provider name/license/NPI/signature) are never
   collected in the referral screen's own UI — they're always pulled
   server-side from the patient/visit/doctor records inside
   `_generate_referral_pdf`'s data merge. Only genuinely clinical content
   (goals, modalities, symptoms, findings) is entered on the screen
   itself.

---

## 8. Scheduling Architecture

**Existing** (`app/calendar/page.tsx`):
- Week view + month view, doctor selector, `lockedDoctorId` URL param
- Quick-pick chips: next N available dates for selected doctor
- Availability: `doctors.available_days` (text array)
- Capacity: `doctors.max_patients_per_day` (integer)
- Full appointment lifecycle: Scheduled → Confirmed → Checked In →
  Completed | Cancelled | No-Show
- FD "Needs Appointment" queue with `Book →` deep link

**Capacity fallback logic** (Phase 3 will implement this):
- If doctor has `doctor_locations` rows → use per-location `capacity`
  and `days_of_week` for the selected location
- If not → fall back to `doctors.available_days` and
  `doctors.max_patients_per_day` (current behavior — unchanged)

**Phase 3 (not yet built)** — location-aware calendar:
- Location selector when doctor selected (filtered to `doctor_locations`)
- Booking form adds Location field → `appointments.location_id` written
- `generateSlots()` uses `doctor_locations.start_time`, `end_time`,
  `slot_minutes` when location selected

**Phase 4 (not yet built)** — MD login location picker:
- After role select → "Which office today?" modal
- Selection stored in `sessionStorage`, passed as URL param to `/calendar`

---

## 9. Admin Dashboard (`/admin`)

Single `'use client'` page component with 6 scrollable tabs:
Overview · Carriers · Providers · Lawyers · CPT Codes · ICD-10

Tab navigation uses `window.CustomEvent('admin-tab', { detail: tabId })`
dispatched from Quick Access buttons, caught by a `useEffect` listener
in the root `AdminPage` component. Allowed tab IDs: `'overview'`,
`'carriers'`, `'doctors'`, `'lawyers'`, `'cpt'`, `'icd10'`.

shadcn/ui exception #2 (see §1 Styling note).

Key sections:
- **Overview**: Quick Access (top), KPI cards (2×3 grid), Office
  Locations manage UI (add/delete → `office_locations`), Practice Info
  (inline edit → `practice_settings`), Recent Providers
- **Providers (DoctorsSection)**: 4-tab edit form (General / Credentials
  / Billing / Schedule). Schedule tab: Default Schedule + Location
  Assignments (→ `doctor_locations` upsert on doctor+location unique key)
- **CPT Codes**: CRUD + filter by provider_type + CSV import (co-imports
  ICD-10 codes from paired column)
- **ICD-10**: CRUD + search + CSV import

---

## 10. Biller Dashboard (`/billing`)

Built across multiple sessions. v1 was the first build against
`PRODUCT_SPEC.md` §10's "actual Billing department feature," previously
explicitly deferred — basic queue, placeholder "Received" column, no
real payment tracking. It was substantially rebuilt into v2 before the
most recent session covered by this document (TanStack Table, KPI cards,
real `received_amount` tracking, the Claim Status/Payment Status field
split) — that rebuild predates this document's direct visibility and
isn't reconstructed blow-by-blow here; the live repo is the source of
truth for exactly what changed and when. Most recently: a round of
typography/UX fixes, Denial Docs delete capability, and a charting pass
(see `HANDOVER.md` for the session-specific list).

**shadcn/ui — deliberate, scoped exception.** Every other screen in this
app is hand-rolled inline styles (§1). The product owner explicitly
approved shadcn/ui + Tailwind utility classes for this one surface after
the tradeoff was presented once (`SYSTEM_PROMPT.md` §9). A second, later
exception on this same surface: a brighter green (`#2ee08a`) than
`SYSTEM_PROMPT.md` §9's stated `#19a866`, also explicitly approved.
Don't extend either pattern elsewhere without the same explicit
approval, and don't treat their presence here as license to assume
either is the project's real design system — they aren't, everywhere
else still is the original palette and hand-rolled styles.

**Theme bridge** (`app/globals.css`, appended additively): shadcn
expects CSS variables under its own names (`--background`, `--card`,
`--primary`, `--popover`, `--accent`, `--muted`, etc.). Rather than
introducing a second color palette, those variable names are mapped onto
the project's existing palette (`--bg-base`, `--bg-card`, `--accent-cyan`,
etc. — already defined in `:root` above), then exposed to Tailwind via a
`@theme inline` block. Net effect: shadcn components render in the same
colors as the rest of the app without the rest of the app's CSS being
touched. A real Tailwind v4 detail that cost real debugging time:
`globals.css` had deliberately omitted `@tailwind base;` (to avoid
Tailwind's reset fighting the hand-rolled one) — but in v4, that single
directive also carries the *default token set* (spacing/font-size/radius
scales), not just the reset. Omitting it meant every new Tailwind utility
class silently resolved to nothing. Fix: split imports —
`@import "tailwindcss/theme.css" layer(theme);` +
`@import "tailwindcss/utilities.css" layer(utilities);` — gets the
default tokens without pulling in preflight (and *not* pulling in
preflight is itself the reason for the bare-interactive-element gotcha
documented below).

**The preflight gap, generalized.** Because `globals.css` never includes
Tailwind's preflight reset, no bare interactive element (`<button>`, or
a shadcn/Radix component's own internal trigger/content elements)
automatically inherits color, font-family, or font-size from its parent
— browsers apply their own default form-control styling instead, and
Radix portaled content (`SelectContent`, `DropdownMenuContent`) renders
to `document.body`, entirely outside its logical parent's DOM subtree,
so even an inherited style that *would* otherwise apply structurally
still can't reach it. This has been the root cause of five separate,
independently-discovered bugs on this dashboard (sortable header
buttons missing font-size; `ReceivedCell` missing the Oxanium font;
`SelectTrigger` losing its text color once a value is selected;
`Button`'s `outline`/`ghost` variants having no text-color class at all;
Android Chrome's separate font-boosting heuristic inflating text size
independent of any CSS, fixed via a global `text-size-adjust: 100%`).
Any new bare button or shadcn trigger/content element added to this
surface needs explicit color/font/size classes set on it directly — see
`AI_STYLE_GUIDE.md` §1 for the full list of confirmed instances.

**Shared font module** (`app/lib/fonts.ts`): the Oxanium font object used
to be declared locally inside `BillerDashboard.tsx` only. Per the portal
gap above, that meant it never reached `SelectContent`/`DropdownMenuContent`.
Both `select.tsx` and `dropdown-menu.tsx` now import the same shared
object from this one module instead of each declaring their own.

**Data model for the queue**: visits where `patient_visits.
submitted_to_billing_at` is set, joined against `patients` for
patient/carrier/AOB info and against `doctors` via `patients.doctor_id`
for the W9 join (see §3's doctor-linkage note for why this is the right
join and what it assumes). "Billed" is computed live as
`sum(visit_line_items.fee)` per visit, the same pattern the FD dashboard
already uses. **"Received" is a real, per-visit value** —
`patient_visits.received_amount`, directly editable via `ReceivedCell`
— feeding the Received column, the Balance column (`billed -
received_amount`, shown in red when positive/still-owed, green when
negative/overpaid), the queue-wide KPIs, and the per-carrier Paid vs
Outstanding chart below. (A prior version of this document described
this as a "Not tracked" placeholder with no backing column — that was
already stale before this session, corrected here against the live
code, per `HANDOVER.md`'s Documentation Corrections note.)

**Status vs. Denial Status** — two genuinely separate fields, by
deliberate earlier design decision, never collapsed: `claim_status`
(workflow stage: Submitted/Accepted/Needs Review/Appeal/Under
Investigation — the "Status" column) and `payment_status` (outcome:
none/Denied/Paid/IME Cut Off/Missing Docs/Fraudulent/Policy Exhausted —
the "Denial Status" column, renamed from "Payment Status" this session
for clarity; label-only change, field name unchanged). The "Submitted"
column (now labeled "Bill Received") is `submitted_to_billing_at`, the
producer-side timestamp described above — a third, separate field from
both of the above and from the `$` Received column.

**Denial Docs**: uploaded per-visit documents related to a denial,
tracked the same way as every other generated document
(`patient_forms`, `form_type = 'DENIAL_DOC'`, stored in the
`patient-forms` Supabase Storage bucket under a `denial-docs/` prefix).
Supports biller-initiated **hard delete** — a confirm-before-delete
dialog, then removal of both the storage object and the `patient_forms`
row, letting a biller correct a wrongly-uploaded file. The
`patient_forms` row is deleted first (and reverted on failure, since
it's what makes the badge exist at all); the storage object removal
afterward is best-effort — an orphaned blob with no DB reference is
harmless, while a DB row pointing at an already-deleted file would leave
a broken badge.

**Document badges** (NF-3, AOB, PCE, W9, Denial Docs): tappable when the
underlying file exists (opens via
`supabase.storage.from('patient-forms').createSignedUrl(...)`, the same
pattern `admin/page.tsx` already uses for W9 elsewhere), inert/greyed
when it doesn't — never a tappable dead end. NF-3/PCE/Denial Docs come
from `patient_forms` filtered to that `visit_id`; AOB comes from
`patients.aob_url` directly (patient-level, not visit-level); W9 comes
from the `doctors.w9_url` join described above.

**Charts**: built with raw Recharts components directly
(`PieChart`/`BarChart`/etc.), **not** shadcn's official `chart.tsx`
wrapper — that wrapper has an open, unresolved upstream compatibility
issue with Recharts v3 (`shadcn-ui/ui#9892`) as of this session; shadcn's
own docs explicitly say they don't wrap Recharts and encourage building
with it directly, which is the lower-risk path for a production billing
surface. Colors are explicit per-category hex values matching this
page's existing badge colors, following this dashboard's established
literal-hex convention rather than introducing shadcn's `--chart-N`
variable convention. Current chart: a "Paid vs Outstanding by Carrier"
horizontal stacked bar (green = Paid/`received_amount` sum, red =
Outstanding/`billed - received_amount` floored at `$0`), alongside —
not replacing — the pre-existing plain "By Carrier" totals list.

**New files, cumulative across sessions**: `app/billing/page.tsx`,
`app/billing/BillerDashboard.tsx`, `app/components/ui/{card,table,badge,
button,select,dropdown-menu}.tsx`, `app/lib/fonts.ts`, `lib/utils.ts`
(shadcn's `cn()` helper), `components.json`. Dependencies added:
`clsx`, `tailwind-merge`, `class-variance-authority`, `recharts`.
