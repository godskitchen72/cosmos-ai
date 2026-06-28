# Cosmos Medical Technologies — HANDOVER (June 28, 2026, session)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all six documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

Both repos were touched this session. All `cosmos-dashboard` commits
confirmed deployed via `tsc --noEmit` + full deploy chain output per
commit. `cosmos-api` had one cleanup commit confirmed. Live app confirmed
healthy at session close.

**The Save→View unconfirmed delivery from the prior session remains
unresolved.** This session did not verify it — check this first before
touching any referral screen (see Unconfirmed Delivery below).

---

## Unconfirmed Delivery — Check This First

The Save→View button-pattern rollout (8 referral screens: DME, Ortho,
Pain Mgmt, ANS, MRI, PT, Rx, VNG — ICD-10 deliberately excluded) was
built and delivered in a prior session. **Neither batch's actual deploy
output was ever confirmed.** This has now carried across two sessions
without resolution.

Before touching any referral screen:

```
cd ~/cosmos-dashboard
git log --oneline -10
```

Look for: `"Switch DME/Ortho/Pain Mgmt referrals to Save/View pattern..."`
and `"Switch all remaining referral types to Save/View pattern"`. If
either is missing, the files may be on-device but undeployed — re-run
the validate+deploy chain before building further on those screens.

---

## Completed This Session

### cosmos-api — orphaned PDF template cleanup

Commit `672f582`: removed `Cosmos_Orthopedic_Surgeon_Referral_Enterprise_
Fillable.pdf` and `Pain_MGMT_Referral_Enterprise_v3_Fillable.pdf` from
repo root — confirmed true orphans (both `forms/ortho.py` and
`forms/pain_mgmt.py` already pointed at `ortho.pdf`/`pain_mgmt.pdf`;
the long-named files were mentioned only in docstring comments, not in
any active code path). Also flagged: `w9_filler.py` at repo root appears
to be a legacy duplicate of `forms/w9.py` — not removed this session,
out of scope.

### cosmos-dashboard — Admin promoted to first-class role

Commit `efe32ef`: removed `soon:true` from the Admin role tile on
`app/page.tsx` (Admin is now selectable alongside Front Desk, MD,
Billing), updated subtitle from stale "Staff · Settings · Developer
tools" to "Carriers · Doctors · Lawyers" (matching actual content),
and removed the buried "⚙️ Admin" button from Front Desk's Patients tab
(`DashboardClient.tsx` line 675) — Admin is now reachable from
role-select and the `⇄ Role` switcher in every dashboard header, making
the Front Desk shortcut redundant.

### cosmos-dashboard — `doctors` schema extension

SQL migration `009_add_doctor_license_type_and_supervising.sql` run
against live Supabase:
- `license_type text DEFAULT 'MD'` — new column. Backfilled: DC for
  Chiropractor, PT for Physical Therapy, Acupuncturist, Psychologist,
  Podiatrist records; corresponding `specialty` values cleared to NULL
  (specialty now reserved for MD subspecialties only). All existing MDs
  defaulted to 'MD' without touching their `specialty`.
