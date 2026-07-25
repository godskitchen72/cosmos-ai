## Session 57 — Schema Changes (July 23, 2026)

### Migration 035 — doctors.is_default column

Adds `is_default` boolean to `doctors` table. One doctor marked as default for new patient intake pre-population. Applied to production only.

```sql
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS is_default boolean DEFAULT false;
UPDATE doctors SET is_default = true WHERE doctor_id = 'ccfeb4b0-e61e-48f0-b4fa-bd15c155f6d0';
```

Applied to: production (`ttudxnzmybcwrtqlbtta`).
**Pending:** cosmos-dev (`tpwbgqfdznqtjqimxric`) — apply when convenient.

### Data Backfill — W9 rows into cosmos_documents

All existing W9 files from `doctors.w9_url` backfilled into `cosmos_documents` for all 7 doctors. No schema change — data migration only.

```sql
INSERT INTO cosmos_documents (patient_id, visit_id, doctor_id, document_scope, form_type, filename, status)
SELECT NULL, NULL, doctor_id, 'doctor', 'W9', w9_url, 'generated'
FROM doctors
WHERE w9_url IS NOT NULL
ON CONFLICT DO NOTHING;
```

Applied to: production (`ttudxnzmybcwrtqlbtta`).

---

## Session 56 — Schema Changes (July 23, 2026)

### Migration 034 — Phase 4: Retire legacy url columns and patient_forms table

All document reads and writes now flow exclusively through `cosmos_documents`. Legacy columns and table dropped from production after confirming all surfaces work from the registry.

```sql
-- Drop scattered url columns from patients
ALTER TABLE public.patients DROP COLUMN IF EXISTS nf2_url;
ALTER TABLE public.patients DROP COLUMN IF EXISTS aob_url;
ALTER TABLE public.patients DROP COLUMN IF EXISTS intake_url;

-- Drop pce_url from patient_visits
ALTER TABLE public.patient_visits DROP COLUMN IF EXISTS pce_url;

-- Drop patient_forms table (all rows backfilled to cosmos_documents in Session 55)
DROP TABLE IF EXISTS public.patient_forms;

NOTIFY pgrst, 'reload schema';
```

Applied to: production (`ttudxnzmybcwrtqlbtta`).
**Pending:** cosmos-dev (`tpwbgqfdznqtjqimxric`) — apply when convenient.

---

## Session 55 — Schema & Data Changes (July 22, 2026)

### Migration 033 — cosmos_documents table

Unified document registry replacing scattered url columns and `patient_forms` as the single source of truth for all generated PDFs.

```sql
CREATE TABLE public.cosmos_documents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id      TEXT REFERENCES public.patients(patient_id) ON DELETE CASCADE,
  visit_id        UUID REFERENCES public.patient_visits(id)   ON DELETE CASCADE,
  doctor_id       UUID REFERENCES public.doctors(doctor_id)   ON DELETE CASCADE,
  document_scope  TEXT NOT NULL CHECK (document_scope IN ('patient', 'visit', 'doctor')),
  form_type       TEXT NOT NULL,
  filename        TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'generated'
                    CHECK (status IN ('generated', 'pending', 'error')),
  generated_by    UUID REFERENCES auth.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT unique_patient_doc UNIQUE (patient_id, form_type),
  CONSTRAINT unique_visit_doc   UNIQUE (visit_id,   form_type),
  CONSTRAINT unique_doctor_doc  UNIQUE (doctor_id,  form_type),
  CONSTRAINT exactly_one_scope CHECK (
    (CASE WHEN patient_id IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN visit_id   IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN doctor_id  IS NOT NULL THEN 1 ELSE 0 END) = 1
  )
);

ALTER TABLE public.cosmos_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all_cosmos_documents"
  ON public.cosmos_documents FOR ALL TO service_role
  USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_all_cosmos_documents"
  ON public.cosmos_documents FOR ALL TO authenticated
  USING (true) WITH CHECK (true);

CREATE INDEX idx_cosmos_documents_patient ON public.cosmos_documents (patient_id, form_type);
CREATE INDEX idx_cosmos_documents_visit   ON public.cosmos_documents (visit_id,   form_type);
CREATE INDEX idx_cosmos_documents_doctor  ON public.cosmos_documents (doctor_id,  form_type);

NOTIFY pgrst, 'reload schema';
```

Applied to: production (`ttudxnzmybcwrtqlbtta`) and cosmos-dev (`tpwbgqfdznqtjqimxric`).

### Backfill — cosmos_documents from existing data

All existing documents backfilled from `patient_forms`, `patients` url columns, and `doctors.w9_url`:

