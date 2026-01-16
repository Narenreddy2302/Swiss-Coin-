-- ============================================================================
-- SWISS COIN - USER PROFILE & SETTINGS SCHEMA
-- Version: 1.0.0
-- Description: Complete user management, authentication, preferences, and settings
-- Features: Phone OTP auth, session management, granular settings, transaction categories
-- ============================================================================

-- ============================================================================
-- CUSTOM TYPES (ENUMS)
-- ============================================================================

-- Theme mode options
CREATE TYPE theme_mode AS ENUM (
    'light',          -- Light mode
    'dark',           -- Dark mode
    'system'          -- Follow system setting
);

-- Font size options
CREATE TYPE font_size AS ENUM (
    'small',          -- Smaller text
    'medium',         -- Default size
    'large',          -- Larger text
    'extra_large'     -- Extra large for accessibility
);

-- Notification frequency options
CREATE TYPE notification_frequency AS ENUM (
    'instant',        -- Send immediately
    'hourly',         -- Batch hourly
    'daily',          -- Daily digest
    'weekly',         -- Weekly summary
    'never'           -- Disabled
);

-- Privacy level for data sharing
CREATE TYPE privacy_level AS ENUM (
    'public',         -- Visible to all contacts
    'contacts_only',  -- Only visible to contacts
    'private'         -- Hidden from everyone
);

-- Session/device status
CREATE TYPE session_status AS ENUM (
    'active',         -- Currently active
    'expired',        -- Session expired
    'revoked'         -- Manually revoked
);

-- OTP purpose
CREATE TYPE otp_purpose AS ENUM (
    'phone_verification',  -- Verify phone number
    'login',               -- Login authentication
    'password_reset',      -- Reset password/PIN
    'sensitive_action'     -- Confirm sensitive action
);

-- Transaction category type
CREATE TYPE category_type AS ENUM (
    'expense',        -- Expense category
    'income',         -- Income category
    'both'            -- Can be used for both
);

-- ============================================================================
-- TABLE: user_settings
-- Description: Extended user preferences beyond basic profile
-- ============================================================================
CREATE TABLE user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to user profile
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

    -- Appearance Settings
    theme_mode theme_mode NOT NULL DEFAULT 'system',
    accent_color VARCHAR(7) NOT NULL DEFAULT '#34C759',       -- App accent color
    font_size font_size NOT NULL DEFAULT 'medium',
    reduce_motion BOOLEAN NOT NULL DEFAULT false,              -- Accessibility: reduce animations
    haptic_feedback_enabled BOOLEAN NOT NULL DEFAULT true,     -- Haptic feedback on/off

    -- Regional Settings (override profile defaults)
    date_format VARCHAR(20) DEFAULT 'MMM d, yyyy',             -- Date display format
    time_format VARCHAR(10) DEFAULT '12h',                     -- 12h or 24h
    week_starts_on SMALLINT DEFAULT 0,                         -- 0=Sunday, 1=Monday

    -- Dashboard Preferences
    default_home_tab VARCHAR(20) DEFAULT 'summary',            -- Default tab on home
    show_balance_on_home BOOLEAN NOT NULL DEFAULT true,        -- Show/hide balance
    default_split_method VARCHAR(20) DEFAULT 'equal',          -- Default split method

    -- Quick Action Preferences
    quick_action_favorites TEXT[],                             -- Array of favorite action IDs
    recent_payers UUID[],                                      -- Recently selected payers
    recent_groups UUID[],                                      -- Recently used groups

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_accent_color CHECK (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
    CONSTRAINT valid_week_start CHECK (week_starts_on >= 0 AND week_starts_on <= 6)
);