- `supervising_provider_id uuid REFERENCES doctors(doctor_id)` — self-
  referencing FK, no `ON DELETE` (blocks deletion of a doctor who is
  currently someone's supervisor). RLS audit confirmed complete policy
  set (SELECT/INSERT/UPDATE/DELETE all present for `anon` role). Round-
  trip write test confirmed both columns persist correctly.

### cosmos-dashboard — Admin page rebuilt in shadcn/ui

Commit `c87fc6f` (full rebuild, 520 insertions / 373 deletions):
- All three sections (Carriers, Lawyers, Providers) ported to
  `Card`/`Input`/`Button`/`Select`/`Badge` shadcn primitives.
- `DropdownSelect`/`StateSelect` imports removed entirely; replaced with
  shadcn `Select` + an inline `StateSelectField` component backed by
  the full 50-state list (prior `StateSelect` only had 10 states).
- Zero native `<select>` elements remain on this page.
- Doctor form broken into 4 tabs: **General** (name, license type,
  specialty, supervising provider, contact, address), **Credentials**
  (NPI, license #, signature capture), **Billing** (PC corp, tax
  classification, registered address, TIN), **Schedule** (available
  days, max patients per day).
- Doctor list cards now show `license_type` badge + `specialty` badge
  side by side.
- **This is the second shadcn/ui scoped exception** after the Biller
  dashboard. `ARCHITECTURE.md` §1 styling note updated accordingly
  (`SYSTEM_PROMPT.md` §9 / `AI_STYLE_GUIDE.md` §2 cover the
  exception policy).

Commit `6b0caa4` (pre-shadcn-rebuild patch, now superseded by the full
rebuild but landing order matters): added License Type + Supervising
Provider fields, pruned specialty dropdown to MD subspecialties only.

### cosmos-dashboard — Admin Oxanium + typography pass

Commit `e7cdb13` (inferred from deploy chain): Oxanium Light applied
to all text across `app/admin/page.tsx` — root div, all `p`/`label`/
`button`/`CardTitle`/`SectionHeading` elements. Text size increases:
`10px → 12px` for secondary text, `11px → 13px` for labels/tab
buttons/section headings. Inactive tab labels changed from `#4a6080`
to `#e2e8f0` (bright gray) on both the top nav strip and the Doctor
form tab strip.

### cosmos-dashboard — Billing tab: supervisor-aware layout

Commit `ce4b604`: when a provider has a `supervising_provider_id` set,
the Billing tab now shows:
1. A read-only green-tinted block displaying the supervising MD's PC
   Corp Name, registered address, tax classification, and TIN — labeled
   "Billing Under Supervisor's PC."
2. A collapsible "Override billing info for this provider" toggle below,
   which expands to show the provider's own editable PC fields.
3. PC-field validation (`pc_corp_name`/`pc_street`/`pc_city`/`pc_state`/
   `pc_zip` required) is skipped when a supervisor is assigned — own PC
   fields are optional when billing flows through the supervisor's PC.

Business rule confirmed: in NY No-Fault practices, supervised service
providers (PT, DC, Psychologist, etc.) bill under the supervising MD's
PC corporation. NF-3 Pay-To Provider logic is **not yet updated** to
reflect this — flagged as future work, deliberately deferred until the
broader NF-3 mapping work is scoped.

### cosmos-dashboard — MD dashboard: supervised-providers toggle

Three commits (`9c1d8f1`, `39cb8ec`, `265cc5c`):
- `md/page.tsx`: added a fourth parallel query — fetches `doctor_id`
  values from `doctors` where `supervising_provider_id = doctorId`.
  Passes result down as `supervisedDoctorIds: string[]`.
- `MDClient.tsx`: checkbox "Include supervised providers' patients"
  appears below the doctor selector only when a specific doctorId is
  selected AND that doctor actually supervises at least one other
  provider. Default: unchecked. When checked, a client-side Supabase
  query fetches patients whose `doctor_id` is in `supervisedDoctorIds`,
  deduplicates against own patients, and merges the list. Header patient
  count shows `'…'` while loading, then the real merged count.
- Supervised patients show a small amber badge below their name: e.g.
  "Dr. Ron Pearlman" — uses the `doctors` list already passed down to
  build a `doctor_id → display name` map.
- Live test confirmed: selecting Dr. Gottesman (who supervises Dr.
  Pearlman) shows the checkbox; checking it loads Pearlman's patients
  with the "Dr. Ron Pearlman" badge.

### cosmos-dashboard — Dev Tools in Admin + dev page rebuild

Commit `540deb5`: Dev Tools link card added at the bottom of every
Admin tab — red-bordered card with description and "Open →" button
navigating to `/dev`. The hidden footer link on `app/page.tsx` (`/dev`)
remains; the card gives it proper discoverability from Admin.

Commit `74371fa`: `app/dev/page.tsx` fully rebuilt in Oxanium/shadcn —
same header pattern as admin, `Card`/`Button` components, Oxanium on
all text. Also cleaned up a pre-existing issue: the dev page was creating
its own Supabase client via `createClient` directly; now uses the shared
`@/lib/supabase` import like every other page.

---

## Open Items, Priority Order

1. **Confirm the Save→View deploy landed** — check before anything else
   touches a referral screen (see Unconfirmed Delivery above, open since
   the prior session).
2. **End-to-end verify the VNG v5 template** with a real generated PDF
   — open across 5+ sessions now.
3. **Verify the NF-3 PC-payee mapping** in a real generated PDF — never
   confirmed, untouched this session.
4. **Regenerate W-9s for every existing doctor** — no bulk path exists
   (`PRODUCT_SPEC.md` §5).
5. **Data integrity audit** — historical `cpt_codes`/`icd10_codes`
   possibly stale from the previously-fixed RLS bug.
6. **NF-3 Pay-To Provider: supervisor PC logic** — when a provider has
   a supervising MD, the NF-3 Pay-To box should reflect the supervisor's
   PC corporation. Backend `forms/nf3.py` currently reads PC fields from
   the treating doctor's own record. Deliberately deferred this session.
7. **Admin Overview tab** — KPI cards (Total Providers, Documents,
   System Status), Recent Providers list, Quick Access shortcuts. All
   data already exists; no new schema needed. Target mockup provided by
   product owner this session (see session notes).
8. **Admin phase 2: new data concepts** — Office Locations, Users,
   Roles & Permissions, Organizations. Each requires new Supabase tables
   before any UI work.
9. **Reference Data tab** — CPT Codes and ICD-10 Codes admin UI (tables
   exist, no edit UI). Insurance Carriers and Attorneys/Lawyers already
   exist as separate tabs — decision pending on whether to consolidate
   under a "Reference Data" grouped tab.
10. **FD and MD shadcn rebuilds** — explicitly deferred to their own
    dedicated session. FD has 4 tabs + appointment scheduling; MD has
    the patient list plus all referral/chart sub-routes. Too large for
    end-of-session work.
11. **`patient_visits` doctor linkage gap** — `doctor_id` not reliably
    written at save time; Biller W9 join depends on `patients.doctor_id`
    one-doctor-per-patient assumption. Still unresolved, still the
    prerequisite for `cpt_codes.provider_type` validation.
12. **PDF filename casing** — `ortho.pdf`/`pain_mgmt.pdf` lowercase vs.
    `ANS.pdf`, `DME.pdf` etc. uppercase. Cosmetic; resolve before adding
    the next new template.
13. **`w9_filler.py` in `cosmos-api` root** — appears to be a legacy
    duplicate of `forms/w9.py`. Flagged but not removed this session.
14. **`forms/base.py` pre-existing `except Exception: pass`** in
    `render_visible_text_in_rect` — flagged prior session, still not
    fixed, prohibited by `SYSTEM_PROMPT.md` §1/§8.
15. **MRI Extremity Studies + insurance fields** — backend ready, pure
    frontend, never started; Wrist inclusion still unresolved.
16. **RLS audit follow-ups** — `patient_forms` RLS disabled entirely;
    `storage.objects` has one fully-open policy on `patient-forms`
    bucket — neither currently causing a bug, both still un-hardened.
17. **Desktop sidebar nav** — product owner provided target mockup this
    session. Scoped as future work; mobile-first confirmed as the
    immediate build priority.

---

## File Confidence Levels (this delivery)

**★ Verified-final** — confirmed deployed via full deploy chain output
(tsc + commit hash + Vercel Ready), and/or live screenshot.

**Obtained-current (this session)** — read in full this session; not
modified.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/page.tsx` | ★ Verified-final (commit `efe32ef`, live) |
| `cosmos-dashboard/app/dashboard/DashboardClient.tsx` | ★ Verified-final (commit `efe32ef`, buried Admin button removed) |
| `cosmos-dashboard/app/admin/page.tsx` | ★ Verified-final (commits `6b0caa4`, `c87fc6f`, `e7cdb13`, `ce4b604` — full shadcn rebuild + Oxanium pass + supervisor billing tab; live screenshot confirmed) |
| `cosmos-dashboard/app/md/page.tsx` | ★ Verified-final (commit `9c1d8f1`, supervised query added) |
| `cosmos-dashboard/app/md/MDClient.tsx` | ★ Verified-final (commits `9c1d8f1`, `39cb8ec`, `265cc5c` — toggle + fetch + badge; live test confirmed) |
| `cosmos-dashboard/app/dev/page.tsx` | ★ Verified-final (commit `74371fa`, Oxanium/shadcn rebuild) |
| `cosmos-api/forms/ortho.py`, `forms/pain_mgmt.py` | Carries forward from prior session — ★ Verified-final for backend logic; TEMPLATE line confirmed pointing at `ortho.pdf`/`pain_mgmt.pdf` |
| `cosmos-api/main.py`, `pdf_engine.py` | Carries forward from prior session — ★ Verified-final |
| `cosmos-api/forms/ans.py`, `dme.py`, `icd10.py`, `mri.py`, `pce.py`, `pt.py`, `rx.py`, `vng.py` | Only TEMPLATE line confirmed — rest of each file never seen in full |
| `cosmos-api/forms/aob.py`, `nf2.py` | Never obtained, any session |
| Everything not listed above | Carries forward unchanged from prior session confidence levels |

---

## Architecture Corrections (discovered this session, `ARCHITECTURE.md` updated)

- **`lib/supabase.ts` / `lib/supabaseServer.ts` are at the top-level
  `lib/` directory**, not `app/lib/` as previously documented.
  `app/lib/` contains only `fonts.ts`. Confirmed by `components.json`'s
  alias (`"lib": "@/lib"`) and direct directory listing of the zip.
- **Admin page (`app/admin/page.tsx`) is now a second shadcn/ui scoped
  exception**, alongside the Biller dashboard. The styling note in §1
  ("until the Biller dashboard, was never actually used") is now
  inaccurate — updated.
- **`doctors` table** has two new columns: `license_type` (text, default
  'MD') and `supervising_provider_id` (uuid FK self-referencing).
  Migration `009_add_doctor_license_type_and_supervising.sql`.

---

## Lessons Learned This Session

- **The Save→View unconfirmed delivery is now the single most recurring
  failure mode in this project's history** — it survived two full
  sessions without resolution. Priority 1 for next session, no
  exceptions.
- **Reading the full repo zip before designing anything is faster than
  incremental file requests** — the zip review this session correctly
  identified that Admin was already architecturally separate (resolving
  the original request's false premise in one pass), found 19 native
  `<select>` violations across 5 files, confirmed the `doctor_id`
  touchpoint map, and caught the stale `lib/` path in documentation.
  Time well spent vs. the alternative of many individual file requests.
- **The `cpt_codes.provider_type` column already existed in the live
  database** — designed for exactly the supervised-provider use case,
  but unused on both frontend and backend. Before designing new schema,
  check the live DB for columns that may already exist.
