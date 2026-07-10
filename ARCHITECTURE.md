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
<path> ~/storage/downloads/<n>` then attach is the standing preferred
method — `SYSTEM_PROMPT.md` §3), or "Copy raw contents" from GitHub's
mobile web UI.

On-device paths (Termux, Android-only — no desktop access exists or
will exist): `~/cosmos-dashboard` (confirmed), `~/cosmos-api` (confirmed).

Supabase project URL: `https://ttudxnzmybcwrtqlbtta.supabase.co` — never
change without explicit instruction (`SYSTEM_PROMPT.md` §3).

**Styling note**: Tailwind CSS is present in `package.json` but was
unused until the Biller dashboard. Five deliberate, scoped exceptions
now exist — all approved explicitly after the tradeoff was presented:
1. **Biller dashboard** (`/billing`, §8) — the first exception.
2. **Admin page** (`/admin`, `app/admin/page.tsx`) — full shadcn/ui
   rebuild; same CSS-variable bridge and Oxanium font as the Biller
   dashboard.
3. **MD V2 patient chart** (`/md-v2/[patientId]`, `app/md-v2/`) —
   shadcn Cards, Badge, Tabs; Oxanium font via shared module (Session 23).
4. **MDClient patient list** (`/md`, `app/md/MDClient.tsx`) — shadcn
   Cards with colored left borders; routes to `/md-v2/` (Session 23).
5. **Referral Management dashboard** (`/referrals`, `app/referrals/`) —
   shadcn Cards, Sheet, TanStack Table; same CSS-variable bridge pattern
   as Biller and Admin (Session 25).
Every other screen remains hand-rolled inline `style={{...}}`.

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
fixed session 9; `insurance_carriers` missing all `authenticated` role
policies — fixed session 10, surfaced by new inline error feedback). A related but
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
live database unless noted otherwise in `HANDOVER.md`). **Migrations
001–019 exist as `.sql` files on disk. Migrations 020+ were run directly
in the Supabase dashboard SQL editor — no corresponding on-disk files
exist for these.**
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
- `012_add_user_profiles.sql` — `user_profiles` table, auth foundation
- `013_add_doctor_default_hours.sql` — `default_start_time`/`default_end_time` on `doctors`
- `014_doctor_mailing_address.sql` — dropped `street`/`city`/`state`/`zip`/`pc_street`/`pc_city`/`pc_state`/`pc_zip`; added `mailing_street`/`mailing_city`/`mailing_state`/`mailing_zip`
- `015_office_locations_is_main_office.sql` — added `is_main_office boolean NOT NULL DEFAULT false` to `office_locations`
- `016_patient_visits_location_id.sql` — added `location_id uuid REFERENCES office_locations(id)` to `patient_visits`
- `017_rls_hardening.sql` — all `anon`/`public` policies removed; every table locked to `authenticated` only (Session 12)
- `018_not_null_constraints.sql` — `doctors.license_number`, `doctors.npi`, `doctors.mailing_state`, `patient_forms.form_type` constrained NOT NULL (Session 12)
- `019_session_timeout.sql` — `practice_settings.session_timeout_minutes int NOT NULL DEFAULT 15` (Session 13)
- 020 — `login_attempts` table (`id`, `email`, `attempted_at`, `success`); index on `email`; RLS `authenticated` + `anon` full access (anon required — lockout check runs pre-auth) (Session 17)
- 021 — `practice_settings.mfa_required boolean DEFAULT false` (Session 17)
- 022 — `patient_visits.nf3_preflight_passed boolean DEFAULT false`; NF-3 workflow preflight columns (Session 17)
- 023 — `audit_logs` table (`id`, `created_at`, `user_id`, `user_role`, `action`, `entity_type`, `entity_id`, `old_data jsonb`, `new_data jsonb`, `ip_address`); indexes; RLS `authenticated` SELECT + INSERT; DB triggers on 7 tables (Session 17/18)
- 024 — `patients.attorney_email text` — stores attorney email auto-filled from `lawyers.email`; used by `/send-billing-packet` endpoint (Session 22)
- 025 — `doctors.pc_npi text` — PC corporation NPI; resolved by `_resolve_billing_npi()` in `database.py`; used in all `forms/*.py` as `billing_npi` (Session 23)
- 026 — `referral_providers`, `referral_types` (seeded: MRI/CT/MRA/Ultrasound/PT/Ortho/Pain Mgmt/EMG/VNG/ANS), `referrals`, `referral_appointments`, `referral_documents`, `referral_status_history`, `referral_timeline`, `referral_notes`, `referral_notifications` — full Referral Management Module schema; all tables RLS-enabled `authenticated` only; `updated_at` triggers on 4 tables (Session 25)
- 027 — `patients.email text` nullable — patient email for appointment notifications (Session 30)
- 028 — Performance indexes: `idx_patient_visits_patient_id`, `idx_patient_visits_submitted_to_billing` (partial WHERE NOT NULL), `idx_patient_visits_location_id`, `idx_biller_md_flags_visit_id`, `idx_biller_md_flags_patient_id`, `idx_referrals_referral_provider_id` (Session 31)
- 029 — `referrals.body_parts text[] DEFAULT '{}'`; `referral_appointments.body_parts text[] DEFAULT '{}'` — MRI session splitting; body parts pool per referral, per-appointment body parts assignment (Session 31)
- 030 — `referral_documents.appointment_id uuid REFERENCES referral_appointments(id)` nullable; `idx_ref_docs_appointment_id` index — links uploaded result documents to specific MRI sessions (Session 31)

