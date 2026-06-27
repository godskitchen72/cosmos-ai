# Cosmos Medical Technologies — HANDOVER (June 27, 2026)

Session-specific status only. Permanent rules live in `SYSTEM_PROMPT.md`,
technical facts in `ARCHITECTURE.md`, product/business rules in
`PRODUCT_SPEC.md`, permanent dev conventions in `AI_STYLE_GUIDE.md` — this
document doesn't repeat them, only references them where relevant. Read
all five documents at session start (`SYSTEM_PROMPT.md` §12).

This handover supersedes all prior `HANDOVER.md` versions — it is
self-contained.

---

## Current Status

`cosmos-dashboard` is deployed and in sync with `origin/main` through
commit `466afaf` ("Add Status and Denial Status donut charts") —
independently confirmed via `git log --oneline -3` (showing `HEAD ->
main, origin/main, origin/HEAD`) and a Vercel "Ready" production deploy
confirmation. Since this branch has never been force-pushed
(`SYSTEM_PROMPT.md` §3) and every commit this session was made
sequentially on it, this transitively confirms everything below up
through the donut charts — but **not** the chart replacement described
next. `cosmos-api` was not touched this session.

---

## Unconfirmed Delivery — Check This First

The final piece of this session's work — replacing the Status/Denial
Status donut charts with a single "Paid vs Outstanding by Carrier"
stacked bar chart — was delivered as a tested patch script
(`patch_billing_step8.py`, expected md5sum `c76fc267cdd215b444088c2f20169e49`)
with full validate+deploy commands, but the conversation moved to
documentation work immediately after, with no terminal output or
screenshot ever returned. Per the skipped-step failure mode
(`SYSTEM_PROMPT.md` §3, §6 — this is at least the third time this
specific failure mode has recurred across sessions), do not assume this
landed. Before building anything further on `BillerDashboard.tsx`:

```
cd ~/cosmos-dashboard
git log --oneline -3
git status
```

Look for a commit message containing "Replace Status/Denial Status
donuts with Paid vs Outstanding by Carrier chart." **If it's not there,
the live dashboard still shows the two donut charts, not the
Paid-vs-Outstanding chart** — re-run `python3 ~/patch_billing_step8.py`
(if it's still on-device) or request it again.

Everything else described below as "Completed This Session" was
independently confirmed via either a direct `git log` screenshot or a
deployed-app screenshot at the time and can be trusted.

---

## Completed This Session

### Biller Dashboard (`/billing`) — typography/UX fixes, charting, delete capability

All work this session was on the existing Biller dashboard (built in a
prior session as v1, then substantially rebuilt into a TanStack Table-
based v2 before this session began — this document's predecessor
versions still described the v1 placeholder state; that was already
stale before this session started, see "Documentation Corrections"
below).

- **Fixed a production 500 crash on `/billing`** — stale `claim_status`
  enum values; defensive `StatusCell` fallback + a one-time data
  migration. Confirmed via checksum + commit hash + zero stale rows on
  re-query.
- **Renamed "Payment Status" column to "Denial Status"**, and "Submitted"
  to "Bill Received" — label-only changes; disambiguates the latter from
  the existing `$` Received column, which is a different field entirely.
  No underlying schema or field changed.
- **Brightened the Biller-scoped green** from `#19a866` to `#2ee08a` —
  explicit product-owner decision, second scoped exception on top of the
  existing shadcn one (`SYSTEM_PROMPT.md` §9, `ARCHITECTURE.md` §8).
- **Reordered the Denial Docs column** to sit immediately after Denial
  Status.
- **Added hard-delete capability for uploaded Denial Docs** — confirm-
  before-delete (browser `confirm()`), removes both the storage object
  and the `patient_forms` row. Confirmed both `patient_forms` (RLS
  disabled entirely) and `storage.objects` (one fully-open `ALL` policy
  scoped to the `patient-forms` bucket) would not block this via the
  standing RLS audit query before building it.
- **New shared font module** `app/lib/fonts.ts` — the Oxanium font object
  was previously declared locally inside `BillerDashboard.tsx` only,
  which meant it never reached content rendered through a Radix Portal
  (Select/DropdownMenu render outside their parent's DOM subtree
  entirely). Both `select.tsx` and `dropdown-menu.tsx` now import the
  same shared object.
- **Five separate "missing color/size class on a bare interactive
  element" bugs found and fixed**, all the same root cause (this app
  deliberately omits Tailwind's preflight reset, so nothing
  resets/normalizes native control styling automatically):
  1. Sortable column-header sort-toggle buttons were missing an explicit
     font-size class (only weight/case/tracking had been set), so every
     sortable header rendered larger than the three non-sortable ones.
  2. `ReceivedCell`'s display button and edit `Input` weren't carrying
     the Oxanium font at all.
  3. `SelectTrigger` only set text color while showing its empty
     placeholder (`data-[placeholder]:text-muted-foreground`) — once a
     real value was selected, it fell back to the browser's default
     black button text. Made unconditional.
  4. `Button`'s `outline` and `ghost` variants had no text-color class at
     all (`default`/`destructive` did) — affected `Clear filters`,
     `Columns`, `Export CSV`, `Set Status`, and the pagination
     `Prev`/`Next` buttons. Added `text-foreground` to both.
  5. A related but distinct symptom — Android Chrome's own font-boosting
     heuristic inflating text size independent of any CSS set — fixed
     globally via `text-size-adjust: 100%` in `globals.css`.
