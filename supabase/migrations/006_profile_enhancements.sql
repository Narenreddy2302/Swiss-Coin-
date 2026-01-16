-- ============================================================================
-- SWISS COIN - PROFILE ENHANCEMENTS
-- Version: 1.0.0
-- Description: Add email field and profile management functions
-- ============================================================================

-- ============================================================================
-- ALTER TABLE: profiles - Add email field
-- ============================================================================
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false;

-- Add index for email lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email) WHERE email IS NOT NULL;

-- Constraint for valid email format
ALTER TABLE profiles
    ADD CONSTRAINT IF NOT EXISTS valid_email_format
    CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- ============================================================================
-- TABLE: profile_photos
-- Description: Track profile photo uploads and history
-- ============================================================================
CREATE TABLE IF NOT EXISTS profile_photos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Link to user profile
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

    -- Photo details
    storage_path TEXT NOT NULL,                              -- Path in Supabase Storage
    original_filename VARCHAR(255),                          -- Original file name
    file_size_bytes INTEGER,                                 -- File size
    mime_type VARCHAR(50),                                   -- image/jpeg, image/png, etc.
    width INTEGER,                                           -- Image width in pixels
    height INTEGER,                                          -- Image height in pixels

    -- Status
    is_current BOOLEAN NOT NULL DEFAULT false,               -- Currently active photo

    -- Audit fields
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ                                   -- Soft delete
);

-- Index for current photo lookup
CREATE INDEX IF NOT EXISTS idx_profile_photos_current ON profile_photos(user_id, is_current) WHERE is_current = true;

