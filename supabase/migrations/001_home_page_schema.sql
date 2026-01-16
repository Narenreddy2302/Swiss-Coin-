-- ============================================================================
-- SWISS COIN - HOME PAGE DATABASE SCHEMA
-- Version: 1.0.0
-- Description: Core tables for user profiles, contacts, transactions, and settlements
-- Features: Multi-currency, Real-time sync, Soft delete, Phone-based auth
-- ============================================================================

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- For UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- For encryption functions

-- ============================================================================
-- CUSTOM TYPES (ENUMS)
-- ============================================================================

-- Split method types for transactions
CREATE TYPE split_method AS ENUM (
    'equal',           -- Split equally among all participants
    'exact',           -- Exact amounts specified for each person
    'percentage',      -- Percentage-based split
    'shares',          -- Share-based split (e.g., 2 shares vs 1 share)
    'adjustment'       -- Manual adjustment split
);

-- Transaction status
CREATE TYPE transaction_status AS ENUM (
    'pending',         -- Transaction created but not confirmed
    'confirmed',       -- Transaction confirmed by all parties
    'settled',         -- Fully settled
    'cancelled'        -- Transaction was cancelled
);

-- Settlement status
CREATE TYPE settlement_status AS ENUM (
    'pending',         -- Settlement initiated
    'completed',       -- Settlement confirmed
    'rejected',        -- Settlement was rejected
    'cancelled'        -- Settlement was cancelled
);

-- ============================================================================
-- TABLE: currencies
-- Description: Supported currencies with exchange rates
-- ============================================================================
CREATE TABLE currencies (
    code VARCHAR(3) PRIMARY KEY,                              -- ISO 4217 code (USD, EUR, GBP, etc.)
    name VARCHAR(100) NOT NULL,                               -- Full name (US Dollar, Euro, etc.)
    symbol VARCHAR(10) NOT NULL,                              -- Display symbol ($, €, £, etc.)
    decimal_places SMALLINT NOT NULL DEFAULT 2,               -- Number of decimal places
    exchange_rate_to_usd DECIMAL(20, 10) NOT NULL DEFAULT 1,  -- Rate relative to USD
    is_active BOOLEAN NOT NULL DEFAULT true,                  -- Whether currency is available
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default currencies
INSERT INTO currencies (code, name, symbol, decimal_places, exchange_rate_to_usd) VALUES
    ('USD', 'US Dollar', '$', 2, 1.0),
    ('EUR', 'Euro', '€', 2, 1.08),
    ('GBP', 'British Pound', '£', 2, 1.27),
    ('INR', 'Indian Rupee', '₹', 2, 0.012),
    ('CAD', 'Canadian Dollar', 'CA$', 2, 0.74),
    ('AUD', 'Australian Dollar', 'A$', 2, 0.65),
    ('JPY', 'Japanese Yen', '¥', 0, 0.0067),
    ('CHF', 'Swiss Franc', 'CHF', 2, 1.13),
    ('CNY', 'Chinese Yuan', '¥', 2, 0.14),
    ('MXN', 'Mexican Peso', 'MX$', 2, 0.058);

-- ============================================================================
-- TABLE: profiles
-- Description: User accounts - linked to phone numbers
-- ============================================================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Identity
    phone_number VARCHAR(20) NOT NULL UNIQUE,                 -- E.164 format (+1234567890)
    phone_verified BOOLEAN NOT NULL DEFAULT false,            -- Whether phone is verified

    -- Profile info
    display_name VARCHAR(100),                                -- User's display name
    full_name VARCHAR(200),                                   -- Full legal name (optional)
    avatar_url TEXT,                                          -- Profile picture URL (Supabase Storage)
    color_hex VARCHAR(7) DEFAULT '#007AFF',                   -- Profile color for UI

    -- Preferences
    default_currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
    locale VARCHAR(10) DEFAULT 'en-US',                       -- Locale for formatting
    timezone VARCHAR(50) DEFAULT 'UTC',                       -- User's timezone

    -- Notification preferences
    push_notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    email_notifications_enabled BOOLEAN NOT NULL DEFAULT false,
    reminder_notifications_enabled BOOLEAN NOT NULL DEFAULT true,

    -- App settings
    biometric_auth_enabled BOOLEAN NOT NULL DEFAULT false,

    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,                  -- Account active status
    last_seen_at TIMESTAMPTZ,                                 -- Last activity timestamp

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,                                   -- Soft delete timestamp

    -- Constraints
    CONSTRAINT valid_phone_format CHECK (phone_number ~ '^\+[1-9]\d{1,14}$'),
    CONSTRAINT valid_color_hex CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- ============================================================================
-- TABLE: contacts
-- Description: People the user can split expenses with (may or may not be app users)
-- ============================================================================
CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Owner of this contact
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Contact identity
    phone_number VARCHAR(20) NOT NULL,                        -- Contact's phone number
    display_name VARCHAR(100) NOT NULL,                       -- Name shown in app

    -- Link to profile (if contact is an app user)
    linked_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

    -- Visual customization
    avatar_url TEXT,                                          -- Contact's photo URL
    color_hex VARCHAR(7) DEFAULT '#34C759',                   -- Color for UI display

    -- Metadata
    notes TEXT,                                               -- Personal notes about contact
    is_favorite BOOLEAN NOT NULL DEFAULT false,               -- Starred/favorite contact

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,                                   -- Soft delete

    -- Constraints
    CONSTRAINT valid_contact_phone CHECK (phone_number ~ '^\+[1-9]\d{1,14}$'),
    CONSTRAINT valid_contact_color CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$'),
    CONSTRAINT unique_contact_per_owner UNIQUE (owner_id, phone_number)
);

