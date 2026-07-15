# Cosmos Medical Technologies — HANDOVER (July 14, 2026, Session 42)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed and live
on `cosmos-dashboard-nu.vercel.app`. Session 42 completed a major capability
expansion across four areas: FD Dashboard V2 Documents and Visits tabs
redesigned, Referral Dashboard KPI and column improvements, and a new
FD-only `/reports` page with four report types.

---

## Completed This Session (Session 42)

### FD Dashboard V2 — Visits Tab: Tap-to-Expand + Document Drawer ✅ CLOSED

Visit rows now expand on tap (chevron indicator). Per-visit document drawer
shows PCE, ICD-10, and referral PDFs via signed URL from `patient-forms`
bucket. CPT code chips changed to cyan. Billed rows simplified (no expand —
nothing to show). Document drawer subsequently removed from Visits tab per
product decision — documents moved to Documents tab exclusively.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Documents Tab Full Rebuild ✅ CLOSED

Documents tab expanded from NF-2/AOB only to a full document hub:
- **No-Fault Forms** — NF-2 and AOB (unchanged)
- **MD Records** — single collapsible card; one row per visit showing PCE
  and ICD-10 pill buttons with visit date in cyan; per-visit checkbox
- **Referral Results** — one collapsible card per referral type (MRI, CT,
  Pain Mgmt, etc.); per-result row with green "Result N" label, cyan
  received date, View button, and cyan checkbox
- **Select All** — above MD Records section, selects all MD forms + all
  referral results
- **Action bar** — appears when any items selected: "Download ZIP" and
  "Email Attorney" buttons
- Download: calls `/generate-records-zip` on cosmos-api, returns ZIP binary
- Email: pre-fills `patients.attorney_email`, editable before send, calls
  `/email-records` on cosmos-api via Resend
- Both endpoints support dual-bucket routing: `patient-forms` for MD records,
  `referral-documents` for referral results

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### cosmos-api — Records ZIP and Email Endpoints ✅ CLOSED

Two new endpoints added to `main.py`:
- `POST /generate-records-zip` — accepts `{ patient_id, files: [{path, bucket}] }`,
  downloads from correct Supabase Storage bucket per file, zips in memory,
  returns binary ZIP. Filename: `{patient_id}_{doa}_records.zip`
- `POST /email-records` — same file list + `recipient_email` + `patient_name`,
  builds ZIP, sends as Resend attachment. From: `records@cosmosmt.com`

Both endpoints: JWT-verified, skip failed files rather than aborting,
log skipped files to console.

**Files:** `cosmos-api/main.py`

### FD Dashboard V2 — Reports Link in Sidebar ✅ CLOSED

`BarChart2` icon added to imports. Reports nav item added to `NAV_ITEMS`
array pointing to `/reports`.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### Referral Dashboard — Awaiting KPI ✅ CLOSED

New **Awaiting** KPI card (orange, `#fb923c`) added between Overdue and
Closed/Mo. Counts sessions where appointment date has passed and no result
uploaded — session-level count, same expansion pattern as Upcoming.

**Overdue redefined:** Now fires on new referrals with no appointment
scheduled for 2+ days (FD inaction, referral-level count). Previously fired
on past-appointment sessions — that is now Awaiting.

`computeReferralDisplayStatus()` updated in `types.ts`: new `'awaiting'`
status added to `ComputedReferralStatus` type. No-appointment path checks
`created_at` age; 2+ days → `'overdue'`. Past pending session → `'awaiting'`
(was `'overdue'`).

`getReferralMetrics()` updated in `actions.ts`: fetches `created_at`, passes
it to `computeReferralDisplayStatus()`. Overdue counts referrals; awaiting
counts sessions.

`ReferralDashboard.tsx`: `COMPUTED_STATUS_META` updated with awaiting entry,
`isAwaiting()` helper added, Awaiting metric card added, Overdue filter now
shows unscheduled 2+ day referrals, Awaiting filter expands per-session rows,
table row background tints orange for awaiting rows, `⏳ AWAITING` inline
badge added.

**Files:** `app/referrals/types.ts`, `app/referrals/actions.ts`,
`app/referrals/ReferralDashboard.tsx`

### Referral Dashboard — Results Received Column ✅ CLOSED

`listReferrals()` now joins `referral_documents ( id, created_at, doc_type,
deleted_at )`. `_results_received_at` computed as earliest result-type doc
`created_at` (deleted docs excluded). Green date shown in new "Results"
column between Appt and Date. `—` when no result exists.

**Files:** `app/referrals/actions.ts`, `app/referrals/ReferralDashboard.tsx`

### Referral Dashboard — Column Rename and Reorder ✅ CLOSED

"Date" column renamed to "Ref. Created" and moved immediately after Status.
Date format updated to `Mon DD, YY` (consistent with Results column).
Column order: Patient → Status → Ref. Created → Appt → Results.

**Files:** `app/referrals/ReferralDashboard.tsx`