Key tables referenced throughout the codebase: `patients`,
`patient_visits` (visit-scoped data, including `cpt_codes`/`icd10_codes`,
`received_amount`, `claim_status`, `payment_status`, `location_id` FK →
`office_locations` — see §11 for how the billing fields are used on the
Biller dashboard), `visit_line_items` (billing), `patient_forms`
(generated-document tracking — `form_type`, `visit_id`, `filename`, used
to find/replace a patient's generated PDFs per visit, and now also Denial
Docs uploads/deletes — see §11), `cpt_codes` (fee schedule — the *only*
source of fee data; there is no separate "fee schedule" concept anywhere
in the codebase; unique constraint on `cpt_code` added migration 011),
`doctors` (PC/tax fields per §5 of `PRODUCT_SPEC.md`, `w9_url`,
`license_number` (required — minimum 6 chars, state license/certification
number used in NF-3 Section 16), signature; `doctor_id` is its primary
key; also `license_type` text DEFAULT 'MD' (options: MD, NP, PA, DC, PT,
Acupuncturist, Psychologist, Podiatrist, Other), `supervising_provider_id`
uuid FK self-referencing (required when `license_type = 'NP'`),
`available_days` text[], `max_patients_per_day` int DEFAULT 25 — migration
009. `default_start_time`/`default_end_time` time DEFAULT '09:00'/'17:00' —
migration 013. `mailing_street`/`mailing_city`/`mailing_state`/
`mailing_zip` text (mailing address for insurance correspondence;
replaces the dropped `street`/`city`/`state`/`zip`/`pc_street`/
`pc_city`/`pc_state`/`pc_zip` columns) — migration 014.

**Tables with schema changes in Sessions 10–11:**
- `office_locations` — added `is_main_office boolean NOT NULL DEFAULT false`
  (migration 015). Main office sorts first in all queries
  (`order('is_main_office', ascending: false).order('name')`). Only one
  location can be `is_main_office = true` — enforced on save by clearing
  all other rows before setting the new one.
- `patient_visits` — added `location_id uuid REFERENCES office_locations(id)`
  (migration 016). Written by `handleStartVisit` in `calendar/page.tsx`
  (uses `apt.location_id` then falls back to `sessionStorage.getItem('cosmos_location_id')`)
  and by `PatientChart.tsx` manual visit INSERT (uses `sessionStorage.getItem('cosmos_location_id')`).
  Used by `main.py` to fetch the office location address for NF-3
  Section 15 Place of Service.
- `insurance_carriers` — added `claims_department text`, `street2 text`,
  `claims_email text` columns (session 10). Added `authenticated` role
  RLS policy (was missing — `anon`-only coverage).
- `patients` — `signature_url` column dropped (session 10), data migrated
  to `patient_signature_url`. The canonical patient signature column is
  now `patient_signature_url` only.

**`user_profiles` table changes (session 9):**
- `user_profiles_role_check` constraint updated to include `pa` and `np`:
  `CHECK (role IN ('frontdesk', 'md', 'pa', 'np', 'billing', 'admin', 'superadmin'))`
- `doctor_id` column (pre-existing) is now also linked for PA/NP users —
  required for the login location picker to work for those roles.

**FK constraints added (session 10):** All FK relationships are now complete.
Key additions:
- `appointments.patient_id → patients` ON DELETE CASCADE
- `patient_visits.patient_id → patients` ON DELETE CASCADE
- `visit_line_items.visit_id → patient_visits` ON DELETE CASCADE
- `visit_line_items.patient_id → patients` ON DELETE CASCADE

**PostgREST join shape note:** FK-joined tables are returned as arrays even
for many-to-one relationships. Consumers must handle both array and object:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

**Doctor-to-visit linkage gap:** `patient_visits` does not reliably
record which doctor performed the visit. A `doctor_name` free-text
column exists, but the real production save path (`PatientChart.tsx` →
`handleSave()`) never writes it — the *only* place that column gets
populated is `app/dev/page.tsx`'s synthetic test-data generator. Don't
trust `patient_visits.doctor_name` for anything real. The reliable link
is `patients.doctor_id`, captured through an actual dropdown on
the patient registration form. `patient_visits.location_id` (migration
016) now reliably records where the visit occurred.

**W9 storage — Supabase Storage API only:** W9 PDFs (and all other
generated documents) are stored in the `patient-forms` storage bucket.
Direct SQL DELETE on `storage.objects` is blocked by Supabase's
`storage.protect_delete()` trigger — always delete storage objects via
the Supabase Storage REST API (`DELETE /storage/v1/object/{bucket}/{path}`
with service role key), never via SQL.

---

## 4. Backend API (`cosmos-api`)

FastAPI on Render. File ownership:
- `main.py` — route definitions + shared dispatcher. Also owns all PDF
  filename construction — see `PRODUCT_SPEC.md §12` for the naming
  convention. `_fmt_date(raw) -> str` helper (line 16) converts any ISO
  DB date string (`YYYY-MM-DD`) to `YYYYMMDD` for use in filenames;
  returns `"00000000"` as a safe fallback for null/missing values.
- `database.py` — builds request-specific data dicts for PDF generators.
  Exports prefixed doctor fields: `doctor_name`, `doctor_npi`,
  `doctor_license_number`, `doctor_phone`, `doctor_fax`, `doctor_tax_id`,
  `doctor_specialty`, `doctor_license_type`, `doctor_signature_url`,
  `doctor_address`, `doctor_street`, `doctor_city`, `doctor_zip`,
  `doctor_pc_corp_name`, `doctor_mailing_address`,
  `doctor_mailing_street/city/state/zip`, `supervisor_npi`,
  `supervisor_tax_id`, `supervisor_specialty`, `supervisor_signature_url`,
  `supervisor_name`. Supervisor fields are populated from the supervisor's
  own record when `supervising_provider_id` is set; fall back to the
  treating doctor's own values when not supervised (so independent MDs
  correctly have their own data in all supervisor fields).
  **Always check `database.py` `_build_doctor_fields()` for the exact
  prefixed key name before referencing a doctor field in any `forms/*.py`.**
