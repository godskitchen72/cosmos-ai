# Cosmos Medical Technologies — HANDOVER (July 12, 2026, Session 37)

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
`cosmos-dashboard-nu.vercel.app`. Session 37 completed the ANS referral
module end-to-end, fixed the MD review table collapse bug, removed DEV UI
artifacts, fixed the audit trail actor attribution system, and introduced
the `isImaging` category-based referral type architecture.

---

## Completed This Session (Session 37)

### MD Review Table Collapse Fix ✅ CLOSED

Silent refresh pattern introduced to `loadReferrals()` in `ReferralsTabV2.tsx`.
`keepExpandedId` and `silent` params added — silent skips `setLoading(true)`
so card never collapses during post-review refresh. `fetchResultDocs` stale
closure bug fixed — early-return guard `if (resultDocs[referralId]) return`
removed; docs always re-fetched after review. `isReviewed` and `handleCardClick`
expandable conditions extended to include `status === 'closed'` so reviewed
referrals remain expandable after auto-close.

### UI Cleanup ✅ CLOSED

- Move To status chips removed from `ReferralSheet.tsx`
- Awaiting Done banner and `bannerExpanded` state removed from `ReferralDashboard.tsx`
- `pendingDoneSessions`, `donningSessionId`, `handleDoneFromBanner` retained — still used by AWAITING KPI filter expansion

### ReferralSheet Default Tab → Appointment ✅ CLOSED

`useState<Tab>('overview')` → `useState<Tab>('appointment')`. Confirmed
on disk at line 66 of `ReferralSheet.tsx`. Browser cache caused apparent
persistence in screenshots — code is correct.

### Session Header — Cyan Color + 12-Hour Time ✅ CLOSED

`ReferralAppointmentTab.tsx`: session header `color` always `#00cfff`.
`fmtTime12()` helper added — converts `HH:MM:SS` to `h:MM AM/PM`. Applied
to both MRI session cards and new non-imaging session card.

### ANS Referral Module — Full End-to-End ✅ CLOSED

**Overview tab:** Testing Requested (full labels with ✓), Diagnosis/Symptoms
(cyan chips), ICD-10 Codes (cyan chips) displayed. Clinical reason, symptoms,
ICD-10 all in cyan. CPT codes removed from display.

**DB:** `ans_tests TEXT[]` and `ans_symptoms TEXT[]` added to `referrals`
table via Supabase SQL editor.

**Data flow:** `AnsReferral.tsx` saves selected test labels and symptom
labels on INSERT. `cpt_codes` and `icd10_codes` fetched server-side from
`patient_visits` in `page.tsx` and passed as props. `listReferrals()` now
selects `cpt_codes`, `icd10_codes`, `ans_tests`, `ans_symptoms`.

**Appointment tab:** MRI-style single session card — `Session 1 · Date · Time`
header (cyan), ANS test chips, Upload · Reschedule · Cancel. Uploaded state
mirrors MRI: View PDF · Delete · Done → Sent for MD Review.

**Auto-close:** `reviewSession()` extended — non-imaging referrals (ANS, VNG)
now auto-close when all completed appointments reviewed.

**Provider email:** `scheduleAppointment()` provider email includes ICD-10
and CPT codes for all referral types.

### isImaging Refactor ✅ CLOSED

`isMri` → `isImaging` throughout `ReferralAppointmentTab.tsx`. Gate is now
`category === 'imaging'` instead of `body_parts.length > 0`. Future referral
types route correctly by DB category alone.

### Referral Overview Tab Enhancements ✅ CLOSED

Clinical reason → cyan. Symptom chips → cyan. ICD-10 chips → cyan. CPT
section removed. ANS Testing Requested section added (full labels, ✓ prefix).
ANS Symptoms section added.

### Timeline Actor Attribution — Full Audit Trail ✅ CLOSED

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

---

## Open Items, Priority Order

