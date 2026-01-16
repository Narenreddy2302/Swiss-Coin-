-- ============================================================================
-- SWISS COIN - SUBSCRIPTIONS PAGE DATABASE SCHEMA
-- Version: 1.0.0
-- Description: Complete subscription management with payments, settlements, reminders
-- Features: Personal/Shared subscriptions, Billing cycles, Balance tracking, Chat
-- ============================================================================

-- ============================================================================
-- CUSTOM TYPES (ENUMS) FOR SUBSCRIPTIONS
-- ============================================================================

-- Billing cycle types
CREATE TYPE billing_cycle AS ENUM (
    'weekly',          -- Every 7 days
    'monthly',         -- Every month
    'yearly',          -- Every year
    'custom'           -- Custom number of days
);

-- Billing status (calculated, not stored)
CREATE TYPE billing_status AS ENUM (
    'upcoming',        -- More than 7 days away
    'due',             -- Within 7 days
    'overdue',         -- Past billing date
    'paused'           -- Subscription is paused
);

-- Subscription category
CREATE TYPE subscription_category AS ENUM (
    'streaming',       -- Netflix, Spotify, etc.
    'software',        -- Apps and software
    'gaming',          -- Gaming subscriptions
    'news',            -- News and magazines
    'fitness',         -- Gym, fitness apps
    'cloud',           -- Cloud storage
    'utilities',       -- Phone, internet, etc.
    'membership',      -- Club memberships
    'insurance',       -- Insurance payments
    'other'            -- Other subscriptions
);

-- ============================================================================
-- TABLE: subscriptions
-- Description: Core subscription entity for recurring payments
-- ============================================================================
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Basic info
    name VARCHAR(200) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),

    -- Billing cycle
    cycle billing_cycle NOT NULL DEFAULT 'monthly',
    custom_cycle_days SMALLINT DEFAULT 30,                    -- For custom cycles (1-365)

    -- Dates
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    next_billing_date DATE NOT NULL,

    -- Status
    is_shared BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,

    -- Categorization
    category subscription_category DEFAULT 'other',

    -- Appearance
    icon_name VARCHAR(50) DEFAULT 'creditcard.fill',          -- SF Symbol name
    color_hex VARCHAR(7) DEFAULT '#007AFF',

    -- Notes
    notes TEXT,

    -- Notifications
    notification_enabled BOOLEAN NOT NULL DEFAULT true,
    notification_days_before SMALLINT NOT NULL DEFAULT 3,     -- Days before due date (1-14)

    -- Owner (creator of the subscription)
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,                                   -- Soft delete (cancelled)
    cancelled_at TIMESTAMPTZ,                                 -- When subscription was cancelled
    cancellation_reason TEXT,                                 -- Why it was cancelled

    -- Constraints
    CONSTRAINT positive_amount CHECK (amount > 0),
    CONSTRAINT valid_custom_cycle CHECK (
        cycle != 'custom' OR (custom_cycle_days >= 1 AND custom_cycle_days <= 365)
    ),
    CONSTRAINT valid_notification_days CHECK (
        notification_days_before >= 1 AND notification_days_before <= 14
    ),
    CONSTRAINT valid_color_hex CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- ============================================================================
-- TABLE: subscription_members
-- Description: Members (subscribers) of shared subscriptions
-- ============================================================================
CREATE TABLE subscription_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    -- Member can be either a profile (app user) or a contact (non-app user)
    member_profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    member_contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,

    -- Member details
    share_percentage DECIMAL(5, 2),                           -- Optional custom share (NULL = equal split)
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,                                      -- When member left the subscription

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_member CHECK (
        (member_profile_id IS NOT NULL AND member_contact_id IS NULL) OR
        (member_profile_id IS NULL AND member_contact_id IS NOT NULL)
    ),
    CONSTRAINT valid_share CHECK (share_percentage IS NULL OR (share_percentage > 0 AND share_percentage <= 100)),
    -- Unique member per subscription
    CONSTRAINT unique_profile_member UNIQUE (subscription_id, member_profile_id),
    CONSTRAINT unique_contact_member UNIQUE (subscription_id, member_contact_id)
);

