# Cosmos Medical Technologies — HANDOVER (July 11, 2026, Session 36)

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
`cosmos-dashboard-nu.vercel.app`. Session 36 completed a full referral
status lifecycle redesign — computed status replaces raw DB status display
throughout the dashboard, KPI counts now match filter results exactly, and
session-level badges apply in all KPI filter expansions. Body part gating
added to schedule/reschedule forms. All test data wiped clean.

Betty Martin SQL reset is now moot — all test data wiped this session.
Lock icon deferred again (not attempted this session).

---

## Completed This Session (Session 36)

### Computed Referral Display Status — Core Architecture ✅ CLOSED

**Problem:** Referral STATUS badge read raw `referrals.status` DB column
directly. Status was only written on explicit events (create, schedule,
review). `New`, `Scheduled` showed incorrectly on referrals with complex
session states. No `Upcoming`, `Overdue`, `Uploaded`, `Awaiting Review`
badges existed.

**Solution:** `computeReferralDisplayStatus()` added to `types.ts` — pure
function that derives display status from `_all_appointments` session data
at read time. Never writes to DB. Priority order (highest urgency first):

1. `closed` — terminal DB state, never recomputed
2. `overdue` — any non-cancelled pending session with past date
3. `awaiting_review` — any session with `session_lifecycle === 'sent_review'`
4. `uploaded` — any session with `session_lifecycle === 'uploaded'`
5. `upcoming` — any non-cancelled pending session with future date (no day limit)
6. `new` — no appointments at all

`Scheduled` and `Review` statuses removed entirely. `Scheduled` absorbed
into `Upcoming`. `Review` badge had no corresponding KPI and was dropped.

`ComputedReferralStatus` type added to `types.ts`. `_session_computed_status`
optional field added to `ReferralSummary` type.

### getReferralMetrics() Rewrite ✅ CLOSED

`getReferralMetrics()` in `actions.ts` rewritten from parallel Supabase
count queries to a single fetch of all referrals + appointments, then
`computeReferralDisplayStatus()` applied to each. KPI counts now always
match what the filter shows:

- **PENDING** — referrals whose computed status is `new`
- **UPCOMING** — individual future pending sessions (session-level count)
- **AWAITING** — individual uploaded sessions (session-level count)
- **REVIEW** — individual `sent_review` sessions (session-level count)
- **OVERDUE** — individual past pending sessions (session-level count)
- **CLOSED/MO** — referrals closed this calendar month

`computeReferralDisplayStatus` imported into `actions.ts`.

### Session-Level Badges in KPI Filter Expansions ✅ CLOSED

Each KPI filter expansion now tags rows with `_session_computed_status`
matching that filter's context:

- UPCOMING filter → each row gets `_session_computed_status: 'upcoming'`
- REVIEW filter → each row gets `_session_computed_status: 'awaiting_review'`
- AWAITING filter → each row gets `_session_computed_status: 'uploaded'`
- OVERDUE filter → expands into individual overdue session rows, each
  tagged `_session_computed_status: 'overdue'`

STATUS badge cell in `ReferralDashboard.tsx` reads `_session_computed_status`
first, falls back to `getComputedStatus(r)` for unfiltered rows.

OVERDUE inline tag (⚠ OVERDUE) in patient name cell now only shows when
`_session_computed_status === 'overdue'` or when no session status is set
and `isOverdue(r)` is true — suppressed in UPCOMING/REVIEW/AWAITING filter
expansions.

REVIEW filter updated to show ALL referrals with `sent_review` sessions
regardless of referral computed status (consistent with UPCOMING/OVERDUE
approach).

### Body Part Gate on Schedule / Reschedule Forms ✅ CLOSED

`ReferralAppointmentTab.tsx`: Save Appointment and Save Reschedule buttons
disabled when `isMri && sessionParts.length === 0` (or `reschedParts.length === 0`).
Red warning "⚠ Select at least 1 body part to save" shown above the button
when date is filled but no body part selected.

### reschedParts Pre-Population on Reschedule Open ✅ CLOSED

`ReferralSheet.tsx` `handleOpenReschedule()`: `setReschedParts([])` →
`setReschedParts(Array.isArray(appt.body_parts) ? appt.body_parts : [])`.
Existing body parts now pre-selected when the reschedule form opens.

### Test Data Wipe ✅ CLOSED

All test patients, referrals, appointments, and related data wiped via
Dev Tools "Wipe All Patients" button. Betty Martin stale status issue
resolved by deletion. System is clean for real data entry.

---

## Open Items, Priority Order