### FD Reports Page ✅ CLOSED

New route `/reports` — FD-only, linked from Dashboard V2 sidebar.
Server component `page.tsx` fetches all referrals with appointments,
documents, type, and provider. Client component `ReportsClient.tsx` renders
four tabs:

**Monthly Summary** — month picker (last 12 months), table by referral type:
Opened (by `created_at`), Closed (by `updated_at` when `status=closed`),
Results Received (by first result doc date). Totals row. CSV export.

**Awaiting Results** — open referrals where appointment passed and no result
uploaded; sorted oldest appointment first. Days Waiting column turns red
after 14 days. CSV export.

**Provider Performance** — per provider: Assigned count, Results Received,
Result Rate % (green ≥80%, yellow ≥50%, red <50%), Avg Turnaround from
appointment to result received in days (green ≤7d, yellow ≤14d, red >14d,
N/A when no results). Unassigned referrals show "Unassigned". CSV export.

**Open Aging** — four bucket cards (0–7 / 8–14 / 15–30 / 30+ days), color-
coded green → yellow → orange → red. Tapping a card filters the table.
Age column color-coded per bucket. "Show all" resets. CSV export.

**Files:** `app/reports/page.tsx` (new), `app/reports/ReportsClient.tsx` (new)

---

## Open Items, Priority Order

1. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

2. **Patient email required at intake.** `PatientForm.tsx` `email` field
   must be made required. Patient confirmation emails dead until fixed.

3. **Render memory limit — cosmos-api.** Render Starter (512MB) crashes
   during PDF generation under load. Pre-go-live blocker. Upgrade to
   Standard plan ($25/mo, 2GB RAM).

4. **Cleanup leftover route folders.** Delete `app/md-v2/[patientId]/ref/`
   and `app/md-v2/[patientId]/referral/` — both abandoned, broken content.
   Use `git rm -rf` via GitHub web UI or fresh clone.

5. **Dashboard V2 — Notes tab persistence.** Notes are session-only.
   Requires a new `patient_notes` table or column. Roadmap item.

6. **Dashboard V2 — Stub KPIs.** Patients Waiting, Insurance Verification,
   Tasks Due Today require new DB tables/columns. Future work.

7. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only.

8. **`/referrals/page.tsx` `userRole` hardcoded to `"md"`.** Relies on
   sessionStorage override. Hard refresh without re-login exposes wrong role.

9. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — all unsigned.
   Pre-go-live blocker.

10. **SPF/DKIM for cosmosmt.com.** Not yet configured. Pre-go-live blocker.

11. **DME and RX referral codes.** Excluded from Session 38 codes refactor.

12. **Psych referral type.** No `psych/` route exists. New build required.

13. **Realtime — referrals and appointments.** Current subscription covers
    `patients`, `patient_visits`, `patient_forms` only. Referral status
    changes and new appointments won't push live. Add before go-live.

14. **PCE guard — minimum pce_data threshold.** Current guard fires on any
    non-empty `pce_data`. A more robust guard would require minimum fields
    (accident type + at least one complaint). Product decision needed.

15. **Provider Performance avg turnaround — always N/A.** Turnaround
    calculation finds appointment date but result may be zero or negative
    when appointments are marked cancelled. Needs investigation against
    real closed referral data.

---

## DB Schema Changes This Session

No new migrations. No publication changes.

---

## File Confidence

All files below were modified or created this session and confirmed on disk
as of last deploy:

| File | Changes |
|---|---|
| `app/dashboard-v2/FDDashboardV2.tsx` | BarChart2 import, Reports nav item added |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | Visits tab simplified (no doc drawer), Documents tab full rebuild (MD Records + Referral Results collapsible cards, checkboxes, Select All, Download ZIP, Email Attorney) |
| `app/referrals/types.ts` | `'awaiting'` added to `ComputedReferralStatus`; `computeReferralDisplayStatus()` split overdue/awaiting logic, accepts `created_at` |
| `app/referrals/actions.ts` | `getReferralMetrics()` fetches `created_at`, counts overdue/awaiting separately; `listReferrals()` joins `referral_documents`, computes `_results_received_at` |
| `app/referrals/ReferralDashboard.tsx` | Awaiting KPI card, COMPUTED_STATUS_META updated, Results column, Ref. Created column renamed/reordered, awaiting filter, row tints, inline badge |
| `app/reports/page.tsx` | New file — server component, fetches referral data |
| `app/reports/ReportsClient.tsx` | New file — four-tab reports client component |
| `cosmos-api/main.py` | `/generate-records-zip` and `/email-records` endpoints added |

---

## Known Architecture Gaps

