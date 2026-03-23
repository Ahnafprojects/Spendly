-- ============================================================
-- SPENDLY — Expense Tracker
-- Supabase PostgreSQL Schema
-- Jalankan di: Supabase Dashboard > SQL Editor > New Query
-- ============================================================


-- ============================================================
-- 0. EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================================
-- 1. TABLE: profiles
--    Auto-linked ke auth.users Supabase
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id              UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name       TEXT,
  avatar_url      TEXT,
  currency        VARCHAR(10) NOT NULL DEFAULT 'IDR',
  monthly_budget  DECIMAL(15,2) DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'Extended user profile data, linked 1:1 to auth.users';


-- ============================================================
-- 2. TABLE: transactions
-- ============================================================
CREATE TABLE IF NOT EXISTS public.transactions (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount      DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  type        VARCHAR(10)   NOT NULL CHECK (type IN ('income', 'expense')),
  category    VARCHAR(50)   NOT NULL,
  note        TEXT,
  date        DATE          NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.transactions IS 'Semua transaksi income dan expense per user';
COMMENT ON COLUMN public.transactions.type IS 'income atau expense';
COMMENT ON COLUMN public.transactions.category IS 'Makanan, Transport, Belanja, Hiburan, Kesehatan, Pendidikan, Tagihan, Lainnya';


-- ============================================================
-- 3. TABLE: budgets
--    Budget per kategori per bulan
-- ============================================================
CREATE TABLE IF NOT EXISTS public.budgets (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID          NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category      VARCHAR(50)   NOT NULL,
  limit_amount  DECIMAL(15,2) NOT NULL CHECK (limit_amount > 0),
  month         DATE          NOT NULL, -- Selalu isi first day of month, e.g. 2024-01-01
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT budgets_user_category_month_unique UNIQUE (user_id, category, month)
);

COMMENT ON TABLE public.budgets IS 'Budget limit per kategori per bulan per user';
COMMENT ON COLUMN public.budgets.month IS 'Selalu first day of month: 2024-01-01, 2024-02-01, dst';


-- ============================================================
-- 4. INDEXES — untuk query performa optimal
-- ============================================================

-- Transaksi: filter by user + urut by tanggal (paling sering dipakai)
CREATE INDEX IF NOT EXISTS idx_transactions_user_date
  ON public.transactions (user_id, date DESC);

-- Transaksi: filter by user + type + category (untuk analytics)
CREATE INDEX IF NOT EXISTS idx_transactions_user_type_category
  ON public.transactions (user_id, type, category);

-- Transaksi: filter by user + date range (untuk monthly report)
CREATE INDEX IF NOT EXISTS idx_transactions_user_date_range
  ON public.transactions (user_id, date);

-- Budgets: filter by user + month
CREATE INDEX IF NOT EXISTS idx_budgets_user_month
  ON public.budgets (user_id, month);


-- ============================================================
-- 5. UPDATED_AT TRIGGER FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Pasang trigger ke semua table
DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_transactions_updated_at ON public.transactions;
CREATE TRIGGER set_transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_budgets_updated_at ON public.budgets;
CREATE TRIGGER set_budgets_updated_at
  BEFORE UPDATE ON public.budgets
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- ============================================================
-- 6. AUTO-CREATE PROFILE TRIGGER
--    Otomatis buat profile saat user baru register
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- 7. ROW LEVEL SECURITY (RLS)
--    User HANYA bisa akses data miliknya sendiri
-- ============================================================

-- Enable RLS
ALTER TABLE public.profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets      ENABLE ROW LEVEL SECURITY;

-- ---- PROFILES ----
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ---- TRANSACTIONS ----
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions"
  ON public.transactions FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions"
  ON public.transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
CREATE POLICY "Users can update own transactions"
  ON public.transactions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;
CREATE POLICY "Users can delete own transactions"
  ON public.transactions FOR DELETE
  USING (auth.uid() = user_id);

-- ---- BUDGETS ----
DROP POLICY IF EXISTS "Users can view own budgets" ON public.budgets;
CREATE POLICY "Users can view own budgets"
  ON public.budgets FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own budgets" ON public.budgets;
CREATE POLICY "Users can insert own budgets"
  ON public.budgets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own budgets" ON public.budgets;
CREATE POLICY "Users can update own budgets"
  ON public.budgets FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own budgets" ON public.budgets;
CREATE POLICY "Users can delete own budgets"
  ON public.budgets FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================================
-- 8. HELPER FUNCTIONS
-- ============================================================

-- 8a. get_monthly_summary
--     Returns total income, expense, dan savings untuk bulan tertentu
CREATE OR REPLACE FUNCTION public.get_monthly_summary(
  p_user_id  UUID,
  p_month    DATE  -- masukkan first day of month, e.g. '2024-01-01'
)
RETURNS TABLE (
  total_income   DECIMAL(15,2),
  total_expense  DECIMAL(15,2),
  net_savings    DECIMAL(15,2)
) AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) AS total_income,
    COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense,
    COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE -amount END), 0) AS net_savings
  FROM public.transactions
  WHERE
    user_id = p_user_id
    AND date >= DATE_TRUNC('month', p_month)
    AND date <  DATE_TRUNC('month', p_month) + INTERVAL '1 month';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.get_monthly_summary IS
  'Hitung total income, expense, dan savings untuk bulan tertentu';


