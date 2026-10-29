-- Franchise Horizon admin image uploads
-- Run this once in the Supabase SQL Editor for the active project.
-- Public bucket allows the website to display uploaded images. Only active admin users can upload, replace, or delete files.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'fh-media',
  'fh-media',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp','image/gif','image/svg+xml']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "FH admins can upload media" on storage.objects;
create policy "FH admins can upload media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'fh-media'
  and exists (
    select 1 from public.admin_users au
    where au.user_id = auth.uid() and au.is_active = true
  )
);

drop policy if exists "FH admins can update media" on storage.objects;
create policy "FH admins can update media"
on storage.objects for update to authenticated
using (
  bucket_id = 'fh-media'
  and exists (
    select 1 from public.admin_users au
    where au.user_id = auth.uid() and au.is_active = true
  )
)
with check (
  bucket_id = 'fh-media'
  and exists (
    select 1 from public.admin_users au
    where au.user_id = auth.uid() and au.is_active = true
  )
);

drop policy if exists "FH admins can delete media" on storage.objects;
create policy "FH admins can delete media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'fh-media'
  and exists (
    select 1 from public.admin_users au
    where au.user_id = auth.uid() and au.is_active = true
  )
);
