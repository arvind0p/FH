-- Franchise Horizon: add independently managed public content sections.
-- Run this once in Supabase SQL Editor on the existing project.

alter table public.site_content
  drop constraint if exists site_content_section_check;

alter table public.site_content
  add constraint site_content_section_check
  check (section in (
    'home','about','home_brands','brands_on_board','group_companies','brands','consulting_partners',
    'services','team','expert_consultants','domestic','global','contact','seo'
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


-- Leadership & Team: split one shared team collection into three manageable groups.
-- Existing Founder/Leadership/Team records become Core Team. The company profile
-- lists these 11 additional names under Our Team; no international team names are
-- identified in the supplied profile, so International remains available but unseeded.
update public.site_content
set data = coalesce(data, '{}'::jsonb) || jsonb_build_object('team_group','Core Team')
where section='team'
  and coalesce(data->>'team_group','')=''
  and coalesce(data->>'member_type','Leadership') in ('Founder','Leadership','Team');

insert into public.site_content (section,title,status,sort_order,data)
select 'team', seed.title, 'published', seed.sort_order,
       jsonb_build_object('team_group','National','member_type','National','designation','','photo_url','','bio','')
from (values
  ('Kuldeep Simlote', 5),
  ('Atma Prakash', 6),
  ('Sanjana Krishnani', 7),
  ('Anitha K', 8),
  ('Amit Jain', 9),
  ('Amit Ojha', 10),
  ('Shikha Tyagi', 11),
  ('Himanshu Mishra', 12),
  ('Shrikant Patekar', 13),
  ('Chirag Pankhaniya', 14),
  ('Rahul Chittora', 15)
) as seed(title, sort_order)
where not exists (
  select 1 from public.site_content existing
  where existing.section='team' and lower(trim(existing.title))=lower(trim(seed.title))
);