```sql
-- visit-scoped rows from patient_forms
INSERT INTO public.cosmos_documents (visit_id, document_scope, form_type, filename, status, created_at)
SELECT visit_id, 'visit', form_type, filename, COALESCE(status, 'generated'), COALESCE(created_at, now())
FROM public.patient_forms WHERE visit_id IS NOT NULL AND filename IS NOT NULL
ON CONFLICT DO NOTHING;

-- patient-scoped rows from patient_forms (no visit_id)
INSERT INTO public.cosmos_documents (patient_id, document_scope, form_type, filename, status, created_at)
SELECT patient_id, 'patient', form_type, filename, COALESCE(status, 'generated'), COALESCE(created_at, now())
FROM public.patient_forms WHERE visit_id IS NULL AND filename IS NOT NULL
ON CONFLICT DO NOTHING;

-- NF-2, AOB, INTAKE from patients table
INSERT INTO public.cosmos_documents (patient_id, document_scope, form_type, filename, status, created_at)
SELECT patient_id, 'patient', 'NF-2', nf2_url, 'generated', now()
FROM public.patients WHERE nf2_url IS NOT NULL AND nf2_url != ''
ON CONFLICT (patient_id, form_type) DO NOTHING;

INSERT INTO public.cosmos_documents (patient_id, document_scope, form_type, filename, status, created_at)
SELECT patient_id, 'patient', 'AOB', aob_url, 'generated', now()
FROM public.patients WHERE aob_url IS NOT NULL AND aob_url != ''
ON CONFLICT (patient_id, form_type) DO NOTHING;

INSERT INTO public.cosmos_documents (patient_id, document_scope, form_type, filename, status, created_at)
SELECT patient_id, 'patient', 'INTAKE', intake_url, 'generated', now()
FROM public.patients WHERE intake_url IS NOT NULL AND intake_url != ''
ON CONFLICT (patient_id, form_type) DO NOTHING;

-- W9 from doctors (billing entities only — no supervisor)
INSERT INTO public.cosmos_documents (doctor_id, document_scope, form_type, filename, status, created_at)
SELECT doctor_id, 'doctor', 'W9', w9_url, 'generated', now()
FROM public.doctors WHERE w9_url IS NOT NULL AND w9_url != '' AND supervising_provider_id IS NULL
ON CONFLICT (doctor_id, form_type) DO NOTHING;
```

Applied to: production and cosmos-dev.

**Backfill result (production):** 3 W9s, 9 AOBs, 9 INTAKEs, 9 NF-2s, plus all visit-scoped docs (ANS, DME, EMG, FC, ICD10, MRI, NF-3, ORTHO, PCE, PSY, PT, RX, SONO, VISIT_PACKET, VNG).

### doctors — W9 backfill for all supervised providers

HANDOVER open item #4 completed. All 4 supervised providers now have `cosmos_documents` rows pointing to supervisor's W9:

```sql
-- Step 1: sync doctors.w9_url
UPDATE doctors d
SET w9_url = sup.w9_url
FROM doctors sup
WHERE d.supervising_provider_id = sup.doctor_id
AND sup.w9_url IS NOT NULL
AND (d.w9_url IS NULL OR d.w9_url != sup.w9_url);

-- Step 2: insert into cosmos_documents registry
INSERT INTO cosmos_documents (doctor_id, document_scope, form_type, filename, status, created_at)
SELECT d.doctor_id, 'doctor', 'W9', sup.w9_url, 'generated', now()
FROM doctors d
JOIN doctors sup ON sup.doctor_id = d.supervising_provider_id
WHERE sup.w9_url IS NOT NULL
ON CONFLICT (doctor_id, form_type) DO UPDATE SET filename = EXCLUDED.filename;
```

Applied to: production. All 7 providers (3 billing-entity MDs + 4 supervised) confirmed in registry.

---

## Session 54 — Data Changes (July 22, 2026)

### No schema DDL this session.

### doctors — w9_url backfill for supervised providers

Supervised provider physicians inherit their supervising MD's W9. `DoctorsSection.tsx` now auto-copies supervisor `w9_url` on save going forward. Manual backfill applied to John Orthobot in production:

```sql
-- Applied to production (ttudxnzmybcwrtqlbtta) via Supabase SQL editor
UPDATE doctors
SET w9_url = 'ccfeb4b0-e61e-48f0-b4fa-bd15c155f6d0_W9.pdf'
WHERE doctor_id = 'e562ce06-d2fd-4146-9165-b1b331028736';
```

**Remaining backfill** (run at next session start or open each provider in Admin and Save):
```sql
UPDATE doctors d
SET w9_url = sup.w9_url
FROM doctors sup
WHERE d.supervising_provider_id = sup.doctor_id
AND sup.w9_url IS NOT NULL
AND (d.w9_url IS NULL OR d.w9_url != sup.w9_url);
```

---

# MIGRATIONS.md
## Cosmos Medical Technologies — Database Migration & Environment Reference
**Created:** Session 47 — July 17, 2026

