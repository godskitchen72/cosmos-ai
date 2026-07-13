# Cosmos Medical Technologies — HANDOVER (July 13, 2026, Session 38)

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
`cosmos-dashboard-nu.vercel.app`. Session 38 completed the referral
codes refactor (MRI/VNG/Ortho/Pain-Mgmt/PT), referral selections
storage and display (VNG/Ortho/Pain-Mgmt/PT), full referral lifecycle
redesign (upload → auto-close → NEW RESULTS badge → MD views → badge
clears), and MD patient chart all-referrals summary table.

---

## Completed This Session (Session 38)

### MRI/VNG/Ortho/Pain-Mgmt/PT — CPT + ICD-10 from patient_visits ✅ CLOSED

**Root cause:** All referral type creation pages hardcoded `cpt_codes: []`
and `icd10_codes: []` in `createLifecycleRecord()`. `patient_visits` stores
codes as comma-separated `text`, not `text[]` — Supabase insert type mismatch
silently threw and lifecycle record was never created.

**Fix:** Each referral `page.tsx` now fetches `cpt_codes`/`icd10_codes` from
`patient_visits` server-side using `Promise.all`. Normalisation applied at
the server component boundary: `Array.isArray()` check first, then
`.split(',').map(s => s.trim())` for string format, default `[]`. Passed as
`cptCodes`/`icd10Codes` props to each referral component and wired into the
referral `INSERT`.

**Files changed:** `mri/page.tsx`, `mri/MriReferral.tsx`, `vng/page.tsx`,
`ortho/page.tsx`, `pain-mgmt/page.tsx`, `pt/page.tsx`, `VngReferral.tsx`,
`OrthoReferral.tsx`, `PainMgmtReferral.tsx`, `PtReferral.tsx`.

**DME and RX excluded** — different lifecycle insert pattern, separate task.

### Referral Selections Storage + Overview Display ✅ CLOSED

**DB migrations applied:**
- `vng_tests text[]`, `vng_symptoms text[]`
- `ortho_referral_types text[]`, `ortho_regions text[]`
- `pain_mgmt_testing text[]`, `pain_mgmt_treating text[]`
- `pt_goals text[]`, `pt_modalities text[]`, `pt_frequency text`

**Data flow:** Each referral component maps state → label arrays on INSERT.
`listReferrals()` select extended. `ReferralOverviewTab.tsx` displays new
sections: Testing Requested, Symptoms, Referral Requested, Body Part/Region,
Testing For, Treating For, Treatment Goals, Modalities, Frequency.

### Referral Lifecycle Redesign — Auto-Close + NEW RESULTS Badge ✅ CLOSED

**Old flow:** Upload result → `needs_review` → MD reviews → Closed.
**New flow:** Upload result → Auto-close → `results_viewed_at = null` for
flagged types → green "NEW RESULTS" badge on MD patient chart → MD opens
referral → `results_viewed_at = now()` → badge clears on next reload.

**Flagged types** (badge shown): MRI, MRA, CT, ORTHO, PAIN-MGMT.
**All other types**: auto-close, no badge.

**DB migration:** `results_viewed_at timestamptz` added to `referrals`.

**MRI session auto-close:** After session result upload, checks if all
non-cancelled sessions are `outcome = 'completed'`. If so, auto-closes
referral (previously MRI never auto-closed from session upload path).

**Badge dismissal:** `markResultsViewed()` action fires when MD opens
`ReferralSheet`. `ReferralsTabV2.tsx` silently reloads on
`visibilitychange` event to clear badge when user returns to tab.

**Files changed:** `actions.ts` (upload action, new `markResultsViewed`,
select), `types.ts` (removed `awaiting_review` stage), `ReferralSheet.tsx`
(dismissal on open), `ReferralDashboard.tsx` (REVIEW KPI zeroed),
`ReferralsTabV2.tsx` (NEW RESULTS badge, visibilitychange reload).

### Review UI Removal ✅ CLOSED

All MD review workflow artifacts removed:

- `MDClient.tsx`: "Referral Results — Review Required" banner removed.
  Patient card review badge removed. `reviewReferrals` state + query removed.
- `ReferralAppointmentTab.tsx`: "Done" button removed (both imaging and
  non-imaging variants). "Sent for MD Review" label removed (both instances).
  `✔ MD Reviewed` label removed.
- `ReferralsTabV2.tsx`: "Reviewed" badge removed. "Review" column header
  and `TableCell` removed. `✔ Review` button removed. `✔ Reviewed` cell
  removed. `handleReviewSession()` function removed. `reviewingId` state
  removed. `reviewSession` import removed.
- `ReferralDashboard.tsx`: REVIEW KPI count set to 0, card left as shell.
  `awaiting_review` meta entry updated to degrade gracefully.
