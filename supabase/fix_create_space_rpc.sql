-- Hotfix: create shared space via SECURITY DEFINER RPC
-- Run this in Supabase SQL Editor (once), then retry "Buat Shared Space".

CREATE OR REPLACE FUNCTION public.create_space_with_owner(p_name TEXT)
RETURNS public.spaces
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
  v_space public.spaces%ROWTYPE;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_name IS NULL OR length(trim(p_name)) = 0 THEN
    RAISE EXCEPTION 'invalid_space_name';
  END IF;

  INSERT INTO public.spaces (name, owner_id)
  VALUES (trim(p_name), v_uid)
  RETURNING * INTO v_space;

  INSERT INTO public.space_members (space_id, user_id, role)
  VALUES (v_space.id, v_uid, 'owner')
  ON CONFLICT (space_id, user_id) DO UPDATE
  SET role = EXCLUDED.role;

  RETURN v_space;
END;
$$;

REVOKE ALL ON FUNCTION public.create_space_with_owner(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_space_with_owner(TEXT) TO authenticated;
