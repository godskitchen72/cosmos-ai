# Cosmos Medical Technologies — HANDOVER (July 13, 2026, Session 39)

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
`cosmos-dashboard-nu.vercel.app`. Session 39 completed the referral
lifecycle simplification (Done/Awaiting/Review workflow removed),
MRI/MRA/CT per-session row expansion in both dashboards, MRA body parts
fix, auto-close body_parts select bug fix, MD referrals table overhaul
(sort, body parts column, card header warning, no row tap), and removal
of individual referral cards from MD patient chart.

---

## Completed This Session (Session 39)

### Done/Awaiting/Review Workflow — Removed ✅ CLOSED

**Old flow:** Upload result → FD taps Done → sent_review → MD review queue → Closed.
**New flow:** Upload result → Auto-close (when all parts assigned + all sessions completed).

**Removed:**
- AWAITING and REVIEW KPI cards from `ReferralDashboard.tsx`
- Done button from `ReferralAppointmentTab.tsx` (imaging + non-imaging)
- `markSessionNeedsReview` import and handler from `ReferralSheet.tsx`
- `donningSessionId` state and `handleDoneSession` from `ReferralSheet.tsx`
- `pendingDoneSessions` memo and `handleDoneFromBanner` from `ReferralDashboard.tsx`
- `done_action` column from dashboard table
- `metricFilter === 'review'` and `metricFilter === 'awaiting'` blocks
- `needs_review`/`isReviewed` gates on Delete button — Delete now always visible on uploaded sessions
- Review-tinted orange border/bg on session cards

**Delete button:** Now always shown for uploaded sessions — no longer gated on review state.

**Files changed:** `ReferralDashboard.tsx`, `ReferralSheet.tsx`, `ReferralAppointmentTab.tsx`

### MRA Body Parts Fix ✅ CLOSED

**Bug:** `MriReferral.tsx` `createLifecycleRecord()` had no `MRA` branch in
`body_parts` IIFE — fell through to `mriOnly` path which reads `MRI_SPINE`
and extremities only. MRA studies never saved to `referrals.body_parts`.

**Fix:** Added `if (modality === 'MRA')` branch that reads `MRA_STUDIES` labels.

**File changed:** `app/md/[patientId]/mri/MriReferral.tsx`

**Note:** Existing MRA referrals created before fix have `body_parts = null`.
Regenerate those referrals to get body parts tracked.

### Auto-Close body_parts Select Bug ✅ CLOSED

**Bug:** `uploadReferralResult()` in `actions.ts` queried appointments with
`.select('id, outcome')` — omitted `body_parts`. `allPartsAssigned` check
always returned false (undefined body_parts on appointment rows). Auto-close
never fired for imaging referrals regardless of completion state.

**Fix:** Changed select to `.select('id, outcome, body_parts')`.

**File changed:** `app/referrals/actions.ts`

### MRI/MRA/CT Auto-Close — All Parts Must Be Assigned ✅ CLOSED

**Bug:** Auto-close fired when all existing sessions were completed, even if
unscheduled body parts remained (FD schedules sessions on different dates).

**Fix:** Before `allComplete` check, fetch `referrals.body_parts` and verify
every part appears in at least one appointment's `body_parts`. Only then close.

**File changed:** `app/referrals/actions.ts`

### Referral Dashboard — MRI/MRA/CT Per-Appointment Row Expansion ✅ CLOSED

MRI/MRA/CT referrals now show one row per appointment in the Full Referral
Dashboard list (default view, no metric filter). Non-imaging types remain one
row per referral. Existing metric filter expansions (upcoming/overdue/awaiting/
review) unchanged.

**File changed:** `app/referrals/ReferralDashboard.tsx`

### MD Patient Chart — ALL REFERRALS Table Overhaul ✅ CLOSED

**Changes to `ReferralsTabV2.tsx`:**

1. **MRI/MRA/CT per-session expansion** — imaging referrals expand to one row
   per appointment in the summary table. `filtered` IIFE handles expansion.
   Summary table iterates `filtered` (was iterating `referrals` directly — bug).

2. **Per-session status for imaging rows** — Upcoming / Overdue / Uploaded
   computed from session appointment date and result presence. Closed referrals
   always show Closed regardless of session state.

3. **Card header warning** — per-type red lines inside the ALL REFERRALS table
   card, above column headers: `⚠ MRI  L. Shoulder, L. Elbow not yet scheduled`.
   One line per imaging type with unscheduled parts. Replaces old standalone
   red banner above the table.

4. **Tap-to-sort** — Type, Status, Provider, Created, Appointment columns
   sortable. Active column header turns white with ▲/▼ arrow. Default sort:
   Created desc.

5. **Body Parts column** — added after Type column. Body part chips displayed
   there, not in the Type cell. Type cell shows label only.

6. **Individual referral cards removed** — the expandable card list below the
   summary table is gone. Summary table is the sole referral display.

7. **NEW badge removed** — `● NEW` badge removed from summary table rows.
   `results_viewed_at` badge logic removed (badge was never clearing correctly
   due to navigation pattern).

8. **Row tap disabled** — rows are not tappable. PDF button in Results column
   is the sole interactive element.

9. **`expandedId` / `keepExpandedId` / `autoExpandId` fully removed** — all
   expand state, auto-expand logic, and `fetchResultDocs` per-referral loading
   removed. Bulk doc fetch on load retained.

**File changed:** `app/md-v2/[patientId]/ReferralsTabV2.tsx`