- `computeReferralDisplayStatus()` in `types.ts`: `awaiting_review` stage
  removed entirely.

### referral_submitted_at — Provider Email Timestamp ✅ CLOSED

**DB migration:** `referral_submitted_at timestamptz` added to `referrals`.

**Set when:** `assignProvider()` in `actions.ts` fires provider notification
email (Resend). `referral_submitted_at = now()` written immediately after
successful email send. Added to `listReferrals()` select.

### MD Patient Chart — All Referrals Summary Table ✅ CLOSED

Summary table rendered above referral cards in `ReferralsTabV2.tsx`.

**Columns:** Type | Status | Provider | Created | Submitted | Appointment | Results

- **Type**: referral label in category color + green "● NEW" badge for
  unviewed flagged results
- **Status**: styled badge matching existing status meta
- **Provider**: provider name
- **Created**: `referral.created_at` — date MD ordered the referral
- **Submitted**: `referral_submitted_at` — date provider email was sent; `—` if not yet sent
- **Appointment**: next non-cancelled session date
- **Results**: `📄 PDF` button if result doc exists, opens signed URL; `—` if none

**Bulk doc fetch:** All result docs loaded on referral list load (not on
card expand) so PDF buttons are immediately available.

**Row click:** Opens referral card in expanded state via `handleCardClick`.

### MRI/MRA/CT Incomplete Parts Warning ✅ CLOSED

`ReferralsTabV2.tsx`: red warning banner above summary table when any open
MRI, MRA, or CT referral has `body_parts` not yet assigned to a session.
Warning includes all unscheduled part names. Previously only showed for MRI.

---

## Open Items, Priority Order

1. **Lock icon removal from Closed status** (`types.ts` icon field).
   Python patch anchor failed Sessions 33–36 due to emoji Unicode encoding
   mismatch. Not attempted this session. Fix: pull `types.ts` fresh, inspect
   exact bytes around the icon field, use Python byte-level replace.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientForm.tsx` `email` field
   must be made required. Patient confirmation emails dead until fixed.

4. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only.

5. **Render memory limit — cosmos-api.** Render Starter (512MB) crashes
   during PDF generation under load. Pre-go-live blocker. Upgrade to
   Standard plan ($25/mo, 2GB RAM).

6. **Add FK: `referral_timeline.actor_user_id → user_profiles.id`.**
   Currently no FK — timeline join done client-side as workaround.

7. **DME and RX referral codes.** `DmeReferral.tsx` and `RxReferral.tsx`
   have a different lifecycle insert pattern and were excluded from the
   Session 38 codes refactor. Handle separately.

8. **Psych referral type.** No `psych/` route exists. New build required.

9. **Body parts missing on pre-Session-36 rescheduled sessions.** Data
   issue only — new reschedules are gated correctly.

10. **Doctor mailing address data.** All current records are test data.
    Real provider data entered at go-live onboarding.

11. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

12. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — all unsigned.
    Pre-go-live blocker.

13. **SPF/DKIM for cosmosmt.com.** Not yet configured. Pre-go-live blocker.

---

## DB Schema Changes This Session

All applied via Supabase SQL editor (no `.sql` migration files — consistent
with Sessions 20+):

```sql
-- Referral selections
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS vng_tests text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS vng_symptoms text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS ortho_referral_types text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS ortho_regions text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS pain_mgmt_testing text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS pain_mgmt_treating text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS pt_goals text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS pt_modalities text[];
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS pt_frequency text;

