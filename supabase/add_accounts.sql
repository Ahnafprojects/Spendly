-- Multi-account wallet manager migration for Spendly

CREATE TABLE IF NOT EXISTS public.accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name            VARCHAR(50) NOT NULL,
  type            VARCHAR(20) NOT NULL CHECK (type IN ('cash','bank','ewallet','investment','other')),
  icon            VARCHAR(10) NOT NULL DEFAULT '💳',
  color           VARCHAR(7)  NOT NULL DEFAULT '#4F6EF7',
  initial_balance DECIMAL(15,2) NOT NULL DEFAULT 0,
  is_default      BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_created
  ON public.accounts (user_id, created_at DESC);

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own accounts" ON public.accounts;
CREATE POLICY "Users can manage own accounts"
  ON public.accounts FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Keep only one default account per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_one_default_per_user
  ON public.accounts (user_id)
  WHERE is_default = true;

-- Auto update updated_at on accounts
DROP TRIGGER IF EXISTS set_accounts_updated_at ON public.accounts;
CREATE TRIGGER set_accounts_updated_at
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- transactions extension for account + transfer support
ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transfer_direction VARCHAR(10) CHECK (transfer_direction IN ('in','out')),
  ADD COLUMN IF NOT EXISTS transfer_group_id UUID;

CREATE INDEX IF NOT EXISTS idx_transactions_user_account_date
  ON public.transactions (user_id, account_id, date DESC);

-- Extend type enum-like check: income, expense, transfer
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.transactions'::regclass
      AND conname = 'transactions_type_check'
  ) THEN
    ALTER TABLE public.transactions
      DROP CONSTRAINT transactions_type_check;
  END IF;

  ALTER TABLE public.transactions
    ADD CONSTRAINT transactions_type_check
    CHECK (type IN ('income', 'expense', 'transfer'));
END $$;

-- Validate transfer rows structure
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.transactions'::regclass
      AND conname = 'transactions_transfer_direction_check'
  ) THEN
    ALTER TABLE public.transactions
      ADD CONSTRAINT transactions_transfer_direction_check
      CHECK (
        (type <> 'transfer' AND transfer_direction IS NULL)
        OR
        (type = 'transfer' AND transfer_direction IN ('in', 'out'))
      );
  END IF;
END $$;

-- Account balance = initial_balance + income - expense +/- transfer direction
CREATE OR REPLACE FUNCTION public.get_account_balance(p_account_id UUID)
RETURNS DECIMAL(15,2) AS $$
  SELECT
    a.initial_balance +
    COALESCE(
      SUM(
        CASE
          WHEN t.type = 'income' THEN t.amount
          WHEN t.type = 'expense' THEN -t.amount
          WHEN t.type = 'transfer' AND t.transfer_direction = 'in' THEN t.amount
          WHEN t.type = 'transfer' AND t.transfer_direction = 'out' THEN -t.amount
          ELSE 0
        END
      ),
      0
    )
  FROM public.accounts a
  LEFT JOIN public.transactions t ON t.account_id = a.id
  WHERE a.id = p_account_id
  GROUP BY a.initial_balance;
$$ LANGUAGE SQL SECURITY DEFINER STABLE;
