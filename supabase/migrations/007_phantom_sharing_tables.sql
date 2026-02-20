-- ============================================================================
-- SWISS COIN - PHANTOM SHARING TABLES
-- Version: 7.0.0
-- Description: Participant tables for cross-user phantom sharing via phone hash
-- ============================================================================

-- ============================================================================
-- ALTER TABLE: persons - Add phone_hash column
-- ============================================================================
ALTER TABLE persons ADD COLUMN IF NOT EXISTS phone_hash VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_persons_phone_hash
    ON persons(phone_hash)
    WHERE phone_hash IS NOT NULL;

-- ============================================================================
-- TABLE: transaction_participants
-- Description: Phantom sharing records for transactions
-- ============================================================================
CREATE TABLE IF NOT EXISTS transaction_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to transaction
    transaction_id UUID NOT NULL REFERENCES financial_transactions(id) ON DELETE CASCADE,

    -- Recipient (NULL until claimed)
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    phone_hash VARCHAR(64),

    -- Status and role
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    role VARCHAR(20) NOT NULL DEFAULT 'participant',

    -- Creator of the share
    source_owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Timestamps
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate participant records
    CONSTRAINT unique_txn_phone UNIQUE NULLS NOT DISTINCT (transaction_id, phone_hash)
);

-- ============================================================================
-- TABLE: settlement_participants
-- Description: Phantom sharing records for settlements
-- ============================================================================
CREATE TABLE IF NOT EXISTS settlement_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to settlement
    settlement_id UUID NOT NULL REFERENCES settlements(id) ON DELETE CASCADE,

    -- Recipient (NULL until claimed)
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    phone_hash VARCHAR(64),

    -- Status and role
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    role VARCHAR(20) NOT NULL DEFAULT 'participant',

    -- Creator of the share
    source_owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Timestamps
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate participant records
    CONSTRAINT unique_sett_phone UNIQUE NULLS NOT DISTINCT (settlement_id, phone_hash)
);

-- ============================================================================
-- TABLE: subscription_participants
-- Description: Phantom sharing records for subscriptions
-- ============================================================================
CREATE TABLE IF NOT EXISTS subscription_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to subscription
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    -- Recipient (NULL until claimed)
    profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    phone_hash VARCHAR(64),

    -- Status and role
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    role VARCHAR(20) NOT NULL DEFAULT 'participant',

    -- Creator of the share
    source_owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Timestamps
    responded_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Prevent duplicate participant records
    CONSTRAINT unique_sub_phone UNIQUE NULLS NOT DISTINCT (subscription_id, phone_hash)
);

-- ============================================================================
-- TABLE: shared_reminders
-- Description: Cross-user reminder sharing records
-- ============================================================================
CREATE TABLE IF NOT EXISTS shared_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Sender
    from_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Recipient (NULL until claimed)
    to_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    phone_hash VARCHAR(64),

    -- Reminder details
    amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
    currency VARCHAR(3),
    message TEXT,

    -- Status
    is_read BOOLEAN NOT NULL DEFAULT false,

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Transaction participants
CREATE INDEX IF NOT EXISTS idx_txn_participants_phone_unclaimed
    ON transaction_participants(phone_hash)
    WHERE profile_id IS NULL AND phone_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_txn_participants_profile
    ON transaction_participants(profile_id)
    WHERE profile_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_txn_participants_source
    ON transaction_participants(source_owner_id);

-- Settlement participants
CREATE INDEX IF NOT EXISTS idx_sett_participants_phone_unclaimed
    ON settlement_participants(phone_hash)
    WHERE profile_id IS NULL AND phone_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sett_participants_profile
    ON settlement_participants(profile_id)
    WHERE profile_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sett_participants_source
    ON settlement_participants(source_owner_id);

-- Subscription participants
CREATE INDEX IF NOT EXISTS idx_sub_participants_phone_unclaimed
    ON subscription_participants(phone_hash)
    WHERE profile_id IS NULL AND phone_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sub_participants_profile
    ON subscription_participants(profile_id)
    WHERE profile_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_sub_participants_source
    ON subscription_participants(source_owner_id);

-- Shared reminders
CREATE INDEX IF NOT EXISTS idx_shared_reminders_phone_unclaimed
    ON shared_reminders(phone_hash)
    WHERE to_profile_id IS NULL AND phone_hash IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_shared_reminders_to_profile
    ON shared_reminders(to_profile_id)
    WHERE to_profile_id IS NOT NULL;

-- ============================================================================
-- UPDATED_AT TRIGGERS
-- ============================================================================

CREATE TRIGGER update_transaction_participants_updated_at
    BEFORE UPDATE ON transaction_participants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settlement_participants_updated_at
    BEFORE UPDATE ON settlement_participants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_participants_updated_at
    BEFORE UPDATE ON subscription_participants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shared_reminders_updated_at
    BEFORE UPDATE ON shared_reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE transaction_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlement_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_reminders ENABLE ROW LEVEL SECURITY;

-- Transaction participants: viewable by recipient or source owner
CREATE POLICY "Users can view own transaction participations"
    ON transaction_participants FOR SELECT
    USING (profile_id = auth.uid() OR source_owner_id = auth.uid());

CREATE POLICY "Users can create transaction participations"
    ON transaction_participants FOR INSERT
    WITH CHECK (source_owner_id = auth.uid());

CREATE POLICY "Users can update own transaction participations"
    ON transaction_participants FOR UPDATE
    USING (profile_id = auth.uid() OR source_owner_id = auth.uid());

-- Settlement participants
CREATE POLICY "Users can view own settlement participations"
    ON settlement_participants FOR SELECT
    USING (profile_id = auth.uid() OR source_owner_id = auth.uid());

CREATE POLICY "Users can create settlement participations"
    ON settlement_participants FOR INSERT
    WITH CHECK (source_owner_id = auth.uid());

CREATE POLICY "Users can update own settlement participations"
    ON settlement_participants FOR UPDATE
    USING (profile_id = auth.uid() OR source_owner_id = auth.uid());

-- Subscription participants
CREATE POLICY "Users can view own subscription participations"
    ON subscription_participants FOR SELECT
    USING (profile_id = auth.uid() OR source_owner_id = auth.uid());

CREATE POLICY "Users can create subscription participations"
    ON subscription_participants FOR INSERT
    WITH CHECK (source_owner_id = auth.uid());

CREATE POLICY "Users can update own subscription participations"
    ON subscription_participants FOR UPDATE
    USING (profile_id = auth.uid() OR source_owner_id = auth.uid());

-- Shared reminders
CREATE POLICY "Users can view own shared reminders"
    ON shared_reminders FOR SELECT
    USING (to_profile_id = auth.uid() OR from_profile_id = auth.uid());

CREATE POLICY "Users can create shared reminders"
    ON shared_reminders FOR INSERT
    WITH CHECK (from_profile_id = auth.uid());

CREATE POLICY "Users can update own shared reminders"
    ON shared_reminders FOR UPDATE
    USING (to_profile_id = auth.uid() OR from_profile_id = auth.uid());

-- ============================================================================
-- REALTIME
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE transaction_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE settlement_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE shared_reminders;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

GRANT ALL ON TABLE transaction_participants TO authenticated;
GRANT ALL ON TABLE settlement_participants TO authenticated;
GRANT ALL ON TABLE subscription_participants TO authenticated;
GRANT ALL ON TABLE shared_reminders TO authenticated;