- **Added `recharts` as a new dependency.** Built a "Status" and "Denial
  Status" composition donut chart pair using raw Recharts components
  (`PieChart`/`Pie`/`Cell`/`Tooltip`/`Legend`), deliberately **not**
  shadcn's official `chart.tsx` wrapper — there's an open, unresolved
  upstream issue (`shadcn-ui/ui#9892`) about that wrapper's Recharts v3
  compatibility, and shadcn's own docs explicitly endorse building
  directly with Recharts. Colors were hardcoded per-status hex matching
  each status's existing badge color, not shadcn's `--chart-N` variable
  convention.
- **Then replaced both donuts with one "Paid vs Outstanding by Carrier"
  stacked bar chart** (green = Paid, sum of `received_amount`; red =
  Outstanding, `billed - received_amount` floored at `$0` per explicit
  product decision — an overpaid carrier renders as fully Paid, not as a
  negative bar) — per a follow-up product request that this answers a
  more useful question for this dashboard than workflow/denial
  composition does. Kept the existing plain "By Carrier" list card as a
  separate, second view rather than replacing it (explicit product
  decision). **This is the delivery flagged Unconfirmed above.**

### Documentation Corrections (this maintenance pass)

The supplied `HANDOVER.md`/`ARCHITECTURE.md`/`PRODUCT_SPEC.md` described
the Biller dashboard's "Received" column as a fixed "Not tracked"
placeholder with no backing column. **This was already false by the
time this session began** — live code review this session
(`BillerDashboard.tsx`'s `ReceivedCell`, `received_amount` field usage in
the KPI/`carrierTotals`/new chart computations) shows a real, working,
per-visit editable received-amount column already exists and is wired
through multiple parts of the dashboard. Per the standing rule at the
top of every document in this set, live repository wins — corrected in
`ARCHITECTURE.md` §8 and `PRODUCT_SPEC.md` §6 this pass. This was not
new work performed this session; it was a stale documentation claim
caught and corrected.

---

## Completed Prior Sessions (condensed)

- **Biller Dashboard v1 → v2**: v1 built end-to-end (shadcn/ui scoped
  exception introduced, Card/Table/Badge/Button primitives, icon-mark
  rollout, W9-via-`doctor_id` join). Substantially rebuilt into v2 before
  this session (TanStack Table, KPI cards, real `received_amount`
  tracking, Claim Status/Payment Status field split) — the specific
  session boundary between v1 and v2 predates this document's visibility
  and is not reconstructed here; treat the live repo as the v2 baseline
  this session's work was built on.
- **Physical Therapy (PT) referral** — new document type, full stack,
  verified end-to-end with a real patient.
