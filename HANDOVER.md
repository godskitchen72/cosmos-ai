# Cosmos Medical Technologies — HANDOVER (July 11, 2026, Session 34)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed and live on
`cosmos-dashboard-nu.vercel.app`. Session 34 priority queue largely
exhausted. Per-session MD review flow fully implemented end-to-end.
UPCOMING/REVIEW KPI cards match table row counts. DOB/DOI client-side
fetch live. Body part abbreviations (L./R.) throughout. CT session
splitting enabled. MD dashboard review banner + patient card badge live.

One open item: Lock icon removal from Closed status label (`types.ts`
icon field — emoji anchor mismatch). Deferred again. Betty Martin test
data still has stale `needs_review` referral status (pre-migration legacy
data) — needs SQL reset when convenient.

---

## Completed This Session (Session 34)

### UPCOMING KPI / Table Row Count Mismatch ✅ CLOSED

Root cause: `listReferrals()` was double-expanding MRI sessions (once in
actions.ts, once in ReferralDashboard.tsx). Removed expansion from
`listReferrals()` — base data now returns one row per referral with
`_all_appointments` attached. UPCOMING filter in ReferralDashboard.tsx
does the expansion, gated to future dates + `outcome = null`. Status badge
for expanded rows shows "Scheduled".

### REVIEW KPI / Table Row Count ✅ CLOSED

Migration 031: `referral_appointments.needs_review boolean NOT NULL DEFAULT false`.
Migration 032: `referral_appointments.reviewed_at timestamptz DEFAULT NULL`.

Per-session review model replaces referral-level `needs_review` status:
- FD uploads result → taps **✔ Done** → `needs_review = true` on session
- MD reviews session → `reviewed_at = now()`, `needs_review = false`
- REVIEW KPI counts `referral_appointments.needs_review = true` (distinct referrals)
- REVIEW filter expands to one row per `needs_review = true` session
- Referral-level status no longer used for review tracking

`markSessionNeedsReview(referralId, appointmentId)` added to `actions.ts`.
`reviewSession(referralId, appointmentId)` updated — clears `needs_review`,
sets `reviewed_at`, no longer auto-advances referral status.
`confirmSessionResults()` removed — replaced by per-session Done button.

### MD Dashboard Review Banner + Badge ✅ CLOSED

Cyan banner in `MDClient.tsx` shows when any patient has a session with
`needs_review = true`. Banner lists patient name + referral type with Tap →.
Per-patient card shows 📋 badge with count. Both query
`referral_appointments.needs_review = true` filtered to MD's patient list.

### ReferralsTabV2 — Session Results Table ✅ CLOSED

`app/md-v2/[patientId]/ReferralsTabV2.tsx` fully rebuilt. For referrals
where any session has `needs_review = true` or `reviewed_at` set:
- Card expands to show shadcn Table with one row per completed session
- Columns: Body Parts · Scheduled · Results Received · PDF · Review
- Review button writes `reviewed_at`, clears `needs_review`
- Status badge derives from appointment-level state (not referral status)
- Card border + prompt text reflects needs_review vs reviewed state
- `needs_review` added to `referral_appointments` select

### DOB/DOI Client-Side Fetch ✅ CLOSED

