# Cosmos Medical Technologies — HANDOVER (July 3, 2026, Session 10)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` and `cosmos-api` commits confirmed deployed via
`tsc --noEmit` + full deploy chain. Live app confirmed healthy at session
close.

---

## Completed This Session

### `forms/base.py` — removed all `except Exception: pass` (P1 closed)

All silent exception swallowing eliminated from `forms/base.py`. Seven
sessions flagged, fixed this session:
- `requests` import failure: now logs `WARNING: requests not available`
- `fitz` import failure: now logs `WARNING: fitz (PyMuPDF) not available`
- `render_visible_text_in_rect`: now logs error instead of passing silently
- `format_date` inner/outer except: both now log parse errors

### `w9_filler.py` removed (P2 closed)

Legacy 120-line duplicate of `forms/w9.py` deleted from `cosmos-api` root.
Nothing imported it. Six sessions flagged, fixed this session.

### PDF filename casing normalized

`ortho.pdf` → `ORTHO.pdf`, `pain_mgmt.pdf` → `PAIN_MGMT.pdf`. Updated
`forms/ortho.py` line 44 and `forms/pain_mgmt.py` line 42 to match.
All 15 PDF templates now use uppercase filenames consistently.

### Practice Info → NF-3 wiring (P4 closed — won't do)

`practice_settings` feeds Admin Overview only. NF-3 billing is
correctly sourced per-doctor via `doctors` table. No wiring needed.

### Admin — Edit Provider header shows provider name in green

`CardTitle` on the provider edit form now renders:
`Edit Provider: <span style={{color:'#19a866'}}>Dr. {first} {last}</span>`
instead of generic "Edit Provider". New Carrier form got the same treatment:
`Edit Carrier: <span style={{color:'#19a866'}}>{carrier_name}</span>`.

### Admin — backend save errors surfaced inline (all sections)

Previously silent Supabase failures now show a red inline error message
below the Save button on every Admin save handler:
- Carriers, Lawyers, CPT Codes, ICD-10 — `saveError` state
- Practice Info — `practiceError` state
- Office Locations (Overview) — `locOvError` state
- Doctor Location Assignments — `locError` state
- Lawyers `alert()` replaced with inline error for consistency
- Providers section already had full try/catch — unchanged

**Side effect:** The error surfacing exposed a missing RLS policy on
`insurance_carriers` — `authenticated` role had no INSERT/UPDATE/DELETE
policies. Fixed via Supabase dashboard:
```sql
CREATE POLICY "authenticated all insurance_carriers"
ON public.insurance_carriers FOR ALL TO authenticated
USING (true) WITH CHECK (true);
```

### Admin — Insurance Carriers expanded

Three new columns added to `insurance_carriers` table:
- `claims_department text`
- `street2 text`
- `claims_email text`

Admin Carriers form updated with new fields. Carrier cards: name now cyan,
`m-0` on all text elements, shows `claims_department` and `claims_email`
when present. CSV batch import added (same pattern as CPT/ICD-10): upload
→ preview → confirm, skips duplicates by name. Top 20 NY No-Fault carriers
imported.

### MD Dashboard — logged-in doctor name in header

`MDClient.tsx` header now shows:
`👤 Dr. Yury Gottesman` (cyan) above `📍 Queens Location` (green).
Doctor name resolved from `doctorNameMap[doctorId]` — already available
from the `doctors` prop. Only MD/DO get "Dr." prefix.

### FD Dashboard — assigned provider on patient cards