-- 8b. get_category_totals
--     Returns total expense per kategori untuk rentang tanggal tertentu
CREATE OR REPLACE FUNCTION public.get_category_totals(
  p_user_id    UUID,
  p_start_date DATE,
  p_end_date   DATE
)
RETURNS TABLE (
  category     VARCHAR(50),
  total_amount DECIMAL(15,2),
  percentage   NUMERIC(5,2),
  tx_count     BIGINT
) AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH category_sums AS (
    SELECT
      t.category,
      SUM(t.amount)   AS total_amount,
      COUNT(*)        AS tx_count
    FROM public.transactions t
    WHERE
      t.user_id = p_user_id
      AND t.type = 'expense'
      AND t.date BETWEEN p_start_date AND p_end_date
    GROUP BY t.category
  ),
  grand_total AS (
    SELECT SUM(total_amount) AS grand FROM category_sums
  )
  SELECT
    cs.category,
    cs.total_amount,
    ROUND((cs.total_amount / gt.grand * 100)::NUMERIC, 2) AS percentage,
    cs.tx_count
  FROM category_sums cs, grand_total gt
  ORDER BY cs.total_amount DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.get_category_totals IS
  'Breakdown expense per kategori dengan persentase, untuk pie chart analytics';


-- 8c. get_daily_totals
--     Returns total income & expense per hari untuk rentang tertentu (untuk bar chart)
CREATE OR REPLACE FUNCTION public.get_daily_totals(
  p_user_id    UUID,
  p_start_date DATE,
  p_end_date   DATE
)
RETURNS TABLE (
  day            DATE,
  total_income   DECIMAL(15,2),
  total_expense  DECIMAL(15,2)
) AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.date AS day,
    COALESCE(SUM(CASE WHEN t.type = 'income'  THEN t.amount ELSE 0 END), 0) AS total_income,
    COALESCE(SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END), 0) AS total_expense
  FROM public.transactions t
  WHERE
    t.user_id = p_user_id
    AND t.date BETWEEN p_start_date AND p_end_date
  GROUP BY t.date
  ORDER BY t.date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.get_daily_totals IS
  'Data harian untuk bar chart di analytics screen';


