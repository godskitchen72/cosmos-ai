# Cosmos Medical Technologies — HANDOVER (July 3, 2026, Session 9)

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

### Admin UI — card spacing / visual polish

Practice Info card, Office Location cards, and User cards: removed empty-line
gaps — `gap-0` on flex containers + `m-0` on all `<p>` elements. Matches
the tight provider card layout established in Session 8. Supervisor billing
card inside the provider form also tightened.

### Admin — office location Edit button + Main Office flag

Office location cards now have an **Edit** button in manage mode (populates
form, shows "Edit Location" title, "Save Changes" button). Added `is_main_office`
boolean to `office_locations` table (migration 015). Main office sorted first,
rendered with cyan border `border-[#00cfff]`; all other locations use purple
`border-[#a855f7]`. Add/Edit form includes a custom toggle (cyan checkbox)
for marking main office — only one location can be main at a time (mutual
exclusivity enforced on save).

### Admin — supervised provider border color

Provider cards for supervised providers (PA, NP, DC, PT, PSY, etc.) changed
from dim white `border-[#ffffff18]` to purple `border-[#a855f7]`, consistent
with their corp name color.

### Admin — SelectTrigger dark-on-dark fix

All `SelectTrigger` elements in the Admin panel now have `style={{color:'#f0f4f8'}}`
explicitly set — fixes the "selected value invisible" bug caused by the
preflight gap (`AI_STYLE_GUIDE.md` §1, `ARCHITECTURE.md` §10).

### Admin — PA and NP user roles

`user_profiles_role_check` constraint updated to include `pa` and `np`.
Role dropdown now shows: Front Desk / MD / PA / NP / Billing / Admin /
Superadmin with human-readable labels via `ROLE_LABELS`. Role badge colors:
PA = blue `#3b82f6`, NP = purple `#8b5cf6`, Superadmin = red `#e74c3c`.
"Linked Doctor" field now shown for PA and NP roles (previously MD-only) —
required for location picker to work on login. `doctor_id` is not cleared
when switching between md/pa/np roles.

### Login — PA and NP location picker

`app/page.tsx` `ROLE_META` extended with `pa` and `np` entries (both route
to `/md`). `navigate()` and `handlePostLogin()` updated: location picker
shown for `['md', 'pa', 'np']` instead of `md` only. PA/NP users get the
same session location flow as MDs — `cosmos_location_id` stored in
`sessionStorage`.

### NF-3 — full Pay-To / signature / place-of-service wiring

Major compliance work this session:

**`database.py`** — refactored to `_build_doctor_fields()` shared helper:
- Reads `mailing_street/city/state/zip` (migration 014 columns) for Pay-To address
- Supervisor fallback: if `supervising_provider_id` is set, fetches supervisor
  row and uses their `mailing_*` + `pc_corp_name` for Pay-To, plus exports:
  `supervisor_npi`, `supervisor_tax_id`, `supervisor_specialty`,
  `supervisor_signature_url`, `supervisor_name`
- `doctor_license_type` exported for NF-3 Section 16 title field
- `get_doctor_by_id` delegates to shared helper (no duplicate logic)

**`forms/nf3.py`**:
- Page 1 `provider.name_address` → PC corp name + mailing address ✅
- Page 2 Section 15 place of service → `place_of_service_address` from
  office location (street / city, state zip — two-line format)