1. **Lock icon removal from Closed status** (`types.ts` icon field).
   Python patch anchor failed Sessions 33, 34, 35, and 36 due to emoji
   Unicode encoding mismatch. Not attempted this session. Fix: pull `types.ts`
   fresh, inspect exact bytes around the icon field, use Python `str.replace()`
   directly with byte-level anchor.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientForm.tsx` should make
   `email` a required field. Patient confirmation emails dead until fixed.

4. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only — dashboard
   table and filters are correct.

5. **Render memory limit — cosmos-api.** Render Starter plan (512MB)
   crashes during PDF generation under load. **Pre-go-live blocker.**
   Upgrade to Standard plan ($25/mo, 2GB RAM) before real patient data.
   Long-term: migrate PDF generation to client-side `@react-pdf/renderer`
   or Vercel serverless function — removes server memory spike entirely.
   Phase 2 item.

6. **MRI referrals should pull cpt_codes/icd10_codes from patient_visits.**
   Currently hardcoded to `[]` in `MriReferral.tsx`. Same server-side fetch
   pattern as ANS should be applied to all referral type creation pages.

7. **Add FK: `referral_timeline.actor_user_id → user_profiles.id`.**
   Currently no FK — timeline join done client-side as workaround. Adding
   FK allows server-side join and eliminates extra client fetch.

8. **Body parts missing on pre-Session-36 rescheduled sessions.** Data
   issue only — new reschedules are gated correctly.

9. **Sidebar rollout — FD, MD, Biller.** Deferred.

10. **Doctor mailing address data.** All current records are test data.
    Real provider data entered at go-live onboarding.

11. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

12. **Vercel Pro upgrade.** At go-live.

13. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — must be signed
    before go-live with real patient data.

14. **SPF/DKIM records** for `cosmosmt.com` — fixes email spam classification.
    At go-live.

15. **Twilio SMS integration.** Deferred.

16. **Provider portal — token-gated referral view.** Phase 2.

17. **`getReferralProviders()` return type.** Still `any[]`.

---

## Pre-Go-Live Blockers

- [ ] Render upgrade to Standard plan (memory limit — crashes on PDF generation)
- [ ] HIPAA BAAs signed (Supabase, Render, Vercel, Resend)
- [ ] SPF/DKIM configured for cosmosmt.com
- [ ] DEV artifacts removed (PCE fill button, Admin Dev Tools card)
- [ ] Patient email required at intake
- [ ] Lock icon fix on Closed status

---

## DB Schema Changes This Session

```sql
-- Added to referrals table (applied via Supabase SQL editor — no migration file)
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS ans_tests TEXT[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS ans_symptoms TEXT[];
```

Last migration on file: 032.

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
- [x] MD review table collapse fixed — silent refresh, stale closure resolved (Session 37)
- [x] Move To chips + Awaiting Done banner removed (Session 37)
- [x] Default tab → Appointment (Session 37)
- [x] Session header cyan + 12-hour time format (Session 37)
- [x] ANS referral module — full end-to-end (Session 37)
- [x] ans_tests + ans_symptoms columns on referrals (Session 37)
- [x] isImaging refactor — category-based routing (Session 37)
- [x] ReferralOverviewTab — cyan colors, ANS sections (Session 37)
- [x] Full audit trail attribution — userId from client to all server actions (Session 37)
- [x] @supabase/ssr installed, getActorId() updated (Session 37)
- [x] Timeline — ROLE · Full Name display in cyan (Session 37)
- [x] Auto-close extended to non-imaging referral types (Session 37)
- [x] Provider email includes ICD-10 + CPT codes for all referral types (Session 37)
- [ ] Lock icon removal from Closed status (anchor mismatch — deferred x4)
- [ ] ReferralSheet header badge — still shows raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientForm.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] MRI referral pages: pull cpt_codes/icd10_codes from patient_visits
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id
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
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id` —
  timeline actor names resolved client-side as workaround.
- `(referral as any).cpt_codes` cast in `ReferralOverviewTab` — `cpt_codes`,
  `icd10_codes`, `ans_tests`, `ans_symptoms` not yet typed in `ReferralSummary`
  TypeScript interface. Add to `types.ts` to remove cast.
- Render Starter plan (512MB) insufficient for PDF generation under load.
  Crashed during Session 37 testing.

---

## Technical Lessons This Session

- Silent refresh pattern (`silent` param skipping `setLoading`) is the
  correct approach for post-action data refreshes where UI state must be
  preserved. `setLoading(true)` causes full card re-render and visual collapse.
- Stale closure bug: `setResultDocs(prev => delete next[id])` is async —
  calling `fetchResultDocs(id)` immediately after reads stale closure where
  the entry still exists. Remove the early-return guard instead.
- `@supabase/auth-helpers-nextjs` 0.15 is deprecated and broken for Next.js
  16 server action session propagation. Replace with `@supabase/ssr` 0.12.
  Even then, server-side session is unreliable — passing `userId` from the
  client is the definitive fix.
- Supabase PostgREST foreign key joins (`table(col)`) only work when an
  explicit FK constraint exists. Without FK, use separate query + client-side
  merge.
- Render Starter (512MB) is not suitable for PDF generation under any real
  load. Plan migration to client-side PDF generation before scale.
- `category` field in `referral_types` table is the correct gate for
  referral type routing — more explicit and future-proof than heuristics
  like `body_parts.length > 0`.
- Python `str.replace()` is more reliable than `sed -i` for multi-line
  anchors in Termux. Always prefer Python for complex replacements.
- File paths in patch scripts must use `os.path.expanduser('~/')` not
  hardcoded `/home/user/` — Termux home is
  `/data/data/com.termux/files/home/`.
- `git show HEAD:path` exports files correctly; always verify byte count
  with `wc -c` before uploading to confirm the file is non-empty.
