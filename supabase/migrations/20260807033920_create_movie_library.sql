create table public.movie_library (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  movie_id text not null check (length(trim(movie_id)) > 0),
  title text not null,
  movie_url text not null,
  poster_url text not null default '',
  description text,
  watched_at timestamptz,
  is_favorite boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, movie_id)
);

create index movie_library_watched_idx
  on public.movie_library (user_id, watched_at desc)
  where watched_at is not null;

create index movie_library_favorite_idx
  on public.movie_library (user_id, updated_at desc)
  where is_favorite;

alter table public.movie_library enable row level security;

create policy "owner select"
  on public.movie_library for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "owner insert"
  on public.movie_library for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "owner update"
  on public.movie_library for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "owner delete"
  on public.movie_library for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.movie_library from anon, authenticated;
grant select, insert, update, delete on table public.movie_library to authenticated;
