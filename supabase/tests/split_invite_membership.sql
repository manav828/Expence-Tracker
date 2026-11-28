-- Run against a local PostgreSQL/Supabase instance after applying the schema and migration.
BEGIN;

INSERT INTO public.split_groups (id, user_id, name, created_by, invite_code)
VALUES
    ('qa-split-assignment', '00000000-0000-0000-0000-000000000001', 'QA Trip', 'Owner', 'QALINK01'),
    ('qa-unrelated-trip', '00000000-0000-0000-0000-000000000002', 'Other Trip', 'Guest', 'QALINK02');

INSERT INTO public.split_members (id, group_id, user_id, name) VALUES
    ('qa-owner', 'qa-split-assignment', '00000000-0000-0000-0000-000000000001', 'Owner'),
    ('qa-placeholder', 'qa-split-assignment', NULL, 'Dev'),
    ('qa-family-member', 'qa-split-assignment', NULL, 'Mira'),
    ('qa-other-placeholder', 'qa-unrelated-trip', NULL, 'Other');

INSERT INTO public.split_expenses (id, group_id, title, total_amount, paid_by_member_id, added_by_member_id)
VALUES ('qa-car', 'qa-split-assignment', 'Car rental', 4000, 'qa-placeholder', 'qa-owner');
INSERT INTO public.split_shares (id, expense_id, member_id, share_amount)
VALUES ('qa-car-share', 'qa-car', 'qa-placeholder', 1000);
INSERT INTO public.settlements (id, group_id, from_member_id, to_member_id, amount)
VALUES ('qa-settlement', 'qa-split-assignment', 'qa-placeholder', 'qa-owner', 500);
INSERT INTO public.split_expense_groups (id, group_id, name)
VALUES ('qa-car-pool', 'qa-split-assignment', 'Car pool');
INSERT INTO public.split_expense_group_members (id, expense_group_id, member_id)
VALUES ('qa-car-pool-member', 'qa-car-pool', 'qa-placeholder');
INSERT INTO public.split_settlement_groups (id, group_id, name)
VALUES ('qa-household', 'qa-split-assignment', 'Household');
INSERT INTO public.split_settlement_group_members (id, group_id, settlement_group_id, member_id)
VALUES
    ('qa-household-dev', 'qa-split-assignment', 'qa-household', 'qa-placeholder'),
    ('qa-household-mira', 'qa-split-assignment', 'qa-household', 'qa-family-member');

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', TRUE);
SELECT set_config('request.jwt.claims', '{"user_metadata":{"full_name":"Dev"}}', TRUE);

DO $$
DECLARE
    v_guest_id TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM public.split_expenses WHERE id = 'qa-car') THEN
        RAISE EXCEPTION 'Trip data was visible before joining';
    END IF;

    BEGIN
        PERFORM public.join_split_group_by_invite('BADCODE', 'Guest');
        RAISE EXCEPTION 'Invalid invite was accepted';
    EXCEPTION WHEN no_data_found THEN NULL;
    END;

    PERFORM public.join_split_group_by_invite(' qalink01 ', 'Guest');
    PERFORM public.join_group_by_invite_code('QALINK01', 'Dev');
    PERFORM public.claim_user_groups(ARRAY['qa-split-assignment']);
    SELECT id INTO STRICT v_guest_id FROM public.split_members
    WHERE group_id = 'qa-split-assignment' AND user_id = auth.uid()::text;

    IF v_guest_id = 'qa-placeholder' OR NOT EXISTS (
        SELECT 1 FROM public.split_members WHERE id = 'qa-placeholder' AND user_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Using the placeholder name changed its ownership';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.split_expenses WHERE id = 'qa-car') THEN
        RAISE EXCEPTION 'Existing expense did not become visible after joining';
    END IF;

    BEGIN
        PERFORM public.assign_split_placeholder('qa-split-assignment', 'qa-placeholder', v_guest_id);
        RAISE EXCEPTION 'A guest could assign their own placeholder';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
END;
$$;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000003', TRUE);
SELECT public.join_split_group_by_invite('QALINK01', 'Guest with a share');
RESET ROLE;

INSERT INTO public.split_shares (id, expense_id, member_id, share_amount)
SELECT 'qa-existing-guest-share', 'qa-car', id, 1000
FROM public.split_members WHERE group_id = 'qa-split-assignment'
    AND user_id = '00000000-0000-0000-0000-000000000003';

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', TRUE);

DO $$
DECLARE
    v_guest_id TEXT;
    v_active_guest_id TEXT;
BEGIN
    SELECT id INTO STRICT v_guest_id FROM public.split_members
    WHERE group_id = 'qa-split-assignment' AND user_id = '00000000-0000-0000-0000-000000000002';
    SELECT id INTO STRICT v_active_guest_id FROM public.split_members
    WHERE group_id = 'qa-split-assignment' AND user_id = '00000000-0000-0000-0000-000000000003';

    BEGIN
        PERFORM public.assign_split_placeholder('qa-split-assignment', 'qa-other-placeholder', v_guest_id);
        RAISE EXCEPTION 'Cross-group assignment was accepted';
    EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
    END;

    BEGIN
        PERFORM public.assign_split_placeholder('qa-split-assignment', 'qa-placeholder', v_active_guest_id);
        RAISE EXCEPTION 'An active guest was incorrectly removed';
    EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
    END;

    PERFORM public.assign_split_placeholder('qa-split-assignment', 'qa-placeholder', v_guest_id);
    IF EXISTS (SELECT 1 FROM public.split_members WHERE id = v_guest_id) THEN
        RAISE EXCEPTION 'The temporary guest row survived assignment';
    END IF;
END;
$$;

SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', TRUE);

DO $$
DECLARE
    v_member_id TEXT;
BEGIN
    PERFORM public.join_split_group_by_invite('QALINK01', 'Guest');
    SELECT id INTO STRICT v_member_id FROM public.split_members
    WHERE group_id = 'qa-split-assignment' AND user_id = auth.uid()::text;

    IF v_member_id <> 'qa-placeholder'
       OR NOT EXISTS (SELECT 1 FROM public.split_expenses WHERE id = 'qa-car' AND paid_by_member_id = v_member_id)
       OR NOT EXISTS (SELECT 1 FROM public.split_shares WHERE id = 'qa-car-share' AND member_id = v_member_id)
       OR NOT EXISTS (SELECT 1 FROM public.settlements WHERE id = 'qa-settlement' AND from_member_id = v_member_id)
       OR NOT EXISTS (SELECT 1 FROM public.split_expense_group_members WHERE id = 'qa-car-pool-member' AND member_id = v_member_id)
       OR NOT EXISTS (SELECT 1 FROM public.split_settlement_group_members WHERE id = 'qa-household-dev' AND member_id = v_member_id)
    THEN
        RAISE EXCEPTION 'The placeholder or its history was not preserved';
    END IF;
END;
$$;

ROLLBACK;