-- ============================================================================
-- TABLE: subscription_payments
-- Description: Payment records for subscriptions
-- ============================================================================
CREATE TABLE subscription_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    -- Payment details
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Billing period this payment covers
    billing_period_start DATE,
    billing_period_end DATE,

    -- Who paid (for shared subscriptions)
    payer_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    payer_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,

    -- Additional info
    note TEXT,
    payment_method VARCHAR(50),                               -- card, bank, cash, etc.
    external_reference VARCHAR(100),                          -- External payment ID

    -- Auto-generated or manual
    is_auto_recorded BOOLEAN NOT NULL DEFAULT false,          -- If generated by recurring logic

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,

    -- Constraints
    CONSTRAINT positive_payment_amount CHECK (amount > 0),
    CONSTRAINT valid_payer CHECK (
        payer_profile_id IS NOT NULL OR payer_contact_id IS NOT NULL
    ),
    CONSTRAINT single_payer CHECK (
        NOT (payer_profile_id IS NOT NULL AND payer_contact_id IS NOT NULL)
    )
);

-- ============================================================================
-- TABLE: subscription_settlements
-- Description: Settlement records between subscription members
-- ============================================================================
CREATE TABLE subscription_settlements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    -- Settlement amount
    amount DECIMAL(15, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' REFERENCES currencies(code),
    date TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- From who to who
    from_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    from_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
    to_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    to_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,

    -- Additional info
    note TEXT,
    is_full_settlement BOOLEAN NOT NULL DEFAULT false,        -- Settles entire balance

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
    )
);

-- ============================================================================
-- TABLE: subscription_reminders
-- Description: Payment reminders for subscription members
-- ============================================================================
CREATE TABLE subscription_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    -- Reminder details
    amount DECIMAL(15, 2) NOT NULL,                           -- Amount being reminded about
    message TEXT,                                             -- Custom reminder message

    -- Sender and recipient
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    to_profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    to_contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,

    -- Status
    is_read BOOLEAN NOT NULL DEFAULT false,
    is_dismissed BOOLEAN NOT NULL DEFAULT false,              -- Recipient dismissed
    read_at TIMESTAMPTZ,
    dismissed_at TIMESTAMPTZ,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT positive_reminder_amount CHECK (amount > 0),
    CONSTRAINT valid_recipient CHECK (
        (to_profile_id IS NOT NULL AND to_contact_id IS NULL) OR
        (to_profile_id IS NULL AND to_contact_id IS NOT NULL)
    )
);

-- ============================================================================
-- TABLE: subscription_notifications
-- Description: Scheduled notifications for subscription billing
-- ============================================================================
CREATE TABLE subscription_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Notification details
    notification_type VARCHAR(50) NOT NULL,                   -- 'upcoming_billing', 'overdue', etc.
    scheduled_for TIMESTAMPTZ NOT NULL,                       -- When to send
    sent_at TIMESTAMPTZ,                                      -- When actually sent
    is_sent BOOLEAN NOT NULL DEFAULT false,

    -- Content
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT unique_notification UNIQUE (subscription_id, user_id, notification_type, scheduled_for)
);

-- ============================================================================
-- TABLE: subscription_activity_log
-- Description: Activity log for subscription events
-- ============================================================================
CREATE TABLE subscription_activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,

    -- What happened
    action VARCHAR(50) NOT NULL,                              -- payment_recorded, settlement_made, etc.
    actor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Related entities
    payment_id UUID REFERENCES subscription_payments(id) ON DELETE SET NULL,
    settlement_id UUID REFERENCES subscription_settlements(id) ON DELETE SET NULL,
    reminder_id UUID REFERENCES subscription_reminders(id) ON DELETE SET NULL,

    -- Human-readable summary
    summary TEXT NOT NULL,
    details JSONB DEFAULT '{}'::jsonb,

    -- When
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR SUBSCRIPTIONS
-- ============================================================================

