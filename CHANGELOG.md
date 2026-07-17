## 2026-07-16 — Session 45

### Visit Packet Merge — FD Documents Tab

New `/generate-visit-packet` endpoint in `cosmos-api`. Merges all per-visit
PDFs (PCE + all referral types + ICD-10) into one file using `merge_pdfs()`
added to `forms/base.py`. FD Documents tab shows "Build Visit Packet" button
per visit; "View Packet" and "Rebuild" on success. `visitPacketMap` tracks
each visit independently. `form_type = VISIT_PACKET`, filename
`{pid}_{doa}_{dos}_visit_packet.pdf`. Individual files preserved intact.
Blocked on Render Standard upgrade for production load.

**Files:** `cosmos-api/main.py`, `cosmos-api/forms/base.py`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — DB-Persisted Column Preferences

`user_profiles.fd_column_prefs JSONB` migration applied. Column picker:
centered dropdown, custom mobile-visible checkbox UI, "Columns" header +
Reset button (clears UI + writes null to DB). Prefs loaded on mount,
debounced save on toggle.

**DB:** `ALTER TABLE user_profiles ADD COLUMN fd_column_prefs jsonb DEFAULT null`
**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — Search Bar X Clear Button

`✕` button inside search bar clears `globalFilter` and resets pagination.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — Activity Summary Tab Navigation

Visits / Appointments / Referrals summary cards navigate to their
respective tabs on tap. Each card now tappable (button element).

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### SONO / FC / PSY — New Referral Types (Generic Form)

Three new referral types using `GENERIC_REFERRAL_FORM.pdf` (CMT-REF-MD-001 v2.0):
- **SONO** — Sonography / Ultrasound; body parts: L. Shoulder, R. Shoulder,
  Neck, Mid Back, Lower Back (multi-select)
- **FC** — Functional Capacity Evaluation; pre-filled reason text
- **PSY** — Psychology / Behavioral Health; pre-filled reason text

`referral_types` updated: ULTRASOUND code → SONO; FC and PSY inserted.
Full lifecycle tracking (referrals, status_history, timeline, notifications).
Facility/Provider field removed. No. of Visits removed. Requested Date removed.

**DB:** `UPDATE referral_types SET code = 'SONO' WHERE code = 'ULTRASOUND'`
`INSERT INTO referral_types (label, category, code) VALUES ('Functional Capacity', 'specialist', 'FC'), ('Psychology', 'specialist', 'PSY')`
**Files:** `cosmos-api/forms/sono.py`, `fc.py`, `psy.py`, `main.py`,
`pdf_engine.py`, `app/md/[patientId]/sono/`, `fc/`, `psy/`,
`app/md/[patientId]/components/ReferralGrid.tsx`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### EMG — New Referral Type (Generic Form)

New EMG referral type using `GENERIC_REFERRAL_FORM.pdf`. Body parts:
Upper / Lower (multi-select, stored in `referrals.body_parts`). Full
lifecycle tracking. Pre-filled reason text.

**Files:** `cosmos-api/forms/emg.py`, `main.py`, `pdf_engine.py`,
`app/md/[patientId]/emg/`, `ReferralGrid.tsx`, `FDPatientSheet.tsx`

### Psych Referral Button — Removed

Old `Psych Referral` toggle (writing `psych_referral` to `patient_visits`)
removed. Replaced by PSY referral type with full tracking.

**Files:** `app/md/[patientId]/components/ReferralGrid.tsx`,
`app/md/[patientId]/components/VisitTab.tsx`

### MRI Selector — MRI / MRA / CT Radio Buttons

Replaced YES/NO metal implant binary with three mutually exclusive radio
buttons (MRI | MRA | CT Scan). Selecting one disables the other two sections.
Submit guard requires selection before generating.

**Files:** `app/md/[patientId]/mri/MriReferral.tsx`

### MRI Session Splitter — Gated to MRI/MRA/CT Only

`isImaging` in `ReferralAppointmentTab.tsx` now checks `typeCode` —
SONO/EMG excluded from session splitter UI. `actions.ts` auto-advance
also gated by `isMriType`. Fixes false "MRI / CT Scan Sessions" block
on Ultrasound referrals.

**Files:** `app/referrals/components/ReferralAppointmentTab.tsx`,
`app/referrals/actions.ts`

### Session Card — Above Schedule Form

Existing session card now renders above the Schedule Appointment form
in `ReferralAppointmentTab.tsx`.

**Files:** `app/referrals/components/ReferralAppointmentTab.tsx`

### Auto-Close SONO/FC/PSY/EMG on Result Upload

After uploading a result, referral auto-advances to `closed` when type code
is in `['SONO', 'FC', 'PSY', 'EMG']`. Writes status_history and timeline.

**Files:** `app/referrals/actions.ts`

### Provider Email — Clinical Reason + Body Parts

Provider session notification email now includes Body Parts (when set)
and Clinical Reason (when set) rows.

**Files:** `app/referrals/actions.ts`

### Referral Pipeline — New Report Tab

New **Referral Pipeline** tab in Reports. KPI strip: Total / Pending /
Upcoming / Overdue / Completed. Summary table by referral type with drill-down
to individual referral detail. All columns color-coded. Totals row all green.
Export CSV for both views.

**Files:** `app/reports/ReportsClient.tsx`

---

## 2026-07-15 — Session 44

### Navigation — Back Button Audit and Full Fix

Full audit of back-button behavior across all pages. Two root causes
identified and fixed:

- `PatientFormV2.tsx` — header ← Back button and tab-0 Cancel button
  changed from `router.back()` to `router.push('/dashboard-v2')`. Eliminates
  accidental logout when browser history reached root `/`.
- `FDDashboardV2.tsx` — patient sheet now uses URL hash
  (`/dashboard-v2#patient`). System back pops the hash and closes the sheet
  via `popstate` listener. User stays on `/dashboard-v2`.
- `ReferralDashboard.tsx` — same hash pattern (`/referrals#referral`).

**Files:** `app/components/PatientFormV2.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`, `app/referrals/ReferralDashboard.tsx`

### DashboardNav — Patients Link Fixed + Search Focus

Patients quick link changed from `/patients` (404) to `/dashboard-v2`.
Now scrolls to work queue table and auto-focuses the search input.

**Files:** `app/components/DashboardNav.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`

### FD Work Queue — Table UI Overhaul

- Headers → bright green `#19a866` (all except select checkbox)
- Data cells → cyan `#00cfff` (all except Workflow Stage and Documents)
- Page size options: 10 (default), 15, 25, 50, 100
- Export CSV on same row as Work Queue title (right side)
- Columns button → cyan styling
- Search input `id="patientsearch"` for Patients link focus targeting
- Work Queue div `id="workqueue"` for scroll targeting

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Work Queue — Doc Status Logic Fix

**Docs OK** now requires signature + AOB + NF-2 generated (`nf2_url`).
New **NF-2 Missing** doc status badge (orange). `nf2_url` added to Patient
interface and dashboard-v2 select query.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`,
`app/dashboard-v2/page.tsx`

### FD Work Queue — Workflow Stage Logic Fix

Workflow Stage now uses `nf2_url` (generated) instead of `nf2_mailed_at`.
Once NF-2 is generated, patient advances past this stage. Mailing tracked
separately via KPI cards.

New labels:
- **NF-2 Missing Stage** (red) — NF-2 not yet generated
- **Book Appointment** — replaces "No Visit"; tapping opens Appointments tab

NF-2 KPI split into **NF-2 Pending Mail** and **NF-2 Missing**.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Work Queue — Badge-to-Tab Navigation

Clicking any Workflow Stage or Documents badge opens the patient sheet
directly on the relevant tab. All badge-to-tab mappings wired.
`FDPatientSheet` accepts `initialTab?: Tab` prop.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### Shared SignatureCaptureModal — Optimistic UI

New `app/components/SignatureCaptureModal.tsx` — shared across
`FDPatientSheet` and `PatientProfile`. Modal closes immediately on Save;
upload happens in background. Eliminates multi-second wait after signing.

**Files:** `app/components/SignatureCaptureModal.tsx` (new),
`app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/patients/[patientId]/PatientProfile.tsx`

### Signature On File — Cyan Card + View Button

All signature status surfaces now show a cyan card when signature is on file:
- Thin cyan border (`1px solid #00cfff30`)
- "✅ Signature on file" in cyan
- Re-sign button
- 👁 View Signature button (Supabase signed URL, 1800s expiry)

Applied to: `FDPatientSheet`, `PatientProfile`, `PatientFormV2`,
`DoctorsSection` (Admin — doctor signatures).

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/patients/[patientId]/PatientProfile.tsx`,
`app/components/PatientFormV2.tsx`,
`app/admin/components/DoctorsSection.tsx`

### FD Patient Sheet — Book Appointment CTA

Appointments tab now shows Book Appointment button (top right) and a
prominent Schedule First Appointment CTA when empty. Both navigate to
`/calendar?patient=${patient_id}`.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### Calendar — Full Redesign

Complete rebuild of `app/calendar/page.tsx`:

- Full FD Dashboard V2 palette (`#0d1821`, Oxanium, cyan/green)
- Booking moved to **bottom-sheet modal** — date field (editable), all
  dropdowns custom dark (no native select)
- **Smart booking:** arriving via `?patient=` auto-opens modal, auto-fills
  patient's assigned MD (green AUTO badge), auto-advances date to next
  available per doctor's schedule
- If FD changes doctor, date re-calculates to next available
- FD can override doctor freely
- **Adaptive doctor filter:** chips for ≤5 doctors, custom dark dropdown
  for >5 (scales to large practices)
- Day cards: capacity bar (green→amber→red), brighter text
- Month view preserved with status dots per day
- View Chart → `/md-v2/[patientId]`
- `+ Book` button always active (defaults to today if no day selected)

**File:** `app/calendar/page.tsx` (full rebuild)

## 2026-07-15 — Session 43

### Email Notifications — Font Fix, AM/PM, Single-Row Layout, ICD-10 Added

Provider-assigned email removed — provider no longer notified on assignment,
only when a session is scheduled. Session emails (patient confirmation +
provider session) fixed:

- Font changed from Oxanium to Arial — Oxanium is a web font unsupported in
  email clients; Outlook was applying its default which caused oversized text
- Layout changed from `display:flex;justify-content:space-between` to
  single-row `Label: Value` format — no more wrapping on long values
- AM/PM conversion added: raw `HH:MM` 24-hour string → `h:MM AM/PM` via
  `fmt12h()` helper in both patient confirmation and provider session emails
- ICD-10 Codes and Referral Type rows added to provider session email
- `referral_submitted_at` still set on provider assignment (unchanged)

**File:** `app/referrals/actions.ts`

### FD Patient Sheet — Overview Tab Restructured

Overview tab sections redesigned:
- **Demographics** — Full Name, DOB, Phone, Email, Patient ID
- **Accident** — Date of Accident (cyan accent), Type of Accident
- **Insurance** — Insurance Co, Policy, Claim, Provider
- **Document Status** — unchanged

Section headers → bright green `#19a866`. Field labels → cyan `#00cfff`.
`accident_description` (collision type from intake) and `policy_num` added
to Patient interface in `FDPatientSheet.tsx` and `FDDashboardV2.tsx`. Both
columns added to patients select in `app/dashboard-v2/page.tsx`.

