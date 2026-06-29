# Cosmos Medical Technologies — HANDOVER (June 29, 2026, session 6)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

All `cosmos-dashboard` commits confirmed deployed via `tsc --noEmit` +
full deploy chain. Live app confirmed healthy at session close.

---

## Completed This Session

### Admin Users Tab — live

Full user management from within Admin dashboard. No more Supabase
dashboard or manual SQL required for day-to-day user administration.

- **API route:** `app/api/admin/users/route.ts` — GET/POST/PATCH/DELETE
  using Supabase Admin client (`SUPABASE_SERVICE_KEY`).
- **`user_profiles.active`** column added (boolean, NOT NULL DEFAULT true)
  via `ALTER TABLE` migration. Controls Deactivate/Reactivate toggle.
- **`user_profiles` CHECK constraint** updated to include `superadmin`:
  `CHECK (role IN ('frontdesk','md','billing','admin','superadmin'))`.
- **PIN padding:** `padPin()` helper in `lib/supabase.ts` pads PINs to 6
  chars (Supabase Auth minimum). Applied on `signIn()`, POST (create),
  and PATCH (reset PIN). Existing test users reset via direct SQL:
  `UPDATE auth.users SET encrypted_password = crypt('999999', gen_salt('bf')) WHERE email IN (...)`.
- **Auth token forwarded:** all `UsersSection` fetch calls include
  `Authorization: Bearer <token>` header via `getToken()` helper.

### Superadmin Role — live

New `superadmin` role gives practice owner access to all four dashboards
from a single login.

- **Login screen** (`app/page.tsx`) fully rewritten in shadcn/ui +
  Oxanium font (replaces all inline styles). Three stages:
  `login` → `location` (MD multi-location picker) → `dashboard`
  (superadmin picker).
- **Superadmin dashboard picker:** 2×2 grid of dashboard tiles
  (Front Desk, MD, Billing, Admin). Gold crown badge. Sign out link.
- **`ROLE_META`** updated to include `superadmin` entry.
- **Role guard on API route:** non-superadmin callers cannot:
  - Create a superadmin account
  - Edit any user to assign the superadmin role
  - Modify or delete an existing superadmin account
  Enforced server-side via `getCallerRole()` which reads the Bearer token.

### Superadmin Provisioning Procedure

The first superadmin per client must be bootstrapped via Supabase SQL
(developer access required). Subsequent superadmins can be created
in-app by an existing superadmin.

**Bootstrap procedure:**
1. Create the user via Admin → Users tab with any role.
2. Promote via Supabase SQL editor:
   ```sql
   UPDATE user_profiles SET role = 'superadmin'
   WHERE id = (SELECT id FROM auth.users WHERE email = 'owner@practice.com');
   ```
3. Hand off credentials. The owner can create additional superadmins
   from within the app going forward.

### Active Users KPI Card — live

Overview tab KPI card now shows real count of active users from
`user_profiles WHERE active = true`. Previously showed `—`.

- State: `activeUserCount` added to `OverviewSection`.
- Fetched in the existing `Promise.all` alongside other KPI counts.

### UI Fixes — live

- **Quick Access Users button** — `'users'` added to the `admin-tab`
  event handler allowlist (was missing, button did nothing).
- **Practice Info card** — font sizes reduced (practice name 18px, all
  other fields 13px), padding tightened (`py-2.5`, `gap-1`).

---

## Open Items, Priority Order

1. **Appointment → Visit conversion** — "Checked In" status should enable
   pre-populated visit creation. Currently manual.

2. **NF-3 PC-payee mapping** — verify in a real generated PDF. Never
   confirmed across any session.

3. **NF-3 Pay-To: supervisor PC logic** — `forms/nf3.py` should fall
   through to supervisor's PC when `supervising_provider_id` is set.
   Deliberately deferred multiple sessions.

4. **Practice Info → NF-3 wiring** — `practice_settings` table exists and
   is NF-3-ready. Backend `forms/nf3.py` doesn't read it yet.

5. **`forms/base.py` `except Exception: pass`** — prohibited
   (`SYSTEM_PROMPT.md` §1/§8). Flagged 5+ sessions, never fixed.