1. **Lock icon removal from Closed status** (`types.ts` icon field).
   Python patch anchor failed Sessions 33, 34, and 35 due to emoji Unicode
   encoding mismatch. Not attempted this session. Fix: pull `types.ts`
   fresh, inspect exact bytes around the icon field, use Python `str.replace()`
   directly with byte-level anchor.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientForm.tsx` should make
   `email` a required field. Patient confirmation emails dead until fixed.

4. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only — dashboard
   table and filters are correct. Requires reading `_all_appointments`
   in `ReferralSheet.tsx` and passing to `computeReferralDisplayStatus()`.

5. **Body parts missing on pre-Session-36 rescheduled sessions.** Sessions
   rescheduled before the body part gate was added have empty `body_parts`
   arrays. Data issue only — new reschedules are gated correctly.

6. **Sidebar rollout — FD, MD, Biller.** Deferred.

7. **Doctor mailing address data.** All current records are test data.
   Real provider data entered at go-live onboarding.

8. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

9. **Vercel Pro upgrade.** At go-live.

10. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — must be signed
    before go-live with real patient data.

11. **SPF/DKIM records** for `cosmosmt.com` — fixes email spam classification.
    At go-live.

12. **Twilio SMS integration.** Deferred.

13. **Provider portal — token-gated referral view.** Phase 2.

14. **`getReferralProviders()` return type.** Still `any[]`.

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
- [x] MRI/CT Scan Sessions label rename (Session 35)
- [x] Session counter redesign — X sessions · N parts remaining (Session 35)
- [x] Provider info green in Appointment tab (Session 35)
- [x] Body parts removed from main table rows (Session 35)
- [x] Date chip removed from UPCOMING expanded rows (Session 35)
- [x] Overview tab font +2pt (Session 35)
- [x] SessionLifecycle enum refactor — single source of truth (Session 35)
- [x] FD "Awaiting Done" banner with inline table + Done button (Session 35)
- [x] AWAITING KPI repurposed to uploaded-awaiting-Done count (Session 35)
- [x] CLOSED/MO KPI tappable — filters to closed referrals (Session 35)
- [x] Treating doctor name in cyan on REVIEW rows (Session 35)
- [x] MD review banner routing fixed — routes to md-v2 + stopPropagation (Session 35)
- [x] PatientChartV2 reads ?tab URL param for initial tab (Session 35)
- [x] ReferralsTabV2 auto-expands referral from ?referral_id param (Session 35)
- [x] Expand state preserved after MD review (Session 35)
- [x] Auto-close referral when all body parts reviewed (Session 35)
- [x] Unscheduled body parts warning in ReferralsTabV2 (Session 35)
- [x] Done button in AWAITING table rows + horizontal scroll (Session 35)
- [x] computeReferralDisplayStatus() — computed status from session data (Session 36)
- [x] ComputedReferralStatus type + _session_computed_status on ReferralSummary (Session 36)
- [x] getReferralMetrics() rewritten — counts via computed status (Session 36)
- [x] UPCOMING/OVERDUE/REVIEW/AWAITING KPI counts are session-level (Session 36)
- [x] Session-level badges in all KPI filter expansions (Session 36)
- [x] OVERDUE inline tag suppressed in non-overdue filter rows (Session 36)
- [x] REVIEW filter shows all sent_review sessions across all referrals (Session 36)
- [x] Body part gate on schedule/reschedule save buttons (Session 36)
- [x] "⚠ Select at least 1 body part to save" warning on schedule/reschedule (Session 36)
- [x] reschedParts pre-populated from session body_parts on reschedule open (Session 36)
- [x] All test data wiped — system clean (Session 36)
- [ ] Lock icon removal from Closed status (anchor mismatch — deferred x3)
- [ ] ReferralSheet header badge — still shows raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientForm.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
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
- ReferralSheet header badge reads raw `referrals.status` DB column —
  shows `New`/`Scheduled` instead of computed status. Cosmetic gap only;
  dashboard table and all KPI filters are correct.
- Body parts missing on sessions rescheduled before Session 36 — data
  issue only, new reschedules are gated correctly.
- Lock icon emoji in `types.ts` `REFERRAL_STATUS_META` icon field for
  `closed` status cannot be patched via Python string anchors due to Unicode
  encoding mismatch — requires byte-level inspection.

---

## Technical Lessons This Session

- Status computed at read time from session data is more reliable than
  event-driven DB writes — eliminates stale status bugs entirely. Pattern:
  `computeReferralDisplayStatus()` mirrors `computeSessionLifecycle()`.
- KPI counts must use the same logic as filter predicates or they will
  always drift. Solution: rewrite `getReferralMetrics()` to iterate
  referrals + sessions using the same `computeReferralDisplayStatus()`
  function rather than parallel SQL count queries.
- Session-level KPI counts (UPCOMING/OVERDUE/REVIEW/AWAITING) require
  filter expansions that produce one row per session. The `_session_computed_status`
  field on each expanded row lets the badge cell show the session-specific
  status rather than the referral's overall computed status.
- Python `str.replace()` is more reliable than `sed -i` for multi-line
  anchors in Termux. Always prefer Python for complex replacements.
- File paths in patch scripts must use `os.path.expanduser('~/')` not
  hardcoded `/home/user/` — Termux home is
  `/data/data/com.termux/files/home/`.
- When TypeScript rejects a property on a spread object literal, add the
  field as optional (`?`) to the base type rather than using `as any` casts
  throughout — cleaner and catches real type errors.
- `git show HEAD:path` exports files correctly; always verify byte count
  with `wc -c` before uploading to confirm the file is non-empty.