- Page 2 Section 16 treating provider title → `doctor_license_type` (PA/NP/MD)
- Page 2 Section 16 license/cert no. → treating provider's own NPI
- Page 3 `assignment.provider_assignee_print_name` → PC corp name (payee_name)
- Page 3 `assignment.provider_assignee_signature` → supervisor signature
- Page 3 `provider.signature` (bottom) → supervisor signature
- Page 3 `provider.irs_tin` → supervisor name (Gottesman's name in billing name field)
- Page 3 `provider.wcb_rating_code` → supervisor NPI
- Page 3 `provider.specialty_if_none` → supervisor specialty
- `billing_npi`, `billing_tax_id`, `billing_specialty` derived from supervisor
  when PC corp exists, else treating provider's own values
- `_p2_vals()` signature extended with `billing_npi` parameter (fixes NameError)
- Signature injection split: `assignee_sig_bytes` (supervisor) for both
  `provider_assignee_signature` and `provider.signature`; `treating_sig_bytes`
  retained in vars but not injected (both sig fields now use supervisor)

**`main.py`**:
- After visit row merge, fetches `office_locations` using `visit.location_id`
  and adds `place_of_service_address` (two-line: `street\ncity, state zip`)

**`cosmos-dashboard/app/calendar/page.tsx`**:
- `handleStartVisit` now writes `location_id: apt.location_id || sessionStorage.getItem('cosmos_location_id') || null`
- `Appointment` interface extended with `location_id?: string`

**`cosmos-dashboard/app/md/[patientId]/PatientChart.tsx`**:
- Manual visit INSERT now includes `location_id: sessionStorage.getItem('cosmos_location_id') || null`

**Migration 016** — `patient_visits.location_id uuid REFERENCES office_locations(id)` added.

**Backfill SQL** run to populate `location_id` on existing NULL visits:
```sql
UPDATE patient_visits pv
SET location_id = a.location_id
FROM appointments a
WHERE a.patient_id = pv.patient_id
  AND a.location_id IS NOT NULL
  AND pv.location_id IS NULL;
```

### Admin — supervised provider validation fix

Mailing address, tax classification fields are now optional for supervised
providers (PA, NP, DC, PT, PSY — anyone with `supervising_provider_id`).
These providers inherit billing info from their supervisor. Independent
providers still require all mailing address fields.

On validation failure, form now auto-switches to the tab containing the
first error (Billing tab if billing fields fail, Credentials tab otherwise).

### Admin — NF-3 treating provider title

Section 16 title field now uses `doctor_license_type` — shows "PA", "NP",
"MD" correctly per provider. Previously hardcoded to "MD".

---

## Open Items, Priority Order

1. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 7+ sessions, never fixed.

2. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 6 sessions, never removed.

3. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet. Lower
   priority now that Pay-To/mailing address wiring is complete.

4. **NF-3 visual verification — independent provider (no corp)** — full
   NF-3 wiring verified for supervised providers (Dr. Orthobot under
   Gottesman). Need a regression check: generate NF-3 for a patient whose
   doctor is an independent MD (no `supervising_provider_id`) — confirm
   all bottom-row fields still populate correctly from their own data.

5. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
   uppercase convention for the other 7.

6. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend work, never started.

7. **`cpt_codes.provider_type` backend wiring** — column exists, unused.

8. **Desktop sidebar nav** — confirmed target. System intended for desktop
   use. Mobile-first was the dev-environment constraint. Desktop layout
   (sidebar, wider containers, multi-column) is a high-priority product
   goal.

9. **Existing doctor records missing mailing address** — Dr. Gottesman,
   Dr. Orthobot, Dr. Pearlman, Dr. Kramer predate migration 014 and have
   blank `mailing_*` fields. Must be edited in Admin → Providers → Billing.

10. **DME provider certification fields blank** — Provider Name, License,
    NPI, Signature missing from DME referral PDF. Pre-existing gap, not
    introduced this session. `forms/dme.py` has never been obtained/audited.

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` installed
version does not export `createServerComponentClient` (TS2724). Server-side
session reads in server components are deferred. The `?doctor_id=` URL param
from the login screen is the reliable doctor-scoping path.

**`patient_visits.doctor_id` missing:** Column does not exist in schema.
Visit-to-doctor linkage currently relies on `patients.doctor_id`
(one-doctor-per-patient assumption). `patient_visits.location_id` was added
this session (migration 016).

**PA/NP users require `doctor_id` in user_profiles:** The location picker
on login requires `doctor_id` to be set on the user's profile row. PA/NP
users created before this session's fix to show the "Linked Doctor" field
for those roles may have `doctor_id = null` — must be edited in Admin →
Users to link them to their provider record.

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — location edit/main-office, card spacing, PA/NP roles, SelectTrigger color, supervised validation, linked doctor for PA/NP) |
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (this session — PA/NP ROLE_META, location picker for pa/np) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (this session — location_id on Start Visit, Appointment interface) |
| `cosmos-dashboard/app/md/[patientId]/PatientChart.tsx` | ★ Verified-final (this session — session location_id on manual visit INSERT) |
| `cosmos-api/forms/nf3.py` | ★ Verified-final (this session — full Pay-To/sig/place-of-service wiring, billing_npi param fix, license_type title, treating NPI in Section 16) |
| `cosmos-api/database.py` | ★ Verified-final (this session — _build_doctor_fields, mailing_* columns, supervisor fields, doctor_license_type) |
| `cosmos-api/main.py` | ★ Verified-final (this session — office location lookup for place_of_service_address, two-line format) |
| `cosmos-dashboard/app/api/wipe-patients/route.ts` | ★ Verified-final (session 8 — appointments cascade) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (session 8 — real doctors/carriers/attorneys) |
| `cosmos-api/forms/w9.py` | ★ Verified-final (session 8 — reads mailing_* columns) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (session 7 — full CRUD + superadmin guard) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (session 7 — padPin helper) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained |

---

## Lessons Learned This Session

- **Termux `sed` with nested quotes is fragile.** When a `sed` command
  contains single and double quotes, the escaping in Termux's shell often
  fails silently (no error, no change). For any sed replacement touching
  complex strings, prefer a Python patch script or the Claude container
  patch approach over inline Termux sed.
- **Chrome duplicate-download suffix is session-persistent.** If a file
  with a given name has ever been downloaded in the current Chrome session,
  subsequent downloads of the same filename append `-1`, `-2`, etc. —
  even after the original is used. Always run `ls -lt ~/storage/downloads/<name>*`
  before `cp` and use the newest file by timestamp, not bare filename.
- **`fitz` (PyMuPDF) is not available in Termux Python.** Commands that
  import `fitz` directly in Termux (e.g. to enumerate PDF field names)
  will fail with `ModuleNotFoundError`. PDF field inspection must be done
  on the Render/production environment or via `pypdf` in a separate step.
- **NF-3 signature fields:** Both `provider_assignee_signature` and
  `provider.signature` (bottom row) use the supervisor/billing MD's
  signature. Treating provider's signature is not injected into the NF-3
  at all — the NF-3 is a billing document, not a clinical one.
- **PA/NP location picker requires `doctor_id` in `user_profiles`** —
  the location fetch uses the user's linked `doctor_id` to find their
  assigned locations. Linking in the providers table is not sufficient;
  the user account itself needs `doctor_id` set.
- **Supervised provider mailing address validation** — requiring mailing
  address for supervised providers (PA, NP) blocks valid saves. Supervised
  providers inherit billing info from their supervisor; their own mailing
  address fields should be optional.
