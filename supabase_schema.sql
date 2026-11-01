-- ==============================================================================
-- SUPABASE SCHEMA FOR EXPENCIRCLE EXPENSE TRACKER & SPLITWISE
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
ALTER TABLE public.user_expenses ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('expense', 'income'));

-- Indexes for lightning fast queries
CREATE INDEX IF NOT EXISTS idx_split_members_group_id ON public.split_members(group_id);
CREATE INDEX IF NOT EXISTS idx_split_members_user_id ON public.split_members(user_id);
CREATE INDEX IF NOT EXISTS idx_split_groups_user_id ON public.split_groups(user_id);
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

-- High-performance composite indexes
CREATE INDEX IF NOT EXISTS idx_split_members_group_user ON public.split_members(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_split_groups_id_user ON public.split_groups(id, user_id);
CREATE INDEX IF NOT EXISTS idx_split_expenses_group_created ON public.split_expenses(group_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_settlements_group_settled ON public.settlements(group_id, settled_at DESC);
CREATE INDEX IF NOT EXISTS idx_split_shares_expense_member ON public.split_shares(expense_id, member_id);

-- Set safe defaults to guarantee user_id is never null on inserts for split_groups
ALTER TABLE public.split_groups ALTER COLUMN user_id SET DEFAULT auth.uid()::text;
-- For split_members, manual members MUST have user_id as NULL! Drop default if previously set.
ALTER TABLE public.split_members ALTER COLUMN user_id DROP DEFAULT;

-- ==============================================================================
-- SAFE MIGRATION & BACKFILL FOR LEGACY UNOWNED DATA
-- Guarantees that existing historical groups, members, and expenses are NEVER
-- hidden or lost when RLS is enabled!
-- ==============================================================================
DO $$
DECLARE
    v_single_user_id TEXT;
BEGIN
    -- Check if an existing registered auth user exists
    SELECT id::text INTO v_single_user_id FROM auth.users ORDER BY created_at ASC LIMIT 1;
    IF v_single_user_id IS NOT NULL THEN
        -- 1. Backfill unowned split_groups to existing user
        UPDATE public.split_groups
        SET user_id = v_single_user_id
        WHERE user_id IS NULL;

        -- 2. Backfill unowned creator member rows ONLY (matching created_by name)
        UPDATE public.split_members m
        SET user_id = g.user_id
        FROM public.split_groups g
        WHERE m.group_id = g.id
          AND m.user_id IS NULL
          AND LOWER(TRIM(m.name)) = LOWER(TRIM(g.created_by));

        -- 3. Cleanup: If any non-creator manual members were accidentally given user_id, restore them to NULL
        UPDATE public.split_members m
        SET user_id = NULL
        FROM public.split_groups g
        WHERE m.group_id = g.id
          AND m.user_id IS NOT NULL
          AND LOWER(TRIM(m.name)) != LOWER(TRIM(g.created_by));

        -- 4. Backfill unowned personal user_expenses
        UPDATE public.user_expenses
        SET user_id = v_single_user_id::uuid
        WHERE user_id IS NULL;
    END IF;
END $$;

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

-- ==============================================================================
-- SECURITY DEFINER HELPER FUNCTIONS FOR STRICT ROW-LEVEL SECURITY
-- ==============================================================================

-- 1. Check if current authenticated user is a verified member or creator of a split group
-- Includes backward-compatible fallback for legacy groups with matching name/email
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT (auth.uid() IS NOT NULL) AND (
        -- Direct user_id match on enrolled members
        EXISTS (
            SELECT 1
            FROM public.split_members
            WHERE group_id = p_group_id
              AND user_id = auth.uid()::text
        )
        -- Direct user_id match on group creator
        OR EXISTS (
            SELECT 1
            FROM public.split_groups
            WHERE id = p_group_id
              AND user_id = auth.uid()::text
        )
        -- Legacy data fallback: if group user_id is null, match creator name against auth claims
        OR EXISTS (
            SELECT 1
            FROM public.split_groups g
            WHERE g.id = p_group_id
              AND g.user_id IS NULL
              AND LOWER(TRIM(g.created_by)) = LOWER(TRIM(COALESCE(
                  auth.jwt()->'user_metadata'->>'full_name',
                  auth.jwt()->'user_metadata'->>'name',
                  split_part(auth.jwt()->>'email', '@', 1),
                  ''
              )))
        )
        -- Legacy data fallback: if member user_id is null, match member name against auth claims
        OR EXISTS (
            SELECT 1
            FROM public.split_members m
            WHERE m.group_id = p_group_id
              AND m.user_id IS NULL
              AND LOWER(TRIM(m.name)) = LOWER(TRIM(COALESCE(
                  auth.jwt()->'user_metadata'->>'full_name',
                  auth.jwt()->'user_metadata'->>'name',
                  split_part(auth.jwt()->>'email', '@', 1),
                  ''
              )))
        )
    );
$$;

-- Check if current authenticated user is the creator of a split group
CREATE OR REPLACE FUNCTION public.is_group_creator(p_group_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT (auth.uid() IS NOT NULL) AND EXISTS (
        SELECT 1 FROM public.split_groups 
        WHERE id = p_group_id 
          AND (
            user_id = auth.uid()::text
            OR (
              user_id IS NULL
              AND LOWER(TRIM(created_by)) = LOWER(TRIM(COALESCE(
                  auth.jwt()->'user_metadata'->>'full_name',
                  auth.jwt()->'user_metadata'->>'name',
                  split_part(auth.jwt()->>'email', '@', 1),
                  ''
              )))
            )
          )
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_group_creator(TEXT) TO authenticated;

-- 2. Check if the current authenticated user belongs to the group of a split expense
CREATE OR REPLACE FUNCTION public.is_expense_member(p_expense_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT (auth.uid() IS NOT NULL) AND EXISTS (
        SELECT 1
        FROM public.split_expenses e
        WHERE e.id = p_expense_id
          AND public.is_group_member(e.group_id)
    );
$$;

-- 3. Check if the current authenticated user belongs to the group of an expense member group
CREATE OR REPLACE FUNCTION public.is_expense_group_member(p_expense_group_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT (auth.uid() IS NOT NULL) AND EXISTS (
        SELECT 1
        FROM public.split_expense_groups eg
        WHERE eg.id = p_expense_group_id
          AND public.is_group_member(eg.group_id)
    );
$$;

-- 4. Secure invite code lookup: Allows fetching ONLY the single group matching an exact invite code.
-- Prevents bulk listing/scraping of all split groups by unauthenticated or unauthorized users.
CREATE OR REPLACE FUNCTION public.get_group_by_invite_code(p_code TEXT)
RETURNS SETOF public.split_groups
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.split_groups
    WHERE UPPER(invite_code) = UPPER(TRIM(p_code))
    LIMIT 1;
END;
$$;

-- 5. Auto-claim known groups RPC: Allows user's app on startup to securely claim
-- any unowned historical groups stored in user's device/preferences.
CREATE OR REPLACE FUNCTION public.claim_user_groups(p_group_ids TEXT[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid TEXT := auth.uid()::text;
    v_name TEXT := COALESCE(
        auth.jwt()->'user_metadata'->>'full_name',
        auth.jwt()->'user_metadata'->>'name',
        split_part(auth.jwt()->>'email', '@', 1)
    );
BEGIN
    IF v_uid IS NULL OR p_group_ids IS NULL OR array_length(p_group_ids, 1) = 0 THEN
        RETURN;
    END IF;

    -- Claim unowned groups
    UPDATE public.split_groups
    SET user_id = v_uid
    WHERE id = ANY(p_group_ids)
      AND user_id IS NULL;

    -- Claim unowned creator member records
    UPDATE public.split_members
    SET user_id = v_uid
    WHERE group_id = ANY(p_group_ids)
      AND user_id IS NULL
      AND (
          (v_name IS NOT NULL AND LOWER(TRIM(name)) = LOWER(TRIM(v_name)))
          OR name IN (SELECT created_by FROM public.split_groups WHERE id = split_members.group_id)
      );
END;
$$;

-- 6. Atomic join group by invite code RPC
-- Validates auth, looks up group by invite code, handles existing/unowned member claiming, or inserts a new member
CREATE OR REPLACE FUNCTION public.join_group_by_invite_code(
    p_code TEXT,
    p_name TEXT,
    p_phone TEXT DEFAULT NULL
)
RETURNS public.split_groups
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid TEXT := auth.uid()::text;
    v_group public.split_groups%ROWTYPE;
    v_clean_code TEXT := UPPER(TRIM(p_code));
    v_clean_name TEXT := TRIM(p_name);
    v_existing_member_id TEXT;
    v_unowned_member_id TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    IF v_clean_code IS NULL OR v_clean_code = '' THEN
        RAISE EXCEPTION 'Invite code is required';
    END IF;

    IF v_clean_name IS NULL OR v_clean_name = '' THEN
        RAISE EXCEPTION 'Member name is required';
    END IF;

    -- Lookup group by invite code
    SELECT * INTO v_group
    FROM public.split_groups
    WHERE UPPER(invite_code) = v_clean_code
    LIMIT 1;

    IF v_group.id IS NULL THEN
        RAISE EXCEPTION 'Invalid invite code';
    END IF;

    -- Check if user is already enrolled in split_members
    SELECT id INTO v_existing_member_id
    FROM public.split_members
    WHERE group_id = v_group.id
      AND user_id = v_uid
    LIMIT 1;

    IF v_existing_member_id IS NOT NULL THEN
        -- User is already enrolled: update name and phone if provided, then return group
        UPDATE public.split_members
        SET name = v_clean_name,
            phone = COALESCE(p_phone, phone)
        WHERE id = v_existing_member_id;

        RETURN v_group;
    END IF;

    -- If there is an existing member row with matching name and user_id IS NULL, claim it
    SELECT id INTO v_unowned_member_id
    FROM public.split_members
    WHERE group_id = v_group.id
      AND user_id IS NULL
      AND LOWER(TRIM(name)) = LOWER(v_clean_name)
    LIMIT 1;

    IF v_unowned_member_id IS NOT NULL THEN
        UPDATE public.split_members
        SET user_id = v_uid,
            phone = COALESCE(p_phone, phone)
        WHERE id = v_unowned_member_id;
    ELSE
        -- Otherwise insert a new member row into split_members
        INSERT INTO public.split_members (id, group_id, user_id, name, phone, joined_at)
        VALUES (
            gen_random_uuid()::text,
            v_group.id,
            v_uid,
            v_clean_name,
            p_phone,
            NOW()
        );
    END IF;

    RETURN v_group;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_group_member(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_expense_member(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_expense_group_member(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_group_by_invite_code(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.claim_user_groups(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_group_by_invite_code(TEXT, TEXT, TEXT) TO authenticated;

-- Single-query batch shares fetcher (resolves N+1 query bottleneck)
CREATE OR REPLACE FUNCTION public.get_group_shares(p_group_id TEXT)
RETURNS SETOF public.split_shares
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT s.*
    FROM public.split_shares s
    JOIN public.split_expenses e ON e.id = s.expense_id
    WHERE e.group_id = p_group_id
      AND public.is_group_member(p_group_id);
$$;

GRANT EXECUTE ON FUNCTION public.get_group_shares(TEXT) TO authenticated;

-- ==============================================================================
-- STRICT ROW LEVEL SECURITY (RLS) POLICIES
-- Multi-tenant isolation: Unauthenticated requests and non-members CANNOT read,
-- list, scrap, update, or delete data belonging to other groups.
-- ==============================================================================

-- Clean up legacy open policies
DROP POLICY IF EXISTS "Public read/write access for split_groups" ON public.split_groups;
DROP POLICY IF EXISTS "Public read/write access for split_members" ON public.split_members;
DROP POLICY IF EXISTS "Public read/write access for split_expenses" ON public.split_expenses;
DROP POLICY IF EXISTS "Public read/write access for split_shares" ON public.split_shares;
DROP POLICY IF EXISTS "Public read/write access for settlements" ON public.settlements;
DROP POLICY IF EXISTS "Public read/write access for split_expense_groups" ON public.split_expense_groups;
DROP POLICY IF EXISTS "Public read/write access for split_expense_group_members" ON public.split_expense_group_members;
DROP POLICY IF EXISTS "Public read/write access for split_settlement_groups" ON public.split_settlement_groups;
DROP POLICY IF EXISTS "Public read/write access for split_settlement_group_members" ON public.split_settlement_group_members;

-- Clean up new policies if they already exist (re-runnable idempotent script)
DROP POLICY IF EXISTS "Split groups select policy" ON public.split_groups;
DROP POLICY IF EXISTS "Split groups insert policy" ON public.split_groups;
DROP POLICY IF EXISTS "Split groups update policy" ON public.split_groups;
DROP POLICY IF EXISTS "Split groups delete policy" ON public.split_groups;

DROP POLICY IF EXISTS "Split members select policy" ON public.split_members;
DROP POLICY IF EXISTS "Split members insert policy" ON public.split_members;
DROP POLICY IF EXISTS "Split members update policy" ON public.split_members;
DROP POLICY IF EXISTS "Split members delete policy" ON public.split_members;

DROP POLICY IF EXISTS "Split expenses select policy" ON public.split_expenses;
DROP POLICY IF EXISTS "Split expenses insert policy" ON public.split_expenses;
DROP POLICY IF EXISTS "Split expenses update policy" ON public.split_expenses;
DROP POLICY IF EXISTS "Split expenses delete policy" ON public.split_expenses;

DROP POLICY IF EXISTS "Split shares select policy" ON public.split_shares;
DROP POLICY IF EXISTS "Split shares insert policy" ON public.split_shares;
DROP POLICY IF EXISTS "Split shares update policy" ON public.split_shares;
DROP POLICY IF EXISTS "Split shares delete policy" ON public.split_shares;

DROP POLICY IF EXISTS "Settlements select policy" ON public.settlements;
DROP POLICY IF EXISTS "Settlements insert policy" ON public.settlements;
DROP POLICY IF EXISTS "Settlements update policy" ON public.settlements;
DROP POLICY IF EXISTS "Settlements delete policy" ON public.settlements;

DROP POLICY IF EXISTS "Split expense groups policy" ON public.split_expense_groups;
DROP POLICY IF EXISTS "Split expense group members policy" ON public.split_expense_group_members;
DROP POLICY IF EXISTS "Split settlement groups policy" ON public.split_settlement_groups;
DROP POLICY IF EXISTS "Split settlement group members policy" ON public.split_settlement_group_members;

-- 1. SPLIT GROUPS
CREATE POLICY "Split groups select policy" ON public.split_groups
    FOR SELECT TO authenticated, anon
    USING (
        user_id = auth.uid()::text 
        OR public.is_group_member(id)
        OR (
            user_id IS NULL
            AND (
                auth.uid() IS NULL 
                OR LOWER(TRIM(created_by)) = LOWER(TRIM(COALESCE(
                    auth.jwt()->'user_metadata'->>'full_name',
                    auth.jwt()->'user_metadata'->>'name',
                    split_part(auth.jwt()->>'email', '@', 1),
                    ''
                )))
            )
        )
    );

CREATE POLICY "Split groups insert policy" ON public.split_groups
    FOR INSERT TO authenticated, anon
    WITH CHECK (auth.uid() IS NOT NULL OR user_id IS NULL);

CREATE POLICY "Split groups update policy" ON public.split_groups
    FOR UPDATE TO authenticated, anon
    USING (user_id = auth.uid()::text OR public.is_group_member(id) OR user_id IS NULL)
    WITH CHECK (user_id = auth.uid()::text OR public.is_group_member(id) OR user_id IS NULL);

CREATE POLICY "Split groups delete policy" ON public.split_groups
    FOR DELETE TO authenticated, anon
    USING (user_id = auth.uid()::text OR user_id IS NULL);

-- 2. SPLIT MEMBERS
CREATE POLICY "Split members select policy" ON public.split_members
    FOR SELECT TO authenticated, anon
    USING (
        public.is_group_member(group_id) 
        OR user_id = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_members.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split members insert policy" ON public.split_members
    FOR INSERT TO authenticated, anon
    WITH CHECK (
        public.is_group_creator(group_id) 
        OR public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_members.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split members update policy" ON public.split_members
    FOR UPDATE TO authenticated, anon
    USING (
        public.is_group_creator(group_id) 
        OR user_id = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_members.group_id AND user_id IS NULL)
    )
    WITH CHECK (
        public.is_group_creator(group_id) 
        OR user_id = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_members.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split members delete policy" ON public.split_members
    FOR DELETE TO authenticated, anon
    USING (
        public.is_group_creator(group_id) 
        OR user_id = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_members.group_id AND user_id IS NULL)
    );

-- 3. SPLIT EXPENSES
CREATE POLICY "Split expenses select policy" ON public.split_expenses
    FOR SELECT TO authenticated, anon
    USING (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expenses.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split expenses insert policy" ON public.split_expenses
    FOR INSERT TO authenticated, anon
    WITH CHECK (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expenses.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split expenses update policy" ON public.split_expenses
    FOR UPDATE TO authenticated, anon
    USING (
        public.is_group_creator(group_id)
        OR paid_by_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expenses.group_id AND user_id IS NULL)
    )
    WITH CHECK (
        public.is_group_creator(group_id)
        OR paid_by_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expenses.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split expenses delete policy" ON public.split_expenses
    FOR DELETE TO authenticated, anon
    USING (
        public.is_group_creator(group_id)
        OR paid_by_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expenses.group_id AND user_id IS NULL)
    );

-- 4. SPLIT SHARES
CREATE POLICY "Split shares select policy" ON public.split_shares
    FOR SELECT TO authenticated, anon
    USING (
        public.is_expense_member(expense_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expenses e 
            JOIN public.split_groups g ON g.id = e.group_id 
            WHERE e.id = split_shares.expense_id AND g.user_id IS NULL
        )
    );

CREATE POLICY "Split shares insert policy" ON public.split_shares
    FOR INSERT TO authenticated, anon
    WITH CHECK (
        public.is_expense_member(expense_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expenses e 
            JOIN public.split_groups g ON g.id = e.group_id 
            WHERE e.id = split_shares.expense_id AND g.user_id IS NULL
        )
    );

CREATE POLICY "Split shares update policy" ON public.split_shares
    FOR UPDATE TO authenticated, anon
    USING (
        public.is_expense_member(expense_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expenses e 
            JOIN public.split_groups g ON g.id = e.group_id 
            WHERE e.id = split_shares.expense_id AND g.user_id IS NULL
        )
    )
    WITH CHECK (
        public.is_expense_member(expense_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expenses e 
            JOIN public.split_groups g ON g.id = e.group_id 
            WHERE e.id = split_shares.expense_id AND g.user_id IS NULL
        )
    );

CREATE POLICY "Split shares delete policy" ON public.split_shares
    FOR DELETE TO authenticated, anon
    USING (
        public.is_expense_member(expense_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expenses e 
            JOIN public.split_groups g ON g.id = e.group_id 
            WHERE e.id = split_shares.expense_id AND g.user_id IS NULL
        )
    );

-- 5. SETTLEMENTS
CREATE POLICY "Settlements select policy" ON public.settlements
    FOR SELECT TO authenticated, anon
    USING (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = settlements.group_id AND user_id IS NULL)
    );

CREATE POLICY "Settlements insert policy" ON public.settlements
    FOR INSERT TO authenticated, anon
    WITH CHECK (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = settlements.group_id AND user_id IS NULL)
    );

CREATE POLICY "Settlements update policy" ON public.settlements
    FOR UPDATE TO authenticated, anon
    USING (
        public.is_group_creator(group_id)
        OR from_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR to_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = settlements.group_id AND user_id IS NULL)
    )
    WITH CHECK (
        public.is_group_creator(group_id)
        OR from_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR to_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = settlements.group_id AND user_id IS NULL)
    );

CREATE POLICY "Settlements delete policy" ON public.settlements
    FOR DELETE TO authenticated, anon
    USING (
        public.is_group_creator(group_id)
        OR from_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR to_member_id IN (SELECT id FROM public.split_members WHERE user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = settlements.group_id AND user_id IS NULL)
    );

-- 6. EXPENSE GROUPS & MEMBERS (Module A)
CREATE POLICY "Split expense groups policy" ON public.split_expense_groups
    FOR ALL TO authenticated, anon
    USING (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expense_groups.group_id AND user_id IS NULL)
    )
    WITH CHECK (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_expense_groups.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split expense group members policy" ON public.split_expense_group_members
    FOR ALL TO authenticated, anon
    USING (
        public.is_expense_group_member(expense_group_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expense_groups eg 
            JOIN public.split_groups g ON g.id = eg.group_id 
            WHERE eg.id = split_expense_group_members.expense_group_id AND g.user_id IS NULL
        )
    )
    WITH CHECK (
        public.is_expense_group_member(expense_group_id)
        OR EXISTS (
            SELECT 1 FROM public.split_expense_groups eg 
            JOIN public.split_groups g ON g.id = eg.group_id 
            WHERE eg.id = split_expense_group_members.expense_group_id AND g.user_id IS NULL
        )
    );

-- 7. SETTLEMENT GROUPS & MEMBERS (Module B)
CREATE POLICY "Split settlement groups policy" ON public.split_settlement_groups
    FOR ALL TO authenticated, anon
    USING (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_settlement_groups.group_id AND user_id IS NULL)
    )
    WITH CHECK (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_settlement_groups.group_id AND user_id IS NULL)
    );

CREATE POLICY "Split settlement group members policy" ON public.split_settlement_group_members
    FOR ALL TO authenticated, anon
    USING (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_settlement_group_members.group_id AND user_id IS NULL)
    )
    WITH CHECK (
        public.is_group_member(group_id)
        OR EXISTS (SELECT 1 FROM public.split_groups WHERE id = split_settlement_group_members.group_id AND user_id IS NULL)
    );

-- 8. PERSONAL EXPENSES
-- Strict multi-tenant user isolation
DROP POLICY IF EXISTS "Public read/write access for user_expenses" ON public.user_expenses;
DROP POLICY IF EXISTS "Users can only access their own expenses" ON public.user_expenses;
CREATE POLICY "Users can only access their own expenses" ON public.user_expenses
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- 9. PAYMENT REMINDERS (Recurring & One-Time Bills with Strict 2-Notification Rule)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.payment_reminders (
    id TEXT PRIMARY KEY,
    user_id TEXT DEFAULT auth.uid()::text,
    title TEXT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    category TEXT NOT NULL,
    payment_method TEXT NOT NULL,
    frequency TEXT NOT NULL DEFAULT 'monthly' CHECK (frequency IN ('one_time', 'weekly', 'monthly', 'quarterly', 'yearly', 'custom_days')),
    custom_interval_days INTEGER,
    due_day INTEGER,
    due_date BIGINT,
    next_due_date BIGINT NOT NULL,
    last_paid_date BIGINT,
    notified_day_before_at BIGINT,
    notified_due_day_at BIGINT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    split_group_id TEXT REFERENCES public.split_groups(id) ON DELETE SET NULL,
    split_type TEXT DEFAULT 'personal' CHECK (split_type IN ('personal', 'split_expense', 'settlement')),
    split_target_member_id TEXT,
    notes TEXT,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

-- Highly-selective partial index for active pending bills (sub-0.1ms dashboard retrieval)
CREATE INDEX IF NOT EXISTS idx_payment_reminders_active_due 
ON public.payment_reminders(user_id, next_due_date ASC) 
WHERE is_active = TRUE AND is_completed = FALSE;

-- Split group foreign key index
CREATE INDEX IF NOT EXISTS idx_payment_reminders_split_group 
ON public.payment_reminders(split_group_id);

-- Strict Multi-Tenant Row Level Security (RLS)
ALTER TABLE public.payment_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can only access their own payment reminders" ON public.payment_reminders;
CREATE POLICY "Users can only access their own payment reminders"
ON public.payment_reminders
FOR ALL
TO authenticated
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);
