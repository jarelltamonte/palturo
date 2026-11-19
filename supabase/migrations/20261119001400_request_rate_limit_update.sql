-- Reactivating a declined request is an UPDATE, not an INSERT. Count both so
-- the daily request limit cannot be bypassed by decline/reactivate loops.
create or replace function public.rate_limit_connection_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending')
     and auth.uid() is not null
     and not public.consume_rate_limit(
       auth.uid(), 'send_connection_request', 20, 86400
     ) then
    raise exception 'Too many connection requests today';
  end if;
  return new;
end;
$$;

drop trigger if exists rate_limit_connection_insert on public.connections;
create trigger rate_limit_connection_insert
  before insert or update of status on public.connections
  for each row execute function public.rate_limit_connection_insert();