-- Lifecycle
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS results_viewed_at timestamptz;
ALTER TABLE referrals ADD COLUMN IF NOT EXISTS referral_submitted_at timestamptz;
```

---

## File Confidence

All files below were modified this session and are confirmed on disk as of
last deploy:

| File | Changes |
|---|---|
| `app/referrals/actions.ts` | Upload auto-close, MRI session auto-close, `markResultsViewed`, `referral_submitted_at` on email, select updates |
| `app/referrals/types.ts` | Removed `awaiting_review` from `computeReferralDisplayStatus`, added `results_viewed_at` to `ReferralSummary` |
| `app/referrals/ReferralDashboard.tsx` | REVIEW KPI zeroed, NEW RESULTS badge removed |
| `app/referrals/ReferralSheet.tsx` | `markResultsViewed` on open |
| `app/referrals/components/ReferralAppointmentTab.tsx` | Done/Sent for MD Review/MD Reviewed labels removed |
| `app/referrals/components/ReferralOverviewTab.tsx` | VNG/Ortho/Pain-Mgmt/PT/Frequency sections added |
| `app/md/MDClient.tsx` | Review banner and patient badge removed |
| `app/md-v2/[patientId]/ReferralsTabV2.tsx` | Summary table, NEW RESULTS badge, bulk doc fetch, MRI/MRA/CT warning, visibilitychange reload, review UI removed |
| `app/md/[patientId]/mri/page.tsx` | Server-side codes fetch + normalisation |
| `app/md/[patientId]/mri/MriReferral.tsx` | cptCodes/icd10Codes props |
| `app/md/[patientId]/vng/page.tsx` | Full rewrite with codes fetch |
| `app/md/[patientId]/ortho/page.tsx` | Full rewrite with codes fetch |
| `app/md/[patientId]/pain-mgmt/page.tsx` | Full rewrite with codes fetch |
| `app/md/[patientId]/pt/page.tsx` | Full rewrite with codes fetch |
| `app/md/[patientId]/vng/VngReferral.tsx` | Props, insert: vng_tests, vng_symptoms |
| `app/md/[patientId]/ortho/OrthoReferral.tsx` | Props, insert: ortho_referral_types, ortho_regions |
| `app/md/[patientId]/pain-mgmt/PainMgmtReferral.tsx` | Props, insert: pain_mgmt_testing, pain_mgmt_treating |
| `app/md/[patientId]/pt/PtReferral.tsx` | Props, insert: pt_goals, pt_modalities, pt_frequency |

---

## Known Architecture Gaps

- `getReferralProviders()` return type is still `any[]`.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — relies on
  sessionStorage override; hard refresh without re-login can expose wrong role.
- `referral_notifications` table schema mismatch — designed for internal
  user notifications, not outbound Resend emails.
- ReferralSheet header badge reads raw `referrals.status` — shows
  `New`/`Scheduled` instead of computed status. Cosmetic gap only.
- Body parts missing on sessions rescheduled before Session 36 — data issue.
- Lock icon emoji in `types.ts` cannot be patched via Python string anchors.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- `(referral as any).cpt_codes` cast in `ReferralOverviewTab` — new type
  columns (`vng_tests`, `ortho_regions`, etc.) also use `as any` cast.
  Add all new columns to `ReferralSummary` in `types.ts`.
- Render Starter (512MB) insufficient for PDF generation under load.
- DME and RX referral pages still hardcode `cpt_codes: []`/`icd10_codes: []`.

---

## Technical Lessons This Session

- `patient_visits` stores `cpt_codes`/`icd10_codes` as comma-separated
  `text`, not `text[]`. Inserting a plain string into a `text[]` column
  silently fails in a `try/catch` — no visible error, record not created.
  Always normalise at the server component boundary before passing as props.
- Silent failures in `createLifecycleRecord()` are hard to debug because
  the referral PDF generates successfully — the button flips to "View" —
  but the `referrals` row is never inserted. Check DB directly when the
  referral doesn't appear on the dashboard.
- `resultDocs` populated lazily (on card expand) means the summary table
  PDF column is always empty on first render. Bulk-fetch all docs on load
  using `.in('referral_id', allIds)` to populate immediately.
- `visibilitychange` event is the correct hook for refreshing data after
  the user navigates away (to ReferralSheet) and returns — avoids polling
  and works reliably on mobile Chrome.
- When removing a JSX expression like `{condition && <Component />}`, Python
  `str.replace` may leave an empty `{condition && }` which fails TypeScript.
  Always verify with `npx tsc --noEmit` before committing.

---

## Roadmap Checklist

### Stage 1 — Core Platform ✅ COMPLETE
- [x] All items from Sessions 1–37

### Stage 2 — Referral Management
- [x] MRI referral lifecycle (Sessions 22–32)
- [x] MRI session splitting (Session 31)
- [x] Per-session result upload (Session 32)
- [x] ANS referral module end-to-end (Session 37)
- [x] VNG/Ortho/Pain-Mgmt/PT codes from patient_visits (Session 38)
- [x] VNG/Ortho/Pain-Mgmt/PT selections stored + displayed (Session 38)
- [x] Auto-close on result upload — all types (Session 38)
- [x] NEW RESULTS badge — MD patient chart (Session 38)
- [x] results_viewed_at dismissal (Session 38)
- [x] referral_submitted_at — set on provider email (Session 38)
- [x] MD all-referrals summary table (Session 38)
- [x] MRI/MRA/CT incomplete parts warning (Session 38)
- [ ] DME and RX codes from patient_visits
- [ ] Psych referral type (new build)
- [ ] Lock icon removal from Closed status (anchor mismatch — deferred x5)
- [ ] ReferralSheet header badge — raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientForm.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id
- [ ] Sidebar rollout — FD, MD, Biller dashboards

### Stage 3 — Billing
- [ ] Billing packet generation improvements
- [ ] Attorney email workflow

### Stage 4 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] PDF migration to client-side @react-pdf/renderer (Phase 2)

### Stage 5 — Scale
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] Data retention and deletion policy
- [ ] Patient data export capability
