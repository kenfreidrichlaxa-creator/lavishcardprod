-- ============================================================
-- STAFF TABLE MIGRATION
-- Centralized staff list managed by Super Admin.
-- ============================================================

-- 1. Create staff table
CREATE TABLE IF NOT EXISTS public.staff (
  id            text        PRIMARY KEY DEFAULT ('stf_' || substr(md5(random()::text), 1, 12)),
  full_name     text        NOT NULL,
  phone         text        NOT NULL DEFAULT '',
  email         text        NOT NULL DEFAULT '',
  "position"      text        NOT NULL DEFAULT 'stylist',
  status        text        NOT NULL DEFAULT 'active',
  joined_date   date        NOT NULL DEFAULT CURRENT_DATE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Disable RLS (same as other tables)
ALTER TABLE public.staff DISABLE ROW LEVEL SECURITY;

-- 2. RPC: list all staff
CREATE OR REPLACE FUNCTION public.list_staff()
RETURNS TABLE (
  id          text,
  full_name   text,
  phone       text,
  email       text,
  "position"    text,
  status      text,
  joined_date date
)
LANGUAGE sql STABLE AS $$
  SELECT id, full_name, phone, email, "position", status, joined_date
  FROM   public.staff
  ORDER  BY full_name;
$$;

-- 3. RPC: create staff member
CREATE OR REPLACE FUNCTION public.create_staff_member(
  p_full_name   text,
  p_phone       text    DEFAULT '',
  p_email       text    DEFAULT '',
  p_position    text    DEFAULT 'stylist',
  p_joined_date date    DEFAULT CURRENT_DATE,
  p_performed_by text   DEFAULT 'admin'
)
RETURNS json
LANGUAGE plpgsql AS $$
DECLARE
  v_id text;
BEGIN
  IF trim(p_full_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;

  v_id := 'stf_' || substr(md5(random()::text), 1, 12);

  INSERT INTO public.staff (id, full_name, phone, email, "position", joined_date)
  VALUES (v_id, trim(p_full_name), trim(p_phone), trim(p_email), p_position, p_joined_date);

  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 4. RPC: update staff member
CREATE OR REPLACE FUNCTION public.update_staff_member(
  p_id          text,
  p_full_name   text,
  p_phone       text    DEFAULT '',
  p_email       text    DEFAULT '',
  p_position    text    DEFAULT 'stylist',
  p_joined_date date    DEFAULT CURRENT_DATE,
  p_performed_by text   DEFAULT 'admin'
)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  IF trim(p_full_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;

  UPDATE public.staff SET
    full_name   = trim(p_full_name),
    phone       = trim(p_phone),
    email       = trim(p_email),
    "position"    = p_position,
    joined_date = p_joined_date,
    updated_at  = now()
  WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Staff not found.');
  END IF;

  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 5. RPC: set staff status (activate / deactivate)
CREATE OR REPLACE FUNCTION public.set_staff_status(
  p_id     text,
  p_active boolean
)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.staff
  SET    status = CASE WHEN p_active THEN 'active' ELSE 'inactive' END,
         updated_at = now()
  WHERE  id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Staff not found.');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- 6. RPC: delete staff member
CREATE OR REPLACE FUNCTION public.delete_staff_member(p_id text)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.staff WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Staff not found.');
  END IF;

  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

