alter table public.movie_library
  drop column title,
  drop column poster_path,
  drop column description,
  drop column created_at;

comment on table public.movie_library is
  'Per-account watch and favorite state. Movie metadata is loaded from the configured movie server via movie_path.';
