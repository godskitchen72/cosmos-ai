# Cosmos Medical Technologies — HANDOVER (July 18, 2026, Session 49 — Close)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed and live as of Session 49 close.

**Production status:** `cosmosmt.com` is live. Referral dashboard fully rebuilt with new workflow. SMS infrastructure live — activation still pending phone number purchase.

**Dev environment status:** `cosmos-dev` Supabase project fully operational. Schema matches production including Session 49 migrations.

---

## Completed This Session (Session 49 — Full)

### Referral Dashboard — Work Queue Columns ✅ CLOSED

`ReferralDashboard.tsx` rebuilt with new column set:
- **Patient · Type (+ body parts) · Provider · Ref. Created · Appt · Docs Rcvd · Workflow Stage · Actions**
- Provider column in green bold (`#19a866`)
- Type column shows body parts as cyan chips below label (MRI/CT/MRA only)
- Workflow Stage badge is tappable — opens ReferralSheet on correct tab per status
- Actions column: 👁 View · 📞 Call (provider call modal) · ✉ Email (mailto provider)
- Appt column: "Book Appt" button when no appointment exists (opens Appointment tab)
- Docs Rcvd column: green "Results In" / yellow "Awaiting"

### Referral Workflow Redesign ✅ CLOSED

Complete referral lifecycle simplified from 15 statuses to 7. All transitions automatic.

**New `ReferralStatus` union:** `new | scheduled | reschedule | cancelled | awaiting_results | results_received | closed`

**New `SessionLifecycle`:** `pending | result_uploaded | cancelled` (removed `uploaded`, `sent_review`, `reviewed`)

**Transition logic:**
- Created → `new`
- Appointment saved → `scheduled` (from `new`, `reschedule`, `cancelled`)
- No-show / Cancel → `reschedule` (auto on `cancelSession()`)
- Reschedule saved → `scheduled`
- Result uploaded → `results_received` → `closed` (two-step auto on upload)

**Overdue computed overlay (not a DB status):**
- `new` / `reschedule` / `cancelled` — 2+ days with no new appointment
- `awaiting_results` — 7+ days since appointment date

**Files changed:** `app/referrals/types.ts`, `app/referrals/actions.ts`, `app/referrals/ReferralDashboard.tsx`, `app/referrals/ReferralSheet.tsx`, `app/referrals/components/ReferralAppointmentTab.tsx`, `app/md-v2/[patientId]/ReferralsTabV2.tsx`

### 9 KPI Cards — Referral Dashboard ✅ CLOSED

4×2 grid: **Total · New · Scheduled · Reschedule · Cancelled · Awaiting · Overdue · Closed**
- Total and Closed in green (`#19a866`)
- Each status has distinct accent color matching badge palette
- Overdue is computed overlay — counts referrals in any overdue condition

### MD Review Workflow — Removed ✅ CLOSED

`markSessionNeedsReview()`, `reviewSession()`, `confirmSessionResults()` deleted from `actions.ts`.
`needs_review` and `reviewed_at` columns dropped from `referral_appointments` (Migration 032).
`ReferralSheet.tsx` and `ReferralsTabV2.tsx` updated to remove all references.

### Storage RLS Fix — referral-documents bucket ✅ CLOSED

INSERT policy had null `WITH CHECK` clause — uploads were silently failing. Fixed:
- Dropped and recreated INSERT policy with correct `WITH CHECK (bucket_id = 'referral-documents')`
- Added missing DELETE policy for `authenticated` role
Applied to both production and cosmos-dev.

### DB Status Constraint Updated ✅ CLOSED

`referrals_status_check` constraint rebuilt on production and cosmos-dev to match new status values:
`('new','scheduled','reschedule','cancelled','awaiting_results','results_received','closed')`

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet
   Merge is blocked for production use until this upgrade lands. One click in
   Render dashboard — $25/mo, no code change.

2. **Twilio SMS activation.** All code is live. Three steps remaining:
   - Buy `+17185695200` (718 NYC number, $1.15/month) — already in cart
   - Update `TWILIO_FROM_NUMBER` in Render from `+18777804236` → `+17185695200`
   - Complete A2P 10DLC business registration (takes a few days after submission)
   - Test live SMS send from FD dashboard

3. **Production patient phone data.** All `patients.phone` records are `+19297683179`
   (set for SMS testing Session 48). Must be cleared before go-live:
   ```sql
   UPDATE patients SET phone = NULL;
   ```

4. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

5. **Patient phone required at intake.** `PatientFormV2.tsx` phone field
   must become required. SMS notifications silently fail for patients with no
   phone on file.

6. **Patient email required at intake.** `PatientFormV2.tsx` email field
   must become required. Deferred multiple sessions.

7. **Appointment confirmation SMS trigger.** `/notify/sms` endpoint exists
   but nothing calls it automatically on booking. Wire into calendar booking
   save path after Twilio activation confirmed.

8. **Duplicate visit records investigation.** Some patients have multiple
   `patient_visits` rows for the same date sharing generated PDF filenames.
   Root cause unknown.

9. **000_initial_schema.sql — superseded by pg_dump method.** Stale on disk.
   Use pg_dump approach documented in MIGRATIONS.md instead.

---

## Known Architecture Gaps (carried forward)

- `patients.intake_url` exists only via manual SQL — not in any migration file.
  Schema drift risk if DB is rebuilt (pg_dump will capture it going forward).
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- Ghost session timeout is 0 — impersonation sessions never expire.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — wrong role on hard
  refresh without re-login.

