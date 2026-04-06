-- Savings Goals migration for Spendly premium

CREATE TABLE IF NOT EXISTS public.savings_goals (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name            VARCHAR(50) NOT NULL,
  icon            VARCHAR(20) NOT NULL DEFAULT 'flag',
  color           VARCHAR(7)  NOT NULL DEFAULT '#4F6EF7',
  target_amount   DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
  current_amount  DECIMAL(15,2) NOT NULL DEFAULT 0 CHECK (current_amount >= 0),
  target_date     DATE NOT NULL,
  is_completed    BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.savings_deposits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id     UUID NOT NULL REFERENCES public.savings_goals(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount      DECIMAL(15,2) NOT NULL,
  note        TEXT,
  account_id  UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_savings_goals_user_target
  ON public.savings_goals (user_id, is_completed, target_date);

CREATE INDEX IF NOT EXISTS idx_savings_deposits_goal_created
  ON public.savings_deposits (goal_id, created_at DESC);

DROP TRIGGER IF EXISTS set_savings_goals_updated_at ON public.savings_goals;
CREATE TRIGGER set_savings_goals_updated_at
  BEFORE UPDATE ON public.savings_goals
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_deposits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own goals" ON public.savings_goals;
CREATE POLICY "Users manage own goals"
  ON public.savings_goals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own deposits" ON public.savings_deposits;
CREATE POLICY "Users manage own deposits"
  ON public.savings_deposits FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.top_up_savings_goal(
  p_goal_id UUID,
  p_user_id UUID,
  p_amount DECIMAL(15,2),
  p_account_id UUID,
  p_note TEXT DEFAULT NULL
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
  WHERE id = p_goal_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'goal_not_found';
  END IF;

  SELECT public.get_account_balance(p_account_id)
  INTO v_account_balance;
  IF v_account_balance IS NULL THEN
    RAISE EXCEPTION 'account_not_found';
  END IF;
  IF v_account_balance < p_amount THEN
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
  VALUES (
    p_goal_id,
    p_user_id,
    p_amount,
    COALESCE(v_clean_note, 'Top up goal: ' || v_goal.name),
    p_account_id
  );

  INSERT INTO public.transactions (
    user_id,
    amount,
    type,
    category,
    note,
    account_id,
    date,
    created_at
  )
  VALUES (
    p_user_id,
    p_amount,
    'expense',
    'Savings Goal',
    COALESCE(v_clean_note, 'Top up goal: ' || v_goal.name),
    p_account_id,
    CURRENT_DATE,
    NOW()
  );

  RETURN v_goal;
END;
$$;

CREATE OR REPLACE FUNCTION public.withdraw_savings_goal(
  p_goal_id UUID,
  p_user_id UUID,
  p_amount DECIMAL(15,2),
  p_account_id UUID,
  p_note TEXT DEFAULT NULL
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
  WHERE id = p_goal_id AND user_id = p_user_id
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
  VALUES (
    p_goal_id,
    p_user_id,
    -p_amount,
    COALESCE(v_clean_note, 'Withdraw goal: ' || v_goal.name),
    p_account_id
  );

  INSERT INTO public.transactions (
    user_id,
    amount,
    type,
    category,
    note,
    account_id,
    date,
    created_at
  )
  VALUES (
    p_user_id,
    p_amount,
    'income',
    'Savings Goal',
    COALESCE(v_clean_note, 'Withdraw goal: ' || v_goal.name),
    p_account_id,
    CURRENT_DATE,
    NOW()
  );

  RETURN v_goal;
END;
$$;
