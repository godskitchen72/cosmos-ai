## 2026-07-05 — Session 19 (continued)

### CPT and ICD-10 admin section fixes

**Edit form visibility** (`CptCodesSection.tsx`, `Icd10Section.tsx`):
Edit form moved from bottom to top of section. `useRef` +
`scrollIntoView({ behavior: 'smooth', block: 'start' })` fires on
`editing` state change. Root cause: sidebar layout introduced an
independent scroll context; bottom-rendered form was below the viewport
and appeared as if Edit did nothing.

**CPT price layout** (`CptCodesSection.tsx`):
Price moved inline after CPT code badge — `[98940] $68.15` on one row,
description below. Eliminates one row per card.

**Active/Inactive toggle** (both sections):
`<input type="checkbox">` replaced with a styled pill button.
`● Active` (green `#19a866`) / `○ Inactive` (red `#e74c3c`).
Checkbox was visually ambiguous on dark theme.

**ICD-10 download template** (`Icd10Section.tsx`):
`⬇ Download Import Template` link added matching CPT pattern.
Template: `code, description, category` columns with 2 format
example rows (one Cervical, one Lumbar).

**CPT download template updated** (`CptCodesSection.tsx`):
Hardcoded blob updated from placeholder data to real NY No-Fault
codes with accurate fee schedule amounts and linked ICD-10s.

---

## 2026-07-05 — Session 19

### Admin sidebar nav — complete

`app/admin/page.tsx` updated to replace the horizontal tab strip with a
collapsible left sidebar. Single file change — all 8 section components
and `shared.tsx` are unchanged.

**Design:**
- Collapsible toggle (☰ expand / ✕ collapse), button in header left
- Collapsed: sidebar fully hidden, content takes full width
- Expanded: 200px left rail, labels only (emoji stripped via `stripEmoji()`)
- Active tab: `2px solid #00cfff` left border + cyan text
- Preference persisted in `localStorage` key `cosmos_admin_sidebar_open`
- Defaults to expanded on first load

**Scope:** Admin only this session. FD, MD, Biller sidebar rollout deferred —
template is proven, rollout is mechanical repetition.

**Header correction:** ← Back button moved before ⇄ Sign Out (order was
reversed in prior version).

---

## 2026-07-05 — Session 18

### Admin page refactor — complete

Pure structural refactor of `app/admin/page.tsx` (2,761 lines → 114-line
shell). Zero behavioral changes. All 8 tabs confirmed working in production.

**New file structure:**

```
app/admin/
  page.tsx                    ← shell only, 114 lines
  shared.tsx                  ← shared helpers, components, constants (264 lines)
  components/
    OverviewSection.tsx        (543 lines)
    CarriersSection.tsx        (320 lines)
    DoctorsSection.tsx         (803 lines)
    LawyersSection.tsx         (186 lines)
    CptCodesSection.tsx        (424 lines)
    Icd10Section.tsx           (310 lines)
    UsersSection.tsx           (306 lines)
    AuditLogSection.tsx        (257 lines)
```

**`shared.tsx`** exports all cross-section utilities: `getAuthToken`,
`PDF_API_URL`, `formatPhone`, `Field`, `SectionHeading`, `STATES`,
`StateSelectField`, `SignaturePad`, `TAX_CLASS_OPTIONS`, `LLC_CLASS_OPTIONS`,
`SPECIALTY_OPTIONS`, `LICENSE_TYPE_OPTIONS`, `BLANK_DOCTOR`, `PROVIDER_TYPES`.

**Preserved intact:** `useMemo` on `filtered` in `AuditLogSection` (prevents
TanStack Table infinite re-render freeze). `admin-tab` custom event listener
in shell `page.tsx`. All handler logic byte-for-byte identical to original.

---

## 2026-07-05 — Session 18 prep / Session 17 final

### Audit Log — full implementation (Enterprise Hardening Stage 2 complete)

**Migration 023:** `audit_logs` table with indexes and RLS (authenticated
SELECT + INSERT).

**DB triggers** — `log_audit_event()` PLPGSQL function on 7 tables:
`patients`, `patient_visits`, `visit_line_items`, `doctors`,
`insurance_carriers`, `user_profiles`, `practice_settings`. Captures
old/new data as jsonb. User attribution shows "System" — no PostgreSQL
session context available in trigger functions.

**`app/lib/auditLogger.ts`** — new shared helper. `writeAuditLog()` reads
current session user + role from `user_profiles`, inserts attributed entry
into `audit_logs`. Never throws — audit failures must not break main flow.

