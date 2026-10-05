-- ============================================================
-- STAFF POSITIONS TABLE
-- Dynamic positions managed by Super Admin.
-- ============================================================

-- 1. Create staff_positions table
CREATE TABLE IF NOT EXISTS public.staff_positions (
  id         text        PRIMARY KEY DEFAULT ('pos_' || substr(md5(random()::text), 1, 12)),
  name       text        NOT NULL,
  sort_order integer     NOT NULL DEFAULT 0,
  is_active  boolean     NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.staff_positions DISABLE ROW LEVEL SECURITY;

-- 2. Add position_id + position_name columns to staff table
ALTER TABLE public.staff
  ADD COLUMN IF NOT EXISTS position_id   text REFERENCES public.staff_positions(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS position_name text;

-- 3. Seed default positions (same as old hardcoded enum)
INSERT INTO public.staff_positions (name, sort_order) VALUES
  ('Stylist',        1),
  ('Senior Stylist', 2),
  ('Manager',        3),
  ('Cashier',        4),
  ('Receptionist',   5),
  ('Administrator',  6)
ON CONFLICT DO NOTHING;

-- 4. RPC: list positions
CREATE OR REPLACE FUNCTION public.list_staff_positions(p_active_only boolean DEFAULT false)
RETURNS TABLE (id text, name text, sort_order integer, is_active boolean)
LANGUAGE sql STABLE AS $$
  SELECT id, name, sort_order, is_active
  FROM   public.staff_positions
  WHERE  (NOT p_active_only OR is_active = true)
  ORDER  BY sort_order, name;
$$;

-- 5. RPC: create position
CREATE OR REPLACE FUNCTION public.create_staff_position(
  p_name       text,
  p_sort_order integer DEFAULT 0
)
RETURNS json LANGUAGE plpgsql AS $$
DECLARE v_id text;
BEGIN
  IF trim(p_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;
  v_id := 'pos_' || substr(md5(random()::text), 1, 12);
  INSERT INTO public.staff_positions (id, name, sort_order)
  VALUES (v_id, trim(p_name), p_sort_order);
  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 6. RPC: update position
CREATE OR REPLACE FUNCTION public.update_staff_position(
  p_id         text,
  p_name       text,
  p_sort_order integer DEFAULT 0
)
RETURNS json LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.staff_positions
  SET    name = trim(p_name), sort_order = p_sort_order, updated_at = now()
  WHERE  id = p_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Position not found.');
  END IF;
  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 7. RPC: set position active/inactive
CREATE OR REPLACE FUNCTION public.set_staff_position_active(p_id text, p_active boolean)
RETURNS json LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.staff_positions
  SET    is_active = p_active, updated_at = now()
  WHERE  id = p_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Position not found.');
  END IF;
  RETURN json_build_object('success', true);
END;
$$;

-- 8. RPC: delete position
CREATE OR REPLACE FUNCTION public.delete_staff_position(p_id text)
RETURNS json LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.staff SET position_id = NULL, position_name = NULL
  WHERE  position_id = p_id;
  DELETE FROM public.staff_positions WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Position not found.');
  END IF;
  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 9. Update create_staff_member and update_staff_member to accept position_id
DROP FUNCTION IF EXISTS public.create_staff_member(text,text,text,text,date,text);
DROP FUNCTION IF EXISTS public.update_staff_member(text,text,text,text,text,date,text);
CREATE OR REPLACE FUNCTION public.create_staff_member(
  p_full_name    text,
  p_phone        text    DEFAULT '',
  p_email        text    DEFAULT '',
  p_position     text    DEFAULT 'stylist',
  p_position_id  text    DEFAULT NULL,
  p_joined_date  date    DEFAULT CURRENT_DATE,
  p_performed_by text    DEFAULT 'admin'
)
RETURNS json LANGUAGE plpgsql AS $$
DECLARE
  v_id        text;
  v_pos_name  text;
BEGIN
  IF trim(p_full_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;
  IF p_position_id IS NOT NULL THEN
    SELECT name INTO v_pos_name FROM public.staff_positions WHERE id = p_position_id;
  END IF;
  v_id := 'stf_' || substr(md5(random()::text), 1, 12);
  INSERT INTO public.staff (id, full_name, phone, email, "position", position_id, position_name, joined_date)
  VALUES (v_id, trim(p_full_name), trim(p_phone), trim(p_email),
          coalesce(v_pos_name, p_position), p_position_id, v_pos_name, p_joined_date);
  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_staff_member(
  p_id           text,
  p_full_name    text,
  p_phone        text    DEFAULT '',
  p_email        text    DEFAULT '',
  p_position     text    DEFAULT 'stylist',
  p_position_id  text    DEFAULT NULL,
  p_joined_date  date    DEFAULT CURRENT_DATE,
  p_performed_by text    DEFAULT 'admin'
)
RETURNS json LANGUAGE plpgsql AS $$
DECLARE v_pos_name text;
BEGIN
  IF trim(p_full_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;
  IF p_position_id IS NOT NULL THEN
    SELECT name INTO v_pos_name FROM public.staff_positions WHERE id = p_position_id;
  END IF;
  UPDATE public.staff SET
    full_name     = trim(p_full_name),
    phone         = trim(p_phone),
    email         = trim(p_email),
    "position"    = coalesce(v_pos_name, p_position),
    position_id   = p_position_id,
    position_name = v_pos_name,
    joined_date   = p_joined_date,
    updated_at    = now()
  WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Staff not found.');
  END IF;
  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 10. Update list_staff to return position_id and position_name
DROP FUNCTION IF EXISTS public.list_staff();
CREATE OR REPLACE FUNCTION public.list_staff()
RETURNS TABLE (
  id            text,
  full_name     text,
  phone         text,
  email         text,
  "position"    text,
  position_id   text,
  position_name text,
  status        text,
  joined_date   date
)
LANGUAGE sql STABLE AS $$
  SELECT id, full_name, phone, email, "position", position_id, position_name, status, joined_date
  FROM   public.staff
  ORDER  BY full_name;
$$;