-- ============================================================================
-- TABLE: user_notification_settings
-- Description: Granular notification preferences per notification type
-- ============================================================================
CREATE TABLE user_notification_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to user profile
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

    -- Master Toggle
    all_notifications_enabled BOOLEAN NOT NULL DEFAULT true,

    -- Transaction Notifications
    new_expense_added BOOLEAN NOT NULL DEFAULT true,
    expense_modified BOOLEAN NOT NULL DEFAULT true,
    expense_deleted BOOLEAN NOT NULL DEFAULT true,
    someone_paid_you BOOLEAN NOT NULL DEFAULT true,

    -- Reminder Notifications
    payment_reminders BOOLEAN NOT NULL DEFAULT true,
    reminder_frequency notification_frequency NOT NULL DEFAULT 'instant',
    reminder_days_before SMALLINT NOT NULL DEFAULT 3,          -- Days before due date

    -- Subscription Notifications
    subscription_due_soon BOOLEAN NOT NULL DEFAULT true,
    subscription_due_days SMALLINT NOT NULL DEFAULT 3,         -- Days before billing
    subscription_overdue BOOLEAN NOT NULL DEFAULT true,
    subscription_paid BOOLEAN NOT NULL DEFAULT true,

    -- Settlement Notifications
    settlement_received BOOLEAN NOT NULL DEFAULT true,
    settlement_sent BOOLEAN NOT NULL DEFAULT true,

    -- Group Notifications
    added_to_group BOOLEAN NOT NULL DEFAULT true,
    removed_from_group BOOLEAN NOT NULL DEFAULT true,
    group_expense_added BOOLEAN NOT NULL DEFAULT true,

    -- Chat Notifications
    new_message BOOLEAN NOT NULL DEFAULT true,
    message_frequency notification_frequency NOT NULL DEFAULT 'instant',

    -- Summary Notifications
    weekly_summary BOOLEAN NOT NULL DEFAULT true,
    monthly_report BOOLEAN NOT NULL DEFAULT false,
    weekly_summary_day SMALLINT NOT NULL DEFAULT 0,            -- Day of week (0=Sunday)

    -- Quiet Hours
    quiet_hours_enabled BOOLEAN NOT NULL DEFAULT false,
    quiet_hours_start TIME DEFAULT '22:00',
    quiet_hours_end TIME DEFAULT '08:00',

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_reminder_days CHECK (reminder_days_before >= 1 AND reminder_days_before <= 30),
    CONSTRAINT valid_subscription_days CHECK (subscription_due_days >= 1 AND subscription_due_days <= 30),
    CONSTRAINT valid_summary_day CHECK (weekly_summary_day >= 0 AND weekly_summary_day <= 6)
);

-- ============================================================================
-- TABLE: user_privacy_settings
-- Description: Privacy and data sharing preferences
-- ============================================================================
CREATE TABLE user_privacy_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to user profile
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

    -- Profile Visibility
    profile_visibility privacy_level NOT NULL DEFAULT 'contacts_only',
    show_phone_number BOOLEAN NOT NULL DEFAULT false,          -- Show phone to contacts
    show_email BOOLEAN NOT NULL DEFAULT false,                 -- Show email to contacts
    show_full_name BOOLEAN NOT NULL DEFAULT true,              -- Show full name vs display name
    show_last_seen BOOLEAN NOT NULL DEFAULT true,              -- Show last active time
    show_profile_photo BOOLEAN NOT NULL DEFAULT true,          -- Show photo to others

    -- Balance & Financial Privacy
    show_balances_to_contacts BOOLEAN NOT NULL DEFAULT false,  -- Let contacts see mutual balance
    show_transaction_history BOOLEAN NOT NULL DEFAULT false,   -- Share transaction details

    -- Contact Discovery
    allow_contact_discovery BOOLEAN NOT NULL DEFAULT true,     -- Allow others to find you by phone
    sync_contacts_with_phone BOOLEAN NOT NULL DEFAULT true,    -- Sync phone contacts

    -- Data & Analytics
    allow_analytics BOOLEAN NOT NULL DEFAULT true,             -- Anonymous usage analytics
    allow_crash_reports BOOLEAN NOT NULL DEFAULT true,         -- Send crash reports
    personalized_suggestions BOOLEAN NOT NULL DEFAULT true,    -- AI-powered suggestions

    -- Account Data
    data_export_enabled BOOLEAN NOT NULL DEFAULT true,         -- Allow data export

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- TABLE: user_security_settings
-- Description: Security and authentication settings
-- ============================================================================
CREATE TABLE user_security_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to user profile
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

    -- PIN/Password
    pin_hash VARCHAR(255),                                     -- Hashed 6-digit PIN (optional)
    pin_enabled BOOLEAN NOT NULL DEFAULT false,
    pin_attempts_remaining SMALLINT DEFAULT 5,                 -- Lockout after 5 failed attempts
    pin_locked_until TIMESTAMPTZ,                              -- Lockout expiry time

    -- Biometric Authentication
    biometric_enabled BOOLEAN NOT NULL DEFAULT false,
    biometric_type VARCHAR(50),                                -- 'face_id', 'touch_id', 'fingerprint'
    biometric_registered_at TIMESTAMPTZ,

    -- Two-Factor Authentication
    two_factor_enabled BOOLEAN NOT NULL DEFAULT false,
    two_factor_method VARCHAR(20),                             -- 'sms', 'authenticator_app'
    two_factor_secret VARCHAR(255),                            -- Encrypted TOTP secret
    two_factor_backup_codes TEXT[],                            -- Encrypted backup codes
    two_factor_setup_at TIMESTAMPTZ,

    -- Session Security
    require_auth_for_sensitive_actions BOOLEAN NOT NULL DEFAULT true,
    auto_lock_timeout_minutes SMALLINT DEFAULT 5,              -- Auto-lock after X minutes
    logout_on_app_close BOOLEAN NOT NULL DEFAULT false,
    single_session_only BOOLEAN NOT NULL DEFAULT false,        -- Only one device at a time

    -- Login Security
    max_login_attempts SMALLINT NOT NULL DEFAULT 5,
    login_lockout_minutes SMALLINT NOT NULL DEFAULT 30,
    notify_on_new_device BOOLEAN NOT NULL DEFAULT true,
    notify_on_suspicious_activity BOOLEAN NOT NULL DEFAULT true,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_pin_attempts CHECK (pin_attempts_remaining >= 0 AND pin_attempts_remaining <= 10),
    CONSTRAINT valid_auto_lock CHECK (auto_lock_timeout_minutes >= 1 AND auto_lock_timeout_minutes <= 60),
    CONSTRAINT valid_max_attempts CHECK (max_login_attempts >= 3 AND max_login_attempts <= 10)
);

