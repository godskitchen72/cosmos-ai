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
upload/paste from the product owner's device (`git show HEAD:<path> >
~/storage/downloads/<name>` then attach is the standing preferred
method — `SYSTEM_PROMPT.md` §3), or "Copy raw contents" from GitHub's
mobile web UI.

On-device paths (Termux, Android-only — no desktop access exists or
will exist): `~/cosmos-dashboard` (confirmed), `~/cosmos-api` (assumed
parallel, never explicitly confirmed by the product owner).

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
UPDATE policy — both fixed). A related but distinct pattern, confirmed
this session: a table can have RLS **disabled entirely** (`patient_forms`
— confirmed via `pg_class.relrowsecurity = false`), which means nothing
is restricted at all rather than partially restricted; and a table can
have RLS enabled with exactly one fully-open policy
(`storage.objects` — one `ALL`-command policy scoped only to
`bucket_id = 'patient-forms'`, otherwise unrestricted). Neither of these
is currently causing a bug — both work for what reads/writes them today
— but both are the same systemic class of gap as the audit below and
are tracked in `HANDOVER.md`'s Open Items rather than assumed safe by
default. `sql/003_rls_audit_query.sql` is the standing tool for checking
a table's actual policy set; run it before trusting any read/write path
"just works," especially for newly-added columns.

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

Key tables referenced throughout the codebase: `patients`,
`patient_visits` (visit-scoped data, including `cpt_codes`/`icd10_codes`,
`received_amount`, `claim_status`, `payment_status` — see §8 for how the
last three are used on the Biller dashboard), `visit_line_items`
(billing), `patient_forms` (generated-document tracking — `form_type`,
`visit_id`, `filename`, used to find/replace a patient's generated PDFs
per visit, and now also Denial Docs uploads/deletes — see §8), `cpt_codes`
(fee schedule — the *only* source of fee data; there is no separate "fee
schedule" concept anywhere in the codebase), `doctors` (PC/tax fields per
§5 of `PRODUCT_SPEC.md`, `w9_url`, signature; `doctor_id` is its primary
key; also `license_type` text DEFAULT 'MD' and `supervising_provider_id`
uuid FK self-referencing — migration `009_add_doctor_license_type_and_supervising.sql`).

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
  fields can't hold an image).
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
session — confirm the live filename via the repo before assuming, since
this has changed twice in one session already):
`ANS.pdf`, `DME.pdf`, `ICD10.pdf`, `MRI.pdf`, `PT.pdf`, `RX.pdf`,
`VNG.pdf`, `PCE.pdf` (all renamed this session from long original
names — uppercase short form), plus `ortho.pdf`, `pain_mgmt.pdf` (new
this session — **lowercase**, an unresolved naming-convention split
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
    ortho.py  pain_mgmt.py   new this session; pain_mgmt.py's route is
                              hyphenated (/generate-pain-mgmt) despite the
                              underscore filename -- see SS4
    w9.py
  <PDF template files>.pdf  one per document type, repo root
  requirements.txt
  render.yaml
  .gitignore                NOTE: do not add a blanket *.pdf rule — every
                             PDF here is a tracked template, not generated
                             output (see HANDOVER.md for why this matters)

cosmos-dashboard/
  app/
    page.tsx                  role-select landing screen (Front Desk / MD /
                              Billing / Admin); "Remember my role" device
                              storage; each role's `path`/`soon` flag lives
                              here — flip `soon:false` once a role's
                              dashboard is actually built, or it stays a
                              dead end on this screen forever
    globals.css               theme tokens (`:root` CSS vars) + the
                              shadcn/Tailwind v4 bridge (§8) appended
                              additively at the end; also carries the
                              global `text-size-adjust: 100%` rule (§8)
    lib/
      fonts.ts                shared Oxanium font object (Biller-exception
                              scope, §8) — imported by BillerDashboard.tsx
                              AND by select.tsx/dropdown-menu.tsx, since a
                              font className set only at a parent's root
                              div never reaches content rendered through a
                              Radix Portal (outside that parent's own DOM
                              subtree entirely)
      supabase.ts                browser-side client (anon key) — used for
                              any client-component Supabase call, e.g.
                              signed-URL generation for document badges
      supabaseServer.ts          server-side client (service key) — used by
                              every dashboard's `page.tsx` server wrapper
                              for the initial data fetch
    components/
      DropdownSelect.tsx     generic dark-themed dropdown (use for any
                              select-like control, never a native <select>)
      StateSelect.tsx         same pattern, US states specifically
      PatientForm.tsx         new-patient/edit form; the actual place
                              `patients.doctor_id` gets captured, via a
                              real dropdown (see §3 doctor-linkage note)
      ui/                     shadcn primitives (§8) — Card, Table, Badge,
                              Button, Select, Dropdown Menu. Grown from the
                              original Card/Table/Badge/Button-only set as
                              the Biller dashboard's needs grew; still
                              minimal-footprint by design, add more only as
                              actually needed
    admin/page.tsx            doctor management (PC info, tax classification,
                              signature capture, specialty)
    calendar/page.tsx         MD calendar (weekly/monthly, 20-min slots,
                              doctor-locking via ?doctor_id=)
    dashboard/
      DashboardClient.tsx     FD dashboard (queues: Psych Referral, NF-2
                              mailing, etc.; also its own internal
                              "Billing" tab — a revenue/carrier summary,
                              unrelated to and not replaced by §8's
                              standalone Biller role dashboard)
    billing/
      page.tsx                 server wrapper, same fetch pattern as every
                              other dashboard (direct Supabase query,
                              `revalidate: 0`, props down to a client
                              component) — see §8
      BillerDashboard.tsx      the Biller role's queue (§8)
    dev/page.tsx               synthetic test-data generator; the *only*
                              place `patient_visits.doctor_name` ever gets
                              written (see §3) — not representative of any
                              real save path
    md/
      MDClient.tsx             doctor-scoped via `?doctor_id=` (explicit
                              comment in source: "stop-gap MD scoping
                              ahead of real auth")
      page.tsx                 passes `doctorId` down to `MDClient`,
                              filters `patients` by `doctor_id` — this
                              filter does *not* currently thread through
                              to `[patientId]/page.tsx` below
      [patientId]/
        page.tsx                does **not** accept or forward
                              `doctor_id` — confirmed gap, see §3
                              doctor-linkage note
        PatientChart.tsx       MD-facing patient chart; includes the PCE
                              six-step wizard and the referral-type grid
                              (routes to each referral type's own screen);
                              `handleSave()` does not write any doctor
                              field to the `patient_visits` insert
        mri/
          page.tsx              thin server wrapper -> MriReferral
          MriReferral.tsx
        rx/
          page.tsx
          RxReferral.tsx
        ans/
          page.tsx
          AnsReferral.tsx
        icd10/                  referral screen; component name not
                              confirmed this session (excluded from the
                              Save->View change, PRODUCT_SPEC.md SS3)
        dme/
          page.tsx              thin server wrapper -> DmeReferral; as of
                              this session also queries patient_forms for
                              an existing saved referral on this visit_id
                              before render, passing existingFilename down
          DmeReferral.tsx        canonical referral-screen pattern: Chip-based
                              multi-select, single button. As of this
                              session: Save/View pattern (button starts
                              "Save", morphs to "View" on success without
                              auto-opening the PDF; a separate "Regenerate"
                              text link appears once saved) replacing the
                              prior Generate->View pattern -- see SS7 and
                              HANDOVER.md (deploy status unconfirmed)
        vng/
          page.tsx
          VngReferral.tsx        rebuilt for the v5 template
        pt/
          page.tsx
          PtReferral.tsx         modeled directly on DmeReferral.tsx
        ortho/
          page.tsx               new this session
          OrthoReferral.tsx       new this session
        pain-mgmt/                folder name hyphenated, matching the
                              route (SS4); component file itself is
                              PainMgmtReferral.tsx
          page.tsx
          PainMgmtReferral.tsx    new this session
    patients/
      [patientId]/
        page.tsx                server wrapper, same fetch pattern as every
                              other dashboard
        PatientProfile.tsx       FD-facing patient profile: NF-2 mailing UI,
                              submit-to-billing, fee estimates, the
                              "Referrals & Orders" status grid (3-column,
                              shows View/"Not yet ordered" per type --
                              the 2 prior "Reserved" placeholder slots were
                              replaced this session with real Ortho/Pain
                              Mgmt cards; no reserved slots remain,
                              PRODUCT_SPEC.md SS3)
  components.json              shadcn/ui config (§8) — `ui` alias points
                              at `app/components/ui`, matching this
                              project's existing convention, not shadcn's
                              top-level default
  public/
    cosmos_icon_mark.jpg       product-owner-supplied icon mark; replaces
                              the plain-text "C" gradient avatar across the
                              app's header locations
```

