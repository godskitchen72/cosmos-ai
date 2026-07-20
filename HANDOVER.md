# Cosmos Medical Technologies — HANDOVER (July 20, 2026, Session 50 — Close)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed and live as of Session 50 close.

**Production status:** `cosmosmt.com` is live. Referral dashboard fully rebuilt with appointment-driven architecture. MRI referral splitting, Multi-Referral tracking row, and single-appointment view all working.

**Dev environment status:** `cosmos-dev` Supabase project fully operational.

---

## Completed This Session (Session 50 — Full)

### MRI Referral Save Bug Fix ✅
`MriReferral.tsx` — error message moved from scrollable content area into fixed footer div, always visible above Save button regardless of scroll position. Silent failure when no modality selected now surfaces immediately.

### Appointment-Driven Referral Dashboard ✅
Complete architectural rebuild of referral tracking. Dashboard now shows one row per `referral_appointments` record instead of one row per referral.

**KPI counts (appointment-driven):**
- NEW = referrals with no appointments + MRI referrals with unscheduled body parts
- SCHEDULED = appointments with future date, no result
- RESCHEDULE = cancelled appointments (self-destroys on rebook)
- OVERDUE = appointments past date, no result
- CLOSED = appointments with result uploaded

**List rows:**
- One row per appointment, showing body part(s), date, status, provider
- Left border color per status (cyan=scheduled, orange=reschedule, red=overdue, green=closed)

**Files:** `app/referrals/ReferralDashboard.tsx`, `app/referrals/actions.ts`, `app/referrals/types.ts`

### Multi-Referral Row ✅
MRI/MRA/CT referrals with multiple body parts generate a persistent "Multi-Referral" reminder row in NEW. Shows unscheduled body parts remaining. Self-destroys when all body parts have active appointments. MULTI-REFERRAL badge rendered under patient name in purple.

### MRI Lifecycle — Stays `new` Throughout ✅
MRI/MRA/CT referrals no longer advance to `scheduled` status. They remain `new` until all sessions have results uploaded, then auto-close. Non-MRI referrals unchanged.

**`scheduleAppointment()`** — MRI skips status advance
**`cancelSession()`** — MRI stays `new` (non-MRI → `reschedule`)
**`rescheduleSession()`** — MRI stays `new` (non-MRI → `scheduled`)
**`uploadReferralResult()`** — MRI closes only when all body parts assigned + all sessions complete

### Referral Detail Full Page at `/referrals/[id]` ✅
`ReferralSheet.tsx` modal replaced with full-page navigation. Tapping a dashboard row navigates to `/referrals/[id]` (Multi-Referral) or `/referrals/[id]?appt=[uuid]` (individual appointment).

**Files added:** `app/referrals/[id]/page.tsx`, `app/referrals/[id]/ReferralDetailPage.tsx`

**Individual appointment view:** Single session card only — no chip pool, no schedule form (unless appointment is cancelled → rebook flow shown).

### CANCELLED Badge on Session Cards ✅
Cancelled appointments display orange CANCELLED badge, dimmed card, "Body part returned to unscheduled pool" note. No action buttons.

**File:** `app/referrals/components/ReferralAppointmentTab.tsx`

### Rebook Flow from RESCHEDULE Row ✅
Tapping a RESCHEDULE row opens single appointment view with:
- Cancelled session card (CANCELLED badge)
- "Rebook — select body parts" chip pool (cancelled body part pre-selected)
- Schedule form shown immediately

On save, cancelled appointment row is **deleted** from DB. RESCHEDULE row self-destroys. New SCHEDULED row appears.

### `needs_review` Column References Fixed ✅
Four files still querying removed `needs_review`/`reviewed_at` columns (removed Session 49). Fixed:
- `app/dashboard-v2/components/FDPatientSheet.tsx`
- `app/md-v2/[patientId]/ref/[rid]/page.tsx`
- `app/reports/ReportsClient.tsx`
- `app/reports/referrals/page.tsx`

### `Math.ceil` Session Gate Removed ✅
`scheduleAppointment()` no longer uses `Math.ceil(parts/2)` to gate MRI status advancement. Gate was preventing status from advancing even when appointment was booked.

### `ReferralAppointmentTab` — Unscheduled Parts Fix ✅
`assignedParts` now excludes cancelled appointments, so cancelled body parts correctly return to the unscheduled chip pool.

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet Merge blocked for production use. One click, $25/mo.

2. **Twilio SMS activation.** All code live. Three steps:
   - Buy `+17185695200`
   - Update `TWILIO_FROM_NUMBER` in Render
   - Complete A2P 10DLC business registration

3. **Production patient phone data.** All `patients.phone` = `+19297683179`. Clear before go-live:
   ```sql
   UPDATE patients SET phone = NULL;
   ```

4. **DEV artifacts removal.** PCE fill-all button in `VisitTab.tsx` + Dev Tools card in Admin panel.