Insurance tab updated to match: Insurance Co → Policy → Claim →
Date of Loss → Provider. Stale placeholder removed.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`, `app/dashboard-v2/page.tsx`

### FD Patient Sheet — Edit Patient Quick Action Button

Edit button (purple `#a78bfa`, User icon) added to FD sheet quick action bar.
Links to `/patients/${patient_id}/edit`. `EditPatientForm.tsx` updated to
use `PatientFormV2` instead of legacy `PatientForm`.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/patients/[patientId]/edit/EditPatientForm.tsx`

### PatientFormV2 — Tabbed Intake Wizard

New `app/components/PatientFormV2.tsx` — patient intake and edit form
styled to match FD Dashboard V2. 5-tab wizard:

1. **Personal** — name, DOB, SSN last 4, sex, phone, email, address
2. **Accident** — date, time, location, collision type, injuries, vehicle/operator
3. **Insurance** — carrier (auto-fill address), policy, claim, policy holder
4. **Attorney** — firm cascade → attorney → phone/email (optional tab)
5. **Signature** — signature pad, treating provider, status (edit only)

Tab bar identical to FD Patient Sheet (cyan active underline, green completion
dot). Thin cyan progress bar under tabs. Per-tab validation. Next button
shows next tab name. Save only on final tab (green/amber per completeness).
All save/insert/update logic identical to `PatientForm.tsx`.
After save → redirects to `/dashboard-v2`. Auto-generates INTAKE PDF on
new patient save (fire-and-forget, non-blocking).

`app/patients/new/page.tsx` updated to use `PatientFormV2`.

**Files:** `app/components/PatientFormV2.tsx`, `app/patients/new/page.tsx`

### INTAKE PDF Auto-Generation (CMT-INTAKE-001)

Patient Intake Form PDF auto-fills on new patient save. Regen available
in Documents tab.

- 38 fillable AcroForm fields filled via `pypdf`
- Field mapping: demographics, contact, accident type checkboxes (Motor
  Vehicle / Work Related / Slip & Fall / Other mapped from `accident_description`
  text), insurance, attorney, treating provider, intake date
- New endpoint: `POST /generate/intake`
- New generator module: `cosmos-api/generate_intake.py`
- Template bundled: `cosmos-api/PATIENT_INTAKE.pdf`
- New DB column: `patients.intake_url TEXT` (added via Supabase SQL editor)
- Documents tab: **Intake Form** card (purple) above NF-2 with View + Regen
- `patient_forms` table: upsert on each generation

**Files:** `cosmos-api/main.py`, `cosmos-api/generate_intake.py`,
`cosmos-api/PATIENT_INTAKE.pdf`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### DashboardNav — Shared Hamburger Dashboard Switcher

New shared component `app/components/DashboardNav.tsx`. Hamburger button
opens slide-out drawer with dashboard switcher. Deployed on all dashboards:
FD, MD, Billing, Referrals, Reports, Admin.

Drawer: Currently Viewing card → Switch Dashboard (6 dashboards with icons
and subtitles) → Quick Links (Patients, Calendar) → user email → Sign Out.
Active dashboard highlighted. Completed dashboards show green dot.

`backdrop-blur` removed from MD (`MDClient.tsx`) and Billing
(`BillerDashboard.tsx`) sticky headers — was creating CSS stacking context
preventing the drawer from rendering above page content on Android Chrome.
Replaced with solid opaque backgrounds. z-index raised to 9998/9999.

Admin sidebar converted from flex push-layout to fixed overlay. Content
always takes full width. Sidebar slides over on top with dark backdrop;
tapping a nav item auto-closes it.

Iron coin (`/public/iron-coin.jpg`, Game of Thrones Faceless Men) used as
profile image for superadmin: replaces "FD" text circle in FD header and
appears alongside SUPER ADMIN badge on login page.

**Files:** `app/components/DashboardNav.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`, `app/md/MDClient.tsx`,
`app/billing/BillerDashboard.tsx`, `app/referrals/ReferralDashboard.tsx`,
`app/reports/ReportsClient.tsx`, `app/admin/page.tsx`,
`public/iron-coin.jpg`

### Valar Morghulis — Superadmin Full JWT Impersonation

Ghost mode system allowing superadmin to fully sign in as any user.

**Backend:**
- `GET /impersonate/users` — fetches all auth users via Supabase Admin API,
  joins `user_profiles` by UUID for role/name, excludes superadmin
- `POST /impersonate` — verifies superadmin, generates one-time magic link
  token via `POST /auth/v1/admin/generate_link`, returns `token_hash`.
  Logs to `audit_logs`. Both endpoints JWT-verified + superadmin-gated.

**Frontend:**
- Superadmin picker: second tab **Valar Morghulis** (anonymous mask logo)
- User list loads via `/impersonate/users`
- Enter tap → `/impersonate` → `supabase.auth.verifyOtp({ token_hash,
  type: 'magiclink' })` → full JWT swap as target user
- Ghost flags set in `sessionStorage`: `cosmos_ghost_origin`,
  `cosmos_ghost_role`
- MD/PA/NP: navigates directly to `/md?doctor_id=...` (skips location picker)
- All other roles: `window.location.href = meta.path`

**Ghost banner (DashboardNav):**
- Fixed amber bar top of every page when ghost flags present
- Iron coin + "Valar Morghulis — {role} ({email})" + Exit ✕ button
- Exit: clears flags, signs out, returns to `/`

**Branding:**
- Anonymous mask (`/public/ghost-mask.jpg`) on Valar Morghulis tab
- Iron coin on Enter buttons, loading indicator, ghost banner
- Description: *"Valar Dohaeris. Select a user to fully impersonate."*
- Superadmin dashboard grid: FD Dashboard V2 card removed; 4 cards remain

**Files:** `cosmos-api/main.py`, `app/page.tsx`,
`app/components/DashboardNav.tsx`, `public/ghost-mask.jpg`

### Provider Performance Turnaround — N/A Bug Fixed

Turnaround calculation now correctly finds valid appointment/result pairs
on closed referrals. All providers show real avg turnaround days.

**File:** `app/reports/ReportsClient.tsx`

---

## 2026-07-14 — Session 42

### FD Dashboard V2 — Visits Tab Simplified

CPT code chips changed to cyan on both pending and billed rows. Visit rows
tap-to-expand with document drawer briefly added then removed — documents
consolidated to Documents tab exclusively. Billed rows simplified (no expand,
flat grid layout). `patient_forms` fetch reverted to PCE-only in `FDVisitsTab`.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Documents Tab Full Rebuild

Documents tab expanded from NF-2/AOB only to a full document hub:

**MD Records** — single collapsible card (purple accent). One row per visit
with per-visit checkbox, green "Visit" label, cyan date, and pill buttons for
PCE and ICD-10. Checkbox selects all forms for that visit.

**Referral Results** — one collapsible card per referral type. Per-result row:
cyan checkbox, green "Result N" label, "Received:" label, cyan date, View button.
Select All above MD Records selects everything. Sticky action bar when items
selected: "Download ZIP" and "Email Attorney".

All forms from `patient-forms` bucket; referral results from `referral-documents`
bucket. Both tracked as `{ path, bucket }` pairs in selection state.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### cosmos-api — Records ZIP and Email Endpoints

Two new endpoints:

`POST /generate-records-zip` — accepts `{ patient_id, files: [{path, bucket}] }`.
Downloads from correct Supabase Storage bucket per file. Zips in memory.
Returns binary ZIP. Filename: `{patient_id}_{doa}_records.zip`.

`POST /email-records` — same file list + `recipient_email` + `patient_name`.
Builds ZIP, sends via Resend as attachment. From: `records@cosmosmt.com`.
Attorney email pre-filled from `patients.attorney_email`, editable by FD.

Both: JWT-verified, skip failed files rather than aborting.

**File:** `cosmos-api/main.py`

### FD Dashboard V2 — Reports Link in Sidebar

`BarChart2` icon imported. Reports item added to `NAV_ITEMS` pointing to `/reports`.

**File:** `app/dashboard-v2/FDDashboardV2.tsx`

### Referral Dashboard — Awaiting KPI + Overdue Redefined

**Awaiting** (orange `#fb923c`) — new KPI card. Counts sessions where
appointment date has passed and no result uploaded. Session-level. Expands
per-session rows with `⏳ AWAITING` badge and orange row tint.

**Overdue** — redefined. Now fires on new referrals with no appointment
scheduled for 2+ days (FD inaction). Referral-level count.

`computeReferralDisplayStatus()` in `types.ts`: new `'awaiting'` status added
to `ComputedReferralStatus`. No-appointment branch checks `created_at` age ≥ 2
days → `'overdue'`. Past pending session → `'awaiting'` (was `'overdue'`).

`getReferralMetrics()` in `actions.ts`: fetches `created_at`, passes to status
function. Overdue counts referrals; awaiting counts sessions.

**Files:** `app/referrals/types.ts`, `app/referrals/actions.ts`,
`app/referrals/ReferralDashboard.tsx`

### Referral Dashboard — Results Received Column

`listReferrals()` joins `referral_documents ( id, created_at, doc_type,
deleted_at )`. `_results_received_at` = earliest non-deleted result doc
`created_at`. New "Results" column shows green date or `—`. Positioned between
Appt and Ref. Created.

**Files:** `app/referrals/actions.ts`, `app/referrals/ReferralDashboard.tsx`

### Referral Dashboard — Ref. Created Column

"Date" column renamed to "Ref. Created". Moved immediately after Status.
Date format updated to `Mon DD, YY`. Column order: Patient → Status →
Ref. Created → Appt → Results.

**File:** `app/referrals/ReferralDashboard.tsx`

### FD Reports Page — New Route

New `/reports` page. FD-only access via Dashboard V2 sidebar.

**Monthly Summary** — month picker (last 12 months). Table by referral type:
Opened / Closed / Results Received. Totals row. CSV export.

**Awaiting Results** — open referrals with past appointment and no result,
sorted oldest first. Days Waiting column, red after 14 days. CSV export.

**Provider Performance** — per provider: Assigned, Results Received, Result
Rate % (color-coded), Avg Turnaround appointment→result in days (color-coded),
N/A when no results. Unassigned shows "Unassigned". CSV export.

**Open Aging** — four bucket cards (0–7 / 8–14 / 15–30 / 30+ days). Tap to
filter table. Age column color-coded. Show all to reset. CSV export.

**Files:** `app/reports/page.tsx` (new), `app/reports/ReportsClient.tsx` (new)
## 2026-07-14 — Session 42

### FD Dashboard V2 — Visits Tab Simplified

CPT code chips changed to cyan on both pending and billed rows. Visit rows
tap-to-expand with document drawer briefly added then removed — documents
consolidated to Documents tab exclusively. Billed rows simplified (no expand,
flat grid layout). `patient_forms` fetch reverted to PCE-only in `FDVisitsTab`.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Documents Tab Full Rebuild

Documents tab expanded from NF-2/AOB only to a full document hub:

**MD Records** — single collapsible card (purple accent). One row per visit
with per-visit checkbox, green "Visit" label, cyan date, and pill buttons for
PCE and ICD-10. Checkbox selects all forms for that visit.

**Referral Results** — one collapsible card per referral type. Per-result row:
cyan checkbox, green "Result N" label, "Received:" label, cyan date, View button.
Select All above MD Records selects everything. Sticky action bar when items
selected: "Download ZIP" and "Email Attorney".

All forms from `patient-forms` bucket; referral results from `referral-documents`
bucket. Both tracked as `{ path, bucket }` pairs in selection state.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### cosmos-api — Records ZIP and Email Endpoints

Two new endpoints:

`POST /generate-records-zip` — accepts `{ patient_id, files: [{path, bucket}] }`.
Downloads from correct Supabase Storage bucket per file. Zips in memory.
Returns binary ZIP. Filename: `{patient_id}_{doa}_records.zip`.

`POST /email-records` — same file list + `recipient_email` + `patient_name`.
Builds ZIP, sends via Resend as attachment. From: `records@cosmosmt.com`.
Attorney email pre-filled from `patients.attorney_email`, editable by FD.

Both: JWT-verified, skip failed files rather than aborting.

**File:** `cosmos-api/main.py`

### FD Dashboard V2 — Reports Link in Sidebar

`BarChart2` icon imported. Reports item added to `NAV_ITEMS` pointing to `/reports`.

**File:** `app/dashboard-v2/FDDashboardV2.tsx`

### Referral Dashboard — Awaiting KPI + Overdue Redefined

**Awaiting** (orange `#fb923c`) — new KPI card. Counts sessions where
appointment date has passed and no result uploaded. Session-level. Expands
per-session rows with `⏳ AWAITING` badge and orange row tint.

**Overdue** — redefined. Now fires on new referrals with no appointment
scheduled for 2+ days (FD inaction). Referral-level count.

`computeReferralDisplayStatus()` in `types.ts`: new `'awaiting'` status added
to `ComputedReferralStatus`. No-appointment branch checks `created_at` age ≥ 2
days → `'overdue'`. Past pending session → `'awaiting'` (was `'overdue'`).

`getReferralMetrics()` in `actions.ts`: fetches `created_at`, passes to status
function. Overdue counts referrals; awaiting counts sessions.

**Files:** `app/referrals/types.ts`, `app/referrals/actions.ts`,
`app/referrals/ReferralDashboard.tsx`

### Referral Dashboard — Results Received Column

`listReferrals()` joins `referral_documents ( id, created_at, doc_type,
deleted_at )`. `_results_received_at` = earliest non-deleted result doc
`created_at`. New "Results" column shows green date or `—`. Positioned between
Appt and Ref. Created.

**Files:** `app/referrals/actions.ts`, `app/referrals/ReferralDashboard.tsx`

### Referral Dashboard — Ref. Created Column

"Date" column renamed to "Ref. Created". Moved immediately after Status.
Date format updated to `Mon DD, YY`. Column order: Patient → Status →
Ref. Created → Appt → Results.

**File:** `app/referrals/ReferralDashboard.tsx`

### FD Reports Page — New Route

New `/reports` page. FD-only access via Dashboard V2 sidebar.

**Monthly Summary** — month picker (last 12 months). Table by referral type:
Opened / Closed / Results Received. Totals row. CSV export.

**Awaiting Results** — open referrals with past appointment and no result,
sorted oldest first. Days Waiting column, red after 14 days. CSV export.

**Provider Performance** — per provider: Assigned, Results Received, Result
Rate % (color-coded), Avg Turnaround appointment→result in days (color-coded),
N/A when no results. Unassigned shows "Unassigned". CSV export.

**Open Aging** — four bucket cards (0–7 / 8–14 / 15–30 / 30+ days). Tap to
filter table. Age column color-coded. Show all to reset. CSV export.

**Files:** `app/reports/page.tsx` (new), `app/reports/ReportsClient.tsx` (new)

## 2026-07-14 — Session 41

### FD Dashboard V2 — Referrals Tab Full Rebuild

