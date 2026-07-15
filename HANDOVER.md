# Cosmos Medical Technologies — HANDOVER (July 15, 2026, Session 43)

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
on `cosmos-dashboard-nu.vercel.app`. Session 43 completed a major UI/UX
expansion: new patient intake form wizard, FD sheet overview restructure,
INTAKE PDF auto-generation, shared DashboardNav hamburger across all
dashboards, and Valar Morghulis (Ghost Mode) full JWT superadmin
impersonation system.

---

## Completed This Session (Session 43)

### Email Notifications — Fixes and Enhancements ✅ CLOSED

Provider-assigned email removed entirely (was Item 1 equivalent — provider
no longer notified on assignment, only on session schedule). Session emails
(patient confirmation + provider session) fixed:
- Font changed from Oxanium (web font, not supported in email clients) to
  Arial — eliminates Outlook font blowup
- Layout changed from `display:flex;justify-content:space-between` to
  single-row `Label: Value` format — no wrapping on mobile
- AM/PM conversion: `HH:MM` → `h:MM AM/PM` via `fmt12h()` helper
- ICD-10 codes and Referral Type added to provider session email
- `referral_submitted_at` still set on provider assignment (unchanged)

**Files:** `app/referrals/actions.ts`

### FD Patient Sheet — Overview Tab Restructure ✅ CLOSED

Overview tab sections redesigned to match new information architecture:
- **Demographics** — Full Name, DOB, Phone, Email, Patient ID
- **Accident** — Date of Accident (cyan accent), Type of Accident
  (`accident_description` column)
- **Insurance** — Insurance Co, Policy (`policy_num`), Claim, Provider
- **Document Status** — unchanged

Section headers → bright green `#19a866`. Field labels → cyan `#00cfff`.
`accident_description` and `policy_num` added to `Patient` interface in
both `FDPatientSheet.tsx` and `FDDashboardV2.tsx`. Both columns added to
patients select in `app/dashboard-v2/page.tsx`.

Insurance tab in FD sheet updated to match: Insurance Co → Policy → Claim
→ Date of Loss → Provider. Stale "extended fields coming soon" placeholder
removed.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`, `app/dashboard-v2/page.tsx`

### FD Patient Sheet — Edit Patient Button ✅ CLOSED

Quick action button added to FD sheet action bar: **Edit** (purple `#a78bfa`,
User icon) links to `/patients/${patient_id}/edit`. Edit route
(`EditPatientForm.tsx`) now imports `PatientFormV2` instead of legacy
`PatientForm`.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/patients/[patientId]/edit/EditPatientForm.tsx`

### PatientFormV2 — Tabbed Intake Wizard ✅ CLOSED

New `app/components/PatientFormV2.tsx` — full patient intake/edit form
styled to match FD Dashboard V2. Replaces `PatientForm.tsx` for new patient
and edit flows. Key design decisions:
- 5-tab wizard: Personal → Accident → Insurance → Attorney → Signature
- Tab bar identical to FD Patient Sheet tabs (cyan active underline, green
  completion dot, Oxanium font)
- Thin cyan progress bar under tab bar
- Per-tab validation: Personal requires name/DOB, Accident requires DOI,
  Signature requires sig before save
- Next button shows next tab name; Save only on final tab (green/amber per
  completeness)
- Attorney tab optional notice — can skip if not yet assigned
- After save → redirects to `/dashboard-v2`
- Auto-generates INTAKE PDF on new patient save (fire-and-forget)
- All save/insert/update logic identical to `PatientForm.tsx`
- `app/patients/new/page.tsx` updated to use `PatientFormV2`

**Files:** `app/components/PatientFormV2.tsx`,
`app/patients/new/page.tsx`

### INTAKE PDF Auto-Generation (CMT-INTAKE-001) ✅ CLOSED

Patient Intake Form PDF (CMT-INTAKE-001 v1.4) auto-fills on patient save
and can be regenerated from the Documents tab.

- 38 fillable AcroForm fields — filled via `pypdf` (no annotation overlay)
- Field mapping: all patient demographics, contact, accident type checkboxes,
  insurance, attorney, treating provider, intake date
- Accident type: `accident_description` text mapped to Motor Vehicle / Work
  Related / Slip & Fall / Other checkboxes via keyword detection
- New endpoint: `POST /generate/intake` in `cosmos-api/main.py`
- New generator: `cosmos-api/generate_intake.py`
- Template: `cosmos-api/PATIENT_INTAKE.pdf` (bundled in repo)
- New column: `patients.intake_url text` (migration applied manually via
  Supabase SQL editor)
- Documents tab: **Intake Form** card (purple `#a78bfa`) added above NF-2
  with View and Regen buttons
- `patient_forms` table: upsert row on each generation (delete old, insert
  new with `form_type: 'INTAKE'`)

**Files:** `cosmos-api/main.py`, `cosmos-api/generate_intake.py`,
`cosmos-api/PATIENT_INTAKE.pdf`,
`app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/components/PatientFormV2.tsx`

### DashboardNav — Shared Hamburger Switcher ✅ CLOSED