-- ============================================================================
-- TABLE: user_groups
-- Description: Groups for splitting expenses among multiple people
-- ============================================================================
CREATE TABLE user_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Group info
    name VARCHAR(100) NOT NULL,                               -- Group name
    description TEXT,                                         -- Group description

    -- Visual
    avatar_url TEXT,                                          -- Group photo URL
    color_hex VARCHAR(7) DEFAULT '#5856D6',                   -- Group color
    icon_name VARCHAR(50),                                    -- SF Symbol icon name

    -- Settings
    default_currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
    default_split_method split_method NOT NULL DEFAULT 'equal',

    -- Creator
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT valid_group_color CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- ============================================================================
-- TABLE: group_members
-- Description: Members of a group (junction table)
-- ============================================================================
CREATE TABLE group_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    group_id UUID NOT NULL REFERENCES user_groups(id) ON DELETE CASCADE,

    -- Member can be either a profile (app user) or a contact (non-app user)
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,

    -- Member role
    is_admin BOOLEAN NOT NULL DEFAULT false,                  -- Can manage group

    -- Member status
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,                                      -- When member left (soft remove)

    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints: Must have either profile_id or contact_id, not both
    CONSTRAINT member_identity CHECK (
        (profile_id IS NOT NULL AND contact_id IS NULL) OR
        (profile_id IS NULL AND contact_id IS NOT NULL)
    ),
    -- Unique member per group
    CONSTRAINT unique_profile_per_group UNIQUE (group_id, profile_id),
    CONSTRAINT unique_contact_per_group UNIQUE (group_id, contact_id)
);