Replaced card layout with full client-side fetch table matching `ReferralsTabV2`
exactly. Per-session row expansion for imaging referrals (MRI/MRA/CT). 8 columns:
Type, Body Parts, Status, Provider, Created, Submitted, Appointment, Results.
Results PDF button opens signed URL from `referral-documents` bucket.
Abbreviated body parts (`abbrevBp`). Status filter strip (All/Open/Closed).
"Full Dashboard →" pre-populates patient name in referral dashboard search.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Documents Tab Simplified

Stripped to NF-2 and AOB only. Removed: PCE, NF-3 preflight, visit selector,
submit to billing. Kept: signature capture, NF-2 generate/view/regen/mail
confirmation, AOB generate/view/regen. Documents tab is now purely a no-fault
form generation surface.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Visits Tab Billing Workflow

Full billing workflow rebuilt in Visits tab:
- Lazy fetch: visits with CPT codes, line items, PCE existence, full patient row
- Red row = locked (PCE missing / preflight not passed / AOB missing / no codes)
- Green row = ready for billing
- 🔒 tap → NF-3 Preflight modal with 8-field checklist
- Custom cyan checkbox on ready visits; batch "Submit X Visits to Billing"
- Submitted visits shown in separate section below

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Realtime Subscriptions

`FDDashboardV2` converted to local state with Supabase Realtime subscription on
`patients`, `patient_visits`, `patient_forms`. KPI counts and sheet data update
live across tabs and devices without page refresh. Tables added to
`supabase_realtime` publication via `ALTER PUBLICATION`.

**File:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — UX Fixes

- Search bar moved below KPI cards (was in sticky header)
- KPI card buttons now use `fontFamily: oxanium.style.fontFamily` (preflight gap)
- Custom cyan div checkbox replaces native checkbox (invisible on Android Chrome)
- Quick actions: Documents button jumps to Documents tab; NF-2 button jumps to Documents tab

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`, `app/dashboard-v2/components/FDPatientSheet.tsx`

### PCE Auto-Generation on MD Visit Save

`VisitTab.tsx` `handleSave` now calls `generatePcePdf(visitId)` silently after
`generateIcd10Pdf` on both save paths. Guard: skips if `pce_data` is empty.
Errors logged to console, never block save. PCE removed from NF-3 preflight
gate — it is a document check, not a data completeness check.

**File:** `app/md/[patientId]/components/VisitTab.tsx`

### Role Clarification (no code change)

- NF-3: generated by Biller. FD runs preflight only.
- PCE: auto-generated on MD visit save (this session).
- NF-2, AOB: FD-generated (Documents tab).
- Referral PDFs: MD-discretionary, Save→View, unchanged.

### Items Closed as Non-Issues

- Lock icon (Item 1): `icon` field in `REFERRAL_STATUS_META` never rendered by any component.
- Appointments tab shows 0 (Item 6): `appointments` table empty — no real bookings yet.

## 2026-07-14 — Session 40

### FD Dashboard V2 — Full Build (Phases 1–4)

New enterprise front desk dashboard at `/dashboard-v2`. Existing `/dashboard`
untouched. Approved as 6th shadcn/Tailwind exception. Framer Motion rejected.

**Phase 1 — Shell:**
Sidebar (desktop fixed, mobile slide-in), sticky header (search, bell,
New Patient, Schedule, FD avatar), 8 KPI cards (5 real data, 3 stubbed with
COMING SOON tag), KPI cards filter work queue on tap.

**Phase 2 — TanStack Work Queue:**
11-column TanStack Data Table. Column sorting, global search, column visibility
toggle, row selection + bulk action bar, CSV export (all filtered rows),
custom PageSizePicker (no native select per AI_STYLE_GUIDE §5), pagination.

**Phase 3 — Patient Sheet:**
Tab reset on new patient open. Alert banners for missing AOB/NF-2/carrier/claim.
Document Status checklist (confirmed columns only). Workflow stage badges
(Intake Incomplete through Billing Ready). Carrier in sheet header subtitle.

**Phase 4 — Patient Sheet Tabs:**
Overview (demographics + activity summary), Insurance, Referrals (FK join data
+ "Manage in Referral Dashboard →" link), Visits, Appointments, Documents,
Timeline (9-step), Notes (session-only textarea).

**Font + Mobile Search:**
Oxanium via `className={oxanium.className}` on root. Mobile search in dedicated
full-width row below header on screens < 768px.

**Files:** `app/dashboard-v2/page.tsx`, `app/dashboard-v2/FDDashboardV2.tsx`,
`app/dashboard-v2/components/FDPatientSheet.tsx`, `app/page.tsx`

### Referral Dashboard — Patient Pre-Filter

`search` state in `ReferralDashboard.tsx` now initializes from
`useSearchParams().get('patient') ?? ''`. Navigating to
`/referrals?patient=Name` pre-populates search and filters table immediately.

**File:** `app/referrals/ReferralDashboard.tsx`

### Schema Lessons (no migrations)

Confirmed column names via existing working code:
- `patients` PK: `patient_id` · DOI field: `doi` · claim field: `claim_num`
- `patient_visits` PK: `id` · `appointments` PK: `id`
- `patients.carrier`: plain text (no FK to insurance_carriers table)
- `referrals`: has `patient_id` directly; mirror `ReferralsTabV2` query for FK joins
## 2026-07-13 — Session 39

### Done/Awaiting/Review Workflow — Removed

Simplified referral lifecycle: FD uploads result → auto-close fires (when all
body parts assigned + all sessions completed). No more Done button, no more
Awaiting/Review queue.

Removed: AWAITING + REVIEW KPI cards, Done button (imaging + non-imaging),
`markSessionNeedsReview`, `donningSessionId`, `pendingDoneSessions`,
`handleDoneFromBanner`, `done_action` dashboard column, metric filter blocks
for awaiting/review, `needs_review`/`isReviewed` delete gate, review-tinted
session card border/bg.

Delete button on uploaded sessions is now always visible.

**Files:** `ReferralDashboard.tsx`, `ReferralSheet.tsx`, `ReferralAppointmentTab.tsx`

### MRA Body Parts Fix

`MriReferral.tsx` `createLifecycleRecord()` had no MRA branch — fell through
to MRI spine/extremity path. Added `if (modality === 'MRA')` branch reading
`MRA_STUDIES` labels. Existing MRA referrals with `body_parts = null` need
regeneration.

**File:** `app/md/[patientId]/mri/MriReferral.tsx`

### Auto-Close body_parts Select Bug Fixed

`uploadReferralResult()` queried appointments with `.select('id, outcome')` —
omitted `body_parts`. `assignedParts` was always `[]`, `allPartsAssigned`
always false, auto-close never fired for imaging. Fixed: `.select('id, outcome, body_parts')`.

**File:** `app/referrals/actions.ts`

### MRI/MRA/CT Auto-Close — All Parts Must Be Assigned

Added pre-close check: fetch `referrals.body_parts`, verify every part appears
in at least one appointment. Prevents premature close when FD has only scheduled
some sessions and plans to return for remaining body parts later.

**File:** `app/referrals/actions.ts`

### Referral Dashboard — MRI/MRA/CT Per-Appointment Row Expansion

Default dashboard list now shows one row per appointment for MRI/MRA/CT
referrals. Non-imaging types remain one row per referral. Metric filter
expansions unchanged.

**File:** `app/referrals/ReferralDashboard.tsx`

### MD ALL REFERRALS Table — Major Overhaul

- MRI/MRA/CT expand to one row per session (was one row per referral)
- Summary table now iterates `filtered` (was `referrals` — bug causing expansion to have no effect)
- Per-session status: Upcoming / Overdue / Uploaded computed from session data; Closed always wins
- Card header warning: per-type red lines inside table card above column headers (replaces standalone banner)
- Tap-to-sort on Type, Status, Provider, Created, Appointment columns
- Body Parts column added after Type; chips moved out of Type cell
- Individual referral cards below table removed entirely
- NEW badge removed from table rows
- Row tap disabled — PDF button in Results column is sole interactive element
- All expandedId / keepExpandedId / autoExpandId state removed

**File:** `app/md-v2/[patientId]/ReferralsTabV2.tsx`

## 2026-07-13 — Session 38

### MRI/VNG/Ortho/Pain-Mgmt/PT — CPT + ICD-10 Codes from patient_visits

**Root cause:** All referral creation pages hardcoded `cpt_codes: []` and
`icd10_codes: []`. `patient_visits` stores codes as comma-separated `text`,
not `text[]` — Supabase insert type mismatch silently threw in `try/catch`,
lifecycle record never created.

**Fix:** Each referral `page.tsx` now fetches codes server-side from
`patient_visits` using `Promise.all`. Normalised at boundary:
`Array.isArray()` check first, then `.split(',').map(s => s.trim())` for
string format, default `[]`. Passed as `cptCodes`/`icd10Codes` props and
wired into each referral INSERT.

**Files:** `mri/page.tsx`, `mri/MriReferral.tsx`, `vng/page.tsx`,
`ortho/page.tsx`, `pain-mgmt/page.tsx`, `pt/page.tsx`, `VngReferral.tsx`,
`OrthoReferral.tsx`, `PainMgmtReferral.tsx`, `PtReferral.tsx`.

DME and RX excluded — different lifecycle insert pattern.

### Referral Selections Storage + Overview Display

**DB columns added:**
`vng_tests text[]`, `vng_symptoms text[]`, `ortho_referral_types text[]`,
`ortho_regions text[]`, `pain_mgmt_testing text[]`, `pain_mgmt_treating text[]`,
`pt_goals text[]`, `pt_modalities text[]`, `pt_frequency text`.

Each referral component maps UI state → label arrays on INSERT. `listReferrals()`
select extended. `ReferralOverviewTab.tsx` displays: Testing Requested,
Symptoms, Referral Requested, Body Part/Region, Testing For, Treating For,
Treatment Goals, Modalities, Frequency.

### Referral Lifecycle Redesign — Auto-Close + NEW RESULTS Badge

**Old flow:** Upload → `needs_review` → MD reviews → Closed.
**New flow:** Upload → Auto-close → `results_viewed_at = null` (flagged
types only) → green "● NEW RESULTS" badge on MD patient chart → MD opens
referral → `results_viewed_at = now()` → badge clears on next reload.

**Flagged types** (badge shown): MRI, MRA, CT, ORTHO, PAIN-MGMT.
All other types: auto-close, no badge.

**DB:** `results_viewed_at timestamptz` added to `referrals`.

**MRI session auto-close:** `uploadReferralResult()` now checks if all
non-cancelled sessions are `outcome = 'completed'` after session upload.
If so, auto-closes referral and sets `results_viewed_at = null` for flagged
types. Previously MRI never auto-closed from the session upload path.

**Badge dismissal:** `markResultsViewed()` new action sets
`results_viewed_at = now()`. Fires in `ReferralSheet.tsx` on open.
`ReferralsTabV2.tsx` silently reloads on `visibilitychange` to clear badge
after user returns from referral sheet.

### Review UI Removal

All MD review workflow artifacts removed across the codebase:

- **`MDClient.tsx`:** "Referral Results — Review Required" banner removed.
  Patient card review badge removed. `reviewReferrals` state + query removed.
- **`ReferralAppointmentTab.tsx`:** Done button removed (imaging + non-imaging).
  "Sent for MD Review" label removed. "✔ MD Reviewed" label removed.
- **`ReferralsTabV2.tsx`:** "Reviewed" badge, "Review" column, "✔ Review"
  button, "✔ Reviewed" cell, `handleReviewSession()`, `reviewingId` state,
  `reviewSession` import — all removed.
- **`ReferralDashboard.tsx`:** REVIEW KPI count set to 0, card shell retained.
- **`types.ts`:** `awaiting_review` stage removed from
  `computeReferralDisplayStatus()`.

### referral_submitted_at — Auto-Set on Provider Email

**DB:** `referral_submitted_at timestamptz` added to `referrals`.

Set automatically in `assignProvider()` / `actions.ts` immediately after
Resend provider notification email succeeds. Added to `listReferrals()` select.

### MD Patient Chart — All Referrals Summary Table

Summary table rendered above referral cards in `ReferralsTabV2.tsx`.

**Columns:** Type | Status | Provider | Created | Submitted | Appointment | Results

- Type: category-colored label + green "● NEW" badge for unviewed flagged results
- Created: `referral.created_at` (MD ordered date)
- Submitted: `referral_submitted_at` (provider email date), `—` if not sent
- Results: `📄 PDF` button if result doc exists; `—` if none

**Bulk doc fetch:** All result docs loaded on referral list load via
`.in('referral_id', allIds)` so PDF buttons are populated immediately without
requiring card expand.

### MRI/MRA/CT Incomplete Parts Warning

`ReferralsTabV2.tsx`: red warning banner above summary table when any open
MRI, MRA, or CT referral has `body_parts` not yet assigned to a session.
Previously only triggered for MRI — extended to MRA and CT.
## 2026-07-12 — Session 37

### MD Review Table Collapse Fix

Silent refresh pattern introduced to `loadReferrals()` in `ReferralsTabV2.tsx`.
`keepExpandedId` and `silent` params added — silent skips `setLoading(true)`
so card never collapses during post-review refresh. `fetchResultDocs` stale
closure bug fixed — early-return guard `if (resultDocs[referralId]) return`
removed; docs always re-fetched after review. `isReviewed` and `handleCardClick`
expandable conditions extended to include `status === 'closed'` so reviewed
referrals remain expandable after auto-close.

### UI Cleanup

Move To status chips removed from `ReferralSheet.tsx`. Awaiting Done banner
and `bannerExpanded` state removed from `ReferralDashboard.tsx`. `pendingDoneSessions`,
`donningSessionId`, and `handleDoneFromBanner` retained — still used by
AWAITING KPI filter expansion.

### Default Tab → Appointment

`ReferralSheet.tsx` `useState<Tab>('overview')` → `useState<Tab>('appointment')`.

### Session Header — Cyan + 12-Hour Time

`ReferralAppointmentTab.tsx`: session number + date + time always `#00cfff`.
`fmtTime12()` helper converts `HH:MM:SS` DB format to `h:MM AM/PM` display.
Applied to MRI session cards and new non-imaging session card.