-- ============================================================================
-- FUNCTION: Update profile details
-- ============================================================================
CREATE OR REPLACE FUNCTION update_profile_details(
    p_user_id UUID,
    p_display_name VARCHAR(100) DEFAULT NULL,
    p_full_name VARCHAR(200) DEFAULT NULL,
    p_email VARCHAR(255) DEFAULT NULL,
    p_color_hex VARCHAR(7) DEFAULT NULL,
    p_avatar_url TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_result RECORD;
BEGIN
    UPDATE profiles
    SET
        display_name = COALESCE(p_display_name, display_name),
        full_name = COALESCE(p_full_name, full_name),
        email = COALESCE(p_email, email),
        color_hex = COALESCE(p_color_hex, color_hex),
        avatar_url = COALESCE(p_avatar_url, avatar_url),
        updated_at = NOW()
    WHERE id = p_user_id AND deleted_at IS NULL
    RETURNING id, display_name, full_name, email, phone_number, color_hex, avatar_url INTO v_result;

    IF v_result.id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'profile_not_found'
        );
    END IF;

    RETURN json_build_object(
        'success', true,
        'profile', json_build_object(
            'id', v_result.id,
            'display_name', v_result.display_name,
            'full_name', v_result.full_name,
            'email', v_result.email,
            'phone_number', v_result.phone_number,
            'color_hex', v_result.color_hex,
            'avatar_url', v_result.avatar_url
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Set profile photo
-- ============================================================================
CREATE OR REPLACE FUNCTION set_profile_photo(
    p_user_id UUID,
    p_storage_path TEXT,
    p_original_filename VARCHAR(255) DEFAULT NULL,
    p_file_size_bytes INTEGER DEFAULT NULL,
    p_mime_type VARCHAR(50) DEFAULT NULL,
    p_width INTEGER DEFAULT NULL,
    p_height INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_photo_id UUID;
    v_public_url TEXT;
BEGIN
    -- Mark previous photos as not current
    UPDATE profile_photos
    SET is_current = false
    WHERE user_id = p_user_id AND is_current = true;

    -- Insert new photo record
    INSERT INTO profile_photos (
        user_id,
        storage_path,
        original_filename,
        file_size_bytes,
        mime_type,
        width,
        height,
        is_current
    )
    VALUES (
        p_user_id,
        p_storage_path,
        p_original_filename,
        p_file_size_bytes,
        p_mime_type,
        p_width,
        p_height,
        true
    )
    RETURNING id INTO v_photo_id;

    -- Construct public URL (adjust bucket name as needed)
    v_public_url := 'https://' || current_setting('app.supabase_url', true) || '/storage/v1/object/public/avatars/' || p_storage_path;

    -- Update profile with new avatar URL
    UPDATE profiles
    SET
        avatar_url = v_public_url,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN json_build_object(
        'success', true,
        'photo_id', v_photo_id,
        'avatar_url', v_public_url
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Delete profile photo
-- ============================================================================
CREATE OR REPLACE FUNCTION delete_profile_photo(
    p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_storage_path TEXT;
BEGIN
    -- Get current photo storage path for cleanup
    SELECT storage_path INTO v_storage_path
    FROM profile_photos
    WHERE user_id = p_user_id AND is_current = true;

    -- Soft delete current photo
    UPDATE profile_photos
    SET
        is_current = false,
        deleted_at = NOW()
    WHERE user_id = p_user_id AND is_current = true;

    -- Clear avatar_url from profile
    UPDATE profiles
    SET
        avatar_url = NULL,
        updated_at = NOW()
    WHERE id = p_user_id;

    RETURN json_build_object(
        'success', true,
        'deleted_storage_path', v_storage_path
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Get profile details
-- ============================================================================
CREATE OR REPLACE FUNCTION get_profile_details(p_user_id UUID)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'id', p.id,
            'phone_number', p.phone_number,
            'phone_verified', p.phone_verified,
            'display_name', p.display_name,
            'full_name', p.full_name,
            'email', p.email,
            'email_verified', p.email_verified,
            'avatar_url', p.avatar_url,
            'color_hex', p.color_hex,
            'default_currency', p.default_currency,
            'created_at', p.created_at,
            'updated_at', p.updated_at
        )
        FROM profiles p
        WHERE p.id = p_user_id AND p.deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- FUNCTION: Validate and update email
-- ============================================================================
CREATE OR REPLACE FUNCTION update_email(
    p_user_id UUID,
    p_email VARCHAR(255)
)
RETURNS JSON AS $$
DECLARE
    v_existing_user UUID;
BEGIN
    -- Check if email is already in use
    SELECT id INTO v_existing_user
    FROM profiles
    WHERE email = p_email AND id != p_user_id AND deleted_at IS NULL;

    IF v_existing_user IS NOT NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'email_already_in_use'
        );
    END IF;

    -- Update email (mark as unverified)
    UPDATE profiles
    SET
        email = p_email,
        email_verified = false,
        updated_at = NOW()
    WHERE id = p_user_id AND deleted_at IS NULL;

    RETURN json_build_object(
        'success', true,
        'email', p_email
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE profile_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own photos"
    ON profile_photos FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Users can manage own photos"
    ON profile_photos FOR ALL
    USING (user_id = auth.uid());

-- ============================================================================
-- STORAGE BUCKET SETUP (run separately in Supabase Dashboard)
-- ============================================================================
-- Note: Create storage bucket 'avatars' in Supabase Dashboard with:
-- - Public bucket: true (for public avatar URLs)
-- - File size limit: 5MB
-- - Allowed MIME types: image/jpeg, image/png, image/webp, image/gif
-- - RLS policies:
--   SELECT: true (public read)
--   INSERT: auth.uid() IS NOT NULL
--   UPDATE: bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]
--   DELETE: bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON TABLE profile_photos TO authenticated;
GRANT EXECUTE ON FUNCTION update_profile_details TO authenticated;
GRANT EXECUTE ON FUNCTION set_profile_photo TO authenticated;
GRANT EXECUTE ON FUNCTION delete_profile_photo TO authenticated;
GRANT EXECUTE ON FUNCTION get_profile_details TO authenticated;
GRANT EXECUTE ON FUNCTION update_email TO authenticated;
