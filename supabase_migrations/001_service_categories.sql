-- ============================================================
-- SERVICE CATEGORIES MIGRATION
-- Run this in your Supabase SQL Editor (production project)
-- ============================================================

-- ── 1. Primary Categories table ──────────────────────────────
CREATE TABLE IF NOT EXISTS service_primary_categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  sort_order  integer NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ── 2. Promo / Secondary Categories table ────────────────────
CREATE TABLE IF NOT EXISTS service_promo_categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  description text NOT NULL DEFAULT '',
  sort_order  integer NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ── 3. Add category columns to services table ────────────────
ALTER TABLE services
  ADD COLUMN IF NOT EXISTS primary_category_id   uuid REFERENCES service_primary_categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS primary_category_name text,
  ADD COLUMN IF NOT EXISTS promo_category_id     uuid REFERENCES service_promo_categories(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS promo_category_name   text;

-- ── 4. RPCs: Primary Categories ──────────────────────────────

CREATE OR REPLACE FUNCTION list_primary_categories(p_active_only boolean DEFAULT false)
RETURNS TABLE (
  id          uuid,
  name        text,
  sort_order  integer,
  is_active   boolean
)
LANGUAGE sql STABLE AS $$
  SELECT id, name, sort_order, is_active
  FROM   service_primary_categories
  WHERE  (NOT p_active_only OR is_active = true)
  ORDER  BY sort_order, name;
$$;

CREATE OR REPLACE FUNCTION create_primary_category(
  p_name       text,
  p_sort_order integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql AS $$
DECLARE
  v_id uuid;
BEGIN
  IF trim(p_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;

  INSERT INTO service_primary_categories (name, sort_order)
  VALUES (trim(p_name), p_sort_order)
  RETURNING id INTO v_id;

  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION update_primary_category(
  p_id         uuid,
  p_name       text,
  p_sort_order integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  IF trim(p_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;

  UPDATE service_primary_categories
  SET    name = trim(p_name), sort_order = p_sort_order, updated_at = now()
  WHERE  id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Category not found.');
  END IF;

  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION set_primary_category_active(
  p_id     uuid,
  p_active boolean
)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE service_primary_categories
  SET    is_active = p_active, updated_at = now()
  WHERE  id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Category not found.');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION delete_primary_category(p_id uuid)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  -- Unlink services using this category first
  UPDATE services
  SET    primary_category_id = NULL, primary_category_name = NULL
  WHERE  primary_category_id = p_id;

  DELETE FROM service_primary_categories WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Category not found.');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 5. RPCs: Promo Categories ─────────────────────────────────

CREATE OR REPLACE FUNCTION list_promo_categories(p_active_only boolean DEFAULT false)
RETURNS TABLE (
  id          uuid,
  name        text,
  description text,
  sort_order  integer,
  is_active   boolean
)
LANGUAGE sql STABLE AS $$
  SELECT id, name, description, sort_order, is_active
  FROM   service_promo_categories
  WHERE  (NOT p_active_only OR is_active = true)
  ORDER  BY sort_order, name;
$$;

CREATE OR REPLACE FUNCTION create_promo_category(
  p_name        text,
  p_description text DEFAULT '',
  p_sort_order  integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql AS $$
DECLARE
  v_id uuid;
BEGIN
  IF trim(p_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;

  INSERT INTO service_promo_categories (name, description, sort_order)
  VALUES (trim(p_name), trim(coalesce(p_description, '')), p_sort_order)
  RETURNING id INTO v_id;

  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION update_promo_category(
  p_id          uuid,
  p_name        text,
  p_description text DEFAULT '',
  p_sort_order  integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  IF trim(p_name) = '' THEN
    RETURN json_build_object('success', false, 'error', 'Name is required.');
  END IF;

  UPDATE service_promo_categories
  SET    name = trim(p_name),
         description = trim(coalesce(p_description, '')),
         sort_order = p_sort_order,
         updated_at = now()
  WHERE  id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Category not found.');
  END IF;

  RETURN json_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE OR REPLACE FUNCTION set_promo_category_active(
  p_id     uuid,
  p_active boolean
)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE service_promo_categories
  SET    is_active = p_active, updated_at = now()
  WHERE  id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Category not found.');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION delete_promo_category(p_id uuid)
RETURNS json
LANGUAGE plpgsql AS $$
BEGIN
  -- Unlink services using this promo first
  UPDATE services
  SET    promo_category_id = NULL, promo_category_name = NULL
  WHERE  promo_category_id = p_id;

  DELETE FROM service_promo_categories WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Category not found.');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

-- ── 6. Update upsert_service to accept category IDs ──────────
-- This replaces the existing upsert_service function.
-- Check your current upsert_service first and merge if needed.
CREATE OR REPLACE FUNCTION upsert_service(
  p_id                  uuid DEFAULT NULL,
  p_name                text DEFAULT '',
  p_category_key        text DEFAULT 'other',
  p_price               numeric DEFAULT 0,
  p_duration            integer DEFAULT 0,
  p_status              text DEFAULT 'active',
  p_description         text DEFAULT NULL,
  p_primary_category_id uuid DEFAULT NULL,
  p_promo_category_id   uuid DEFAULT NULL,
  p_performed_by        text DEFAULT 'admin'
)
RETURNS json
LANGUAGE plpgsql AS $$
DECLARE
  v_id           uuid;
  v_primary_name text;
  v_promo_name   text;
BEGIN
  -- Resolve category names for denormalized columns
  IF p_primary_category_id IS NOT NULL THEN
    SELECT name INTO v_primary_name
    FROM   service_primary_categories
    WHERE  id = p_primary_category_id;
  END IF;

  IF p_promo_category_id IS NOT NULL THEN
    SELECT name INTO v_promo_name
    FROM   service_promo_categories
    WHERE  id = p_promo_category_id;
  END IF;

  IF p_id IS NULL THEN
    -- INSERT
    INSERT INTO services (
      name, category_name, price, duration_minutes, status,
      description, primary_category_id, primary_category_name,
      promo_category_id, promo_category_name
    ) VALUES (
      trim(p_name), p_category_key, p_price, p_duration, p_status,
      p_description, p_primary_category_id, v_primary_name,
      p_promo_category_id, v_promo_name
    )
    RETURNING id INTO v_id;
  ELSE
    -- UPDATE
    UPDATE services SET
      name                  = trim(p_name),
      category_name         = p_category_key,
      price                 = p_price,
      duration_minutes      = p_duration,
      status                = p_status,
      description           = p_description,
      primary_category_id   = p_primary_category_id,
      primary_category_name = v_primary_name,
      promo_category_id     = p_promo_category_id,
      promo_category_name   = v_promo_name
    WHERE id = p_id
    RETURNING id INTO v_id;

    IF v_id IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'Service not found.');
    END IF;
  END IF;

  RETURN json_build_object('success', true, 'id', v_id);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