### ANS Referral Module — Full End-to-End

**DB:** `ans_tests TEXT[]` and `ans_symptoms TEXT[]` columns added to
`referrals` table via Supabase SQL editor.

**Data flow:** `AnsReferral.tsx` saves selected ANS test full labels and
symptom labels to `ans_tests`/`ans_symptoms` on INSERT. `cpt_codes` and
`icd10_codes` fetched server-side from `patient_visits` in `page.tsx` and
passed as props — avoids client RLS ambiguity. `listReferrals()` now selects
`cpt_codes`, `icd10_codes`, `ans_tests`, `ans_symptoms`.

**Overview:** Testing Requested (full labels ✓), Diagnosis/Symptoms (cyan
chips), ICD-10 Codes (cyan chips). Clinical reason, symptoms, ICD-10 in cyan.
CPT codes removed from display.

**Appointment:** MRI-style single session card — `Session 1 · Date · Time`
header (cyan), ANS test chips, Upload · Reschedule · Cancel. Uploaded state:
View PDF · Delete · Done → Sent for MD Review. Mirrors MRI exactly.

**Auto-close:** `reviewSession()` extended — non-imaging referrals now
auto-close when all completed appointments reviewed (previously imaging-only).

**Provider email:** `scheduleAppointment()` provider email includes ICD-10
+ CPT codes for all referral types.

### isImaging Refactor

`isMri` → `isImaging` throughout `ReferralAppointmentTab.tsx`. Gate now
`category === 'imaging'` instead of `body_parts.length > 0`. Future types
route correctly by DB category alone.

### Referral Overview Tab

Clinical reason → cyan. Symptom chips → cyan. ICD-10 chips → cyan. ANS
Testing Requested section (full labels). ANS Symptoms section. CPT section
removed.

### Audit Trail — Full Actor Attribution

**Root cause:** `@supabase/auth-helpers-nextjs` 0.15 broken for Next.js 16
server action session propagation. `@supabase/ssr` 0.12 installed.

**Fix:** All exported `actions.ts` functions accept `userId?: string | null`.
`const actorId = userId ?? await getActorId()`. `ReferralSheet.tsx` and
`ReferralsTabV2.tsx` call `supabase.auth.getUser()` on mount, store in
`currentUserId` state, pass to every server action call. Functions covered:
`updateReferralStatus`, `assignProvider`, `scheduleAppointment`,
`cancelSession`, `rescheduleSession`, `reviewSession`, `uploadReferralResult`,
`markSessionNeedsReview`, `addReferralNote`, `createReferral`,
`confirmSessionResults`, `deleteSessionResult`.

**Timeline display:** `user_profiles` fetched separately after timeline load
(no FK — client-side merge). Format: `ROLE · Full Name` (role uppercase cyan).
Historical events remain unattributed — no backfill.

## 2026-07-10 — Session 33

### Per-Session Cancel

cancelSession(referralId, appointmentId) added to actions.ts. Writes
outcome='cancelled' to referral_appointments (row kept for audit). Reverts
referral status to most recent non-scheduled status from
referral_status_history (Option A — history lookup). Writes status history
+ timeline rows. Two-tap confirm pattern on session card: first tap shows
inline confirm, second tap executes. Cancel button hidden when
outcome=completed. __dismiss__ sentinel used for Keep button. handleCancelSession()
in ReferralSheet.tsx handles dismiss, first-tap-show, second-tap-execute logic.

### Per-Session Reschedule

rescheduleSession(referralId, appointmentId, ...) added to actions.ts.
Updates referral_appointments row in place: new date/time/location/confNum,
outcome→null, body_parts→[]. FD re-selects body parts from referral's full
pool (up to 2). Referral status unchanged. Writes timeline entry. Inline
reschedule form renders on session card when reschedulingSessionId matches.

### PDF View Badge on Completed Sessions

📄 View PDF button added before Delete button on completed session cards.
handleViewSessionDoc() in ReferralSheet.tsx creates 15-minute signed URL
from referral-documents bucket and opens in new tab. onViewSessionDoc prop
added to ReferralAppointmentTab interface and destructured.

### Patient Name + DOB/DOI in ReferralSheet Header

