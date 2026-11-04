-- Connection rows stay readable for membership/status, but the read
-- timestamps are RPC-only. Otherwise a modified client could bypass the
-- receipt toggle with a direct select.

revoke all on public.connections from anon, authenticated;

grant select (
  id,
  requester_id,
  recipient_id,
  status,
  created_at,
  responded_at,
  skill_name,
  skill_path
) on public.connections to authenticated;
