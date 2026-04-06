-- Shared Spaces migration for Spendly premium

-- 1) Core tables
CREATE TABLE IF NOT EXISTS public.spaces (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(50) NOT NULL,
  owner_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.space_members (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id    UUID NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role        VARCHAR(10) NOT NULL DEFAULT 'member'
              CHECK (role IN ('owner','admin','member')),
  joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (space_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.invitations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id       UUID NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  invited_by     UUID NOT NULL REFERENCES public.profiles(id),
  invited_email  VARCHAR(255) NOT NULL,
  invited_user_id UUID REFERENCES public.profiles(id),
  status         VARCHAR(10) NOT NULL DEFAULT 'pending'
                 CHECK (status IN ('pending','accepted','declined','expired')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at     TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days'
);

CREATE TABLE IF NOT EXISTS public.activity_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id    UUID NOT NULL REFERENCES public.spaces(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id),
  action      VARCHAR(50) NOT NULL,
  description TEXT NOT NULL,
  metadata    JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_spaces_owner ON public.spaces(owner_id);
CREATE INDEX IF NOT EXISTS idx_space_members_space_user ON public.space_members(space_id, user_id);
CREATE INDEX IF NOT EXISTS idx_invites_space_status ON public.invitations(space_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_invites_email_status ON public.invitations(invited_email, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_activity_space_created ON public.activity_log(space_id, created_at DESC);

-- 2) Extend existing domain tables
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS space_id UUID REFERENCES public.spaces(id) ON DELETE SET NULL;
ALTER TABLE public.budgets ADD COLUMN IF NOT EXISTS space_id UUID REFERENCES public.spaces(id) ON DELETE SET NULL;
ALTER TABLE public.savings_goals ADD COLUMN IF NOT EXISTS space_id UUID REFERENCES public.spaces(id) ON DELETE SET NULL;
ALTER TABLE public.accounts ADD COLUMN IF NOT EXISTS space_id UUID REFERENCES public.spaces(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_space_date ON public.transactions(space_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_budgets_space_month ON public.budgets(space_id, month DESC);
CREATE INDEX IF NOT EXISTS idx_accounts_space_created ON public.accounts(space_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_savings_goals_space_target ON public.savings_goals(space_id, target_date DESC);

-- Budget uniqueness for shared spaces
CREATE UNIQUE INDEX IF NOT EXISTS idx_budgets_space_category_month_unique
  ON public.budgets(space_id, category, month)
  WHERE space_id IS NOT NULL;

-- Access helpers (avoid recursive RLS checks on space_members)
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

-- 3) RLS for new tables
ALTER TABLE public.spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.space_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own spaces" ON public.spaces;
CREATE POLICY "Users can view own spaces"
  ON public.spaces FOR SELECT
  USING (public.can_access_space(id, auth.uid()));

DROP POLICY IF EXISTS "Owner can create space" ON public.spaces;
CREATE POLICY "Owner can create space"
  ON public.spaces FOR INSERT
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Owner can update space" ON public.spaces;
CREATE POLICY "Owner can update space"
  ON public.spaces FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "Owner can delete space" ON public.spaces;
CREATE POLICY "Owner can delete space"
  ON public.spaces FOR DELETE
  USING (owner_id = auth.uid());

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

-- 4) Shared policies on existing tables (additional policies)
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

-- Similar shared policies for budgets/accounts/savings_goals
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

-- 5) RPC helper: resolve user by email from auth.users
CREATE OR REPLACE FUNCTION public.find_user_id_by_email(p_email TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  SELECT id
  INTO v_user_id
  FROM auth.users
  WHERE lower(email) = lower(trim(p_email))
  LIMIT 1;

  RETURN v_user_id;
END;
$$;

-- 6) RPC helper: accept invitation atomically
CREATE OR REPLACE FUNCTION public.accept_space_invitation(p_invitation_id UUID)
RETURNS public.invitations
LANGUAGE plpgsql
SECURITY DEFINER
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

  IF v_invite.invited_user_id IS NOT NULL AND v_invite.invited_user_id <> v_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF v_invite.invited_user_id IS NULL AND lower(v_invite.invited_email) <> v_user_email THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.space_members (space_id, user_id, role)
  VALUES (v_invite.space_id, v_user_id, 'member')
  ON CONFLICT (space_id, user_id) DO NOTHING;

  UPDATE public.invitations
  SET
    invited_user_id = v_user_id,
    status = 'accepted'
  WHERE id = p_invitation_id
  RETURNING * INTO v_invite;

  RETURN v_invite;
END;
$$;

-- 7) Upgrade savings RPC to be space-aware
CREATE OR REPLACE FUNCTION public.top_up_savings_goal(
  p_goal_id UUID,
  p_user_id UUID,
  p_amount DECIMAL(15,2),
  p_account_id UUID,
  p_note TEXT DEFAULT NULL,
  p_space_id UUID DEFAULT NULL
)
RETURNS public.savings_goals
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_goal public.savings_goals%ROWTYPE;
  v_account_balance DECIMAL(15,2);
  v_clean_note TEXT;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  SELECT *
  INTO v_goal
  FROM public.savings_goals
  WHERE id = p_goal_id
    AND ((p_space_id IS NULL AND user_id = p_user_id AND space_id IS NULL) OR (space_id = p_space_id))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'goal_not_found';
  END IF;

  SELECT public.get_account_balance(p_account_id)
  INTO v_account_balance;
  IF v_account_balance IS NULL OR v_account_balance < p_amount THEN
    RAISE EXCEPTION 'insufficient_account_balance';
  END IF;

  UPDATE public.savings_goals
  SET
    current_amount = current_amount + p_amount,
    is_completed = (current_amount + p_amount) >= target_amount,
    updated_at = NOW()
  WHERE id = p_goal_id
  RETURNING * INTO v_goal;

  v_clean_note := NULLIF(TRIM(p_note), '');
  INSERT INTO public.savings_deposits (goal_id, user_id, amount, note, account_id)
  VALUES (p_goal_id, p_user_id, p_amount, COALESCE(v_clean_note, 'Top up goal: ' || v_goal.name), p_account_id);

  INSERT INTO public.transactions (user_id, amount, type, category, note, account_id, date, created_at, space_id)
  VALUES (
    p_user_id,
    p_amount,
    'expense',
    'Savings Goal',
    COALESCE(v_clean_note, 'Top up goal: ' || v_goal.name),
    p_account_id,
    CURRENT_DATE,
    NOW(),
    p_space_id
  );

  RETURN v_goal;
END;
$$;

CREATE OR REPLACE FUNCTION public.withdraw_savings_goal(
  p_goal_id UUID,
  p_user_id UUID,
  p_amount DECIMAL(15,2),
  p_account_id UUID,
  p_note TEXT DEFAULT NULL,
  p_space_id UUID DEFAULT NULL
)
RETURNS public.savings_goals
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_goal public.savings_goals%ROWTYPE;
  v_clean_note TEXT;
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'invalid_amount';
  END IF;

  SELECT *
  INTO v_goal
  FROM public.savings_goals
  WHERE id = p_goal_id
    AND ((p_space_id IS NULL AND user_id = p_user_id AND space_id IS NULL) OR (space_id = p_space_id))
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'goal_not_found';
  END IF;
  IF v_goal.current_amount < p_amount THEN
    RAISE EXCEPTION 'insufficient_goal_balance';
  END IF;

  UPDATE public.savings_goals
  SET
    current_amount = current_amount - p_amount,
    is_completed = (current_amount - p_amount) >= target_amount,
    updated_at = NOW()
  WHERE id = p_goal_id
  RETURNING * INTO v_goal;

  v_clean_note := NULLIF(TRIM(p_note), '');
  INSERT INTO public.savings_deposits (goal_id, user_id, amount, note, account_id)
  VALUES (p_goal_id, p_user_id, -p_amount, COALESCE(v_clean_note, 'Withdraw goal: ' || v_goal.name), p_account_id);

  INSERT INTO public.transactions (user_id, amount, type, category, note, account_id, date, created_at, space_id)
  VALUES (
    p_user_id,
    p_amount,
    'income',
    'Savings Goal',
    COALESCE(v_clean_note, 'Withdraw goal: ' || v_goal.name),
    p_account_id,
    CURRENT_DATE,
    NOW(),
    p_space_id
  );

  RETURN v_goal;
END;
$$;