---

## Twilio Configuration Reference

| Env Var | Value | Location |
|---|---|---|
| `TWILIO_ACCOUNT_SID` | `ACabce173444c01d6b1735130ec2f354a9` | Render cosmos-api |
| `TWILIO_AUTH_TOKEN` | (set) | Render cosmos-api |
| `TWILIO_FROM_NUMBER` | `+18777804236` (placeholder — update next session) | Render cosmos-api |

**Target FROM number:** `+17185695200` (718 NYC, $1.15/mo, purchase pending)

**A2P 10DLC:** Required for production SMS delivery to US numbers. Must register Cosmos Medical Technologies as a business sender via Twilio console after number purchase.

---

## SMS Templates (live in SmsModal + notifications.py)

1. **Appointment Confirmed** — Hi [Name], your appointment at Cosmos Medical has been confirmed. We look forward to seeing you. Reply STOP to opt out.
2. **Appointment Reminder** — Hi [Name], this is a reminder about your upcoming appointment at Cosmos Medical. Please call our office if you need to reschedule. Reply STOP to opt out.
3. **Please Call Our Office** — Hi [Name], please call our office at your earliest convenience regarding your treatment. Reply STOP to opt out.
4. **Documents Needed** — Hi [Name], we have outstanding documents that require your attention. Please contact our office. Reply STOP to opt out.
5. **Results Ready** — Hi [Name], your test results are ready for review. Please schedule a follow-up visit. Reply STOP to opt out.

Note: `[Name]` is auto-substituted with patient first name when template is selected in the modal.

---

## Referral Status Reference (Session 49)

| Status | DB Value | Color | Trigger |
|---|---|---|---|
| New | `new` | `#a78bfa` purple | Referral created |
| Scheduled | `scheduled` | `#60a5fa` blue | Appointment saved |
| Reschedule | `reschedule` | `#f97316` orange | No-show or cancel |
| Cancelled [REBOOK] | `cancelled` | `#ef4444` red | FD cancels |
| Awaiting Results | `awaiting_results` | `#fbbf24` amber | Appointment date passed |
| Results Received | `results_received` | `#4ade80` green | Result uploaded (transient) |
| Closed | `closed` | `#94a3b8` grey | Auto on upload |
| **Overdue** | *(computed)* | `#fca5a5` red | 2+ days no action / 7+ days no result |

---

## Roadmap Checklist

### Stage 1 — Core Clinical
- [x] Patient intake — PatientFormV2 5-tab wizard (Session 43)
- [x] Visit documentation — SOAP, CPT, ICD-10 (Sessions 1–20)
- [x] NF-2 generation and mailing (Sessions 1–20)
- [x] AOB generation (Sessions 1–20)

### Stage 2 — Referral Management
- [x] Full referral lifecycle (Sessions 30–46)
- [x] MRI/MRA/CT body parts (Sessions 38–39)
- [x] SONO/FC/PSY/EMG/ANS referral types (Sessions 37, 45)
- [x] Auto-close on result upload — all types (Session 49)
- [x] Referral workflow redesign — 7 statuses, all auto-transitions (Session 49)
- [x] MD review workflow removed — replaced by auto-close (Session 49)
- [x] Referral Pipeline report (Session 45)
- [ ] DME and RX codes from patient_visits
- [ ] Patient email required at intake — PatientFormV2.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id

### Stage 3 — Front Desk Dashboard V2
- [x] Full FD Dashboard V2 (Sessions 40–46)
- [x] SMS notification system — modal, templates, API (Session 48)
- [x] Call modal — work queue (Session 48)
- [x] Message QuickAction — patient sheet (Session 48)
- [x] Referral dashboard work queue columns — Provider, Type, Workflow Stage, Actions (Session 49)
- [x] Provider call modal — referral dashboard (Session 49)
- [ ] Appointment confirmation SMS — auto-trigger on booking
- [ ] Patient phone required at intake
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables
- [ ] Remove legacy PatientForm.tsx

### Stage 3b — FD Reports
- [x] All report tabs (Sessions 42–47)
- [x] Reports landing page (Session 47)
- [x] Active Patients report (Session 47)

### Stage 3c — Patient Intake
- [x] PatientFormV2 (Session 43)
- [ ] Patient email required
- [ ] Patient phone required
- [ ] intake_url added to migration file

### Stage 3d — Superadmin & Ghost Mode
- [x] Full JWT impersonation (Session 43)
- [ ] Ghost mode for PA/NP users
- [ ] Impersonation session timeout

### Stage 3e — Scheduling
- [x] Calendar redesign + smart booking (Sessions 44, 46)
- [ ] Appointment confirmation SMS on booking
- [ ] Calendar realtime
- [ ] Conflict-aware time slot display

### Stage 3f — Admin
- [x] All admin sections complete (Sessions 46–47)

### Stage 4 — Billing
- [ ] Billing packet generation improvements
- [ ] Attorney email workflow

### Stage 5 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] Twilio SMS activation — number purchase + A2P 10DLC
- [x] Dev/Preview environment (Sessions 47–48)
- [ ] 000_initial_schema.sql removal/replacement

### Stage 6 — Scale
- [ ] Holistic UX audit
- [ ] Accessibility
- [ ] Multi-tenancy

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend, Twilio
- [ ] SPF/DKIM for cosmosmt.com
- [ ] Data retention and deletion policy
- [ ] Patient data export capability