6. **`w9_filler.py` in `cosmos-api` root** — legacy duplicate of
   `forms/w9.py`. Flagged 4 sessions, never removed.

7. **RLS hardening** — `patient_forms` RLS disabled entirely;
   `storage.objects` has one fully-open policy on `patient-forms` bucket.

8. **`patient_visits` doctor linkage gap** — `doctor_id` not reliably
   written at save time.

9. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
   uppercase convention for the other 7.

10. **MRI Extremity Studies + insurance fields** — backend ready, pure
    frontend work, never started.

11. **`cpt_codes.provider_type` backend wiring** — column exists, unused
    on both frontend and backend.

12. **Regenerate W-9s for existing doctors** — no bulk path. Low urgency.

13. **Desktop sidebar nav** — mockup confirmed target. Mobile-first
    remains immediate priority.

---

## Known Architecture Gaps

**Auth server-component gap:** `@supabase/auth-helpers-nextjs` installed
version does not export `createServerComponentClient` (TS2724). Server-side
session reads in server components are deferred. The `?doctor_id=` URL param
from the login screen is the reliable doctor-scoping path. Do not attempt to
use `createServerComponentClient` until confirmed exportable via:
`grep -r "createServerClient" node_modules/@supabase/auth-helpers-nextjs/dist/`

---

## File Confidence Levels (cumulative)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (this session — full shadcn rewrite, superadmin picker) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (this session — Users tab, active KPI, quick access fix, practice info spacing) |
| `cosmos-dashboard/app/api/admin/users/route.ts` | ★ Verified-final (this session — new file, full CRUD + superadmin guard) |
| `cosmos-dashboard/lib/supabase.ts` | ★ Verified-final (this session — padPin helper added) |
| `cosmos-dashboard/app/calendar/page.tsx` | ★ Verified-final (prior session — Phase 4, union availability, location badge) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (prior session — location badge added) |
| `cosmos-dashboard/middleware.ts` | ★ Verified-final (prior session — cookie-based route guard) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (prior session — simplified, no server auth read) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (prior session — signOut added) |
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final (prior session — signOut added) |
| `cosmos-dashboard/app/dev/page.tsx` | Obtained-current (prior session — no changes) |
| `cosmos-dashboard/app/layout.tsx` | Obtained-current (prior session — default scaffold) |
| `cosmos-dashboard/app/billing/page.tsx` | Obtained-current (prior session — server wrapper) |
| `cosmos-dashboard/app/lib/fonts.ts` | Obtained-current (prior session) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | ★ Verified-final (prior session) |
| `cosmos-api/main.py`, `pdf_engine.py` | ★ Verified-final (prior session) |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed — rest never seen in full |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained, any session |

---

## Lessons Learned This Session

- **Supabase Auth min password length** — default is 6 chars. PINs shorter
  than 6 are silently rejected by `updateUserById`. Fix: `padPin()` pads
  to 6 with trailing zeros. Applied at both `signIn()` and all admin PIN
  operations. Existing users must have PINs reset after this change.
- **`user_profiles` CHECK constraint** — adding a new role value requires
  `DROP CONSTRAINT` + `ADD CONSTRAINT`. Supabase doesn't support
  `ALTER CONSTRAINT`. Omitting this causes silent `user_profiles_role_check`
  violations on insert.
- **Service-role API guard pattern** — to enforce caller-role restrictions
  in a Next.js Route Handler using the service-role client, read the
  `Authorization: Bearer` header, call `supabase.auth.getUser(token)` with
  it, then look up `user_profiles.role`. Frontend must forward the session
  token via `supabase.auth.getSession()` on every mutating call.
- **Superadmin bootstrap** — first superadmin per deployment must be set
  via direct SQL. Subsequent superadmins can be created in-app by an
  existing superadmin. Document this in client onboarding checklist.
- **`/tmp` not writable in Termux** — use `~/` (home directory) for
  temporary Python patch scripts. Path for Termux home is
  `/data/data/com.termux/files/home/`.