---
## Environment Map

| Environment | URL | Supabase Project | Branch |
|---|---|---|---|
| Production | cosmosmt.com | cosmos (prod) | `main` |
| Preview / Dev | cosmos-dashboard-nu.vercel.app | cosmos-dev | any feature branch |
| Local | localhost:3000 | cosmos-dev | any |

**How it works:** Vercel automatically injects the correct Supabase credentials based on the deployment environment. Feature branch pushes deploy to Preview (cosmos-dev). Merges to `main` deploy to Production.

---

## Environment Variables

### Production (Vercel — scoped to Production)
- `NEXT_PUBLIC_SUPABASE_URL` — production Supabase project URL (`https://ttudxnzmybcwrtqlbtta.supabase.co`)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — production anon/publishable key
- `SUPABASE_SERVICE_KEY` — production service role key

### Preview (Vercel — scoped to Preview)
- `NEXT_PUBLIC_SUPABASE_URL` — cosmos-dev project URL (`https://tpwbgqfdznqtjqimxric.supabase.co`)
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` — cosmos-dev publishable key
- `SUPABASE_SERVICE_KEY_PREVIEW` — cosmos-dev secret key

### Shared (both environments)
- `NEXT_PUBLIC_PDF_API_URL` — cosmos-api Render URL (same for both)
- `RESEND_API_KEY` — email delivery (same for both)

### Code routing (lib/supabaseServer.ts)
```ts
const supabaseServiceKey =
  process.env.SUPABASE_SERVICE_KEY_PREVIEW ||
  process.env.SUPABASE_SERVICE_KEY!
```

**Warning:** Vercel mobile UI cannot reliably manage per-environment scoping for variables with the same name — always use Vercel desktop UI for env var changes.

---

## Migration Files

### supabase/migrations/000_initial_schema.sql
**Purpose:** Complete schema for a new Cosmos environment — all 34 tables, RLS, indexes, seed data.

**Known limitation:** Generated from batched CSV exports. Must be supplemented with manual fixes (see Session 47 Schema Changes below) until regenerated from a full pg_dump.

### supabase/new_user.sql
Reusable template for creating Cosmos users in any environment.

### supabase/seed_from_production.sql
Seed data copied from production: 20 insurance carriers, 3 lawyers, 7 doctors.

---

## RLS Policy Reference

All tables have:
1. `service_role_all_<table>` — service role bypass (full access for cosmos-api)
2. `authenticated_all_<table>` — authenticated users full access (added Session 47)
3. `authenticated_read_own_profile` — users can read their own user_profiles row

---

## Setting Up a New Environment

**Preferred method (Session 48+): pg_dump from production**

```bash
# 1. Install PostgreSQL client in Termux (if not already installed)
pkg install postgresql -y

# 2. Dump production schema (schema only — no data)
pg_dump "postgresql://postgres:PASSWORD@db.ttudxnzmybcwrtqlbtta.supabase.co:5432/postgres" \
  --schema-only --no-owner --no-acl -f ~/prod_schema.sql

# 3. Apply to new environment
psql "postgresql://postgres:PASSWORD@db.<new-project-id>.supabase.co:5432/postgres" \
  -f ~/prod_schema.sql 2>&1 | tail -30
```

**Notes:**
- Use direct connection (`db.<id>.supabase.co:5432`), NOT the pooler — pg_dump requires direct connection
- DB password must not contain `@` — reset via Supabase dashboard if needed (Settings → Database → Reset password)
- Errors about Supabase internal objects (`s3_multipart_uploads_parts`, `vector_indexes`, publications, event triggers) are harmless — these are system-owned and already exist on all Supabase projects
- After apply, run duplicate FK check (see below) and drop any pre-existing manual patches

**Post-apply: check for duplicate FKs**
```sql
SELECT conrelid::regclass AS table_name, confrelid::regclass AS ref_table, COUNT(*) AS fk_count
FROM pg_constraint
WHERE contype = 'f'
AND conrelid::regclass::text NOT LIKE 'pg_%'
GROUP BY conrelid, confrelid
HAVING COUNT(*) > 1
ORDER BY table_name;
```
Any result with `fk_count > 1` where both point to the same column is a duplicate — drop the manually-named one (prefixed `fk_`).

**After schema apply:**
4. `NOTIFY pgrst, 'reload schema';` in SQL editor
5. Supabase → Authentication → Users → Add user → run `new_user.sql`
6. Vercel env vars (desktop browser only) → add Preview-scoped vars
7. Run `seed_from_production.sql` or use Dev Tools to generate test patients

**Legacy method (deprecated):** `000_initial_schema.sql` + Session 47 Schema Changes SQL. Do not use for new environments — schema is now stale relative to production.

---

## Creating New Users (any environment)

1. Supabase → Authentication → Users → Add user → enter email + password
2. Fill in `supabase/new_user.sql` and run

### Roles reference
| Role | Dashboard | Access Level |
|---|---|---|
| superadmin | All dashboards | Full access + ghost mode + admin panel |
| admin | Admin | Admin panel only, no ghost mode |
| fd | Front Desk V2 | Patient management, scheduling, documents |
| md | MD Chart | Clinical notes, referrals, visit review |
| biller | Billing | Claims, billing events, flags |
| pa | MD Chart | Physician assistant — ghost mode via supervising MD |

---

## Session 49 — Schema Changes (July 18, 2026)

### Migration 032 — Drop needs_review and reviewed_at from referral_appointments

MD review workflow removed (Session 49). Auto-close on upload replaces it.

```sql
ALTER TABLE public.referral_appointments DROP COLUMN IF EXISTS needs_review;
ALTER TABLE public.referral_appointments DROP COLUMN IF EXISTS reviewed_at;
NOTIFY pgrst, 'reload schema';
```

Applied to: production (`ttudxnzmybcwrtqlbtta`) and cosmos-dev (`tpwbgqfdznqtjqimxric`).

### referrals_status_check Constraint Rebuilt

Old constraint included deprecated status values. Rebuilt to match new workflow.

```sql
ALTER TABLE public.referrals DROP CONSTRAINT IF EXISTS referrals_status_check;
ALTER TABLE public.referrals ADD CONSTRAINT referrals_status_check
  CHECK (status IN ('new','scheduled','reschedule','cancelled','awaiting_results','results_received','closed'));