5. **Patient phone required at intake.** `PatientFormV2.tsx` phone field must be required.

6. **Patient email required at intake.** `PatientFormV2.tsx` email field must be required.

7. **Appointment confirmation SMS trigger.** Wire `/notify/sms` into calendar booking save path.

8. **Referral detail page restyling.** `ReferralAppointmentTab.tsx`, `ReferralOverviewTab.tsx`, `ReferralNotesTab.tsx`, `ReferralDocumentsTab.tsx` need full restyling to match calendar BookingModal design tokens (`#0f1f2e` cards, `#19a866` section labels, `#0a1119` inputs).

9. **`page.tsx` userRole hardcoded.** `/referrals/page.tsx` passes `userRole="md"` — role is resolved client-side from sessionStorage. Not a bug but should be cleaned up.

10. **Duplicate visit records investigation.** Some patients have multiple `patient_visits` rows for the same date.

11. **`000_initial_schema.sql` superseded.** Stale on disk — use pg_dump approach.

---

## Known Architecture Gaps (carried forward)

- `patients.intake_url` exists only via manual SQL — not in any migration file.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- Ghost session timeout is 0 — impersonation sessions never expire.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"`.

---

## Referral Architecture — Session 50 Model

### Appointment-Driven Dashboard
- One row per `referral_appointments` record
- Multi-Referral reminder row (NEW bucket only) for MRI with unscheduled parts
- Individual appointment row navigates to `/referrals/[id]?appt=[uuid]`
- Multi-Referral row navigates to `/referrals/[id]` (all sessions)

### MRI Session Splitting Rules
- Max 2 body parts per session (FD chooses 1 or 2)
- Patient can spread across as many sessions as needed
- MRI referral status stays `new` throughout
- Closes only when ALL ordered body parts have sessions + ALL sessions have results

### Cancelled Appointment Lifecycle
- Cancel → `outcome = 'cancelled'` → RESCHEDULE row appears
- Rebook → cancelled appointment row **deleted** → RESCHEDULE row destroyed → new SCHEDULED row created
- History preserved in `referral_timeline`

### `outcome` Values (referral_appointments)
`null` (scheduled/pending) | `completed` | `cancelled` | `no_show`
Note: `superseded` was attempted but abandoned — delete approach used instead.

---

## Twilio Configuration Reference

| Env Var | Value | Location |
|---|---|---|
| `TWILIO_ACCOUNT_SID` | `AC...` (stored in Render env vars) | Render cosmos-api |
| `TWILIO_AUTH_TOKEN` | (set) | Render cosmos-api |
| `TWILIO_FROM_NUMBER` | `+18777804236` (placeholder) | Render cosmos-api |

**Target FROM number:** `+17185695200` (718 NYC, $1.15/mo, purchase pending)

---

## SMS Templates (live)

1. **Appointment Confirmed** — Hi [Name], your appointment at Cosmos Medical has been confirmed.
2. **Appointment Reminder** — Hi [Name], this is a reminder about your upcoming appointment at Cosmos Medical.
3. **Please Call Our Office** — Hi [Name], please call our office at your earliest convenience.
4. **Documents Needed** — Hi [Name], we have outstanding documents that require your attention.
5. **Results Ready** — Hi [Name], your test results are ready for review.

---

## Roadmap Checklist

### Stage 1 — Core Clinical
- [x] Patient intake — PatientFormV2 5-tab wizard
- [x] Visit documentation — SOAP, CPT, ICD-10
- [x] NF-2 generation and mailing
- [x] AOB generation

### Stage 2 — Referral Management
- [x] Full referral lifecycle
- [x] MRI/MRA/CT body parts + session splitting
- [x] SONO/FC/PSY/EMG/ANS referral types
- [x] Auto-close on result upload
- [x] Referral workflow redesign — 7 statuses, all auto-transitions
- [x] MD review workflow removed
- [x] Appointment-driven dashboard (Session 50)
- [x] Multi-Referral tracking row (Session 50)
- [x] MRI stays `new` throughout lifecycle (Session 50)
- [x] Single appointment view at /referrals/[id]?appt= (Session 50)
- [x] Rebook flow from RESCHEDULE row (Session 50)
- [ ] Referral detail page restyling (calendar design tokens)
- [ ] DME and RX codes from patient_visits
- [ ] Patient email required at intake
- [ ] DEV artifacts removal

### Stage 3 — Front Desk Dashboard V2
- [x] Full FD Dashboard V2
- [x] SMS notification system
- [x] Referral dashboard appointment-driven (Session 50)
- [ ] Appointment confirmation SMS — auto-trigger on booking
- [ ] Patient phone required at intake
- [ ] Notes tab persistence
- [ ] Realtime — referrals and appointments tables

### Stage 5 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] Twilio SMS activation
- [ ] 000_initial_schema.sql removal/replacement

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend, Twilio
- [ ] SPF/DKIM for cosmosmt.com
