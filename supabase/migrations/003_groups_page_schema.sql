-- ============================================================================
-- SWISS COIN - GROUPS PAGE DATABASE SCHEMA ENHANCEMENTS
-- Version: 1.0.0
-- Description: Enhanced group features, member management, and group-specific functions
-- Features: Group balances, member settlements, group activity, invitations
-- ============================================================================

-- ============================================================================
-- CUSTOM TYPES (ENUMS) FOR GROUPS
-- ============================================================================

-- Member role in a group
CREATE TYPE group_member_role AS ENUM (
    'owner',           -- Created the group, full admin rights
    'admin',           -- Can manage members and settings
    'member'           -- Regular member
);

-- Group invitation status
CREATE TYPE invitation_status AS ENUM (
    'pending',         -- Invitation sent, not yet responded
    'accepted',        -- Invitation accepted
    'declined',        -- Invitation declined
    'expired',         -- Invitation expired
    'cancelled'        -- Invitation cancelled by sender
);

-- ============================================================================
-- TABLE: group_invitations
-- Description: Track invitations to join groups
-- ============================================================================
CREATE TABLE group_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Group being invited to
    group_id UUID NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,

    -- Who sent the invitation
    inviter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Who is being invited (can be profile or phone number for non-users)
    invitee_profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    invitee_phone_number VARCHAR(20),                         -- For inviting non-app users

    -- Invitation details
    status invitation_status NOT NULL DEFAULT 'pending',
    message TEXT,                                             -- Optional invitation message

    -- Response tracking
    responded_at TIMESTAMPTZ,

    -- Expiration (default 7 days)
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_invitee CHECK (
        invitee_profile_id IS NOT NULL OR invitee_phone_number IS NOT NULL
    ),
    CONSTRAINT inviter_not_invitee CHECK (
        inviter_id != invitee_profile_id
    )
);

-- ============================================================================
-- TABLE: group_settings
-- Description: Per-group settings and configuration
-- ============================================================================
CREATE TABLE group_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    group_id UUID NOT NULL UNIQUE REFERENCES user_groups(id) ON DELETE CASCADE,

    -- Expense settings
    default_split_method split_method NOT NULL DEFAULT 'equal',
    default_currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
    simplify_debts BOOLEAN NOT NULL DEFAULT true,             -- Auto-simplify debt chains

    -- Notification settings
    notify_on_expense BOOLEAN NOT NULL DEFAULT true,
    notify_on_settlement BOOLEAN NOT NULL DEFAULT true,
    notify_on_reminder BOOLEAN NOT NULL DEFAULT true,
    notify_on_message BOOLEAN NOT NULL DEFAULT true,

    -- Privacy settings
    allow_non_members_to_view BOOLEAN NOT NULL DEFAULT false,
    require_approval_for_expenses BOOLEAN NOT NULL DEFAULT false,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- TABLE: group_activity_log
-- Description: Detailed activity log for groups (for activity feed)
-- ============================================================================
CREATE TABLE group_activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    group_id UUID NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,

    -- What happened
    action VARCHAR(50) NOT NULL,                              -- expense_added, settlement_recorded, member_joined, etc.

    -- Who did it
    actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Related entities
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    settlement_id UUID REFERENCES settlements(id) ON DELETE SET NULL,
    reminder_id UUID REFERENCES reminders(id) ON DELETE SET NULL,
    affected_member_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

    -- Human-readable summary
    summary TEXT NOT NULL,                                    -- e.g., "John added 'Dinner' ($50.00)"

    -- Additional context
    details JSONB DEFAULT '{}'::jsonb,

    -- When
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- ALTER group_members TABLE
-- Add role and enhanced tracking
-- ============================================================================