```

Applied to: production and cosmos-dev.

### Storage RLS — referral-documents Bucket

INSERT policy had null `WITH CHECK` — uploads silently failed. Fixed:

```sql
DROP POLICY IF EXISTS "Authenticated users can upload referral docs" ON storage.objects;
CREATE POLICY "Authenticated users can upload referral docs"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'referral-documents');
CREATE POLICY "Authenticated users can delete referral docs"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'referral-documents');
```

Applied to: production and cosmos-dev.

---

## Known Technical Debt (updated Session 56)

- `000_initial_schema.sql` on disk is stale — superseded by pg_dump method (Session 48). Should be removed or replaced with a pointer to the pg_dump approach.
- PostgREST on free-tier Supabase does not reliably pick up FK constraints — use flat selects + client-side joins (Cosmos standard pattern; `app/reports/referrals/page.tsx` is the reference implementation).
- Production DB password was reset Session 48 (removed `@` for pg_dump compatibility). No app code uses this password — only direct DB connections.
- Migration 034 (Phase 4 schema drop) applied to production only. Apply to cosmos-dev when convenient:
  ```sql
  ALTER TABLE public.patients DROP COLUMN IF EXISTS nf2_url;
  ALTER TABLE public.patients DROP COLUMN IF EXISTS aob_url;
  ALTER TABLE public.patients DROP COLUMN IF EXISTS intake_url;
  ALTER TABLE public.patient_visits DROP COLUMN IF EXISTS pce_url;
  DROP TABLE IF EXISTS public.patient_forms;
  NOTIFY pgrst, 'reload schema';
  ```

---

## Session 48 — cosmos-dev Schema Rebuild (July 18, 2026)

cosmos-dev was rebuilt from a production pg_dump after discovering severe schema drift (wrong PK names/types on `patients`, `doctors`; missing PKs on multiple tables). The `000_initial_schema.sql` + manual patch approach was abandoned.

**Rebuild steps performed:**
1. `pkg install postgresql -y` in Termux
2. Production DB password reset (removed `@`)
3. `pg_dump` from production direct connection → `~/prod_schema.sql`
4. cosmos-dev DB password reset (removed `@`)
5. `psql` applied `prod_schema.sql` to cosmos-dev
6. All 34 tables confirmed present
7. Duplicate FK constraints from Session 47 manual patches dropped (8 constraints removed)
8. `referral_providers` PK added (was missing from cosmos-dev)
9. `referrals_referral_provider_id_fkey` FK added to cosmos-dev
10. `NOTIFY pgrst, 'reload schema'` sent
11. Preview `/referrals` and `/reports` confirmed working

**cosmos-dev post-rebuild FK state:** All FK relationships match production. No duplicate constraints remain.

---

## cosmos-dev Seed Data (Session 47)

| Table | Records |
|---|---|
| `user_profiles` | 1 (superadmin: super@cosmos.local / PIN 999999) |
| `doctors` | 7 |
| `insurance_carriers` | 20 |
| `lawyers` | 3 |
| `referral_types` | 14 |
| `practice_settings` | 1 |
| `patients` | 25+ (seed + Dev Tools generated) |

---

*This document is maintained alongside HANDOVER.md. Update after any schema change, new migration, or environment configuration change.*
