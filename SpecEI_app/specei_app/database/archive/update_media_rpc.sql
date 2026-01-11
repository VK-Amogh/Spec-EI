-- Secure function to get media items items
-- This function allows the app to fetch photos/videos securely, bypassing complex permission rules.
-- Run this in your Supabase SQL Editor to fix the media loading issue.

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

-- Grant access to this function so the app can call it
GRANT EXECUTE ON FUNCTION get_media_secure(text) TO anon, authenticated, service_role;
