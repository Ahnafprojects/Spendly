-- Hotfix: resolve 42501 RLS error when creating shared space
-- Run in Supabase SQL Editor (once).

ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.space_members ENABLE ROW LEVEL SECURITY;

-- Clean all existing policies on spaces (avoid conflicting legacy policies)
DO $$
DECLARE
  p RECORD;
BEGIN
  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'spaces'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.spaces', p.policyname);
  END LOOP;
END $$;

-- Clean all existing policies on space_members (avoid insert blocked after space creation)
DO $$
DECLARE
  p RECORD;
BEGIN
  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'space_members'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.space_members', p.policyname);
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.spaces TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.space_members TO authenticated;

-- Spaces policies
CREATE POLICY "spaces_select_member_or_owner"
ON public.spaces
FOR SELECT
USING (
  owner_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = spaces.id
      AND sm.user_id = auth.uid()
  )
);

CREATE POLICY "spaces_insert_owner_only"
ON public.spaces
FOR INSERT
WITH CHECK (
  auth.uid() IS NOT NULL
  AND owner_id = auth.uid()
);

CREATE POLICY "spaces_update_owner_only"
ON public.spaces
FOR UPDATE
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

CREATE POLICY "spaces_delete_owner_only"
ON public.spaces
FOR DELETE
USING (owner_id = auth.uid());

-- space_members policies
CREATE POLICY "space_members_select_owner_or_member"
ON public.space_members
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = space_members.space_id
      AND s.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = space_members.space_id
      AND sm.user_id = auth.uid()
  )
);

-- owner can add members (including self-owner row right after creating space)
CREATE POLICY "space_members_insert_owner_only"
ON public.space_members
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = space_members.space_id
      AND s.owner_id = auth.uid()
  )
);

-- owner/admin can update/delete members
CREATE POLICY "space_members_update_owner_admin"
ON public.space_members
FOR UPDATE
USING (
  EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = space_members.space_id
      AND s.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = space_members.space_id
      AND sm.user_id = auth.uid()
      AND sm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = space_members.space_id
      AND s.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = space_members.space_id
      AND sm.user_id = auth.uid()
      AND sm.role IN ('owner', 'admin')
  )
);

CREATE POLICY "space_members_delete_owner_admin"
ON public.space_members
FOR DELETE
USING (
  EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = space_members.space_id
      AND s.owner_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = space_members.space_id
      AND sm.user_id = auth.uid()
      AND sm.role IN ('owner', 'admin')
  )
);
