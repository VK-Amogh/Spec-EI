-- Update check_email_exists to be case-insensitive
CREATE OR REPLACE FUNCTION public.check_email_exists(email_to_check text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with admin privileges to bypass RLS
SET search_path = public -- Secure search path
AS $$
BEGIN
  -- Use ILIKE for case-insensitive comparison
  RETURN EXISTS (SELECT 1 FROM public.users WHERE email ILIKE email_to_check);
END;
$$;

-- Grant access to this function for anonymous and authenticated users
GRANT EXECUTE ON FUNCTION public.check_email_exists(text) TO anon, authenticated, service_role;
