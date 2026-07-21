# Cosmos Medical Technologies — HANDOVER (July 21, 2026, Session 51 — Close)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all seven documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed and live as of Session 51 close.

**Production status:** `cosmosmt.com` is live. FD Dashboard V2 KPI cards updated, MD Referral Workspace live, Admin Users login email edit live, referral detail tabs restyled.

**Dev environment status:** `cosmos-dev` Supabase project fully operational.

---

## Completed This Session (Session 51 — Full)

### FD Dashboard V2 — Documents Missing: intake form added ✅
`docsIssues` filter now includes `!p.intake_url` — patients without an intake form are included in the Documents Missing KPI and work queue filter. `intake_url` added to `Patient` interface and to the Supabase select in `page.tsx`.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`, `app/dashboard-v2/page.tsx`

### FD Dashboard V2 — Bills Submitted KPI (visit count) ✅
`billingReady` (patient count) replaced with `billsSubmitted` (visit count — `visits.filter(v => v.submitted_to_billing_at).length`). KPI label updated to "Bills Submitted", description "visits submitted to billing".

**File:** `app/dashboard-v2/FDDashboardV2.tsx`

### FD Dashboard V2 — Submit Bills KPI (full 4-gate) ✅
New `submitBills` KPI counts visits ready to submit but not yet submitted. Full 4-condition gate: `nf3_preflight_passed = true` + `AOB on file` + `visit_line_items` exist + PCE generated + `submitted_to_billing_at IS NULL`. `page.tsx` fetches `visit_line_items` (visit_id only) and `patient_forms` (visit_id + form_type = PCE) to support the gate.

**Files:** `app/dashboard-v2/FDDashboardV2.tsx`, `app/dashboard-v2/page.tsx`

### FD Dashboard V2 — NF-2 Missing KPI removed ✅
`nf2missing` KPI card removed. Documents Missing (which includes NF-2 check) makes it redundant. `nf2Missing` variable retained — still used by `getWorkflowStage()`.

**File:** `app/dashboard-v2/FDDashboardV2.tsx`

### FDPatientSheet — Bills Submitted label ✅
"Billing Ready" label updated to "Bills Submitted" in the patient sheet workflow status section.

**File:** `app/dashboard-v2/components/FDPatientSheet.tsx`

### Admin Users — login email edit for superadmin ✅
Superadmins can now change any user's login email directly from the Users tab. Email change calls `supabase.auth.admin.updateUserById(id, { email, email_confirm: true })` — immediate, no confirmation email sent. `emailEdit` field added to edit form with helper note. Email only sent to API when it has actually changed (prevents unnecessary auth updates on every save).

**Files:** `app/admin/components/UsersSection.tsx`, `app/api/admin/users/route.ts`

### Admin Users — scroll + focus on edit form and PIN reset ✅
`fullNameRef` auto-focuses the Full Name input when Edit is tapped. `pinResetRef` auto-focuses the PIN input when Reset PIN is tapped. Both scroll into view first (150ms delay on focus to allow scroll to complete).

**File:** `app/admin/components/UsersSection.tsx`

### Admin Overview — KPI cards 3 per row ✅
KPI grid changed from `grid-cols-2` to `grid-cols-3`. Card `py-6` default from shadcn `Card` component overridden with `py-0 gap-0` on `KpiCard`. `CardContent` padding updated to `py-2`.

**File:** `app/admin/components/OverviewSection.tsx`

### MD Referral Workspace — `/referrals` route ✅
New full-page workspace at `/md/[patientId]/referrals?visit_id=`. Replaces direct navigation to individual referral pages. Features: sticky collapsible referral selector (4-col grid, 13 types), per-referral status tracking (not started / in progress / completed), `onBack` returns to grid, `onSaved` marks complete and returns to grid, Finish screen with summary and direct jump-back to any referral.

**Files added:**
- `app/md/[patientId]/referrals/page.tsx` (server wrapper)
- `app/md/[patientId]/referrals/ReferralWorkspace.tsx` (client workspace)
- `app/md/[patientId]/lib/referralUtils.ts` (shared `getAuthToken` + `viewReferralFile`)

### MD Referral Workspace — all 11 forms wired ✅
All referral form components updated: `getAuthToken` extracted to shared `referralUtils.ts` (eliminates 11 duplicate copies). `onBack` + `onSaved` optional props added to all 11 forms. `router.back()` replaced with `onBack ? onBack() : router.back()`. `viewReferralFile()` replaces inline `createSignedUrl` calls.

**Files:** all 11 `*Referral.tsx` components across `mri/`, `sono/`, `pt/`, `ortho/`, `vng/`, `ans/`, `dme/`, `rx/`, `emg/`, `psy/`, `fc/`

### MD Referral Workspace — MRI/MRA/CT split into 3 focused forms ✅
`MriReferral.tsx` (combined modality form) is no longer used by the workspace. Three new focused forms created:
- `MriForm.tsx` — Spine + Extremities + Contrast only
- `MraForm.tsx` — MRA Studies only
- `CtForm.tsx` — CT Studies only

All three call the same `/generate-mri` endpoint. Existing `MriReferral.tsx` retained for individual page route (`/mri/page.tsx`).

**Files added:** `app/md/[patientId]/mri/MriForm.tsx`, `MraForm.tsx`, `CtForm.tsx`

### Referral Detail — tab restyling ✅
All 4 referral detail tab components updated to match calendar BookingModal design tokens:
- Card backgrounds: `#0a1015` → `#0f1f2e`
- Input backgrounds: `#0d1821` → `#0a1119`
- Section headers: `fontSize 15, cyan` → `fontSize 11, green, uppercase, letterSpacing 0.1em`
- Upload/action buttons: `#1a2e4a / #60a5fa` → `#00cfff20 / #00cfff`
- Field labels: `#64748b` → `#19a866`
- Destructive buttons: `#3a1a1a / #f87171` → `#e74c3c18 / #e74c3c`

