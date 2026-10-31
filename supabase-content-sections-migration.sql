-- Franchise Horizon: add independently managed public content sections.
-- Run this once in Supabase SQL Editor on the existing project.

alter table public.site_content
  drop constraint if exists site_content_section_check;

alter table public.site_content
  add constraint site_content_section_check
  check (section in (
    'home','about','home_brands','group_companies','brands',
    'services','team','expert_consultants','domestic','global',
    'contact','seo'
  ));

-- Seed the seven existing homepage brand labels so they can be managed immediately.
insert into public.site_content (section, title, status, sort_order, data)
select 'home_brands', seed.title, 'published', seed.sort_order,
       jsonb_build_object('description', '', 'logo_url', '', 'website_url', '')
from (values
  ('Chamak', 1),
  ('Legacy of Bhojraj', 2),
  ('MBH', 3),
  ('Bhatter Silver', 4),
  ('Just Mats', 5),
  ('Casa Dei Bambini', 6),
  ('So Southy', 7)
) as seed(title, sort_order)
where not exists (
  select 1 from public.site_content existing
  where existing.section = 'home_brands'
    and lower(existing.title) = lower(seed.title)
);

-- Ensure the public image bucket and admin upload policies exist.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fh-media','fh-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
set public=excluded.public,
    file_size_limit=excluded.file_size_limit,
    allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "Public can read FH media" on storage.objects;
create policy "Public can read FH media"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'fh-media');

drop policy if exists "Admins manage FH media" on storage.objects;
create policy "Admins manage FH media"
  on storage.objects for all
  to authenticated
  using (bucket_id = 'fh-media' and public.fh_is_admin())
  with check (bucket_id = 'fh-media' and public.fh_is_admin());