---

## 7. Frontend ↔ Backend Integration Flow (referral generation)

1. A referral screen (e.g. `PtReferral.tsx`) collects clinical input into
   a `referral_data` object whose keys match the live PDF's own AcroForm
   field names directly (no translation layer) for any field with no
   legacy contract to preserve.
2. `POST https://cosmos-api-789w.onrender.com/generate-<type>` with
   `{ patient_id, visit_id, referral_data }`.
3. **As of this session, Save→View is the standing pattern** (replacing
   the prior Generate→View pattern) **for every type except ICD-10**,
   which auto-fires on visit save and was deliberately excluded
   (`PRODUCT_SPEC.md` §3). On success, the button morphs from "Save" to
   "View" **without** auto-opening the PDF — the MD taps the resulting
   "View" state on their own terms. Tapping "View" fetches a fresh
   signed URL client-side
   (`supabase.storage.from('patient-forms').createSignedUrl(filename,
   1800)`, the same pattern `PatientProfile.tsx`'s `handleView` already
   used) rather than reusing the URL returned at generation time, since
   those expire. A separate "Regenerate [Type] Referral" text link
   appears once saved (mirroring the FD profile's existing NF-3/PCE
   Regenerate-link pattern), gated behind a `confirm()` dialog, since
   otherwise there is no way to redo a referral from this screen at all
   once point 3a below makes "View" the default state on every revisit.
   **Deploy status of this change is unconfirmed — see `HANDOVER.md`,
   "Unconfirmed Delivery."**
3a. **Check-on-load**: each referral type's `page.tsx` server wrapper
   now also queries `patient_forms` for an existing row matching this
   `visit_id` + the type's tag, before rendering, and passes the
   resulting filename (or `null`) down as an `existingFilename` prop.
   This means revisiting an already-saved referral shows "View"
   immediately, rather than resetting to "Save" and risking an
   accidental overwrite of a real saved referral with a blank one —
   recommended explicitly over "always reset to Save" given the
   backend's delete-then-insert behavior on every save (point 2 above).
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

## 8. Biller Dashboard (`/billing`)

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