**Files:** `app/referrals/components/ReferralAppointmentTab.tsx`, `ReferralOverviewTab.tsx`, `ReferralDocumentsTab.tsx`, `ReferralNotesTab.tsx`

---

## Open Items, Priority Order

1. **Render Standard plan upgrade.** Still on Starter (512MB). Visit Packet Merge blocked for production use. One click, $25/mo.

2. **Twilio SMS activation.** All code live. Three steps:
   - Buy `+17185695200`
   - Update `TWILIO_FROM_NUMBER` in Render
   - Complete A2P 10DLC business registration

3. **Production patient phone data.** All `patients.phone` = `+19297683179`. Clear before go-live:
   ```sql
   UPDATE patients SET phone = NULL;
   ```

4. **DEV artifacts removal.** PCE fill-all button in `VisitTab.tsx` + Dev Tools card in Admin panel.

5. **Patient phone required at intake.** `PatientFormV2.tsx` phone field must be required.

6. **Patient email required at intake.** `PatientFormV2.tsx` email field must be required.

7. **Appointment confirmation SMS trigger.** Wire `/notify/sms` into calendar booking save path.

8. **`page.tsx` userRole hardcoded.** `/referrals/page.tsx` passes `userRole="md"` — role is resolved client-side from sessionStorage. Not a bug but should be cleaned up.

9. **Duplicate visit records investigation.** Some patients have multiple `patient_visits` rows for the same date.

10. **`000_initial_schema.sql` superseded.** Stale on disk — use pg_dump approach.

---

## Known Architecture Gaps (carried forward)

- `patients.intake_url` exists only via manual SQL — not in any migration file.
- No FK between `referral_timeline.actor_user_id` and `user_profiles.id`.
- Ghost session timeout is 0 — impersonation sessions never expire.
- `/referrals/page.tsx` `userRole` hardcoded to `"md"`.

---

## Referral Architecture — Session 50 Model (unchanged)

### Appointment-Driven Dashboard
- One row per `referral_appointments` record
- Multi-Referral reminder row (NEW bucket only) for MRI with unscheduled parts
- Individual appointment row navigates to `/referrals/[id]?appt=[uuid]`
- Multi-Referral row navigates to `/referrals/[id]` (all sessions)

### MRI Session Splitting Rules
- Max 2 body parts per session (FD chooses 1 or 2)
- Patient can spread across as many sessions as needed
- MRI referral status stays `new` throughout
- Closes only when ALL ordered body parts have sessions + ALL sessions have results

### Cancelled Appointment Lifecycle
- Cancel → `outcome = 'cancelled'` → RESCHEDULE row appears
- Rebook → cancelled appointment row **deleted** → RESCHEDULE row destroyed → new SCHEDULED row created
- History preserved in `referral_timeline`

### `outcome` Values (referral_appointments)
`null` (scheduled/pending) | `completed` | `cancelled` | `no_show`

---

## MD Referral Workspace Architecture (Session 51)

### Route
`/md/[patientId]/referrals?visit_id=` — server page.tsx → `ReferralWorkspace.tsx` (client)