- `forms/*.py` — one module per document/referral type; PDF field-fill logic only
- `forms/base.py` — shared PDF helpers only (signature injection, field filling);
  no database logic
- `pdf_engine.py` — pure router; re-exports each `forms/*.py` module's
  generator function for `main.py` to call by name

Referral-type documents share one generic dispatch path: a
`REFERRAL_FORM_CONFIG` entry maps a type to its generator function name +
`tag` (DB `form_type` value) + `fn_type` (filename token) + labels.
Adding a new referral type means touching `forms/<type>.py`, the config
entry + route in `main.py`, and the import/`__all__` entry in
`pdf_engine.py` — all three, every time. **`tag` and `fn_type` are
separate keys** — `tag` is stored in `patient_forms.form_type` and read
by `ReferralGrid.tsx`; `fn_type` is used only in the filename. Never
conflate them.

Non-referral documents (NF-2, NF-3, AOB, W-9, PCE) are routed individually;
not all import through `pdf_engine.py` (`/generate-w9` imports `forms.w9`
directly) — confirm the actual import path per document rather than assuming
the referral pattern applies.

**`patient_forms` insert rule — required for zip inclusion:** every
per-visit document type must insert a `patient_forms` row with `visit_id`
explicitly set after generating the PDF. This is the mechanism the
billing packet zip (`PatientProfile.tsx` `handleDownloadZip`) uses to
collect all files for a visit — it queries `patient_forms` filtered by
`visit_id`. A document stored anywhere else, or inserted with
`visit_id = null`, is silently excluded from the zip. NF-2 and AOB are
the only intentional exceptions — they are patient-level documents stored
on `patients.nf2_url` / `patients.aob_url` and are added to the zip
separately via those fields.