-- Subscriptions indexes
CREATE INDEX idx_subscriptions_owner ON subscriptions(owner_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_subscriptions_active ON subscriptions(is_active) WHERE deleted_at IS NULL;
CREATE INDEX idx_subscriptions_shared ON subscriptions(is_shared) WHERE deleted_at IS NULL AND is_shared = true;
CREATE INDEX idx_subscriptions_next_billing ON subscriptions(next_billing_date) WHERE deleted_at IS NULL AND is_active = true;
CREATE INDEX idx_subscriptions_category ON subscriptions(category) WHERE deleted_at IS NULL;

-- Subscription members indexes
CREATE INDEX idx_subscription_members_subscription ON subscription_members(subscription_id) WHERE left_at IS NULL;
CREATE INDEX idx_subscription_members_profile ON subscription_members(member_profile_id) WHERE member_profile_id IS NOT NULL AND left_at IS NULL;
CREATE INDEX idx_subscription_members_contact ON subscription_members(member_contact_id) WHERE member_contact_id IS NOT NULL AND left_at IS NULL;

-- Subscription payments indexes
CREATE INDEX idx_subscription_payments_subscription ON subscription_payments(subscription_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_subscription_payments_payer ON subscription_payments(payer_profile_id) WHERE payer_profile_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_subscription_payments_date ON subscription_payments(date DESC) WHERE deleted_at IS NULL;

-- Subscription settlements indexes
CREATE INDEX idx_subscription_settlements_subscription ON subscription_settlements(subscription_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_subscription_settlements_from ON subscription_settlements(from_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_subscription_settlements_to ON subscription_settlements(to_profile_id) WHERE deleted_at IS NULL;

-- Subscription reminders indexes
CREATE INDEX idx_subscription_reminders_subscription ON subscription_reminders(subscription_id);
CREATE INDEX idx_subscription_reminders_recipient ON subscription_reminders(to_profile_id) WHERE to_profile_id IS NOT NULL AND is_read = false;

-- Subscription notifications indexes
CREATE INDEX idx_subscription_notifications_scheduled ON subscription_notifications(scheduled_for) WHERE is_sent = false;
CREATE INDEX idx_subscription_notifications_subscription ON subscription_notifications(subscription_id);

-- Activity log indexes
CREATE INDEX idx_subscription_activity_subscription ON subscription_activity_log(subscription_id);
CREATE INDEX idx_subscription_activity_recent ON subscription_activity_log(created_at DESC);

-- ============================================================================
-- FUNCTIONS FOR SUBSCRIPTIONS
-- ============================================================================

-- Function to calculate next billing date based on cycle
CREATE OR REPLACE FUNCTION calculate_next_billing_date(
    p_from_date DATE,
    p_cycle billing_cycle,
    p_custom_days INTEGER DEFAULT 30
)
RETURNS DATE AS $$
BEGIN
    CASE p_cycle
        WHEN 'weekly' THEN
            RETURN p_from_date + INTERVAL '7 days';
        WHEN 'monthly' THEN
            RETURN p_from_date + INTERVAL '1 month';
        WHEN 'yearly' THEN
            RETURN p_from_date + INTERVAL '1 year';
        WHEN 'custom' THEN
            RETURN p_from_date + (p_custom_days || ' days')::INTERVAL;
        ELSE
            RETURN p_from_date + INTERVAL '1 month';
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate monthly equivalent of subscription amount
CREATE OR REPLACE FUNCTION calculate_monthly_equivalent(
    p_amount DECIMAL(15, 2),
    p_cycle billing_cycle,
    p_custom_days INTEGER DEFAULT 30
)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    days_per_month CONSTANT DECIMAL := 30.44;
BEGIN
    CASE p_cycle
        WHEN 'weekly' THEN
            RETURN p_amount * 4.33;  -- Average weeks per month
        WHEN 'monthly' THEN
            RETURN p_amount;
        WHEN 'yearly' THEN
            RETURN p_amount / 12.0;
        WHEN 'custom' THEN
            RETURN p_amount * (days_per_month / GREATEST(p_custom_days, 1));
        ELSE
            RETURN p_amount;
    END CASE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get billing status for a subscription
CREATE OR REPLACE FUNCTION get_billing_status(
    p_next_billing_date DATE,
    p_is_active BOOLEAN
)
RETURNS billing_status AS $$
DECLARE
    days_until INTEGER;
BEGIN
    IF NOT p_is_active THEN
        RETURN 'paused';
    END IF;

    days_until := p_next_billing_date - CURRENT_DATE;

    IF days_until < 0 THEN
        RETURN 'overdue';
    ELSIF days_until <= 7 THEN
        RETURN 'due';
    ELSE
        RETURN 'upcoming';
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get subscriber count for a subscription (including owner)
CREATE OR REPLACE FUNCTION get_subscriber_count(p_subscription_id UUID)
RETURNS INTEGER AS $$
DECLARE
    member_count INTEGER;
    is_shared BOOLEAN;
BEGIN
    SELECT s.is_shared INTO is_shared
    FROM subscriptions s
    WHERE s.id = p_subscription_id AND s.deleted_at IS NULL;

    IF NOT is_shared THEN
        RETURN 1;
    END IF;

    SELECT COUNT(*) INTO member_count
    FROM subscription_members sm
    WHERE sm.subscription_id = p_subscription_id AND sm.left_at IS NULL;

    RETURN member_count + 1;  -- +1 for owner
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate user's share of a subscription
CREATE OR REPLACE FUNCTION calculate_user_share(
    p_subscription_id UUID,
    p_user_id UUID
)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    v_amount DECIMAL(15, 2);
    v_is_shared BOOLEAN;
    v_subscriber_count INTEGER;
BEGIN
    SELECT s.amount, s.is_shared INTO v_amount, v_is_shared
    FROM subscriptions s
    WHERE s.id = p_subscription_id AND s.deleted_at IS NULL;

    IF NOT v_is_shared THEN
        RETURN v_amount;
    END IF;

    v_subscriber_count := get_subscriber_count(p_subscription_id);

    IF v_subscriber_count = 0 THEN
        RETURN v_amount;
    END IF;

    RETURN v_amount / v_subscriber_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate balance for a user in a shared subscription
CREATE OR REPLACE FUNCTION calculate_subscription_user_balance(
    p_subscription_id UUID,
    p_user_id UUID
)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    v_balance DECIMAL(15, 2) := 0;
    v_subscriber_count INTEGER;
    v_payment RECORD;
    v_settlement RECORD;
    v_amount_per_member DECIMAL(15, 2);
BEGIN
    v_subscriber_count := get_subscriber_count(p_subscription_id);

    IF v_subscriber_count = 0 THEN
        RETURN 0;
    END IF;

    -- Process payments
    FOR v_payment IN
        SELECT sp.amount, sp.payer_profile_id
        FROM subscription_payments sp
        WHERE sp.subscription_id = p_subscription_id
          AND sp.deleted_at IS NULL
    LOOP
        v_amount_per_member := v_payment.amount / v_subscriber_count;

        IF v_payment.payer_profile_id = p_user_id THEN
            -- User paid - others owe their share
            v_balance := v_balance + v_payment.amount - v_amount_per_member;
        ELSE
            -- Someone else paid - user owes their share
            v_balance := v_balance - v_amount_per_member;
        END IF;
    END LOOP;

    -- Process settlements
    FOR v_settlement IN
        SELECT ss.amount, ss.from_profile_id, ss.to_profile_id
        FROM subscription_settlements ss
        WHERE ss.subscription_id = p_subscription_id
          AND ss.deleted_at IS NULL
    LOOP
        IF v_settlement.to_profile_id = p_user_id THEN
            -- Someone paid user
            v_balance := v_balance - v_settlement.amount;
        ELSIF v_settlement.from_profile_id = p_user_id THEN
            -- User paid someone
            v_balance := v_balance + v_settlement.amount;
        END IF;
    END LOOP;

    RETURN v_balance;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to calculate balance between user and specific member
CREATE OR REPLACE FUNCTION calculate_subscription_member_balance(
    p_subscription_id UUID,
    p_user_id UUID,
    p_member_id UUID
)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    v_balance DECIMAL(15, 2) := 0;
    v_subscriber_count INTEGER;
    v_payment RECORD;
    v_settlement RECORD;
    v_amount_per_member DECIMAL(15, 2);
BEGIN
    IF p_user_id = p_member_id THEN
        RETURN 0;
    END IF;

    v_subscriber_count := get_subscriber_count(p_subscription_id);

    IF v_subscriber_count = 0 THEN
        RETURN 0;
    END IF;

    -- Process payments
    FOR v_payment IN
        SELECT sp.amount, sp.payer_profile_id
        FROM subscription_payments sp
        WHERE sp.subscription_id = p_subscription_id
          AND sp.deleted_at IS NULL
    LOOP
        v_amount_per_member := v_payment.amount / v_subscriber_count;

        IF v_payment.payer_profile_id = p_user_id THEN
            -- User paid - member owes their share
            v_balance := v_balance + v_amount_per_member;
        ELSIF v_payment.payer_profile_id = p_member_id THEN
            -- Member paid - user owes their share
            v_balance := v_balance - v_amount_per_member;
        END IF;
    END LOOP;

    -- Process settlements between user and member
    FOR v_settlement IN
        SELECT ss.amount, ss.from_profile_id, ss.to_profile_id
        FROM subscription_settlements ss
        WHERE ss.subscription_id = p_subscription_id
          AND ss.deleted_at IS NULL
          AND (
              (ss.from_profile_id = p_member_id AND ss.to_profile_id = p_user_id) OR
              (ss.from_profile_id = p_user_id AND ss.to_profile_id = p_member_id)
          )
    LOOP
        IF v_settlement.from_profile_id = p_member_id AND v_settlement.to_profile_id = p_user_id THEN
            -- Member paid user
            v_balance := v_balance - v_settlement.amount;
        ELSIF v_settlement.from_profile_id = p_user_id AND v_settlement.to_profile_id = p_member_id THEN
            -- User paid member
            v_balance := v_balance + v_settlement.amount;
        END IF;
    END LOOP;

    RETURN v_balance;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get all member balances for a subscription
CREATE OR REPLACE FUNCTION get_subscription_member_balances(
    p_subscription_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    member_id UUID,
    member_name VARCHAR(100),
    avatar_url TEXT,
    color_hex VARCHAR(7),
    balance DECIMAL(15, 2),
    total_paid DECIMAL(15, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(sm.member_profile_id, sm.member_contact_id) as member_id,
        COALESCE(p.display_name, c.display_name) as member_name,
        COALESCE(p.avatar_url, c.avatar_url) as avatar_url,
        COALESCE(p.color_hex, c.color_hex, '#007AFF') as color_hex,
        calculate_subscription_member_balance(p_subscription_id, p_user_id, COALESCE(sm.member_profile_id, sm.member_contact_id)) as balance,
        COALESCE(
            (SELECT SUM(sp.amount) FROM subscription_payments sp
             WHERE sp.subscription_id = p_subscription_id
               AND sp.payer_profile_id = sm.member_profile_id
               AND sp.deleted_at IS NULL),
            0
        ) as total_paid
    FROM subscription_members sm
    LEFT JOIN profiles p ON p.id = sm.member_profile_id
    LEFT JOIN contacts c ON c.id = sm.member_contact_id
    WHERE sm.subscription_id = p_subscription_id
      AND sm.left_at IS NULL
      AND COALESCE(sm.member_profile_id, sm.member_contact_id) != p_user_id
    ORDER BY member_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get members who owe user
CREATE OR REPLACE FUNCTION get_subscription_members_who_owe(
    p_subscription_id UUID,
    p_user_id UUID
)
RETURNS TABLE (
    member_id UUID,
    member_name VARCHAR(100),
    amount_owed DECIMAL(15, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        mb.member_id,
        mb.member_name,
        mb.balance as amount_owed
    FROM get_subscription_member_balances(p_subscription_id, p_user_id) mb
    WHERE mb.balance > 0.01
    ORDER BY mb.balance DESC;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get conversation items for a subscription
CREATE OR REPLACE FUNCTION get_subscription_conversation_items(
    p_subscription_id UUID,
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
    -- Payments
    SELECT
        sp.id as item_id,
        'payment'::VARCHAR(20) as item_type,
        COALESCE(p.display_name, 'Someone') || ' paid' as content,
        sp.amount,
        sp.payer_profile_id as actor_id,
        p.display_name as actor_name,
        sp.created_at,
        jsonb_build_object(
            'note', sp.note,
            'billing_period_start', sp.billing_period_start,
            'billing_period_end', sp.billing_period_end
        ) as metadata
    FROM subscription_payments sp
    LEFT JOIN profiles p ON p.id = sp.payer_profile_id
    WHERE sp.subscription_id = p_subscription_id
      AND sp.deleted_at IS NULL
      AND (p_before_timestamp IS NULL OR sp.created_at < p_before_timestamp)

    UNION ALL

    -- Settlements
    SELECT
        ss.id as item_id,
        'settlement'::VARCHAR(20) as item_type,
        COALESCE(from_p.display_name, 'Someone') || ' paid ' || COALESCE(to_p.display_name, 'someone') as content,
        ss.amount,
        ss.from_profile_id as actor_id,
        from_p.display_name as actor_name,
        ss.created_at,
        jsonb_build_object(
            'note', ss.note,
            'from_profile_id', ss.from_profile_id,
            'to_profile_id', ss.to_profile_id,
            'is_full_settlement', ss.is_full_settlement
        ) as metadata
    FROM subscription_settlements ss
    LEFT JOIN profiles from_p ON from_p.id = ss.from_profile_id
    LEFT JOIN profiles to_p ON to_p.id = ss.to_profile_id
    WHERE ss.subscription_id = p_subscription_id
      AND ss.deleted_at IS NULL
      AND (p_before_timestamp IS NULL OR ss.created_at < p_before_timestamp)

    UNION ALL

    -- Reminders
    SELECT
        sr.id as item_id,
        'reminder'::VARCHAR(20) as item_type,
        'Reminder sent to ' || COALESCE(to_p.display_name, 'someone') as content,
        sr.amount,
        sr.sender_id as actor_id,
        sender_p.display_name as actor_name,
        sr.created_at,
        jsonb_build_object(
            'message', sr.message,
            'is_read', sr.is_read,
            'to_profile_id', sr.to_profile_id
        ) as metadata
    FROM subscription_reminders sr
    LEFT JOIN profiles sender_p ON sender_p.id = sr.sender_id
    LEFT JOIN profiles to_p ON to_p.id = sr.to_profile_id
    WHERE sr.subscription_id = p_subscription_id
      AND (p_before_timestamp IS NULL OR sr.created_at < p_before_timestamp)

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
            'is_edited', m.is_edited,
            'status', m.status::text
        ) as metadata
    FROM chat_messages m
    LEFT JOIN profiles p ON p.id = m.sender_id
    JOIN subscriptions s ON s.id = p_subscription_id
    WHERE m.group_id IS NULL
      AND m.recipient_profile_id IS NULL
      AND m.deleted_at IS NULL
      AND (p_before_timestamp IS NULL OR m.created_at < p_before_timestamp)
      -- Link to subscription via a special metadata field or separate join table
      -- For now, we'll use the subscription's chat_messages relationship via the app

    ORDER BY created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to record a subscription payment
CREATE OR REPLACE FUNCTION record_subscription_payment(
    p_subscription_id UUID,
    p_payer_id UUID,
    p_amount DECIMAL(15, 2),
    p_note TEXT DEFAULT NULL,
    p_update_next_billing BOOLEAN DEFAULT true
)
RETURNS UUID AS $$
DECLARE
    v_payment_id UUID;
    v_subscription RECORD;
BEGIN
    -- Get subscription details
    SELECT * INTO v_subscription
    FROM subscriptions
    WHERE id = p_subscription_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Subscription not found';
    END IF;

    -- Create payment
    INSERT INTO subscription_payments (
        subscription_id, amount, currency, payer_profile_id,
        billing_period_start, billing_period_end, note
    )
    VALUES (
        p_subscription_id,
        p_amount,
        v_subscription.currency,
        p_payer_id,
        v_subscription.next_billing_date - CASE v_subscription.cycle
            WHEN 'weekly' THEN INTERVAL '7 days'
            WHEN 'monthly' THEN INTERVAL '1 month'
            WHEN 'yearly' THEN INTERVAL '1 year'
            WHEN 'custom' THEN (v_subscription.custom_cycle_days || ' days')::INTERVAL
        END,
        v_subscription.next_billing_date,
        p_note
    )
    RETURNING id INTO v_payment_id;

    -- Update next billing date if requested
    IF p_update_next_billing THEN
        UPDATE subscriptions
        SET next_billing_date = calculate_next_billing_date(
            CURRENT_DATE, cycle, custom_cycle_days
        ),
        updated_at = NOW()
        WHERE id = p_subscription_id;
    END IF;

    -- Log activity
    INSERT INTO subscription_activity_log (
        subscription_id, action, actor_id, payment_id,
        summary, details
    )
    VALUES (
        p_subscription_id,
        'payment_recorded',
        p_payer_id,
        v_payment_id,
        'Payment of ' || v_subscription.currency || p_amount || ' recorded',
        jsonb_build_object('amount', p_amount, 'note', p_note)
    );

    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get subscription summary for a user
CREATE OR REPLACE FUNCTION get_subscription_summary(p_user_id UUID)
RETURNS TABLE (
    personal_monthly_total DECIMAL(15, 2),
    personal_count INTEGER,
    shared_monthly_total DECIMAL(15, 2),
    shared_your_share DECIMAL(15, 2),
    shared_count INTEGER,
    next_due_date DATE,
    overdue_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- Personal subscriptions monthly total
        COALESCE(SUM(
            CASE WHEN NOT s.is_shared THEN
                calculate_monthly_equivalent(s.amount, s.cycle, s.custom_cycle_days)
            ELSE 0 END
        ), 0) as personal_monthly_total,

        -- Personal subscription count
        COALESCE(SUM(CASE WHEN NOT s.is_shared THEN 1 ELSE 0 END)::INTEGER, 0) as personal_count,

        -- Shared subscriptions monthly total
        COALESCE(SUM(
            CASE WHEN s.is_shared THEN
                calculate_monthly_equivalent(s.amount, s.cycle, s.custom_cycle_days)
            ELSE 0 END
        ), 0) as shared_monthly_total,

        -- Your share of shared subscriptions
        COALESCE(SUM(
            CASE WHEN s.is_shared THEN
                calculate_monthly_equivalent(
                    s.amount / get_subscriber_count(s.id),
                    s.cycle,
                    s.custom_cycle_days
                )
            ELSE 0 END
        ), 0) as shared_your_share,

        -- Shared subscription count
        COALESCE(SUM(CASE WHEN s.is_shared THEN 1 ELSE 0 END)::INTEGER, 0) as shared_count,

        -- Next due date
        MIN(CASE WHEN s.is_active AND s.next_billing_date >= CURRENT_DATE THEN s.next_billing_date END) as next_due_date,

        -- Overdue count
        COALESCE(SUM(CASE WHEN s.is_active AND s.next_billing_date < CURRENT_DATE THEN 1 ELSE 0 END)::INTEGER, 0) as overdue_count

    FROM subscriptions s
    LEFT JOIN subscription_members sm ON sm.subscription_id = s.id AND sm.left_at IS NULL
    WHERE s.deleted_at IS NULL
      AND (
          s.owner_id = p_user_id
          OR sm.member_profile_id = p_user_id
      );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- TRIGGERS FOR SUBSCRIPTIONS
-- ============================================================================

-- Trigger to update updated_at
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_members_updated_at
    BEFORE UPDATE ON subscription_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_payments_updated_at
    BEFORE UPDATE ON subscription_payments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_settlements_updated_at
    BEFORE UPDATE ON subscription_settlements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_subscription_reminders_updated_at
    BEFORE UPDATE ON subscription_reminders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to log payment activity
CREATE OR REPLACE FUNCTION log_subscription_payment_activity()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO subscription_activity_log (
        subscription_id, action, actor_id, payment_id, summary, details
    )
    VALUES (
        NEW.subscription_id,
        'payment_recorded',
        COALESCE(NEW.payer_profile_id, NEW.payer_contact_id),
        NEW.id,
        'Payment recorded: ' || NEW.currency || NEW.amount,
        jsonb_build_object('amount', NEW.amount, 'note', NEW.note)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_subscription_payment
    AFTER INSERT ON subscription_payments
    FOR EACH ROW EXECUTE FUNCTION log_subscription_payment_activity();

-- Trigger to log settlement activity
CREATE OR REPLACE FUNCTION log_subscription_settlement_activity()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO subscription_activity_log (
        subscription_id, action, actor_id, settlement_id, summary, details
    )
    VALUES (
        NEW.subscription_id,
        'settlement_recorded',
        COALESCE(NEW.from_profile_id, NEW.from_contact_id),
        NEW.id,
        'Settlement recorded: ' || NEW.currency || NEW.amount,
        jsonb_build_object(
            'amount', NEW.amount,
            'from', NEW.from_profile_id,
            'to', NEW.to_profile_id
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER log_subscription_settlement
    AFTER INSERT ON subscription_settlements
    FOR EACH ROW EXECUTE FUNCTION log_subscription_settlement_activity();

-- ============================================================================
-- ROW LEVEL SECURITY FOR SUBSCRIPTIONS
-- ============================================================================

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_activity_log ENABLE ROW LEVEL SECURITY;

-- Subscriptions: Owner and members can view
CREATE POLICY "Subscription participants can view"
    ON subscriptions FOR SELECT
    USING (
        owner_id = auth.uid()
        OR id IN (
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Subscriptions: Owner can create
CREATE POLICY "Users can create subscriptions"
    ON subscriptions FOR INSERT
    WITH CHECK (owner_id = auth.uid());

-- Subscriptions: Owner can update
CREATE POLICY "Owner can update subscription"
    ON subscriptions FOR UPDATE
    USING (owner_id = auth.uid());

-- Subscriptions: Owner can delete
CREATE POLICY "Owner can delete subscription"
    ON subscriptions FOR DELETE
    USING (owner_id = auth.uid());

-- Subscription members: Subscription participants can view
CREATE POLICY "Subscription participants can view members"
    ON subscription_members FOR SELECT
    USING (
        subscription_id IN (
            SELECT id FROM subscriptions WHERE owner_id = auth.uid()
            UNION
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Subscription members: Owner can manage
CREATE POLICY "Owner can manage subscription members"
    ON subscription_members FOR ALL
    USING (
        subscription_id IN (SELECT id FROM subscriptions WHERE owner_id = auth.uid())
    );

-- Subscription payments: Participants can view
CREATE POLICY "Subscription participants can view payments"
    ON subscription_payments FOR SELECT
    USING (
        subscription_id IN (
            SELECT id FROM subscriptions WHERE owner_id = auth.uid()
            UNION
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Subscription payments: Participants can create
CREATE POLICY "Subscription participants can record payments"
    ON subscription_payments FOR INSERT
    WITH CHECK (
        subscription_id IN (
            SELECT id FROM subscriptions WHERE owner_id = auth.uid()
            UNION
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Subscription settlements: Participants can view
CREATE POLICY "Subscription participants can view settlements"
    ON subscription_settlements FOR SELECT
    USING (
        subscription_id IN (
            SELECT id FROM subscriptions WHERE owner_id = auth.uid()
            UNION
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Subscription settlements: Participants can create
CREATE POLICY "Subscription participants can record settlements"
    ON subscription_settlements FOR INSERT
    WITH CHECK (
        subscription_id IN (
            SELECT id FROM subscriptions WHERE owner_id = auth.uid()
            UNION
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- Subscription reminders: Sender and recipient can view
CREATE POLICY "Reminder participants can view"
    ON subscription_reminders FOR SELECT
    USING (
        sender_id = auth.uid()
        OR to_profile_id = auth.uid()
    );

-- Subscription reminders: Participants can send
CREATE POLICY "Subscription participants can send reminders"
    ON subscription_reminders FOR INSERT
    WITH CHECK (sender_id = auth.uid());

-- Subscription reminders: Recipient can update (mark as read)
CREATE POLICY "Recipient can update reminder"
    ON subscription_reminders FOR UPDATE
    USING (to_profile_id = auth.uid());

-- Subscription notifications: User can view their own
CREATE POLICY "Users can view their notifications"
    ON subscription_notifications FOR SELECT
    USING (user_id = auth.uid());

-- Subscription activity log: Participants can view
CREATE POLICY "Subscription participants can view activity"
    ON subscription_activity_log FOR SELECT
    USING (
        subscription_id IN (
            SELECT id FROM subscriptions WHERE owner_id = auth.uid()
            UNION
            SELECT subscription_id FROM subscription_members
            WHERE member_profile_id = auth.uid() AND left_at IS NULL
        )
    );

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS
-- ============================================================================

ALTER PUBLICATION supabase_realtime ADD TABLE subscriptions;
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_payments;
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_settlements;
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_reminders;
ALTER PUBLICATION supabase_realtime ADD TABLE subscription_activity_log;

-- ============================================================================
-- VIEWS FOR SUBSCRIPTIONS
-- ============================================================================

-- View: Personal subscriptions with billing status
CREATE OR REPLACE VIEW personal_subscriptions_view AS
SELECT
    s.id,
    s.name,
    s.amount,
    s.currency,
    s.cycle,
    s.custom_cycle_days,
    s.next_billing_date,
    s.is_active,
    s.category,
    s.icon_name,
    s.color_hex,
    s.owner_id,
    s.created_at,
    get_billing_status(s.next_billing_date, s.is_active) as billing_status,
    s.next_billing_date - CURRENT_DATE as days_until_billing,
    calculate_monthly_equivalent(s.amount, s.cycle, s.custom_cycle_days) as monthly_equivalent
FROM subscriptions s
WHERE s.deleted_at IS NULL
  AND s.is_shared = false;

-- View: Shared subscriptions with member info
CREATE OR REPLACE VIEW shared_subscriptions_view AS
SELECT
    s.id,
    s.name,
    s.amount,
    s.currency,
    s.cycle,
    s.next_billing_date,
    s.is_active,
    s.category,
    s.icon_name,
    s.color_hex,
    s.owner_id,
    s.created_at,
    get_subscriber_count(s.id) as member_count,
    s.amount / get_subscriber_count(s.id) as per_member_share,
    calculate_monthly_equivalent(s.amount / get_subscriber_count(s.id), s.cycle, s.custom_cycle_days) as monthly_share
FROM subscriptions s
WHERE s.deleted_at IS NULL
  AND s.is_shared = true;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