-- Add role column if not exists (check first)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'group_members' AND column_name = 'role') THEN
        ALTER TABLE group_members ADD COLUMN role group_member_role NOT NULL DEFAULT 'member';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'group_members' AND column_name = 'invited_by') THEN
        ALTER TABLE group_members ADD COLUMN invited_by UUID REFERENCES profiles(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'group_members' AND column_name = 'nickname') THEN
        ALTER TABLE group_members ADD COLUMN nickname VARCHAR(50);  -- Optional nickname in this group
    END IF;
END $$;

-- ============================================================================
-- INDEXES FOR GROUPS
-- ============================================================================

-- Group invitations indexes
CREATE INDEX IF NOT EXISTS idx_invitations_group ON group_invitations(group_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_invitations_invitee_profile ON group_invitations(invitee_profile_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_invitations_invitee_phone ON group_invitations(invitee_phone_number) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_invitations_expires ON group_invitations(expires_at) WHERE status = 'pending';

-- Group activity log indexes
CREATE INDEX IF NOT EXISTS idx_group_activity_group ON group_activity_log(group_id);
CREATE INDEX IF NOT EXISTS idx_group_activity_actor ON group_activity_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_group_activity_recent ON group_activity_log(group_id, created_at DESC);

-- Enhanced group members indexes
CREATE INDEX IF NOT EXISTS idx_group_members_role ON group_members(group_id, role) WHERE left_at IS NULL;

-- ============================================================================
-- FUNCTIONS FOR GROUPS
-- ============================================================================

-- Function to calculate group balance for a user
CREATE OR REPLACE FUNCTION calculate_group_balance(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    total_balance DECIMAL(15, 2),
    you_owe DECIMAL(15, 2),
    you_are_owed DECIMAL(15, 2),
    member_count INTEGER,
    transaction_count INTEGER
) AS $$
DECLARE
    v_you_owe DECIMAL(15, 2) := 0;
    v_you_are_owed DECIMAL(15, 2) := 0;
    v_member_count INTEGER := 0;
    v_transaction_count INTEGER := 0;
BEGIN
    -- Get member count
    SELECT COUNT(*) INTO v_member_count
    FROM group_members
    WHERE group_id = p_group_id AND left_at IS NULL;

    -- Get transaction count
    SELECT COUNT(*) INTO v_transaction_count
    FROM transactions
    WHERE group_id = p_group_id AND deleted_at IS NULL;

    -- Calculate what user owes (from transactions where others paid)
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO v_you_owe
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE t.group_id = p_group_id
      AND ts.owed_by_profile_id = p_user_id
      AND t.payer_profile_id != p_user_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Calculate what user is owed (from transactions where user paid)
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO v_you_are_owed
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE t.group_id = p_group_id
      AND t.payer_profile_id = p_user_id
      AND ts.owed_by_profile_id != p_user_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Account for settlements within the group
    -- Settlements you received (reduces what others owe you)
    v_you_are_owed := v_you_are_owed - COALESCE((
        SELECT SUM(s.amount)
        FROM settlements s
        WHERE s.group_id = p_group_id
          AND s.to_profile_id = p_user_id
          AND s.status = 'completed'
          AND s.deleted_at IS NULL
    ), 0);

    -- Settlements you sent (reduces what you owe)
    v_you_owe := v_you_owe - COALESCE((
        SELECT SUM(s.amount)
        FROM settlements s
        WHERE s.group_id = p_group_id
          AND s.from_profile_id = p_user_id
          AND s.status = 'completed'
          AND s.deleted_at IS NULL
    ), 0);

    -- Ensure no negative values (can happen if overpaid)
    v_you_owe := GREATEST(v_you_owe, 0);
    v_you_are_owed := GREATEST(v_you_are_owed, 0);

    RETURN QUERY SELECT
        (v_you_are_owed - v_you_owe) as total_balance,
        v_you_owe as you_owe,
        v_you_are_owed as you_are_owed,
        v_member_count as member_count,
        v_transaction_count as transaction_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate balance between user and specific group member
CREATE OR REPLACE FUNCTION calculate_group_member_balance(
    p_group_id UUID,
    p_user_id UUID,
    p_member_id UUID
)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    v_balance DECIMAL(15, 2) := 0;
    v_user_paid_member_owes DECIMAL(15, 2) := 0;
    v_member_paid_user_owes DECIMAL(15, 2) := 0;
    v_settlements_member_to_user DECIMAL(15, 2) := 0;
    v_settlements_user_to_member DECIMAL(15, 2) := 0;
BEGIN
    -- User paid, member owes
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO v_user_paid_member_owes
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE t.group_id = p_group_id
      AND t.payer_profile_id = p_user_id
      AND ts.owed_by_profile_id = p_member_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Member paid, user owes
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO v_member_paid_user_owes
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE t.group_id = p_group_id
      AND t.payer_profile_id = p_member_id
      AND ts.owed_by_profile_id = p_user_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Settlements from member to user
    SELECT COALESCE(SUM(amount), 0)
    INTO v_settlements_member_to_user
    FROM settlements
    WHERE group_id = p_group_id
      AND from_profile_id = p_member_id
      AND to_profile_id = p_user_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    -- Settlements from user to member
    SELECT COALESCE(SUM(amount), 0)
    INTO v_settlements_user_to_member
    FROM settlements
    WHERE group_id = p_group_id
      AND from_profile_id = p_user_id
      AND to_profile_id = p_member_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    -- Calculate balance
    -- Positive = member owes user
    -- Negative = user owes member
    v_balance := (v_user_paid_member_owes - v_settlements_member_to_user) -
                 (v_member_paid_user_owes - v_settlements_user_to_member);

    RETURN v_balance;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get all member balances for a group
CREATE OR REPLACE FUNCTION get_group_member_balances(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    member_id UUID,
    member_name VARCHAR(100),
    avatar_url TEXT,
    color_hex VARCHAR(7),
    balance DECIMAL(15, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(gm.profile_id, gm.contact_id) as member_id,
        COALESCE(p.display_name, c.display_name) as member_name,
        COALESCE(p.avatar_url, c.avatar_url) as avatar_url,
        COALESCE(p.color_hex, c.color_hex, '#007AFF') as color_hex,
        calculate_group_member_balance(p_group_id, p_user_id, COALESCE(gm.profile_id, gm.contact_id)) as balance
    FROM group_members gm
    LEFT JOIN profiles p ON p.id = gm.profile_id
    LEFT JOIN contacts c ON c.id = gm.contact_id
    WHERE gm.group_id = p_group_id
      AND gm.left_at IS NULL
      AND COALESCE(gm.profile_id, gm.contact_id) != p_user_id
    ORDER BY member_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get members who owe user in a group
CREATE OR REPLACE FUNCTION get_group_members_who_owe(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    member_id UUID,
    member_name VARCHAR(100),
    avatar_url TEXT,
    color_hex VARCHAR(7),
    amount_owed DECIMAL(15, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        mb.member_id,
        mb.member_name,
        mb.avatar_url,
        mb.color_hex,
        mb.balance as amount_owed
    FROM get_group_member_balances(p_group_id, p_user_id) mb
    WHERE mb.balance > 0.01
    ORDER BY mb.balance DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get members user owes in a group
CREATE OR REPLACE FUNCTION get_group_members_user_owes(
    p_group_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    member_id UUID,
    member_name VARCHAR(100),
    avatar_url TEXT,
    color_hex VARCHAR(7),
    amount_owed DECIMAL(15, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        mb.member_id,
        mb.member_name,
        mb.avatar_url,
        mb.color_hex,
        ABS(mb.balance) as amount_owed
    FROM get_group_member_balances(p_group_id, p_user_id) mb
    WHERE mb.balance < -0.01
    ORDER BY ABS(mb.balance) DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get group conversation items (transactions, settlements, messages)
CREATE OR REPLACE FUNCTION get_group_conversation_items(
    p_group_id UUID,
    p_user_id UUID,
    p_limit INTEGER DEFAULT 50,
    p_before_timestamp TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    item_id UUID,
    item_type VARCHAR(20),
    content TEXT,
    amount DECIMAL(15, 2),
    actor_id UUID,
    actor_name VARCHAR(100),
    created_at TIMESTAMPTZ,
    metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    -- Transactions
    SELECT
        t.id as item_id,
        'transaction'::VARCHAR(20) as item_type,
        t.title as content,
        t.amount,
        t.payer_profile_id as actor_id,
        p.display_name as actor_name,
        t.created_at,
        jsonb_build_object(
            'split_method', t.split_method::text,
            'currency', t.currency,
            'user_amount', (
                SELECT CASE
                    WHEN t.payer_profile_id = p_user_id THEN
                        (SELECT COALESCE(SUM(ts.amount), 0) FROM transaction_splits ts
                         WHERE ts.transaction_id = t.id AND ts.owed_by_profile_id != p_user_id)
                    ELSE
                        -(SELECT COALESCE(ts.amount, 0) FROM transaction_splits ts
                          WHERE ts.transaction_id = t.id AND ts.owed_by_profile_id = p_user_id)
                END
            )
        ) as metadata
    FROM transactions t
    JOIN profiles p ON p.id = t.payer_profile_id
    WHERE t.group_id = p_group_id
      AND t.deleted_at IS NULL
      AND (p_before_timestamp IS NULL OR t.created_at < p_before_timestamp)

    UNION ALL

    -- Settlements
    SELECT
        s.id as item_id,
        'settlement'::VARCHAR(20) as item_type,
        CASE
            WHEN s.from_profile_id = p_user_id THEN 'You paid ' || to_p.display_name
            WHEN s.to_profile_id = p_user_id THEN from_p.display_name || ' paid you'
            ELSE from_p.display_name || ' paid ' || to_p.display_name
        END as content,
        s.amount,
        s.from_profile_id as actor_id,
        from_p.display_name as actor_name,
        s.created_at,
        jsonb_build_object(
            'from_profile_id', s.from_profile_id,
            'to_profile_id', s.to_profile_id,
            'note', s.note,
            'is_full_settlement', s.is_full_settlement
        ) as metadata
    FROM settlements s
    JOIN profiles from_p ON from_p.id = s.from_profile_id
    JOIN profiles to_p ON to_p.id = s.to_profile_id
    WHERE s.group_id = p_group_id
      AND s.deleted_at IS NULL
      AND (p_before_timestamp IS NULL OR s.created_at < p_before_timestamp)

    UNION ALL

    -- Chat messages
    SELECT
        m.id as item_id,
        'message'::VARCHAR(20) as item_type,
        m.content,
        NULL::DECIMAL(15, 2) as amount,
        m.sender_id as actor_id,
        p.display_name as actor_name,
        m.created_at,
        jsonb_build_object(
            'is_from_user', m.sender_id = p_user_id,
            'is_edited', m.is_edited,
            'status', m.status::text
        ) as metadata
    FROM chat_messages m
    JOIN profiles p ON p.id = m.sender_id
    WHERE m.group_id = p_group_id
      AND m.deleted_at IS NULL
      AND (p_before_timestamp IS NULL OR m.created_at < p_before_timestamp)

    ORDER BY created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to add member to group
CREATE OR REPLACE FUNCTION add_group_member(
    p_group_id UUID,
    p_adder_id UUID,
    p_member_profile_id UUID DEFAULT NULL,
    p_member_contact_id UUID DEFAULT NULL,
    p_role group_member_role DEFAULT 'member'
)
RETURNS UUID AS $$
DECLARE
    v_member_id UUID;
BEGIN
    -- Validate: must have either profile or contact
    IF p_member_profile_id IS NULL AND p_member_contact_id IS NULL THEN
        RAISE EXCEPTION 'Must provide either profile_id or contact_id';
    END IF;

    -- Check if already a member
    IF p_member_profile_id IS NOT NULL THEN
        SELECT id INTO v_member_id
        FROM group_members
        WHERE group_id = p_group_id AND profile_id = p_member_profile_id AND left_at IS NULL;
    ELSE
        SELECT id INTO v_member_id
        FROM group_members
        WHERE group_id = p_group_id AND contact_id = p_member_contact_id AND left_at IS NULL;
    END IF;

    IF v_member_id IS NOT NULL THEN
        RAISE EXCEPTION 'Already a member of this group';
    END IF;

    -- Add member
    INSERT INTO group_members (group_id, profile_id, contact_id, role, invited_by, joined_at)
    VALUES (p_group_id, p_member_profile_id, p_member_contact_id, p_role, p_adder_id, NOW())
    RETURNING id INTO v_member_id;

    -- Log activity
    INSERT INTO group_activity_log (group_id, action, actor_id, affected_member_id, summary, details)
    VALUES (
        p_group_id,
        'member_added',
        p_adder_id,
        COALESCE(p_member_profile_id, p_member_contact_id),
        'Member added to group',
        jsonb_build_object('role', p_role::text)
    );

    RETURN v_member_id;
END;
$$ LANGUAGE plpgsql;

-- Function to remove member from group
CREATE OR REPLACE FUNCTION remove_group_member(
    p_group_id UUID,
    p_remover_id UUID,
    p_member_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Mark member as left
    UPDATE group_members
    SET left_at = NOW(), updated_at = NOW()
    WHERE group_id = p_group_id
      AND (profile_id = p_member_id OR contact_id = p_member_id)
      AND left_at IS NULL;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Log activity
    INSERT INTO group_activity_log (group_id, action, actor_id, affected_member_id, summary)
    VALUES (
        p_group_id,
        'member_removed',
        p_remover_id,
        p_member_id,
        'Member removed from group'
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to create a group with settings
CREATE OR REPLACE FUNCTION create_group_with_settings(
    p_name VARCHAR(100),
    p_creator_id UUID,
    p_description TEXT DEFAULT NULL,
    p_color_hex VARCHAR(7) DEFAULT '#007AFF',
    p_default_currency VARCHAR(3) DEFAULT 'USD',
    p_default_split_method split_method DEFAULT 'equal'
)
RETURNS UUID AS $$
DECLARE
    v_group_id UUID;
BEGIN
    -- Create group
    INSERT INTO user_groups (name, description, color_hex, default_currency, default_split_method, created_by)
    VALUES (p_name, p_description, p_color_hex, p_default_currency, p_default_split_method, p_creator_id)
    RETURNING id INTO v_group_id;

    -- Add creator as owner
    INSERT INTO group_members (group_id, profile_id, role, is_admin, joined_at)
    VALUES (v_group_id, p_creator_id, 'owner', true, NOW());

    -- Create default settings
    INSERT INTO group_settings (group_id, default_split_method, default_currency)
    VALUES (v_group_id, p_default_split_method, p_default_currency);

    -- Log activity
    INSERT INTO group_activity_log (group_id, action, actor_id, summary)
    VALUES (v_group_id, 'group_created', p_creator_id, 'Group created');

    RETURN v_group_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS FOR GROUPS
-- ============================================================================

-- Trigger to log transaction additions to group activity
CREATE OR REPLACE FUNCTION log_group_transaction_activity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.group_id IS NOT NULL THEN
        INSERT INTO group_activity_log (group_id, action, actor_id, transaction_id, summary, details)
        VALUES (
            NEW.group_id,
            'expense_added',
            NEW.created_by,
            NEW.id,
            'Added expense: ' || COALESCE(NEW.title, 'Untitled') || ' (' || NEW.currency || NEW.amount::text || ')',
            jsonb_build_object(
                'amount', NEW.amount,
                'currency', NEW.currency,
                'split_method', NEW.split_method::text
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_group_transaction
    AFTER INSERT ON transactions
    FOR EACH ROW
    WHEN (NEW.group_id IS NOT NULL)
    EXECUTE FUNCTION log_group_transaction_activity();

-- Trigger to log settlement activity
CREATE OR REPLACE FUNCTION log_group_settlement_activity()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.group_id IS NOT NULL THEN
        INSERT INTO group_activity_log (group_id, action, actor_id, settlement_id, summary, details)
        VALUES (
            NEW.group_id,
            'settlement_recorded',
            NEW.created_by,
            NEW.id,
            'Settlement recorded: ' || NEW.currency || NEW.amount::text,
            jsonb_build_object(
                'amount', NEW.amount,
                'currency', NEW.currency,
                'from_profile_id', NEW.from_profile_id,
                'to_profile_id', NEW.to_profile_id,
                'is_full_settlement', NEW.is_full_settlement
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_group_settlement
    AFTER INSERT ON settlements
    FOR EACH ROW
    WHEN (NEW.group_id IS NOT NULL)
    EXECUTE FUNCTION log_group_settlement_activity();

-- Trigger to update updated_at on group_settings
CREATE TRIGGER update_group_settings_updated_at
    BEFORE UPDATE ON group_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at on group_invitations
CREATE TRIGGER update_group_invitations_updated_at
    BEFORE UPDATE ON group_invitations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY FOR GROUPS
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE group_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_activity_log ENABLE ROW LEVEL SECURITY;

-- Group invitations: Inviter and invitee can view
CREATE POLICY "Invitation participants can view"
    ON group_invitations FOR SELECT
    USING (
        inviter_id = auth.uid()
        OR invitee_profile_id = auth.uid()
    );

-- Group invitations: Group admins can create
CREATE POLICY "Group admins can invite"
    ON group_invitations FOR INSERT
    WITH CHECK (
        inviter_id = auth.uid()
        AND group_id IN (
            SELECT group_id FROM group_members
            WHERE profile_id = auth.uid()
              AND (is_admin = true OR role IN ('owner', 'admin'))
              AND left_at IS NULL
        )
    );

-- Group invitations: Invitee can update (accept/decline)
CREATE POLICY "Invitee can respond to invitation"
    ON group_invitations FOR UPDATE
    USING (invitee_profile_id = auth.uid());

-- Group settings: Members can view
CREATE POLICY "Group members can view settings"
    ON group_settings FOR SELECT
    USING (
        group_id IN (
            SELECT group_id FROM group_members
            WHERE profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Group settings: Admins can update
CREATE POLICY "Group admins can update settings"
    ON group_settings FOR UPDATE
    USING (
        group_id IN (
            SELECT group_id FROM group_members
            WHERE profile_id = auth.uid()
              AND (is_admin = true OR role IN ('owner', 'admin'))
              AND left_at IS NULL
        )
    );

-- Group activity log: Members can view
CREATE POLICY "Group members can view activity"
    ON group_activity_log FOR SELECT
    USING (
        group_id IN (
            SELECT group_id FROM group_members
            WHERE profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS FOR GROUPS
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE group_invitations;
ALTER PUBLICATION supabase_realtime ADD TABLE group_activity_log;

-- ============================================================================
-- VIEWS FOR GROUPS
-- ============================================================================

-- View: Groups with summary info for a user
CREATE OR REPLACE VIEW user_groups_summary AS
SELECT
    g.id,
    g.name,
    g.description,
    g.avatar_url,
    g.color_hex,
    g.created_by,
    g.created_at,
    gm.profile_id as user_id,
    gm.role,
    gm.joined_at,
    (SELECT COUNT(*) FROM group_members WHERE group_id = g.id AND left_at IS NULL) as member_count,
    (SELECT COUNT(*) FROM transactions WHERE group_id = g.id AND deleted_at IS NULL) as transaction_count,
    (SELECT MAX(created_at) FROM transactions WHERE group_id = g.id AND deleted_at IS NULL) as last_activity_at
FROM user_groups g
JOIN group_members gm ON gm.group_id = g.id
WHERE g.deleted_at IS NULL
  AND gm.left_at IS NULL;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
