-- Removing a device token never needed elevated rights: registering already
-- moves a row left by a previous account to whoever signs in next, so this only
-- ever has to delete the caller's own row. As SECURITY DEFINER it also let any
-- signed-in user unregister a token they came across, silencing that device.
create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security invoker
set search_path = ''
as $$
  delete from public.device_tokens
  where token = trim(p_token) and user_id = auth.uid();
$$;
