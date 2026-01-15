-- ============================================================================
-- SWISS COIN - PEOPLE PAGE DATABASE SCHEMA
-- Version: 1.0.0
-- Description: Chat messages, reactions, and People page specific features
-- Features: Two-way chat, Delivery/Read receipts, Edit/Delete, Reply, Reactions
-- ============================================================================

-- ============================================================================
-- CUSTOM TYPES (ENUMS)
-- ============================================================================

-- Message delivery status
CREATE TYPE message_status AS ENUM (
    'sending',         -- Message is being sent
    'sent',            -- Message sent to server
    'delivered',       -- Message delivered to recipient's device
    'read',            -- Message read by recipient
    'failed'           -- Message failed to send
);

-- Message type for different content types
CREATE TYPE message_type AS ENUM (
    'text',            -- Regular text message
    'image',           -- Image attachment
    'system',          -- System message (e.g., "User joined")
    'expense_share',   -- Shared expense notification
    'settlement_request', -- Settlement request
    'payment_confirmation' -- Payment confirmed
);

-- ============================================================================
-- TABLE: chat_messages
-- Description: Two-way chat messages between users
-- ============================================================================
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Message content
    content TEXT NOT NULL,                                    -- Message text
    message_type message_type NOT NULL DEFAULT 'text',        -- Type of message

    -- Sender and conversation context
    sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Conversation context (one of these must be set)
    -- For 1-on-1 chats: recipient_profile_id or recipient_contact_id
    -- For group chats: group_id
    recipient_profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    recipient_contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
    group_id UUID REFERENCES user_groups(id) ON DELETE CASCADE,

    -- Reply support (for threaded replies)
    reply_to_message_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,

    -- Delivery and read status
    status message_status NOT NULL DEFAULT 'sent',
    delivered_at TIMESTAMPTZ,                                 -- When delivered to recipient
    read_at TIMESTAMPTZ,                                      -- When read by recipient

    -- Edit support
    is_edited BOOLEAN NOT NULL DEFAULT false,
    edited_at TIMESTAMPTZ,                                    -- When last edited
    original_content TEXT,                                    -- Original content before edit
    edit_history JSONB DEFAULT '[]'::jsonb,                   -- Array of {content, edited_at}

    -- Attachments (for future use)
    attachments JSONB DEFAULT '[]'::jsonb,                    -- Array of {url, type, size, name}

    -- Metadata
    metadata JSONB DEFAULT '{}'::jsonb,                       -- Additional metadata

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,                                   -- Soft delete

    -- Constraints
    CONSTRAINT valid_conversation_context CHECK (
        -- Must have exactly one context
        (recipient_profile_id IS NOT NULL AND recipient_contact_id IS NULL AND group_id IS NULL) OR
        (recipient_profile_id IS NULL AND recipient_contact_id IS NOT NULL AND group_id IS NULL) OR
        (recipient_profile_id IS NULL AND recipient_contact_id IS NULL AND group_id IS NOT NULL)
    ),
    CONSTRAINT sender_not_recipient CHECK (
        sender_id != recipient_profile_id
    ),
    CONSTRAINT content_not_empty CHECK (
        LENGTH(TRIM(content)) > 0
    )
);

-- ============================================================================
-- TABLE: message_reactions
-- Description: Emoji reactions to messages
-- ============================================================================
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    reactor_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Reaction emoji (e.g., "👍", "❤️", "😂")
    emoji VARCHAR(10) NOT NULL,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One reaction per emoji per user per message
    CONSTRAINT unique_reaction UNIQUE (message_id, reactor_id, emoji)
);

-- ============================================================================
-- TABLE: message_read_receipts
-- Description: Track read status for group messages (per member)
-- ============================================================================
CREATE TABLE message_read_receipts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    reader_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One receipt per reader per message
    CONSTRAINT unique_read_receipt UNIQUE (message_id, reader_id)
);

-- ============================================================================
-- TABLE: typing_indicators
-- Description: Track who is currently typing (ephemeral data)
-- ============================================================================
CREATE TABLE typing_indicators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Who is typing
    typer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Where they are typing (conversation context)
    recipient_profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    group_id UUID REFERENCES user_groups(id) ON DELETE CASCADE,

    -- When they started typing (auto-expire after 10 seconds)
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_typing_context CHECK (
        (recipient_profile_id IS NOT NULL AND group_id IS NULL) OR
        (recipient_profile_id IS NULL AND group_id IS NOT NULL)
    ),
    CONSTRAINT unique_typing_indicator UNIQUE (typer_id, recipient_profile_id, group_id)
);