Patient name added as cyan (#00cfff) subtitle beneath referral type label.
DOB + DOI displayed in bright green (#19a866) below name in mm/dd/yyyy
format. patient_name renders correctly. patient_dob/patient_doi currently
null — PostgREST inline join with dob/doi columns caused listReferrals()
to return 0 rows (reverted, deferred to client-side fetch Session 34).

### types.ts Updates

ReferralSummary: patient_name, patient_dob, patient_doi, _all_appointments
fields added. _all_appointments required for UPCOMING filter serialization
fix (Next.js server actions strip unknown type properties).

### Font Size Bump — ReferralAppointmentTab

All inline fontSize values +2pt: 10→12 (session header, chips, scheduled
count, NEXT SESSION label, selected helper text), 11→13 (MRI Sessions header,
parts chip, all sessions scheduled, Assigned Provider header, Upload Result
button), Confirm Results button →14.

### Timeline Oldest-First + Color Updates

referral_timeline query ascending: true (oldest first). Event label text
→ cyan (#00cfff). Timestamps → bright green (#19a866). Bullet dots →
bright green (#19a866).

### NEXT SESSION Label + Chip Colors

NEXT SESSION label → bright green (#19a866). Unselected body part chips
→ cyan (#00cfff) in both main pool and inline reschedule form.

### Cancel Session Button Label

"✕ Cancel Session" → "✕ Cancel" on session cards.

### UPCOMING KPI Fix

getReferralMetrics() UPCOMING count adds .is('outcome', null) to exclude
completed and cancelled sessions. Previously counted all scheduled
appointments regardless of outcome, inflating the KPI.

### UPCOMING Filter Per-Session Expansion

ReferralDashboard.tsx metricFilter==='upcoming' block now expands MRI
referrals into one row per upcoming pending session. Each row has
_session_appointment set to that session's data. Requires _all_appointments
on base spread in listReferrals() (added this session).

### Email Templates Rebuilt

All three email templates in actions.ts rebuilt. Replaced table/tr/td
layout with div row pairs (display:flex; justify-content:space-between).
font-family:'Oxanium',sans-serif added to all HTML elements. Email system
confirmed end-to-end: Resend domain cosmosmt.com verified, all /emails
calls returning 200, provider session email hitting referralsout@outlook.com.
Patient emails not sending — all test patient email fields are NULL (test
data only, not a code bug).

### Bug Fix — TS1117 Duplicate fontSize

Confirm Results button had duplicate fontSize key after email patch. Removed
original fontSize:12 from button style object.

### Bug Fix — UPCOMING Dashboard 0 Results

listReferrals() dob/doi inline join caused PostgREST to error and return 0
rows. Reverted patients nested select to first_name/last_name only.
patient_dob/patient_doi set to null in base spread.

### Deferred to Session 34

Lock icon removal from Closed status (types.ts icon field — emoji Unicode
encoding mismatch in Python patch, anchor NOT FOUND). Patient DOB/DOI
client-side fetch in ReferralSheet.tsx refreshDetail().

---

## 2026-07-10 — Session 32

### ReferralSheet.tsx Refactor

Split 1,078-line monolith into shell + 5 tab components under
app/referrals/components/. Zero behavior change — deployed and confirmed
before feature work began.

New files: ReferralDropdowns.tsx, ReferralOverviewTab.tsx,
ReferralAppointmentTab.tsx, ReferralDocumentsTab.tsx, ReferralNotesTab.tsx,
ReferralTimelineTab.tsx. ReferralSheet.tsx reduced to shell (state, handlers,
tab routing, prop passthrough).

### types.ts Updates

ReferralDocumentRow.appointment_id: string | null added (Migration 030).
UploadSessionResultInput interface added. reviewed status color changed from
#1a3a1a/#86efac to #19a866/#ffffff (solid green — terminal complete state).

### Per-Session MRI Result Upload — Full Workflow

Product decisions: session upload marks outcome=completed only (no status
change); FD taps Confirm Results to advance to needs_review; MD taps Mark
Reviewed to advance to reviewed (solid green); per-session reschedule/cancel
deferred to Session 33.

actions.ts — uploadReferralResult() extended with optional appointmentId:
writes appointment_id to referral_documents, sets outcome=completed on that
session row. confirmSessionResults() added: FD-initiated, direct update to
needs_review (bypasses VALID_TRANSITIONS — intentional for async clinical
event). deleteSessionResult() added: deletes referral_documents row, reverts
referral_appointments.outcome to null, removes storage object (best-effort).
listReferrals(): outcome added to appointment inline select; body_parts
explicitly set in base spread to prevent PostgREST join collision;
pendingAppts filter uses (a.outcome ?? null) === null.

ReferralSheet.tsx — uploadingSessionId, confirmingResults, deletingResultId
state added. handleUploadSessionResult(), handleConfirmSessionResults(),
handleDeleteSessionResult() handlers added. sessionDocuments prop derived
from detail.documents filtered to result type with appointment_id set.

ReferralAppointmentTab.tsx — per-session ⬆ Upload Result button (outcome
null); ✓ Result Uploaded + filename + 🗑 Delete button with inline confirm
(outcome=completed); Confirm Results button when ≥1 session uploaded and
referral not yet needs_review/reviewed/closed.

ReferralsTabV2.tsx — needs_review cards: orange border, tap to expand docs,
Mark Reviewed button (advances to reviewed). reviewed cards: green border,
tap to expand docs (no Mark Reviewed). Both: Open Full Referral → link.
loadReferrals() extracted for post-review refresh. fetchResultDocs()
on-demand, cached per referral.

### Bug Fix — refreshDetail select('*') outcome misread

ReferralSheet.tsx refreshDetail() used select('*') on referral_appointments.
Supabase JS client column ordering caused outcome to be misread as truthy for
fresh appointments with outcome=null in DB — session cards rendered green
"✓ Result Uploaded" with no Upload Result button. Fixed with explicit column
list. Also fixed stale toast message: "Referral advanced to Needs MD Review"
→ "Tap Confirm Results when ready." Confirmed on fresh patient data.

### Bug Fix — listReferrals body_parts spread collision

body_parts from referral row was potentially colliding with appointment-level
body_parts in ...r spread. Fixed with explicit body_parts assignment in base
object. outcome added to appointment inline select for correct pendingAppts
filtering.

---

## 2026-07-10 — Session 31

### Infrastructure — DB Indexes (Migration 028)

6 indexes added to Supabase SQL editor. Pre-existing index audit confirmed
referral tables already well-indexed from Migration 026. Gaps filled:
- idx_patient_visits_patient_id
- idx_patient_visits_submitted_to_billing (partial WHERE NOT NULL)
- idx_patient_visits_location_id
- idx_biller_md_flags_visit_id
- idx_biller_md_flags_patient_id
- idx_referrals_referral_provider_id
All used IF NOT EXISTS. login_attempts.email index confirmed pre-existing.

### Infrastructure — Sentry Error Monitoring

cosmos-dashboard: @sentry/nextjs installed. sentry.client.config.ts,
sentry.server.config.ts, instrumentation.ts created manually (wizard not
usable in Termux). DSN confirmed working via curl test — event received
in Sentry dashboard. Sentry project: cosmos-dashboard.

cosmos-api: sentry-sdk 2.64.0 installed (base, not [fastapi] — pydantic-core
requires Rust on ARM/Termux). sentry_sdk.init() added to main.py after
import supabase as sb. sentry-sdk>=2.64.0 added to requirements.txt.
Sentry project: cosmos-api.

Both projects under cosmosmedtechnologies Sentry org. Alert: 1 occurrence,
notify via email.

### MRI Referral UI — Spine Buttons

Spine buttons now rendered in rows of 2 (Cervical W/O | Cervical W/WO).
Per-pair mutual exclusivity: selecting W/O deselects W/WO for same region
and vice versa. Implemented via SPINE_PAIRS toggle logic in MriReferral.tsx.

### MRI Referral UI — CT Section

CT / CAT Scan section dimmed (disabledOverlay + secDisabled) when NO — MRI
available is selected. CT enabled only when YES — CT only (metal implant).
Label shows "(MRI selected — CT unavailable)" when dimmed.

### Migration 029 — MRI Session Tracking

ALTER TABLE referrals ADD COLUMN body_parts text[] DEFAULT '{}';
ALTER TABLE referral_appointments ADD COLUMN body_parts text[] DEFAULT '{}';

### MRI Session Splitting — Full Workflow

Product decisions: max 2 body parts per session; FD manually selects which
parts go in each session; auto-advance to scheduled when all sessions booked;
MRA/CT session splitting deferred.

MriReferral.tsx — createLifecycleRecord() now writes body_parts[] (MRI spine
+ extremity labels only, MRA/CT excluded) to referrals table.

types.ts — ScheduleAppointmentInput: body_parts?: string[]. ReferralSummary:
body_parts: string[] | null, _session_appointment optional field,
current_appointment.outcome added. ReferralAppointmentRow: body_parts optional.

actions.ts — scheduleAppointment() writes body_parts to referral_appointments.
Auto-advance: MRI referrals only advance to scheduled when appointment_count
>= ceil(body_parts.length / 2). Non-MRI advances on first appointment.
listReferrals() adds body_parts + outcome to select; expands MRI referrals
with pending appointments into one row per session (_session_appointment).
Provider session email added — fires on every scheduleAppointment() call
with date, time, body parts for that session.

ReferralSheet.tsx — Overview tab: CLINICAL REASON + PROVIDER labels now
#19a866 (bright green). Body parts shown as cyan chips below clinical reason.
Header: body_part text removed (moved to Overview). Appointment tab: MRI
Sessions card with session counter, scheduled sessions list, unassigned parts
pool (select up to 2), schedule form visible when sessions remain. sessionParts
state added; wired into handleSchedule(); cleared on cancel and save.

ReferralDashboard.tsx — UPCOMING KPI: individual referral_appointments rows
where scheduled_date >= today. OVERDUE KPI: stale referrals (14 days, not
scheduled) + missed appointments (date passed, no outcome). isOverdue() updated
to match. Per-session rows: MRI referrals expand into one list row per pending
session; each row shows date + body parts in cyan chips.

### Provider Session Email

actions.ts scheduleAppointment() — provider session email added after patient
email block. Fires fire-and-forget on every session save. Fetches assigned
provider from referrals.referral_provider_id. Email includes patient name,
date, time, location, confirmation #, body parts for that session.
Subject: "Session Scheduled — {type} — {patient name}".

### UPCOMING and OVERDUE KPI Redesign

UPCOMING: now counts individual appointment rows (scheduled_date >= today)
rather than referral records in scheduled status. Reflects actual calendar load.

OVERDUE: two conditions summed — (1) open referral not updated in 14 days
(excluding scheduled/patient_confirmed status), (2) appointment date passed
with no outcome recorded (missed appointment). isOverdue() client-side updated
to match both conditions.

### Per-Session Rows in Referral Dashboard

listReferrals() expands MRI referrals with pending appointments into multiple
ReferralSummary rows — one per session. Each row carries _session_appointment
{scheduled_date, scheduled_time, body_parts, outcome}. Dashboard patient cell
renders date + cyan body part chips for session rows. Non-MRI and unscheduled
MRI referrals return as single rows unchanged.

Completed/no-show/rescheduled appointments filtered out of session display
(outcome != null excluded). Clicking any session row opens the full referral
sheet for that referral_id.

### Migration 030 — appointment_id on referral_documents

ALTER TABLE referral_documents ADD COLUMN appointment_id uuid
REFERENCES referral_appointments(id);
CREATE INDEX idx_ref_docs_appointment_id ON referral_documents(appointment_id);

Deployed. No code changes yet. Session 32 picks up with per-session upload
button on session cards, auto-close session on upload, referral auto-advance
chain to needs_review, MD chart result viewing.

## 2026-07-09 — Session 30

### Priority Queue — Full Resolution

All actionable items from the Session 29 priority queue resolved or
formally deferred this session.

### patient_forms visit_id backfill — CLOSED

Investigation: all 30 null-visit_id rows were dev-seeded ghost records
with both visit_id and filename null. No real PDF existed. No real patient
data affected. Billing ZIP correctly excluded them. Resolved:
DELETE FROM patient_forms WHERE visit_id IS NULL AND filename IS NULL;

### CPT codes provider_type — CLOSED

All 34 CPT codes bulk-updated: MD → General in database.
VisitTab.tsx filter updated to show codes where
provider_type === effectiveLicenseType || provider_type === 'General'.
PA and NP users now see full 34-code set (previously empty picker).
Product decision: single General code set correct for this practice.
DC/PT/etc. are referral recipients, not visit coders in Cosmos.

### ReferralProviderRow type cleanup — CLOSED

app/referrals/types.ts fully corrected. All seven interface field names
updated to match live schema: ReferralProviderRow (street/city/state/zip),
ReferralRow (referral_provider_id, created_by_user_id), ReferralAppointmentRow
(location_name), ReferralDocumentRow (uploaded_by_user_id, created_at),
ReferralStatusHistoryRow (changed_by_user_id, created_at), ReferralTimelineRow
(actor_user_id, created_at), ReferralNoteRow (author_user_id).

### Migration 027 — patients.email

ALTER TABLE patients ADD COLUMN email text;
Optional nullable field. FD enters at registration or via edit. If absent,
FD calls patient manually. Future: SMS via Twilio when ready.

### PatientForm.tsx — Email field

Email field added to Personal Information section after Phone. Optional,
type="email", inputMode="email". State initialized from patient?.email in
edit mode. Writes to patients.email on save (both INSERT and UPDATE paths).

### PatientProfile.tsx — Email display

Email conditionally shown in patient info grid when has(patient, 'email')
is true. Uses spread pattern into the grid array.

### actions.ts — sendEmail() Resend helper

Fire-and-forget email helper. Uses RESEND_API_KEY env var (added to Vercel
Production environment variables, separate from Render). Sends via Resend
from admin@cosmosmt.com. Logs every attempt to referral_notifications
(delivery_status: sent/failed, sent_at). Uses two-arg .then(onFulfilled,
onRejected) — Supabase insert returns PromiseLike<void>; .catch() not
available.

### actions.ts — Patient appointment confirmation email

scheduleAppointment() — after successful insert, fetches patient.email.
If present, sends appointment confirmation: subject "Appointment
Confirmation — {type}", body includes patient name, referral type, date
(long format), time, location, confirmation number. Confirmed working in
production.

### actions.ts — Provider assignment notification email

assignProvider() — after successful provider assignment, fetches
referral_providers.email. If present, sends referral notification: subject
"New {type} Referral — {patient name}", body includes patient name,
referral type, urgency, clinical reason. For MRI/Rx/DME types: fetches
most recent patient_forms row, downloads PDF from patient-forms storage
bucket, attaches as base64. Confirmed working in production (email received,
PDF attached).

### RESEND_API_KEY — Vercel env var added

RESEND_API_KEY added to Vercel Production + Preview environment variables.
Required for actions.ts sendEmail(). Previously only set on Render for
cosmos-api attorney email feature.

### Superadmin dashboard — CLOSED (already built)

Confirmed: superadmin login lands on role-selector screen with 👑 SUPER
ADMIN badge and four dashboard tiles. No separate /superadmin route needed.
Audit log records all logins. Priority closed.

### DEV artifacts — deferred to go-live

DEV fill-all PCE button (VisitTab.tsx) and Dev Tools card (Admin) retained
during testing. Remove together at go-live.

### Doctor mailing addresses — deferred to pre-production

All current doctor records are test data. Real addresses entered at go-live.

### SMS notifications — deferred

Twilio integration deferred. Email primary channel. sendSMS() will slot
alongside sendEmail() in actions.ts when Twilio account ready.

### Provider portal — deferred to Phase 2

Token-gated provider referral view page (public route with signed URL).
MRI/Rx/DME providers receive PDF via email attachment in the interim.

## 2026-07-09 — Session 29

### AI_STYLE_GUIDE.md — shadcn Exception Scope Corrected

§2 updated: exception scope was listed as "Biller dashboard only" — corrected
to five approved surfaces: Biller (/billing), Admin (/admin), MD V2 (/md-v2),
MDClient (/md), Referral dashboard (/referrals). Matches SYSTEM_PROMPT.md §9
and ARCHITECTURE.md §1.

### Provider Assignment — Appointment Tab

app/referrals/ReferralSheet.tsx — Assigned Provider card added to Appointment tab.

Dark custom ProviderDropdown component (useRef outside-click dismiss, Oxanium
font, #0d1821 background). Providers loaded from referral_providers on mount.
Filtered by referral category → specialty mapping (CATEGORY_SPECIALTIES dict).
Show all toggle bypasses filter. Selection calls assignProvider() Server Action
immediately with optimistic update + revert on error. Assigned provider's
specialty, address, phone shown below dropdown. Schedule form Location
pre-fills from assigned provider address when opened empty.

### assignProvider() Server Action

app/referrals/actions.ts — new assignProvider(referralId, providerId | null).

Writes referral_provider_id (confirmed column name — not provider_id). Fetches
provider address and returns providerAddress for Location pre-fill. Inserts
provider_assigned timeline event. Returns { ok, providerAddress } or { error }.

### Column Audit — actions.ts

referral_providers: no address composite column — real columns are street, city,
state, zip. referrals FK is referral_provider_id not provider_id. referral_timeline:
no occurred_at — uses auto-set created_at. referral_documents: no uploaded_at —
uses auto-set created_at. All actions.ts inserts corrected accordingly.
getReferralProviders() return type changed to any[] (ReferralProviderRow stale).

### Document Upload — Documents Tab

app/referrals/ReferralSheet.tsx — Documents tab upload UI added.

Upload card with DarkDropdown doc type selector (Result / Authorization /
Referral Form / Other), hidden file input, file name + size preview, Upload
button. Accepted: PDF, JPEG, PNG, TIFF. 25MB limit enforced client-side.
Storage path: {patientId}/{referralId}/{timestamp}_{filename} in
referral-documents bucket. On success: calls uploadReferralResult() Server
Action → inserts referral_documents row + document_uploaded timeline event.
Document list refreshes on upload. View button generates 15-min signed URL.

### referral-documents Storage Bucket

New Supabase Storage bucket: referral-documents, private, 25MB file limit,
PDF/JPEG/PNG/TIFF. Created via SQL INSERT INTO storage.buckets. Three RLS
policies (INSERT/SELECT/UPDATE) for authenticated role.

### Timeline — Fixed End-to-End

referral_timeline query in ReferralSheet.tsx now orders by created_at (was
occurred_at — column does not exist). Timestamp display uses e.created_at.
All timeline inserts no longer pass occurred_at. Timeline now records: referral
created, status changed, provider assigned, appointment scheduled, document
uploaded. Confirmed working in production.

### Dark Dropdowns — ReferralSheet

All native <select> elements in ReferralSheet.tsx replaced with custom dark
dropdowns: ProviderDropdown (provider assignment) and DarkDropdown (Record
Outcome). Eliminates Android OS light-theme native picker.

### Overdue Row Flagging — ReferralDashboard

app/referrals/ReferralDashboard.tsx — isOverdue() helper added.

Definition: status not terminal/completed AND updated_at older than 14 days.
Patient cell gets ⚠ OVERDUE dark red badge (#7f1d1d bg, #fca5a5 text). Table
row gets subtle dark red background tint (#7f1d1d18). Overdue metric card
filter now uses isOverdue() — previously used past appointment date (wrong
definition). Now matches KPI count exactly.

### Admin Sidebar — Referrals Link Removed

app/admin/page.tsx — Referrals → nav link added then removed. Decision:
Admin dashboard is configuration-only. Operational dashboards belong to
Superadmin role-switching.
## 2026-07-09 — Session 30

### Priority Queue — Full Resolution

All actionable items from the Session 29 priority queue resolved or
formally deferred this session.

### patient_forms visit_id backfill — CLOSED

Investigation: all 30 null-visit_id rows were dev-seeded ghost records
with both visit_id and filename null. No real PDF existed. No real patient
data affected. Billing ZIP correctly excluded them. Resolved:
DELETE FROM patient_forms WHERE visit_id IS NULL AND filename IS NULL;

### CPT codes provider_type — CLOSED

All 34 CPT codes bulk-updated: MD → General in database.
VisitTab.tsx filter updated to show codes where
provider_type === effectiveLicenseType || provider_type === 'General'.
PA and NP users now see full 34-code set (previously empty picker).
Product decision: single General code set correct for this practice.
DC/PT/etc. are referral recipients, not visit coders in Cosmos.

### ReferralProviderRow type cleanup — CLOSED

app/referrals/types.ts fully corrected. All seven interface field names
updated to match live schema: ReferralProviderRow (street/city/state/zip),
ReferralRow (referral_provider_id, created_by_user_id), ReferralAppointmentRow
(location_name), ReferralDocumentRow (uploaded_by_user_id, created_at),
ReferralStatusHistoryRow (changed_by_user_id, created_at), ReferralTimelineRow
(actor_user_id, created_at), ReferralNoteRow (author_user_id).

### Migration 027 — patients.email

ALTER TABLE patients ADD COLUMN email text;
Optional nullable field. FD enters at registration or via edit. If absent,
FD calls patient manually. Future: SMS via Twilio when ready.

### PatientForm.tsx — Email field

Email field added to Personal Information section after Phone. Optional,
type="email", inputMode="email". State initialized from patient?.email in
edit mode. Writes to patients.email on save (both INSERT and UPDATE paths).

### PatientProfile.tsx — Email display

Email conditionally shown in patient info grid when has(patient, 'email')
is true. Uses spread pattern into the grid array.

### actions.ts — sendEmail() Resend helper

Fire-and-forget email helper. Uses RESEND_API_KEY env var (added to Vercel
Production environment variables, separate from Render). Sends via Resend
from admin@cosmosmt.com. Logs every attempt to referral_notifications
(delivery_status: sent/failed, sent_at). Uses two-arg .then(onFulfilled,
onRejected) — Supabase insert returns PromiseLike<void>; .catch() not
available.

### actions.ts — Patient appointment confirmation email

scheduleAppointment() — after successful insert, fetches patient.email.
If present, sends appointment confirmation: subject "Appointment
Confirmation — {type}", body includes patient name, referral type, date
(long format), time, location, confirmation number. Confirmed working in
production.

### actions.ts — Provider assignment notification email

assignProvider() — after successful provider assignment, fetches
referral_providers.email. If present, sends referral notification: subject
"New {type} Referral — {patient name}", body includes patient name,
referral type, urgency, clinical reason. For MRI/Rx/DME types: fetches
most recent patient_forms row, downloads PDF from patient-forms storage
bucket, attaches as base64. Confirmed working in production (email received,
PDF attached).

### RESEND_API_KEY — Vercel env var added

RESEND_API_KEY added to Vercel Production + Preview environment variables.
Required for actions.ts sendEmail(). Previously only set on Render for
cosmos-api attorney email feature.

### Superadmin dashboard — CLOSED (already built)

Confirmed: superadmin login lands on role-selector screen with 👑 SUPER
ADMIN badge and four dashboard tiles. No separate /superadmin route needed.
Audit log records all logins. Priority closed.

### DEV artifacts — deferred to go-live

DEV fill-all PCE button (VisitTab.tsx) and Dev Tools card (Admin) retained
during testing. Remove together at go-live.

### Doctor mailing addresses — deferred to pre-production

All current doctor records are test data. Real addresses entered at go-live.

### SMS notifications — deferred

Twilio integration deferred. Email primary channel. sendSMS() will slot
alongside sendEmail() in actions.ts when Twilio account ready.

### Provider portal — deferred to Phase 2

Token-gated provider referral view page (public route with signed URL).
MRI/Rx/DME providers receive PDF via email attachment in the interim.

## 2026-07-09 — Session 29

### AI_STYLE_GUIDE.md — shadcn Exception Scope Corrected

§2 updated: exception scope was listed as "Biller dashboard only" — corrected
to five approved surfaces: Biller (/billing), Admin (/admin), MD V2 (/md-v2),
MDClient (/md), Referral dashboard (/referrals). Matches SYSTEM_PROMPT.md §9
and ARCHITECTURE.md §1.

### Provider Assignment — Appointment Tab

app/referrals/ReferralSheet.tsx — Assigned Provider card added to Appointment tab.

Dark custom ProviderDropdown component (useRef outside-click dismiss, Oxanium
font, #0d1821 background). Providers loaded from referral_providers on mount.
Filtered by referral category → specialty mapping (CATEGORY_SPECIALTIES dict).
Show all toggle bypasses filter. Selection calls assignProvider() Server Action
immediately with optimistic update + revert on error. Assigned provider's
specialty, address, phone shown below dropdown. Schedule form Location
pre-fills from assigned provider address when opened empty.

### assignProvider() Server Action

app/referrals/actions.ts — new assignProvider(referralId, providerId | null).

Writes referral_provider_id (confirmed column name — not provider_id). Fetches
provider address and returns providerAddress for Location pre-fill. Inserts
provider_assigned timeline event. Returns { ok, providerAddress } or { error }.

### Column Audit — actions.ts

referral_providers: no address composite column — real columns are street, city,
state, zip. referrals FK is referral_provider_id not provider_id. referral_timeline:
no occurred_at — uses auto-set created_at. referral_documents: no uploaded_at —
uses auto-set created_at. All actions.ts inserts corrected accordingly.
getReferralProviders() return type changed to any[] (ReferralProviderRow stale).

### Document Upload — Documents Tab

app/referrals/ReferralSheet.tsx — Documents tab upload UI added.

Upload card with DarkDropdown doc type selector (Result / Authorization /
Referral Form / Other), hidden file input, file name + size preview, Upload
button. Accepted: PDF, JPEG, PNG, TIFF. 25MB limit enforced client-side.
Storage path: {patientId}/{referralId}/{timestamp}_{filename} in
referral-documents bucket. On success: calls uploadReferralResult() Server
Action → inserts referral_documents row + document_uploaded timeline event.
Document list refreshes on upload. View button generates 15-min signed URL.

### referral-documents Storage Bucket

New Supabase Storage bucket: referral-documents, private, 25MB file limit,
PDF/JPEG/PNG/TIFF. Created via SQL INSERT INTO storage.buckets. Three RLS
policies (INSERT/SELECT/UPDATE) for authenticated role.

### Timeline — Fixed End-to-End

referral_timeline query in ReferralSheet.tsx now orders by created_at (was
occurred_at — column does not exist). Timestamp display uses e.created_at.
All timeline inserts no longer pass occurred_at. Timeline now records: referral
created, status changed, provider assigned, appointment scheduled, document
uploaded. Confirmed working in production.

### Dark Dropdowns — ReferralSheet

All native <select> elements in ReferralSheet.tsx replaced with custom dark
dropdowns: ProviderDropdown (provider assignment) and DarkDropdown (Record
Outcome). Eliminates Android OS light-theme native picker.

### Overdue Row Flagging — ReferralDashboard

app/referrals/ReferralDashboard.tsx — isOverdue() helper added.

Definition: status not terminal/completed AND updated_at older than 14 days.
Patient cell gets ⚠ OVERDUE dark red badge (#7f1d1d bg, #fca5a5 text). Table
row gets subtle dark red background tint (#7f1d1d18). Overdue metric card
filter now uses isOverdue() — previously used past appointment date (wrong
definition). Now matches KPI count exactly.

### Admin Sidebar — Referrals Link Removed

app/admin/page.tsx — Referrals → nav link added then removed. Decision:
Admin dashboard is configuration-only. Operational dashboards belong to
Superadmin role-switching (not yet built). Admin has no operational reason
to view the referral workflow.

### Superadmin Dashboard — Scoped for Future

Superadmin dashboard fully scoped: identity/access controls, role-switching/
impersonation (read-only), cross-role KPI executive summary, full audit log,
system health. Not built this session — documented in HANDOVER.md Open Items.
## 2026-07-09 — Session 28

### Referral Dashboard — Full FD Scheduling Workflow

app/referrals/ReferralSheet.tsx — Appointment tab rebuilt from read-only
to fully functional three-state workflow:

Schedule form — shown when no current appointment exists or Reschedule
tapped. Fields: Date (required), Time, Location, Confirmation #. Calls
scheduleAppointment() Server Action on submit.

Current appointment card — shows date/time/location/conf# with three action
buttons: ✓ Patient Confirmed, Record Outcome, 🔄 Reschedule. Patient
Confirmed writes patient_confirmed + patient_confirmed_at directly via
Supabase client; auto-advances referral status to patient_confirmed if
currently scheduled. Record Outcome shows inline dropdown (Completed / No
Show / Rescheduled) + optional notes; updates referral_appointments.outcome
and advances referral status to match.

Prior appointments — read-only history cards below current card.

### Referral Actions — Service Key Rewrite + Column Name Corrections

app/referrals/actions.ts — full rewrite:

All DB operations now use supabaseServer (service key). Previously used
createServerClient with anon key + session cookie — caused silent RLS
failures for reads and unhandled Server Action errors for writes.

getActorId() replaces getClient() — resolves session user ID for attribution
only; failure falls back to null rather than throwing. All DB writes use
supabaseServer regardless of session state.

All write actions now return { error: string } instead of throwing —
callers check result.error and call toastError() directly. No unhandled
Server Action exceptions reaching the Next.js error boundary.

listReferrals() now joins patients for first_name/last_name, returning
patient_name on each summary row.

Column name corrections (confirmed against information_schema.columns):
- referrals: created_by_user_id (was created_by)
- referral_status_history: changed_by_user_id (was changed_by)
- referral_timeline: actor_user_id (was actor_id)
- referral_notes: author_user_id (was created_by)
- referral_documents: uploaded_by_user_id (was uploaded_by)
- referral_appointments: location_name (was location)

### Schema — Attribution Columns Made Nullable

Five attribution columns dropped NOT NULL constraint:
ALTER TABLE referrals ALTER COLUMN created_by_user_id DROP NOT NULL;
ALTER TABLE referral_status_history ALTER COLUMN changed_by_user_id DROP NOT NULL;
ALTER TABLE referral_appointments ALTER COLUMN created_by_user_id DROP NOT NULL;
ALTER TABLE referral_notes ALTER COLUMN author_user_id DROP NOT NULL;
ALTER TABLE referral_documents ALTER COLUMN uploaded_by_user_id DROP NOT NULL;

### Referral Dashboard — Patient Name Column + Dark Dropdowns + Metrics Refresh

app/referrals/ReferralDashboard.tsx — rebuilt:

Table recolumned to 4 mobile-first columns: Patient (name + type + urgency
badge), Status, Appt, Date. Patient name visible without horizontal scroll.

All three <select> filter dropdowns replaced with DarkSelect — custom dark
pill dropdown with useRef outside-click dismiss. Eliminates OS light-theme
native picker on Android Chrome.

Refresh button now calls getReferralMetrics() + listReferrals() in parallel —
metric cards (Total/Open/Pending/Upcoming/etc.) update on refresh, not just
the table.

resolvedRole derived from sessionStorage.getItem('cosmos_license_type') in
useEffect — overrides userRole="md" prop from page.tsx for accurate
role-aware UI.

### Auth — cosmos_license_type Written for All Roles

app/page.tsx line 118 (else branch covering FD/billing/admin/superadmin):
sessionStorage.setItem('cosmos_license_type', prof.role) now added before
cosmos_login_marker write. Previously only MD/PA/NP wrote this value (from
doctors.license_type). FD users now correctly resolve as 'frontdesk'.

### FD Dashboard — Referrals Nav Button

app/dashboard/DashboardClient.tsx — 🔗 Referrals button added to Patients
tab action row. Routes to /referrals via window.location.href.

### Lifecycle Simplification

types.ts VALID_TRANSITIONS simplified:
- new: ['cancelled'] — FD schedules directly via Appointment tab
- scheduling and auth_required preserved in DB but removed from Move To UI
  on new status (business model has no insurance pre-authorization step)

scheduleAppointment() in actions.ts bypasses VALID_TRANSITIONS for direct
status update — writes status = 'scheduled' + inserts status history row
directly via supabaseServer without calling updateReferralStatus.

### CosmosUI — Toast System Fixed

app/components/ui/CosmosUI.tsx — full rewrite:

toastSuccess() now wires to _addToast — auto-dismiss green toast (3.5s,
✓ icon). Previously incorrectly routed to AlertModal (blocking red modal).
toastError() correctly routes to AlertModal (blocking red modal, OK required).
ToastContainer renders bottom-anchored stack of auto-dismiss toasts.
Toast types: success (green #2ee08a), info (cyan #00cfff), error (red #f87171).
AlertModal border/text changed to red (#e74c3c) — was cyan.

### Dev Generator — Referral Seeding + FK Fix

app/api/wipe-patients/route.ts — referral subtree deleted before
patient_visits to satisfy referrals_visit_id_fkey. Correct order:
referral_notifications → referral_timeline → referral_status_history →
referral_notes → referral_documents → referral_appointments →
referrals → visit_line_items → patient_visits → patient_forms → appointments → patients

app/api/seed-referrals/route.ts — new POST endpoint. Accepts
{ patient_id, visit_id, referral_type_code, clinical_reason }.
Uses supabaseServer to insert referrals + referral_status_history +
referral_timeline rows. Called by dev generator after each successful PDF.
ICD-10 excluded (not a referral type).

app/dev/page.tsx — referral seeding integrated. After each successful PDF
call, fetches /api/seed-referrals with referral_type_code from map.
Results log compacted: all referral results per visit on one line
(MRI ✓ · PT ✓). Intermediate per-referral lines removed.

### Provider Directory — Admin CRUD

app/admin/components/ReferralProvidersSection.tsx — new component. Full
CRUD for referral_providers table: add, edit, deactivate/activate.
Fields: Name, Facility Name, Specialty (dropdown), Phone, Fax, Email,
Street, City, State, ZIP, NPI, Avg Turnaround Days, Preferred Contact,
Notes, Active toggle. Search bar. Active Only / Show All toggle.
Deactivate/Activate with confirm modal.

app/admin/page.tsx — 🔗 Ref. Providers tab added to sidebar nav and
render block.

10 providers seeded via Supabase SQL (one per specialty): Physical Therapy,
MRI/Radiology, Orthopedic, Pain Management, Neurology, VNG/Vestibular,
Chiropractic, ANS Autonomic, DME/Equipment, Pharmacy. All providers:
email = 'referralsout@outlook.com', city = NY metro area.

## 2026-07-08 — Session 26

### Referral Management Module — Phase 1 Route Deployment

Five /referrals route files written to repo and deployed via split heredoc
method (designed Session 25, not yet on disk):

app/referrals/types.ts (293 lines) — ReferralStatus type, ALL_STATUSES,
TERMINAL_STATUSES, REFERRAL_STATUS_META (15 statuses, badge colors/icons),
VALID_TRANSITIONS, ReferralUrgency, URGENCY_META, UserRole, ROLE_PERMISSIONS,
CATEGORY_COLOR, categoryColor(), all DB row interfaces, ReferralSummary,
ReferralDetail, ReferralMetrics, form input types, ReferralFilters.

app/referrals/actions.ts (314 lines) — Server Actions: createReferral,
updateReferralStatus (validates VALID_TRANSITIONS), scheduleAppointment
(auto-advances to scheduled), uploadReferralResult (auto-chains to
needs_review), addReferralNote, getReferralMetrics (8 KPIs parallel),
listReferrals (filters + PostgREST join shape), getReferralTypes,
getReferralProviders. Uses createServerClient with async cookie wrapper.

app/referrals/page.tsx — server-side auth removed (middleware handles it);
parallel fetch; userRole hardcoded 'md' pending role-aware pattern.

app/referrals/ReferralDashboard.tsx (356 lines) — 8 metric cards (clickable
filter), TanStack Table (sort/pagination), filter bar, Sheet trigger, Refresh.

app/referrals/ReferralSheet.tsx (303 lines) — 5-tab detail panel (Overview,
Appointment, Documents, Notes, Timeline) + status action buttons per
VALID_TRANSITIONS + note entry with live Supabase fetch.

TSC errors resolved:
- createServerComponentClient → createServerClient
- Next.js 15 async cookies: await cookies() + get/set/remove wrapper
- async getClient() + await at all call sites

Confirmed working: dashboard renders, metric cards clickable, table sortable,
Sheet opens on row tap, Notes tab functional.

Commit b97e812..ed56af5 — Vercel Ready in 38s.

### MD Dashboard — Referrals Nav Button

app/md/MDClient.tsx — 🔗 Referrals button added to header alongside Schedule
and Sign Out. router.push('/referrals'). Always visible (not gated on doctorId).
Restored from git checkout HEAD after multiple patch corruptions before final
clean Python patch applied.

Lesson: git checkout HEAD -- <file> before patching a file with 3+ prior
patches. Never patch a corrupted working-tree file.

### Referral Dual-Write Bridge — PT, Ortho, Pain Mgmt, VNG, ANS

Five referral screens patched via ~/patch_dualwrite.py (deleted post-commit).
Each file receives createLifecycleRecord(filename) — fire-and-forget after
PDF success. Writes referrals + referral_status_history + referral_timeline +
referral_notifications rows. ✓ TRACKED badge in header on success.

Files patched:
- app/md/[patientId]/pt/PtReferral.tsx (code: PT)
- app/md/[patientId]/ortho/OrthoReferral.tsx (code: ORTHO)
- app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx (code: PAIN-MGMT)
- app/md/[patientId]/vng/VngReferral.tsx (code: VNG)
- app/md/[patientId]/ans/AnsReferral.tsx (code: ANS)

RX and DME deferred — referral_types has no RX or DME code rows. Seed SQL
recorded in HANDOVER.md Open Items #11.

Confirmed working: Pain Management, VNG, Orthopedic, ANS all appear in MD V2
Referrals tab with New status and correct category colors after generation.

referral_types.code confirmed present. All bridges use .eq('code', ...) lookup.
Codes: MRI, CT, MRA, ULTRASOUND, PT, ORTHO, PAIN-MGMT, EMG, VNG, ANS.

Lesson: Python os.path in Termux uses /data/data/com.termux/files/home/ not /root/.
Lesson: createServerClient cookie wrapper required — await cookies() returns
Promise<ReadonlyRequestCookies> in Next.js 15; wrap with get/set/remove methods.
Lesson: Vercel preview URL domain isolation — cookies scoped per domain; always
test on cosmos-dashboard-nu.vercel.app aliased domain.
## 2026-07-07 — Session 25

### Referral Management Module — Phase 1: Foundation

New route /referrals — dedicated referral management dashboard.
shadcn/ui approved as fifth scoped exception (same CSS-variable bridge
as Biller and Admin dashboards).

Migration 026 — 9 new tables run in Supabase SQL editor (3 blocks):
- referral_providers (external specialists — distinct from doctors table)
- referral_types (seeded: MRI, CT, MRA, Ultrasound, PT, Ortho, Pain Mgmt,
  EMG, VNG, ANS; legacy_form_tag bridge column for patient_forms migration)
- referrals (core lifecycle entity; 15-status engine with CHECK constraint)
- referral_appointments (is_current flag preserves reschedule history)
- referral_documents (soft-delete only; doc_type CHECK constraint)
- referral_status_history (immutable — no DELETE policy)
- referral_timeline (immutable append-only event log)
- referral_notes (soft-delete; is_internal flag)
- referral_notifications (delivery stub; queued status; wires to SendGrid)
All tables: RLS enabled, authenticated role only, updated_at triggers
on providers/referrals/appointments/notes.

New files (designed; not yet written to repo as live route — Phase 3):
- app/referrals/types.ts — 15 statuses + badge metadata + transition map
  + urgency metadata + role permission matrix + all DB/query/input types
- app/referrals/actions.ts — Server Actions: createReferral,
  updateReferralStatus (validates transition map), scheduleAppointment,
  uploadReferralResult (auto-chains to needs_review), addReferralNote,
  getReferralMetrics (8 KPIs parallel), listReferrals, getReferralTypes,
  getReferralProviders
- app/referrals/page.tsx — server component; auth gate; parallel data fetch
- app/referrals/ReferralDashboard.tsx — 8 metric cards (clickable filter),
  TanStack table (sort/filter/search/pagination), filter bar, Sheet trigger
- app/referrals/ReferralSheet.tsx — 7-tab detail panel + status actions

### Referral Management Module — Phase 2: MRI Dual-Write Bridge + V2 Tab

app/md/[patientId]/mri/MriReferral.tsx — dual-write bridge added.
createLifecycleRecord() fires after PDF success (fire-and-forget, non-blocking).
Modality derived from selected keys: ct.* → CT, mri.mra.* → MRA, else MRI.
Writes referrals + referral_status_history + referral_timeline +
referral_notifications rows. Failure console-logged only — never shown to MD,
never rolls back PDF. TRACKED badge in header on success.

app/md-v2/[patientId]/ReferralsTabV2.tsx — new component. Queries referrals
table for patient. Status cards with badges, overdue highlighting, appointment
dates, provider. Filter pills: All / Open / Closed. Full Dashboard link.
REFERRAL_STATUS_META and URGENCY_META inlined (not imported) to avoid TSC
failure before /referrals route files are deployed to repo.

app/md-v2/[patientId]/PatientChartV2.tsx — Referrals tab added as fourth
tab. Tab font reduced 12px to 10px for mobile fit.

Commit df0341e..c2428f8 — deployed Vercel production in 41s.

TSC error encountered and resolved: ReferralsTabV2 initially imported from
@/app/referrals/types (not yet in repo). Fixed via sed + Python patch to
inline constants. Lesson recorded in HANDOVER.md Lessons Learned.

Supabase SQL editor RLS prompt: chose Run without RLS for all 3 blocks
since migration SQL includes explicit ENABLE ROW LEVEL SECURITY + CREATE
POLICY statements. Lesson recorded in HANDOVER.md Lessons Learned.

## 2026-07-07 — Session 24

### Re-login hang — fully resolved

Root cause: setLoading(false) was never called on the success path of
handleLogin. All 8 login steps completed (confirmed via on-screen debug log),
but loading state was never cleared. On second login the component remained
mounted with loading=true, causing "Signing in…" to hang indefinitely even
though authentication succeeded.

Fixes applied to app/page.tsx (clean rewrite):

- setLoading(false) added before setStage/setReady in all handlePostLogin
  branches: superadmin, md/pa/np with location picker, other roles.

- cosmos_login_marker sessionStorage guard in useEffect: only restores a
  prior session if marker === '1'. Prevents stale Supabase auth tokens from
  a prior user auto-navigating on page load.

- Direct localStorage.removeItem('sb-ttudxnzmybcwrtqlbtta-auth-token')
  before signIn: clears stale session token synchronously without racing
  the Supabase singleton client's async signOut() state machine.

- All Sign Out buttons (superadmin picker, location picker, MFA setup,
  MFA challenge): sessionStorage.clear() + setLoading(false) + setError('')
  for full state reset.

- autoComplete="email" on email field, autoComplete="current-password" on
  PIN field: restores browser saved credential support.

- Debug instrumentation (debugLog state, dlog(), on-screen cyan log panel)
  added during diagnosis and fully removed in final clean rewrite.

### Patch script cleanup

rm ~/fix_*.py ~/patch_*.py ~/rewrite_*.py — confirmed clean.

## 2026-07-07 -- Session 23

### PC NPI full-stack implementation

Migration 025: ALTER TABLE doctors ADD COLUMN IF NOT EXISTS pc_npi text

cosmos-api/database.py complete rewrite with _resolve_billing_npi resolver:
- Supervised provider uses supervisor pc_npi
- PC corp provider uses own pc_npi
- Sole proprietor uses own individual npi

All 11 forms/*.py patched: doctor_npi replaced with billing_npi.
nf3.py internal resolver block removed (moved to database.py).

DoctorsSection.tsx: pc_npi field in Billing tab (hidden for sole proprietors).
Card display: PC corp shows PC NPI, sole prop shows NPI, supervised shows Lic.
shared.tsx: pc_npi added to BLANK_DOCTOR.

### Dev generator attorney_email fix

app/dev/page.tsx: lawyers select includes email; patient insert includes
attorney_email populated from atty.email.

### MD V2 dashboard (new primary MD patient chart)

New route /md-v2/[patientId] using shadcn components.
V2 is now the primary MD patient chart.
/md/[patientId] remains the clinical visit entry point via Start Visit button.

New files:
- app/md-v2/[patientId]/page.tsx
- app/md-v2/[patientId]/PatientChartV2.tsx (Pat Profile / History / New Visit tabs)
- app/md-v2/[patientId]/InfoTabV2.tsx (shadcn patient profile)
- app/md-v2/[patientId]/HistoryTabV2.tsx (shadcn history)
- app/md-v2/page.tsx (redirect to /md)

Pat Profile: one-line cyan header (PTID DOB DOA Carrier) + claim/pol line;
collapsible Attorney card; pain scores grid; visit summary.
History: shadcn Card per visit, bottom drawer, PCE generation.
New Visit: Start Visit button to /md/{patientId}.

MDClient.tsx: full shadcn rewrite; cards route to /md-v2/; colored left border.

### Login page improvements

app/page.tsx: shadcn Card role selector with descriptions; cyan location picker;
autoComplete off on login fields; sessionStorage.clear on all Sign Out buttons.
Pre-login signOut removed from handleLogin (was causing hang).

DashboardClient.tsx MDClient.tsx BillerDashboard.tsx: sessionStorage.clear added.

Open bug: re-login hang when switching users not fully resolved.

### TurboSMTP account closure

Account closed by TurboSMTP (spam detection). /send-billing-packet broken.
SendGrid setup required before go-live.

## 2026-07-06 — Session 22

### Backend billing packet ZIP — complete

Replaced client-side JSZip with server-side `/generate-zip` endpoint on
`cosmos-api`. Backend fetches all storage files directly using the
Supabase service key, zips in memory with Python `zipfile`, returns
binary `Response`.

**`cosmos-api/main.py`:** `/generate-zip` endpoint appended. `ZipRequest`
model (`patient_id`, `visit_id`). Zip filename fixed to
`{patient_id}_{doa}_{dos}_billing_packet.zip`.

**`PatientProfile.tsx`:** `handleDownloadZip` rewritten to call backend
endpoint; JSZip CDN loader block removed; `fmtDateForFilename` helper
removed.

**Why backend:** Server is on same network as Supabase Storage — no
signed URL round-trips, no browser memory constraint, no CDN dependency,
works reliably on low-end mobile.

---

### Email billing packet to attorney — complete

New `/send-billing-packet` endpoint generates one ZIP per selected visit
and emails it to the patient's attorney via TurboSMTP. Confirmed
delivered end-to-end.

**New file — `cosmos-api/send_billing_endpoint.py`:** Endpoint extracted
to separate file to avoid heredoc string literal corruption in Termux.
Wired into `main.py` via `register(app, get_db, verify_jwt, Depends, ...)`.

**`cosmos-api/main.py`:** Imports and registers `send_billing_endpoint`.

**`PatientProfile.tsx`:**
- `selectedVisits: Set<string>` state + `sendingEmail` state
- `toggleVisitSelect(visitId)` — toggles visit in/out of selection set
- `handleEmailAttorney()` — calls `/send-billing-packet` with selected visit IDs
- Checkboxes appear on complete visit rows (left side)
- "📧 Email X Billing Packet(s) to Attorney" button appears below list when any visits selected; disappears after successful send

**`PatientForm.tsx`:**
- `attorney_email` field added to Attorney section (after Attorney Phone)
- `attorney_email` added to form state (initialized from `patient?.attorney_email`)
- `handleLawyerChange` now auto-fills `attorney_email` from `lawyers.email`
- `Lawyer` interface updated: `email?: string`

**Migration 024:** `ALTER TABLE patients ADD COLUMN IF NOT EXISTS attorney_email text` — run in Supabase SQL editor; no on-disk file.

**Render env vars added:** `TURBOSMTP_HOST`, `TURBOSMTP_PORT`, `TURBOSMTP_USER` (Consumer Key), `TURBOSMTP_PASS` (Consumer Secret), `TURBOSMTP_FROM`.

**Email provider:** TurboSMTP via `smtplib` (Python stdlib — no new
dependency in `requirements.txt`). Dev/testing only — switch to
SendGrid with HIPAA BAA before go-live.

**Confirmed delivered:** TurboSMTP Analytics shows `Delivered` to
`kompaniaadvokat@gmail.com` at 2026-07-06 21:59:56.

---

## 2026-07-06 — Session 21 (continued)

### Billing packet ZIP download — complete

`app/patients/[patientId]/PatientProfile.tsx`: 📦 zip icon added to each
Recent Visits row. Appears only when the visit has a complete billing
packet (same four-condition gate as Submit to Billing: billing finalized +
PCE generated + NF-3 preflight passed + AOB on file).

**Zip contents:**
- All `patient_forms` rows for that `visit_id` (dynamic — future document
  types included automatically, no code change required, provided they
  store their PDF as a `patient_forms` row with `visit_id` set)
- `patients.nf2_url` (patient-level, included in every visit zip)
- `patients.aob_url` (patient-level, included in every visit zip)

**Zip filename:** `{patient_id}_{doa}_{dos}.zip` — same date convention
as PDF filenames (`YYYYMMDD`).

**Implementation notes:**
- JSZip loaded from CDN (`cdnjs.cloudflare.com`) inline on first render —
  no npm dependency added
- All PDFs fetched in parallel via `Promise.all` with signed URLs (300s TTL)
- Individual file fetch failures are silently skipped — zip proceeds with
  whatever files successfully download rather than aborting entirely
- `zippingVisit` state tracks which visit is being zipped; button shows
  ⏳ during generation, 📦 when idle
- `isVisitComplete(v)` helper mirrors `readyVisits` logic exactly

**Known open item:** some legacy `patient_forms` rows may have
`visit_id = null` (generated before visit linkage was reliable). These
are silently excluded from the zip. A data backfill is needed for affected
patients — deferred pending Supabase incident resolution (Jul 6, 2026
Americas region 500 errors). See Open Items.

**`patient_forms` visit_id rule:** all per-visit document types must store
their generated PDF as a `patient_forms` row with `visit_id` set. This is
the mechanism that makes them automatically included in the zip. See
`PRODUCT_SPEC.md §12`.

### SYSTEM_PROMPT.md §13 — fresh doc upload rule added

Before producing any end-of-session documentation updates, fresh uploads
of all six documents are now required. Prevents updates based on
session-start copies that may have been edited mid-session.

---

## 2026-07-06 — Session 21

### PDF filename convention — complete

All generated PDFs now follow a structured naming convention.
Implemented in `cosmos-api/main.py` only — no changes to any
`forms/*.py` or `database.py`.

**Convention:**
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

---

## 2026-07-11 — Session 34

### UPCOMING KPI / Table Row Count Fix

`listReferrals()` was double-expanding MRI sessions. Removed expansion from
`listReferrals()` — base data returns one row per referral with
`_all_appointments` attached. UPCOMING filter in `ReferralDashboard.tsx`
does the expansion, gated to future dates + `outcome = null`. Status badge
for expanded rows shows "Scheduled".

### Per-Session Review Model (Migrations 031–032)

Migration 031: `referral_appointments.needs_review boolean NOT NULL DEFAULT false`.
Migration 032: `referral_appointments.reviewed_at timestamptz DEFAULT NULL`.

Per-session review replaces referral-level `needs_review` status. FD uploads
result → taps Done → `needs_review = true`. MD reviews → `reviewed_at = now()`,
`needs_review = false`. REVIEW KPI counts distinct referrals with
`needs_review = true`. `markSessionNeedsReview()` added. `reviewSession()`
updated — session-level, no referral status advance. `confirmSessionResults()`
removed.

### MD Dashboard Review Banner + Patient Card Badge

Cyan banner in `MDClient.tsx` shows when any patient has a session with
`needs_review = true`. Banner lists patient name + referral type with Tap →.
Per-patient card shows 📋 badge with count.

### ReferralsTabV2 — Session Results Table

`app/md-v2/[patientId]/ReferralsTabV2.tsx` fully rebuilt. For referrals
where any session has `needs_review = true` or `reviewed_at` set: card expands
to show shadcn Table with one row per completed session. Columns: Body Parts ·
Scheduled · Results Received · PDF · Review. Review button writes `reviewed_at`,
clears `needs_review`.

### DOB/DOI Client-Side Fetch

`ReferralSheet.tsx`: on open, separate `supabase.from('patients')` call sets
`patientDob`/`patientDoi` state. Bypasses PostgREST inline join limitation.

### Body Part Abbreviations

`abbrevBp(bp)` helper (Left→L., Right→R.) added to `ReferralAppointmentTab.tsx`,
`ReferralDashboard.tsx`, `ReferralsTabV2.tsx`.

### Font Bumps +2pt

`ReferralAppointmentTab.tsx`, `ReferralOverviewTab.tsx`, `ReferralTimelineTab.tsx`,
`InfoTabV2.tsx`, `PatientChartV2.tsx` header.

### ReferralOverviewTab Restyled

Provider name → cyan. Facility name, phone, email → green. Email + phone fields
added. `abbrevBp` applied to body part chips. Clinical reason → green.

### CT Session Splitting

`MriReferral.tsx` `createLifecycleRecord()`: when `modality === 'CT'`,
`body_parts` populated from `CT_STUDIES` selections. CT referrals now use
the same session splitter, per-session upload, Done button, and MD review
flow as MRI.

### allDone Logic Fix

`allDone` in `ReferralAppointmentTab.tsx` now checks
`unassignedParts.length === 0` instead of `schedCount >= reqSessions`.

### Provider Required Before Scheduling

`handleSchedule()` in `ReferralSheet.tsx` guards: if `!assignedId`, toast
error and return early.

### UPCOMING Filter Status Badge

Expanded UPCOMING rows show "Scheduled" badge. Expanded REVIEW rows show
"Needs MD Review" badge via `_session_is_review` flag.

---

## 2026-07-11 — Session 35

### MRI / CT Scan Sessions Label

"MRI Sessions" header in `ReferralAppointmentTab.tsx` renamed to
"MRI / CT Scan Sessions".

### Session Counter Redesign

`ReferralAppointmentTab.tsx`: counter changes from "X of Y scheduled" to
"X sessions scheduled · N parts remaining". `reqSessions` formula removed —
`unassignedParts.length` is the source of truth for done state.

### Provider Info Green in Appointment Tab

Assigned provider specialty/address/phone info color: `#64748b` → `#19a866`.

### Body Parts Removed from Main Table Rows

`ReferralDashboard.tsx`: body parts text removed from non-session rows.
Date chip removed from UPCOMING expanded session rows.

### Overview Tab Font +2pt

All font sizes in `ReferralOverviewTab.tsx` increased by 2pt.

### SessionLifecycle Enum Refactor

`types.ts`: `SessionLifecycle` type added (`pending` | `uploaded` |
`sent_review` | `reviewed` | `cancelled`). `computeSessionLifecycle()`
pure function exported. `actions.ts` `listReferrals()`: `reviewed_at` added
to `referral_appointments` select; `session_lifecycle` computed per
appointment. `ReferralSheet.tsx` `refreshDetail()`: same lifecycle
computation applied to client-fetched appointments. `ReferralDashboard.tsx`,
`ReferralAppointmentTab.tsx`: all scattered `outcome`/`needs_review`/
`reviewed_at` checks replaced with `session_lifecycle` reads.

### FD "Awaiting Done" Banner

`ReferralDashboard.tsx`: cyan collapsible banner above KPI cards lists all
sessions where `session_lifecycle === 'uploaded'`. Inline ✔ Done button per
row calls `markSessionNeedsReview()` and refreshes. Starts collapsed by default.

### AWAITING KPI Repurposed

AWAITING KPI counts sessions with `outcome = 'completed'` AND
`needs_review = false`. Tapping expands those sessions in the table with
"Uploaded" badge and inline Done button.

### CLOSED/MO KPI Tappable

CLOSED/MO card now tappable — filters table to show closed referrals.

### Treating Doctor Name on REVIEW Rows

`listReferrals()` extended: `patients` select includes `doctor_id` +
nested `doctors(first_name, last_name)`. `treating_doctor_name` mapped onto
base object. REVIEW filter rows show doctor name in cyan beneath badge.

### MD Review Banner Routing Fixed

`MDClient.tsx`: review banner routes to `/md-v2/[patientId]?tab=referrals&referral_id=xxx`
with `e.stopPropagation()`. `PatientChartV2.tsx`: reads `?tab` URL param for
initial tab. `ReferralsTabV2.tsx`: reads `?referral_id` to auto-expand target
referral. Fallback: auto-expands first referral with `needs_review = true`.

### Expand Preserved After MD Review

`ReferralsTabV2.tsx`: `handleReviewSession()` saves and restores `expandedId`
across `loadReferrals()` — card no longer collapses on review.

### Auto-Close Referral on Full Completion

`reviewSession()` in `actions.ts`: after marking a session reviewed, checks
if all body parts assigned and all completed sessions reviewed. If so, advances
referral to `closed`. MRI/CT only (`body_parts.length > 0` guard).

### Unscheduled Body Parts Warning

`ReferralsTabV2.tsx`: "⚠ Not yet scheduled: X, Y" in red below SESSION RESULTS
when body parts exist and some are unassigned. `body_parts` added to select.

### Done Button in AWAITING Table + Horizontal Scroll

`ReferralDashboard.tsx`: AWAITING filter table includes inline ✔ Done button
column. `_session_appointment_id` stored on expanded rows, added to
`ReferralSummary` type. Main table `Card` has `overflowX: 'auto'`.

### Deferred

Lock icon removal from Closed status (emoji anchor mismatch — 3 sessions
deferred). Betty Martin SQL reset. DEV artifacts removal. Patient email
required at intake.

---

## Session 36 — July 11, 2026

### Computed Referral Display Status — Core Architecture

**Problem:** STATUS badge read raw `referrals.status` DB column. Status
only updated on explicit events (create, schedule, review). `New`/`Scheduled`
showed incorrectly on referrals with complex session states. No `Upcoming`,
`Overdue`, `Uploaded`, `Awaiting Review` computed badges existed.

**Solution:** `computeReferralDisplayStatus()` added to `types.ts` — pure
function deriving display status from `_all_appointments` at read time.
Priority (highest urgency first): `closed` (terminal) → `overdue` (past
pending session) → `awaiting_review` (sent_review session) → `uploaded`
(uploaded session) → `upcoming` (future pending session, no day limit) →
`new` (no appointments). `Scheduled` absorbed into `Upcoming`. `Review`
badge dropped (no KPI). `ComputedReferralStatus` type + `_session_computed_status`
optional field added to `ReferralSummary`.

### getReferralMetrics() Rewrite

Single fetch of all referrals + appointments, then `computeReferralDisplayStatus()`
applied to each. KPI counts now always match filter results:

- PENDING — referrals with computed status `new`
- UPCOMING/OVERDUE/REVIEW/AWAITING — individual session counts (session-level)
- CLOSED/MO — referrals closed this calendar month

`computeReferralDisplayStatus` imported into `actions.ts`.

### Session-Level Badges in KPI Filter Expansions

Each filter expansion tags rows with `_session_computed_status` (Upcoming /
Awaiting Review / Uploaded / Overdue). STATUS badge cell reads
`_session_computed_status` first, falls back to `getComputedStatus(r)`.
OVERDUE filter now expands into individual overdue session rows. REVIEW
filter shows all referrals with `sent_review` sessions regardless of
computed status. OVERDUE inline tag (⚠ OVERDUE) suppressed in
non-overdue filter expansions.

### Body Part Gate on Schedule / Reschedule Forms

`ReferralAppointmentTab.tsx`: Save Appointment and Save Reschedule buttons
disabled when `isMri && sessionParts/reschedParts.length === 0`. Red warning
"⚠ Select at least 1 body part to save" shown when date filled but no
body part selected.

### reschedParts Pre-Population

`ReferralSheet.tsx` `handleOpenReschedule()`: `setReschedParts([])` →
`setReschedParts(Array.isArray(appt.body_parts) ? appt.body_parts : [])`.
Existing body parts pre-selected when reschedule form opens.

### Test Data Wipe

All test patients and related data wiped via Dev Tools "Wipe All Patients".
System clean for real data entry. Betty Martin stale status resolved by deletion.

### Deferred

Lock icon removal from Closed status (emoji anchor mismatch — 4 sessions
deferred). DEV artifacts removal. Patient email required at intake.
ReferralSheet header badge shows raw DB status (cosmetic — deferred).
