-- Hotfix: remove recursive RLS evaluation on public.space_members (42P17)
-- Run this once in Supabase SQL Editor on the affected project.

CREATE OR REPLACE FUNCTION public.can_access_space(
  p_space_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = p_space_id
      AND s.owner_id = p_user_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = p_space_id
      AND sm.user_id = p_user_id
  );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_space(
  p_space_id UUID,
  p_user_id UUID DEFAULT auth.uid()
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.spaces s
    WHERE s.id = p_space_id
      AND s.owner_id = p_user_id
  )
  OR EXISTS (
    SELECT 1
    FROM public.space_members sm
    WHERE sm.space_id = p_space_id
      AND sm.user_id = p_user_id
      AND sm.role IN ('owner', 'admin')
  );
$$;

DROP POLICY IF EXISTS "Users can view own spaces" ON public.spaces;
CREATE POLICY "Users can view own spaces"
  ON public.spaces FOR SELECT
  USING (public.can_access_space(id, auth.uid()));

DROP POLICY IF EXISTS "Members can view space members" ON public.space_members;
CREATE POLICY "Members can view space members"
  ON public.space_members FOR SELECT
  USING (public.can_access_space(space_id, auth.uid()));

DROP POLICY IF EXISTS "Owner and admin can manage space members" ON public.space_members;
CREATE POLICY "Owner and admin can manage space members"
  ON public.space_members FOR ALL
  USING (public.can_manage_space(space_id, auth.uid()))
  WITH CHECK (public.can_manage_space(space_id, auth.uid()));

DROP POLICY IF EXISTS "Users can view relevant invitations" ON public.invitations;
CREATE POLICY "Users can view relevant invitations"
  ON public.invitations FOR SELECT
  USING (
    invited_by = auth.uid()
    OR invited_user_id = auth.uid()
    OR lower(invited_email) = lower(coalesce(auth.jwt()->>'email', ''))
    OR public.can_manage_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Owner and admin can create invitations" ON public.invitations;
CREATE POLICY "Owner and admin can create invitations"
  ON public.invitations FOR INSERT
  WITH CHECK (
    invited_by = auth.uid()
    AND public.can_manage_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Owner/admin/invitee can update invitation status" ON public.invitations;
CREATE POLICY "Owner/admin/invitee can update invitation status"
  ON public.invitations FOR UPDATE
  USING (
    invited_user_id = auth.uid()
    OR lower(invited_email) = lower(coalesce(auth.jwt()->>'email', ''))
    OR public.can_manage_space(space_id, auth.uid())
  )
  WITH CHECK (
    invited_user_id = auth.uid()
    OR lower(invited_email) = lower(coalesce(auth.jwt()->>'email', ''))
    OR public.can_manage_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Members can view activity log" ON public.activity_log;
CREATE POLICY "Members can view activity log"
  ON public.activity_log FOR SELECT
  USING (public.can_access_space(space_id, auth.uid()));

DROP POLICY IF EXISTS "Members can insert activity log" ON public.activity_log;
CREATE POLICY "Members can insert activity log"
  ON public.activity_log FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND public.can_access_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Space members can view transactions" ON public.transactions;
CREATE POLICY "Space members can view transactions"
  ON public.transactions FOR SELECT
  USING (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Space members can insert transactions" ON public.transactions;
CREATE POLICY "Space members can insert transactions"
  ON public.transactions FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND (
      space_id IS NULL
      OR public.can_access_space(space_id, auth.uid())
    )
  );

DROP POLICY IF EXISTS "Space members can update transactions" ON public.transactions;
CREATE POLICY "Space members can update transactions"
  ON public.transactions FOR UPDATE
  USING (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_manage_space(space_id, auth.uid())
    OR auth.uid() = user_id
  )
  WITH CHECK (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_manage_space(space_id, auth.uid())
    OR auth.uid() = user_id
  );

DROP POLICY IF EXISTS "Space members can delete transactions" ON public.transactions;
CREATE POLICY "Space members can delete transactions"
  ON public.transactions FOR DELETE
  USING (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_manage_space(space_id, auth.uid())
    OR auth.uid() = user_id
  );

DROP POLICY IF EXISTS "Space members can manage budgets" ON public.budgets;
CREATE POLICY "Space members can manage budgets"
  ON public.budgets FOR ALL
  USING (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  )
  WITH CHECK (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Space members can manage accounts" ON public.accounts;
CREATE POLICY "Space members can manage accounts"
  ON public.accounts FOR ALL
  USING (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  )
  WITH CHECK (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  );

DROP POLICY IF EXISTS "Space members can manage goals" ON public.savings_goals;
CREATE POLICY "Space members can manage goals"
  ON public.savings_goals FOR ALL
  USING (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  )
  WITH CHECK (
    (space_id IS NULL AND auth.uid() = user_id)
    OR public.can_access_space(space_id, auth.uid())
  );