-- ============================================================================
-- TABLE: conversation_settings
-- Description: Per-conversation settings (mute, pin, archive)
-- ============================================================================
CREATE TABLE conversation_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Owner of these settings
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Conversation context (one of these)
    contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
    group_id UUID REFERENCES user_groups(id) ON DELETE CASCADE,

    -- Settings
    is_muted BOOLEAN NOT NULL DEFAULT false,
    muted_until TIMESTAMPTZ,                                  -- Mute until specific time
    is_pinned BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,

    -- Notification settings
    notification_sound VARCHAR(50) DEFAULT 'default',
    show_previews BOOLEAN NOT NULL DEFAULT true,

    -- Last read position
    last_read_message_id UUID REFERENCES chat_messages(id) ON DELETE SET NULL,
    last_read_at TIMESTAMPTZ,

    -- Audit fields
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_settings_context CHECK (
        (contact_id IS NOT NULL AND group_id IS NULL) OR
        (contact_id IS NULL AND group_id IS NOT NULL)
    ),
    CONSTRAINT unique_conversation_settings UNIQUE (owner_id, contact_id, group_id)
);

-- ============================================================================
-- INDEXES FOR CHAT PERFORMANCE
-- ============================================================================

-- Chat messages indexes
CREATE INDEX idx_messages_sender ON chat_messages(sender_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_messages_recipient_profile ON chat_messages(recipient_profile_id) WHERE recipient_profile_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_messages_recipient_contact ON chat_messages(recipient_contact_id) WHERE recipient_contact_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_messages_group ON chat_messages(group_id) WHERE group_id IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_messages_created ON chat_messages(created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_messages_reply ON chat_messages(reply_to_message_id) WHERE reply_to_message_id IS NOT NULL;
CREATE INDEX idx_messages_unread ON chat_messages(recipient_profile_id, status) WHERE status != 'read' AND deleted_at IS NULL;

-- Composite index for 1-on-1 conversation queries (both directions)
CREATE INDEX idx_messages_conversation ON chat_messages(
    LEAST(sender_id, recipient_profile_id),
    GREATEST(sender_id, recipient_profile_id),
    created_at DESC
) WHERE recipient_profile_id IS NOT NULL AND deleted_at IS NULL;

-- Message reactions indexes
CREATE INDEX idx_reactions_message ON message_reactions(message_id);
CREATE INDEX idx_reactions_reactor ON message_reactions(reactor_id);

-- Read receipts indexes
CREATE INDEX idx_read_receipts_message ON message_read_receipts(message_id);
CREATE INDEX idx_read_receipts_reader ON message_read_receipts(reader_id);

-- Typing indicators (need fast lookup)
CREATE INDEX idx_typing_recipient ON typing_indicators(recipient_profile_id) WHERE recipient_profile_id IS NOT NULL;
CREATE INDEX idx_typing_group ON typing_indicators(group_id) WHERE group_id IS NOT NULL;

-- Conversation settings indexes
CREATE INDEX idx_settings_owner ON conversation_settings(owner_id);
CREATE INDEX idx_settings_pinned ON conversation_settings(owner_id) WHERE is_pinned = true;
CREATE INDEX idx_settings_archived ON conversation_settings(owner_id) WHERE is_archived = true;

-- ============================================================================
-- ADDITIONAL INDEXES FOR PEOPLE PAGE QUERIES
-- ============================================================================

-- Index for finding people with balance (transactions or settlements)
CREATE INDEX idx_transactions_participants ON transactions(created_by, payer_profile_id) WHERE deleted_at IS NULL;

-- Index for settlements between two people
CREATE INDEX idx_settlements_parties ON settlements(from_profile_id, to_profile_id) WHERE deleted_at IS NULL;

-- Index for reminders
CREATE INDEX idx_reminders_recipient ON reminders(to_profile_id) WHERE to_profile_id IS NOT NULL AND deleted_at IS NULL;

-- ============================================================================
-- FUNCTIONS FOR CHAT
-- ============================================================================

-- Function to get conversation messages between two users
CREATE OR REPLACE FUNCTION get_conversation_messages(
    user1_id UUID,
    user2_id UUID,
    limit_count INTEGER DEFAULT 50,
    before_timestamp TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    content TEXT,
    message_type message_type,
    sender_id UUID,
    status message_status,
    is_edited BOOLEAN,
    reply_to_message_id UUID,
    reactions JSONB,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.content,
        m.message_type,
        m.sender_id,
        m.status,
        m.is_edited,
        m.reply_to_message_id,
        COALESCE(
            (SELECT jsonb_agg(jsonb_build_object('emoji', r.emoji, 'reactor_id', r.reactor_id))
             FROM message_reactions r WHERE r.message_id = m.id),
            '[]'::jsonb
        ) as reactions,
        m.created_at
    FROM chat_messages m
    WHERE m.deleted_at IS NULL
      AND (
          (m.sender_id = user1_id AND m.recipient_profile_id = user2_id) OR
          (m.sender_id = user2_id AND m.recipient_profile_id = user1_id)
      )
      AND (before_timestamp IS NULL OR m.created_at < before_timestamp)
    ORDER BY m.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get unread message count for a user
CREATE OR REPLACE FUNCTION get_unread_count(user_id UUID)
RETURNS TABLE (
    conversation_id UUID,
    conversation_type TEXT,
    unread_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    -- 1-on-1 conversations
    SELECT
        m.sender_id as conversation_id,
        'profile'::TEXT as conversation_type,
        COUNT(*) as unread_count
    FROM chat_messages m
    WHERE m.recipient_profile_id = user_id
      AND m.status != 'read'
      AND m.deleted_at IS NULL
    GROUP BY m.sender_id

    UNION ALL

    -- Group conversations
    SELECT
        m.group_id as conversation_id,
        'group'::TEXT as conversation_type,
        COUNT(*) as unread_count
    FROM chat_messages m
    LEFT JOIN message_read_receipts rr ON rr.message_id = m.id AND rr.reader_id = user_id
    WHERE m.group_id IS NOT NULL
      AND m.sender_id != user_id
      AND rr.id IS NULL
      AND m.deleted_at IS NULL
    GROUP BY m.group_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to mark messages as read
CREATE OR REPLACE FUNCTION mark_messages_read(
    reader_id UUID,
    sender_id UUID DEFAULT NULL,
    group_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    IF sender_id IS NOT NULL THEN
        -- 1-on-1 conversation
        UPDATE chat_messages
        SET status = 'read',
            read_at = NOW(),
            updated_at = NOW()
        WHERE recipient_profile_id = reader_id
          AND chat_messages.sender_id = mark_messages_read.sender_id
          AND status != 'read'
          AND deleted_at IS NULL;

        GET DIAGNOSTICS updated_count = ROW_COUNT;

    ELSIF group_id IS NOT NULL THEN
        -- Group conversation - insert read receipts
        INSERT INTO message_read_receipts (message_id, reader_id, read_at)
        SELECT m.id, mark_messages_read.reader_id, NOW()
        FROM chat_messages m
        WHERE m.group_id = mark_messages_read.group_id
          AND m.sender_id != mark_messages_read.reader_id
          AND m.deleted_at IS NULL
          AND NOT EXISTS (
              SELECT 1 FROM message_read_receipts rr
              WHERE rr.message_id = m.id AND rr.reader_id = mark_messages_read.reader_id
          )
        ON CONFLICT DO NOTHING;

        GET DIAGNOSTICS updated_count = ROW_COUNT;
    END IF;

    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to edit a message
CREATE OR REPLACE FUNCTION edit_message(
    message_id UUID,
    editor_id UUID,
    new_content TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    old_content TEXT;
    old_edit_history JSONB;
BEGIN
    -- Get current content and validate ownership
    SELECT content, edit_history INTO old_content, old_edit_history
    FROM chat_messages
    WHERE id = message_id
      AND sender_id = editor_id
      AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Update message with edit history
    UPDATE chat_messages
    SET content = new_content,
        is_edited = TRUE,
        edited_at = NOW(),
        original_content = COALESCE(original_content, old_content),
        edit_history = old_edit_history || jsonb_build_object(
            'content', old_content,
            'edited_at', NOW()
        ),
        updated_at = NOW()
    WHERE id = message_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to toggle reaction on a message
CREATE OR REPLACE FUNCTION toggle_reaction(
    p_message_id UUID,
    p_reactor_id UUID,
    p_emoji VARCHAR(10)
)
RETURNS BOOLEAN AS $$
DECLARE
    existing_id UUID;
BEGIN
    -- Check if reaction exists
    SELECT id INTO existing_id
    FROM message_reactions
    WHERE message_id = p_message_id
      AND reactor_id = p_reactor_id
      AND emoji = p_emoji;

    IF existing_id IS NOT NULL THEN
        -- Remove reaction
        DELETE FROM message_reactions WHERE id = existing_id;
        RETURN FALSE; -- Reaction removed
    ELSE
        -- Add reaction
        INSERT INTO message_reactions (message_id, reactor_id, emoji)
        VALUES (p_message_id, p_reactor_id, p_emoji);
        RETURN TRUE; -- Reaction added
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate balance between two people (enhanced version)
CREATE OR REPLACE FUNCTION calculate_person_balance(
    current_user_id UUID,
    other_person_id UUID
)
RETURNS TABLE (
    total_balance DECIMAL(15, 2),
    you_owe DECIMAL(15, 2),
    they_owe DECIMAL(15, 2),
    pending_settlements DECIMAL(15, 2),
    transaction_count INTEGER,
    settlement_count INTEGER
) AS $$
DECLARE
    v_you_owe DECIMAL(15, 2) := 0;
    v_they_owe DECIMAL(15, 2) := 0;
    v_settlements_received DECIMAL(15, 2) := 0;
    v_settlements_sent DECIMAL(15, 2) := 0;
    v_transaction_count INTEGER := 0;
    v_settlement_count INTEGER := 0;
BEGIN
    -- Calculate what you owe them (from transactions they paid where you have a split)
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0), COUNT(DISTINCT t.id)
    INTO v_you_owe, v_transaction_count
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE ts.owed_by_profile_id = current_user_id
      AND t.payer_profile_id = other_person_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Calculate what they owe you (from transactions you paid where they have a split)
    SELECT COALESCE(SUM(ts.amount - ts.amount_settled), 0), v_transaction_count + COUNT(DISTINCT t.id)
    INTO v_they_owe, v_transaction_count
    FROM transaction_splits ts
    JOIN transactions t ON t.id = ts.transaction_id
    WHERE ts.owed_by_profile_id = other_person_id
      AND t.payer_profile_id = current_user_id
      AND t.deleted_at IS NULL
      AND ts.is_settled = false;

    -- Get settlements they sent to you
    SELECT COALESCE(SUM(amount), 0), COUNT(*)
    INTO v_settlements_received, v_settlement_count
    FROM settlements
    WHERE from_profile_id = other_person_id
      AND to_profile_id = current_user_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    -- Get settlements you sent to them
    SELECT COALESCE(SUM(amount), 0), v_settlement_count + COUNT(*)
    INTO v_settlements_sent, v_settlement_count
    FROM settlements
    WHERE from_profile_id = current_user_id
      AND to_profile_id = other_person_id
      AND status = 'completed'
      AND deleted_at IS NULL;

    RETURN QUERY SELECT
        (v_they_owe - v_you_owe) + (v_settlements_sent - v_settlements_received) as total_balance,
        v_you_owe as you_owe,
        v_they_owe as they_owe,
        (SELECT COALESCE(SUM(amount), 0) FROM settlements
         WHERE ((from_profile_id = current_user_id AND to_profile_id = other_person_id) OR
                (from_profile_id = other_person_id AND to_profile_id = current_user_id))
           AND status = 'pending' AND deleted_at IS NULL) as pending_settlements,
        v_transaction_count as transaction_count,
        v_settlement_count as settlement_count;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get people with balances for People list
CREATE OR REPLACE FUNCTION get_people_with_balances(user_id UUID)
RETURNS TABLE (
    contact_id UUID,
    profile_id UUID,
    display_name VARCHAR(100),
    phone_number VARCHAR(20),
    avatar_url TEXT,
    color_hex VARCHAR(7),
    balance DECIMAL(15, 2),
    last_activity_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    WITH contact_balances AS (
        -- Get all contacts with their linked profiles
        SELECT
            c.id as contact_id,
            c.linked_profile_id as profile_id,
            c.display_name,
            c.phone_number,
            c.avatar_url,
            c.color_hex,
            COALESCE(
                (SELECT total_balance FROM calculate_person_balance(user_id, COALESCE(c.linked_profile_id, c.id))),
                0
            ) as balance,
            GREATEST(
                (SELECT MAX(created_at) FROM transactions
                 WHERE (payer_profile_id = c.linked_profile_id OR created_by = c.linked_profile_id)
                   AND deleted_at IS NULL),
                (SELECT MAX(created_at) FROM settlements
                 WHERE (from_profile_id = c.linked_profile_id OR to_profile_id = c.linked_profile_id)
                   AND deleted_at IS NULL),
                (SELECT MAX(created_at) FROM chat_messages
                 WHERE (sender_id = c.linked_profile_id OR recipient_profile_id = c.linked_profile_id)
                   AND deleted_at IS NULL)
            ) as last_activity_at
        FROM contacts c
        WHERE c.owner_id = user_id
          AND c.deleted_at IS NULL
    )
    SELECT * FROM contact_balances
    WHERE balance != 0 OR last_activity_at IS NOT NULL
    ORDER BY last_activity_at DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- TRIGGERS FOR CHAT
-- ============================================================================

-- Trigger to update updated_at on chat messages
CREATE TRIGGER update_chat_messages_updated_at
    BEFORE UPDATE ON chat_messages
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at on conversation settings
CREATE TRIGGER update_conversation_settings_updated_at
    BEFORE UPDATE ON conversation_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-expire typing indicators (cleanup old ones)
CREATE OR REPLACE FUNCTION cleanup_expired_typing_indicators()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM typing_indicators
    WHERE started_at < NOW() - INTERVAL '10 seconds';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cleanup_typing_on_insert
    AFTER INSERT ON typing_indicators
    FOR EACH STATEMENT EXECUTE FUNCTION cleanup_expired_typing_indicators();

-- ============================================================================
-- ROW LEVEL SECURITY FOR CHAT
-- ============================================================================

-- Enable RLS
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_read_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_settings ENABLE ROW LEVEL SECURITY;

-- Chat messages: Participants can view (sender, recipient, or group member)
CREATE POLICY "Chat participants can view messages"
    ON chat_messages FOR SELECT
    USING (
        sender_id = auth.uid()
        OR recipient_profile_id = auth.uid()
        OR (group_id IS NOT NULL AND group_id IN (
            SELECT gm.group_id FROM group_members gm
            WHERE gm.profile_id = auth.uid() AND gm.left_at IS NULL
        ))
    );

-- Chat messages: Only sender can insert
CREATE POLICY "Users can send messages"
    ON chat_messages FOR INSERT
    WITH CHECK (sender_id = auth.uid());

-- Chat messages: Only sender can update (for editing)
CREATE POLICY "Sender can edit messages"
    ON chat_messages FOR UPDATE
    USING (sender_id = auth.uid());

-- Chat messages: Only sender can soft-delete
CREATE POLICY "Sender can delete messages"
    ON chat_messages FOR DELETE
    USING (sender_id = auth.uid());

-- Message reactions: Participants can view
CREATE POLICY "Participants can view reactions"
    ON message_reactions FOR SELECT
    USING (
        message_id IN (
            SELECT id FROM chat_messages
            WHERE sender_id = auth.uid()
               OR recipient_profile_id = auth.uid()
               OR group_id IN (
                   SELECT group_id FROM group_members
                   WHERE profile_id = auth.uid() AND left_at IS NULL
               )
        )
    );

-- Message reactions: Users can add/remove their own reactions
CREATE POLICY "Users can manage their reactions"
    ON message_reactions FOR ALL
    USING (reactor_id = auth.uid());

-- Read receipts: Participants can view
CREATE POLICY "Participants can view read receipts"
    ON message_read_receipts FOR SELECT
    USING (
        message_id IN (
            SELECT id FROM chat_messages
            WHERE sender_id = auth.uid()
               OR group_id IN (
                   SELECT group_id FROM group_members
                   WHERE profile_id = auth.uid() AND left_at IS NULL
               )
        )
    );

-- Read receipts: Users can insert their own
CREATE POLICY "Users can mark messages as read"
    ON message_read_receipts FOR INSERT
    WITH CHECK (reader_id = auth.uid());

-- Typing indicators: Conversation participants can view
CREATE POLICY "Participants can view typing indicators"
    ON typing_indicators FOR SELECT
    USING (
        recipient_profile_id = auth.uid()
        OR (group_id IS NOT NULL AND group_id IN (
            SELECT gm.group_id FROM group_members gm
            WHERE gm.profile_id = auth.uid() AND gm.left_at IS NULL
        ))
    );

-- Typing indicators: Users can manage their own
CREATE POLICY "Users can manage their typing status"
    ON typing_indicators FOR ALL
    USING (typer_id = auth.uid());

-- Conversation settings: Users can manage their own
CREATE POLICY "Users can manage their conversation settings"
    ON conversation_settings FOR ALL
    USING (owner_id = auth.uid());

-- ============================================================================
-- REAL-TIME SUBSCRIPTIONS FOR CHAT
-- ============================================================================

-- Enable real-time for chat tables
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE typing_indicators;

-- ============================================================================
-- VIEWS FOR PEOPLE PAGE
-- ============================================================================

-- View: People list with balances and last activity
CREATE OR REPLACE VIEW people_with_activity AS
SELECT
    c.id as contact_id,
    c.owner_id,
    c.display_name,
    c.phone_number,
    c.avatar_url,
    c.color_hex,
    c.linked_profile_id,
    c.is_favorite,
    c.created_at,
    -- Last activity timestamp (for sorting)
    GREATEST(
        (SELECT MAX(t.created_at) FROM transactions t
         JOIN transaction_splits ts ON ts.transaction_id = t.id
         WHERE (ts.owed_by_profile_id = c.linked_profile_id OR t.payer_profile_id = c.linked_profile_id)
           AND t.deleted_at IS NULL),
        (SELECT MAX(s.created_at) FROM settlements s
         WHERE s.from_profile_id = c.linked_profile_id OR s.to_profile_id = c.linked_profile_id
           AND s.deleted_at IS NULL),
        (SELECT MAX(m.created_at) FROM chat_messages m
         WHERE m.sender_id = c.linked_profile_id OR m.recipient_profile_id = c.linked_profile_id
           AND m.deleted_at IS NULL)
    ) as last_activity_at
FROM contacts c
WHERE c.deleted_at IS NULL;

-- View: Conversation list (for chat inbox)
CREATE OR REPLACE VIEW conversation_list AS
SELECT
    c.id as contact_id,
    c.owner_id,
    c.display_name,
    c.avatar_url,
    c.color_hex,
    c.linked_profile_id,
    'contact' as conversation_type,
    -- Last message preview
    (SELECT content FROM chat_messages m
     WHERE (m.sender_id = c.linked_profile_id AND m.recipient_profile_id = c.owner_id)
        OR (m.sender_id = c.owner_id AND m.recipient_profile_id = c.linked_profile_id)
     ORDER BY m.created_at DESC LIMIT 1) as last_message,
    (SELECT created_at FROM chat_messages m
     WHERE (m.sender_id = c.linked_profile_id AND m.recipient_profile_id = c.owner_id)
        OR (m.sender_id = c.owner_id AND m.recipient_profile_id = c.linked_profile_id)
     ORDER BY m.created_at DESC LIMIT 1) as last_message_at,
    -- Unread count
    (SELECT COUNT(*) FROM chat_messages m
     WHERE m.sender_id = c.linked_profile_id
       AND m.recipient_profile_id = c.owner_id
       AND m.status != 'read'
       AND m.deleted_at IS NULL) as unread_count,
    -- Conversation settings
    COALESCE(cs.is_muted, false) as is_muted,
    COALESCE(cs.is_pinned, false) as is_pinned,
    COALESCE(cs.is_archived, false) as is_archived
FROM contacts c
LEFT JOIN conversation_settings cs ON cs.owner_id = c.owner_id AND cs.contact_id = c.id
WHERE c.deleted_at IS NULL;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