### Referral Registry
13 entries in `REFERRAL_REGISTRY` array in `ReferralWorkspace.tsx`. To add a new referral type: add one entry to the registry + add a case to `ReferralFormRouter` switch. Nothing else changes.

### Form Contract
All 11 referral form components share identical optional props:
```ts
onBack?: () => void        // called instead of router.back() when inside workspace
onSaved?: (filename: string) => void  // called after successful PDF save
```
When `onBack` is absent (standalone page route), `router.back()` fires as before — backward compatible.

### Shared Utilities
`app/md/[patientId]/lib/referralUtils.ts`:
- `getAuthToken()` — session JWT for API Authorization headers
- `viewReferralFile(filename)` — opens signed URL in new tab

### MRI / MRA / CT
Three separate focused forms in `app/md/[patientId]/mri/`:
- `MriForm.tsx` — spine + extremities + contrast (formType: `MRI`)
- `MraForm.tsx` — MRA studies (formType: `MRA`)
- `CtForm.tsx` — CT studies (formType: `CT`)
- `MriReferral.tsx` — retained for `/mri/page.tsx` standalone route only

---

## Twilio Configuration Reference

| Env Var | Value | Location |
|---|---|---|
| `TWILIO_ACCOUNT_SID` | `AC...` (stored in Render env vars) | Render cosmos-api |
| `TWILIO_AUTH_TOKEN` | (set) | Render cosmos-api |
| `TWILIO_FROM_NUMBER` | `+18777804236` (placeholder) | Render cosmos-api |

**Target FROM number:** `+17185695200` (718 NYC, $1.15/mo, purchase pending)

---

## SMS Templates (live)

1. **Appointment Confirmed** — Hi [Name], your appointment at Cosmos Medical has been confirmed.
2. **Appointment Reminder** — Hi [Name], this is a reminder about your upcoming appointment at Cosmos Medical.
3. **Please Call Our Office** — Hi [Name], please call our office at your earliest convenience.
4. **Documents Needed** — Hi [Name], we have outstanding documents that require your attention.
5. **Results Ready** — Hi [Name], your test results are ready for review.

---

## Roadmap Checklist

### Stage 1 — Core Clinical
- [x] Patient intake — PatientFormV2 5-tab wizard
- [x] Visit documentation — SOAP, CPT, ICD-10
- [x] NF-2 generation and mailing
- [x] AOB generation

### Stage 2 — Referral Management
- [x] Full referral lifecycle
- [x] MRI/MRA/CT body parts + session splitting
- [x] SONO/FC/PSY/EMG/ANS referral types
- [x] Auto-close on result upload
- [x] Referral workflow redesign — 7 statuses, all auto-transitions
- [x] MD review workflow removed
- [x] Appointment-driven dashboard (Session 50)
- [x] Multi-Referral tracking row (Session 50)
- [x] MRI stays `new` throughout lifecycle (Session 50)
- [x] Single appointment view at /referrals/[id]?appt= (Session 50)
- [x] Rebook flow from RESCHEDULE row (Session 50)
- [x] Referral detail page restyling — calendar design tokens (Session 51)
- [x] MD Referral Workspace — all 11 forms, onBack/onSaved, shared utils (Session 51)
- [x] MRI/MRA/CT split into 3 focused workspace forms (Session 51)
- [ ] DME and RX codes from patient_visits
- [ ] Patient email required at intake
- [ ] DEV artifacts removal

### Stage 3 — Front Desk Dashboard V2
- [x] Full FD Dashboard V2
- [x] SMS notification system
- [x] Referral dashboard appointment-driven (Session 50)
- [x] Documents Missing — intake form added (Session 51)
- [x] Bills Submitted KPI — visit count (Session 51)
- [x] Submit Bills KPI — full 4-gate (Session 51)
- [ ] Appointment confirmation SMS — auto-trigger on booking
- [ ] Patient phone required at intake
- [ ] Notes tab persistence
- [ ] Realtime — referrals and appointments tables

### Stage 4 — Admin
- [x] Admin Users — login email edit for superadmin (Session 51)
- [x] Admin Overview — KPI cards 3 per row (Session 51)

### Stage 5 — Infrastructure
- [ ] Render upgrade to Standard plan — pre-go-live blocker
- [ ] Twilio SMS activation
- [ ] 000_initial_schema.sql removal/replacement

### Stage 7 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel, Resend, Twilio
- [ ] SPF/DKIM for cosmosmt.com
