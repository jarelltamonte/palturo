-- Blocking promises removal from Pals. Pending requests were already declined;
-- accepted connections must be removed too so Chats/Pals/Profile agree.

create or replace function public.block_user(p_target uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not authenticated'; end if;
  if me = p_target then raise exception 'You cannot block yourself'; end if;
  insert into public.blocks (blocker_id, blocked_id)
    values (me, p_target) on conflict do nothing;
  update public.connections set status = 'declined', responded_at = now()
    where status = 'pending'
      and ((requester_id = me and recipient_id = p_target)
        or (requester_id = p_target and recipient_id = me));
  delete from public.connections
    where status = 'accepted'
      and ((requester_id = me and recipient_id = p_target)
        or (requester_id = p_target and recipient_id = me));
end $$;