**Frontend audit calls added to:**
- `app/page.tsx` — login success, login failed, MFA verified
- `app/patients/[patientId]/PatientProfile.tsx` — NF-2/AOB generated,
  NF-3 preflight confirmed, submitted to billing
- `app/billing/BillerDashboard.tsx` — NF-3 generated, claim status changed,
  received amount updated, MD flagged
- `app/md/[patientId]/PatientChart.tsx` — visit created/updated, flag
  accepted, flag rejected

**Admin Audit Log tab** — shadcn/TanStack Table, last 500 entries
newest-first, category filter chips, search, pagination. Fixed freeze:
`useMemo` on filtered data.

---

## 2026-07-05 — Session 17 (final)

### MFA for admin/billing/superadmin

TOTP-based MFA via Supabase Auth. `practice_settings.mfa_required boolean DEFAULT false`.
Setup screen (QR + manual key), challenge screen (6-digit code), 30-day
device trust via `localStorage`. Reset MFA button in Users tab.
`app/api/admin/users/route.ts` — `reset_mfa: true` PATCH handler.

### PIN attempt lockout

Migration: `login_attempts` table. 5 failures in 15-minute window →
account locked with minutes-remaining display. Auto-expires. RLS must
include `anon` role.

### NF-3 workflow redesign

NF-3 generation moved from FD to Biller. FD becomes preflight-only.
Migrations 020–022. `biller_md_flags` table for CPT/ICD-10 flagging
workflow between Biller and MD.

### IcdReferral.tsx — Authorization header fix

Missing `getAuthToken()` + `Authorization: Bearer` header added.

### Biller docs column layout

Docs column badges now render in single horizontal `nowrap` row via
inline `style={{ flexWrap:'nowrap' }}`.

---

## 2026-07-05 — Session 16

### Documentation update only

No code written or deployed. `CHANGELOG.md`, `ARCHITECTURE.md`,
`HANDOVER.md` updated for Sessions 15–16.

---

## 2026-07-04 — Session 15

### Dev Tools — full rebuild (`app/dev/page.tsx`)

Real DB data, visit count selector, DOI guard, live CPT codes, Max MD
mode, individual referral selectors, Render warm-up ping.

### W9 supervisor-chain fix

`supervising_provider_id` added to billing query. `doctorWithW9` resolver
walks supervisor chain in `BillerDashboard.tsx`.

---

## 2026-07-04 — Session 14 (concluded)

### CPT importer — many-to-many ICD-10 mapping

Deduplication, `cpt_icd10_map` upsert, RLS fix on `icd10_codes`,
Download Template link added.

---

## 2026-07-04 — Session 13

### CosmosUI standard — fully adopted app-wide

All referral screens + calendar migrated. Native `alert()`/`confirm()`
eliminated app-wide.

### Enterprise Hardening Stage 2 — API JWT + Session timeout

All 15 POST endpoints protected with `verify_jwt`. Session timeout hook
across all four dashboards. Migration 019.

---

## 2026-07-04 — Session 12

### Enterprise Hardening — RLS audit, NOT NULL constraints, NF-3 regression fix

Full RLS audit — all anon/public policies removed. Migration 018 NOT NULL
constraints. MRI Referral full rebuild. CPT codes filtered by license type.
CosmosUI notification standard introduced.

---

## 2026-07-04 — Session 11

NF-3 patient signature gate. W9 entity-based scoping rule. Supervisor W9
routing. NF-3 Section 16 license number fix. AOB billing entity resolution.

---

## 2026-07-03 — Session 10

`forms/base.py` exception suppression removed. `w9_filler.py` removed.
PDF filename casing normalized. FK constraint audit complete. NF-3 full
regression passed.

---

## 2026-06-29 — Phase 4, union availability, location badge, Admin day blocking

Scheduling Phase 4 — MD login location pre-filters calendar.
Union-of-locations availability. Admin blocked days in location form.

---

## 2026-06-29 — Scheduling Phase 3A, timezone fix, appointments RLS

Scheduling Phase 3A live. `localDateStr()` timezone fix. RLS on appointments.

---

## 2026-06-28 — Auth foundation, Phase 3 location picker, RLS authenticated fix

Full authentication implementation. RLS authenticated role. Scheduling Phase 3B live.

---

## 2026-06-28 — Admin dashboard expansion: Overview, CPT/ICD-10, Locations, Scheduling Phase 1+2

Admin Overview tab, CPT Codes + ICD-10 tabs, Providers improvements.
Migrations 010 (`practice_settings`, `office_locations`), 011 (`doctor_locations`).

---

# Cosmos Medical Technologies — CHANGELOG

Append-only. Entries in reverse chronological order. Never renumber,
never delete. Each entry records only what actually shipped.
