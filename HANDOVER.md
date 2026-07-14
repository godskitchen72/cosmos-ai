# Cosmos Medical Technologies — HANDOVER (July 14, 2026, Session 40)

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
`cosmos-dashboard-nu.vercel.app`. Session 40 completed the Front Desk
Dashboard V2 — a full enterprise-grade dashboard rebuild across four phases,
covering KPI cards, TanStack work queue, patient detail sheet, referral
integration, Oxanium font, and mobile search. The new dashboard is accessible
at `/dashboard-v2` and linked from the superadmin picker.

---

## Completed This Session (Session 40)

### FD Dashboard V2 — Full Build ✅ CLOSED

New enterprise front desk dashboard built from scratch at `/dashboard-v2`.
Existing `/dashboard` is completely untouched and preserved.

**Technology decisions locked:**
- shadcn/Tailwind approved as 6th exception (alongside existing 5 dashboard surfaces)
- Framer Motion explicitly rejected — not added to project
- TanStack Table (already in project) used for work queue
- Oxanium font applied via `className={oxanium.className}` on root wrapper

**Phase 1 — Shell + Header + KPI Cards:**
- New route `app/dashboard-v2/page.tsx` (server component, `revalidate: 0`)
- Sidebar (desktop fixed, mobile slide-in with backdrop + overlay)
- Header: search, date, notifications bell (lights up on NF-2 queue), New Patient, Schedule, FD avatar
- 8 KPI cards: 5 real (Today's Patients, Appointments Today, Documents Missing, NF-2 Queue, Billing Ready), 3 stubbed (Patients Waiting, Insurance Verification, Tasks Due Today) with COMING SOON tag
- KPI cards filter work queue on tap

**Phase 2 — TanStack Work Queue:**
- Full TanStack Data Table with 11 columns
- Column sorting (click header, arrow indicators)
- Global search wired to TanStack `globalFilter`
- Column visibility toggle (custom dark dropdown, no native select)
- Row selection with bulk action bar
- CSV export (all filtered rows, not just current page)
- Custom `PageSizePicker` (25/50/100) — no native `<select>` per AI_STYLE_GUIDE §5
- Server-side pagination (50 rows default)
- Row hover + selected row highlight

**Phase 3 — Patient Sheet Polish:**
- Tab reset to Overview when new patient opens
- Alert banners for missing AOB, NF-2, carrier, claim number
- Document Status checklist using confirmed columns only (AOB, NF-2, Insurance, Claim #)
- Workflow stage badges: Intake Incomplete, NF-2 Pending, No Visit, Needs Appt, Appt Today, In Progress, Billing Ready
- Carrier name shown in sheet header subtitle

**Phase 4 — Patient Sheet Tabs:**
- **Overview tab**: Demographics, Accident & Claim, Document Status checklist, Activity Summary (visits/appointments/referrals counts)
- **Insurance tab**: Carrier, claim number, date of loss
- **Referrals tab**: Real referral data via FK joins (referral_types, referral_providers, referral_appointments). "Manage in Referral Dashboard →" button links to `/referrals?patient=Name` pre-filtered
- **Visits tab**: Full visit history with billing status and NF-3 preflight result
- **Appointments tab**: All appointments with date, time, status
- **Documents tab**: AOB on file with View link
- **Timeline tab**: 9-step workflow timeline with real completion dates
- **Notes tab**: Session-only text area (not persisted to DB — roadmap item)

**Font + Mobile Search:**
- Entire dashboard now uses Oxanium via `className={oxanium.className}` — matches all other Cosmos dashboards
- Mobile search: dedicated full-width search row below header buttons on screens < 768px; inline in header on md+

**Superadmin picker:**
- FD Dashboard V2 card added to `app/page.tsx` dashboard picker

**Key schema lessons learned this session:**
- `patients` PK is `patient_id` (not `id`)
- `patient_visits` PK is `id`
- `appointments` PK is `id`
- `patients.date_of_accident` → actual column is `doi`
- `patients.claim_number` → actual column is `claim_num`
- `patients.carrier` is a plain text field (not FK to insurance_carriers)
- `referrals` table has `patient_id` directly; use `select('*')` or mirror `ReferralsTabV2` query exactly
- Always use `select('*')` for discovery; never assume column names not confirmed in existing working code
- FK joins on `supabaseServer` silently return null when PostgREST FK relationship not configured — use flat selects + client-side lookup maps instead

### Referral Dashboard — Patient Pre-Filter ✅ CLOSED

`ReferralDashboard.tsx` `search` state now initializes from `useSearchParams().get('patient') ?? ''`.
Linking to `/referrals?patient=David+Anderson` pre-populates the search bar and
immediately filters the table to that patient. No changes to `referrals/page.tsx`
needed — `useSearchParams` reads URL client-side automatically.

**Files changed:** `app/referrals/ReferralDashboard.tsx`, `app/dashboard-v2/components/FDPatientSheet.tsx`

---

## Open Items, Priority Order

1. **Lock icon removal from Closed status** (`types.ts` icon field).
   Python patch anchor failed Sessions 33–39 due to emoji Unicode encoding
   mismatch. Fix: pull `types.ts` fresh, inspect exact bytes around the icon
   field, use Python byte-level replace.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientForm.tsx` `email` field
   must be made required. Patient confirmation emails dead until fixed.

4. **Render memory limit — cosmos-api.** Render Starter (512MB) crashes
   during PDF generation under load. Pre-go-live blocker. Upgrade to
   Standard plan ($25/mo, 2GB RAM).

5. **Cleanup leftover route folders.** Delete `app/md-v2/[patientId]/ref/`
   and `app/md-v2/[patientId]/referral/` — both abandoned, broken content.
   Use `git rm -rf` via GitHub web UI or fresh clone.

6. **Dashboard V2 — Appointments tab shows 0.** `appointments` table
   `patient_id` filter may not be matching due to column name mismatch. Verify
   `appointments` table FK column name against working code before next fix.

7. **Dashboard V2 — Notes tab persistence.** Notes are session-only.
   Requires a new `patient_notes` table or column. Roadmap item.

8. **Dashboard V2 — Stub KPIs.** Patients Waiting, Insurance Verification,
   Tasks Due Today require new DB tables/columns. Future work.

9. **ReferralSheet header badge.** Still shows raw DB status (`New`,
   `Scheduled`) instead of computed status. Cosmetic only.

10. **`/referrals/page.tsx` `userRole` hardcoded to `"md"`.** Relies on
    sessionStorage override. Hard refresh without re-login exposes wrong role.

11. **HIPAA BAAs.** Supabase, Render, Vercel, Resend — all unsigned.
    Pre-go-live blocker.

12. **SPF/DKIM for cosmosmt.com.** Not yet configured. Pre-go-live blocker.

13. **DME and RX referral codes.** Excluded from Session 38 codes refactor.

14. **Psych referral type.** No `psych/` route exists. New build required.

---

## DB Schema Changes This Session

No new migrations this session. All schema from Session 38 remains current.

`referral_appointments.needs_review` and `reviewed_at` columns (migrations
031–032) are now vestigial — the workflow that wrote to them was removed in
Session 39. No code writes to them in the current flow.

---

## File Confidence

All files below were modified this session and confirmed on disk as of
last deploy:

| File | Changes |
|---|---|
| `app/dashboard-v2/page.tsx` | Server component — patients (flat select), visits (select *), appointments (select *), doctors, referrals (FK joins + deleted_at filter) |
| `app/dashboard-v2/FDDashboardV2.tsx` | Full new file — TanStack table, KPI cards, sidebar, header, Oxanium font, mobile search |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | Full new file — 8 tabs, referral integration, Oxanium font, patient pre-filter link |
| `app/page.tsx` | FD Dashboard V2 card added to superadmin picker |
| `app/referrals/ReferralDashboard.tsx` | `search` state initialized from `useSearchParams().get('patient') ?? ''` |

---

## Known Architecture Gaps

- `getReferralProviders()` return type is still `any[]`.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — sessionStorage override only.
- ReferralSheet header badge reads raw `referrals.status` — cosmetic gap.
- Body parts missing on sessions rescheduled before Session 36 — data issue.
- Lock icon emoji in `types.ts` cannot be patched via Python string anchors.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- `(referral as any).cpt_codes` cast in `ReferralOverviewTab` — new type columns use `as any`.
- Render Starter (512MB) insufficient for PDF generation under load.
- DME and RX referral pages still hardcode `cpt_codes: []`/`icd10_codes: []`.
- `app/md-v2/[patientId]/ref/` and `app/md-v2/[patientId]/referral/` abandoned folders to delete.
- Android/Termux filesystem is case-insensitive — git cannot track folder renames with bracket characters.
- `dashboard-v2` Appointments tab shows 0 — `appointments.patient_id` FK column name unverified.
- `patients.patient_signature_url` unreliable — not used by existing FD dashboard; removed from doc status logic in V2.
- `dashboard-v2` notes are session-only — not persisted to DB.

---

## Technical Lessons This Session

- Never assume column names on tables not previously queried in the session. Always grep existing working code or use `select('*')` first.
- `supabaseServer` FK joins silently return `null` for the entire query when PostgREST FK relationship is not configured — symptoms look identical to RLS block. Use flat selects + client-side lookup maps for new queries.
- `patients` table PK is `patient_id`, not `id`. `patient_visits` and `appointments` use `id`. Confirm PKs before writing any select.
- Regex `re.sub` on multi-line TypeScript interface blocks with `| null` union types corrupts the file — use exact `str.replace` on known content instead.
- Always pull fresh files from git HEAD before patching — never base patches on files already in the outputs directory from earlier in the same session.
- Python heredoc `<< 'EOF'` inside a `cat` command fails in Termux when the outer shell is also using `EOF` as a delimiter. Use `cat > file << 'ENDOFFILE'` with a unique delimiter.
- `useSearchParams()` reads URL query params client-side automatically in Next.js App Router — no `searchParams` prop needed on server component parent when the client component reads params itself.

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
- [ ] Lock icon removal from Closed status (anchor mismatch — deferred x6)
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
- [ ] Appointments tab — verify patient_id FK column name, fix 0 count
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today

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
