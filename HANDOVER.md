# Cosmos Medical Technologies — HANDOVER (July 17, 2026, Session 47)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed and live
as of Session 47. Session 47 was a major infrastructure and UX session:
Active Patients report, Reports landing page, back navigation fixes, Admin
improvements, and complete dev/preview environment setup with `cosmos-dev`
Supabase project.

**Production status:** `cosmosmt.com` is live. Last successful deploy confirmed
Session 47 — env var restoration required an extra redeploy cycle (see Open Items).

**Dev environment status:** `cosmos-dev` Supabase project is operational.
Preview URL (`cosmos-dashboard-nu.vercel.app`) hits cosmos-dev. Login confirmed
working (`super@cosmos.local`). Dev Tools confirmed generating test patients.
Reports page has a known issue (see Open Items #6).

---

## Completed This Session (Session 47)

### Named ZIP Downloads — Live Test ✅ CLOSED
End-to-end live test confirmed. Open Item from Session 46 closed.

### Active Patients Report ✅ CLOSED
New `/reports/active-patients` — standalone page with TanStack Table, 17
columns, Active/All toggle, global search, column picker, CSV export.
Back button uses `router.back()`.

**Files:** `app/reports/active-patients/page.tsx`,
`app/reports/active-patients/ActivePatientsReport.tsx`

### Reports Landing Page ✅ CLOSED
`/reports` now a card grid entry point. Referral analytics moved to
`/reports/referrals`. "Active Patients ↗" link in Reports header.

**Files:** `app/reports/page.tsx`, `app/reports/ReportsLanding.tsx`,
`app/reports/referrals/page.tsx`

### Referral Reports — Flat Selects ✅ CLOSED
`app/reports/referrals/page.tsx` rewritten to use flat selects + client-side
lookup maps. Eliminates PostgREST FK join dependency. Works on both dev and
production. `ReportsClient.tsx` unchanged.

### Back Navigation — router.back() ✅ CLOSED
`ReportsClient.tsx` and `ActivePatientsReport.tsx` back links converted to
`router.back()`. Browser history stack respected.

### Admin Hardware Back Guard ✅ CLOSED
`#admin` hash sentinel + `popstate` handler. Hardware back from non-overview
tab returns to overview first; second back exits Admin.

**Files:** `app/admin/page.tsx`

### Admin Quick Access — All Sections ✅ CLOSED
Quick Access grid expanded: ICD-10, Audit Log, Ref. Providers added.

**Files:** `app/admin/components/OverviewSection.tsx`, `app/admin/page.tsx`

### Admin Provider Signature Card ✅ CLOSED
Thick cyan border removed. Eye emoji + full-width button replaced with plain
"View" text link. Green `✓` text. Matches rest of admin style.

**Files:** `app/admin/components/DoctorsSection.tsx`

### Dev/Preview Environment ✅ OPERATIONAL
- `cosmos-dev` Supabase project created and schema applied
- `supabase/migrations/000_initial_schema.sql` — 34 tables, 418 columns
- `supabase/new_user.sql` — reusable user creation template
- `supabase/seed_from_production.sql` — carriers, lawyers, doctors
- Vercel env vars: Production and Preview correctly scoped
- `lib/supabaseServer.ts` — reads `SUPABASE_SERVICE_KEY_PREVIEW` for Preview
- cosmos-dev seeded and operational

**Files:** `lib/supabaseServer.ts`, `supabase/migrations/000_initial_schema.sql`,
`supabase/new_user.sql`, `supabase/seed_from_production.sql`

### MIGRATIONS.md ✅ CLOSED
Sixth documentation file added to `cosmos-ai`. Covers environment map, env
var reference, migration inventory, RLS reference, setup guide, user creation
guide.

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet
   Merge is blocked for production use until this upgrade lands. One click in
   Render dashboard — $25/mo, no code change.

2. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

3. **Patient email required at intake.** `PatientFormV2.tsx` email field
   must become required. Patient confirmation notifications are dead until
   fixed. Deferred multiple sessions.

4. **Referral workflow auto-advancement logic.** Only SONO/FC/PSY/EMG
   currently auto-close on result upload. All other types require manual FD
   advancement. Full design needed.

5. **Duplicate visit records investigation.** Some patients have multiple
   `patient_visits` rows for the same date sharing generated PDF filenames.
   Root cause unknown.

6. **Reports page on dev — referral_types relationship error.** `/reports/referrals`
   on Preview URL still shows "Could not find a relationship between 'referrals'
   and 'referral_types'". FK constraints added and schema reload sent — may
   need additional time or a manual PostgREST restart on cosmos-dev free tier.
   Production Reports unaffected (flat selects fix deployed).

7. **000_initial_schema.sql needs regeneration.** Generated from batched CSV
   exports — missing primary keys, JSONB type for `available_days`, and all FK
   constraints. Apply `schema_fix.sql` manually when setting up new environments
   until a full `pg_dump`-based regeneration is done.

8. **Production env var incident resolved but fragile.** `NEXT_PUBLIC_SUPABASE_URL`
   and `NEXT_PUBLIC_SUPABASE_ANON_KEY` were lost from Production scope during
   Session 47 dev environment setup and had to be re-added. Vercel mobile UI
   does not reliably support per-environment scoping of variables with the same
   name — always use desktop Vercel UI for env var changes.

---

## Known Architecture Gaps (carried forward)

- `patients.intake_url` exists only via manual SQL — not in any migration file.
  Schema drift risk if DB is rebuilt.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- `referral_appointments.needs_review` and `reviewed_at` (Migrations 031-032)
  are vestigial — flagged for cleanup.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — hard refresh without
  re-login exposes wrong role.
- Ghost mode for PA/NP users skips location selection.
- Ghost sessions have no timeout (`timeout=0`).
- Abandoned route folders `ref/` and `referral/` left in repo for cleanup.

---

## Dev Environment Reference

| Environment | URL | Supabase | Branch |
|---|---|---|---|
| Production | cosmosmt.com | cosmos (prod) | `main` |
| Preview | cosmos-dashboard-nu.vercel.app | cosmos-dev | any feature branch |

**Dev login:** `super@cosmos.local` / PIN `999999`

**Feature branch workflow:**
```bash
git checkout -b feat/my-feature
# build and test
git push origin feat/my-feature
# → Vercel auto-deploys Preview → hits cosmos-dev
# → test at Preview URL
git checkout main && git merge feat/my-feature && git push
# → Vercel auto-deploys to Production
```

**When to use a feature branch:** any new DB column/table, anything that could
break existing workflows, multi-session features, anything touching auth/billing/PDF.

**Schema changes:** apply manually to cosmos-dev first, test on Preview, then
apply same SQL to production Supabase before merging code to main.

---

## Lessons Learned (Session 47, appended)

- Vercel mobile UI cannot reliably manage per-environment scoping for variables
  with the same name — always use Vercel desktop UI for env var changes involving
  Production vs Preview scope.
- PostgREST on Supabase free tier does not reliably pick up FK constraints
  added via ALTER TABLE — use flat selects + client-side lookup maps for all
  Supabase joins (Cosmos standard pattern, confirmed necessary for dev
  environment reliability).
- Supabase SQL Editor export is capped at 100 rows regardless of LIMIT setting
  — use 1,000 row limit setting on the UI row limit dropdown to get more, but
  batch exports are still required for schemas with many columns.
- `NOTIFY pgrst, 'reload schema'` can be run from SQL Editor to trigger
  PostgREST schema cache refresh without needing Supabase dashboard access.
- When `available_days` was declared as `TEXT[]` in migration but production
  uses `JSONB`, seed inserts fail with type mismatch — always export column
  types before generating seed scripts.

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
- [x] Auto-close on result upload — MRI types (Session 38)
- [x] Auto-close on result upload — SONO/FC/PSY/EMG (Session 45)
- [x] NEW RESULTS badge — MD patient chart (Session 38)
- [x] results_viewed_at dismissal (Session 38)
- [x] referral_submitted_at — set on provider assign (Session 38)
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
- [x] Provider Performance turnaround N/A fixed (Session 43)
- [x] SONO referral type — body parts, generic form (Session 45)
- [x] FC referral type — generic form (Session 45)
- [x] PSY referral type — generic form (Session 45)
- [x] EMG referral type — body parts (Upper/Lower), generic form (Session 45)
- [x] MRI selector → MRI/MRA/CT radio buttons (Session 45)
- [x] Psych referral button removed (Session 45)
- [x] Body parts in provider session email (Session 45)
- [x] Clinical reason in provider session email (Session 45)
- [x] Referral Pipeline report tab (Session 45)
- [x] Manual result upload on referral result cards (Session 46)
- [ ] DME and RX codes from patient_visits
- [ ] ReferralSheet header badge — raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientFormV2.tsx
- [ ] DEV artifacts removal — VisitTab.tsx PCE button + Admin Dev Tools card
- [ ] Add FK: referral_timeline.actor_user_id → user_profiles.id
- [ ] Cleanup abandoned route folders (ref/, referral/)
- [ ] Full referral workflow auto-advancement logic design

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
- [x] Overview tab — Demographics/Accident/Insurance restructure (Session 43)
- [x] Insurance tab — matches overview structure, policy_num (Session 43)
- [x] Edit Patient quick action button (Session 43)
- [x] Intake Form card in Documents tab (Session 43)
- [x] DashboardNav shared hamburger (Session 43)
- [x] Back button — router.back() replaced with explicit push (Session 44)
- [x] System back closes patient sheet via hash nav (Session 44)
- [x] Badge-to-tab navigation — clicking badge opens correct tab (Session 44)
- [x] Signature on file — cyan card + View button on all surfaces (Session 44)
- [x] Shared SignatureCaptureModal — optimistic UI (Session 44)
- [x] Book Appointment CTA in Appointments tab (Session 44)
- [x] Docs OK requires sig + AOB + NF-2 generated (Session 44)
- [x] Workflow Stage: NF-2 Missing Stage, Book Appointment badge (Session 44)
- [x] NF-2 KPI split — Missing vs Pending Mail (Session 44)
- [x] Work queue table — green headers, cyan cells, 10-row default (Session 44)
- [x] Visit Packet Merge — Build/View/Rebuild per visit in Documents tab (Session 45)
- [x] Column preferences — DB-persisted per user (Session 45)
- [x] Column picker — custom checkbox UI, centered dropdown, Reset button (Session 45)
- [x] Search bar X clear button (Session 45)
- [x] Activity Summary buttons → tab navigation (Session 45)
- [x] Workflow Stage — full lifecycle redesign (Session 46)
- [x] Needs Scheduling KPI card (Session 46)
- [x] Booking-action badges route directly to calendar with patient pre-filled (Session 46)
- [x] Documents tab — MD Clinical removed; visit packet checkboxes; manual result upload; named ZIP downloads; NF-2 mailed inline; signature card restyled; section header renamed/moved (Session 46)
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables
- [ ] Remove legacy PatientForm.tsx

### Stage 3b — FD Reports
- [x] Monthly Summary (Sessions 42–43)
- [x] Awaiting Results tab (Sessions 42–43)
- [x] Provider Performance tab (Sessions 42–43)
- [x] Open Aging tab (Sessions 42–43)
- [x] Referral Pipeline tab (Session 45)
- [x] Reports landing page — card grid entry point (Session 47)
- [x] Active Patients report — standalone page (Session 47)
- [x] Referral analytics moved to /reports/referrals (Session 47)
- [x] Reports flat selects — no PostgREST FK dependency (Session 47)

### Stage 3c — Patient Intake
- [x] PatientFormV2 — 5-tab wizard, FD dark theme (Session 43)
- [x] INTAKE PDF auto-generation on save (Session 43)
- [x] INTAKE Regen button in Documents tab (Session 43)
- [x] Edit patient wired to PatientFormV2 (Session 43)
- [ ] Patient email required in PatientFormV2
- [ ] intake_url added to migration file (currently manual SQL only)

### Stage 3d — Superadmin & Ghost Mode
- [x] DashboardNav on all dashboards (Session 43)
- [x] Valar Morghulis — full JWT impersonation (Session 43)
- [x] Audit log on impersonation (Session 43)
- [x] Ghost banner on all pages (Session 43)
- [x] Iron coin + anonymous mask branding (Session 43)
- [ ] Ghost mode for PA/NP users — location selection currently skipped
- [ ] Impersonation session timeout (ghost sessions have timeout=0)

### Stage 3e — Scheduling
- [x] Calendar redesign — FD V2 palette, bottom-sheet booking (Session 44)
- [x] Smart booking — auto-resolve patient's MD, next available date (Session 44)
- [x] Adaptive doctor filter — chips ≤5, dropdown >5 (Session 44)
- [x] System back closes referral sheet via hash nav (Session 44)
- [x] Location date chips in booking modal — available dates by location (Session 46)
- [x] Patient pre-fill fix — all non-discharged patients shown (Session 46)
- [ ] Calendar realtime — appointment status changes don't push live
- [ ] Conflict-aware time slot display (future enhancement)

### Stage 3f — Admin
- [x] Scroll-to-edit across all admin sections (Session 46)
- [x] Quick Access — all 8 sections (Session 47)
- [x] Hardware back guard — stays inside admin (Session 47)
- [x] Provider signature card restyled (Session 47)

### Stage 4 — Billing
- [ ] Billing packet generation improvements
- [ ] Attorney email workflow

### Stage 5 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker (Visit Packet production-blocked until done)
- [x] Dev/Preview environment — cosmos-dev Supabase (Session 47)
- [x] Initial schema migration — 000_initial_schema.sql (Session 47)
- [x] MIGRATIONS.md documentation (Session 47)
- [ ] 000_initial_schema.sql regeneration from pg_dump (technical debt)
- [ ] PDF migration to client-side @react-pdf/renderer (Phase 2, long-term)

### Stage 6 — Scale
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend
- [ ] SPF/DKIM for cosmosmt.com
- [ ] Data retention and deletion policy
- [ ] Patient data export capability
