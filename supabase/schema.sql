-- Run once in the Supabase SQL Editor for your own project.
create table if not exists public.notes (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  content jsonb not null default '[{"insert":"\n"}]'::jsonb,
  plain_text text not null default '',
  color_index integer not null default 0 check (color_index between 0 and 5),
  images jsonb not null default '[]'::jsonb,
  strokes jsonb not null default '[]'::jsonb,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  revision integer not null default 1 check (revision >= 1),
  deleted boolean not null default false
);

create index if not exists notes_owner_updated_idx
  on public.notes (owner_id, updated_at desc);

alter table public.notes enable row level security;
revoke all on public.notes from anon;
grant select, insert, update on public.notes to authenticated;

create policy "read own notes" on public.notes
  for select to authenticated
  using (owner_id = (select auth.uid()));

create policy "create own notes" on public.notes
  for insert to authenticated
  with check (owner_id = (select auth.uid()));

create policy "update own notes" on public.notes
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'note-assets', 'note-assets', false, 8388608,
  array['image/png', 'image/jpeg', 'image/gif', 'image/webp']
)
on conflict (id) do nothing;

create policy "read own note images" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'note-assets'
    and split_part(name, '/', 1) = (select auth.uid())::text
  );

create policy "upload own note images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'note-assets'
    and split_part(name, '/', 1) = (select auth.uid())::text
  );

create policy "update own note images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'note-assets'
    and split_part(name, '/', 1) = (select auth.uid())::text
  )
  with check (
    bucket_id = 'note-assets'
    and split_part(name, '/', 1) = (select auth.uid())::text
  );

create policy "remove own note images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'note-assets'
    and split_part(name, '/', 1) = (select auth.uid())::text
  );