-- 8d. get_budget_usage
--     Returns budget limit vs actual spending per kategori bulan ini
CREATE OR REPLACE FUNCTION public.get_budget_usage(
  p_user_id UUID,
  p_month   DATE
)
RETURNS TABLE (
  category      VARCHAR(50),
  limit_amount  DECIMAL(15,2),
  spent_amount  DECIMAL(15,2),
  remaining     DECIMAL(15,2),
  usage_pct     NUMERIC(5,2),
  is_over       BOOLEAN
) AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    b.category,
    b.limit_amount,
    COALESCE(SUM(t.amount), 0)                                          AS spent_amount,
    b.limit_amount - COALESCE(SUM(t.amount), 0)                        AS remaining,
    ROUND((COALESCE(SUM(t.amount), 0) / b.limit_amount * 100)::NUMERIC, 2) AS usage_pct,
    COALESCE(SUM(t.amount), 0) > b.limit_amount                        AS is_over
  FROM public.budgets b
  LEFT JOIN public.transactions t
    ON  t.user_id  = b.user_id
    AND t.category = b.category
    AND t.type     = 'expense'
    AND t.date >= DATE_TRUNC('month', p_month)
    AND t.date <  DATE_TRUNC('month', p_month) + INTERVAL '1 month'
  WHERE
    b.user_id = p_user_id
    AND b.month = DATE_TRUNC('month', p_month)::DATE
  GROUP BY b.category, b.limit_amount
  ORDER BY usage_pct DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

COMMENT ON FUNCTION public.get_budget_usage IS
  'Budget vs actual spending per kategori — untuk progress bar di budget screen';


-- ============================================================
-- 9. SAMPLE DATA (opsional — hapus kalau tidak perlu)
--    Uncomment untuk test di development
-- ============================================================
/*
-- Contoh insert transaksi (ganti USER_ID dengan UUID user kamu)
INSERT INTO public.transactions (user_id, amount, type, category, note, date) VALUES
  ('YOUR-USER-UUID', 50000,   'expense', 'Makanan',    'Makan siang',      CURRENT_DATE),
  ('YOUR-USER-UUID', 25000,   'expense', 'Transport',  'Grab ke kantor',   CURRENT_DATE),
  ('YOUR-USER-UUID', 5000000, 'income',  'Lainnya',    'Gaji bulanan',     CURRENT_DATE - 1),
  ('YOUR-USER-UUID', 150000,  'expense', 'Belanja',    'Indomaret',        CURRENT_DATE - 2),
  ('YOUR-USER-UUID', 200000,  'expense', 'Kesehatan',  'Vitamin',          CURRENT_DATE - 3),
  ('YOUR-USER-UUID', 100000,  'expense', 'Hiburan',    'Netflix + Spotify',CURRENT_DATE - 4);

-- Contoh budget
INSERT INTO public.budgets (user_id, category, limit_amount, month) VALUES
  ('YOUR-USER-UUID', 'Makanan',   1500000, DATE_TRUNC('month', CURRENT_DATE)::DATE),
  ('YOUR-USER-UUID', 'Transport',  500000, DATE_TRUNC('month', CURRENT_DATE)::DATE),
  ('YOUR-USER-UUID', 'Hiburan',    300000, DATE_TRUNC('month', CURRENT_DATE)::DATE);
*/


-- ============================================================
-- 10. CARA PANGGIL FUNCTIONS DI FLUTTER (Dart)
-- ============================================================
/*
// get_monthly_summary
final result = await supabase.rpc('get_monthly_summary', params: {
  'p_user_id': supabase.auth.currentUser!.id,
  'p_month':   '2024-01-01',
});

// get_category_totals
final result = await supabase.rpc('get_category_totals', params: {
  'p_user_id':    supabase.auth.currentUser!.id,
  'p_start_date': '2024-01-01',
  'p_end_date':   '2024-01-31',
});

// get_budget_usage
final result = await supabase.rpc('get_budget_usage', params: {
  'p_user_id': supabase.auth.currentUser!.id,
  'p_month':   '2024-01-01',
});
*/

-- ============================================================
-- DONE! Urutan eksekusi sudah benar.
-- Verifikasi di: Table Editor > profiles, transactions, budgets
-- ============================================================