- **VNG rebuilt for new (v5) template** — deployed, **not yet**
  end-to-end verified (Priority #2 below, still open, now 3+ sessions).
- **Repo hygiene**: `.gitignore` bug fixed (blanket `*.pdf` rule was
  silently blocking the VNG template), 35 stale patch/`.bak_*` files
  removed across both repos.
- **Psych Referral FD card**, **MD Calendar doctor-jump + quick-pick
  chips** (two real bugs found and fixed along the way).
- **NF-2 mailing confirmation** workflow (`PRODUCT_SPEC.md` §7).
- **Submit-to-billing** producer-side signal (`PRODUCT_SPEC.md` §6) —
  consumed by the Biller dashboard.
- **Auto-finalize billing on visit save** — fixed the real root cause of
  recurring "$0 billing" reports.
- **CPT fee-schedule estimate** for visits without finalized billing yet.
- **PC Corp Name / Address / Tax Classification** doctor fields, wired
  into the NF-3 Pay-To box and the W-9.
- Earlier still: FD-gating principle established; visit-scoped referral
  redesign; RLS silent-failure pattern discovered (`ARCHITECTURE.md`
  §3); PCE six-step wizard built; six referral types built end-to-end
  with signature injection; FD dashboard core workflow; NF-2 PDF engine
  rebuilt in ReportLab; a `git push --force` incident destroyed 102
  remote commits (never repeated); MD Calendar base build; project
  originated as Python/Streamlit before gaining the Next.js frontend.

---

## Open Items, Priority Order

1. **Confirm the Paid-vs-Outstanding chart delivery landed** (see top of
   this document) — check before anything else.
2. **End-to-end verify the VNG v5 template** with a real generated PDF —
   open across 3+ sessions now. Confirm ICD-10 codes populate, the
   Auth/Precert field is genuinely absent from the rendered PDF, and the
   Symptoms checkboxes land correctly.
3. **Verify the NF-3 PC-payee mapping** in a real generated PDF — patch
   deployed several sessions ago, functional test still never confirmed.
4. **Regenerate W-9s for every existing doctor** now that tax
   classification is real — no bulk path exists, one manual tap per
   doctor (`PRODUCT_SPEC.md` §5).
5. **Data integrity audit** — historical `cpt_codes`/`icd10_codes` may be
   stale from a previously-fixed RLS bug; full sweep never run.
6. **MRI Extremity Studies + insurance fields** — backend ready, pure
   frontend, never started; Wrist inclusion unresolved
   (`PRODUCT_SPEC.md` §10).
7. **RLS audit follow-ups** — `nf2_mailed_at`, `submitted_to_billing_at`,
   the `pc_*`/`tax_classification*` columns remain specifically
   un-audited. **New this session**: `patient_forms` RLS is confirmed
   *disabled entirely* (not just an incomplete policy) and
   `storage.objects` carries one fully-open `ALL` policy scoped to the
   `patient-forms` bucket — both work correctly for the features that
   need them today, but represent the same class of systemic gap as the
   already-flagged columns above and are worth a deliberate decision,
   not just continued reliance.
8. **Front Desk + MD dashboard holistic planning** — flagged across
   multiple sessions without dedicated focus. Treat as a planning
   conversation with the product owner, not a queue to execute silently
   (`PRODUCT_SPEC.md` §9).
9. **Full-visit edit capability** — explicitly out of scope pending a
   real product conversation.
10. **Confirm `cosmos-api`'s real on-device repo path** — still assumed
    `~/cosmos-api`, never explicitly stated.
11. **Stale Billing role-select subtitle** — still describes carrier
    tracking/reports beyond what's actually built. Low priority,
    cosmetic.
12. **`CHANGELOG.md`'s actual existence/contents are still unconfirmed.**
    A `CHANGELOG.md` was drafted this session as a best-effort first
    entry, but whether the file already exists in the repo with prior
    real entries was never checked before that draft was produced — **do
    not commit it without first running `cat CHANGELOG.md` /
    `git show HEAD:CHANGELOG.md`** to see if it's already real.

Don't start lower-priority work while a higher item is blocked on a
product decision (`SYSTEM_PROMPT.md` §2).

---

## File Confidence Levels (this delivery)

**★ Verified-final** — directly read in full this session (uploaded/
pasted as real file text, not OCR), and/or independently confirmed live
via a `git log` commit hash and/or deployed-app screenshot.

**Obtained-current (this session)** — seen in full this session; not
modified by any assistant action.

**⚠ Low-confidence reconstruction** — built from OCR'd screenshot text,
never seen as exact source, or a delivered-but-unconfirmed patch.

| File | Confidence |
|---|---|
| `cosmos-dashboard/app/billing/BillerDashboard.tsx` | ★ Verified-final through the donut-chart commit (`466afaf`); the Paid-vs-Outstanding replacement is ⚠ delivered, not confirmed — see top of document |
| `cosmos-dashboard/app/components/ui/{select,dropdown-menu,button}.tsx` | ★ Verified-final |
| `cosmos-dashboard/app/lib/fonts.ts` | ★ Verified-final (new file, this session) |
| `cosmos-dashboard/app/globals.css` | ★ Verified-final (read in full this session; `text-size-adjust` addition confirmed) |
| `cosmos-dashboard/app/components/ui/{card,table,badge}.tsx`, `lib/utils.ts`, `components.json` | Obtained-current (prior session) — not re-verified this session |
| `cosmos-dashboard/app/page.tsx`, `app/dashboard/DashboardClient.tsx`, `app/admin/page.tsx`, `app/calendar/page.tsx`, `app/components/PatientForm.tsx`, `app/md/**`, `app/patients/**`, `app/dev/page.tsx` | Obtained-current (prior session) — not touched or re-verified this session |
| `cosmos-api/forms/vng.py`, `forms/pt.py`, `main.py`, `.gitignore` | Obtained-current (prior session) — untouched this session |
| `cosmos-api/pdf_engine.py` | ⚠ Low-confidence — unchanged this session, re-fetch fresh before trusting beyond known additions |
| `cosmos-api/database.py`, `models.py`, `forms/nf3.py`, `forms/w9.py`, `forms/base.py`, `forms/dme.py` | Unmodified-reference (untouched this and prior sessions) |

**Live repository state is always the source of truth over this
delivery** — re-pull anything above before trusting it exactly,
especially `BillerDashboard.tsx` per the Unconfirmed Delivery flag.

---

## Missing Files (never obtained, any session)

Entirely `cosmos-api`, unchanged this session:

- `cosmos-api/forms/mri.py`, `rx.py`, `ans.py`, `icd10.py`, `aob.py`,
  `nf2.py`, `pce.py`
- PDF binaries for every referral/document type except PT and VNG v5
  (MRI, Rx, ANS, ICD-10, AOB, NF2, NF3, W9, PCE, the old DME) — never
  uploaded as actual files, any session

---

## Lessons Learned This Session

(Rules resulting from these are already folded into `SYSTEM_PROMPT.md`/
`AI_STYLE_GUIDE.md` — this section is the narrative, for context.)

- **Screenshot-based code review cost real time, repeatedly** — several
  rounds of `grep`/`sed -n` + screenshot were needed to assemble a full
  picture of a single file before a direct file upload (`git show
  HEAD:<path> > ~/storage/downloads/<name>`, then attach) was adopted
  mid-session as the standing default. Confirmed faster and exact
  (no OCR risk) for everything afterward.
- **The same root-cause bug recurred across five different components**
  before being generalized as a standing rule rather than patched
  reactively each time (see "Completed This Session" above for the
  full list) — worth proactively checking on any *new* interactive
  element added to this dashboard going forward, not just reactively
  fixing each report.
- **A documentation claim was stale and directly contradicted by the
  live code** — "Received is a Not-tracked placeholder" — caught only
  by reading the actual file, not by trusting the prior handover. A
  concrete instance of the standing "live repo over docs" rule actually
  mattering, not just a theoretical caveat.
- **A feature was built, then replaced, within the same session** after
  a follow-up product request changed direction (the donut charts →
  Paid vs Outstanding chart) — handled via a tested, idempotency-guarded
  removal-and-replacement patch script rather than ad hoc edits. Anyone
  picking this up needs to know the *current intended* state is the bar
  chart, even though the donut-chart commit is what's actually
  confirmed live right now (see Unconfirmed Delivery, top).
- **Deliberately avoided an official component due to a live upstream
  bug report** (shadcn's `chart.tsx`, `shadcn-ui/ui#9892`, Recharts v3
  compatibility) rather than assuming "the docs say v3 is supported" was
  the complete picture — worth re-checking if that issue closes before
  building any future chart on this dashboard.
