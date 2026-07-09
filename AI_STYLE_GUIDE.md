# Cosmos Medical Technologies — AI STYLE GUIDE

Permanent development conventions only. Not a handoff document (see
`HANDOVER.md`), not architecture (see `ARCHITECTURE.md`), not product
requirements (see `PRODUCT_SPEC.md`), not operating rules/roles/decision
hierarchy (see `SYSTEM_PROMPT.md`). Contains no project history, no
current priorities, no open bugs. If a section has no verified standard
yet, it says so explicitly rather than inventing one.

---

## 1. Coding Standards

**Python** (`cosmos-api`):
- Validate every change with `python3 -m py_compile <files>` before commit.
- Never `except Exception: pass` — always log (`SYSTEM_PROMPT.md` §1, §8).
- File ownership is strict — see `SYSTEM_PROMPT.md` §10: `forms/*.py` is
  one module per document type, PDF field-fill logic only; `forms/
  base.py` is shared PDF helpers, never database logic; `database.py`
  builds the data dicts generators read from; `main.py` is routes + the
  shared dispatcher; `pdf_engine.py` is a pure router re-exporting each
  `forms/*.py` generator for `main.py` to call by name.
- `«Reserved for future standards»` — no project-specific docstring
  format, type-hint policy, or import-ordering convention is documented.

**FastAPI** (`cosmos-api`):
- Referral-type documents share one generic dispatch path
  (`ARCHITECTURE.md` §4): a `REFERRAL_FORM_CONFIG` entry maps a type to
  its generator function name + tag + labels; adding a new referral type
  means touching `forms/<type>.py`, the config entry + route in
  `main.py`, and the import/`__all__` entry in `pdf_engine.py` — all
  three, every time.
- Non-referral documents (NF-2, NF-3, AOB, W-9, PCE) are routed
  individually; not all import through `pdf_engine.py` (`/generate-w9`
  imports `forms.w9` directly) — confirm the actual import path per
  document rather than assuming the referral pattern applies.

**TypeScript / React** (`cosmos-dashboard`):
- Validate every change with `tsc --noEmit`. Local `next build` is not a
  usable validation step on this project's environment (no Android/
  arm64 Turbopack bindings, missing service-key env var on-device) —
  `tsc --noEmit` plus a successful remote Vercel deploy is the real
  validation chain.
- Standard dashboard data-fetch pattern: a server-component `page.tsx`
  wrapper does the initial Supabase query with `revalidate: 0`, then
  passes the result down as props to a client component that owns all
  interactivity (`ARCHITECTURE.md` §6, §8). Don't fetch inside the
  client component unless there's a specific reason to deviate.
- Document-generation screens follow the Generate→View button pattern:
  a single button starts as "Generate," flips to "View" on success, and
  a second tap re-opens the existing signed URL rather than
  regenerating (`ARCHITECTURE.md` §7).
