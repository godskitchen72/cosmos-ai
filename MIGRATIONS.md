# MIGRATIONS.md
## Cosmos Medical Technologies — Database Migration & Environment Reference
**Created:** Session 47 — July 17, 2026
**Maintained by:** Godskitchen / cosmos-ai repo

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

## Session 47 Schema Changes Applied to cosmos-dev

Run these after `000_initial_schema.sql` on any new environment until migration is regenerated.

```sql
-- Primary keys
ALTER TABLE public.insurance_carriers ADD PRIMARY KEY (id);
ALTER TABLE public.lawyers ADD PRIMARY KEY (id);
ALTER TABLE public.doctors ADD PRIMARY KEY (doctor_id);
ALTER TABLE public.referral_types ADD PRIMARY KEY (id);
ALTER TABLE public.referrals ADD PRIMARY KEY (id);
ALTER TABLE public.referral_appointments ADD PRIMARY KEY (id);
ALTER TABLE public.referral_documents ADD PRIMARY KEY (id);
ALTER TABLE public.referral_timeline ADD PRIMARY KEY (id);
ALTER TABLE public.referral_notes ADD PRIMARY KEY (id);
ALTER TABLE public.patients ADD PRIMARY KEY (patient_id);

-- Column type fix
ALTER TABLE public.doctors
  ALTER COLUMN available_days TYPE JSONB
  USING available_days::text::jsonb;

-- FK constraints
ALTER TABLE public.referrals ADD CONSTRAINT fk_referrals_referral_type FOREIGN KEY (referral_type_id) REFERENCES public.referral_types(id);
ALTER TABLE public.referrals ADD CONSTRAINT fk_referrals_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id);
ALTER TABLE public.referral_appointments ADD CONSTRAINT fk_ref_appointments_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.referral_documents ADD CONSTRAINT fk_ref_documents_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.referral_timeline ADD CONSTRAINT fk_ref_timeline_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.referral_notes ADD CONSTRAINT fk_ref_notes_referral FOREIGN KEY (referral_id) REFERENCES public.referrals(id);
ALTER TABLE public.patient_visits ADD CONSTRAINT fk_patient_visits_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id);
ALTER TABLE public.appointments ADD CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id);

-- RLS policies
CREATE POLICY "authenticated_read_own_profile" ON public.user_profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "authenticated_all_lawyers" ON public.lawyers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_carriers" ON public.insurance_carriers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_doctors" ON public.doctors FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_providers" ON public.referral_providers FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_office_locations" ON public.office_locations FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_patients" ON public.patients FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_appointments" ON public.appointments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referrals" ON public.referrals FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_appointments" ON public.referral_appointments FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_documents" ON public.referral_documents FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_referral_types" ON public.referral_types FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_patient_visits" ON public.patient_visits FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_all_patient_forms" ON public.patient_forms FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';
```

---

## Known Technical Debt

- `000_initial_schema.sql` on disk is stale — superseded by pg_dump method (Session 48). Should be removed or replaced with a note pointing to the pg_dump approach to prevent confusion.
- `patients.intake_url` column exists in production via manual SQL — not captured in any migration file. Schema drift risk on rebuild (pg_dump will capture it going forward).
- `referral_appointments.needs_review` and `reviewed_at` are vestigial — flagged for cleanup.
- PostgREST on free-tier Supabase does not reliably pick up FK constraints — use flat selects + client-side joins (Cosmos standard pattern; `app/reports/referrals/page.tsx` is the reference implementation).
- Production DB password was reset Session 48 (removed `@` for pg_dump compatibility). No app code uses this password — only direct DB connections (pg_dump, psql). cosmos-dev DB password also reset same session.

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
