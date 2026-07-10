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