- **No bare interactive element inherits color, font, or font-size for
  free on this project** — neither a plain `<button>`/form control, nor
  a shadcn/Radix component's own trigger or portaled content
  (`SelectContent`, `DropdownMenuContent` render to `document.body`,
  entirely outside their logical parent's DOM subtree). This project's
  `globals.css` deliberately omits Tailwind's preflight reset, so
  nothing resets/normalizes native control styling or restores
  inheritance for free. Confirmed on five separate occasions on the
  Biller dashboard before being generalized as a standing rule: a sort-
  toggle button missing font-size, `ReceivedCell` missing its font
  entirely, `SelectTrigger` losing its text color once a real value is
  selected (only its empty-placeholder state had a color class),
  `Button`'s `outline`/`ghost` variants having no text-color class at
  all, and — a related but mechanically distinct symptom — Android
  Chrome's own font-boosting heuristic inflating text size independent
  of any CSS set, fixed globally via `text-size-adjust: 100%`. Always
  set color/font/size explicitly on any new bare button or shadcn
  trigger/content element; never assume inheritance will reach it.
- **A font object consumed by both a parent component and any shadcn/
  Radix primitive it renders through** (e.g. `Select`, `DropdownMenu`)
  **must live in one shared, importable module** — e.g.
  `app/lib/fonts.ts` — not be declared locally inside the parent. Per
  the portal gap above, a font className set only at the parent's own
  root element never reaches that primitive's portaled content.
- **Build charts with raw Recharts components directly**
  (`PieChart`/`BarChart`/`Bar`/`Cell`/`Tooltip`/`Legend`/etc.), not
  shadcn's official `chart.tsx` wrapper — that wrapper has an open,
  unresolved upstream compatibility issue with Recharts v3
  (`shadcn-ui/ui#9892`, as of mid-2026); shadcn's own docs explicitly
  say they don't wrap Recharts and encourage building with it directly.
  Style chart colors as explicit per-category hex values matching
  existing badge/status colors on the same surface, consistent with
  this project's established literal-hex convention — not shadcn's
  `--chart-N` CSS-variable convention.
- `«Reserved for future standards»` — no project-wide component-prop
  naming convention, hooks-usage policy, or state-management convention
  beyond the data-fetch pattern above is documented.

**Validation, generally** — see `SYSTEM_PROMPT.md` §6 for the full
workflow (commit-existence checks, RLS audit timing, the "a successful
patch run is not evidence the right file got patched" principle). Not
duplicated here.

---

## 2. UI Standards

Full color/component policy lives in `SYSTEM_PROMPT.md` §9 — summary
only:

- Palette: background `#0d1821`, accent `#00cfff`, borders `#1a3a4a`,
  success/section-headers `#19a866`.
- Mobile-first; every screen hand-rolled inline `style={{...}}` —
  **five explicit, scoped exceptions, all approved by the product owner
  after the tradeoff was presented**: (1) shadcn/ui + Tailwind, bridged
  onto the same palette via CSS variables (`ARCHITECTURE.md` §8), approved
  on: Biller dashboard (`/billing`), Admin (`/admin`), MD V2 chart
  (`/md-v2`), MDClient list (`/md`), and Referral dashboard (`/referrals`);
  (2) a brighter success/accent green, `#2ee08a`, scoped to the Biller
  dashboard only. Don't extend either to any other surface without the
  same explicit approval — see `ARCHITECTURE.md` §1 for the authoritative
  list.
- Never a native `<select>` — use the project's `DropdownSelect`/
  `StateSelect` components (or, inside the Biller exception only,
  shadcn's `Select`) for any select-like control; native selects render
  with the OS's light-themed picker, inconsistent with the dark theme.
- Never a dead-end input or button — a control with no real effect
  reads as a bug, not a design choice, regardless of intent.
- Reuse existing components; read a component's actual source before
  assuming visual similarity implies implementation similarity.

**CosmosUI Notification Standard** — established Session 20; applies to
all roles and all screens:
- **Single-record CRUD** (save, delete, add) → `toastSuccess()` /
  `toastError()`. These are transient; they confirm an action worked
  and dismiss automatically. No modal needed — the user acted, it
  worked, they move on.
- **Bulk operations** (CSV import, batch actions), **destructive
  completions** (Replace All), and **errors requiring attention** →
  `AlertModal` (cyan-bordered, requires acknowledgment). The user needs
  to read and confirm the result — e.g. "Replaced with 34 CPT codes."
- **The distinction**: does the user need to *acknowledge* this result,
  or just be *informed* of it? Acknowledge → `AlertModal`. Informed →
  toast.
- `toastSuccess` and `toastError` both internally route through
  `AlertModal` — they are not separate UI primitives, just convenience
  wrappers (confirmed in `HANDOVER.md` Lessons Learned).
- Every new screen must mount both `<AlertModal />` and
  `<ConfirmModal />` at its root — without them, `cosmosConfirm()` and
  toast calls silently fail.

**Typography**: no app-wide font standard exists — default browser/
system font everywhere except the Biller dashboard, which loads Oxanium
(weights 300–800, default Light) via a shared module
(`app/lib/fonts.ts`, §1 above) so it reaches both the dashboard's own
component tree and the shadcn primitives it renders through portals.
Don't extend to other surfaces without the same explicit-approval
process used for the shadcn exception above.

**Accessibility**: `«Reserved for future standards»` — no holistic
accessibility policy is documented. The Biller dashboard's table
supports arrow-key row-to-row focus movement as a starting point, not a
project-wide standard yet.

---

## 3. Documentation Standards

Observed and binding for `SYSTEM_PROMPT.md`, `ARCHITECTURE.md`,
`PRODUCT_SPEC.md`, `HANDOVER.md`, this document, and `CHANGELOG.md`:

- H1 title naming the document and project; numbered `##` sections;
  `---` horizontal rule between every top-level section.
- Inline code spans for file names, column names, function names, and
  literal values; fenced code blocks (with a language hint when one
  applies — `sql`, `ts`, `bash`) for anything meant to be copy-pasted or
  read as a unit.
- Cross-reference by document + section number (e.g. `ARCHITECTURE.md
  §8`), not by re-stating the referenced content.
- **If documentation and the live repository ever conflict, the live
  repository is the source of truth** — this is the standing rule
  stated at the top of `SYSTEM_PROMPT.md` and applies to every document
  in this set. Confirmed mattering in practice, not just a theoretical
  caveat: a prior `HANDOVER.md`/`ARCHITECTURE.md`/`PRODUCT_SPEC.md`
  claim that the Biller dashboard's "Received" column was an unbacked
  placeholder was caught as stale and wrong against direct live-code
  review, and corrected accordingly.
- **File retrieval — standing standard**: whenever a source file is
  needed for review or patching, always provide the canonical retrieval
  command alongside the request. Never use `grep` output or screenshots
  as a substitute for reading the actual file. The standard command is:
  ```bash
  cd ~/cosmos-dashboard   # or ~/cosmos-api as appropriate
  git show HEAD:<path/to/file> > ~/storage/downloads/<filename>
  ```
  Then attach the downloaded file. This is faster and exact (no OCR
  risk, no truncation) compared to incremental `grep`/`sed -n` rounds.
  Confirmed the hard way across multiple sessions before becoming the
  default. Every file request from Claude must include this command.
- SQL migrations are numbered sequentially and never renumbered
  retroactively (`001_...`, `002_...`, `ARCHITECTURE.md` §3) — the same
  append-only, never-renumber principle applies to `CHANGELOG.md`
  entries.
- Code comments explain *why* a decision was made, not what the code
  literally does — see `BillerDashboard.tsx`'s doc-comment blocks
  recording product decisions (e.g. the Outstanding-floor-at-$0 comment,
  the shared-font-module comment) as the working examples.
- `«Reserved for future standards»` — no document version-numbering
  scheme exists yet beyond the handoff protocol's own version number;
  individual `.md` files in this set aren't independently versioned.

---

## 4. Patch Standards

Full methodology lives in `SYSTEM_PROMPT.md` §3 and §5 — summary only:

- Simple replacements → `sed -i`. Structural changes → a patch script:
  anchor-based, exact occurrence-count checked, idempotency-guarded,
  tested against a fresh copy of the actual live file before delivery.
- A file modified 3+ times → consider a full-file rebuild instead of
  stacking further patches.
- Patch scripts live in `~/`, never inside the repo, never in `/tmp`;
  delete immediately once the commit lands — a patch script has zero
  value afterward and its anchors won't match a second time anyway.
- Keep every pasted command block small; prefer a downloadable artifact
  + `cp` + `md5sum` verification over inline paste for anything over
  ~2–3KB (Termux can silently corrupt large pastes with no error).
- For files under ~170 lines, `cat > file << 'ENDOFFILE' ... ENDOFFILE`
  is a reliable full-file write method in Termux — confirmed faster and
  more reliable than downloading artifacts for files this size.
- Multi-step patches: one step per message, explicitly numbered ("Step
  X of Y"), with the literal printed confirmation required before the
  next step is sent.
- A patch script's successful exit is not evidence it patched the
  intended target — confirm via `grep`/`git status` for the specific
  intended change, independent of the script's own reported success.

---

## 5. Git Standards

- Never `git push --force` (a prior incident destroyed 102 remote
  commits).
- Validate before every commit: `tsc --noEmit` / `python3 -m py_compile`
  as appropriate (`SYSTEM_PROMPT.md` §6).
- Confirm the commit actually exists and matches `origin/main`
  (`git log --oneline -3`, `git status`) immediately before any further
  work building on it — `origin/main` can move without any local
  command having caused it.
- A new file failing to appear in `git status` after `git add` can mean
  `.gitignore` silently blocked it — check `git check-ignore -v <file>`
  immediately when this happens.
- **Deployment**: validation and the full deploy chain go in one single
  chained bash block (`npx tsc --noEmit && git add -A && git commit -m
  "..." && git push && vercel --prod --yes` for `cosmos-dashboard`) —
  the `&&` chaining halts before committing if validation fails, so
  this is safe to combine rather than pausing for a separate
  confirmation step between validation and deploy.
- `cosmos-dashboard` intentionally double-deploys: `git push` triggers
  Vercel's GitHub-integration auto-deploy, and the explicit `vercel
  --prod --yes` call in the same chain is a deliberate safety net, not
  a bug (`ARCHITECTURE.md` §2). `cosmos-api` (Render) auto-deploys from
  `git push` alone — no CLI-equivalent step exists for that repo.

---

## 6. PDF Development Standards

Pure engineering rules only — see `PRODUCT_SPEC.md` for the actual
document-confirmation tiers and workflow these rules support:

- Verify every field name against the real PDF's `pypdf.get_fields()`
  output before writing any filler code. Never trust a provided
  field-list export (csv/json/txt) without cross-checking the live PDF
  directly.
- Never assume AcroForm contracts; inspect checkbox behavior whenever
  an issue is reported, and verify widget placement when needed.
- All PDFs stay unflattened (editable AcroForm) unless a specific
  document is explicitly required otherwise.
- `forms/base.py` (or equivalent shared helper module) is PDF
  manipulation only — never database logic.
- When a template is replaced (a real field-set change, not just a
  version-name bump), diff the new file's real field list against what
  the current generator code actually writes to, **programmatically** —
  never by eyeballing it.
- The only real proof a field mapping works is a human visually
  inspecting an actual generated PDF for a real record — a clean
  compile or sandbox test against sample data is necessary but not
  sufficient.
- `except Exception: pass` is prohibited anywhere in the PDF pipeline —
  always log.
- A confidently-worded code comment or docstring is not evidence of
  correctness — verify the underlying claim independently.

---

## 7. Response Standards

Full output format and role model live in `SYSTEM_PROMPT.md` §1 and
§11 — summary only:

- One unified recommendation synthesizing all relevant engineering
  perspectives; don't roleplay separate personas or label which
  sentence came from which role.
- Standard development-request format: Current Understanding → Risks/
  Blockers → Product Decisions Required → Recommended Approach →
  Implementation Plan → Commands/Code. Don't skip the Product Decisions
  step when one applies.
- Keep the Commands/Code step to one small, focused step at a time —
  don't compress a multi-file, multi-step delivery into a single block
  (`SYSTEM_PROMPT.md` §3, §11) — except the validation+deploy chain
  itself, which is deliberately one combined block (§5 above).
- Stop and ask — don't infer — on anything touching billing, clinical
  workflow, referral workflow, medical documentation, or compliance
  (`SYSTEM_PROMPT.md` §7). Don't re-litigate a product decision already
  recorded in `PRODUCT_SPEC.md` without the product owner raising it
  again.
- When a recommendation is heard and explicitly overruled, implement
  what was asked for well — don't re-argue a preference call that isn't
  a safety/compliance issue.

---

## 8. Naming Conventions

- **Files**: `forms/<type>.py` mirrors its document/referral type name
  exactly (e.g. `forms/vng.py`, `forms/pt.py`); SQL migrations are
  `<sequence>_<description>.sql`, numbered sequentially, never reused.
- **Routes**: referral-type generation routes follow `/generate-<type>`
  matching the `forms/<type>.py` name and the `REFERRAL_FORM_CONFIG` key
  for that type.
- **Components**: `cosmos-dashboard/app/components/ui/` holds shadcn
  primitives only (Biller-exception scope); hand-rolled shared
  components (`DropdownSelect.tsx`, `PatientForm.tsx`, etc.) live
  directly under `app/components/`. Shared non-component utilities used
  across both a Biller-exception primitive and the dashboard itself
  (e.g. the shared font object) live under `app/lib/`.
- **Database**: see `ARCHITECTURE.md` §3 for the actual table/column
  inventory — not duplicated here. `«Reserved for future standards»` —
  no documented column-naming policy (e.g. `snake_case` vs. suffix
  conventions) beyond what's observable in the existing schema.
- **Documents**: this six-document set uses fixed, permanent filenames
  (`SYSTEM_PROMPT.md`, `HANDOVER.md`, `ARCHITECTURE.md`,
  `PRODUCT_SPEC.md`, `AI_STYLE_GUIDE.md`, `CHANGELOG.md`) — never
  renamed, never duplicated under a different name.
- `«Reserved for future standards»` — no documented function- or
  variable-naming convention beyond standard idiomatic Python/
  TypeScript.

---

## 9. Quality Standards

**Definition of Done** for a development task:
- Code change validated (`tsc --noEmit` / `py_compile`) — compilation
  alone is not sufficient for a refactor; behavioral equivalence must
  also be verified.
- Deployed and the deployment independently confirmed (commit exists,
  matches `origin/main`, real RLS policy confirmed via audit query when
  the change touches a table's read/write path for the first time).
- For PDF work specifically: a real generated PDF visually reviewed by
  a human, not just a clean compile.
- Relevant documentation updated in the same pass, per the ownership
  rules in the handoff protocol (`HANDOVER.md` always; `ARCHITECTURE.md`
  /`PRODUCT_SPEC.md`/`SYSTEM_PROMPT.md` only when their respective
  domain actually changed).

**Verification checklist** — see `SYSTEM_PROMPT.md` §4 (Pre-
Implementation Checklist) and §6 (Validation Workflow) in full; not
duplicated here.

**Deployment checklist** — see §5 above (Git Standards).

**Documentation checklist** — see the handoff protocol's own
Documentation Validation section (no contradictory/duplicated
information, consistent terminology, valid cross-references, current
priorities matching across documents, live repository as source of
truth).