`ReferralSheet.tsx`: on open, separate `supabase.from('patients').select('dob,
doi').eq('patient_id', referral.patient_id)` call sets `patientDob`/`patientDoi`
state. Header renders DOB: MM/DD/YYYY · DOI: MM/DD/YYYY in green (#19a866).
Bypasses PostgREST inline join limitation.

### Body Part Abbreviations ✅ CLOSED

`abbrevBp(bp)` helper (Left→L., Right→R.) added to:
- `ReferralAppointmentTab.tsx` — session cards, unassigned pool, reschedule picker
- `ReferralDashboard.tsx` — session row body part chips
- `ReferralsTabV2.tsx` — session results table chips, card summary line

### Font Size Bumps ✅ CLOSED

+2pt throughout: `ReferralAppointmentTab.tsx`, `ReferralOverviewTab.tsx`,
`ReferralTimelineTab.tsx`, `InfoTabV2.tsx`, `PatientChartV2.tsx` header.

### ReferralOverviewTab Restyled ✅ CLOSED

Provider name → cyan (#00cfff). Facility name, phone, email → green (#19a866).
Email + phone fields added (requires `referral_providers.email, phone` in
`listReferrals()` select and `ReferralSummary` type). No extra spacing.
`abbrevBp` applied to body part chips. Clinical reason text → green (#19a866).

### Provider Required Before Scheduling ✅ CLOSED

`handleSchedule()` in `ReferralSheet.tsx` now guards: if `!assignedId`,
toast error "Assign a provider before scheduling." and return early.

### CT Session Splitting ✅ CLOSED

`MriReferral.tsx` `createLifecycleRecord()`: when `modality === 'CT'`,
`body_parts` is now populated from `CT_STUDIES` selections. MRI branch
unchanged. CT referrals now trigger the same session splitter, per-session
upload, Done button, and MD review flow as MRI.

### allDone Logic Fix ✅ CLOSED

`allDone` in `ReferralAppointmentTab.tsx` now checks
`unassignedParts.length === 0` instead of `schedCount >= reqSessions`.
Fixes "4 of 3 scheduled" display when more sessions are created than
`reqSessions` formula predicted.

### UPCOMING Filter Status Badge ✅ CLOSED

Expanded UPCOMING rows show "Scheduled" badge. Expanded REVIEW rows show
"Needs MD Review" badge. Implemented via `_session_is_review` flag on
expanded rows — avoids closure issue with `metricFilter` in useMemo columns.

---

## Open Items, Priority Order

1. **Lock icon removal from Closed status** (`types.ts` icon field).
   Python patch anchor failed Session 33 + 34 due to emoji Unicode encoding
   mismatch. Fix: pull `types.ts` fresh, inspect exact bytes around the
   icon field, write targeted patch.

2. **Betty Martin test data cleanup.** Referral still has `status =
   needs_review` from pre-migration `confirmSessionResults()` flow. Run:
   `UPDATE referrals SET status = 'scheduled' WHERE patient_id = 'PT120427'
   AND deleted_at IS NULL;` when convenient.

3. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

4. **Patient email required at intake.** `PatientForm.tsx` should make
   `email` a required field. All test patient emails NULL — patient
   confirmation emails dead until fixed.

5. **Sidebar rollout — FD, MD, Biller.** Deferred.

6. **Doctor mailing address data.** All current records are test data.
   Real provider data entered at go-live onboarding.

7. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

8. **Vercel Pro upgrade.** At go-live.

9. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — must be signed
   before go-live with real patient data.

10. **SPF/DKIM records** for `cosmosmt.com` — fixes email spam classification.
    At go-live.

11. **Twilio SMS integration.** Deferred.

12. **Provider portal — token-gated referral view.** Phase 2.

13. **`getReferralProviders()` return type.** Still `any[]`.

---

## Enterprise Hardening Checklist

### Stage 1 — Data Integrity ✅ Complete
- [x] FK constraints (Session 10)
- [x] Full RLS audit (Session 12)
- [x] NOT NULL constraints (Session 12)

### Stage 2 — Security ✅ Complete (except BAA)
- [x] API JWT authentication (Session 13)
- [x] Session timeout (Session 13)
- [x] Failed PIN attempt lockout (Session 17)
- [x] MFA for admin/billing/superadmin — TOTP, 30-day device trust (Session 17)
- [x] Audit log table — DB triggers + frontend logging (Session 17)
- [x] `patient_forms` RLS enabled (Session 27)
- [ ] HIPAA BAA with Supabase, Render, Vercel, Resend — administrative

### Stage 3 — Infrastructure
- [x] Database indexes on FK and common filter columns (Session 31 — Migration 028)
- [x] Error monitoring — Sentry on cosmos-dashboard + cosmos-api (Session 31)
- [ ] Staging environment
- [ ] GitHub Actions CI
- [ ] Supabase point-in-time recovery confirmed enabled

### Stage 4 — Code Quality
- [x] Admin page refactor (Session 18)
- [ ] Replace all `print()` in `cosmos-api` with structured logging
- [ ] Eliminate remaining `any` types — TypeScript strict mode
- [ ] React error boundaries on all dashboard surfaces
- [ ] Loading states on all data fetches

### Stage 5 — Product & UX
- [x] Admin sidebar nav (Session 19)
- [x] MD V2 shadcn chart (Session 23)
- [x] MDClient shadcn list (Session 23)
- [x] Login shadcn (Session 23)
- [x] Re-login hang fixed (Session 24)
- [x] Referral Management Module Phase 1 + 2 (Session 25)
- [x] Referral Module Phase 1 route deployed (Session 26)
- [x] Referral dual-write: PT, Ortho, Pain Mgmt, VNG, ANS (Session 26)
- [x] MD dashboard Referrals nav button (Session 26)
- [x] Referral dual-write: RX, DME (Session 27)
- [x] ReferralsTabV2 import cleanup (Session 27)
- [x] FD scheduling workflow — full end-to-end (Session 28)
- [x] FD dashboard Referrals nav button (Session 28)
- [x] Provider Directory CRUD in Admin (Session 28)
- [x] `cosmos_license_type` written for all roles on login (Session 28)
- [x] CosmosUI toast system fixed (Session 28)
- [x] Provider assignment — Appointment tab (Session 29)
- [x] Document upload — referral-documents bucket (Session 29)
- [x] Overdue row flagging + filter fix (Session 29)
- [x] Timeline — writes and display fully working (Session 29)
- [x] Dark dropdowns throughout ReferralSheet (Session 29)
- [x] CPT codes provider_type → General (Session 30)
- [x] patient_forms ghost row cleanup (Session 30)
- [x] ReferralProviderRow type cleanup — types.ts (Session 30)
- [x] patients.email field (Migration 027) (Session 30)
- [x] Referral notifications — patient + provider emails (Session 30)
- [x] MRI/Rx/DME PDF attachment in provider notification email (Session 30)
- [x] DB indexes — Migration 028 (Session 31)
- [x] Sentry error monitoring — both services (Session 31)
- [x] MRI spine UI fixes — rows of 2, per-pair exclusivity, CT dim (Session 31)
- [x] MRI session splitting — body parts pool, per-session assignment (Session 31)
- [x] Provider session email per appointment save (Session 31)
- [x] UPCOMING KPI → individual appointment count (Session 31)
- [x] OVERDUE KPI → stale + missed appointment conditions (Session 31)
- [x] Per-session rows in referral dashboard list (Session 31)
- [x] Migration 029 — referrals.body_parts, referral_appointments.body_parts (Session 31)
- [x] Migration 030 — referral_documents.appointment_id (Session 31)
- [x] Per-session result upload + FD Confirm + MD Mark Reviewed (Session 32)
- [x] Per-session cancel + reschedule buttons (Session 33)
- [x] Patient name in ReferralSheet header (Session 33)
- [x] Font size bump throughout ReferralAppointmentTab (Session 33)
- [x] PDF View badge on completed session cards (Session 33)
- [x] Timeline oldest-first + color updates (Session 33)
- [x] NEXT SESSION label green + chips cyan (Session 33)
- [x] UPCOMING KPI excludes completed/cancelled sessions (Session 33)
- [x] UPCOMING filter per-session row expansion (Session 33)
- [x] Email templates div layout + Oxanium font (Session 33)
- [x] UPCOMING KPI/table row count fix — removed double expansion (Session 34)
- [x] Per-session Done button replaces Confirm Results (Session 34)
- [x] Migration 031 — referral_appointments.needs_review (Session 34)
- [x] Migration 032 — referral_appointments.reviewed_at (Session 34)
- [x] markSessionNeedsReview() action (Session 34)
- [x] reviewSession() updated — session-level, no referral status advance (Session 34)
- [x] MD dashboard review banner + patient card badge (Session 34)
- [x] ReferralsTabV2 session results shadcn table (Session 34)
- [x] REVIEW KPI counts appointment-level needs_review (Session 34)
- [x] REVIEW filter expands per needs_review session (Session 34)
- [x] DOB/DOI client-side fetch in ReferralSheet (Session 34)
- [x] Body part abbreviations L./R. throughout (Session 34)
- [x] Font bumps +2pt — Overview, Timeline, InfoTabV2, PatientChartV2 (Session 34)
- [x] ReferralOverviewTab restyled — provider cyan, clinical reason green, email+phone (Session 34)
- [x] Provider required before scheduling gate (Session 34)
- [x] CT session splitting via body_parts population (Session 34)
- [x] allDone fix — uses unassignedParts.length===0 (Session 34)
- [x] referral_providers.email + phone added to listReferrals select (Session 34)
- [ ] Lock icon removal from Closed status (anchor mismatch — deferred)
- [ ] Patient email required at intake — PatientForm.tsx
- [ ] Sidebar rollout — FD, MD, Biller dashboards
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] Data retention and deletion policy
- [ ] Patient data export capability

---

## Known Architecture Gaps

- `getReferralProviders()` return type is still `any[]`.
- `/referrals/page.tsx` `userRole` prop hardcoded to `"md"` — relies on
  sessionStorage override in `useEffect`; hard refresh without re-login
  can expose wrong role default.
- `referral_notifications` table schema mismatch — designed for internal
  user notifications, not outbound Resend emails. Email delivery audit
  via Resend dashboard only.
- Betty Martin referral has stale `status = needs_review` from pre-migration
  `confirmSessionResults()` flow. Needs SQL reset.

---

## Technical Lessons This Session

- PostgREST inline join syntax is sensitive to column additions — confirmed
  again. Always use separate client-side queries for fields not in the
  original select.
- Python patch anchor failures are almost always caused by the file having
  changed since it was last read. Always pull a fresh copy immediately
  before writing a patch script.
- TypeScript `useMemo` columns don't see updated closure variables like
  `metricFilter` — use row-level flags (`_session_is_review`) instead of
  checking outer state inside cell renderers.
- When expanding referral rows into session rows, `_session_appointment`
  alone is insufficient for badge logic — add semantic flags like
  `_session_is_review` to disambiguate UPCOMING vs REVIEW expansions.
- `Math.ceil(totalParts / 2)` for `reqSessions` can be exceeded when
  sessions are rescheduled and new ones added — always check
  `unassignedParts.length === 0` for done state, not appointment count.
