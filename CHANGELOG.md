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
