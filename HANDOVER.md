# Cosmos Medical Technologies — HANDOVER (July 14, 2026, Session 41)

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
`cosmos-dashboard-nu.vercel.app`. Session 41 completed a major FD Dashboard
V2 capability expansion — Referrals tab rebuilt to match MD view exactly,
Documents tab rebuilt (NF-2/AOB only), Visits tab rebuilt as full billing
workflow surface, Realtime subscriptions added, and PCE auto-generation
added to MD visit save.

---

## Completed This Session (Session 41)

### Item 1 — Lock Icon (Closed status) ✅ CLOSED AS NON-ISSUE

`REFERRAL_STATUS_META` `icon` field is never rendered by any component —
`StatusBadge` only outputs `m.label`. The 🔒 is invisible to users.
No code change needed. Removed from open items permanently.

### Item 6 — Dashboard V2 Appointments Tab Shows 0 ✅ CLOSED AS NON-ISSUE

`appointments` table is empty — all test data wiped in Session 36, no real
bookings yet. RLS correct, filter logic correct, column name correct.
Will self-resolve when appointments are booked.

### FD Dashboard V2 — Referrals Tab Full Rebuild ✅ CLOSED

Replaced card-based referrals tab with full client-side fetch table matching
`ReferralsTabV2` exactly. Per-session rows for imaging referrals, 8 columns
(Type, Body Parts, Status, Provider, Created, Submitted, Appointment, Results),
Results PDF button opens signed URL from `referral-documents` bucket,
abbreviated body parts (`abbrevBp`), status filter strip (All/Open/Closed),
"Full Dashboard →" pre-populates patient name in referral dashboard search.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Documents Tab Simplified ✅ CLOSED

Documents tab stripped to NF-2 and AOB only — signature capture, generate,
view, regenerate, mail confirmation with receipt upload. PCE, NF-3 preflight,
visit selector, and submit to billing moved out. Documents is now purely a
no-fault form generation surface.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Visits Tab Full Billing Workflow ✅ CLOSED

Visits tab rebuilt as the primary FD billing workflow surface:
- Lazy client-side fetch: `patient_visits` (with `cpt_codes`), `visit_line_items`,
  `patient_forms` (PCE check), full patient row
- Pending visits: date, CPT code chips, billed amount, readiness indicator
- Red background = locked (PCE missing / NF-3 preflight not passed / AOB missing / no line items)
- Green background = ready for billing
- 🔒 tap → NF-3 Preflight modal for that specific visit
- Preflight modal: 8-field checklist, PCE removed from gate (MD responsibility),
  "Confirm Ready" writes `nf3_preflight_passed = true`
- Custom cyan checkbox on ready visits — tap to select
- "Submit X Visits to Billing" button appears when ready visits selected
- Batch submit: `submitted_to_billing_at = now()` on all selected visit IDs
- Submitted visits shown in separate "Submitted to Billing" section below

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Dashboard V2 — Realtime Subscriptions ✅ CLOSED

`FDDashboardV2` converted from static server props to live local state.
Supabase Realtime subscription on `patients`, `patient_visits`, `patient_forms`
— UPDATE and INSERT events patch local arrays instantly. KPI counts recompute
automatically. Sheet-level `selectedPatient` also patched on UPDATE so
Timeline and Overview reflect live data without sheet close/reopen.

**DB change:** `ALTER PUBLICATION supabase_realtime ADD TABLE patients, patient_visits, patient_forms` — confirmed via `pg_publication_tables`.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — Search Bar Moved Below KPI Cards ✅ CLOSED

Search removed from sticky header (both desktop and mobile). Single search
bar placed between KPI cards and Work Queue in the body. Always visible,
consistent position on all screen sizes.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — KPI Cards Oxanium Font ✅ CLOSED

`<button>` wrapper on KPI cards now has `fontFamily: oxanium.style.fontFamily`
explicitly set — preflight gap rule, bare buttons don't inherit.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — Quick Actions Updated ✅ CLOSED

"Upload" and "NF-2" quick action buttons now navigate to Documents tab.
"Documents" quick action added. "NF-2" button jumps directly to Documents tab.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### PCE Auto-Generation on Visit Save ✅ CLOSED

`VisitTab.tsx` `handleSave` now calls `generatePcePdf(visitId)` after
`generateIcd10Pdf` on both save paths (new visit INSERT and existing visit
UPDATE). Guard: only fires when `Object.keys(pceData).length > 0` — empty
PCE wizard skips generation silently. Errors logged to console, never block save.

**Product decision:** PCE is MD-generated (MD fills wizard, auto-generates on
save). FD verifies existence via visit row indicator. PCE removed from NF-3
preflight check — it is a document check, not a data completeness check.

**Files:** `app/md/[patientId]/components/VisitTab.tsx`

### Role Clarification — PCE and NF-3 ✅ RESOLVED

- **NF-3** — generated by Biller dashboard. FD runs preflight check only.
- **PCE** — generated automatically on MD visit save (this session). FD verifies existence.
- **NF-2, AOB** — FD-generated (Documents tab).
- **Referral PDFs** — MD-discretionary, Save→View pattern, unchanged.

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

---

## DB Schema Changes This Session

No new migrations. One publication change:
- `supabase_realtime` publication now includes `patients`, `patient_visits`,
  `patient_forms` — added via `ALTER PUBLICATION supabase_realtime ADD TABLE`.

---

## File Confidence

All files below were modified this session and confirmed on disk as of
last deploy:

| File | Changes |
|---|---|
| `app/dashboard-v2/FDDashboardV2.tsx` | Local state for patients/visits, Realtime subscription, search moved below KPIs, KPI card Oxanium font |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | Full rebuild — Referrals tab (client fetch, ReferralsTabV2-style table), Visits tab (billing workflow, preflight modal, checkbox selection, submit to billing), Documents tab (NF-2/AOB only), custom cyan checkbox, quick actions updated |
| `app/md/[patientId]/components/VisitTab.tsx` | `generatePcePdf()` function added, called from `handleSave` on both save paths |

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

---

## Technical Lessons This Session

- `REFERRAL_STATUS_META` `icon` field is defined in `types.ts` but never rendered by any consuming component — always verify actual usage before patching UI-adjacent constants.
- `appointments` table being empty is indistinguishable from a filter bug — always check DB row count before debugging filter logic.
- Bash history expansion (`!f.ok`) breaks inline Python `-c` strings on Termux — always use a script file for any string containing `!`.
- `outline` CSS on native checkboxes does not reliably render on Android Chrome — use a custom div-based checkbox instead.
- `React.useState` inside a non-component function (e.g. inside `PreflightModal` which is a component but was being treated as a utility) requires the default React import — `import React from 'react'` — not just named imports.
- Supabase Realtime requires tables to be added to `supabase_realtime` publication via `ALTER PUBLICATION` — not enabled by default per table.
- `pce_data: {}` (empty object) means MD saved visit without filling PCE wizard — PCE auto-generation correctly skips. FD sees "PCE missing" on visit row.
- `/generate-pce` API call body is `{ patient_id, visit_id }` — no additional fields required, backend reads `pce_data` from DB directly.

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
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables

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
