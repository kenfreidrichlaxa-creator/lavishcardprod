-- Add discounted_price column to services table
ALTER TABLE public.services
  ADD COLUMN IF NOT EXISTS discounted_price numeric DEFAULT NULL;

-- Update upsert_service to accept and save discounted_price
CREATE OR REPLACE FUNCTION public.upsert_service(
  p_id                  text    DEFAULT NULL,
  p_name                text    DEFAULT '',
  p_category_key        text    DEFAULT 'other',
  p_price               numeric DEFAULT 0,
  p_duration            integer DEFAULT 0,
  p_status              text    DEFAULT 'active',
  p_description         text    DEFAULT NULL,
  p_primary_category_id uuid    DEFAULT NULL,
  p_promo_category_id   uuid    DEFAULT NULL,
  p_performed_by        text    DEFAULT 'admin',
  p_discounted_price    numeric DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql AS $$
DECLARE
  v_id           text;
  v_cat          text[] := public._service_category(p_category_key);
  v_status       text   := CASE WHEN lower(coalesce(p_status,'active')) = 'inactive'
                                THEN 'inactive' ELSE 'active' END;
  v_new          boolean := (p_id IS NULL OR length(trim(p_id)) = 0);
  v_primary_name text;
  v_promo_name   text;
BEGIN
  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RETURN json_build_object('success', false, 'error', 'Service name is required.');
  END IF;
  IF coalesce(p_price, -1) < 0 THEN
    RETURN json_build_object('success', false, 'error', 'Price must be zero or more.');
  END IF;

  IF p_primary_category_id IS NOT NULL THEN
    SELECT name INTO v_primary_name
    FROM   public.service_primary_categories
    WHERE  id = p_primary_category_id;
  END IF;

  IF p_promo_category_id IS NOT NULL THEN
    SELECT name INTO v_promo_name
    FROM   public.service_promo_categories
    WHERE  id = p_promo_category_id;
  END IF;

  IF v_new THEN
    v_id := 'svc_' || substr(md5(random()::text), 1, 12);
    INSERT INTO public.services
      (id, name, category_id, category_name, price, duration_minutes,
       description, status, show_in_pos,
       primary_category_id, primary_category_name,
       promo_category_id,   promo_category_name,
       discounted_price)
    VALUES
      (v_id, trim(p_name), v_cat[1], v_cat[2], round(p_price, 2),
       coalesce(p_duration, 0),
       nullif(trim(coalesce(p_description, '')), ''),
       v_status, true,
       p_primary_category_id, v_primary_name,
       p_promo_category_id,   v_promo_name,
       CASE WHEN p_discounted_price IS NOT NULL THEN round(p_discounted_price, 2) ELSE NULL END);
  ELSE
    v_id := p_id;
    UPDATE public.services SET
      name                  = trim(p_name),
      category_id           = v_cat[1],
      category_name         = v_cat[2],
      price                 = round(p_price, 2),
      duration_minutes      = coalesce(p_duration, 0),
      description           = nullif(trim(coalesce(p_description, '')), ''),
      status                = v_status,
      primary_category_id   = p_primary_category_id,
      primary_category_name = v_primary_name,
      promo_category_id     = p_promo_category_id,
      promo_category_name   = v_promo_name,
      discounted_price      = CASE WHEN p_discounted_price IS NOT NULL THEN round(p_discounted_price, 2) ELSE NULL END,
      updated_at            = now()
    WHERE id = v_id;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'Service not found.');
    END IF;
  END IF;

  BEGIN
    PERFORM public.log_audit(
      CASE WHEN v_new THEN 'SERVICE_CREATE' ELSE 'SERVICE_UPDATE' END,
      'service', v_id, '', '',
      p_performed_by, 'admin',
      (CASE WHEN v_new THEN 'Added' ELSE 'Updated' END) ||
        ' service "' || trim(p_name) || '" (' ||
        to_char(round(p_price, 2), 'FM999,999,990.00') || ')',
      json_build_object(
        'service_id', v_id, 'name', trim(p_name),
        'price', round(p_price, 2),
        'discounted_price', p_discounted_price,
        'category', v_cat[2], 'status', v_status
      )::jsonb
    );
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RETURN json_build_object('success', true, 'id', v_id, 'is_new', v_new);
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