**W9 generation rules (`/generate-w9`):**
- Requires `!supervising_provider_id AND (!!pc_corp_name OR tax_classification === 'individual')`
- Returns HTTP 400 for supervised providers or providers without billing
  entity status — enforced at the API level regardless of UI state.

---

## 5. NF-3 Field Mapping (current state, post-Session 11)

Key field assignments:

| Field | Value |
|---|---|
| `provider.name_address` | PC corp name + `\n` + mailing address (Pay-To) |
| `services.N.place_of_service_zip` | Office location address (two-line: `street\ncity, state zip`) |
| `treating_provider.1.name` | Treating provider full name |
| `treating_provider.1.title` | `doctor_license_type` (MD/PA/NP/etc.) |
| `treating_provider.1.license_or_certification_number` | Treating provider **state license number** (`doctor_license_number`) — **not NPI** |
| `assignment.provider_assignee_print_name` | PC corp name (payee_name) |
| `assignment.provider_assignee_signature` | Supervisor/billing MD signature (image injection) |
| `provider.signature` (bottom row) | Supervisor/billing MD signature (image injection) |
| `provider.irs_tin` | Supervisor name (printed name) |
| `provider.wcb_rating_code` | Supervisor NPI |
| `provider.specialty_if_none` | Supervisor specialty |
| `provider.owners_and_credentials` | Empty (Section 17 — left blank by product decision) |

**Section 16 rule:** LICENSE OR CERTIFICATION NO. is the treating
provider's state-issued license/certification number — never NPI. NPI
is a federal identifier used elsewhere on the form (billing header).

**Supervisor fallback logic:** When treating provider has `supervising_provider_id`,
all billing fields (corp name, mailing address, NPI, tax ID, specialty, signature)
use the supervisor's data. When no supervisor, treating provider's own data
is used for all fields.

**W9 routing for NF-3:** After doctor merge, if treating doctor has
`supervising_provider_id`, fetches supervisor's `w9_url` and injects it
into `patient_data` as the billing entity W9. Supervised providers have
no W9 of their own; the supervisor's W9 is the correct document.

---

## 6. AOB Field Mapping (current state, post-Session 11)

AOB (Assignment of Benefits) assigns benefits to the **billing entity**,
never to the treating provider. Provider fields:

| Field | Resolution |
|---|---|
| `assignee_provider_name` | `doctor_pc_corp_name` → `supervisor_name` → `doctor_name` |
| `provider_printed_name` | Same as above |
| `provider_address` | `doctor_mailing_address` (resolves to supervisor's mailing address when supervised) |
| Provider signature | `supervisor_signature_url` → `doctor_signature_url` |

`doctor_pc_corp_name` and `doctor_mailing_address` are already resolved
to the supervisor's values by `database.py` when `supervising_provider_id`
is set — AOB uses these resolved fields directly.

---

## 7. Frontend Data Fetch Pattern

Standard: a server-component `page.tsx` wrapper does the initial Supabase
query with `revalidate: 0`, then passes the result as props to a client
component that owns all interactivity. Don't fetch inside the client
component unless there's a specific reason to deviate.

---

## 8. Document Generation Pattern (Save→View)

All MD-discretionary referral types follow the Save→View pattern:
- Button starts as "Save [type]", generates and stores the PDF on tap.
- Button flips to "View" on success; tapping "View" opens the existing
  signed URL rather than regenerating.
- Revisiting an already-saved referral shows "View" immediately (prevents
  accidental overwrite).
- "Regenerate" link available as a confirm-gated escape hatch.
- ICD-10 Diagnosis PDF is the sole auto-fire exception (fires on visit save,
  no tap required).

---

## 9. Admin Panel (`app/admin/page.tsx`)

Six-tab system: Overview / Carriers / Providers / Lawyers / CPT Codes /
ICD-10. Uses shadcn/ui + Oxanium — second approved exception to the
hand-rolled inline-styles convention (`SYSTEM_PROMPT.md` §9).

**Overview tab** shows: Practice Info card (name, corp, address, TIN,
phone/fax), KPI cards (providers, documents, patients, visits, locations,
users), Office Locations section (manage toggle, Edit/Del per card, Add
Location form with Main Office toggle), Dev Tools card.

**Providers tab** shows: grouped hierarchy (supervising/independent MDs
with cyan border, supervised providers with purple border `#a855f7`,
indented `ml-4`). Three-tab provider form: Credentials / Billing / Schedule.
Credentials: name, license type, specialty, supervising provider, email,
phone, fax, NPI, **license # (required — minimum 6 chars)**, signature.
Billing: mailing address (required for independent providers, optional
for supervised), PC corp name, tax classification. Supervised providers
show a read-only "Billing under Supervisor's PC" card instead of the
mailing address form.
Schedule: location assignments (required before Save Provider can be clicked
for existing providers). New provider flow: two-step — first save creates the
record, then reopens in edit mode on Schedule tab for location assignment.

**W9 buttons on provider cards**: shown only when provider meets billing
entity criteria (`!supervising_provider_id AND (!!pc_corp_name OR tax_classification === 'individual')`).
Supervised providers show no W9 button regardless of `w9_url` value.

**Dropdown contrast fix (Session 11):** All `SelectContent` use
`bg-[#1a2235] border-[#2a3a5a] text-[#e2e8f0]`. All `SelectItem` use
`text-[#e2e8f0] focus:bg-[#00cfff20] focus:text-white`. Native `bg-card`
was dark-on-dark unreadable.

**SelectTrigger color fix** — all `SelectTrigger` elements in Admin have
`style={{color:'#f0f4f8'}}` explicitly set. Shadcn's `SelectValue` renders
its selected value in the trigger's own color context, which is not
reliably inherited on this project (preflight gap, §11).

**Users tab** shows: user cards (name, email, role badge with color,
active/inactive state). Role dropdown: Front Desk / MD / PA / NP / Billing
/ Admin / Superadmin. "Linked Doctor" field shown for MD, PA, NP roles.
PA/NP users must have `doctor_id` linked for the login location picker
to function.

---

## 10. Login Flow (`app/page.tsx`)

Three stages: `login` → `location` (md/pa/np) → `dashboard` (superadmin picker).

`ROLE_META` entries:
- `frontdesk` → `/dashboard`
- `md` → `/md`
- `pa` → `/md`
- `np` → `/md`
- `billing` → `/billing`
- `admin` → `/admin`
- `superadmin` → `/admin` (then 2×2 dashboard picker)

Location picker always shown for `['md', 'pa', 'np']` when `doctor_id` is set on
the user profile — regardless of how many locations the doctor has.
(`locs.length > 1` bypass removed Session 14.) `cosmos_location_id`
and `cosmos_location_name` stored in `sessionStorage` for use by
`handleStartVisit` and manual visit INSERT in `PatientChart.tsx`.

---

## 11. Biller Dashboard (`/billing`)

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
still can't reach it. This has been the root cause of multiple
independently-discovered bugs across the Biller and Admin dashboards.
**Confirmed instances on Admin (Session 11):** all `SelectContent`
dropdowns were dark-on-dark (fixed with explicit background/text colors);
all `SelectTrigger` elements lost text color once a value was selected
(fixed with `style={{color:'#f0f4f8'}}`). Always set color/font/size
explicitly on any new bare button or shadcn trigger/content element —
see `AI_STYLE_GUIDE.md` §1 for the full confirmed list.

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
Outstanding chart below.

**Status vs. Denial Status** — two genuinely separate fields, by
deliberate earlier design decision, never collapsed: `claim_status`
(workflow stage: Submitted/Accepted/Needs Review/Appeal/Under
Investigation — the "Status" column) and `payment_status` (outcome:
none/Denied/Paid/IME Cut Off/Missing Docs/Fraudulent/Policy Exhausted —
the "Denial Status" column, renamed from "Payment Status" for clarity;
label-only change, field name unchanged). The "Submitted"
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