-- ============================================================================
-- TABLE: user_sessions
-- Description: Active device sessions for the user
-- ============================================================================
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to user profile
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Session Token (hashed for security)
    session_token_hash VARCHAR(255) NOT NULL UNIQUE,
    refresh_token_hash VARCHAR(255),

    -- Device Information
    device_id VARCHAR(255),                                    -- Unique device identifier
    device_name VARCHAR(100),                                  -- "iPhone 15 Pro", "iPad Air"
    device_type VARCHAR(50),                                   -- 'iphone', 'ipad', 'android'
    device_model VARCHAR(100),                                 -- Specific model
    os_version VARCHAR(50),                                    -- "iOS 17.2"
    app_version VARCHAR(20),                                   -- "1.2.3"

    -- Location (approximate, for security display)
    ip_address INET,
    location_city VARCHAR(100),
    location_country VARCHAR(100),
    location_country_code VARCHAR(2),

    -- Session Status
    status session_status NOT NULL DEFAULT 'active',

    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,

    -- Metadata
    is_current_session BOOLEAN NOT NULL DEFAULT false,         -- Flag for current device
    trusted_device BOOLEAN NOT NULL DEFAULT false,             -- User marked as trusted

    -- Index for faster lookups
    CONSTRAINT valid_device_type CHECK (device_type IN ('iphone', 'ipad', 'android', 'web', 'other'))
);

-- Index for session lookups
CREATE INDEX idx_user_sessions_user ON user_sessions(user_id, status);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token_hash);
CREATE INDEX idx_user_sessions_device ON user_sessions(user_id, device_id);

-- ============================================================================
-- TABLE: login_history
-- Description: Audit log of all login attempts
-- ============================================================================
CREATE TABLE login_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- User (may be null for failed attempts with invalid phone)
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    phone_number VARCHAR(20),                                  -- Phone used for attempt

    -- Attempt Details
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(100),                               -- 'invalid_otp', 'account_locked', etc.
    auth_method VARCHAR(50),                                   -- 'otp', 'biometric', 'pin'

    -- Device/Location Info
    device_id VARCHAR(255),
    device_name VARCHAR(100),
    device_type VARCHAR(50),
    ip_address INET,
    user_agent TEXT,
    location_city VARCHAR(100),
    location_country VARCHAR(100),

    -- Risk Assessment
    is_suspicious BOOLEAN NOT NULL DEFAULT false,
    risk_score SMALLINT DEFAULT 0,                             -- 0-100 risk score
    risk_factors TEXT[],                                       -- Array of risk factors

    -- Timestamp
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Session created (if successful)
    session_id UUID REFERENCES user_sessions(id) ON DELETE SET NULL
);

