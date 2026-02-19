# 11 - Auth Flow Migration: Apple Metadata Sync & Phone Hash

Step-by-step instructions for updating the Supabase backend to support improved Apple Sign-In metadata capture and phone hash indexing.

**Prerequisites:** Access to the Supabase Dashboard for the Swiss Coin project.

---

## Step 1: Open the SQL Editor

1. Go to your **Supabase Dashboard** at [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select the **Swiss Coin** project (`fgcjijairsikaeshpiof`)
3. In the left sidebar, click **SQL Editor**
4. Click **New query** to open a blank editor

---

## Step 2: Ensure `phone_hash` Column Exists on `profiles` Table

The `profiles` table needs a `phone_hash` column for privacy-preserving contact discovery. This column stores a SHA-256 hash of the user's E.164 phone number.

**Paste and run this SQL:**

```sql
-- Add phone_hash column if it doesn't already exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone_hash TEXT;

-- Create index for fast phone hash lookups (used by contact discovery)
CREATE INDEX IF NOT EXISTS idx_profiles_phone_hash ON public.profiles(phone_hash);
```

**Expected result:** `Success. No rows returned.` (or similar confirmation)

**Verification:** Go to **Table Editor** > **profiles** and confirm the `phone_hash` column appears in the column list.

---

## Step 3: Update the `handle_new_user()` Trigger Function

The current trigger only captures `display_name` and `phone` when a new user signs up. For Apple Sign-In users, the trigger needs to also capture:
- **email** from `auth.users.email` (Apple provides this via the identity token)
- **full_name** from `raw_user_meta_data` (set by the iOS client after sign-in)
- **display_name** with better fallback chain (given_name → full_name → 'Me')

**Paste and run this SQL:**

```sql
-- Update the trigger function to capture Apple Sign-In metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, full_name, phone, email, created_at, updated_at)
  VALUES (
    NEW.id,
    -- Prefer given_name (first name), fall back to full_name, then 'Me'
    COALESCE(
      NEW.raw_user_meta_data ->> 'given_name',
      NEW.raw_user_meta_data ->> 'full_name',
      NEW.raw_user_meta_data ->> 'display_name',
      'Me'
    ),
    -- Full name from Apple metadata (may be null on first sign-in since
    -- the iOS client calls auth.update() after the trigger fires)
    NEW.raw_user_meta_data ->> 'full_name',
    -- Phone (null for Apple Sign-In users; set later via PhoneEntryView)
    NEW.phone,
    -- Email from Apple identity token (may be relay address like xxx@privaterelay.appleid.com)
    COALESCE(NEW.email, NEW.raw_user_meta_data ->> 'email'),
    NOW(),
    NOW()
  );
  RETURN NEW;
END;
$$;
```

**Expected result:** `Success. No rows returned.`

**Verification:** The function is automatically active because the trigger `on_auth_user_created` already references it. No need to recreate the trigger.

---

## Step 4: Verify the Trigger Exists

Run this query to confirm the trigger is still attached:

```sql
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND event_object_schema = 'auth';
```

**Expected result:** You should see a row with:
- `trigger_name`: `on_auth_user_created`
- `event_manipulation`: `INSERT`
- `action_statement`: `EXECUTE FUNCTION handle_new_user()`

If the trigger is missing, recreate it:

```sql
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

---

## Step 5: Backfill Existing Profiles (Optional)

If you have existing users whose `profiles` rows are missing `email` or have `display_name = 'Me'`, you can backfill from `auth.users`:

```sql
-- Backfill email from auth.users where profiles.email is null
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id
  AND p.email IS NULL
  AND u.email IS NOT NULL;

-- Backfill display_name from auth.users metadata where it's still 'Me'
UPDATE public.profiles p
SET display_name = COALESCE(
  u.raw_user_meta_data ->> 'given_name',
  u.raw_user_meta_data ->> 'full_name',
  p.display_name
)
FROM auth.users u
WHERE p.id = u.id
  AND p.display_name = 'Me'
  AND (u.raw_user_meta_data ->> 'given_name' IS NOT NULL
       OR u.raw_user_meta_data ->> 'full_name' IS NOT NULL);
```

**Note:** This step is optional. The iOS client's `syncAppleMetadataToProfile()` method will also update these fields on next app launch.

---

## Step 6: Verify Everything Works

1. **Check the profiles table schema:**
   ```sql
   SELECT column_name, data_type, is_nullable
   FROM information_schema.columns
   WHERE table_name = 'profiles' AND table_schema = 'public'
   ORDER BY ordinal_position;
   ```
   Confirm `phone_hash`, `email`, `full_name`, `display_name` columns all exist.

2. **Check the trigger function source:**
   ```sql
   SELECT prosrc FROM pg_proc WHERE proname = 'handle_new_user';
   ```
   Confirm it contains the updated COALESCE logic for `display_name` and `email`.

3. **Test with a new user (optional):** Create a test user via the Supabase Dashboard Authentication tab and check if the profiles row is created correctly.

---

## Summary of Changes

| What | Before | After |
|------|--------|-------|
| `profiles.phone_hash` column | May not exist | Exists with index |
| `handle_new_user()` — display_name | `COALESCE(metadata.display_name, 'Me')` | `COALESCE(metadata.given_name, metadata.full_name, metadata.display_name, 'Me')` |
| `handle_new_user()` — full_name | Not captured | Captured from `metadata.full_name` |
| `handle_new_user()` — email | Not captured | Captured from `auth.users.email` or `metadata.email` |

These changes are backward-compatible. Existing profiles are unaffected. The iOS client's `syncAppleMetadataToProfile()` method provides a safety net for any metadata the trigger misses.