- `getReferralProviders()` return type is still `any[]`.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — sessionStorage override only.
- ReferralSheet header badge reads raw `referrals.status` — cosmetic gap.
- Body parts missing on sessions rescheduled before Session 36 — data issue.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- `(referral as any).cpt_codes` cast in `ReferralOverviewTab` — new type columns use `as any`.
- Render Starter (512MB) insufficient for PDF generation under load.
- DME and RX referral pages still hardcode `cpt_codes: []`/`icd10_codes: []`.
- `app/md-v2/[patientId]/ref/` and `app/md-v2/[patientId]/referral/` abandoned folders to delete.
- Android/Termux filesystem is case-insensitive — git cannot track folder renames with bracket characters.
- `dashboard-v2` notes are session-only — not persisted to DB.
- `referral_appointments.needs_review` and `reviewed_at` (migrations 031–032) vestigial — no code writes to them.
- `patients.patient_signature_url` unreliable — not used by existing FD dashboard; removed from doc status logic in V2.
- Realtime subscription covers `patients`, `patient_visits`, `patient_forms` only — `referrals` and `appointments` not yet subscribed.
- PCE auto-generation guard fires on any non-empty `pce_data` — minimum field threshold not enforced.
- `hasPceLocal` variable remains in `PreflightModal` but is no longer used in `allOk` — dead variable, harmless, clean up next touch.
- Provider Performance avg turnaround shows N/A for all providers — turnaround calculation may not be finding valid appointment/result pairs on closed referrals; needs investigation with real data.
- `/generate-records-zip` and `/email-records` use `records@cosmosmt.com` as sender — verify this address is configured in Resend before testing email flow end-to-end.

---

## Technical Lessons This Session

- TypeScript `Record<string, string>` state must be updated to `Record<string, { path: string; bucket: string }>` when storing structured objects — TS2322 caught at compile time, not runtime.
- Chrome on Android does not overwrite same-named downloads — always check `ls -lt` before `cp` when re-downloading a file with the same name (SYSTEM_PROMPT.md §3 standing rule, reinforced).
- Next.js route files must be named exactly `page.tsx` — `reports-page.tsx` does not register as a route; always use the deploy command pattern `cp downloads/X.tsx app/route/page.tsx` not `cp ... page.tsx` blindly.
- `computeReferralDisplayStatus()` splitting overdue (FD inaction) from awaiting (provider inaction) required passing `created_at` to the function — always thread new fields through the full call chain (type signature → caller → consumer).
- Supabase PostgREST nested select on `referral_documents` returns an array even when no results — always guard with `Array.isArray()` before filtering.

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
- [x] Referral dashboard patient pre-filter via ?patient= (Session 40)
- [x] Awaiting KPI — past appointment, no result (Session 42)
- [x] Overdue KPI — redefined as unscheduled 2+ days (Session 42)
- [x] Results Received column in referral dashboard (Session 42)
- [x] Ref. Created column renamed and reordered (Session 42)
- [ ] DME and RX codes from patient_visits
- [ ] Psych referral type (new build)
- [ ] ReferralSheet header badge — raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientForm.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id
- [ ] Cleanup abandoned route folders (ref/, referral/)

### Stage 3 — Front Desk Dashboard V2
- [x] Shell, header, sidebar, KPI cards (Session 40)
- [x] TanStack work queue — sorting, pagination, search, CSV export, column visibility (Session 40)
- [x] Patient detail sheet — 8 tabs, real data (Session 40)
- [x] Referrals tab — real FK join data, links to Referral Dashboard (Session 40)
- [x] Oxanium font, mobile search (Session 40)
- [x] Superadmin picker integration (Session 40)
- [x] Referrals tab — full ReferralsTabV2-style table, per-session rows, Results PDF (Session 41)
- [x] Documents tab — NF-2 and AOB only, signature capture (Session 41)
- [x] Visits tab — billing workflow, preflight modal, checkbox selection, submit to billing (Session 41)
- [x] Realtime subscriptions — patients, patient_visits, patient_forms (Session 41)
- [x] Search bar moved below KPI cards (Session 41)
- [x] KPI cards Oxanium font (Session 41)
- [x] Documents tab — MD Records + Referral Results collapsible cards (Session 42)
- [x] Documents tab — Select All, Download ZIP, Email Attorney (Session 42)
- [x] Visits tab — CPT chips cyan, simplified (Session 42)
- [x] Reports link in sidebar (Session 42)
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables

### Stage 3b — FD Reports
- [x] /reports page — server component + client component (Session 42)
- [x] Monthly Summary tab — by type: opened/closed/results (Session 42)
- [x] Awaiting Results tab — oldest first, days waiting (Session 42)
- [x] Provider Performance tab — assigned/results/rate/turnaround (Session 42)
- [x] Open Aging tab — 4 bucket cards, filterable table (Session 42)
- [ ] Provider Performance turnaround — investigate N/A issue with real data

### Stage 4 — Billing
- [ ] Billing packet generation improvements
- [ ] Attorney email workflow

### Stage 5 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] PDF migration to client-side @react-pdf/renderer (Phase 2, long-term)

### Stage 6 — Scale
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] Data retention and deletion policy
- [ ] Patient data export capability
