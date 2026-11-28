BEGIN;

-- Snapshot linked authors once so later membership changes cannot transfer ownership.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'split_expenses'
          AND column_name = 'author_user_id'
    ) THEN
        ALTER TABLE public.split_expenses ADD COLUMN author_user_id text;
        UPDATE public.split_expenses e
        SET author_user_id = m.user_id
        FROM public.split_members m
        WHERE m.id = e.added_by_member_id
          AND m.group_id = e.group_id
          AND m.user_id IS NOT NULL;
    END IF;
END;
$$;

ALTER TABLE public.split_expenses
    ALTER COLUMN author_user_id SET DEFAULT (auth.uid()::text);

CREATE OR REPLACE FUNCTION public.is_split_expense_author(
    expense_group_id text,
    author_member_id text
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.split_members m
        WHERE m.id = author_member_id
          AND m.group_id = expense_group_id
          AND m.user_id = (SELECT auth.uid())::text
    );
$$;

REVOKE ALL ON FUNCTION public.is_split_expense_author(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_split_expense_author(text, text) TO authenticated;

DROP POLICY IF EXISTS "Split expenses insert policy" ON public.split_expenses;
DROP POLICY IF EXISTS "Split expenses update policy" ON public.split_expenses;
DROP POLICY IF EXISTS "Split expenses delete policy" ON public.split_expenses;

CREATE POLICY "Split expenses insert policy" ON public.split_expenses
    FOR INSERT TO authenticated
    WITH CHECK (
        author_user_id = (SELECT auth.uid())::text
        AND public.is_split_expense_author(group_id, added_by_member_id)
    );

CREATE POLICY "Split expenses update policy" ON public.split_expenses
    FOR UPDATE TO authenticated
    USING (author_user_id = (SELECT auth.uid())::text)
    WITH CHECK (
        author_user_id = (SELECT auth.uid())::text
        AND public.is_group_member(group_id)
    );

CREATE POLICY "Split expenses delete policy" ON public.split_expenses
    FOR DELETE TO authenticated
    USING (author_user_id = (SELECT auth.uid())::text);

DROP POLICY IF EXISTS "Split shares insert policy" ON public.split_shares;
DROP POLICY IF EXISTS "Split shares update policy" ON public.split_shares;
DROP POLICY IF EXISTS "Split shares delete policy" ON public.split_shares;

CREATE POLICY "Split shares insert policy" ON public.split_shares
    FOR INSERT TO authenticated
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.split_expenses e
        WHERE e.id = split_shares.expense_id
          AND e.author_user_id = (SELECT auth.uid())::text
    ));

CREATE POLICY "Split shares update policy" ON public.split_shares
    FOR UPDATE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.split_expenses e
        WHERE e.id = split_shares.expense_id
          AND e.author_user_id = (SELECT auth.uid())::text
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.split_expenses e
        WHERE e.id = split_shares.expense_id
          AND e.author_user_id = (SELECT auth.uid())::text
    ));

CREATE POLICY "Split shares delete policy" ON public.split_shares
    FOR DELETE TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.split_expenses e
        WHERE e.id = split_shares.expense_id
          AND e.author_user_id = (SELECT auth.uid())::text
    ));

COMMIT;