Patient cards now show assigned provider inline:
`PT336816 · Progressive · Dr. Yury Gottesman (MD)`
Provider name in cyan; `⚠ No provider` in red when `doctor_id` is null.
Implemented via PostgREST join `doctors(first_name, last_name, license_type)`
in client-side `loadAll`. PostgREST returns joined rows as array — mapping
handles both array and object forms: `Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.
`Dr.` prefix only for `['MD', 'DO']` license types.

### FK constraint audit — Stage 1 complete

Full audit of all FK relationships. Added missing constraints:

| Constraint | Added this session |
|---|---|
| `patients.doctor_id → doctors` | Already existed |
| `appointments.patient_id → patients` ON DELETE CASCADE | ✅ Added |
| `appointments.doctor_id → doctors` | Already existed |
| `appointments.location_id → office_locations` | Already existed |
| `patient_visits.patient_id → patients` ON DELETE CASCADE | ✅ Added |
| `patient_visits.location_id → office_locations` | Already existed |
| `visit_line_items.visit_id → patient_visits` ON DELETE CASCADE | ✅ Added |
| `visit_line_items.patient_id → patients` ON DELETE CASCADE | ✅ Added |
| `doctor_locations.doctor_id → doctors` | Already existed |
| `doctor_locations.location_id → office_locations` | Already existed |
| `user_profiles.doctor_id → doctors` | Already existed |

All FK constraints are now in place across the schema.

---

## Open Items, Priority Order

1. **NF-3 visual verification — independent provider (no corp)** — P3.
   Susan Martinez is assigned to Gottesman (confirmed in DB). Generate NF-3
   for her and verify Page 1 Pay-To, Page 2 Section 16, Page 3 bottom row
   all populate from Gottesman's own data (not a supervisor fallback).

2. **Dev generator fix** — `app/dev/page.tsx` may be creating patients with
   `doctor_id = null`. Confirmed two patients (Susan Martinez, Sandra Gonzalez)
   had null `doctor_id` despite the Session 8 fix. Root cause unconfirmed —
   may be pre-Session 8 data or a generator bug. Audit the generator and
   RLS on `patients` INSERT before next data wipe.

3. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend work, never started.

4. **`cpt_codes.provider_type` backend wiring** — column exists, unused.

5. **Desktop sidebar nav** — confirmed product direction. No design or
   implementation work started.

6. **DME provider certification fields blank** — `forms/dme.py` has never
   been obtained or audited.

7. **Full RLS audit** — enterprise hardening Stage 1 item. Every table,
   every command (SELECT/INSERT/UPDATE/DELETE), both `anon` and `authenticated`.
   FK audit complete; RLS audit is next.

---

## Enterprise Hardening Checklist (running)

Introduced this session. Updated incrementally each session.

### Stage 1 — Data Integrity
- [x] FK constraints — all tables audited and complete (this session)
- [ ] Full RLS audit — every table, every command, both roles
- [ ] `NOT NULL` constraints on required columns

### Stage 2 — Security
- [ ] API JWT authentication on all `cosmos-api` endpoints
- [ ] Session timeout / auto sign-out after inactivity
- [ ] Failed PIN attempt lockout
- [ ] MFA for admin and billing roles
- [ ] HIPAA BAA with Supabase
- [ ] Audit log table (who changed what, when)

### Stage 3 — Infrastructure
- [ ] Staging environment (Vercel preview + Render staging)
- [ ] GitHub Actions CI (auto `tsc --noEmit` + `py_compile` on push)
- [ ] Database indexes on all FK and common filter columns
- [ ] Supabase point-in-time recovery confirmed enabled
- [ ] Error monitoring (Sentry or equivalent)

### Stage 4 — Code Quality
- [ ] Replace all `print()` in `cosmos-api` with structured Python `logging`
- [ ] Eliminate remaining `any` types — TypeScript strict mode
- [ ] React error boundaries on all dashboard surfaces
- [ ] Loading states on all data fetches
- [ ] Dev generator fix (patients always get `doctor_id`)

### Stage 5 — Product & UX
- [ ] Desktop sidebar nav
- [ ] Holistic UX audit
- [ ] Accessibility (ARIA, keyboard nav)
- [ ] Multi-tenancy for commercial SaaS

### Stage 6 — Compliance
- [ ] HIPAA compliance review
- [ ] BAA with Supabase, Render, Vercel
- [ ] Data retention and deletion policy
- [ ] Patient data export capability

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` installed
version does not export `createServerComponentClient` (TS2724). Server-side
session reads in server components are deferred. The `?doctor_id=` URL param
from the login screen is the reliable doctor-scoping path.

**`patient_visits.doctor_id` missing:** Column does not exist in schema.
Visit-to-doctor linkage currently relies on `patients.doctor_id`
(one-doctor-per-patient assumption). `patient_visits.location_id` was added
in migration 016.

**PA/NP users require `doctor_id` in user_profiles:** The location picker
on login requires `doctor_id` to be set on the user's profile row. PA/NP
users created before Session 9's fix may have `doctor_id = null` — must be
edited in Admin → Users.

**PostgREST join shape:** Supabase PostgREST returns FK-joined rows as an
array even for many-to-one relationships (e.g. `patients.doctor_id →
doctors` returns `doctors` as `[{...}]` not `{...}`). All client-side
join consumers must handle both shapes:
`const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — carrier CSV import/new fields, inline save errors, Edit Carrier/Provider green name headers) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (this session — assigned provider on patient cards, PostgREST array join fix, license type + Dr. prefix logic) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (this session — logged-in doctor name in header) |
| `cosmos-dashboard/app/dashboard/page.tsx` | ★ Verified-final (this session — reverted to select(*) after join broke server props) |
| `cosmos-api/forms/base.py` | ★ Verified-final (this session — all except Exception: pass removed) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (session 9 — location edit/main-office, card spacing, PA/NP roles, SelectTrigger color, supervised validation, linked doctor for PA/NP) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (session 9 — PA/NP ROLE_META, location picker for pa/np) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (session 9 — location_id on Start Visit, Appointment interface) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (session 9 — session location_id on manual visit INSERT) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (session 9 — full Pay-To/sig/place-of-service wiring) |
| `cosmos-api/database.py` | ★ Verified-final (session 9 — _build_doctor_fields, mailing_* columns, supervisor fields) |
| `cosmos-api/main.py` | ★ Verified-final (session 9 — office location lookup for place_of_service_address) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (this session — ORTHO.pdf/PAIN_MGMT.pdf filename fix) |
| `cosmos-dashboard/app/api/wipe-patients/route.ts` | ★ Verified-final (session 8) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (session 8 — real doctors/carriers/attorneys; doctor_id null bug unresolved) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (session 8) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (session 7) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (session 7) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **PostgREST FK join returns array, not object.** Even for a many-to-one
  relationship (e.g. `patients.doctor_id → doctors`), PostgREST returns the
  joined table as `[{...}]` not `{...}`. Always handle both:
  `const d = Array.isArray(p.doctors) ? p.doctors[0] : p.doctors`.
- **Server-side `select('*')` and client-side join must stay in sync.**
  Adding a join to the server component's `select()` changes the data shape
  passed as `initialPatients` props — breaking client-side filters that
  expect flat patient objects. Keep server fetch as `select('*')` and let
  `loadAll` client-side re-fetch handle joins.
- **`insurance_carriers` was missing `authenticated` RLS policies.** The
  inline error surfacing (new this session) immediately caught this — the
  error "new row violates row-level security policy" appeared on Save instead
  of silently failing. Inline error feedback is now a first-class debugging
  tool for RLS gaps.
- **FK constraints were largely already in place.** The `patients_doctor_id_fkey`
  and most `appointments` FKs existed. The gaps were on `visit_line_items`
  (completely unlinked) and `appointments.patient_id`. The incremental audit
  approach (verify before adding) prevented duplicate constraint errors.