-- ============================================================================
-- TABLE: transactions
-- Description: Financial transactions (expenses, bills, etc.)
-- ============================================================================
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Transaction details
    title VARCHAR(200) NOT NULL,                              -- Transaction description
    description TEXT,                                         -- Additional notes

    -- Amount
    amount DECIMAL(15, 2) NOT NULL,                           -- Total transaction amount
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),

    -- Original amount (if converted from another currency)
    original_amount DECIMAL(15, 2),
    original_currency VARCHAR(3) REFERENCES currencies(code),
    exchange_rate DECIMAL(20, 10),                            -- Rate used for conversion

    -- Split configuration
    split_method split_method NOT NULL DEFAULT 'equal',

    -- Status
    status transaction_status NOT NULL DEFAULT 'confirmed',

    -- Who paid
    payer_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    payer_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,

    -- Group (optional - for group expenses)
    group_id UUID REFERENCES user_groups(id) ON DELETE SET NULL,

    -- Creator
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Transaction date (may differ from created_at)
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Category and visual
    category VARCHAR(50),                                     -- Expense category
    icon_name VARCHAR(50),                                    -- SF Symbol icon

    -- Receipt/attachment
    receipt_url TEXT,                                         -- Receipt image URL

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT positive_amount CHECK (amount > 0),
    CONSTRAINT valid_payer CHECK (
        payer_profile_id IS NOT NULL OR payer_contact_id IS NOT NULL
    ),
    CONSTRAINT single_payer CHECK (
        NOT (payer_profile_id IS NOT NULL AND payer_contact_id IS NOT NULL)
    )
);

-- ============================================================================
-- TABLE: transaction_splits
-- Description: How a transaction is split among participants
-- ============================================================================
CREATE TABLE transaction_splits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,

    -- Who owes this split (either a profile or contact)
    owed_by_profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    owed_by_contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,

    -- Split amount
    amount DECIMAL(15, 2) NOT NULL,                           -- Amount owed

    -- For percentage/shares split method
    percentage DECIMAL(5, 2),                                 -- Percentage of total (0-100)
    shares INTEGER,                                           -- Number of shares

    -- Raw amount before rounding (for exact reconciliation)
    raw_amount DECIMAL(15, 4),

    -- Settlement tracking
    amount_settled DECIMAL(15, 2) NOT NULL DEFAULT 0,         -- Amount already paid
    is_settled BOOLEAN NOT NULL DEFAULT false,                -- Fully settled flag
    settled_at TIMESTAMPTZ,                                   -- When fully settled

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT positive_split_amount CHECK (amount >= 0),
    CONSTRAINT valid_percentage CHECK (percentage IS NULL OR (percentage >= 0 AND percentage <= 100)),
    CONSTRAINT valid_shares CHECK (shares IS NULL OR shares >= 0),
    CONSTRAINT valid_owed_by CHECK (
        (owed_by_profile_id IS NOT NULL AND owed_by_contact_id IS NULL) OR
        (owed_by_profile_id IS NULL AND owed_by_contact_id IS NOT NULL)
    ),
    CONSTRAINT settled_amount_valid CHECK (amount_settled >= 0 AND amount_settled <= amount),
    -- Unique split per person per transaction
    CONSTRAINT unique_profile_split UNIQUE (transaction_id, owed_by_profile_id),
    CONSTRAINT unique_contact_split UNIQUE (transaction_id, owed_by_contact_id)
);

-- ============================================================================
-- TABLE: settlements
-- Description: Payments made to settle debts between users
-- ============================================================================
CREATE TABLE settlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Settlement amount
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),

    -- Parties involved (from -> to)
    from_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    from_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    to_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    to_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,

    -- Settlement details
    is_full_settlement BOOLEAN NOT NULL DEFAULT false,        -- Settles all debt
    note TEXT,                                                -- Optional note

    -- Status
    status settlement_status NOT NULL DEFAULT 'completed',

    -- Group context (optional)
    group_id UUID REFERENCES user_groups(id) ON DELETE SET NULL,

    -- Link to specific transaction (optional)
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,

    -- Creator
    created_by UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Settlement date
    settlement_date DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Payment method (for future use)
    payment_method VARCHAR(50),                               -- cash, venmo, bank, etc.

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT positive_settlement_amount CHECK (amount > 0),
    CONSTRAINT valid_from_party CHECK (
        (from_profile_id IS NOT NULL AND from_contact_id IS NULL) OR
        (from_profile_id IS NULL AND from_contact_id IS NOT NULL)
    ),
    CONSTRAINT valid_to_party CHECK (
        (to_profile_id IS NOT NULL AND to_contact_id IS NULL) OR
        (to_profile_id IS NULL AND to_contact_id IS NOT NULL)
    ),
    CONSTRAINT different_parties CHECK (
        NOT (from_profile_id IS NOT NULL AND from_profile_id = to_profile_id)
    )
);

