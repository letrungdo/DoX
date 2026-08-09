-- Delete one signed-in user's complete chicken dataset in a single
-- transaction. SECURITY INVOKER keeps every DELETE behind the existing owner
-- RLS policies; auth.uid() also makes it impossible to name another owner.
create or replace function public.delete_all_chicken_data()
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_deleted integer := 0;
  v_rows integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  delete from public.cock_sales where user_id = v_user_id;
  get diagnostics v_rows = row_count;
  v_deleted := v_deleted + v_rows;

  delete from public.expenses where user_id = v_user_id;
  get diagnostics v_rows = row_count;
  v_deleted := v_deleted + v_rows;

  -- Vaccinations and batch sales cascade with their batch.
  delete from public.chicken_batches where user_id = v_user_id;
  get diagnostics v_rows = row_count;
  v_deleted := v_deleted + v_rows;

  return v_deleted;
end;
$$;

revoke execute on function public.delete_all_chicken_data() from public, anon;
grant execute on function public.delete_all_chicken_data() to authenticated;
