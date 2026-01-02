# Fix Supabase CORS and RPC for Media Persistence

For media to persist after logout/refresh, your Supabase project needs two things configured:

## Step 1: Run the SQL Script (Required for RPC)

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard/project/sguojbwhhiatcdgpfise)
2. Click **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy and paste the following SQL:

```sql
-- Secure function to get media items
CREATE OR REPLACE FUNCTION get_media_secure(p_user_id text)
RETURNS SETOF media
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM media
  WHERE user_id = p_user_id
  ORDER BY captured_at DESC;
$$;

-- Grant access to this function
GRANT EXECUTE ON FUNCTION get_media_secure(text) TO anon, authenticated, service_role;
```

5. Click **Run** (or press Ctrl+Enter)
6. You should see "Success. No rows returned" - this is correct!

## Step 2: Configure CORS (Required for Web)

> **IMPORTANT**: This step is REQUIRED when running the app in Chrome/Web browser.

### Option A: Via Supabase Dashboard
1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/sguojbwhhiatcdgpfise)
2. Click **Project Settings** (gear icon) in the left sidebar
3. Click **API** in the settings menu
4. Scroll down to find **CORS** settings
5. Add these origins (one per line):
   - `http://localhost`
   - `http://localhost:*`
   - `http://127.0.0.1`
   - `http://127.0.0.1:*`
6. Click **Save**

### Option B: If CORS setting is not visible
Supabase's newer dashboard may not show CORS in the API section. In this case:

1. Go to **Project Settings** → **Edge Functions** (if visible)
2. Or try running the app on a mobile device/emulator instead of Chrome (no CORS issues on mobile)

## Step 3: Test the Fix

1. After configuring CORS, go back to your app
2. Press **R** in the terminal to hot restart
3. Go to the Memory tab and click the **Refresh** button
4. You should see "Refreshed! Found X media items." in green
5. Try recording a video - it should now persist after refresh!

## Troubleshooting

If you still see "Failed to fetch" errors:
- Double-check that CORS includes your exact localhost URL
- Try running on Android/iOS instead of Chrome (no CORS restrictions)
- Check the browser console (F12) for specific CORS error messages
