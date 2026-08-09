-- pg_net 0.20 is not relocatable, so it cannot use ALTER EXTENSION SET SCHEMA.
-- Recreating it is safe only while its request queue is empty. Abort rather
-- than discard a pending HTTP request if one appears between inspection and
-- deployment.
do $$
begin
  if exists (select 1 from net.http_request_queue) then
    raise exception 'Cannot move pg_net while HTTP requests are queued';
  end if;
end;
$$;

create schema if not exists extensions;
drop extension pg_net;
create extension pg_net schema extensions;
