# Cosmos Medical Technologies — HANDOVER (July 15, 2026, Session 44)

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
`cosmos-dashboard-nu.vercel.app`. Session 44 focused entirely on navigation
correctness, UX improvements to the FD work queue and patient sheet, a full
calendar redesign, and a shared signature capture system.

---

## Completed This Session (Session 44)

### Navigation — Back Button Audit and Fixes ✅ CLOSED

Full audit of all back-button and navigation patterns across the app.
Root causes identified: `router.back()` relying on browser history stack,
and `page.tsx` session restore auto-redirecting when `/` is reached via back.

**Fixes applied:**
- `PatientFormV2.tsx` — header ← Back button and tab-0 Cancel button changed
  from `router.back()` to `router.push('/dashboard-v2')`. Eliminates
  accidental logout/wrong-page on cancel.
- `FDDashboardV2.tsx` — patient sheet uses URL hash (`/dashboard-v2#patient`)
  pushed on open, `replaceState` on ✕ close, `popstate` listener closes sheet
  on system back. User stays on dashboard.
- `ReferralDashboard.tsx` — same hash pattern (`/referrals#referral`).

**Files:** `app/components/PatientFormV2.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`, `app/referrals/ReferralDashboard.tsx`

### DashboardNav — Patients Quick Link Fix ✅ CLOSED

Patients quick link was pointing to `/patients` (no route exists → 404).
Changed to `/dashboard-v2`. Link now scrolls to the work queue table and
auto-focuses the search input (400ms delay for page render).

**Files:** `app/components/DashboardNav.tsx`,
`app/dashboard-v2/FDDashboardV2.tsx`

### FD Work Queue — Table UI Overhaul ✅ CLOSED

- All table headers → bright green `#19a866` (except select checkbox column)
- All data cell text → cyan `#00cfff` (except Workflow Stage and Documents columns)
- Page size options: added 10 (default), kept 15, 25, 50, 100
- Export CSV moved to same row as Work Queue label (right side)
- Columns button → cyan styling
- Search input given `id="patientsearch"` for focus targeting
- Work Queue div given `id="workqueue"` for scroll targeting

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Work Queue — Doc Status Logic Fix ✅ CLOSED

**Docs OK** previously only required signature + AOB. Now requires all three:
- Signature on file (`patient_signature_url`)
- AOB on file (`aob_url`)
- NF-2 generated (`nf2_url`)

New **NF-2 Missing** doc status badge added (orange, same as AOB Missing).
`nf2_url` added to `Patient` interface and to `dashboard-v2/page.tsx` select.
`docsIssues` filter and KPI updated to include `nf2_url`.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`,
`app/dashboard-v2/page.tsx`

### FD Work Queue — Workflow Stage Logic Fix ✅ CLOSED

Workflow Stage previously used `nf2_mailed_at` to gate "NF-2 Pending".
Now uses `nf2_url` — once NF-2 is generated, patient advances past this stage.
Mailing is tracked separately via KPI cards.

New workflow stage label: **"NF-2 Missing Stage"** (red) — NF-2 not yet
generated. **"Book Appointment"** replaces "No Visit" — tapping badge opens
patient sheet on Appointments tab. **"Needs Appt"** → Appointments tab.
**"NF-2 Missing Stage"** → Documents tab. All badge-to-tab mappings updated.

NF-2 KPI split into two:
- **NF-2 Pending Mail** — `nf2_url` exists but `nf2_mailed_at` is null
- **NF-2 Missing** — no `nf2_url` yet

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`

### Signature Capture — Shared Component + Optimistic UI ✅ CLOSED

New shared `app/components/SignatureCaptureModal.tsx` — replaces duplicated
`SignaturePad` implementations in `FDPatientSheet` and `PatientProfile`.

Key improvements:
- Modal closes **immediately** on Save — upload happens in background
- Caller receives `filename` via `onSaved()` and updates local state optimistically
- Upload + DB write in background; `onError` callback shows toast if it fails
- Canvas drawing, PNG blob, Supabase Storage upload all centralized

`FDPatientSheet.tsx` and `PatientProfile.tsx` wired to shared component.
`PatientFormV2.tsx` retains local `SignaturePad` (stores `dataUrl` locally
for form-save flow — different pattern).
`DoctorsSection.tsx` (Admin) retains its own flow (uploads via
`/api/upload-signature` — different path/entity).

**Files:** `app/components/SignatureCaptureModal.tsx` (new),
`app/dashboard-v2/components/FDPatientSheet.tsx`,
`app/patients/[patientId]/PatientProfile.tsx`