New shared component `app/components/DashboardNav.tsx` — hamburger button
+ slide-out drawer deployed on all dashboards.

Drawer contains:
- Currently Viewing (highlighted card with role color)
- Switch Dashboard: Front Desk / MD / Clinical / Referrals / Billing /
  Reports / Admin (with icons and subtitles)
- Quick Links: Patients, Calendar
- User email + Sign Out button

Wired to: FD Dashboard V2, MD (MDClient), Billing (BillerDashboard),
Referrals (ReferralDashboard), Reports (ReportsClient), Admin (admin/page.tsx).

**backdrop-blur removed** from MD and Billing sticky headers — was creating
CSS stacking context that prevented the drawer from rendering above page
content on Android Chrome. Replaced with solid opaque backgrounds.

Admin sidebar converted from flex push-layout to fixed overlay — content
now always takes full screen width; sidebar slides over on top with dark
backdrop. Tapping a nav item auto-closes the sidebar.

**Iron coin** (`/public/iron-coin.jpg`) used as profile image:
- Superadmin badge on login page
- FD header role badge replaces "FD" text circle

**Files:** `app/components/DashboardNav.tsx`, `app/dashboard-v2/FDDashboardV2.tsx`,
`app/md/MDClient.tsx`, `app/billing/BillerDashboard.tsx`,
`app/referrals/ReferralDashboard.tsx`, `app/reports/ReportsClient.tsx`,
`app/admin/page.tsx`, `public/iron-coin.jpg`

### Valar Morghulis — Superadmin Ghost Mode ✅ CLOSED

Full JWT impersonation system for superadmin. Complete implementation:

**Backend (`cosmos-api/main.py`):**
- `GET /impersonate/users` — fetches all auth users via Supabase Admin API,
  joins `user_profiles` by UUID to get role/name, excludes superadmin.
  Returns `{ users: [{id, email, full_name, role, active}] }`
- `POST /impersonate` — verifies caller is superadmin, finds target in
  `auth.users` by email, calls Supabase Admin API
  `POST /auth/v1/admin/generate_link` with `type: magiclink` + target email.
  Returns `{ token_hash, type, target_email, target_role, target_id }`.
  Logs to `audit_logs` with superadmin ID + target info.
- Both endpoints: JWT-verified, superadmin-gated

**Frontend (`app/page.tsx`):**
- Superadmin dashboard picker gains second tab: **Valar Morghulis**
  (anonymous mask icon + iron coin)
- Ghost tab loads user list via `/impersonate/users`
- Tapping **Enter** calls `/impersonate`, gets `token_hash`, calls
  `supabase.auth.verifyOtp({ token_hash, type: 'magiclink' })` — full JWT
  swap, real session as target user
- Sets `sessionStorage`: `cosmos_ghost_origin = 'superadmin'`,
  `cosmos_ghost_role = '{role} ({email})'`
- MD/PA/NP users: skips location picker, navigates directly to
  `/md?doctor_id=...`
- All other roles: `window.location.href = meta.path`

**Ghost banner (`DashboardNav.tsx`):**
- Reads `cosmos_ghost_origin` on mount
- If set: renders fixed amber banner at top of every page (z-index 99999):
  iron coin + "Valar Morghulis — {role} ({email})" + Exit ✕ button
- Exit: clears ghost flags, signs out, redirects to `/`

**Superadmin picker:**
- FD Dashboard V2 removed as separate card (Front Desk now points to
  `/dashboard-v2` directly)
- Dashboard grid: Front Desk / MD / Billing / Admin (4 cards)
- Anonymous mask image (`/public/ghost-mask.jpg`) on Valar Morghulis tab
- Iron coin on Enter buttons and loading indicator

**Files:** `cosmos-api/main.py`, `app/page.tsx`,
`app/components/DashboardNav.tsx`, `public/ghost-mask.jpg`,
`public/iron-coin.jpg`

### Provider Performance Turnaround N/A Bug ✅ CLOSED

Item 15 resolved this session. Turnaround calculation now correctly finds
valid appointment/result pairs on closed referrals.

**Files:** `app/reports/ReportsClient.tsx`

---

## Open Items, Priority Order

1. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

2. **Patient email required at intake.** `PatientFormV2.tsx` email field
   must be made required. Patient confirmation emails dead until fixed.
   (`PatientForm.tsx` legacy form also still has this gap.)

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

- `patients.intake_url TEXT` — added manually via Supabase SQL editor
  (`ALTER TABLE patients ADD COLUMN IF NOT EXISTS intake_url text`)
- No new migrations. No publication changes.

---

## File Confidence

All files below were modified or created this session and confirmed deployed:

| File | Changes |
|---|---|
| `app/referrals/actions.ts` | Provider-assigned email removed; session emails fixed (Arial font, AM/PM, single-row layout, ICD-10 + type added) |
| `app/dashboard-v2/page.tsx` | `policy_num`, `accident_description` added to patients select |
| `app/dashboard-v2/FDDashboardV2.tsx` | `policy_num`, `accident_description` added to Patient interface; Edit button added; iron coin profile image; DashboardNav wired; old sidebar removed |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | Overview restructured (Demographics/Accident/Insurance); Insurance tab updated; Edit quick action; Intake Form card; `intake_url` + `accident_description` + `policy_num` in FullPatient interface; handleGenerate/handleRegenerate support `intake_url` |
| `app/components/PatientFormV2.tsx` | New file — 5-tab intake/edit wizard, FD dark theme, auto-generates INTAKE on save |
| `app/components/DashboardNav.tsx` | New file — shared hamburger drawer with dashboard switcher, ghost mode banner |
| `app/patients/new/page.tsx` | Uses `PatientFormV2` |
| `app/patients/[patientId]/edit/EditPatientForm.tsx` | Uses `PatientFormV2` |
| `app/md/MDClient.tsx` | DashboardNav wired; backdrop-blur removed; Sign Out moved to drawer |
| `app/billing/BillerDashboard.tsx` | DashboardNav wired; backdrop-blur removed; Sign Out moved to drawer |
| `app/referrals/ReferralDashboard.tsx` | DashboardNav wired |
| `app/reports/ReportsClient.tsx` | DashboardNav wired; Provider Performance turnaround N/A fixed |
| `app/admin/page.tsx` | DashboardNav wired; solid header bg; sidebar converted to fixed overlay |
| `app/page.tsx` | Superadmin picker: Valar Morghulis tab, ghost mode impersonation flow, iron coin, FD Dashboard V2 card removed, 4-card grid |
| `cosmos-api/main.py` | `/generate/intake`, `/generate-records-zip`, `/impersonate`, `/impersonate/users` endpoints |
| `cosmos-api/generate_intake.py` | New file — CMT-INTAKE-001 PDF fill logic, 38 AcroForm fields |
| `cosmos-api/PATIENT_INTAKE.pdf` | New file — intake form template bundled in repo |
| `public/ghost-mask.jpg` | New file — anonymous mask logo for Valar Morghulis tab |
| `public/iron-coin.jpg` | New file — iron coin (GoT) for superadmin profile and ghost UI |

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
- `/generate-records-zip` and `/email-records` use `records@cosmosmt.com` as sender — verify this address is configured in Resend before testing email flow end-to-end.
- `user_profiles` table has no `email` column — email lives only in `auth.users`. Any query joining user identity to email must go through the Supabase Admin API (service role), not the public client.
- Ghost mode (`/impersonate`) uses Supabase Admin API `generate_link` which generates a one-time magic link. Token is single-use — a second Enter tap on same user requires a new API call.
- `PatientForm.tsx` (legacy) still exists and is used nowhere after Session 43 edit wiring — candidate for removal next session.

---

## Technical Lessons This Session

- `backdrop-blur` on sticky headers creates a CSS compositor layer on Android Chrome that ignores `z-index` from outside its stacking context. Fixed overlays (drawers, modals) cannot render above it regardless of z-index value. Remove `backdrop-blur` and use solid opaque backgrounds instead.
- Supabase `generate_link` correct endpoint is `POST /auth/v1/admin/generate_link` with `{ type: 'magiclink', email }` in body — NOT `POST /auth/v1/admin/users/{id}/generate_link`. The user-specific path returns 404.
- `user_profiles` has no `email` column — always use `auth.users` via Admin API for email lookups. Never assume profile tables mirror auth fields.
- Ghost mode for MD users must bypass `handlePostLogin` entirely — that function triggers location picker stage which hangs when called post-impersonation. Use `window.location.href` directly after `verifyOtp` for all ghost navigation.
- `pypdf` fills AcroForm checkboxes with `/Yes` (on) and `/Off` (off) — confirm via `field.get('/_States_')` before writing. `auto_regenerate=False` required or Acrobat re-renders and drops values.
- TypeScript `Record<string, string>` state must be updated to `Record<string, { path: string; bucket: string }>` when storing structured objects — TS2322 caught at compile time (Session 42 lesson reinforced).
- Chrome on Android does not overwrite same-named downloads — always check `ls -lt` before `cp` when re-downloading.

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
- [ ] DME and RX codes from patient_visits
- [ ] Psych referral type (new build)
- [ ] ReferralSheet header badge — raw DB status (cosmetic)
- [ ] Patient email required at intake — PatientFormV2.tsx
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
- [x] Overview tab — Demographics/Accident/Insurance restructure (Session 43)
- [x] Insurance tab — matches overview structure, policy_num (Session 43)
- [x] Edit Patient quick action button (Session 43)
- [x] Intake Form card in Documents tab (Session 43)
- [x] DashboardNav shared hamburger (Session 43)
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables
- [ ] Remove legacy PatientForm.tsx

### Stage 3b — FD Reports
- [x] /reports page — server component + client component (Session 42)
- [x] Monthly Summary tab — by type: opened/closed/results (Session 42)
- [x] Awaiting Results tab — oldest first, days waiting (Session 42)
- [x] Provider Performance tab — assigned/results/rate/turnaround (Session 42)
- [x] Open Aging tab — 4 bucket cards, filterable table (Session 42)
- [x] Provider Performance turnaround N/A fixed (Session 43)

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
