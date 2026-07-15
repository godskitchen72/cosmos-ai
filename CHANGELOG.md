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