### Signature — View Signature Button + Cyan Card ✅ CLOSED

All surfaces that display signature status now show:
- When **missing**: orange warning card with Capture button
- When **on file**: thin cyan border card (`1px solid #00cfff30`), cyan
  "✅ Signature on file" text, Re-sign button, **👁 View Signature** button
  that opens a Supabase signed URL (1800s expiry) in a new tab

Applied to: `FDPatientSheet.tsx`, `PatientProfile.tsx`, `PatientFormV2.tsx`,
`DoctorsSection.tsx` (Admin panel — doctor signatures).

### FD Patient Sheet — Badge-to-Tab Navigation ✅ CLOSED

Clicking any Workflow Stage or Documents badge in the work queue table now
opens the FD patient sheet directly on the relevant tab:
- NF-2 Missing Stage / NF-2 Pending → Documents tab
- Book Appointment / Needs Appt / Appt Today → Appointments tab
- No Visit / Billing Ready → Visits tab
- No Signature / AOB Missing / NF-2 Missing (doc) → Documents tab
- Docs OK → Overview tab

`FDPatientSheet` now accepts `initialTab?: Tab` prop. `FDDashboardV2`
passes `initialTab` state set by badge click before `openPatient()`.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`,
`app/dashboard-v2/components/FDPatientSheet.tsx`

### FD Patient Sheet — Appointments Tab ✅ CLOSED

Appointments tab now shows a **Book Appointment** button (blue gradient)
at top right, and a prominent **Schedule First Appointment** CTA when no
appointments exist. Both navigate to `/calendar?patient=${patient_id}`.
Calendar auto-opens booking modal when `?patient=` param is present.

**Files:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### Calendar — Full Redesign ✅ CLOSED

Complete rebuild of `app/calendar/page.tsx`. All existing functionality
preserved; visual and UX overhaul:

**Visual:** Full FD Dashboard V2 palette (`#0d1821`, Oxanium, cyan/green
accents). Replaced old light-mode styling.

**Booking:** Bottom-sheet modal (slides up from bottom) — no more inline form
hijacking the page. Modal includes date field (editable, pre-filled with
selected date). All dropdowns are custom dark components — no native select.

**Smart booking logic:**
- When arriving via `?patient=`, modal auto-opens
- Patient's assigned doctor (`doctor_id` from patient record) auto-fills
  the Doctor field (green AUTO badge shown)
- Date auto-advances to next available date for that doctor's schedule
  (reads `doctor_locations.days_of_week`)
- If FD changes doctor, date re-calculates to next available for new doctor
- FD can override doctor freely — no restriction

**Doctor filter:** Adaptive — chips for ≤5 doctors, custom dark dropdown
for >5 doctors (scales to large practices).

**Day cards:** Capacity bar (green→amber→red as fills), brighter text.

**Month view:** Preserved. Status dots per day. Tapping a day switches to
week view centered on that day.

**View Chart:** Now links to `/md-v2/[patientId]` (new chart).

**File:** `app/calendar/page.tsx` (full rebuild)

---

## Open Items, Priority Order

1. **DEV artifacts removal.** Remove DEV fill-all PCE button from
   `VisitTab.tsx` and Dev Tools card from Admin panel before go-live.

2. **Patient email required at intake.** `PatientFormV2.tsx` email field
   must be made required. Patient confirmation emails dead until fixed.

3. **Render memory limit — cosmos-api.** Render Starter (512MB) crashes
   during PDF generation under load. Pre-go-live blocker. Upgrade to
   Standard plan ($25/mo, 2GB RAM).

4. **Cleanup leftover route folders.** Delete `app/md-v2/[patientId]/ref/`
   and `app/md-v2/[patientId]/referral/` — both abandoned, broken content.

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
    `patients`, `patient_visits`, `patient_forms` only. Add before go-live.

14. **PCE guard — minimum pce_data threshold.** Product decision needed.

15. **Ghost mode for PA/NP users.** Location selection currently skipped.

16. **Impersonation session timeout.** Ghost sessions have `timeout=0`.

17. **`patients.intake_url` not in migration file.** Added manually via SQL
    only — schema drift risk if DB is rebuilt.

---

## DB Schema Changes This Session

No new schema changes. `nf2_url` was already in the `patients` table —
only added to the select query and Patient interface.

---

## File Confidence

All files below were modified or created this session and confirmed deployed:

| File | Changes |
|---|---|
| `app/components/PatientFormV2.tsx` | router.back() → router.push('/dashboard-v2') on Back + Cancel; sig card cyan styling; View Signature button |
| `app/components/DashboardNav.tsx` | Patients link → /dashboard-v2 with scroll+focus; Book button always active |
| `app/components/SignatureCaptureModal.tsx` | New — shared optimistic signature capture modal |
| `app/dashboard-v2/FDDashboardV2.tsx` | Hash nav for patient sheet; initialTab state + badge-to-tab; Workflow Stage logic (nf2_url); Doc Status (3 fields); NF-2 KPI split; table header/cell colors; page size; toolbar layout; Book Appointment badge |
| `app/dashboard-v2/page.tsx` | nf2_url added to patients select |
| `app/dashboard-v2/components/FDPatientSheet.tsx` | initialTab prop; Book Appointment CTA in Appointments tab; sig card cyan+View; SignatureCaptureModal wired; onClose hash clear |
| `app/referrals/ReferralDashboard.tsx` | Hash nav for referral sheet (popstate listener) |
| `app/patients/[patientId]/PatientProfile.tsx` | SignatureCaptureModal wired; sig card cyan+View |
| `app/admin/components/DoctorsSection.tsx` | Sig card cyan+View |
| `app/calendar/page.tsx` | Full rebuild — FD V2 palette, bottom-sheet booking, smart doctor/date logic, adaptive doctor filter, day card brightness, month view, View Chart → md-v2 |

---

## Known Architecture Gaps

- `getReferralProviders()` return type is still `any[]`.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"` — sessionStorage override only.
- ReferralSheet header badge reads raw `referrals.status` — cosmetic gap.
- Body parts missing on sessions rescheduled before Session 36 — data issue.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- `(referral as any).cpt_codes` cast in `ReferralOverviewTab`.
- Render Starter (512MB) insufficient for PDF generation under load.
- DME and RX referral pages still hardcode `cpt_codes: []`/`icd10_codes: []`.
- `app/md-v2/[patientId]/ref/` and `app/md-v2/[patientId]/referral/` abandoned folders to delete.
- Android/Termux filesystem is case-insensitive — git cannot track folder renames with bracket characters.
- `dashboard-v2` notes are session-only — not persisted to DB.
- `referral_appointments.needs_review` and `reviewed_at` (migrations 031–032) vestigial.
- Realtime subscription covers `patients`, `patient_visits`, `patient_forms` only.
- PCE auto-generation guard fires on any non-empty `pce_data` — minimum field threshold not enforced.
- `hasPceLocal` variable remains in `PreflightModal` — dead variable, harmless.
- `PatientForm.tsx` (legacy) still exists and is used nowhere — candidate for removal.
- `patients.intake_url` added via manual SQL only — not in any migration file.
- Ghost mode for PA/NP users skips location selection.
- Ghost mode has no session timeout (timeout=0).
- `AI_STYLE_GUIDE.md` §2 still says "five" Tailwind/shadcn exceptions — should be "six" (FD Dashboard V2 added Session 41).

---

## Technical Lessons This Session

- `router.back()` is unreliable for cancel/back navigation in Next.js App
  Router SPA — it depends on browser history stack which doesn't match app
  logical flow. Use `router.push('/target')` with explicit destination instead.
- URL hash navigation (`window.history.pushState` + `popstate` listener) is
  the correct pattern for "system back closes panel" on Android Chrome. The
  `popstate` event fires when hash is popped; check `!window.location.hash`
  to distinguish from other hash changes.
- Python `sed` is unreliable for multi-line replacements in Termux — use
  Python `str.replace()` with heredoc scripts instead. Always write `if new
  in content / elif old in content` guards to make patches idempotent.
- When delivering large file rebuilds from the artifact system, always
  `rm -f ~/storage/downloads/<filename>*` before re-downloading to avoid
  Chrome's duplicate-rename behavior (`file (1).tsx` etc).
- Supabase optimistic UI pattern: call `onSaved(filename)` before upload
  completes, update local state immediately, run upload in background IIFE.
  Eliminates perceived wait on signature save.

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
- [ ] Notes tab persistence — patient_notes table
- [ ] Stub KPIs — Patients Waiting, Insurance Verification, Tasks Due Today
- [ ] Realtime — referrals and appointments tables
- [ ] Remove legacy PatientForm.tsx

### Stage 3b — FD Reports ✅ COMPLETE
- [x] All items from Sessions 42–43

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
- [ ] Calendar realtime — appointment status changes don't push live
- [ ] Conflict-aware time slot display (future enhancement)

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
