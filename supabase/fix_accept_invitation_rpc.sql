-- Hotfix: accept shared-space invitation via SECURITY DEFINER RPC
-- Run this once in Supabase SQL Editor, then reload PostgREST schema.

CREATE OR REPLACE FUNCTION public.accept_space_invitation(
  p_invitation_id UUID
)
RETURNS public.invitations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite public.invitations%ROWTYPE;
  v_user_id UUID;
  v_user_email TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_user_email := lower(coalesce(auth.jwt()->>'email', ''));

  SELECT *
  INTO v_invite
  FROM public.invitations
  WHERE id = p_invitation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_found';
  END IF;

  IF v_invite.status <> 'pending' THEN
    RAISE EXCEPTION 'invitation_not_pending';
  END IF;

  IF v_invite.expires_at < NOW() THEN
    UPDATE public.invitations
    SET status = 'expired'
    WHERE id = p_invitation_id;
    RAISE EXCEPTION 'invitation_expired';
  END IF;

  IF v_invite.invited_user_id IS NOT NULL
      AND v_invite.invited_user_id <> v_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF v_invite.invited_user_id IS NULL
      AND lower(v_invite.invited_email) <> v_user_email THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.space_members (space_id, user_id, role)
  VALUES (v_invite.space_id, v_user_id, 'member')
  ON CONFLICT (space_id, user_id) DO NOTHING;

  UPDATE public.invitations
  SET invited_user_id = v_user_id,
      status = 'accepted'
  WHERE id = p_invitation_id
  RETURNING * INTO v_invite;

  RETURN v_invite;
END;
$$;

REVOKE ALL ON FUNCTION public.accept_space_invitation(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.accept_space_invitation(UUID) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
