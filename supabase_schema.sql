-- ==============================================================================
-- SUPABASE SCHEMA FOR APEX EXPENSE TRACKER & SPLITWISE
-- Run this script in your Supabase SQL Editor (Dashboard -> SQL Editor -> New Query)
-- ==============================================================================

-- 1. Split Groups Table
CREATE TABLE IF NOT EXISTS public.split_groups (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    created_by TEXT NOT NULL,
    invite_code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.split_groups ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.split_groups ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2. Split Members Table
CREATE TABLE IF NOT EXISTS public.split_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    user_id TEXT,
    name TEXT NOT NULL,
    phone TEXT,
    joined_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.split_members ADD COLUMN IF NOT EXISTS user_id TEXT;

-- 3. Split Expenses Table (Anyone can add on behalf of anyone)
CREATE TABLE IF NOT EXISTS public.split_expenses (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    total_amount NUMERIC(12, 2) NOT NULL,
    paid_by_member_id TEXT NOT NULL,
    split_type TEXT NOT NULL DEFAULT 'equal', -- 'equal', 'unequal', 'percentage'
    category TEXT,
    note TEXT,
    receipt_url TEXT,
    added_by_member_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE public.split_expenses ADD COLUMN IF NOT EXISTS receipt_url TEXT;
ALTER TABLE public.split_expenses ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE public.split_expenses ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE public.split_expenses ADD COLUMN IF NOT EXISTS added_by_member_id TEXT;
ALTER TABLE public.split_expenses ADD COLUMN IF NOT EXISTS split_type TEXT DEFAULT 'equal';

-- 4. Split Shares Table (Stores breakdown of shares per member)
CREATE TABLE IF NOT EXISTS public.split_shares (
    id TEXT PRIMARY KEY,
    expense_id TEXT NOT NULL REFERENCES public.split_expenses(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL,
    share_amount NUMERIC(12, 2) NOT NULL,
    is_settled BOOLEAN DEFAULT FALSE
);

-- 5. Settlements Table (Settle up debts between members)
CREATE TABLE IF NOT EXISTS public.settlements (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    from_member_id TEXT NOT NULL,
    to_member_id TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    settled_at TIMESTAMPTZ DEFAULT NOW(),
    note TEXT,
    from_settlement_group_id TEXT,
    to_settlement_group_id TEXT
);
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS from_settlement_group_id TEXT;
ALTER TABLE public.settlements ADD COLUMN IF NOT EXISTS to_settlement_group_id TEXT;

-- 6. Split Expense Member Groups (Module A: Participant Selection Shortcuts)
CREATE TABLE IF NOT EXISTS public.split_expense_groups (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Split Expense Member Group Members (Module A Mappings)
CREATE TABLE IF NOT EXISTS public.split_expense_group_members (
    id TEXT PRIMARY KEY,
    expense_group_id TEXT NOT NULL REFERENCES public.split_expense_groups(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL REFERENCES public.split_members(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_expense_group_member UNIQUE (expense_group_id, member_id)
);

-- 8. Split Settlement Groups (Module B: Combined Net Balance Settlement)
CREATE TABLE IF NOT EXISTS public.split_settlement_groups (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Split Settlement Group Members (Module B Mappings)
-- Note: A member can belong to only one active settlement group per split group.
CREATE TABLE IF NOT EXISTS public.split_settlement_group_members (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES public.split_groups(id) ON DELETE CASCADE,
    settlement_group_id TEXT NOT NULL REFERENCES public.split_settlement_groups(id) ON DELETE CASCADE,
    member_id TEXT NOT NULL REFERENCES public.split_members(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_settlement_group_member UNIQUE (settlement_group_id, member_id),
    CONSTRAINT uq_member_single_settlement_group UNIQUE (group_id, member_id)
);

-- 10. Personal Expenses Table (Optional Supabase Cloud Storage for personal expenses)
CREATE TABLE IF NOT EXISTS public.user_expenses (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id UUID DEFAULT auth.uid(),
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    comment TEXT,
    receipt_url TEXT,
    expense_date BIGINT NOT NULL, -- Epoch millis
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);
ALTER TABLE public.user_expenses ADD COLUMN IF NOT EXISTS receipt_url TEXT;
ALTER TABLE public.user_expenses ADD COLUMN IF NOT EXISTS comment TEXT;

-- Indexes for lightning fast queries
CREATE INDEX IF NOT EXISTS idx_split_members_group_id ON public.split_members(group_id);
CREATE INDEX IF NOT EXISTS idx_split_groups_invite_code ON public.split_groups(invite_code);
CREATE INDEX IF NOT EXISTS idx_split_expenses_group_id ON public.split_expenses(group_id);
CREATE INDEX IF NOT EXISTS idx_split_shares_expense_id ON public.split_shares(expense_id);
CREATE INDEX IF NOT EXISTS idx_settlements_group_id ON public.settlements(group_id);
CREATE INDEX IF NOT EXISTS idx_split_expense_groups_group_id ON public.split_expense_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_split_expense_group_members_eg ON public.split_expense_group_members(expense_group_id);
CREATE INDEX IF NOT EXISTS idx_split_expense_group_members_m ON public.split_expense_group_members(member_id);
CREATE INDEX IF NOT EXISTS idx_split_settlement_groups_group_id ON public.split_settlement_groups(group_id);
CREATE INDEX IF NOT EXISTS idx_split_settlement_group_members_sg ON public.split_settlement_group_members(settlement_group_id);
CREATE INDEX IF NOT EXISTS idx_split_settlement_group_members_m ON public.split_settlement_group_members(member_id);
CREATE INDEX IF NOT EXISTS idx_user_expenses_user_date ON public.user_expenses(user_id, expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_user_expenses_date ON public.user_expenses(expense_date DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.split_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_expense_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_expense_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_settlement_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.split_settlement_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_expenses ENABLE ROW LEVEL SECURITY;

-- Splitwise tables: allow anonymous / authenticated access for instant web and app sharing by group invite code
DROP POLICY IF EXISTS "Public read/write access for split_groups" ON public.split_groups;
CREATE POLICY "Public read/write access for split_groups" ON public.split_groups FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_members" ON public.split_members;
CREATE POLICY "Public read/write access for split_members" ON public.split_members FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_expenses" ON public.split_expenses;
CREATE POLICY "Public read/write access for split_expenses" ON public.split_expenses FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_shares" ON public.split_shares;
CREATE POLICY "Public read/write access for split_shares" ON public.split_shares FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for settlements" ON public.settlements;
CREATE POLICY "Public read/write access for settlements" ON public.settlements FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_expense_groups" ON public.split_expense_groups;
CREATE POLICY "Public read/write access for split_expense_groups" ON public.split_expense_groups FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_expense_group_members" ON public.split_expense_group_members;
CREATE POLICY "Public read/write access for split_expense_group_members" ON public.split_expense_group_members FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_settlement_groups" ON public.split_settlement_groups;
CREATE POLICY "Public read/write access for split_settlement_groups" ON public.split_settlement_groups FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public read/write access for split_settlement_group_members" ON public.split_settlement_group_members;
CREATE POLICY "Public read/write access for split_settlement_group_members" ON public.split_settlement_group_members FOR ALL USING (true) WITH CHECK (true);

-- Personal expenses: STRICT multi-tenant user isolation (users can NEVER see or modify another user's expenses)
DROP POLICY IF EXISTS "Public read/write access for user_expenses" ON public.user_expenses;
DROP POLICY IF EXISTS "Users can only access their own expenses" ON public.user_expenses;
CREATE POLICY "Users can only access their own expenses" ON public.user_expenses
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
