-- Franchise Horizon Admin Dashboard schema
-- Run this script in Supabase SQL Editor before connecting admin-config.js.
-- Create the first admin in Supabase Authentication > Users, then insert their UUID below.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'admin' check (role in ('owner','admin','editor')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.site_content (
  id uuid primary key default gen_random_uuid(),
  section text not null check (section in ('home','about','home_brands','brands_on_board','group_companies','brands','consulting_partners','services','team','expert_consultants','domestic','global','contact','seo')),
  title text not null,
  status text not null default 'draft' check (status in ('published','draft','archived')),
  sort_order integer not null default 0,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  name text,
  email text,
  phone text,
  subject text,
  message text,
  source text not null default 'website',
  status text not null default 'new' check (status in ('new','contacted','follow-up','converted','closed')),
  assigned_to text,
  follow_up_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.site_content (section, title, status, sort_order, data)
select 'home_brands', seed.title, 'published', seed.sort_order,
       jsonb_build_object('description', '', 'logo_url', '', 'website_url', '')
from (values
  ('Chamak', 1), ('Legacy of Bhojraj', 2), ('MBH', 3),
  ('Bhatter Silver', 4), ('Just Mats', 5), ('Casa Dei Bambini', 6),
  ('So Southy', 7)
) as seed(title, sort_order)
where not exists (
  select 1 from public.site_content existing
  where existing.section='home_brands' and lower(existing.title)=lower(seed.title)
);

create index if not exists site_content_section_status_order_idx
  on public.site_content(section, status, sort_order);
create index if not exists enquiries_status_created_idx
  on public.enquiries(status, created_at desc);

create or replace function public.fh_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = auth.uid() and is_active = true
  );
$$;

create or replace function public.fh_is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = auth.uid() and is_active = true and role = 'owner'
  );
$$;

alter table public.admin_users enable row level security;
alter table public.site_content enable row level security;
alter table public.enquiries enable row level security;

drop policy if exists "Admin users can read own access record" on public.admin_users;
create policy "Admin users can read own access record"
  on public.admin_users for select
  to authenticated
  using (user_id = auth.uid() or public.fh_is_admin());

drop policy if exists "Owners manage admin access" on public.admin_users;
create policy "Owners manage admin access"
  on public.admin_users for all
  to authenticated
  using (public.fh_is_owner())
  with check (public.fh_is_owner());

drop policy if exists "Public can read published website content" on public.site_content;
create policy "Public can read published website content"
  on public.site_content for select
  to anon, authenticated
  using (status = 'published' or public.fh_is_admin());

drop policy if exists "Admins manage website content" on public.site_content;
create policy "Admins manage website content"
  on public.site_content for all
  to authenticated
  using (public.fh_is_admin())
  with check (public.fh_is_admin());

drop policy if exists "Visitors can submit enquiries" on public.enquiries;
create policy "Visitors can submit enquiries"
  on public.enquiries for insert
  to anon, authenticated
  with check (
    (name is null or char_length(name) <= 160)
    and (email is null or char_length(email) <= 254)
    and (phone is null or char_length(phone) <= 40)
    and (subject is null or char_length(subject) <= 240)
    and (message is null or char_length(message) <= 10000)
  );

drop policy if exists "Admins read enquiries" on public.enquiries;
create policy "Admins read enquiries"
  on public.enquiries for select
  to authenticated
  using (public.fh_is_admin());

drop policy if exists "Admins update enquiries" on public.enquiries;
create policy "Admins update enquiries"
  on public.enquiries for update
  to authenticated
  using (public.fh_is_admin())
  with check (public.fh_is_admin());

drop policy if exists "Admins delete enquiries" on public.enquiries;
create policy "Admins delete enquiries"
  on public.enquiries for delete
  to authenticated
  using (public.fh_is_admin());

-- FIRST ADMIN SETUP:
-- 1. Create a user in Supabase Authentication > Users.
-- 2. Copy their user UUID and run the following statement after replacing the values:
-- insert into public.admin_users (user_id, email, role, is_active)
-- values ('PASTE-AUTH-USER-UUID-HERE', 'admin@yourdomain.com', 'owner', true);
--
-- Keep the Supabase service_role key private. Browser code must use only the anon/publishable key.

-- Required SQL privileges (RLS policies above still control which rows/actions are allowed).
grant select on public.site_content to anon, authenticated;
grant insert, update, delete on public.site_content to authenticated;

grant insert on public.enquiries to anon;
grant select, insert, update, delete on public.enquiries to authenticated;

grant select on public.admin_users to authenticated;

-- Storage bucket for leadership photos, brand logos, and other admin-uploaded images.
-- Public read is enabled so images can appear on the public website.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'fh-media',
  'fh-media',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

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