-- ============================================================================
-- TABLE: reminders
-- Description: Payment reminders sent between users
-- ============================================================================
CREATE TABLE reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Reminder details
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
    message TEXT,                                             -- Custom reminder message

    -- Sender and recipient
    from_profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    to_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    to_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,

    -- Related transaction/group
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
    group_id UUID REFERENCES user_groups(id) ON DELETE SET NULL,

    -- Status
    is_read BOOLEAN NOT NULL DEFAULT false,
    is_cleared BOOLEAN NOT NULL DEFAULT false,                -- Dismissed by recipient
    read_at TIMESTAMPTZ,
    cleared_at TIMESTAMPTZ,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT positive_reminder_amount CHECK (amount > 0),
    CONSTRAINT valid_to_party CHECK (
        (to_profile_id IS NOT NULL AND to_contact_id IS NULL) OR
        (to_profile_id IS NULL AND to_contact_id IS NOT NULL)
    )
);

-- ============================================================================
-- TABLE: activity_log
-- Description: Audit log for tracking all changes (for activity feed)
-- ============================================================================
CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What happened
    action VARCHAR(50) NOT NULL,                              -- created, updated, deleted, settled, etc.
    entity_type VARCHAR(50) NOT NULL,                         -- transaction, settlement, reminder, etc.
    entity_id UUID NOT NULL,                                  -- ID of the affected entity

    -- Who did it
    actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Context
    group_id UUID REFERENCES user_groups(id) ON DELETE SET NULL,

    -- Details (JSON for flexibility)
    details JSONB,                                            -- Additional context

    -- When
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Profiles indexes
CREATE INDEX idx_profiles_phone ON profiles(phone_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_active ON profiles(is_active) WHERE deleted_at IS NULL;

-- Contacts indexes
CREATE INDEX idx_contacts_owner ON contacts(owner_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_contacts_phone ON contacts(phone_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_contacts_linked ON contacts(linked_profile_id) WHERE linked_profile_id IS NOT NULL AND deleted_at IS NULL;

-- Groups indexes
CREATE INDEX idx_groups_created_by ON user_groups(created_by) WHERE deleted_at IS NULL;

-- Group members indexes
CREATE INDEX idx_group_members_group ON group_members(group_id) WHERE left_at IS NULL;
CREATE INDEX idx_group_members_profile ON group_members(profile_id) WHERE profile_id IS NOT NULL AND left_at IS NULL;

-- Transactions indexes
CREATE INDEX idx_transactions_created_by ON transactions(created_by) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_payer_profile ON transactions(payer_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_group ON transactions(group_id) WHERE group_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_transactions_date ON transactions(transaction_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_status ON transactions(status) WHERE deleted_at IS NULL;
CREATE INDEX idx_transactions_recent ON transactions(created_at DESC) WHERE deleted_at IS NULL;

-- Transaction splits indexes
CREATE INDEX idx_splits_transaction ON transaction_splits(transaction_id);
CREATE INDEX idx_splits_owed_profile ON transaction_splits(owed_by_profile_id) WHERE owed_by_profile_id IS NOT NULL;
CREATE INDEX idx_splits_owed_contact ON transaction_splits(owed_by_contact_id) WHERE owed_by_contact_id IS NOT NULL;
CREATE INDEX idx_splits_unsettled ON transaction_splits(transaction_id) WHERE is_settled = false;

-- Settlements indexes
CREATE INDEX idx_settlements_from_profile ON settlements(from_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_settlements_to_profile ON settlements(to_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_settlements_group ON settlements(group_id) WHERE group_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_settlements_date ON settlements(settlement_date DESC) WHERE deleted_at IS NULL;

-- Reminders indexes
CREATE INDEX idx_reminders_from ON reminders(from_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_reminders_to_profile ON reminders(to_profile_id) WHERE to_profile_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_reminders_unread ON reminders(to_profile_id) WHERE is_read = false AND deleted_at IS NULL;

-- Activity log indexes
CREATE INDEX idx_activity_actor ON activity_log(actor_id);
CREATE INDEX idx_activity_entity ON activity_log(entity_type, entity_id);
CREATE INDEX idx_activity_recent ON activity_log(created_at DESC);
CREATE INDEX idx_activity_group ON activity_log(group_id) WHERE group_id IS NOT NULL;

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate balance between two profiles
CREATE OR REPLACE FUNCTION calculate_balance(user1_id UUID, user2_id UUID)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    user1_owes DECIMAL(15, 2) := 0;
    user2_owes DECIMAL(15, 2) := 0;
    settlements_from_1_to_2 DECIMAL(15, 2) := 0;
    settlements_from_2_to_1 DECIMAL(15, 2) := 0;
BEGIN
    -- Calculate what user1 owes user2 (from transactions where user2 paid)
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO user1_owes
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE ts.owed_by_profile_id = user1_id
      AND t.payer_profile_id = user2_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Calculate what user2 owes user1 (from transactions where user1 paid)
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO user2_owes
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE ts.owed_by_profile_id = user2_id
      AND t.payer_profile_id = user1_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Get settlements from user1 to user2
    SELECT COALESCE(SUM(amount), 0)
    INTO settlements_from_1_to_2
    FROM settlements
    WHERE from_profile_id = user1_id
      AND to_profile_id = user2_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    -- Get settlements from user2 to user1
    SELECT COALESCE(SUM(amount), 0)
    INTO settlements_from_2_to_1
    FROM settlements
    WHERE from_profile_id = user2_id
      AND to_profile_id = user1_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    -- Positive = user2 owes user1, Negative = user1 owes user2
    RETURN (user2_owes - settlements_from_2_to_1) - (user1_owes - settlements_from_1_to_2);
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get total amount user owes others
CREATE OR REPLACE FUNCTION get_total_owed_by_user(user_id UUID)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    total_owed DECIMAL(15, 2) := 0;
BEGIN
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO total_owed
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE ts.owed_by_profile_id = user_id
      AND t.payer_profile_id != user_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    RETURN total_owed;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get total amount others owe user
CREATE OR REPLACE FUNCTION get_total_owed_to_user(user_id UUID)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    total_owed DECIMAL(15, 2) := 0;
BEGIN
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0)
    INTO total_owed
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE t.payer_profile_id = user_id
      AND ts.owed_by_profile_id != user_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    RETURN total_owed;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to link contact to profile when they join the app
CREATE OR REPLACE FUNCTION link_contact_to_profile()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new profile is created, link any existing contacts with same phone
    UPDATE contacts
    SET linked_profile_id = NEW.id,
        updated_at = NOW()
    WHERE phone_number = NEW.phone_number
      AND linked_profile_id IS NULL;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to log activity
CREATE OR REPLACE FUNCTION log_activity()
RETURNS TRIGGER AS $$
DECLARE
    action_type VARCHAR(50);
    actor UUID;
BEGIN
    -- Determine action type
    IF TG_OP = 'INSERT' THEN
        action_type := 'created';
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
            action_type := 'deleted';
        ELSE
            action_type := 'updated';
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        action_type := 'hard_deleted';
    END IF;

    -- Get actor (created_by for new, or from the record)
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        actor := COALESCE(NEW.created_by, NEW.from_profile_id, NEW.actor_id);

        INSERT INTO activity_log (action, entity_type, entity_id, actor_id, group_id, details)
        VALUES (
            action_type,
            TG_TABLE_NAME,
            NEW.id,
            actor,
            CASE WHEN TG_TABLE_NAME IN ('transactions', 'settlements') THEN NEW.group_id ELSE NULL END,
            jsonb_build_object('table', TG_TABLE_NAME, 'operation', TG_OP)
        );
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Updated_at triggers
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at
    BEFORE UPDATE ON contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at
    BEFORE UPDATE ON user_groups
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_group_members_updated_at
    BEFORE UPDATE ON group_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_splits_updated_at
    BEFORE UPDATE ON transaction_splits
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_settlements_updated_at
    BEFORE UPDATE ON settlements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reminders_updated_at
    BEFORE UPDATE ON reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_currencies_updated_at
    BEFORE UPDATE ON currencies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Link contacts to profiles when new profile is created
CREATE TRIGGER link_contacts_on_profile_create
    AFTER INSERT ON profiles
    FOR EACH ROW EXECUTE FUNCTION link_contact_to_profile();

-- Activity logging triggers (for transactions and settlements)
CREATE TRIGGER log_transaction_activity
    AFTER INSERT OR UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION log_activity();

CREATE TRIGGER log_settlement_activity
    AFTER INSERT OR UPDATE ON settlements
    FOR EACH ROW EXECUTE FUNCTION log_activity();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_splits ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;

-- Currencies: Everyone can read
CREATE POLICY "Currencies are viewable by everyone"
    ON currencies FOR SELECT
    USING (true);

-- Profiles: Users can view and update their own profile
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (id = auth.uid());

-- Profiles: Users can view profiles of people they have transactions with
CREATE POLICY "Users can view profiles of transaction participants"
    ON profiles FOR SELECT
    USING (
        id IN (
            -- People in same transactions
            SELECT DISTINCT t.payer_profile_id FROM transactions t WHERE t.created_by = auth.uid()
            UNION
            SELECT DISTINCT ts.owed_by_profile_id FROM transaction_splits ts
                JOIN transactions t ON t.id = ts.transaction_id
                WHERE t.created_by = auth.uid() AND ts.owed_by_profile_id IS NOT NULL
        )
    );

-- Contacts: Users can CRUD their own contacts
CREATE POLICY "Users can manage their own contacts"
    ON contacts FOR ALL
    USING (owner_id = auth.uid());

-- Groups: Members can view their groups
CREATE POLICY "Group members can view groups"
    ON user_groups FOR SELECT
    USING (
        id IN (
            SELECT group_id FROM group_members
            WHERE (profile_id = auth.uid() OR created_by = auth.uid())
              AND left_at IS NULL
        )
        OR created_by = auth.uid()
    );

-- Groups: Creators and admins can update
CREATE POLICY "Group admins can update groups"
    ON user_groups FOR UPDATE
    USING (
        created_by = auth.uid()
        OR id IN (
            SELECT group_id FROM group_members
            WHERE profile_id = auth.uid() AND is_admin = true AND left_at IS NULL
        )
    );

-- Groups: Any user can create groups
CREATE POLICY "Users can create groups"
    ON user_groups FOR INSERT
    WITH CHECK (created_by = auth.uid());

-- Group members: Members can view other members
CREATE POLICY "Group members can view group members"
    ON group_members FOR SELECT
    USING (
        group_id IN (
            SELECT group_id FROM group_members
            WHERE profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Transactions: Creator and participants can view
CREATE POLICY "Transaction participants can view transactions"
    ON transactions FOR SELECT
    USING (
        created_by = auth.uid()
        OR payer_profile_id = auth.uid()
        OR id IN (
            SELECT transaction_id FROM transaction_splits
            WHERE owed_by_profile_id = auth.uid()
        )
    );

-- Transactions: Creator can update/delete
CREATE POLICY "Transaction creator can modify"
    ON transactions FOR UPDATE
    USING (created_by = auth.uid());

CREATE POLICY "Transaction creator can delete"
    ON transactions FOR DELETE
    USING (created_by = auth.uid());

-- Transactions: Users can create transactions
CREATE POLICY "Users can create transactions"
    ON transactions FOR INSERT
    WITH CHECK (created_by = auth.uid());

-- Transaction splits: Same as transactions
CREATE POLICY "Split participants can view splits"
    ON transaction_splits FOR SELECT
    USING (
        transaction_id IN (
            SELECT id FROM transactions
            WHERE created_by = auth.uid()
               OR payer_profile_id = auth.uid()
        )
        OR owed_by_profile_id = auth.uid()
    );

CREATE POLICY "Transaction creator can manage splits"
    ON transaction_splits FOR ALL
    USING (
        transaction_id IN (
            SELECT id FROM transactions WHERE created_by = auth.uid()
        )
    );

-- Settlements: Participants can view
CREATE POLICY "Settlement participants can view"
    ON settlements FOR SELECT
    USING (
        created_by = auth.uid()
        OR from_profile_id = auth.uid()
        OR to_profile_id = auth.uid()
    );

CREATE POLICY "Users can create settlements"
    ON settlements FOR INSERT
    WITH CHECK (created_by = auth.uid());

CREATE POLICY "Settlement creator can update"
    ON settlements FOR UPDATE
    USING (created_by = auth.uid());

-- Reminders: Sender and recipient can view
CREATE POLICY "Reminder participants can view"
    ON reminders FOR SELECT
    USING (
        from_profile_id = auth.uid()
        OR to_profile_id = auth.uid()
    );

CREATE POLICY "Users can send reminders"
    ON reminders FOR INSERT
    WITH CHECK (from_profile_id = auth.uid());

CREATE POLICY "Reminder recipient can update read status"
    ON reminders FOR UPDATE
    USING (to_profile_id = auth.uid());

-- Activity log: Users can view their own activity
CREATE POLICY "Users can view their activity"
    ON activity_log FOR SELECT
    USING (actor_id = auth.uid());

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS
-- ============================================================================

-- Enable real-time for tables that need live updates
ALTER PUBLICATION supabase_realtime ADD TABLE transactions;
ALTER PUBLICATION supabase_realtime ADD TABLE transaction_splits;
ALTER PUBLICATION supabase_realtime ADD TABLE settlements;
ALTER PUBLICATION supabase_realtime ADD TABLE reminders;
ALTER PUBLICATION supabase_realtime ADD TABLE activity_log;

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Recent transactions for a user (for Home page)
CREATE OR REPLACE VIEW recent_transactions AS
SELECT
    t.id,
    t.title,
    t.amount,
    t.currency,
    t.transaction_date,
    t.split_method,
    t.status,
    t.created_by,
    t.created_at,
    p.display_name as payer_name,
    p.avatar_url as payer_avatar,
    g.name as group_name,
    (
        SELECT jsonb_agg(jsonb_build_object(
            'id', ts.id,
            'amount', ts.amount,
            'is_settled', ts.is_settled,
            'owed_by_profile_id', ts.owed_by_profile_id
        ))
        FROM transaction_splits ts
        WHERE ts.transaction_id = t.id
    ) as splits
FROM transactions t
LEFT JOIN profiles p ON p.id = t.payer_profile_id
LEFT JOIN user_groups g ON g.id = t.group_id
WHERE t.deleted_at IS NULL
ORDER BY t.transaction_date DESC, t.created_at DESC;

-- ============================================================================
-- SEED DATA (Optional - for development)
-- ============================================================================

-- Uncomment below to add test data in development
/*
INSERT INTO profiles (id, phone_number, display_name, phone_verified, default_currency)
VALUES
    ('00000000-0000-0000-0000-000000000000', '+10000000000', 'You', true, 'USD');
*/

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
