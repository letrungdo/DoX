-- Storage for account profile pictures.
--
-- Public read: an avatar URL is handed to CachedNetworkImage, which fetches it
-- without the session. Writes are confined to a folder named after the owner's
-- uid, so a signed-in user can replace their own picture and nobody else's.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  1048576, -- 1 MiB; the app compresses to a 512px webp, far under this.
  array['image/webp', 'image/jpeg', 'image/png']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars are readable by anyone" on storage.objects;
create policy "avatars are readable by anyone"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "a user writes only their own avatar" on storage.objects;
create policy "a user writes only their own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "a user replaces only their own avatar" on storage.objects;
create policy "a user replaces only their own avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "a user removes only their own avatar" on storage.objects;
create policy "a user removes only their own avatar"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