### MD Referral Detail Page — Abandoned ✅ CLOSED (not needed)

Attempted to build `app/md-v2/[patientId]/ref/[rid]/page.tsx` to give MD
access to ReferralSheet. Blocked by Android/Termux case-insensitive filesystem
preventing git from tracking bracket-named folders correctly. Abandoned after
determining MD only needs the summary table + PDF button — no referral detail
view required for MD workflow.

**Leftover:** `app/md-v2/[patientId]/ref/` and `app/md-v2/[patientId]/referral/`
folders exist in repo with empty or broken content. Safe to delete next session.

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

4. **Render memory limit — cosmos-api.** Render Starter (512MB) crashes
   during PDF generation under load. Pre-go-live blocker. Upgrade to
   Standard plan ($25/mo, 2GB RAM).

5. **Cleanup leftover route folders.** Delete `app/md-v2/[patientId]/ref/`
   and `app/md-v2/[patientId]/referral/` — both are abandoned and contain
   broken/empty content. Use `git rm -rf` via GitHub web UI or a fresh clone.

6. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only.

7. **Add FK: `referral_timeline.actor_user_id → user_profiles.id`.**
   Currently no FK — timeline join done client-side as workaround.

8. **DME and RX referral codes.** `DmeReferral.tsx` and `RxReferral.tsx`
   have a different lifecycle insert pattern and were excluded from the
   Session 38 codes refactor. Handle separately.

9. **Psych referral type.** No `psych/` route exists. New build required.

10. **`patients.doctor_id` NOT NULL.** Deferred to pre-production.

11. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — all unsigned.
    Pre-go-live blocker.

12. **SPF/DKIM for cosmosmt.com.** Not yet configured. Pre-go-live blocker.

---

## DB Schema Changes This Session

No new migrations this session. All schema from Session 38 remains current.

---

## File Confidence

All files below were modified this session and confirmed on disk as of
last deploy:

| File | Changes |
|---|---|
| `app/referrals/actions.ts` | Auto-close: `body_parts` added to select, all-parts-assigned check added, session-scope auto-close fixed |
| `app/referrals/ReferralDashboard.tsx` | AWAITING/REVIEW KPI cards removed, Done column removed, pendingDoneSessions removed, awaiting/review metric filter blocks removed, MRI/MRA/CT per-appointment expansion added |
| `app/referrals/ReferralSheet.tsx` | `markSessionNeedsReview` import removed, `donningSessionId` state removed, `handleDoneSession` removed, toast message updated, `onDoneSession` prop removed |
| `app/referrals/components/ReferralAppointmentTab.tsx` | Done button removed (imaging + non-imaging), `donningSessionId`/`onDoneSession` props removed, `needsReview`/`isReviewed` variables removed, review-gated delete removed, review border/bg removed |
| `app/md/[patientId]/mri/MriReferral.tsx` | MRA body_parts branch added in `createLifecycleRecord()` |
| `app/md-v2/[patientId]/ReferralsTabV2.tsx` | Full overhaul — see Completed section above |

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
- `app/md-v2/[patientId]/ref/` and `app/md-v2/[patientId]/referral/` are
  abandoned folders that should be deleted.
- Android/Termux filesystem is case-insensitive — git cannot track folder
  renames involving bracket characters (`[param]`). Always create new route
  folders via `cat >` or heredoc, never `mv`. If casing is wrong, use GitHub
  web UI to delete and recreate.

---

## Technical Lessons This Session

- Android/Termux uses a case-insensitive filesystem. Git tracks `[referralId]`
  and `[referraLId]` as the same path — renames are invisible to git. Never
  attempt folder renames with bracket characters on Termux. Use GitHub web UI
  for any bracket-named folder operations, or avoid the problem by choosing
  route param names with no ambiguous characters (`[rid]` not `[referralId]`).
- GitHub web UI also rejects bracket characters in file paths via the web
  editor ("malformed path component"). The only reliable way to create
  Next.js dynamic route folders from Termux is to write files directly with
  `cat >` or heredoc in the correct directory from the start.
- `git add -f` and `git update-index --add --cacheinfo` both silently fail
  on case-insensitive filesystems when the index already has a conflicting
  entry — `git status` shows "nothing to commit" even though the new files
  are not tracked.
- When a patch script assertion fails with "Expected 1, got 0", always pull
  the live file fresh before writing the patch — Chrome often serves a cached
  stale download. Use a unique filename (`_live2`, `_live3`) on each pull to
  force a fresh download.
- `sed` with complex replacement strings fails silently on Android — use
  Python `str.replace` patches instead.
- Auto-close for imaging referrals requires both: (a) all body parts assigned
  to sessions AND (b) all sessions completed. Either condition alone is
  insufficient.

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
- [x] Done/Awaiting/Review workflow removed (Session 39)
- [x] MRA body_parts fix (Session 39)
- [x] Auto-close body_parts select bug fixed (Session 39)
- [x] MRI/MRA/CT all-parts-assigned gate for auto-close (Session 39)
- [x] Referral dashboard MRI/MRA/CT per-appointment expansion (Session 39)
- [x] MD referrals table — per-session expansion, sort, body parts column (Session 39)
- [ ] DME and RX codes from patient_visits
- [ ] Psych referral type (new build)
- [ ] Lock icon removal from Closed status (anchor mismatch — deferred x5)
- [ ] ReferralSheet header badge — raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientForm.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id
- [ ] Sidebar rollout — FD, MD, Biller dashboards
- [ ] Cleanup abandoned route folders (ref/, referral/)

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
