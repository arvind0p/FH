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
  section text not null check (section in ('home','about','brands','services','team','domestic','global','contact','seo')),
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
