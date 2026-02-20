-- ============================================================================
-- SWISS COIN - PHONE ACCOUNT LINKING & MERGE
-- Version: 8.0.0
-- Description: Relax phone NOT NULL on profiles, add merge function for
--              linking Apple Sign-In accounts with existing phone-based profiles
-- ============================================================================

-- ============================================================================
-- 1. RELAX phone_number NOT NULL (allow Apple Sign-In profiles without phone)
-- ============================================================================
ALTER TABLE profiles ALTER COLUMN phone_number DROP NOT NULL;

-- Drop the existing E.164 format constraint (blocks NULL inserts)
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS valid_phone_format;

-- Re-add as a permissive check (NULL allowed, format enforced when present)
ALTER TABLE profiles ADD CONSTRAINT valid_phone_format
    CHECK (phone_number IS NULL OR phone_number ~ '^\+[1-9]\d{1,14}$');

-- ============================================================================
-- 2. ENSURE phone_hash column + index on profiles
-- ============================================================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_hash VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_profiles_phone_hash_active
    ON profiles(phone_hash)
    WHERE phone_hash IS NOT NULL AND deleted_at IS NULL;

-- ============================================================================
-- 3. AUDIT TABLE: account_merge_log
-- ============================================================================
CREATE TABLE IF NOT EXISTS account_merge_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survivor_user_id UUID NOT NULL,
    absorbed_user_id UUID NOT NULL,
    phone_number VARCHAR(20),
    phone_hash VARCHAR(64),
    merge_reason VARCHAR(50) NOT NULL DEFAULT 'phone_linking',
    tables_affected JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 4. ATOMIC MERGE FUNCTION: merge_accounts_by_phone
--
-- Transfers ALL data from the absorbed account to the survivor account,
-- deactivates the absorbed profile, and sets the phone on the survivor.
-- Runs in a single transaction — auto-rollback on any failure.
-- ============================================================================
CREATE OR REPLACE FUNCTION merge_accounts_by_phone(
    p_survivor_id UUID,    -- The Apple Sign-In user (keeps this account)
    p_absorbed_id UUID,    -- The existing phone-linked account (gets absorbed)
    p_phone VARCHAR(20),
    p_phone_hash VARCHAR(64)
) RETURNS JSON AS $$
DECLARE
    v_counts JSON;
    v_txn INT; v_persons INT; v_groups INT; v_sett INT; v_subs INT; v_rem INT; v_msg INT;
BEGIN
    -- Guard: don't merge same user
    IF p_survivor_id = p_absorbed_id THEN
        RETURN json_build_object('error', 'Cannot merge user with self');
    END IF;

    -- 1. Transfer financial_transactions ownership
    UPDATE financial_transactions SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id AND deleted_at IS NULL;
    GET DIAGNOSTICS v_txn = ROW_COUNT;

    -- 2. Transfer persons (contacts)
    UPDATE persons SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id AND deleted_at IS NULL;
    GET DIAGNOSTICS v_persons = ROW_COUNT;

    -- 3. Transfer user_groups
    UPDATE user_groups SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id AND deleted_at IS NULL;
    GET DIAGNOSTICS v_groups = ROW_COUNT;

    -- 4. Transfer group_members
    UPDATE group_members SET profile_id = p_survivor_id, updated_at = NOW()
        WHERE profile_id = p_absorbed_id;

    -- 5. Transfer settlements
    UPDATE settlements SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id AND deleted_at IS NULL;
    GET DIAGNOSTICS v_sett = ROW_COUNT;

    -- 6. Transfer subscriptions
    UPDATE subscriptions SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id AND deleted_at IS NULL;
    GET DIAGNOSTICS v_subs = ROW_COUNT;

    -- 7. Transfer reminders
    UPDATE reminders SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id AND deleted_at IS NULL;
    GET DIAGNOSTICS v_rem = ROW_COUNT;

    -- 8. Transfer chat messages
    UPDATE chat_messages SET owner_id = p_survivor_id, updated_at = NOW()
        WHERE owner_id = p_absorbed_id;
    GET DIAGNOSTICS v_msg = ROW_COUNT;

    -- 9. Transfer conversations
    UPDATE conversations SET participant_a = p_survivor_id
        WHERE participant_a = p_absorbed_id;
    UPDATE conversations SET participant_b = p_survivor_id
        WHERE participant_b = p_absorbed_id;

    -- 10. Transfer direct_messages
    UPDATE direct_messages SET sender_id = p_survivor_id
        WHERE sender_id = p_absorbed_id;

    -- 11. Re-point phantom sharing participant records (source side)
    UPDATE transaction_participants SET source_owner_id = p_survivor_id, updated_at = NOW()
        WHERE source_owner_id = p_absorbed_id;
    UPDATE settlement_participants SET source_owner_id = p_survivor_id, updated_at = NOW()
        WHERE source_owner_id = p_absorbed_id;
    UPDATE subscription_participants SET source_owner_id = p_survivor_id, updated_at = NOW()
        WHERE source_owner_id = p_absorbed_id;

    -- 12. Re-point phantom sharing participant records (recipient side)
    UPDATE transaction_participants SET profile_id = p_survivor_id, updated_at = NOW()
        WHERE profile_id = p_absorbed_id;
    UPDATE settlement_participants SET profile_id = p_survivor_id, updated_at = NOW()
        WHERE profile_id = p_absorbed_id;
    UPDATE subscription_participants SET profile_id = p_survivor_id, updated_at = NOW()
        WHERE profile_id = p_absorbed_id;

    -- 13. Re-point shared_reminders
    UPDATE shared_reminders SET from_profile_id = p_survivor_id
        WHERE from_profile_id = p_absorbed_id;
    UPDATE shared_reminders SET to_profile_id = p_survivor_id
        WHERE to_profile_id = p_absorbed_id;

    -- 14. Re-point contacts that linked to absorbed profile (other users' contact books)
    UPDATE persons SET linked_profile_id = p_survivor_id, updated_at = NOW()
        WHERE linked_profile_id = p_absorbed_id;

    -- 15. Clear phone from absorbed profile (releases UNIQUE constraint)
    UPDATE profiles SET
        deleted_at = NOW(),
        phone_number = NULL,
        phone_hash = NULL,
        is_active = false,
        updated_at = NOW()
    WHERE id = p_absorbed_id;

    -- 16. Set phone on survivor profile
    UPDATE profiles SET
        phone_number = p_phone,
        phone_hash = p_phone_hash,
        phone_verified = true,
        updated_at = NOW()
    WHERE id = p_survivor_id;

    -- 17. Log the merge
    v_counts := json_build_object(
        'transactions', v_txn, 'persons', v_persons, 'groups', v_groups,
        'settlements', v_sett, 'subscriptions', v_subs, 'reminders', v_rem, 'messages', v_msg
    );

    INSERT INTO account_merge_log (survivor_user_id, absorbed_user_id, phone_number, phone_hash, tables_affected)
    VALUES (p_survivor_id, p_absorbed_id, p_phone, p_phone_hash, v_counts);

    RETURN json_build_object('success', true, 'merged', true, 'data_transferred', v_counts);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================
GRANT EXECUTE ON FUNCTION merge_accounts_by_phone TO authenticated;