-- Index for security monitoring
CREATE INDEX idx_login_history_user ON login_history(user_id, attempted_at DESC);
CREATE INDEX idx_login_history_phone ON login_history(phone_number, attempted_at DESC);
CREATE INDEX idx_login_history_suspicious ON login_history(is_suspicious, attempted_at DESC);

-- ============================================================================
-- TABLE: otp_codes
-- Description: One-time password codes for phone verification
-- ============================================================================
CREATE TABLE otp_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Target
    phone_number VARCHAR(20) NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,

    -- OTP Details
    code_hash VARCHAR(255) NOT NULL,                           -- Hashed 6-digit code
    purpose otp_purpose NOT NULL,

    -- Attempt Tracking
    attempts_remaining SMALLINT NOT NULL DEFAULT 3,

    -- Validity
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,

    -- Metadata
    ip_address INET,
    device_id VARCHAR(255),

    -- Constraints
    CONSTRAINT valid_otp_attempts CHECK (attempts_remaining >= 0 AND attempts_remaining <= 5)
);

-- Index for OTP lookups
CREATE INDEX idx_otp_phone ON otp_codes(phone_number, purpose, expires_at);

-- Cleanup function for expired OTPs
CREATE OR REPLACE FUNCTION cleanup_expired_otps()
RETURNS void AS $$
BEGIN
    DELETE FROM otp_codes WHERE expires_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TABLE: blocked_users
-- Description: Users blocked by the current user
-- ============================================================================
CREATE TABLE blocked_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Blocker (current user)
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Blocked user
    blocked_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Reason (optional)
    reason TEXT,

    -- Timestamps
    blocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT no_self_block CHECK (user_id != blocked_user_id),
    CONSTRAINT unique_block UNIQUE (user_id, blocked_user_id)
);

-- Index for block lookups
CREATE INDEX idx_blocked_users_user ON blocked_users(user_id);
CREATE INDEX idx_blocked_users_blocked ON blocked_users(blocked_user_id);

-- ============================================================================
-- TABLE: transaction_categories
-- Description: Transaction categories (system defaults + user custom)
-- ============================================================================
CREATE TABLE transaction_categories (
    id VARCHAR(50) PRIMARY KEY,                                -- Unique identifier

    -- Category Info
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(20) NOT NULL,                                 -- Emoji icon
    color_hex VARCHAR(7) NOT NULL,                             -- Category color

    -- Type
    category_type category_type NOT NULL DEFAULT 'both',

    -- Ownership
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,    -- NULL = system category
    is_system BOOLEAN NOT NULL DEFAULT false,                  -- System categories can't be deleted

    -- Display
    display_order SMALLINT NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_category_color CHECK (color_hex ~ '^#[0-9A-Fa-f]{6}$')
);

-- Insert default system categories
INSERT INTO transaction_categories (id, name, icon, color_hex, category_type, is_system, display_order) VALUES
    ('food', 'Food & Drinks', '🍽️', '#FF9500', 'expense', true, 1),
    ('transport', 'Transport', '🚗', '#007AFF', 'expense', true, 2),
    ('shopping', 'Shopping', '🛍️', '#FF2D55', 'expense', true, 3),
    ('entertainment', 'Entertainment', '🎬', '#AF52DE', 'expense', true, 4),
    ('bills', 'Bills', '📄', '#5856D6', 'expense', true, 5),
    ('health', 'Health', '💊', '#FF3B30', 'expense', true, 6),
    ('travel', 'Travel', '✈️', '#34C759', 'expense', true, 7),
    ('groceries', 'Groceries', '🛒', '#00C7BE', 'expense', true, 8),
    ('utilities', 'Utilities', '💡', '#FF9F0A', 'expense', true, 9),
    ('rent', 'Rent', '🏠', '#64D2FF', 'expense', true, 10),
    ('salary', 'Salary', '💰', '#30D158', 'income', true, 11),
    ('freelance', 'Freelance', '💻', '#32ADE6', 'income', true, 12),
    ('refund', 'Refund', '↩️', '#BF5AF2', 'income', true, 13),
    ('gift', 'Gift', '🎁', '#FF375F', 'both', true, 14),
    ('other', 'Other', '📦', '#8E8E93', 'both', true, 99);

