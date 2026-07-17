-- ============================================================
-- Cosmos Medical Technologies
-- new_user.sql — Run this to create a new Cosmos user
-- ============================================================
-- STEP 1: Create the auth user first in Supabase dashboard
--         Authentication → Users → Add user → copy the email
-- STEP 2: Fill in the values below and run in SQL Editor
-- ============================================================

DO $$
DECLARE
  v_id UUID;
BEGIN
  -- Find the auth user by email
  SELECT id INTO v_id
  FROM auth.users
  WHERE email = 'REPLACE_WITH_EMAIL';

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Auth user not found for email: REPLACE_WITH_EMAIL — create them in Authentication → Users first';
  END IF;

  -- Insert Cosmos profile
  INSERT INTO public.user_profiles (
    id,
    role,
    full_name,
    pin_hint,
    active,
    doctor_id,
    fd_column_prefs
  ) VALUES (
    v_id,
    'REPLACE_WITH_ROLE',   -- superadmin | admin | fd | md | biller | pa
    'REPLACE_WITH_NAME',   -- Full name as it appears in the app
    'REPLACE_WITH_HINT',   -- PIN hint shown on lockout e.g. ****99
    true,
    null,                  -- Set to doctor UUID if role is 'md'
    null
  )
  ON CONFLICT (id) DO UPDATE
    SET role     = EXCLUDED.role,
        full_name = EXCLUDED.full_name,
        pin_hint  = EXCLUDED.pin_hint,
        active    = EXCLUDED.active;

  RAISE NOTICE 'User profile created for % (role: %)', 'REPLACE_WITH_NAME', 'REPLACE_WITH_ROLE';
END $$;

-- ============================================================
-- Available roles:
--   superadmin  — full access, ghost mode, admin panel
--   admin       — admin panel, no ghost mode
--   fd          — front desk dashboard
--   md          — MD dashboard (requires doctor_id)
--   biller      — billing dashboard
--   pa          — physician assistant (ghost mode via MD)
-- ============================================================
