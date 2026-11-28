BEGIN;

-- Keep legacy owner recovery, but require a linked account for owned groups.
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
    SELECT auth.uid() IS NOT NULL AND (
        EXISTS (SELECT 1 FROM public.split_members
                WHERE group_id = p_group_id AND user_id = auth.uid()::text)
        OR EXISTS (SELECT 1 FROM public.split_groups
                   WHERE id = p_group_id AND user_id = auth.uid()::text)
        OR EXISTS (
            SELECT 1 FROM public.split_groups AS g
            WHERE g.id = p_group_id AND g.user_id IS NULL
              AND lower(btrim(g.created_by)) = lower(btrim(coalesce(
                  auth.jwt()->'user_metadata'->>'full_name',
                  auth.jwt()->'user_metadata'->>'name',
                  split_part(auth.jwt()->>'email', '@', 1)
              )))
        )
    );
$$;

CREATE OR REPLACE FUNCTION public.claim_user_groups(p_group_ids TEXT[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id TEXT := auth.uid()::text;
    v_name TEXT := lower(btrim(coalesce(
        auth.jwt()->'user_metadata'->>'full_name',
        auth.jwt()->'user_metadata'->>'name',
        split_part(auth.jwt()->>'email', '@', 1)
    )));
BEGIN
    IF v_user_id IS NULL OR nullif(v_name, '') IS NULL THEN
        RETURN;
    END IF;

    -- Only bind the creator's row in a group recovered by this call.
    WITH recovered AS (
        UPDATE public.split_groups SET user_id = v_user_id
        WHERE id = ANY(p_group_ids) AND user_id IS NULL
            AND lower(btrim(created_by)) = v_name
        RETURNING id
    ), creator_members AS (
        SELECT DISTINCT ON (g.id) m.id
        FROM recovered AS g
        JOIN public.split_members AS m ON m.group_id = g.id
        WHERE m.user_id IS NULL AND lower(btrim(m.name)) = v_name
          AND NOT EXISTS (SELECT 1 FROM public.split_members AS linked
                          WHERE linked.group_id = g.id AND linked.user_id = v_user_id)
        ORDER BY g.id, m.joined_at, m.id
    )
    UPDATE public.split_members SET user_id = v_user_id
    WHERE id IN (SELECT id FROM creator_members);
END;
$$;

-- Join through the invite only. A display name does not establish ownership of a placeholder.
CREATE OR REPLACE FUNCTION public.join_split_group_by_invite(
    p_code TEXT, p_name TEXT, p_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id TEXT := auth.uid()::text;
    v_name TEXT := NULLIF(btrim(p_name), '');
    v_group public.split_groups%ROWTYPE;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Sign in to join a group';
    END IF;
    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Enter a member name';
    END IF;

    SELECT * INTO v_group
    FROM public.split_groups
    WHERE invite_code = upper(btrim(p_code))
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Invalid invite code';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.split_members
        WHERE group_id = v_group.id AND user_id = v_user_id
    ) THEN
        INSERT INTO public.split_members (id, group_id, user_id, name, phone)
        VALUES (gen_random_uuid()::text, v_group.id, v_user_id, v_name, p_phone);
    END IF;

    RETURN to_jsonb(v_group);
END;
$$;

-- Retain the older RPC signature for deployed callers, with the same safe join behavior.
CREATE OR REPLACE FUNCTION public.join_group_by_invite_code(
    p_code TEXT, p_name TEXT, p_phone TEXT DEFAULT NULL
)
RETURNS public.split_groups
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
    SELECT jsonb_populate_record(NULL::public.split_groups, public.join_split_group_by_invite(p_code, p_name, p_phone));
$$;

-- Attach a freshly joined account to the original member ID so all history stays in place.
CREATE OR REPLACE FUNCTION public.assign_split_placeholder(
    p_group_id TEXT, p_placeholder_id TEXT, p_joined_member_id TEXT
)
RETURNS public.split_members
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_owner TEXT := auth.uid()::text;
    v_guest public.split_members%ROWTYPE;
    v_placeholder public.split_members%ROWTYPE;
BEGIN
    IF v_owner IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Only the group owner can assign a member';
    END IF;

    PERFORM 1 FROM public.split_groups
    WHERE id = p_group_id AND user_id = v_owner
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Only the group owner can assign a member';
    END IF;

    SELECT * INTO v_placeholder FROM public.split_members
    WHERE id = p_placeholder_id AND group_id = p_group_id
    FOR UPDATE;
    IF NOT FOUND OR v_placeholder.user_id IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Placeholder is no longer available';
    END IF;

    SELECT * INTO v_guest FROM public.split_members
    WHERE id = p_joined_member_id AND group_id = p_group_id
    FOR UPDATE;
    IF NOT FOUND OR v_guest.user_id IS NULL OR v_guest.user_id = v_owner THEN
        RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Select a joined guest account';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.split_members
        WHERE group_id = p_group_id AND user_id = v_guest.user_id AND id <> v_guest.id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Guest has more than one membership';
    END IF;

    IF EXISTS (SELECT 1 FROM public.split_expenses
               WHERE paid_by_member_id = v_guest.id OR added_by_member_id = v_guest.id)
       OR EXISTS (SELECT 1 FROM public.split_shares WHERE member_id = v_guest.id)
       OR EXISTS (SELECT 1 FROM public.settlements
                  WHERE from_member_id = v_guest.id OR to_member_id = v_guest.id)
       OR EXISTS (SELECT 1 FROM public.split_expense_group_members WHERE member_id = v_guest.id)
       OR EXISTS (SELECT 1 FROM public.split_settlement_group_members WHERE member_id = v_guest.id)
       OR EXISTS (SELECT 1 FROM public.payment_reminders WHERE split_target_member_id = v_guest.id)
    THEN
        RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Guest already has split activity';
    END IF;

    DELETE FROM public.split_members WHERE id = v_guest.id;
    UPDATE public.split_members
    SET user_id = v_guest.user_id, phone = coalesce(v_placeholder.phone, v_guest.phone)
    WHERE id = v_placeholder.id
    RETURNING * INTO v_placeholder;
    RETURN v_placeholder;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_user_groups(TEXT[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_split_group_by_invite(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.join_group_by_invite_code(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.assign_split_placeholder(TEXT, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_user_groups(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_split_group_by_invite(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_group_by_invite_code(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_split_placeholder(TEXT, TEXT, TEXT) TO authenticated;

COMMIT;