-- ============================================================================
-- ALTER TABLE: transactions
-- Description: Add category field to existing transactions table
-- ============================================================================
ALTER TABLE transactions
    ADD COLUMN IF NOT EXISTS category_id VARCHAR(50) REFERENCES transaction_categories(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS receipt_url TEXT,
    ADD COLUMN IF NOT EXISTS location_name VARCHAR(200),
    ADD COLUMN IF NOT EXISTS location_lat DECIMAL(10, 8),
    ADD COLUMN IF NOT EXISTS location_lng DECIMAL(11, 8);

-- Index for category lookups
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);

-- ============================================================================
-- FUNCTIONS: User Settings Management
-- ============================================================================

-- Function to create default settings for a new user
CREATE OR REPLACE FUNCTION create_user_default_settings()
RETURNS TRIGGER AS $$
BEGIN
    -- Create default user_settings
    INSERT INTO user_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    -- Create default notification_settings
    INSERT INTO user_notification_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    -- Create default privacy_settings
    INSERT INTO user_privacy_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    -- Create default security_settings
    INSERT INTO user_security_settings (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-create settings when user is created
DROP TRIGGER IF EXISTS trigger_create_user_settings ON profiles;
CREATE TRIGGER trigger_create_user_settings
    AFTER INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION create_user_default_settings();

-- ============================================================================
-- FUNCTION: Get complete user profile with all settings
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_profile_complete(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'profile', row_to_json(p.*),
        'settings', row_to_json(us.*),
        'notification_settings', row_to_json(uns.*),
        'privacy_settings', row_to_json(ups.*),
        'security_settings', json_build_object(
            'pin_enabled', uss.pin_enabled,
            'biometric_enabled', uss.biometric_enabled,
            'biometric_type', uss.biometric_type,
            'two_factor_enabled', uss.two_factor_enabled,
            'two_factor_method', uss.two_factor_method,
            'require_auth_for_sensitive_actions', uss.require_auth_for_sensitive_actions,
            'auto_lock_timeout_minutes', uss.auto_lock_timeout_minutes
        ),
        'active_sessions_count', (
            SELECT COUNT(*) FROM user_sessions
            WHERE user_id = p_user_id AND status = 'active'
        )
    )
    INTO v_result
    FROM profiles p
    LEFT JOIN user_settings us ON us.user_id = p.id
    LEFT JOIN user_notification_settings uns ON uns.user_id = p.id
    LEFT JOIN user_privacy_settings ups ON ups.user_id = p.id
    LEFT JOIN user_security_settings uss ON uss.user_id = p.id
    WHERE p.id = p_user_id AND p.deleted_at IS NULL;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Update user settings
-- ============================================================================
CREATE OR REPLACE FUNCTION update_user_settings(
    p_user_id UUID,
    p_settings JSONB
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    UPDATE user_settings
    SET
        theme_mode = COALESCE((p_settings->>'theme_mode')::theme_mode, theme_mode),
        accent_color = COALESCE(p_settings->>'accent_color', accent_color),
        font_size = COALESCE((p_settings->>'font_size')::font_size, font_size),
        reduce_motion = COALESCE((p_settings->>'reduce_motion')::boolean, reduce_motion),
        haptic_feedback_enabled = COALESCE((p_settings->>'haptic_feedback_enabled')::boolean, haptic_feedback_enabled),
        date_format = COALESCE(p_settings->>'date_format', date_format),
        time_format = COALESCE(p_settings->>'time_format', time_format),
        week_starts_on = COALESCE((p_settings->>'week_starts_on')::smallint, week_starts_on),
        default_home_tab = COALESCE(p_settings->>'default_home_tab', default_home_tab),
        show_balance_on_home = COALESCE((p_settings->>'show_balance_on_home')::boolean, show_balance_on_home),
        default_split_method = COALESCE(p_settings->>'default_split_method', default_split_method),
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING row_to_json(user_settings.*) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Verify OTP code
-- ============================================================================
CREATE OR REPLACE FUNCTION verify_otp(
    p_phone_number VARCHAR(20),
    p_code VARCHAR(6),
    p_purpose otp_purpose
)
RETURNS JSON AS $$
DECLARE
    v_otp_record RECORD;
    v_code_hash VARCHAR(255);
BEGIN
    -- Hash the provided code for comparison
    v_code_hash := encode(digest(p_code, 'sha256'), 'hex');

    -- Find valid OTP
    SELECT * INTO v_otp_record
    FROM otp_codes
    WHERE phone_number = p_phone_number
      AND purpose = p_purpose
      AND expires_at > NOW()
      AND used_at IS NULL
      AND attempts_remaining > 0
    ORDER BY created_at DESC
    LIMIT 1;

    -- No valid OTP found
    IF v_otp_record.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'invalid_or_expired_otp'
        );
    END IF;

    -- Check if code matches
    IF v_otp_record.code_hash != v_code_hash THEN
        -- Decrement attempts
        UPDATE otp_codes
        SET attempts_remaining = attempts_remaining - 1
        WHERE id = v_otp_record.id;

        RETURN json_build_object(
            'success', false,
            'error', 'incorrect_code',
            'attempts_remaining', v_otp_record.attempts_remaining - 1
        );
    END IF;

    -- Mark as used
    UPDATE otp_codes
    SET used_at = NOW()
    WHERE id = v_otp_record.id;

    RETURN json_build_object(
        'success', true,
        'user_id', v_otp_record.user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Create or get session
-- ============================================================================
CREATE OR REPLACE FUNCTION create_session(
    p_user_id UUID,
    p_device_id VARCHAR(255),
    p_device_name VARCHAR(100),
    p_device_type VARCHAR(50),
    p_os_version VARCHAR(50),
    p_app_version VARCHAR(20),
    p_ip_address INET DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_session_token VARCHAR(64);
    v_refresh_token VARCHAR(64);
    v_session_id UUID;
    v_security_settings RECORD;
BEGIN
    -- Get user security settings
    SELECT * INTO v_security_settings
    FROM user_security_settings
    WHERE user_id = p_user_id;

    -- If single session only, revoke existing sessions
    IF v_security_settings.single_session_only THEN
        UPDATE user_sessions
        SET status = 'revoked', revoked_at = NOW()
        WHERE user_id = p_user_id AND status = 'active';
    END IF;

    -- Generate tokens
    v_session_token := encode(gen_random_bytes(32), 'hex');
    v_refresh_token := encode(gen_random_bytes(32), 'hex');

    -- Create session
    INSERT INTO user_sessions (
        user_id,
        session_token_hash,
        refresh_token_hash,
        device_id,
        device_name,
        device_type,
        os_version,
        app_version,
        ip_address,
        expires_at,
        is_current_session
    )
    VALUES (
        p_user_id,
        encode(digest(v_session_token, 'sha256'), 'hex'),
        encode(digest(v_refresh_token, 'sha256'), 'hex'),
        p_device_id,
        p_device_name,
        p_device_type,
        p_os_version,
        p_app_version,
        p_ip_address,
        NOW() + INTERVAL '30 days',
        true
    )
    RETURNING id INTO v_session_id;

    -- Update last seen
    UPDATE profiles
    SET last_seen_at = NOW(), updated_at = NOW()
    WHERE id = p_user_id;

    RETURN json_build_object(
        'session_id', v_session_id,
        'session_token', v_session_token,
        'refresh_token', v_refresh_token,
        'expires_at', NOW() + INTERVAL '30 days'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Revoke session
-- ============================================================================
CREATE OR REPLACE FUNCTION revoke_session(
    p_user_id UUID,
    p_session_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE user_sessions
    SET status = 'revoked', revoked_at = NOW()
    WHERE id = p_session_id AND user_id = p_user_id;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Revoke all sessions except current
-- ============================================================================
CREATE OR REPLACE FUNCTION revoke_all_other_sessions(
    p_user_id UUID,
    p_current_session_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE user_sessions
    SET status = 'revoked', revoked_at = NOW()
    WHERE user_id = p_user_id
      AND id != p_current_session_id
      AND status = 'active';

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Get user's active sessions
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_sessions(p_user_id UUID)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'id', id,
                'device_name', device_name,
                'device_type', device_type,
                'os_version', os_version,
                'app_version', app_version,
                'location_city', location_city,
                'location_country', location_country,
                'is_current_session', is_current_session,
                'trusted_device', trusted_device,
                'last_active_at', last_active_at,
                'created_at', created_at
            )
            ORDER BY is_current_session DESC, last_active_at DESC
        )
        FROM user_sessions
        WHERE user_id = p_user_id AND status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Get user's custom categories
-- ============================================================================
CREATE OR REPLACE FUNCTION get_user_categories(p_user_id UUID)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_agg(
            json_build_object(
                'id', id,
                'name', name,
                'icon', icon,
                'color_hex', color_hex,
                'category_type', category_type,
                'is_system', is_system,
                'display_order', display_order
            )
            ORDER BY is_system DESC, display_order ASC
        )
        FROM transaction_categories
        WHERE (user_id = p_user_id OR is_system = true) AND is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_privacy_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_security_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE login_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE otp_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaction_categories ENABLE ROW LEVEL SECURITY;

-- user_settings policies
CREATE POLICY "Users can view own settings"
    ON user_settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own settings"
    ON user_settings FOR UPDATE
    USING (user_id = auth.uid());

-- user_notification_settings policies
CREATE POLICY "Users can view own notification settings"
    ON user_notification_settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own notification settings"
    ON user_notification_settings FOR UPDATE
    USING (user_id = auth.uid());

-- user_privacy_settings policies
CREATE POLICY "Users can view own privacy settings"
    ON user_privacy_settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own privacy settings"
    ON user_privacy_settings FOR UPDATE
    USING (user_id = auth.uid());

-- user_security_settings policies
CREATE POLICY "Users can view own security settings"
    ON user_security_settings FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can update own security settings"
    ON user_security_settings FOR UPDATE
    USING (user_id = auth.uid());

-- user_sessions policies
CREATE POLICY "Users can view own sessions"
    ON user_sessions FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own sessions"
    ON user_sessions FOR ALL
    USING (user_id = auth.uid());

-- login_history policies (read-only for users)
CREATE POLICY "Users can view own login history"
    ON login_history FOR SELECT
    USING (user_id = auth.uid());

-- blocked_users policies
CREATE POLICY "Users can view own blocked list"
    ON blocked_users FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own blocked list"
    ON blocked_users FOR ALL
    USING (user_id = auth.uid());

-- transaction_categories policies
CREATE POLICY "Users can view system and own categories"
    ON transaction_categories FOR SELECT
    USING (is_system = true OR user_id = auth.uid());

CREATE POLICY "Users can manage own categories"
    ON transaction_categories FOR ALL
    USING (user_id = auth.uid() AND is_system = false);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_user_settings_user ON user_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notification_settings_user ON user_notification_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_privacy_settings_user ON user_privacy_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_user_security_settings_user ON user_security_settings(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_categories_user ON transaction_categories(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_transaction_categories_system ON transaction_categories(is_system) WHERE is_system = true;

-- ============================================================================
-- ENABLE REALTIME
-- ============================================================================
ALTER PUBLICATION supabase_realtime ADD TABLE user_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE user_notification_settings;
ALTER PUBLICATION supabase_realtime ADD TABLE user_sessions;

-- ============================================================================
-- UPDATED_AT TRIGGERS
-- ============================================================================
CREATE TRIGGER set_updated_at_user_settings
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at_user_notification_settings
    BEFORE UPDATE ON user_notification_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at_user_privacy_settings
    BEFORE UPDATE ON user_privacy_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at_user_security_settings
    BEFORE UPDATE ON user_security_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_updated_at_transaction_categories
    BEFORE UPDATE ON transaction_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- GRANT PERMISSIONS (for Supabase Auth integration)
-- ============================================================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
