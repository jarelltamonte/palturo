-- P2.2: signup/reset no longer reveal whether an email exists. The helper is
-- kept for service/admin use only.
revoke all on function public.email_exists(text) from public, anon, authenticated;
